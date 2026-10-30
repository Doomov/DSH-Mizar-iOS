#!/usr/bin/env python3
"""Generate the star's geometry, the Live Activity icon, and the motion strip.

The mark is one **three-armed star**, drawn twice sixty degrees apart to make the
six-armed icon. That layer is the whole of the shape: this script turns it into
the things the app can draw.

    scripts/make-star-geometry.py

    DSH-Mizar/Design/StarGeometry+Generated.swift   the layer, as a Swift Path
    DSH-Mizar-LiveActivity/Assets.xcassets/MizarIcon.imageset/*.png
    ../docs/evidence/ios-star-motion-2026-10-30.png   filmstrips for the spec

### Where the shape comes from

`LAYER_PROFILE` below is the layer's outline measured off the owner's own
reference (the single white three-armed star he supplied): radius at every five
degrees off a tip, as a fraction of the tip radius. It is the only source of
truth for the shape, and `--trace IMAGE` recomputes it from that reference so
the table can be checked rather than trusted.

The earlier version of this file read the path out of `icon-design/`'s SVG
instead. That SVG was traced from the *composite* -- the six-armed star -- and
then closed each gap with an arc on a circle, which invents a round core of
0.328 R that the real layer does not have. Its notches actually reach 0.247 R
and taper into it. Two such cores stacked are what made the mark look like a
ball with arms on it, so the profile replaced the SVG.

### Why a path here and a PNG there

A Live Activity is a snapshot the system renders outside the app: it cannot link
the app's `Shape`, and its assets are capped at the size they are drawn at.
Everything else can, and a vector stays crisp at 14 points on an island and at
92 on the launch screen.

Run from the iOS repository root. Needs Pillow for the raster side.

    python3 scripts/make-star-geometry.py [--check] [--skip-raster]
    python3 scripts/make-star-geometry.py --trace reference.png

`--check` writes nothing and exits non-zero if the generated Swift file is stale.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_OUT = ROOT / "DSH-Mizar" / "Design" / "StarGeometry+Generated.swift"
WIDGET_SET = ROOT / "DSH-Mizar-LiveActivity" / "Assets.xcassets" / "MizarIcon.imageset"
STRIP_OUT = ROOT.parent / "docs" / "evidence" / "ios-star-motion-2026-10-30.png"

#: The design box the icon is drawn in.
DESIGN = 1024.0
#: The tip's distance from the centre, in that box -- the icon's own proportion.
TIP_RADIUS = 365.0
#: Where the front layer's tips point: up, lower-left, lower-right.
PHASE = 90.0
#: How finely the outline is sampled, in degrees. Two and a half degrees is
#: under a fifth of a pixel at the largest size the app draws (92 points).
SAMPLE_STEP = 2.5

#: The layer's radius at each angle off a tip, as a fraction of the tip radius.
#:
#: Traced from the owner's reference layer (`--trace`): the three arms, and the
#: notch between them, which is the part the old SVG got wrong. The notch is not
#: a circle -- it keeps falling all the way to sixty degrees, where it is 0.247
#: of the tip. That is what makes the arms read as three pointed stars instead
#: of a ball with arms.
LAYER_PROFILE: list[tuple[float, float]] = [
    (0, 1.0000),
    (5, 0.8046),
    (10, 0.6255),
    (15, 0.5244),
    (20, 0.4379),
    (25, 0.3843),
    (30, 0.3544),
    (35, 0.3144),
    (40, 0.2916),
    (45, 0.2728),
    (50, 0.2653),
    (55, 0.2480),
    (60, 0.2467),
]

#: The icon's palette: three colours, flat -- background, front star, and the
#: same star one step darker behind it. From `icon-design/brief.md`, which
#: picked flat over the reference's gradient because a gradient that lights the
#: middle is exactly the ball this mark must not have.
FRONT_RGB = (10, 120, 174)
BACK_RGB = (8, 96, 139)


# --------------------------------------------------------------------------
# The outline
# --------------------------------------------------------------------------


def radius(delta: float) -> float:
    """The layer's radius `delta` degrees off a tip, in design units.

    The profile is symmetric about both the tip axis and the notch axis -- a
    three-armed star is -- so the absolute angle is all that matters, and
    sixty is the far side of the notch.
    """
    d = min(abs(delta), 60.0)
    for (a, ra), (b, rb) in zip(LAYER_PROFILE, LAYER_PROFILE[1:]):
        if d <= b:
            t = 0.0 if b == a else (d - a) / (b - a)
            return (ra + (rb - ra) * t) * TIP_RADIUS
    return LAYER_PROFILE[-1][1] * TIP_RADIUS


def polar(r: float, degrees: float) -> tuple[float, float]:
    """A point at `r` from the centre, `degrees` counter-clockwise from east."""
    a = math.radians(degrees)
    return (DESIGN / 2 + r * math.cos(a), DESIGN / 2 - r * math.sin(a))


def outline_points() -> list[tuple[float, float]]:
    """The closed outline, sampled: three arms of 120 degrees, tip to notch."""
    points = []
    for arm in range(3):
        tip = PHASE + 120.0 * arm
        offset = -60.0
        while offset <= 60.0:
            # The last sample of an arm is the first of the next one: append it
            # once, when it is the tip of the arm's far end.
            if not (offset == 60.0 and arm > 0):
                points.append(polar(radius(offset), tip + offset))
            offset += SAMPLE_STEP
    return points


def to_cubics(points: list[tuple[float, float]]) -> list[tuple[str, tuple]]:
    """A smooth closed path through the samples, as Catmull-Rom cubics.

    Catmull-Rom rather than a fit because the points *are* the shape: it
    interpolates them instead of approximating, and the tangents it derives are
    what round the tip and the notch without either becoming a corner.
    """
    count = len(points)
    steps: list[tuple[str, tuple]] = [("move", points[0])]
    for index in range(count):
        p0 = points[(index - 1) % count]
        p1 = points[index % count]
        p2 = points[(index + 1) % count]
        p3 = points[(index + 2) % count]
        control1 = (p1[0] + (p2[0] - p0[0]) / 6.0, p1[1] + (p2[1] - p0[1]) / 6.0)
        control2 = (p2[0] - (p3[0] - p1[0]) / 6.0, p2[1] - (p3[1] - p1[1]) / 6.0)
        steps.append(("curve", (control1, control2, p2)))
    steps.append(("close", None))
    return steps


def flatten(steps: list[tuple[str, tuple]], per_curve: int = 8) -> list[tuple[float, float]]:
    """The path as a polygon, for rasterising."""
    points: list[tuple[float, float]] = []
    current = (0.0, 0.0)
    for kind, payload in steps:
        if kind == "move":
            current = payload
            points.append(current)
        elif kind == "line":
            current = payload
            points.append(current)
        elif kind == "curve":
            c1, c2, end = payload
            for index in range(1, per_curve + 1):
                t = index / per_curve
                mt = 1 - t
                points.append((
                    mt ** 3 * current[0] + 3 * mt * mt * t * c1[0]
                    + 3 * mt * t * t * c2[0] + t ** 3 * end[0],
                    mt ** 3 * current[1] + 3 * mt * mt * t * c1[1]
                    + 3 * mt * t * t * c2[1] + t ** 3 * end[1],
                ))
            current = end
    return points


# --------------------------------------------------------------------------
# Swift
# --------------------------------------------------------------------------


def number(value: float) -> str:
    """A coordinate in design units, four decimals, no trailing zeros."""
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return "0" if text == "-0" else text


def swift_file(steps: list[tuple[str, tuple]]) -> str:
    lines = [
        "//",
        "//  StarGeometry+Generated.swift",
        "//  DSH-Mizar",
        "//",
        "//  The Mizar star's three-armed layer, in design units.",
        "//",
        "//  Generated -- do not edit. The shape is the owner's own reference layer,",
        "//  measured into a radius profile in `scripts/make-star-geometry.py`: three",
        "//  pointed arms and the notch between them, which keeps falling to 0.247 of",
        "//  the tip. The six-armed icon is this path and its sixty-degree turn.",
        "//",
        "//  Regenerate: python3 scripts/make-star-geometry.py",
        "//",
        "",
        "import SwiftUI",
        "",
        "enum StarGeometry {",
        "    /// The box the path below is drawn in, in the icon's own units.",
        "    static let designSize: CGFloat = 1024",
        "",
        "    /// The layer under the front star, turned this far from it.",
        "    ///",
        "    /// 60 degrees is what turns three arms into the icon's six: each layer",
        "    /// is three-fold symmetric, so 60 is the smallest offset that reads as two",
        "    /// stars rather than one.",
        "    static let backOffset: Double = 60",
        "",
        "    /// The path, scaled to a `0...1` box with its top-left at the origin.",
        "    ///",
        "    /// Normalised rather than left in design units so a `Shape` can map it",
        "    /// onto any frame with one multiply, and so a point on the curve means the",
        "    /// same thing at 14 points as at 92.",
        "    static func path() -> Path {",
        "        var path = Path()",
    ]
    for kind, payload in steps:
        if kind == "move":
            x, y = payload
            lines.append(f"        path.move(to: CGPoint(x: {number(x / DESIGN)}, y: {number(y / DESIGN)}))")
        elif kind == "line":
            x, y = payload
            lines.append(f"        path.addLine(to: CGPoint(x: {number(x / DESIGN)}, y: {number(y / DESIGN)}))")
        elif kind == "curve":
            c1, c2, end = payload
            lines.append(
                "        path.addCurve("
                f"to: CGPoint(x: {number(end[0] / DESIGN)}, y: {number(end[1] / DESIGN)}), "
                f"control1: CGPoint(x: {number(c1[0] / DESIGN)}, y: {number(c1[1] / DESIGN)}), "
                f"control2: CGPoint(x: {number(c2[0] / DESIGN)}, y: {number(c2[1] / DESIGN)}))"
            )
        elif kind == "close":
            lines.append("        path.closeSubpath()")
    lines += [
        "        return path",
        "    }",
        "}",
        "",
    ]
    return "\n".join(lines)


# --------------------------------------------------------------------------
# Rasters
# --------------------------------------------------------------------------


def layer_mask(size: int, steps: list[tuple[str, tuple]], scale: int = 4) -> "object":
    """The layer, antialiased, as a Pillow `L` mask."""
    from PIL import Image, ImageDraw

    big = size * scale
    factor = big / DESIGN
    polygon = [(x * factor, y * factor) for x, y in flatten(steps)]
    image = Image.new("L", (big, big), 0)
    ImageDraw.Draw(image).polygon(polygon, fill=255)
    return image.resize((size, size), Image.LANCZOS)


def white_layer(size: int, steps: list[tuple[str, tuple]]) -> "object":
    """The layer in white, with the mask as its alpha."""
    from PIL import Image

    white = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    white.putalpha(layer_mask(size, steps))
    return white


def write_widget_icon(steps: list[tuple[str, tuple]]) -> None:
    """The Live Activity's template glyph: the six-armed silhouette.

    A template image is tinted by the system, so both layers are white and the
    edge between them is gone -- what matters is the silhouette. The three sizes
    are the three scales of a 32-point frame, which is the largest the card
    draws it at.

    Cropped to the star rather than left in the icon's design box: inside a
    Live Activity the glyph sits in a 14- or 16-point row, and the design box's
    14% margin would spend a fifth of that on nothing.
    """
    from PIL import Image, ImageChops

    WIDGET_SET.mkdir(parents=True, exist_ok=True)
    for scale, name in ((1, "MizarIcon.png"), (2, "MizarIcon@2x.png"), (3, "MizarIcon@3x.png")):
        size = 32 * scale
        master = size * 12
        front = layer_mask(master, steps, scale=1)
        back = front.rotate(-60, resample=3, center=(master / 2, master / 2))
        union = ImageChops.lighter(front, back)
        box = union.getbbox()
        if box is None:
            raise SystemExit("the star rendered empty")
        slack = max(1, round(master * 0.01))
        cropped = union.crop((
            max(0, box[0] - slack),
            max(0, box[1] - slack),
            min(master, box[2] + slack),
            min(master, box[3] + slack),
        ))
        alpha = cropped.resize(
            (
                round(cropped.width * size / max(cropped.size)),
                round(cropped.height * size / max(cropped.size)),
            ),
            Image.LANCZOS,
        )
        image = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
        image.putalpha(alpha)
        image.save(WIDGET_SET / name)
    print(f"widget icon: {WIDGET_SET}")


def compose(
    size: int,
    front_angle: float,
    back_angle: float,
    steps: list[tuple[str, tuple]],
) -> "object":
    """One frame of the mark: the two layers at their angles, on the icon's tile."""
    from PIL import Image

    layer = white_layer(size, steps)
    front = Image.new("RGBA", (size, size), (*FRONT_RGB, 255))
    front.putalpha(layer.getchannel("A"))
    back = Image.new("RGBA", (size, size), (*BACK_RGB, 255))
    back.putalpha(layer.getchannel("A"))

    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    canvas.alpha_composite(back.rotate(back_angle, resample=3, center=(size / 2, size / 2)))
    canvas.alpha_composite(front.rotate(front_angle, resample=3, center=(size / 2, size / 2)))
    return canvas


def smootherstep(p: float) -> float:
    """0 to 1 with zero velocity at both ends -- the flick's curve."""
    p = min(max(p, 0.0), 1.0)
    return p * p * p * (p * (p * 6 - 15) + 10)


def write_motion_strip(steps: list[tuple[str, tuple]]) -> None:
    """Two filmstrips for the motion spec: the loop and the flick."""
    from PIL import Image, ImageDraw

    cell = 96
    pad = 12
    running_frames = 8
    flick_frames = 8
    period = 9.0  # seconds per revolution of each layer, the shipped default
    flick_front_degrees, flick_front_seconds = 480.0, 1.0
    flick_back_degrees, flick_back_seconds = -600.0, 1.55
    flick_back_delay = 0.035
    bloom_seconds = period / 6.0

    width = pad + running_frames * (cell + pad)
    height = pad + 2 * (cell + pad) + 30
    strip = Image.new("RGBA", (width, height), (24, 24, 26, 255))
    draw = ImageDraw.Draw(strip)

    draw.text(
        (pad, 8),
        f"running: {bloom_seconds:.2f} s per bloom (each layer {period:g} s / rev, opposite ways)",
        fill=(220, 220, 220, 255),
    )
    for index in range(running_frames):
        angle = 60.0 * index / (running_frames - 1)
        frame = compose(cell, angle, 60.0 - angle, steps)
        strip.alpha_composite(frame, (pad + index * (cell + pad), 28))

    top = 28 + cell + 18
    draw.text(
        (pad, top),
        "flick: front +480 deg / 1.00 s, back -600 deg / 1.55 s",
        fill=(220, 220, 220, 255),
    )
    for index in range(flick_frames):
        t = 2.0 * index / (flick_frames - 1)
        front = smootherstep(t / flick_front_seconds) * flick_front_degrees
        back = 60.0 + smootherstep((t - flick_back_delay) / flick_back_seconds) * flick_back_degrees
        frame = compose(cell, front, back, steps)
        strip.alpha_composite(frame, (pad + index * (cell + pad), top + 20))

    STRIP_OUT.parent.mkdir(parents=True, exist_ok=True)
    strip.convert("RGB").save(STRIP_OUT)
    print(f"motion strip: {STRIP_OUT}")


# --------------------------------------------------------------------------
# Tracing the reference
# --------------------------------------------------------------------------


def trace(path: Path) -> list[tuple[float, float]]:
    """Measure the layer's radius profile off a single-layer reference image.

    The star must be light on a dark (or transparent) background. The centre is
    the area's centroid, which is the rotation centre for a three-fold symmetric
    shape, and the profile is folded over the three arms.
    """
    from PIL import Image

    image = Image.open(path).convert("L")
    width, height = image.size
    pixels = image.load()

    def lit(x: int, y: int) -> bool:
        return 0 <= x < width and 0 <= y < height and pixels[x, y] > 40

    sx = sy = count = 0
    for y in range(0, height, 2):
        for x in range(0, width, 2):
            if lit(x, y):
                sx += x
                sy += y
                count += 1
    if not count:
        raise SystemExit(f"{path} has no star in it")
    cx, cy = sx / count, sy / count

    def reachable(degrees: float) -> float:
        radians = math.radians(degrees)
        r = 0.0
        while r < max(width, height) and lit(
            int(round(cx + r * math.cos(radians))),
            int(round(cy - r * math.sin(radians))),
        ):
            r += 0.5
        return r

    profile = {step / 8: reachable(step / 8) for step in range(2880)}
    tip_radius = max(profile.values())
    peak = max(profile, key=lambda key: profile[key])

    table = []
    for delta in range(0, 61, 5):
        here = profile[(peak + delta) % 360]
        there = profile[(peak - delta) % 360]
        table.append((float(delta), round((here + there) / 2 / tip_radius, 4)))
    return table


# --------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace", type=Path, help="measure a reference layer and print its profile")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--skip-raster", action="store_true")
    arguments = parser.parse_args()

    if arguments.trace:
        for delta, value in trace(arguments.trace):
            print(f"    ({delta:g}, {value:.4f}),")
        return 0

    steps = to_cubics(outline_points())
    swift = swift_file(steps)

    if arguments.check:
        current = SWIFT_OUT.read_text(encoding="utf-8") if SWIFT_OUT.exists() else ""
        if current != swift:
            print(f"{SWIFT_OUT} is stale; run scripts/make-star-geometry.py")
            return 1
        print("geometry is up to date")
        return 0

    SWIFT_OUT.parent.mkdir(parents=True, exist_ok=True)
    SWIFT_OUT.write_text(swift, encoding="utf-8")
    print(f"swift: {SWIFT_OUT}")
    if not arguments.skip_raster:
        write_widget_icon(steps)
        write_motion_strip(steps)
    return 0


if __name__ == "__main__":
    sys.exit(main())
