//
//  LocalAgentController.swift
//  DSH-Mizar
//
//  The on-device agent: one kernel, booted when the operator picks it, and the
//  connection that makes it look like every other host.
//
//  The kernel itself is finished and shipped (see `MizarKit/Kernel/`); this is
//  the app's half -- the lifecycle of the JavaScriptCore runtime, the fact that
//  a boot failure is a state and not a crash, and the one boolean the host list
//  needs before any of that exists.
//
//  Two rules here are the feature, not implementation detail:
//
//    1. **Boot on the tap.** The kernel costs a few milliseconds (measured in
//       `LocalKernelTests`), but it is not run at launch for people who only
//       talk to a computer. Nothing is created until the local agent is picked.
//    2. **Never keep it alive in the background.** There is no keep-alive and
//       no background mode: iOS suspends the process, the JavaScript queue
//       stops with it, and the UI says so before it happens. See the plan,
//       `docs/ios-local-agent-plan-2026-10-29.md` §5.3.
//

import Foundation
import MizarKit
import UIKit

/// The kernel and the connection built on top of it.
@MainActor
@Observable
final class LocalAgentController {
    /// Where the agent is in its life, as the host list draws it.
    enum State: Equatable {
        case idle
        case starting
        case running
        case failed(String)
    }

    /// A kernel that booted and a connection that completed its handshake.
    struct Started {
        let connection: MizarConnection
        let welcome: WelcomeFrame
    }

    private(set) var state: State = .idle
    /// The runtime, kept for the life of the app once booted.
    ///
    /// Kept rather than destroyed on leaving local mode: the sessions live on
    /// disk either way, and a second entry into the mode should not pay the boot
    /// again. It costs one `JSContext` and one serial queue.
    private(set) var runtime: KernelRuntime?
    /// Whether at least one provider has an API key. Drives the red pill.
    private(set) var hasConfiguredProvider = false

    private let rootURL: URL
    private let hostName: String
    private let presence: @Sendable () -> Bool

    /// The flag behind the one-time "this stops in the background" notice.
    private static let noticeKey = "mizar.localAgent.backgroundNoticeShown"

    init(
        rootURL: URL = LocalAgentController.defaultRootURL,
        hostName: String = UIDevice.current.name,
        presence: @escaping @Sendable () -> Bool = { APIKeyPresence.hasConfiguredProvider() },
    ) {
        self.rootURL = rootURL
        self.hostName = hostName
        self.presence = presence
    }

    /// `Documents/LocalAgent`: the folder the Files app shows.
    ///
    /// The root is where the operator's workspaces live -- one folder each, the
    /// agent writing files straight into them -- so it has to be a directory
    /// iOS exposes to the Files app (`UIFileSharingEnabled` and
    /// `LSSupportsOpeningDocumentsInPlace`, both set in the Info.plist). The
    /// kernel's own bookkeeping sits one level down, in `.mizar/`, and is not a
    /// workspace. Before this, the root was in Application Support: invisible
    /// to the user, and impossible to look at without Xcode.
    nonisolated static var defaultRootURL: URL {
        let base = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true,
        )
        let directory = (base ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true))
            .appendingPathComponent("LocalAgent", isDirectory: true)
        return directory
    }

    /// What the first workspace is called when the root has none.
    static var defaultWorkspaceName: String {
        String(localized: "Default workspace")
    }

    /// Where kernels from before the move kept their data.
    ///
    /// `Application Support/LocalKernel`. Read once, to carry the sessions and
    /// the model configuration across the change of root; the workspaces those
    /// sessions pointed at are gone, and the kernel gives them the default one
    /// on the next boot (it knows a cwd outside its root when it sees one).
    static var legacyRootURL: URL {
        let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false,
        )
        return (base ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true))
            .appendingPathComponent("LocalKernel", isDirectory: true)
    }

    /// Re-read the "is a model configured?" answer.
    ///
    /// A Keychain enumeration, not a kernel call: the host list asks this every
    /// time it opens, and booting 53 KB of JavaScript to answer a boolean is the
    /// kind of cost that shows up as a stutter rather than as a bug.
    func refreshKeyPresence() {
        hasConfiguredProvider = presence()
    }

    /// Boot the kernel if it is not booted, connect, and hand back the pair.
    func start() async throws -> Started {
        state = .starting
        do {
            let runtime = try await ensureRuntime()
            let connection = MizarConnection(
                configuration: .init(
                    // A local kernel has no socket to dial; the transport
                    // ignores the address. It still has to be a well-formed
                    // one, because `MizarConnection` builds a URL from it
                    // before the transport is ever asked (`LocalKernelTests`
                    // uses the same placeholder).
                    authority: "127.0.0.1:19390",
                    token: "local",
                    appVersion: AppModel.appVersion,
                    deviceModel: AppModel.deviceModel,
                    requestTimeout: .seconds(120),
                    handshakeTimeout: .seconds(20),
                ),
                makeTransport: { LocalKernelTransport(runtime: runtime) },
            )
            let welcome = try await connection.connect()
            state = .running
            refreshKeyPresence()
            return Started(connection: connection, welcome: welcome)
        } catch {
            let message = Self.describe(error)
            state = .failed(message)
            throw error
        }
    }

    /// The connection is gone; the kernel is not.
    func stop() {
        if state != .idle { state = .idle }
    }

    /// A second connection, for configuration rather than conversation.
    ///
    /// The kernel serves several clients and the app has exactly one connection
    /// -- which belongs to whichever host is open, and may not be this one. A
    /// settings screen that asked "which providers are configured?" by borrowing
    /// it would either fail when the local agent is not the current host or tear
    /// down a session to ask. So it opens its own, and closes it when it is done.
    func adminConnection() async throws -> MizarConnection {
        let runtime = try await ensureRuntime()
        let connection = MizarConnection(
            configuration: .init(
                authority: "127.0.0.1:19390",
                token: "local",
                appVersion: AppModel.appVersion,
                deviceModel: AppModel.deviceModel,
                requestTimeout: .seconds(30),
                handshakeTimeout: .seconds(20),
            ),
            makeTransport: { LocalKernelTransport(runtime: runtime) },
        )
        _ = try await connection.connect()
        return connection
    }

    /// Throw the kernel away. Only the memory warning path and tests use this.
    func shutdown() {
        runtime = nil
        state = .idle
    }

    /// Delete the agent's sessions, keeping the model configuration and the workspaces.
    ///
    /// Sessions are the agent's own bookkeeping. The workspace folders are the
    /// operator's files -- they can see them in the Files app, put their own
    /// files in them, and would not expect a button in Settings to delete them.
    /// What it is configured to call lives in `.mizar/config.json` and the
    /// Keychain, and an operator who is short of space has no reason to type
    /// their provider back in. The runtime is dropped rather than left holding
    /// the sessions it just lost, so the next entry reads the empty directory.
    func clearData() throws {
        let sessions = rootURL.appendingPathComponent(".mizar/sessions", isDirectory: true)
        if FileManager.default.fileExists(atPath: sessions.path) {
            try FileManager.default.removeItem(at: sessions)
        }
        shutdown()
    }

    /// Carry a pre-Files-app install's sessions and configuration into the new root.
    ///
    /// Runs before the first boot in the new location. Best effort: a failure
    /// leaves the old data where it was, which is invisible but harmless, and
    /// the agent simply starts empty.
    func migrateFromLegacyRootIfNeeded() {
        let fileManager = FileManager.default
        let legacy = Self.legacyRootURL
        guard fileManager.fileExists(atPath: legacy.path) else { return }
        let data = rootURL.appendingPathComponent(".mizar", isDirectory: true)
        let newSessions = data.appendingPathComponent("sessions", isDirectory: true)
        guard !fileManager.fileExists(atPath: newSessions.path) else { return }
        do {
            try fileManager.createDirectory(at: data, withIntermediateDirectories: true)
            let oldSessions = legacy.appendingPathComponent("sessions", isDirectory: true)
            if fileManager.fileExists(atPath: oldSessions.path) {
                try fileManager.moveItem(at: oldSessions, to: newSessions)
            }
            let oldConfig = legacy.appendingPathComponent("config.json")
            let newConfig = data.appendingPathComponent("config.json")
            if fileManager.fileExists(atPath: oldConfig.path),
               !fileManager.fileExists(atPath: newConfig.path) {
                try fileManager.moveItem(at: oldConfig, to: newConfig)
            }
        } catch {
            // Reported, not fatal: the agent works without the old data.
            state = .failed(error.localizedDescription)
        }
    }

    /// How much is on disk, for the row's subtitle. `nil` when nothing is.
    var storedByteCount: Int64? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL.appendingPathComponent(".mizar", isDirectory: true),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
        ) else { return nil }
        var total: Int64 = 0
        var sawFile = false
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
            sawFile = true
        }
        return sawFile ? total : nil
    }

    // MARK: - The background notice

    /// Whether the operator has been told the agent stops in the background.
    var hasShownBackgroundNotice: Bool {
        UserDefaults.standard.bool(forKey: Self.noticeKey)
    }

    /// Remember that the notice was shown.
    func noteBackgroundNoticeShown() {
        UserDefaults.standard.set(true, forKey: Self.noticeKey)
    }

    /// For tests and the "clear local data" button.
    func forgetBackgroundNotice() {
        UserDefaults.standard.removeObject(forKey: Self.noticeKey)
    }

    // MARK: - Boot

    private func ensureRuntime() async throws -> KernelRuntime {
        if let runtime { return runtime }
        migrateFromLegacyRootIfNeeded()
        let runtime = KernelRuntime(
            rootURL: rootURL,
            hostName: hostName,
            defaultWorkspaceName: Self.defaultWorkspaceName,
        )
        try await runtime.boot()
        self.runtime = runtime
        return runtime
    }

    /// A sentence for the row's failure state.
    static func describe(_ error: any Error) -> String {
        if let error = error as? MizarError { return error.message }
        if let error = error as? KernelRuntime.RuntimeError { return error.message }
        return (error as NSError).localizedDescription
    }
}
