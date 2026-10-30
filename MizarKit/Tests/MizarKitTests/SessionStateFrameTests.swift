//
//  SessionStateFrameTests.swift
//  MizarKitTests
//
//  The Swift half of the state channel, pinned to the same bytes the Rust suite
//  decodes (`protocol/fixtures/state-frames.json`). A drift in either encoder
//  fails here or there — never on a device.
//

import Foundation
import Testing
@testable import MizarKit

private struct WireFixture: Codable {
    struct Case: Codable {
        let name: String
        let hex: String
        let state: UInt8
        let interval: UInt32
        let textSeq: UInt32
        let flags: UInt8
        let text: String
    }
    let frames: [Case]
}

private var fixtureURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // MizarKitTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // MizarKit
        .deletingLastPathComponent()  // repository root
        .appendingPathComponent("protocol/fixtures/state-frames.json")
}

private func loadWireFixture() throws -> WireFixture {
    try JSONDecoder().decode(WireFixture.self, from: Data(contentsOf: fixtureURL))
}

private func bytes(fromHex hex: String) -> Data {
    var out = Data(capacity: hex.count / 2)
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        out.append(UInt8(hex[index..<next], radix: 16)!)
        index = next
    }
    return out
}

@Suite("State channel wire format")
struct SessionStateFrameTests {
    @Test("every fixture frame decodes and re-encodes to the same bytes")
    func fixtureRoundTrips() throws {
        let cases = try loadWireFixture().frames
        #expect(cases.count >= 8)
        for testCase in cases {
            let raw = bytes(fromHex: testCase.hex)
            let frame = try StateFrame(decoding: raw)
            #expect(frame.state.code == testCase.state, "\(testCase.name): state")
            #expect(frame.interval == testCase.interval, "\(testCase.name): interval")
            #expect(frame.textSeq == testCase.textSeq, "\(testCase.name): text seq")
            #expect(frame.flags.rawValue == testCase.flags, "\(testCase.name): flags")
            #expect(frame.text == testCase.text, "\(testCase.name): text")
            #expect(frame.encoded() == raw, "\(testCase.name): re-encode")
        }
    }

    @Test("a malformed frame is refused, not guessed at")
    func malformedFramesAreRefused() {
        #expect(throws: StateFrameError.truncated) {
            _ = try StateFrame(decoding: Data([StateFrame.magic, 1]))
        }
        #expect(throws: StateFrameError.notAStateFrame) {
            _ = try StateFrame(decoding: Data(repeating: 0x7B, count: 13))
        }
        var unknown = Data(repeating: 0, count: 13)
        unknown[0] = StateFrame.magic
        unknown[1] = 200
        #expect(throws: StateFrameError.unknownState(200)) {
            _ = try StateFrame(decoding: unknown)
        }
    }

    @Test("the receiver follows intervals and appends text")
    func channelFollowsIntervals() {
        var channel = StateChannel()
        let start = Date(timeIntervalSince1970: 1_760_000_000)

        let began = channel.apply(
            StateFrame(state: .streamFinal, interval: 1, flags: [.snapshot, .append], text: "第一段"),
            at: start,
        )
        #expect(began == .began)
        #expect(channel.state == .streamFinal)
        #expect(channel.text == "第一段")

        let updated = channel.apply(
            StateFrame(state: .streamFinal, interval: 1, textSeq: 9, flags: [.append], text: "第二段"),
            at: start.addingTimeInterval(1),
        )
        #expect(updated == .updated)
        #expect(channel.text == "第一段第二段")

        // An older interval changes nothing.
        let stale = channel.apply(StateFrame(state: .idle, interval: 0, flags: []), at: start)
        #expect(stale == .stale)
        #expect(channel.state == .streamFinal)
    }

    @Test("a held state ages out; a terminal one does not")
    func staleness() {
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        var held = StateChannel()
        held.apply(StateFrame(state: .tool, interval: 1, flags: []), at: start)
        #expect(!held.isStale(at: start.addingTimeInterval(StateChannel.staleAfter)))

        var done = StateChannel()
        done.apply(StateFrame(state: .completed, interval: 2, flags: []), at: start)
        #expect(!done.isStale(at: start.addingTimeInterval(600)))
    }

    @Test("a heartbeat is thirteen bytes and carries nothing")
    func heartbeatIsTiny() {
        let frame = StateFrame(state: .thinking, interval: 3, flags: [.heartbeat])
        #expect(frame.encoded().count == StateFrame.headerLength)
        #expect(frame.encoded()[0] == StateFrame.magic)
    }
}
