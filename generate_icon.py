#!/usr/bin/env python3
"""Generate a radio/network themed app icon for FT8ClusterAggregator."""

from PIL import Image, ImageDraw, ImageFont
import math
import os

def create_icon(size=1024):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2

    # Rounded rectangle background - dark navy blue
    margin = int(size * 0.05)
    radius = int(size * 0.18)
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        fill=(20, 30, 60, 255)
    )

    # Subtle gradient overlay (simulated with concentric shapes)
    for i in range(10):
        alpha = int(15 - i * 1.5)
        r = int(size * 0.45 - i * size * 0.02)
        draw.ellipse(
            [cx - r, cy - r - int(size * 0.05), cx + r, cy + r - int(size * 0.05)],
            fill=(40, 80, 160, max(0, alpha))
        )

    # Radio wave arcs (emanating from antenna)
    antenna_x = int(cx - size * 0.15)
    antenna_y = int(cy - size * 0.05)

    wave_colors = [
        (0, 200, 255, 180),   # cyan
        (0, 180, 230, 150),
        (0, 160, 210, 120),
        (0, 140, 190, 90),
    ]

    for i, color in enumerate(wave_colors):
        r = int(size * (0.12 + i * 0.08))
        arc_width = max(3, int(size * 0.012))
        draw.arc(
            [antenna_x - r, antenna_y - r, antenna_x + r, antenna_y + r],
            start=-60, end=60,
            fill=color, width=arc_width
        )

    # Antenna tower (stylized)
    tower_width = int(size * 0.025)
    tower_top = int(cy - size * 0.25)
    tower_bottom = int(cy + size * 0.28)

    # Main antenna mast
    draw.line(
        [(antenna_x, tower_top), (antenna_x, tower_bottom)],
        fill=(200, 220, 255, 230), width=tower_width
    )

    # Antenna cross arms
    arm_len = int(size * 0.08)
    for offset_y in [int(size * 0.05), int(size * 0.12)]:
        y = tower_top + offset_y
        draw.line(
            [(antenna_x - arm_len, y), (antenna_x + arm_len, y)],
            fill=(200, 220, 255, 200), width=max(2, int(size * 0.012))
        )

    # Antenna tip - small circle
    tip_r = int(size * 0.018)
    draw.ellipse(
        [antenna_x - tip_r, tower_top - tip_r * 2, antenna_x + tip_r, tower_top],
        fill=(255, 100, 100, 255)
    )

    # Network nodes (representing cluster aggregation)
    node_color = (0, 220, 180, 220)
    node_r = int(size * 0.035)

    # Central hub node
    hub_x = int(cx + size * 0.15)
    hub_y = int(cy + size * 0.05)

    # Satellite nodes around the hub
    nodes = []
    for angle_deg in [30, 90, 150, 210, 330]:
        rad = math.radians(angle_deg)
        dist = int(size * 0.18)
        nx = int(hub_x + dist * math.cos(rad))
        ny = int(hub_y + dist * math.sin(rad))
        nodes.append((nx, ny))

    # Connection lines from nodes to hub
    line_color = (0, 180, 160, 100)
    line_width = max(2, int(size * 0.008))
    for nx, ny in nodes:
        draw.line([(hub_x, hub_y), (nx, ny)], fill=line_color, width=line_width)

    # Draw satellite nodes
    small_r = int(size * 0.022)
    for nx, ny in nodes:
        draw.ellipse(
            [nx - small_r, ny - small_r, nx + small_r, ny + small_r],
            fill=(0, 200, 170, 200),
            outline=(0, 255, 220, 255),
            width=max(1, int(size * 0.004))
        )

    # Draw hub node (larger, brighter)
    draw.ellipse(
        [hub_x - node_r, hub_y - node_r, hub_x + node_r, hub_y + node_r],
        fill=(0, 255, 200, 240),
        outline=(255, 255, 255, 200),
        width=max(2, int(size * 0.006))
    )

    # Connection line from antenna to hub
    draw.line(
        [(antenna_x, antenna_y), (hub_x, hub_y)],
        fill=(100, 200, 255, 120), width=max(2, int(size * 0.008))
    )

    # "FT8" text at bottom
    text_y = int(cy + size * 0.32)
    try:
        font_size = int(size * 0.09)
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = ImageFont.load_default()

    text = "FT8"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(
        (cx - tw // 2, text_y),
        text,
        fill=(255, 255, 255, 220),
        font=font
    )

    return img


def create_iconset(img, iconset_dir):
    """Create .iconset directory with all required sizes."""
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]

    for base_size, scale in sizes:
        actual_size = base_size * scale
        resized = img.resize((actual_size, actual_size), Image.LANCZOS)
        if scale == 1:
            filename = f"icon_{base_size}x{base_size}.png"
        else:
            filename = f"icon_{base_size}x{base_size}@{scale}x.png"
        resized.save(os.path.join(iconset_dir, filename))
        print(f"  Created {filename} ({actual_size}x{actual_size})")


if __name__ == "__main__":
    base_dir = "/Users/manoj/Documents/Claude/code/FT8ClusterAggregator"
    iconset_dir = os.path.join(base_dir, "AppIcon.iconset")

    print("Generating icon...")
    icon = create_icon(1024)

    print("Creating iconset...")
    create_iconset(icon, iconset_dir)

    print("Done! Now run: iconutil -c icns AppIcon.iconset")
