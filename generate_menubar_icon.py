#!/usr/bin/env python3
"""Generate a distinctive monochrome menu bar icon (template image) for FT8ClusterAggregator.

Menu bar icons in macOS should be:
- Monochrome (black on transparent) with alpha
- Around 18-22pt tall (we render at 2x/3x for retina)
- Named with 'Template' suffix so macOS adapts to light/dark mode
"""

from PIL import Image, ImageDraw
import math
import os


def create_menubar_icon(size=44):
    """Render the icon at the given pixel size. Antenna + wave + node cluster,
    monochrome black on transparent."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Slight inset so icon doesn't touch edges
    pad = max(1, size // 22)

    BLACK = (0, 0, 0, 255)

    # ----- Antenna tower (left) -----
    tower_x = int(size * 0.24)
    tower_top = int(size * 0.14)
    tower_bottom = int(size * 0.86)
    tower_width = max(2, size // 22)

    draw.line(
        [(tower_x, tower_top), (tower_x, tower_bottom)],
        fill=BLACK, width=tower_width
    )
    # Cross arms
    for offset_y, len_factor in [(0.05, 0.06), (0.11, 0.09)]:
        y = tower_top + int(size * offset_y)
        arm_len = int(size * len_factor)
        draw.line(
            [(tower_x - arm_len, y), (tower_x + arm_len, y)],
            fill=BLACK, width=max(1, size // 30)
        )

    # Antenna tip dot
    tip_r = max(1, size // 24)
    draw.ellipse(
        [tower_x - tip_r, tower_top - tip_r * 2,
         tower_x + tip_r, tower_top],
        fill=BLACK
    )

    # ----- Radio wave arcs emanating from tower -----
    arc_width = max(1, size // 30)
    center_x = tower_x
    center_y = int(size * 0.5)
    for r_factor in [0.22, 0.32, 0.42]:
        r = int(size * r_factor)
        draw.arc(
            [center_x - r, center_y - r, center_x + r, center_y + r],
            start=-60, end=60, fill=BLACK, width=arc_width
        )

    # ----- Small cluster hub + 2 satellite nodes (right) -----
    hub_x = int(size * 0.82)
    hub_y = int(size * 0.5)
    hub_r = max(2, size // 14)

    # 2 satellite nodes offset above/below
    satellites = [
        (hub_x - int(size * 0.10), hub_y - int(size * 0.16)),
        (hub_x - int(size * 0.10), hub_y + int(size * 0.16)),
    ]

    # Connection lines (thin)
    for sx, sy in satellites:
        draw.line([(hub_x, hub_y), (sx, sy)], fill=BLACK, width=max(1, size // 40))

    # Hub (solid circle)
    draw.ellipse(
        [hub_x - hub_r, hub_y - hub_r, hub_x + hub_r, hub_y + hub_r],
        fill=BLACK
    )

    # Satellites (smaller solid circles)
    sat_r = max(1, size // 20)
    for sx, sy in satellites:
        draw.ellipse(
            [sx - sat_r, sy - sat_r, sx + sat_r, sy + sat_r],
            fill=BLACK
        )

    return img


def main():
    base = "/Users/manoj/Documents/Claude/code/FT8ClusterAggregator/FT8ClusterAggregator/Resources"
    os.makedirs(base, exist_ok=True)

    # 1x (22pt), 2x (44pt), 3x (66pt) for high-DPI
    for scale, pt in [(1, 22), (2, 44), (3, 66)]:
        img = create_menubar_icon(pt)
        suffix = "" if scale == 1 else f"@{scale}x"
        path = os.path.join(base, f"MenuBarIcon{suffix}.png")
        img.save(path)
        print(f"  {path} ({pt}x{pt})")

    # Also save a preview at larger size
    preview = create_menubar_icon(128)
    preview.save(os.path.join(base, "MenuBarIcon_preview.png"))
    print(f"  preview saved")


if __name__ == "__main__":
    main()
