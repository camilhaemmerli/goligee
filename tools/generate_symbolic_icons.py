#!/usr/bin/env python3
"""Generate symbolic tower icons via PixelLab API.

Generates 128x128 PNG icons: bold symbol on transparent bg, composited onto
a dark gradient rounded-rectangle card.

Usage:
    python tools/generate_symbolic_icons.py                 # all towers
    python tools/generate_symbolic_icons.py --towers rubber_bullet,lrad

Requires: pip install Pillow requests
Env:      PIXELLAB_API_KEY in .env or environment
"""

import argparse
import base64
import io
import os
import subprocess
import sys
from pathlib import Path

import requests
from PIL import Image, ImageDraw

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites"
OUTPUT_DIR = SPRITES_DIR / "ui"
ENV_FILE = PROJECT_ROOT / ".env"

API_BASE = "https://api.pixellab.ai/v2"
ICON_SIZE = 128
CORNER_RADIUS = 12
BG_TOP = (26, 26, 30)      # #1A1A1E
BG_BOTTOM = (42, 42, 48)   # #2A2A30

CHROMA_BG = "on solid bright magenta #FF00FF background"

# ── Per-tower icon prompts ─────────────────────────────────────────────
# Keep prompts short and iconic — describe the SYMBOL, not the tower.

TOWER_ICONS = {
    "rubber_bullet": (
        f"pixel art game icon, clean bold symbol, "
        f"crosshair target reticle scope symbol, circular aim sight, "
        f"deep red #C03030 color, dark theme, {CHROMA_BG}"
    ),
    "water_cannon": (
        f"pixel art game icon, clean bold symbol, "
        f"single large water droplet, teardrop shape, "
        f"deep red #C03030 color, dark theme, {CHROMA_BG}"
    ),
    "tear_gas": (
        f"pixel art game icon, clean bold symbol, "
        f"toxic gas cloud, poison smoke puff, skull in cloud, "
        f"deep red #C03030 color, dark theme, {CHROMA_BG}"
    ),
    "taser_grid": (
        f"pixel art game icon, clean bold symbol, "
        f"electric lightning bolt, jagged electricity symbol, "
        f"deep red #C03030 color, dark theme, {CHROMA_BG}"
    ),
    "pepper_spray": (
        f"pixel art game icon, clean bold symbol, "
        f"fire flame, spray burst, chili pepper with flames, "
        f"deep red #C03030 color, dark theme, {CHROMA_BG}"
    ),
    "lrad": (
        f"pixel art game icon, clean bold symbol, "
        f"sound wave symbol, speaker with concentric arcs, audio blast, "
        f"deep red #C03030 color, dark theme, {CHROMA_BG}"
    ),
    "surveillance": (
        f"pixel art game icon, clean bold symbol, "
        f"all-seeing eye symbol, surveillance eye, watching eye, "
        f"deep red #C03030 color, dark theme, {CHROMA_BG}"
    ),
    "microwave": (
        f"pixel art game icon, clean bold symbol, "
        f"radiation hazard symbol, radioactive trefoil, heat waves, "
        f"deep red #C03030 color, dark theme, {CHROMA_BG}"
    ),
}


# ── Palette swatch (reuse from generate_assets) ───────────────────────

PALETTE_COLORS = [
    "#0E0E12", "#161618", "#1A1A1E", "#1E1E22", "#28282C", "#2E2E32",
    "#3A3A3E", "#484850", "#585860", "#606068", "#808898",
    "#C8A040", "#D8A040", "#E8A040", "#D06030", "#D04040", "#903020",
    "#5080A0", "#3868A0",
    "#D06040", "#A84030", "#802818", "#E89060",
    "#F0E0C0", "#70A040", "#50A0D0", "#6090B0",
    "#A0D8A0", "#88C888", "#9A9AA0",
]


def hex_to_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def create_palette_swatch() -> str:
    swatch = Image.new("RGB", (len(PALETTE_COLORS), 1))
    for i, c in enumerate(PALETTE_COLORS):
        swatch.putpixel((i, 0), hex_to_rgb(c))
    buf = io.BytesIO()
    swatch.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


# ── API helpers ────────────────────────────────────────────────────────

def load_api_key() -> str:
    key = os.environ.get("PIXELLAB_API_KEY")
    if key:
        return key
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    print("ERROR: PIXELLAB_API_KEY not found. Set it in .env or as environment variable.")
    sys.exit(1)


def generate_image(session: requests.Session, palette_b64: str,
                   description: str, width: int, height: int) -> bytes:
    """Generate a single image via PixelLab pixflux endpoint."""
    payload = {
        "description": description,
        "image_size": {"width": width, "height": height},
        "isometric": False,
        "color_image": {"base64": palette_b64},
        "text_guidance_scale": 8.0,
        "negative_description": (
            "background, scene, environment, building, architecture, "
            "street, urban, night sky, ground, floor, landscape, "
            "character, person, human, body, face"
        ),
    }
    url = f"{API_BASE}/create-image-pixflux"
    resp = session.post(url, json=payload, timeout=300)
    if resp.status_code == 429:
        import time
        print("  Rate limited, waiting 30s...")
        time.sleep(30)
        resp = session.post(url, json=payload, timeout=300)
    if not resp.ok:
        print(f"  API error {resp.status_code}: {resp.text[:500]}")
        resp.raise_for_status()
    data = resp.json()
    img_b64 = data.get("image", {}).get("base64", "")
    if not img_b64:
        raise ValueError(f"No image in response: {list(data.keys())}")
    return base64.b64decode(img_b64)


# ── Background removal (chroma-key flood-fill) ────────────────────────

def remove_background(img_bytes: bytes, tolerance: int = 30) -> bytes:
    """Remove solid background via flood-fill from edges."""
    from collections import deque

    img = Image.open(io.BytesIO(img_bytes)).convert("RGBA")
    pixels = img.load()
    w, h = img.size

    corner_coords = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    transparent_corners = sum(1 for x, y in corner_coords if pixels[x, y][3] < 10)
    if transparent_corners >= 3:
        return img_bytes

    corners = [pixels[x, y][:3] for x, y in corner_coords]
    bg_color = max(set(corners), key=corners.count)

    bg_brightness = sum(bg_color)
    if bg_brightness < 90:
        tolerance = 10

    def color_dist(c1, c2):
        return sum((a - b) ** 2 for a, b in zip(c1, c2)) ** 0.5

    visited = set()
    queue = deque()

    for x in range(w):
        for y in (0, h - 1):
            if color_dist(pixels[x, y][:3], bg_color) <= tolerance:
                queue.append((x, y))
                visited.add((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if (x, y) not in visited and color_dist(pixels[x, y][:3], bg_color) <= tolerance:
                queue.append((x, y))
                visited.add((x, y))

    to_clear = set()
    while queue:
        cx, cy = queue.popleft()
        to_clear.add((cx, cy))
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                visited.add((nx, ny))
                if color_dist(pixels[nx, ny][:3], bg_color) <= tolerance:
                    queue.append((nx, ny))

    for x, y in to_clear:
        pixels[x, y] = (0, 0, 0, 0)

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


# ── Card background compositing ───────────────────────────────────────

def make_card_bg(size: int = ICON_SIZE) -> Image.Image:
    """Dark vertical gradient with rounded corners."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / (size - 1)
        r = int(BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t)
        g = int(BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t)
        b = int(BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t)
        for x in range(size):
            grad.putpixel((x, y), (r, g, b, 255))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=CORNER_RADIUS, fill=255
    )
    img.paste(grad, mask=mask)
    return img


def composite_icon(symbol_bytes: bytes, size: int = ICON_SIZE) -> bytes:
    """Composite transparent symbol onto dark gradient card background."""
    card = make_card_bg(size)
    symbol = Image.open(io.BytesIO(symbol_bytes)).convert("RGBA")

    # Resize symbol to fit with padding (80% of card size)
    inner = int(size * 0.80)
    symbol = symbol.resize((inner, inner), Image.LANCZOS)

    # Center on card
    offset = (size - inner) // 2
    card.paste(symbol, (offset, offset), symbol)

    buf = io.BytesIO()
    card.save(buf, format="PNG")
    return buf.getvalue()


# ── Main generation ────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generate symbolic tower icons via PixelLab")
    parser.add_argument("--towers", type=str, default="",
                        help="Comma-separated tower IDs to generate (default: all)")
    args = parser.parse_args()

    tower_filter = [t.strip() for t in args.towers.split(",") if t.strip()] if args.towers else []

    api_key = load_api_key()
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    })
    palette_b64 = create_palette_swatch()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    towers = {k: v for k, v in TOWER_ICONS.items()
              if not tower_filter or k in tower_filter}

    print(f"\n=== SYMBOLIC TOWER ICONS ({len(towers)}) ===\n")

    for tower_id, prompt in towers.items():
        print(f"  Generating symbolic_{tower_id}...")
        try:
            raw = generate_image(session, palette_b64, prompt, 64, 64)
            clean = remove_background(raw)
            final = composite_icon(clean)
            out_path = OUTPUT_DIR / f"symbolic_tower_{tower_id}.png"
            with open(out_path, "wb") as f:
                f.write(final)
            print(f"  -> {out_path.relative_to(PROJECT_ROOT)}")
            subprocess.Popen(["open", str(out_path)])
        except Exception as e:
            print(f"  ERROR generating {tower_id}: {e}")

    print(f"\nDone. Generated {len(towers)} symbolic icons.")


if __name__ == "__main__":
    main()
