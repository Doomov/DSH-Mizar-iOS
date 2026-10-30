//
//  LiveTurnBlockSnapshotTests.swift
//  DSH-MizarTests
//
//  The running-turn line: one state, two categories, the frozen heading with an
//  answer under it. The wording rules are DSH's, so the snapshots pin what a
//  phone and a desktop would both say about the same turn.
//

import MizarKit
import SwiftUI
import Testing
@testable import DSH_Mizar

@MainActor
struct LiveTurnBlockSnapshotTests {
    enum Variant: String, CaseIterable, Sendable {
        case working
        case two
        case frozenWithAnswer
    }

    private func block(_ variant: Variant) -> some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)
            switch variant {
            case .working:
                LiveTurnBlock(running: .thinking, done: [], text: "")
            case .two:
                LiveTurnBlock(running: .tools, done: [.thinking], text: "")
            case .frozenWithAnswer:
                LiveTurnBlock(
                    running: nil,
                    done: [.thinking, .commands],
                    text: "三处都改完了，测试全绿。",
                )
            }
        }
        .frame(width: 360, height: 120)
    }

    @Test(arguments: Variant.allCases)
    func liveTurnBlock(_ variant: Variant) throws {
        try SnapshotHarness.assertSnapshot(
            of: block(variant),
            named: "live-turn-block-\(variant.rawValue)",
            size: CGSize(width: 360, height: 120),
        )
    }
}
