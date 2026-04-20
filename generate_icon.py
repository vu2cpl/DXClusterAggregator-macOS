#!/usr/bin/env python3
"""Generate a vibrant, colorful radio/network app icon for FT8ClusterAggregator."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import os


def create_icon(size=1024):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2

    # ----- Vibrant gradient background -----
    # Sunset / aurora-inspired: deep indigo → magenta → orange
    margin = int(size * 0.05)
    radius = int(size * 0.20)

    # Build gradient by stacking horizontal lines
    grad = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    grad_draw = ImageDraw.Draw(grad)

    # Three colour stops, top → bottom
    stops = [
        (0.00, (30, 20, 90, 255)),     # deep indigo
        (0.45, (160, 30, 130, 255)),   # magenta
        (0.80, (245, 95, 50, 255)),    # vivid orange
        (1.00, (255, 180, 60, 255)),   # warm gold
    ]

    def lerp(a, b, t):
        return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))

    for y in range(size):
        t = y / (size - 1)
        # Find which stop pair we're between
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                local = (t - t0) / (t1 - t0)
                color = lerp(c0, c1, local)
                grad_draw.line([(0, y), (size, y)], fill=color)
                break

    # Apply gradient inside a rounded-rect mask
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius, fill=255
    )
    img.paste(grad, (0, 0), mask)
    draw = ImageDraw.Draw(img)

    # ----- Glow halo behind antenna -----
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    halo_x = int(cx - size * 0.18)
    halo_y = int(cy - size * 0.05)
    for r, alpha in [(int(size * 0.30), 60), (int(size * 0.22), 90), (int(size * 0.14), 120)]:
        glow_draw.ellipse(
            [halo_x - r, halo_y - r, halo_x + r, halo_y + r],
            fill=(255, 255, 200, alpha)
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=int(size * 0.04)))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # ----- Rainbow concentric radio waves -----
    wave_colors = [
        (255, 80, 80, 230),     # red
        (255, 165, 60, 220),    # orange
        (255, 230, 90, 210),    # yellow
        (90, 230, 130, 200),    # green
        (90, 200, 255, 200),    # sky blue
        (180, 130, 255, 200),   # violet
    ]

    for i, color in enumerate(wave_colors):
        r = int(size * (0.10 + i * 0.07))
        arc_width = max(4, int(size * 0.018))
        # Arcs to right of antenna
        draw.arc(
            [halo_x - r, halo_y - r, halo_x + r, halo_y + r],
            start=-65, end=65,
            fill=color, width=arc_width
        )

    # ----- Antenna tower (bright white with subtle red tip) -----
    tower_top = int(cy - size * 0.30)
    tower_bottom = int(cy + size * 0.30)
    tower_width = max(4, int(size * 0.028))

    # Tower outline (slight shadow)
    draw.line(
        [(halo_x, tower_top + 2), (halo_x, tower_bottom + 2)],
        fill=(0, 0, 0, 130), width=tower_width + 4
    )
    # Tower body
    draw.line(
        [(halo_x, tower_top), (halo_x, tower_bottom)],
        fill=(255, 255, 255, 245), width=tower_width
    )

    # Cross arms - graduated lengths like a real tower
    for offset_y, len_factor in [(0.04, 0.05), (0.10, 0.08), (0.18, 0.11)]:
        y = tower_top + int(size * offset_y)
        arm_len = int(size * len_factor)
        draw.line(
            [(halo_x - arm_len, y), (halo_x + arm_len, y)],
            fill=(255, 255, 255, 230), width=max(3, int(size * 0.012))
        )

    # Glowing red tip light
    tip_r = int(size * 0.025)
    # Soft glow around tip
    tip_glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(tip_glow).ellipse(
        [halo_x - tip_r * 3, tower_top - tip_r * 4,
         halo_x + tip_r * 3, tower_top + tip_r * 2],
        fill=(255, 70, 70, 180)
    )
    tip_glow = tip_glow.filter(ImageFilter.GaussianBlur(radius=int(size * 0.02)))
    img = Image.alpha_composite(img, tip_glow)
    draw = ImageDraw.Draw(img)
    # Solid red dot on top
    draw.ellipse(
        [halo_x - tip_r, tower_top - tip_r * 2,
         halo_x + tip_r, tower_top],
        fill=(255, 60, 60, 255),
        outline=(255, 255, 255, 255),
        width=max(2, int(size * 0.005))
    )

    # ----- Network cluster nodes (right side) -----
    hub_x = int(cx + size * 0.20)
    hub_y = int(cy + size * 0.10)

    # Connection lines first (behind nodes)
    node_colors = [
        (90, 255, 200, 255),    # mint
        (255, 220, 90, 255),    # amber
        (255, 100, 180, 255),   # pink
        (140, 200, 255, 255),   # ice blue
        (200, 130, 255, 255),   # purple
    ]

    nodes = []
    for i, angle_deg in enumerate([20, 80, 150, 215, 305]):
        rad = math.radians(angle_deg)
        dist = int(size * 0.18)
        nx = int(hub_x + dist * math.cos(rad))
        ny = int(hub_y + dist * math.sin(rad))
        nodes.append((nx, ny, node_colors[i % len(node_colors)]))

    # Glowing connection lines
    line_glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    line_glow_draw = ImageDraw.Draw(line_glow)
    for nx, ny, color in nodes:
        line_glow_draw.line(
            [(hub_x, hub_y), (nx, ny)],
            fill=(*color[:3], 140),
            width=max(3, int(size * 0.012))
        )
    line_glow = line_glow.filter(ImageFilter.GaussianBlur(radius=int(size * 0.008)))
    img = Image.alpha_composite(img, line_glow)
    draw = ImageDraw.Draw(img)

    # Crisp connection lines on top
    for nx, ny, color in nodes:
        draw.line(
            [(hub_x, hub_y), (nx, ny)],
            fill=(*color[:3], 200),
            width=max(2, int(size * 0.005))
        )

    # Satellite nodes
    small_r = int(size * 0.030)
    for nx, ny, color in nodes:
        # Glow
        draw.ellipse(
            [nx - small_r - 4, ny - small_r - 4,
             nx + small_r + 4, ny + small_r + 4],
            fill=(*color[:3], 80)
        )
        # Solid node
        draw.ellipse(
            [nx - small_r, ny - small_r, nx + small_r, ny + small_r],
            fill=color,
            outline=(255, 255, 255, 255),
            width=max(2, int(size * 0.004))
        )

    # Hub - bright cyan glowing core
    hub_r = int(size * 0.045)
    hub_glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(hub_glow).ellipse(
        [hub_x - hub_r * 2, hub_y - hub_r * 2,
         hub_x + hub_r * 2, hub_y + hub_r * 2],
        fill=(60, 255, 240, 200)
    )
    hub_glow = hub_glow.filter(ImageFilter.GaussianBlur(radius=int(size * 0.025)))
    img = Image.alpha_composite(img, hub_glow)
    draw = ImageDraw.Draw(img)

    draw.ellipse(
        [hub_x - hub_r, hub_y - hub_r, hub_x + hub_r, hub_y + hub_r],
        fill=(80, 255, 240, 255),
        outline=(255, 255, 255, 255),
        width=max(3, int(size * 0.008))
    )

    # ----- Connection from antenna to hub (signal pulse) -----
    draw.line(
        [(halo_x, halo_y), (hub_x, hub_y)],
        fill=(255, 255, 255, 160), width=max(2, int(size * 0.006))
    )

    # ----- "FT8" text with shadow -----
    text_y = int(cy + size * 0.34)
    try:
        font_size = int(size * 0.10)
        font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", font_size)
    except Exception:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", int(size * 0.10))
        except Exception:
            font = ImageFont.load_default()

    text = "FT8"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    text_x = cx - tw // 2

    # Drop shadow
    draw.text((text_x + 2, text_y + 3), text, fill=(0, 0, 0, 140), font=font)
    # Main text
    draw.text((text_x, text_y), text, fill=(255, 255, 255, 245), font=font)

    return img


def create_iconset(img, iconset_dir):
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
        print(f"  {filename} ({actual_size}x{actual_size})")


if __name__ == "__main__":
    base_dir = "/Users/manoj/Documents/Claude/code/FT8ClusterAggregator"
    iconset_dir = os.path.join(base_dir, "AppIcon.iconset")

    print("Generating colorful icon...")
    icon = create_icon(1024)
    icon.save(os.path.join(base_dir, "AppIcon_preview.png"))

    print("Creating iconset...")
    create_iconset(icon, iconset_dir)

    print("Done.")
