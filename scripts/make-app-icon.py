#!/usr/bin/env python3
"""Build the phone's app icon from the desktop's.

The two apps are one product, so they wear one icon: this takes the desktop
build's 1024-point master -- the star on Apple's 824-point macOS tile -- and
turns it into the shape an iOS icon has to be.

Apple's two icon grids differ in exactly one way that matters here. macOS gets a
rounded square drawn inside the canvas with transparent margin around it; iOS
expects the artwork **full-bleed and opaque**, and applies the rounded mask
itself. Feeding the macOS canvas to iOS would produce a small rounded icon
floating in a transparent square, which is both wrong and rejected by App Store
Connect (transparency is not allowed at all).

Two appearances, because the desktop ships two: the light tile (a blue star on
white) and the dark one (a white star on black). iOS 18 and later draw the dark
asset when the system is in Dark Mode, which is what `AppIcon.appiconset`'s
`appearances` entry selects.

So: crop each tile, flatten it onto its own background so the four corners are
that colour rather than transparent, and scale to 1024. Nothing is redrawn --
the star's pixels are the desktop's.

    python3 scripts/make-app-icon.py [--source PATH] [--dark-source PATH] [--check]

The default sources are the sibling `AGI Mizar` checkout's build icons, which is
what the desktop ships. `--check` exits non-zero if either committed PNG is not
what this script would produce.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT.parent / "AGI Mizar" / "crates" / "agi-app" / "icons"
DEFAULT_SOURCE = ICON_DIR / "icon.png"
DEFAULT_DARK_SOURCE = ICON_DIR / "icon-dark.png"
OUT_DIR = ROOT / "DSH-Mizar" / "Assets.xcassets" / "AppIcon.appiconset"
OUT = OUT_DIR / "AppIcon-1024.png"
OUT_DARK = OUT_DIR / "AppIcon-1024-dark.png"

#: The desktop icon's geometry, as `AGI Mizar/scripts/make-icons.py` writes it:
#: an 824-point tile centred in a 1024-point canvas.
CANVAS = 1024
TILE = 824
INSET = (CANVAS - TILE) // 2


def build(source: Path, background: tuple[int, int, int]) -> Image.Image:
    """One appearance: the desktop's tile, full-bleed and opaque.

    - Parameters:
      - source: the 1024-point desktop icon.
      - background: the tile's own background colour, which the macOS canvas
        leaves transparent in the corners.
    """
    master = Image.open(source).convert("RGBA")
    if master.size != (CANVAS, CANVAS):
        raise SystemExit(f"{source} is {master.size[0]}x{master.size[1]}, expected {CANVAS}x{CANVAS}")

    tile = master.crop((INSET, INSET, INSET + TILE, INSET + TILE))
    # The tile's own colour: the macOS canvas leaves its four corners
    # transparent, and on iOS those patches become four notches of whatever is
    # behind them once the system rounds the icon.
    flat = Image.new("RGBA", tile.size, (*background, 255))
    flat.alpha_composite(tile)

    icon = flat.convert("RGB").resize((CANVAS, CANVAS), Image.LANCZOS)
    # No alpha channel at all: App Store Connect refuses an icon that has one,
    # even when every pixel in it is opaque.
    return icon


def matches(path: Path, icon: Image.Image) -> bool:
    """Whether the committed PNG is already this image."""
    if not path.exists():
        return False
    current = Image.open(path).convert("RGB")
    return current.size == icon.size and current.tobytes() == icon.tobytes()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--dark-source", type=Path, default=DEFAULT_DARK_SOURCE)
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()

    for source in (arguments.source, arguments.dark_source):
        if not source.exists():
            print(f"no desktop icon at {source}")
            return 1

    light = build(arguments.source, (255, 255, 255))
    dark = build(arguments.dark_source, (0, 0, 0))

    if arguments.check:
        stale = [path for path, icon in ((OUT, light), (OUT_DARK, dark)) if not matches(path, icon)]
        if stale:
            for path in stale:
                print(f"{path} is missing or stale; run scripts/make-app-icon.py")
            return 1
        print("app icons are up to date")
        return 0

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    light.save(OUT, format="PNG", optimize=True)
    dark.save(OUT_DARK, format="PNG", optimize=True)
    print(f"app icons: {OUT} and {OUT_DARK.name} ({light.size[0]}x{light.size[1]}, {light.mode})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
