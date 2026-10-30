//
//  StarMotionTests.swift
//  DSH-MizarTests
//
//  The two motions, as arithmetic.
//
//  The animations themselves cannot be asserted on: a repeating keyframe
//  animator is not something a test can step frame by frame, and the poses it
//  goes through are transient. What *can* be pinned is the part that is a
//  decision rather than an effect -- the numbers, the easing, and the fact that
//  both motions come to rest exactly on the icon's pose. Those are the four
//  things a future edit would break silently: a flick that ends two degrees off
//  looks like a rendering bug, and a breath that is nine seconds long looks
//  like a still image.
//
//  The shape is pinned the same way: its bounding box, not its pixels (the
//  snapshot suite owns those), so a regenerated path that is rotated or scaled
//  wrong fails here first and says which.
//

import SwiftUI
import Testing
@testable import DSH_Mizar

@MainActor
struct StarMotionTests {
    // MARK: The shape

    @Test("the layer is drawn around the icon's own centre")
    func geometry() {
        let box = StarGeometry.path().boundingRect

        // The path is *one* three-armed layer, and that layer is deliberately
        // not centred in its box: its arms point up, down-left and down-right,
        // so the box runs from the top tip to the two lower ones. What has to
        // sit on the centre is the point the layers turn about -- the icon's
        // centre -- and the tip radius has to be the icon's.
        let centre = CGPoint(x: 0.5, y: 0.5)
        // The top tip is a curve endpoint, so its coordinate is exact even
        // though `boundingRect` also counts control points.
        #expect(abs((centre.y - box.minY) - StarMetrics.tipFraction) < 0.002)
        // Symmetric left to right, because one arm points straight up.
        #expect(abs(box.midX - centre.x) < 0.002)
        // The two lower tips sit half a radius below the centre and half a
        // radius out to each side, so the box is wider than it is tall by
        // 2/sqrt(3). A ratio rather than two absolutes, because
        // `Path.boundingRect` is the control-point box: the curves stay inside
        // it by the same few hundredths on both axes.
        #expect(abs(box.width / box.height - 2 / sqrt(3)) < 0.01)
    }

    @Test("the two layers together are the six-armed icon")
    func composite() {
        // The icon is the layer and its sixty-degree turn. That union is
        // symmetric about both axes and fills the design box the icon was drawn
        // in -- which is the check that the offset applied by ``MizarStar`` is
        // the same sixty degrees the icon was drawn with.
        let layer = StarGeometry.path()
        let back = layer.applying(
            CGAffineTransform(translationX: 0.5, y: 0.5)
                .rotated(by: .pi / 3)
                .translatedBy(x: -0.5, y: -0.5),
        )
        let union = layer.union(back).boundingRect
        // Centred on both axes, which the single layer is not: the union has
        // tips straight up and straight down.
        #expect(abs(union.midX - 0.5) < 0.02)
        #expect(abs(union.midY - 0.5) < 0.02)
        // And taller than it is wide, by the same 2/sqrt(3): six tips, two of
        // them vertical.
        #expect(abs(union.height / union.width - 2 / sqrt(3)) < 0.02)
    }

    @Test("the back layer is the front one, sixty degrees along")
    func layerOffset() {
        // Not a tunable: 60 is what makes three arms into the icon's six. A
        // value that is not a multiple of the layer's own 120-degree symmetry
        // would leave the resting mark looking like a mistake.
        #expect(StarGeometry.backOffset == 60)
    }

    // MARK: The easing

    @Test("the flick starts and ends at rest")
    func easingEnds() {
        #expect(StarMetrics.eased(0) == 0)
        #expect(StarMetrics.eased(1) == 1)
        #expect(abs(StarMetrics.eased(0.5) - 0.5) < 1e-9)

        // Zero speed at both ends: the first and last thousandth of the throw
        // move less than a hundredth of a percent of it. That is what keeps a
        // 480-degree spin from snatching at the start and from stopping dead at
        // the end.
        for edge in [(0.0, 0.001), (0.999, 1.0)] {
            let travelled = StarMetrics.eased(edge.1) - StarMetrics.eased(edge.0)
            #expect(travelled < 0.0001, "a flick that starts or stops with speed: \(travelled)")
        }
    }

    @Test("the easing never goes backwards")
    func easingMonotonic() {
        var previous = 0.0
        for step in 0...1000 {
            let value = StarMetrics.eased(Double(step) / 1000)
            #expect(value >= previous)
            previous = value
        }
        // And it clamps rather than extrapolating, so a frame that arrives late
        // lands on the final pose instead of past it.
        #expect(StarMetrics.eased(-1) == 0)
        #expect(StarMetrics.eased(2) == 1)
    }

    // MARK: The running loop

    @Test("one breath is a sixth of a revolution")
    func breath() {
        // The silhouette returns when each layer has turned 120 degrees -- the
        // layer's own three-fold symmetry -- so a nine-second revolution
        // breathes every 1.5 seconds. Stated separately from the constant
        // because this is the number a person actually sees.
        #expect(StarMetrics.breath == StarMetrics.revolution / 6)
        #expect(StarMetrics.breath == 1.5)
    }

    // MARK: The flick

    @Test("both layers come to rest on the icon's pose")
    func flickLandsUpright() {
        // The last frame, computed the way the view computes it.
        let seconds = StarMetrics.flickWindow
        let front = StarMetrics.flickFrontDegrees
            * StarMetrics.eased(seconds / StarMetrics.flickFrontSeconds)
        let back = StarMetrics.flickBackDegrees
            * StarMetrics.eased((seconds - StarMetrics.flickBackDelay) / StarMetrics.flickBackSeconds)

        #expect(abs(front - StarMetrics.flickFrontDegrees) < 1e-9)
        #expect(abs(back - StarMetrics.flickBackDegrees) < 1e-9)

        // The pose is the icon's when both angles are multiples of the layer's
        // 120-degree symmetry, which is why the degrees above were chosen as
        // four and five turns of it.
        #expect(front.truncatingRemainder(dividingBy: 120) == 0)
        #expect(back.truncatingRemainder(dividingBy: 120) == 0)
    }

    @Test("the layers are not in step")
    func flickLayersDiffer() {
        // Two layers that start together, turn together and stop together read
        // as one rigid object being rotated. The difference is the motion: the
        // back layer travels further and takes longer, so the mark settles in
        // two stages.
        #expect(abs(StarMetrics.flickBackDegrees) > abs(StarMetrics.flickFrontDegrees))
        #expect(StarMetrics.flickBackSeconds > StarMetrics.flickFrontSeconds)
        #expect(StarMetrics.flickBackDelay > 0)

        let frontSpeed = abs(StarMetrics.flickFrontDegrees) / StarMetrics.flickFrontSeconds
        let backSpeed = abs(StarMetrics.flickBackDegrees) / StarMetrics.flickBackSeconds
        #expect(abs(frontSpeed - backSpeed) > 20, "the layers turn at the same average speed")
    }

    @Test("the flick's window covers both layers")
    func flickWindow() {
        #expect(StarMetrics.flickWindow >= StarMetrics.flickFrontSeconds)
        #expect(StarMetrics.flickWindow >= StarMetrics.flickBackDelay + StarMetrics.flickBackSeconds)
        // Short enough to be a gesture rather than a wait: anything past about
        // two seconds stops reading as a flick and starts reading as an
        // animation the operator has to sit through.
        #expect(StarMetrics.flickWindow < 2)
    }

    // MARK: The progress reading

    @Test("opening the mark is the icon being assembled")
    func opening() {
        // `0` puts the two layers on top of each other -- the three-armed star
        // -- and `1` is the icon's sixty degrees. A download that ends at the
        // icon is the whole point of the reading.
        #expect(StarGeometry.backOffset * (0 - 1) == -60)
        #expect(StarGeometry.backOffset * (1 - 1) == 0)
    }
}
