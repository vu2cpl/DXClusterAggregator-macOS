#!/usr/bin/env python3
"""Generate a distinctive monochrome menu bar icon: "FT8" text in a rounded
rectangle. Immediately recognizable at menu bar size, unambiguous, and unique
to this app."""

from PIL import Image, ImageDraw, ImageFont
import os


def create_menubar_icon(size=44):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    BLACK = (0, 0, 0, 255)

    # Clean, bold FT8 text filling most of the icon width.
    # Try a bold font first; fall back progressively.
    font = None
    font_size = int(size * 0.80)  # tall so the text dominates
    for path in [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/Library/Fonts/Arial Bold.ttf",
    ]:
        try:
            font = ImageFont.truetype(path, font_size, index=1)  # index 1 = bold variant
            break
        except Exception:
            try:
                font = ImageFont.truetype(path, font_size)
                break
            except Exception:
                continue
    if font is None:
        font = ImageFont.load_default()

    text = "DX"
    # Shrink until text fits within icon width with ~5% padding
    max_width = int(size * 0.95)
    while font_size > 6:
        bbox = draw.textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0]
        if tw <= max_width:
            break
        font_size -= 1
        font = ImageFont.truetype(font.path if hasattr(font, "path") else "/System/Library/Fonts/Helvetica.ttc", font_size)

    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    text_x = (size - tw) // 2 - bbox[0]
    text_y = (size - th) // 2 - bbox[1]
    draw.text((text_x, text_y), text, fill=BLACK, font=font)

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
