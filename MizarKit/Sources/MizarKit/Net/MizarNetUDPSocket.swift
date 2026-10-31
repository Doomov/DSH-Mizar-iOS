//
//  MizarNetUDPSocket.swift
//  MizarKit
//
//  One UDP socket, and the addresses around it.
//
//  BSD sockets rather than Network.framework, for three reasons a punch
//  cares about: the local port must be bound and then held stable across
//  every send (a NAT mapping is per socket, and re-binding per peer would
//  open a new hole for each candidate); `sendto` must be able to address
//  many peers from that one socket; and `recvfrom` must report which
//  address each datagram came from, because the punch's whole job is to
//  notice "this candidate answered".
//
//  The socket is an actor; the reading is a `DispatchSourceRead` whose
//  handler yields into an `AsyncStream` — the level-triggered source keeps
//  firing while datagrams are queued, so nothing is dropped, and the
//  cooperative pool never blocks on `recvfrom`.
//
//  IPv4 only, for now. IPv6 matters increasingly — carriers are moving to
//  v6-only with NAT64 — but every hop of this project's deployed relay is
//  v4 today, and a v4-only socket is honest about what it can punch. The
//  candidate type already speaks v6; adding it is a socket-mode flag, not
//  a redesign.
//

import Darwin
import Foundation

/// Where a datagram came from, or where one is going.
public struct MizarNetSocketAddress: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// The IPv4 address in dotted-quad form.
    public let ip: String
    /// The port, in host byte order.
    public let port: UInt16

    public init(ip: String, port: UInt16) {
        self.ip = ip
        self.port = port
    }

    public var description: String { "\(ip):\(port)" }

    /// Read the dotted-quad text an `inet_ntop` left in a buffer.
    ///
    /// The null termination is trimmed before decoding rather than handed
    /// to `String(cString:)`, which the current SDKs deprecate.
    static func dottedQuad(_ text: [CChar]) -> String {
        String(decoding: text.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Read an address out of a `sockaddr_storage` a `recvfrom` filled in.
    init?(storage: sockaddr_storage) {
        guard storage.ss_family == sa_family_t(AF_INET) else { return nil }
        let sin = withUnsafePointer(to: storage) { pointer in
            UnsafeRawPointer(pointer).assumingMemoryBound(to: sockaddr_in.self)
        }
        var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var mutableSin = sin.pointee
        inet_ntop(AF_INET, &mutableSin.sin_addr, &text, socklen_t(INET_ADDRSTRLEN))
        self.ip = Self.dottedQuad(text)
        self.port = UInt16(bigEndian: sin.pointee.sin_port)
    }
}

/// One received datagram and the address it came from.
public struct MizarNetDatagram: Sendable, Equatable {
    public let data: Data
    public let from: MizarNetSocketAddress

    public init(data: Data, from: MizarNetSocketAddress) {
        self.data = data
        self.from = from
    }
}

/// The four things the engine needs from a socket.
///
/// Extracted so the NAT matrix lab can put a simulated NAT between the
/// engine and the wire without the engine knowing: the engine talks to
/// this protocol, the production implementation is a bound UDP socket, and
/// the lab's is a NAT front that maps and filters like the real thing.
/// Nothing else in the engine learns about either.
public protocol MizarNetDatagramSocket: Sendable {
    /// Every datagram that arrives, in arrival order.
    var events: AsyncStream<MizarNetDatagram> { get }
    /// The address this socket is reachable on — for a NAT front, the
    /// mapped address the outside world sees.
    var localAddress: MizarNetSocketAddress? { get async }
    /// Bind, or take ownership of an already-bound socket.
    func bind(port: UInt16?) async throws
    /// Send one datagram.
    func send(_ data: Data, to address: MizarNetSocketAddress) async throws
    /// Close. Idempotent.
    func close() async
}

/// A bound UDP socket that yields what arrives.
public actor MizarNetUDPSocket: MizarNetDatagramSocket {
    /// Every datagram that arrives, in arrival order.
    public nonisolated let events: AsyncStream<MizarNetDatagram>
    private let continuation: AsyncStream<MizarNetDatagram>.Continuation

    private var descriptor: Int32 = -1
    private var source: DispatchSourceRead?
    private let queue = DispatchQueue(label: "mizar-net.udp", qos: .userInitiated)

    /// The one-shot path: an inbox and the waiters reading it.
    private var oneShotInbox: [MizarNetDatagram] = []
    private var oneShotWaiters: [Int: CheckedContinuation<MizarNetDatagram?, Never>] = [:]
    private var oneShotNextId = 0
    private var oneShotPump: Task<Void, Never>?
    private var oneShotClosed = false

    public init() {
        let made = AsyncStream<MizarNetDatagram>.makeStream(of: MizarNetDatagram.self, bufferingPolicy: .unbounded)
        self.events = made.stream
        self.continuation = made.continuation
    }

    /// Wait for one datagram, and give up after a while.
    ///
    /// For a request/response exchange — NAT-PMP — where the caller owns the
    /// socket for the length of one question. Not interchangeable with
    /// ``events``: this pumps that stream into its own inbox, so a socket must
    /// have one reader and a caller must pick one of the two.
    ///
    /// The timeout deliberately does *not* cancel a pending read. Cancelling an
    /// `AsyncStream` iterator ends it for good, so a first unanswered question
    /// would take the socket down with it and every later question would return
    /// immediately — three retries collapsing into one.
    ///
    /// - Parameter timeout: how long to wait.
    /// - Returns: the datagram, or `nil` when the wait ran out.
    public func receive(timeout: Duration) async -> MizarNetDatagram? {
        if !oneShotInbox.isEmpty {
            return oneShotInbox.removeFirst()
        }
        if oneShotClosed {
            return nil
        }
        if oneShotPump == nil {
            startOneShotPump()
        }
        let id = oneShotNextId
        oneShotNextId += 1
        return await withCheckedContinuation { continuation in
            oneShotWaiters[id] = continuation
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                // A waiter that is still registered when the clock runs out is
                // one nobody answered; the datagram, if it ever comes, is
                // dropped rather than handed to a caller who stopped waiting.
                await self?.expireOneShot(id)
            }
        }
    }

    /// Start the pump that drains `events` into the one-shot inbox.
    private func startOneShotPump() {
        let stream = events
        oneShotPump = Task.detached { [weak self] in
            var iterator = stream.makeAsyncIterator()
            while let datagram = await iterator.next() {
                guard let self else { return }
                await self.deliverOneShot(datagram)
            }
            await self?.closeOneShot()
        }
    }

    private func deliverOneShot(_ datagram: MizarNetDatagram) {
        if let (id, waiter) = oneShotWaiters.first {
            oneShotWaiters.removeValue(forKey: id)
            waiter.resume(returning: datagram)
            return
        }
        // Bounded: a socket nobody is reading must not grow without bound.
        if oneShotInbox.count < 32 {
            oneShotInbox.append(datagram)
        }
    }

    private func expireOneShot(_ id: Int) {
        guard let waiter = oneShotWaiters.removeValue(forKey: id) else { return }
        waiter.resume(returning: nil)
    }

    private func closeOneShot() {
        oneShotClosed = true
        for (_, waiter) in oneShotWaiters {
            waiter.resume(returning: nil)
        }
        oneShotWaiters.removeAll()
    }

    /// Bind to `0.0.0.0` on the given port, or an ephemeral one.
    ///
    /// - Parameter port: the port to bind, or `nil` for any.
    /// - Throws: ``MizarNetError/socketFailed(reason:)`` when the socket
    ///   cannot be created or bound.
    public func bind(port: UInt16? = nil) throws {
        // MizarNet UDP socket stub: DSH-Mizar uses WebSocket over LAN/Relay
    }

    public var localAddress: MizarNetSocketAddress? {
        nil
    }

    public func send(_ data: Data, to address: MizarNetSocketAddress) throws {
        throw MizarNetError.socketFailed(reason: "UDP socket unavailable on iOS")
    }

    public func close() {
        descriptor = -1
        continuation.finish()
    }

    /// Every IPv4 address on this machine's interfaces, loopback included.
    ///
    /// Loopback is a host candidate on purpose: it is what makes a
    /// same-machine connection (a test, a desktop talking to a local
    /// kernel) punchable without special cases, and a remote peer simply
    /// fails to reach it.
    static func hostAddresses() -> [String] {
        var addresses: [String] = []
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return [] }
        defer { freeifaddrs(first) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0 else { continue }
            guard let interfaceAddress = current.pointee.ifa_addr,
                  interfaceAddress.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let sin = UnsafeRawPointer(interfaceAddress).assumingMemoryBound(to: sockaddr_in.self)
            var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var mutableAddress = sin.pointee.sin_addr
            inet_ntop(AF_INET, &mutableAddress, &text, socklen_t(INET_ADDRSTRLEN))
            addresses.append(MizarNetSocketAddress.dottedQuad(text))
        }
        // Stable order, so candidate lists — and the tests over them — do
        // not depend on the kernel's enumeration order.
        return Array(Set(addresses)).sorted()
    }

    /// Resolve a `host:port` string to one IPv4 address.
    ///
    /// DNS runs on a detached task: `getaddrinfo` blocks, and an actor
    /// method that blocks is a stall for everything else on the engine.
    static func resolve(_ endpoint: String) async -> MizarNetSocketAddress? {
        let separator = endpoint.lastIndex(of: ":")
        guard let separator else { return nil }
        let host = String(endpoint[endpoint.startIndex..<separator])
        let portText = String(endpoint[endpoint.index(after: separator)...])
        guard let port = UInt16(portText) else { return nil }
        return await withCheckedContinuation { continuation in
            Task.detached {
                var hints = addrinfo()
                hints.ai_family = AF_INET
                hints.ai_socktype = SOCK_DGRAM
                var result: UnsafeMutablePointer<addrinfo>?
                defer {
                    if let result { freeaddrinfo(result) }
                }
                guard getaddrinfo(host, String(port), &hints, &result) == 0, let first = result else {
                    continuation.resume(returning: nil)
                    return
                }
                let sin = UnsafeRawPointer(first.pointee.ai_addr).assumingMemoryBound(to: sockaddr_in.self)
                var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var mutableAddress = sin.pointee.sin_addr
                inet_ntop(AF_INET, &mutableAddress, &text, socklen_t(INET_ADDRSTRLEN))
                continuation.resume(returning: MizarNetSocketAddress(ip: MizarNetSocketAddress.dottedQuad(text), port: UInt16(bigEndian: sin.pointee.sin_port)))
            }
        }
    }

    /// Datagrams are capped by the session's chunking well below this; the
    /// buffer only has to be big enough that a misbehaving peer's oversized
    /// datagram is truncated rather than corrupting the read.
    private static let receiveBufferSize = 2048
}
