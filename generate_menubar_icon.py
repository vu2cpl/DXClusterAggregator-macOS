#!/usr/bin/env python3
"""Generate a distinctive monochrome menu bar icon: "FT8" text in a rounded
rectangle. Immediately recognizable at menu bar size, unambiguous, and unique
to this app."""

from PIL import Image, ImageDraw, ImageFont
import os


def find_bold_font(font_size):
    """Try to locate a genuinely bold font on macOS. Falls back to Helvetica."""
    # Direct bold fonts
    direct = [
        "/System/Library/Fonts/Helvetica.ttc",   # indices 1 & 2 are Bold variants
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/SFCompactText.ttf",
    ]
    # Helvetica.ttc indices: 0=Regular, 1=Bold, 2=Light, 3=Oblique, 4=BoldOblique...
    for path in direct:
        for index in (1, 2, 0):
            try:
                f = ImageFont.truetype(path, font_size, index=index)
                # Heuristic: only accept if it looks bold (check weight via name)
                if "Bold" in f.getname()[1] or index == 1:
                    return f
            except Exception:
                continue
    # Fallback: regular
    try:
        return ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except Exception:
        return ImageFont.load_default()


def create_menubar_icon(size=44):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    BLACK = (0, 0, 0, 255)
    text = "DX"

    # Keep the glyphs comfortably inside the icon: ~65% height, ~80% max width
    font_size = int(size * 0.70)
    font = find_bold_font(font_size)

    max_width = int(size * 0.80)
    while font_size > 6:
        bbox = draw.textbbox((0, 0), text, font=font)
        if bbox[2] - bbox[0] <= max_width:
            break
        font_size -= 1
        font = find_bold_font(font_size)

    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    text_x = (size - tw) // 2 - bbox[0]
    text_y = (size - th) // 2 - bbox[1]

    # Use Pillow's built-in stroke_width for clean, even boldness that does
    # not fill in counters at small sizes. Small stroke only at larger renders.
    stroke = 1 if size >= 40 else 0
    draw.text((text_x, text_y), text, fill=BLACK, font=font,
              stroke_width=stroke, stroke_fill=BLACK)

    return img


def main():
    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "DXClusterAggregator", "Resources")
    os.makedirs(base, exist_ok=True)

    # 1x (22pt), 2x (44pt), 3x (66pt) for high-DPI
    for scale, pt in [(1, 22), (2, 44), (3, 66)]:
        img = create_menubar_icon(pt)
        suffix = "" if scale == 1 else f"@{scale}x"
        path = os.path.join(base, f"MenuBarIcon{suffix}.png")
        img.save(path)
        print(f"  {path} ({pt}x{pt})")

    # Preview at large size
    preview = create_menubar_icon(128)
    preview.save(os.path.join(base, "MenuBarIcon_preview.png"))
    print(f"  preview saved")


if __name__ == "__main__":
    main()
