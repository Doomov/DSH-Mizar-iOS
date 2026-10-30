//
//  MizarStarSnapshotTests.swift
//  DSH-MizarTests
//
//  The mark, in the poses the app actually draws.
//
//  This is the cheapest possible snapshot: pure geometry with no environment
//  dependency, so it is also the harness's own smoke test — if these references
//  stop matching, the renderer or the runtime moved, not the mark.
//
//  The animation itself cannot be pinned here: `running` is a repeating keyframe
//  animator no render transaction stops, and `accessibilityReduceMotion` is a
//  get-only environment key the harness cannot set. What is pinned is what the
//  app draws while the animation is not allowed to run, plus the two ends of the
//  progress reading — which is where a shape change would show up first.
//

import SwiftUI
import Testing
@testable import DSH_Mizar

@MainActor
struct MizarStarSnapshotTests {
    /// The poses a screen can hold still: the icon, a download half arrived, and
    /// the 56-point size the refresh sheet draws.
    enum Pose: String, CaseIterable, Sendable {
        case icon
        case openingHalf
        case inkOnNavy
        case darkRunning

        @ViewBuilder var view: some View {
            switch self {
            case .icon:
                MizarStar(motion: .still, size: 68)
            case .openingHalf:
                MizarStar(motion: .opening(0.5), size: 68)
            case .inkOnNavy:
                MizarStar(motion: .still, size: 68, palette: .ink(.white))
                    .background(Color(red: 19 / 255, green: 31 / 255, blue: 61 / 255))
            case .darkRunning:
                // The same mark, in Dark Mode, with no palette named: the ink
                // follows the appearance, so this must come out white. Pinned
                // on black because a white star on the harness's white ground
                // would pass by being invisible.
                ZStack {
                    Color.black
                    MizarStar(motion: .still, size: 68)
                }
                .environment(\.colorScheme, .dark)
            }
        }

        var size: CGSize {
            switch self {
            case .icon, .openingHalf, .inkOnNavy, .darkRunning: CGSize(width: 68, height: 68)
            }
        }
    }

    @Test(arguments: Pose.allCases)
    func mizarStar(_ pose: Pose) throws {
        let snapshot = try SnapshotHarness.assertSnapshot(
            of: pose.view,
            named: "MizarStar-\(pose.rawValue)",
            size: pose.size,
        )

        // The mark's own box, exactly: a changed aspect ratio must not be
        // absorbed by the tolerance.
        #expect(snapshot.pixelWidth == 136)
        #expect(snapshot.pixelHeight == 136)
        #expect(snapshot.recorded == SnapshotHarness.isRecording)
    }

    /// The app icon's own composition: the mark on its tile.
    @Test
    func mizarIconTile() throws {
        let snapshot = try SnapshotHarness.assertSnapshot(
            of: MizarIconTile(size: 64, motion: .still),
            named: "MizarIconTile",
            size: CGSize(width: 64, height: 64),
        )
        #expect(snapshot.pixelWidth == 128)
        #expect(snapshot.pixelHeight == 128)
    }

    /// The same tile in Dark Mode: the icon's other appearance.
    ///
    /// The asset catalog ships a black-tile icon for dark, and this is the
    /// settings page agreeing with it. A tile that stayed white here is the
    /// bug that made this reference exist.
    @Test
    func mizarIconTileDark() throws {
        let snapshot = try SnapshotHarness.assertSnapshot(
            of: MizarIconTile(size: 64, motion: .still)
                .environment(\.colorScheme, .dark),
            named: "MizarIconTile-dark",
            size: CGSize(width: 64, height: 64),
        )
        #expect(snapshot.pixelWidth == 128)
        #expect(snapshot.pixelHeight == 128)
    }
}
