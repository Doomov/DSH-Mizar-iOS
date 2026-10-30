//
//  MizarStar.swift
//  DSH-Mizar
//
//  The app's mark: two three-armed stars, sixty degrees apart, one behind the
//  other -- and the two ways it moves.
//
//  The shape is the owner's icon, not a drawing of it. It is measured off the
//  reference layer into a radius profile in `scripts/make-star-geometry.py` --
//  three pointed arms and the notch between them -- and that profile becomes
//  the Swift `Path` in `StarGeometry+Generated.swift`, so the phone, the Live
//  Activity and the Mac are the same mark by construction rather than by eye.
//
//  Two things about it are not negotiable. The notch is not a circle: it keeps
//  falling to 0.247 of the tip, which is what makes the arms read as pointed
//  stars rather than a ball with arms. And the layers are flat colours: a
//  gradient that lights the middle paints that core as a disc, which is the
//  same ball by another route.
//
//  ### Why two layers rather than one picture
//
//  Because the icon is two stars, and that is what makes it possible to move it
//  as if it had depth. The back star is the front one turned sixty degrees and
//  a step darker; turning them apart closes the six arms into three and opens
//  them again, which is a breath rather than a spin. A single flattened image
//  can only be rotated, and a rotation of the icon on its own reads as a
//  loading spinner that happens to be a star.
//
//  ### The two motions
//
//  `running` is for waiting: each layer turns once every nine seconds, in
//  opposite directions, at the same speed. The silhouette then reaches the full
//  six arms every 1.5 seconds -- one breath -- which is calm enough to watch for
//  a minute and slow enough to read as alive rather than busy. It loops
//  linearly: an eased loop stutters once a period, and the eye finds that
//  immediately.
//
//  `flick` is for arriving: both layers start from rest, accelerate, and come
//  to rest again, in opposite directions and at different speeds -- +480
//  degrees in 1 second in front, -600 in 1.55 behind, a hair late. It is the
//  gesture of somebody nudging both layers with a thumb, and it ends exactly on
//  the icon's pose, so a flick can play over a screen whose star is the icon.
//
//  Both are built on `smootherstep`, which starts and ends with zero speed and
//  zero acceleration: a flick that stops abruptly reads as a stutter, and one
//  that eases in reads as a motor starting.
//
//  Reduce Motion: `running` parks at the icon's pose, `flick` shows its last
//  frame, and `opening` still moves -- that one is a progress reading, not
//  decoration, and hiding it would hide the progress.
//

import SwiftUI

// MARK: - Geometry

/// The three-armed layer, scaled into whatever square it is given.
///
/// The generated path is a `0...1` box, so the shape is one affine transform
/// away from any size and stays exact at 14 points as at 92.
struct MizarStarLayer: Shape {
    /// Whether the shape is drawn mirrored. Never used by the mark itself; kept
    /// out of the API on purpose so the two layers cannot drift apart.
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let inset = CGPoint(x: (rect.width - side) / 2, y: (rect.height - side) / 2)
        let scaled = StarGeometry.path().applying(
            CGAffineTransform(scaleX: side, y: side),
        )
        return scaled.offsetBy(dx: inset.x, dy: inset.y)
    }
}

// MARK: - Palette

/// What the two layers are painted in.
///
/// Three flat colours, never a gradient. A radial gradient that lights the
/// middle paints the layer's core as a bright disc over the darker back layer,
/// and the mark then reads as a ball with arms on it -- the one thing the shape
/// must not be. The depth is the back layer's tone alone, which is the icon's
/// own recipe (`icon-design/brief.md`: background, star, one step darker).
struct MizarStarPalette: Sendable {
    /// The front layer's colour.
    var front: Color
    /// The layer behind it, one step darker.
    var back: Color

    /// The icon's own colours: the flat pair the vector master uses.
    static let brand = MizarStarPalette(
        front: Color(red: 10 / 255, green: 120 / 255, blue: 174 / 255),
        back: Color(red: 8 / 255, green: 96 / 255, blue: 139 / 255),
    )

    /// One colour, with the back layer dimmed the way the icon's shade does it.
    ///
    /// - Parameter color: the ink, usually white on the navy screens.
    /// - Returns: a palette that reads as one material at two depths.
    static func ink(_ color: Color) -> MizarStarPalette {
        MizarStarPalette(front: color, back: color.opacity(0.55))
    }

    /// What a bare mark is drawn in, in a given appearance.
    ///
    /// The icon has two appearances -- a blue star on white, a white star on
    /// black -- and a mark that is not on a tile follows the same rule: the
    /// blue one disappears into a dark screen, so Dark Mode draws it in the ink
    /// the dark icon uses, which is white.
    ///
    /// - Parameter scheme: the appearance the mark is drawn in.
    /// - Returns: the default palette for a mark that did not name one.
    static func automatic(for scheme: ColorScheme) -> MizarStarPalette {
        scheme == .dark ? .ink(.white) : .brand
    }

    /// The front layer's fill.
    var frontFill: AnyShapeStyle { AnyShapeStyle(front) }

    /// The back layer's fill.
    var backFill: AnyShapeStyle { AnyShapeStyle(back) }
}

// MARK: - Motion numbers

/// The mark's motion, as numbers worth arguing about in one place.
enum StarMetrics {
    /// How far the star's arms reach, as a fraction of the mark's width.
    ///
    /// `365 / 1024` from the icon's own design box: on a 1024 box the tips are
    /// 365 units from the centre, so the six-armed mark spans `0.144...0.856`.
    /// A single layer spans less, because its three arms do not include a
    /// downward one.
    static let tipFraction: CGFloat = 365.0 / 1024.0

    /// Seconds for one layer to turn a full revolution while running.
    ///
    /// A layer is three-fold symmetric, so the pair returns to its opening
    /// silhouette every sixth of a turn -- and that is the breath: one full
    /// six-arm star, one three-arm star, one six-arm star, every
    /// `revolution / 6` seconds, 1.5 at nine. Longer reads as breathing;
    /// shorter reads as a dial. The filmstrip used to choose it is
    /// `docs/evidence/ios-star-motion-2026-10-30.png` in the workspace.
    static let revolution: Double = 9

    /// Seconds one breath takes while running.
    static var breath: Double { revolution / 6 }

    /// What the flick turns each layer through.
    ///
    /// Both are multiples of 120 -- the layer's own symmetry -- so the flick
    /// lands on the icon's pose instead of a degree or two off it.
    static let flickFrontDegrees: Double = 480
    static let flickBackDegrees: Double = -600
    /// How long the front layer takes.
    static let flickFrontSeconds: Double = 1.0
    /// How long the back layer takes. Longer, and turning further: two layers
    /// stopping at the same instant read as one rigid object.
    static let flickBackSeconds: Double = 1.55
    /// How much later the back layer starts. A thumb cannot nudge both at once.
    static let flickBackDelay: Double = 0.035
    /// The whole throw, from the first frame to the last layer stopping.
    static var flickWindow: Double { max(flickFrontSeconds, flickBackDelay + flickBackSeconds) }

    /// The flick's easing: from rest to rest, with an eager middle.
    ///
    /// `smootherstep` has zero first *and* second derivative at both ends, so
    /// the throw starts without a jolt and settles without a stop.
    ///
    /// - Parameter progress: linear time, 0 to 1.
    /// - Returns: the fraction of the turn completed, 0 to 1.
    static func eased(_ progress: Double) -> Double {
        let p = min(max(progress, 0), 1)
        return p * p * p * (p * (p * 6 - 15) + 10)
    }
}

// MARK: - The mark

/// The app's star, at one of the four things it does.
struct MizarStar: View {
    /// What the star is doing.
    enum Motion: Equatable {
        /// The icon's pose: six arms, still.
        case still
        /// Endless: two layers turning opposite ways, breathing.
        case running
        /// One throw, then still: the icon's pose again.
        case flick
        /// A reading: `0` is the three-armed star, `1` the icon's six.
        case opening(Double)
    }

    /// What it is doing.
    var motion: Motion = .still
    /// The mark's width, in points.
    var size: CGFloat = 64
    /// What the layers are painted in, or `nil` for the appearance's own ink.
    ///
    /// Most marks name nothing and get ``MizarStarPalette/automatic(for:)``:
    /// the icon's blue on a light screen, white on a dark one. The tile names
    /// one, because it is the icon and has an icon's two appearances.
    var palette: MizarStarPalette?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.drawersStill) private var drawersStill
    /// Linear time through the flick, animated by SwiftUI.
    @State private var flickProgress: Double = 0

    var body: some View {
        Group {
            switch motion {
            case .still:
                MizarStarPose(palette: ink, size: size)
            case .running:
                running
            case .flick:
                flick
            case .opening(let fraction):
                opening(fraction)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The palette this mark is drawn in.
    private var ink: MizarStarPalette {
        palette ?? .automatic(for: colorScheme)
    }

    // MARK: Running

    /// The loop, or the icon's pose when motion is not allowed.
    ///
    /// Both branches draw the same view; only one of them moves. `360` and `0`
    /// are the same pose on a three-fold-symmetric layer, which is what makes
    /// the repeat seamless rather than a jump once every nine seconds.
    @ViewBuilder private var running: some View {
        if reduceMotion || !drawersStill {
            MizarStarPose(palette: ink, size: size)
        } else {
            MizarStarPose(palette: ink, size: size)
                .keyframeAnimator(initialValue: 0.0, repeating: true) { _, angle in
                    MizarStarPose(front: angle, back: -angle, palette: ink, size: size)
                } keyframes: { _ in
                    LinearKeyframe(360, duration: StarMetrics.revolution)
                }
        }
    }

    // MARK: Flick

    /// One throw, from rest to rest.
    private var flick: some View {
        Flick(
            progress: reduceMotion ? 1 : flickProgress,
            palette: ink,
            size: size,
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: StarMetrics.flickWindow)) { flickProgress = 1 }
        }
    }

    // MARK: Opening

    /// The two layers drawn apart by a fraction of their sixty degrees.
    ///
    /// At `0` they sit on top of each other and the mark is the three-armed
    /// star; at `1` it is the icon. A download that reads `1` at the end is
    /// therefore showing the icon being assembled, which is a better metaphor
    /// for "the history is arriving" than a bar.
    ///
    /// - Parameter fraction: how far along, 0 to 1.
    private func opening(_ fraction: Double) -> some View {
        let clamped = min(max(fraction, 0), 1)
        return MizarStarPose(
            back: StarGeometry.backOffset * (clamped - 1),
            palette: ink,
            size: size,
        )
        .animation(reduceMotion ? nil : .mizarGentle, value: clamped)
    }
}

extension MizarStar {
    /// A mark whose *ink* is a given width, rather than whose box is.
    ///
    /// The design box keeps a margin around the arms so two layers have room to
    /// part; a running indicator in a 13-point row wants the star, not the
    /// margin. Dividing by the ink's share of the box (`2 * tipFraction`, 0.712)
    /// is that conversion.
    ///
    /// - Parameters:
    ///   - diameter: how wide the drawn star should be, in points.
    ///   - motion: what it is doing. Running, almost always.
    ///   - palette: an explicit ink, or `nil` for the appearance's own.
    init(
        ink diameter: CGFloat,
        motion: Motion = .running,
        palette: MizarStarPalette? = nil,
    ) {
        self.init(
            motion: motion,
            size: diameter / (2 * StarMetrics.tipFraction),
            palette: palette,
        )
    }
}

// MARK: - The layers

/// The two stars at one pose: the back one behind, the front one over it.
///
/// `back` is an *offset* from the icon's pose, in degrees: `0` is the six-armed
/// icon, `-60` puts the two layers on top of each other.
private struct MizarStarPose: View {
    var front: Double = 0
    var back: Double = 0
    let palette: MizarStarPalette
    let size: CGFloat

    var body: some View {
        ZStack {
            MizarStarLayer()
                .fill(palette.backFill)
                .rotationEffect(.degrees(StarGeometry.backOffset + back))
            MizarStarLayer()
                .fill(palette.frontFill)
                .rotationEffect(.degrees(front))
        }
        .frame(width: size, height: size)
    }
}

/// The flick, as an animatable progress.
///
/// One `Double` is interpolated by SwiftUI and the body turns it into two
/// angles, each through its own curve and its own clock. Keeping the easing
/// here rather than in a timing curve is what lets the two layers stop at
/// different times off one animation, and it makes the last frame land exactly
/// on the icon's pose.
private struct Flick: View, Animatable {
    var progress: Double
    let palette: MizarStarPalette
    let size: CGFloat

    /// `nonisolated` because `Animatable` is not a main-actor protocol: the
    /// animation engine reads this from wherever it runs, and this is a value
    /// type with no shared state to protect.
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let seconds = progress * StarMetrics.flickWindow
        let front = StarMetrics.flickFrontDegrees
            * StarMetrics.eased(seconds / StarMetrics.flickFrontSeconds)
        let back = StarMetrics.flickBackDegrees
            * StarMetrics.eased((seconds - StarMetrics.flickBackDelay) / StarMetrics.flickBackSeconds)
        MizarStarPose(front: front, back: back, palette: palette, size: size)
    }
}

// MARK: - The icon, drawn

/// The app icon as a view: the star on its own tile.
///
/// Used where the app shows *itself* rather than a status -- the settings
/// header. It is the icon's composition, not a copy of the bitmap: the tile's
/// corner radius and the star's share of it are the icon's own numbers
/// (22.37% of the width, and 64% for the star), so it survives every size
/// without a second asset.
///
/// Two appearances, matching the two the icon ships: white tile and blue star
/// in Light Mode, black tile and white star in Dark. The system's own dark icon
/// is the white-star one, so a settings page that drew the light tile in a dark
/// app would be showing a different product's icon.
struct MizarIconTile: View {
    var size: CGFloat = 64
    /// What the star inside is doing. The tile itself never moves.
    var motion: MizarStar.Motion = .still

    @Environment(\.colorScheme) private var colorScheme

    /// Apple's icon corner radius, as a share of the width.
    private static let radiusShare: CGFloat = 185.0 / 824.0
    /// The star's width as a share of the icon's, from the icon's own bbox.
    private static let starShare: CGFloat = 527.0 / 824.0

    /// Whether this is the dark appearance.
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        RoundedRectangle(cornerRadius: size * Self.radiusShare, style: .continuous)
            .fill(isDark ? Color.black : Color.white)
            .overlay {
                // `starShare` is the star's *drawn* width; the mark's own frame
                // is larger than its ink by the margin the design box spends on
                // it (the tips reach `tipFraction` from the centre, so the ink
                // is `2 * tipFraction` of the box), so the frame is divided by
                // that.
                MizarStar(
                    motion: motion,
                    size: size * Self.starShare / (2 * StarMetrics.tipFraction),
                    palette: .automatic(for: colorScheme),
                )
            }
            .overlay {
                // A hairline, so a tile of the same colour as the list behind
                // it is still a tile. Black on white, white on black -- the
                // same edge seen from the other side.
                RoundedRectangle(cornerRadius: size * Self.radiusShare, style: .continuous)
                    .strokeBorder(
                        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08),
                        lineWidth: 1,
                    )
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview("The mark") {
    ScrollView {
        VStack(spacing: 28) {
            HStack(spacing: 24) {
                MizarStar(motion: .still, size: 28)
                MizarStar(motion: .running, size: 28)
                MizarStar(motion: .flick, size: 28)
                MizarStar(motion: .opening(0.5), size: 28)
            }
            HStack(spacing: 24) {
                MizarStar(motion: .still, size: 72)
                MizarStar(motion: .running, size: 72)
                MizarStar(motion: .flick, size: 72)
                MizarStar(motion: .opening(0.5), size: 72)
            }
            HStack(spacing: 24) {
                MizarStar(motion: .still, size: 72, palette: .ink(.white))
                    .background(Color(red: 19 / 255, green: 31 / 255, blue: 61 / 255))
                MizarStar(motion: .running, size: 72, palette: .ink(.white))
                    .background(Color(red: 19 / 255, green: 31 / 255, blue: 61 / 255))
            }
            HStack(spacing: 24) {
                MizarIconTile(size: 64, motion: .still)
                MizarIconTile(size: 128, motion: .flick)
            }
            MizarStar(motion: .opening(0), size: 96)
            MizarStar(motion: .opening(1), size: 96)
        }
        .padding(32)
    }
}
