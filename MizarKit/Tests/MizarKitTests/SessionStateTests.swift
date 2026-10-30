//
//  SessionStateTests.swift
//  MizarKitTests
//
//  The state table is generated, but generated is not the same as correct.
//  These tests pin three properties that a hand-edit or a bad regeneration would
//  silently break:
//
//  - every generated code decodes to the text the fixture says;
//  - an unknown code is `.unknown`, never a crash and never a wrong state;
//  - `SessionStateFrame` reads epoch milliseconds, not seconds.
//

import Foundation
import Testing
@testable import MizarKit

/// The generated fixture, shared with the Rust suite.
private struct StateFixture: Codable {
    struct Entry: Codable {
        let code: UInt8
        let id: String
        let text: String
        let english: String
        let tone: String
    }
    let version: Int
    let states: [Entry]
}

private var fixtureURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // MizarKitTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // MizarKit
        .deletingLastPathComponent()  // repository root
        .appendingPathComponent("protocol/fixtures/session-state.json")
}

private func loadStates() throws -> StateFixture {
    let data = try Data(contentsOf: fixtureURL)
    return try JSONDecoder().decode(StateFixture.self, from: data)
}

@Suite("Session states")
struct SessionStateTests {
    @Test("every fixture code decodes to its own text")
    func codesMatchTheFixture() throws {
        let fixture = try loadStates()
        #expect(fixture.states.count >= 12)
        for entry in fixture.states {
            let state = SessionState(code: entry.code)
            #expect(state != .unknown, "code \(entry.code) (\(entry.id)) is unknown to this build")
            #expect(state.text == entry.text, "code \(entry.code) text")
            #expect(state.english == entry.english, "code \(entry.code) english")
            #expect(state.tone.rawValue == entry.tone, "code \(entry.code) tone")
        }
    }

    @Test("the person-facing text is never empty")
    func everyStateSpeaks() {
        for state in SessionState.allCases where state != .unknown {
            #expect(!state.text.isEmpty, "\(state)")
            #expect(!state.detail.isEmpty, "\(state)")
        }
    }

    @Test("an unknown code is inert, not fatal")
    func unknownCodesAreSurvivable() throws {
        #expect(SessionState(code: 200) == .unknown)
        #expect(SessionState(code: 99) == .unknown)
        #expect(SessionState.unknown.text.isEmpty)
        #expect(SessionState.unknown.tone == .neutral)

        // Decoding through the wire representation behaves the same way.
        let decoded = try JSONDecoder().decode(SessionState.self, from: Data("200".utf8))
        #expect(decoded == .unknown)
    }

    @Test("a frame reads its clock as milliseconds")
    func framesUseMilliseconds() throws {
        let json = #"{"st":4,"at":1761728400000,"turn":12}"#
        let frame = try JSONDecoder().decode(SessionStateFrame.self, from: Data(json.utf8))
        #expect(frame.state == .awaitingUser)
        // 2025-10-29T... would be 1.7e9 seconds; milliseconds land here.
        #expect(frame.at.timeIntervalSince1970 > 1_700_000_000)
        #expect(frame.turn == 12)

        let round = try JSONEncoder().encode(frame)
        let back = try JSONDecoder().decode(SessionStateFrame.self, from: round)
        #expect(back == frame)
    }

    @Test("busy states are the ones worth animating")
    func busyStates() {
        #expect(SessionState.thinking.isBusy)
        #expect(SessionState.tool.isBusy)
        #expect(!SessionState.completed.isBusy)
        #expect(!SessionState.awaitingUser.isBusy)
    }
}
