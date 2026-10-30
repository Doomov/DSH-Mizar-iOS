//
//  StarSpin.swift
//  DSH-Mizar
//
//  The mark, turning against itself.
//
//  "Running" is already drawn by `TwinStar` -- two dots, one going round the
//  other. This is the same idea with the app's own star, for the two places the
//  mark itself should carry the motion: the launch screen, and a session row
//  once the icon ships.
//
//  Two identical layers turning opposite ways do not read as one rotation: the
//  silhouette is symmetric, so the eye gets a bloom opening and closing. The
//  back layer is therefore dimmer, a little larger and softened -- the bright
//  star is what the eye follows, and the faint one is the counter-motion behind
//  it. At equal weight the two layers cancel into a pulse.
//
//  The endless loop is linear on purpose: an eased spinner looks like it is
//  stuttering once a second. The flick is the opposite -- one throw, fastest at
//  the start, coming to rest. Its angle is `1 - e^(-k p)`, the curve of
//  something pushed and slowed by friction, evaluated from a linearly animated
//  progress so the deceleration is exact at any frame rate.
//

import Foundation
import SwiftUI

/// The app's star mark, turning.
///
/// Two modes: `running` for an endless indicator, `flick` for a splash or a
/// transition that plays once and settles upright.
struct StarSpin: View {
    /// What the star is doing.
    enum Motion {
        /// Endless, one revolution every ``period`` seconds: a session working.
        case running
        /// One throw, then still.
        case flick
    }

    /// What it is doing.
    var motion: Motion = .running
    /// The diameter of the figure, in points.
    var size: CGFloat = 64
    /// Seconds for one revolution of each layer while running.
    ///
    /// The visible bloom repeats every `period / 12`, because six arms mean a
    /// 30-degree turn of each layer puts the two back where they started. A
    /// dozen seconds is therefore a one-second pulse; much below that and the
    /// mark shimmers rather than breathes.
    var period: Double = 12
    /// Degrees each layer turns during a flick. A multiple of 360 ends upright.
    var flickDegrees: Double = 360
    /// Seconds a flick takes.
    var flickDuration: Double = 1.15
    /// How hard the flick brakes. 4 glides for a long time; 8 stops quickly.
    var flickSharpness: Double = 5
    /// The mark itself. A parameter so the asset can change without this view.
    var mark: Image = Image("StarMark")

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.drawersStill) private var drawersStill
    @State private var progress: Double = 0

    var body: some View {
        Group {
            switch motion {
            case .running:
                running
            case .flick:
                flick
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - Running

    /// The endless loop, or the star parked when motion is not allowed.
    ///
    /// Parked at 24 degrees rather than at zero: two layers exactly on top of
    /// each other are the plain icon, and the point of the glyph is that there
    /// are two. The jump back to the loop's zero is the same small jump
    /// ``TwinStar`` makes when a drawer settles.
    @ViewBuilder private var running: some View {
        if reduceMotion || !drawersStill {
            StarPair(mark: mark, size: size, angle: 24)
        } else {
            StarPair(mark: mark, size: size, angle: 0)
                .keyframeAnimator(initialValue: 0.0, repeating: true) { _, angle in
                    StarPair(mark: mark, size: size, angle: angle)
                } keyframes: { _ in
                    LinearKeyframe(360, duration: period)
                }
        }
    }

    // MARK: - Flick

    /// One throw, from rest to rest.
    ///
    /// `progress` is animated linearly; the angle comes from ``Flick/spin(_:)``.
    /// Reduce Motion keeps the last frame -- the star upright -- rather than
    /// playing the throw.
    private var flick: some View {
        Flick(
            progress: reduceMotion ? 1 : progress,
            degrees: flickDegrees,
            sharpness: flickSharpness,
            size: size,
            mark: mark,
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: flickDuration)) { progress = 1 }
        }
    }
}

// MARK: - The layers

/// The two stars at one angle: the companion behind, the mark in front.
private struct StarPair: View {
    let mark: Image
    let size: CGFloat
    let angle: Double

    var body: some View {
        ZStack {
            // The companion. Dim, larger by a hair, and softened: enough that
            // the counter-rotation is legible, not enough to compete with the
            // bright star in front.
            mark
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .opacity(0.45)
                .scaleEffect(1.05)
                // No blur at indicator sizes: the radius would be a twentieth
                // of a point, and the offscreen pass would still be paid for
                // on every row that is running.
                .blur(radius: size >= 32 ? size * 0.005 : 0)
                .rotationEffect(.degrees(-angle))
            mark
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .rotationEffect(.degrees(angle))
        }
        .frame(width: size, height: size)
    }
}

/// The flick, as an animatable progress.
///
/// One `Double` is interpolated by SwiftUI; the body turns it into the eased
/// angle. Keeping the easing here rather than in a Bézier timing curve is what
/// makes it a true exponential glide, and lets the last frame land exactly on
/// `degrees`.
private struct Flick: View, Animatable {
    var progress: Double
    let degrees: Double
    let sharpness: Double
    let size: CGFloat
    let mark: Image

    /// `nonisolated` because ``Animatable`` is not a main-actor protocol: the
    /// animation engine reads and writes this value from wherever it runs, and
    /// `Flick` is a value type, so there is no shared state to protect.
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        StarPair(mark: mark, size: size, angle: spin(progress) * degrees)
    }

    /// The fraction of the turn completed at linear time `progress`.
    ///
    /// `1 - e^(-k p)` is the distance travelled by something given a push and
    /// slowed by a force proportional to its speed: the angle grows quickly at
    /// first and the last degrees take a long time. Normalised so that
    /// `spin(1) == 1` -- the star stops exactly upright instead of a fraction
    /// of a degree short.
    ///
    /// - Parameter progress: linear time, 0 to 1.
    /// - Returns: the fraction of `degrees` turned, 0 to 1.
    private func spin(_ progress: Double) -> Double {
        let p = min(max(progress, 0), 1)
        return (1 - exp(-sharpness * p)) / (1 - exp(-sharpness))
    }
}

#Preview("Running and flick") {
    VStack(spacing: 36) {
        HStack(spacing: 28) {
            StarSpin(motion: .running, size: 18, period: 6)
            StarSpin(motion: .running, size: 28)
            StarSpin(motion: .running, size: 56, period: 10)
        }
        StarSpin(motion: .flick, size: 140)
    }
    .padding(48)
    .background(.black)
}
