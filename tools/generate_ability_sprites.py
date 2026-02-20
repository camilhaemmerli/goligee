#!/usr/bin/env python3
"""Generate sprites for ability vehicles: water cannon truck + airstrike jet.

Uses PixelLab API (pixflux) for isometric pixel art.
Output: assets/sprites/abilities/water_truck.png, jet.png

Usage:
    python3 tools/generate_ability_sprites.py
    python3 tools/generate_ability_sprites.py --num-variants 4
    python3 tools/generate_ability_sprites.py --sprite jet
"""

from __future__ import annotations

import argparse
import base64
import io
import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow required. Run: pip install Pillow")
    sys.exit(1)

try:
    import requests
except ImportError:
    print("ERROR: requests required. Run: pip install requests")
    sys.exit(1)


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites" / "abilities"
ENV_FILE = PROJECT_ROOT / ".env"
PALETTE_CACHE = PROJECT_ROOT / "tools" / ".palette_swatch.png"

PL_API_BASE = "https://api.pixellab.ai/v2"

CHROMA_BG = "on solid bright magenta #FF00FF background"

PALETTE_COLORS = [
    "#0E0E12", "#161618", "#1A1A1E", "#1E1E22", "#28282C", "#2E2E32",
    "#3A3A3E", "#484850", "#585860", "#606068", "#808898",
    "#C8A040", "#D8A040", "#E8A040", "#D06030", "#D04040", "#903020",
    "#5080A0", "#3868A0",
    "#D06040", "#A84030", "#802818", "#E89060",
    "#F0E0C0", "#70A040", "#50A0D0", "#6090B0",
    "#A0D8A0", "#88C888", "#9A9AA0",
]

# -- Sprite definitions --

SPRITES = {
    "water_truck": {
        "prompt": (
            f"8-bit isometric pixel art, single large blue police water cannon truck {CHROMA_BG}, "
            "bright blue boxy 6-wheeled Wasserwerfer truck, twin water cannon turrets on roof, "
            "large rectangular water tank body, cab with windshield on front right, "
            "six big black wheels three axles, sloped rear, rooftop spotlights, "
            "blue steel panels, heavy duty riot control vehicle"
        ),
        "negative": "person, character, building, ground, shadow, text, UI, scenery, trees, road",
        "width": 128,
        "height": 128,
        "filename": "water_truck.png",
    },
    "jet": {
        "prompt": (
            f"8-bit isometric pixel art, single military fighter jet aircraft {CHROMA_BG}, "
            "dark gunmetal gray angular stealth jet, swept delta wings, "
            "small glass canopy cockpit, twin engine exhaust orange glow, "
            "underside weapon pylons, sharp angular nose, tactical strike aircraft"
        ),
        "negative": "person, character, building, ground, shadow, text, UI, runway, scenery",
        "width": 128,
        "height": 96,
        "filename": "jet.png",
    },
}


def hex_to_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def create_palette_swatch() -> str:
    """Create palette swatch image as base64."""
    if PALETTE_CACHE.exists():
        with open(PALETTE_CACHE, "rb") as f:
            return base64.b64encode(f.read()).decode()
    cols = len(PALETTE_COLORS)
    img = Image.new("RGB", (cols, 1))
    for i, c in enumerate(PALETTE_COLORS):
        img.putpixel((i, 0), hex_to_rgb(c))
    img = img.resize((cols * 4, 4), Image.NEAREST)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    PALETTE_CACHE.parent.mkdir(parents=True, exist_ok=True)
    with open(PALETTE_CACHE, "wb") as f:
        f.write(buf.getvalue())
    return base64.b64encode(buf.getvalue()).decode()


def load_api_key() -> str:
    """Load PixelLab API key from .env file."""
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    key = os.environ.get("PIXELLAB_API_KEY", "")
    if not key:
        print("ERROR: PIXELLAB_API_KEY not found in .env or environment.")
        sys.exit(1)
    return key


def pl_generate(api_key: str, palette_b64: str, prompt: str, width: int, height: int,
                negative: str = "", seed: int | None = None) -> bytes:
    """Generate image via PixelLab pixflux endpoint."""
    session = requests.Session()
    session.headers["Authorization"] = f"Bearer {api_key}"
    session.headers["Content-Type"] = "application/json"

    payload = {
        "description": prompt,
        "image_size": {"width": max(width, 32), "height": max(height, 32)},
        "isometric": True,
        "color_image": {"base64": palette_b64},
        "text_guidance_scale": 8.0,
    }
    if negative:
        payload["negative_description"] = negative
    if seed is not None:
        payload["seed"] = seed

    url = f"{PL_API_BASE}/create-image-pixflux"
    print(f"  Calling PixelLab API ({width}x{height})...")
    resp = session.post(url, json=payload, timeout=120)
    if resp.status_code == 429:
        print("  Rate limited, waiting 30s...")
        import time
        time.sleep(30)
        resp = session.post(url, json=payload, timeout=120)
    if not resp.ok:
        print(f"  API error {resp.status_code}: {resp.text[:500]}")
        resp.raise_for_status()

    data = resp.json()
    # Extract image from response
    img_b64 = data.get("image", {}).get("base64", "")
    if not img_b64:
        print(f"  Warning: no image in response. Keys: {list(data.keys())}")
        # Try alternate formats
        for key in ("base64_image", "result", "output"):
            if key in data and isinstance(data[key], str):
                img_b64 = data[key]
                break
    if not img_b64:
        raise RuntimeError(f"No image in response: {list(data.keys())}")

    return base64.b64decode(img_b64)


def remove_background(img_bytes: bytes, tolerance: int = 40) -> bytes:
    """Remove magenta chroma-key background via flood-fill from corners."""
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

    # Magenta bg (#FF00FF) has high brightness -- use generous tolerance
    bg_brightness = sum(bg_color)
    if bg_brightness > 400:  # Bright magenta
        tolerance = 60
    elif bg_brightness < 90:  # Dark bg -- tight tolerance
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
    img.save(buf, "PNG")
    return buf.getvalue()


def generate_overview(images: dict[str, list[bytes]], out_dir: Path) -> None:
    """Generate a combined overview sheet of all variants."""
    all_imgs = []
    for name, variants in images.items():
        for img_bytes in variants:
            img = Image.open(io.BytesIO(img_bytes)).convert("RGBA")
            all_imgs.append(img)

    if not all_imgs:
        return

    cols = min(len(all_imgs), 4)
    rows = (len(all_imgs) + cols - 1) // cols
    pad = 4
    max_w = max(img.width for img in all_imgs)
    max_h = max(img.height for img in all_imgs)
    cell_w = max_w + pad * 2
    cell_h = max_h + pad * 2

    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (30, 30, 34, 255))
    for idx, img in enumerate(all_imgs):
        c = idx % cols
        r = idx // cols
        x = c * cell_w + pad + (max_w - img.width) // 2
        y = r * cell_h + pad + (max_h - img.height) // 2
        sheet.paste(img, (x, y), img)

    overview_path = out_dir / "_overview.png"
    sheet.save(overview_path, "PNG")
    print(f"  Overview sheet: {overview_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate ability vehicle sprites")
    parser.add_argument("--num-variants", type=int, default=4,
                        help="Number of variants per sprite (default: 4)")
    parser.add_argument("--sprite", type=str, default=None,
                        help="Generate only a specific sprite (water_truck, jet)")
    args = parser.parse_args()

    api_key = load_api_key()
    palette_b64 = create_palette_swatch()
    SPRITES_DIR.mkdir(parents=True, exist_ok=True)

    sprites_to_generate = SPRITES
    if args.sprite:
        if args.sprite not in SPRITES:
            print(f"ERROR: Unknown sprite '{args.sprite}'. Choose from: {', '.join(SPRITES.keys())}")
            sys.exit(1)
        sprites_to_generate = {args.sprite: SPRITES[args.sprite]}

    all_images: dict[str, list[bytes]] = {}

    for name, spec in sprites_to_generate.items():
        print(f"\n=== Generating {name} ({args.num_variants} variants) ===")
        print(f"  Prompt: {spec['prompt'][:80]}...")

        processed = []
        for i in range(args.num_variants):
            try:
                raw = pl_generate(
                    api_key, palette_b64,
                    spec["prompt"],
                    spec["width"],
                    spec["height"],
                    negative=spec.get("negative", ""),
                    seed=None,  # Random each time for variety
                )
                cleaned = remove_background(raw)
                processed.append(cleaned)

                # Save variant
                variant_name = spec["filename"].replace(".png", f"_v{i}.png")
                variant_path = SPRITES_DIR / variant_name
                with open(variant_path, "wb") as f:
                    f.write(cleaned)
                print(f"  Saved variant {i}: {variant_path}")
            except Exception as e:
                print(f"  ERROR generating variant {i}: {e}")

        all_images[name] = processed

        # Save first variant as default
        if processed:
            default_path = SPRITES_DIR / spec["filename"]
            with open(default_path, "wb") as f:
                f.write(processed[0])
            print(f"  Default: {default_path}")

    # Generate overview sheet
    if all_images:
        generate_overview(all_images, SPRITES_DIR)

    print(f"\nDone! Review variants in: {SPRITES_DIR}")
    print("Pick the best variant and rename it to the default filename.")
    print("Then run: open -a Preview " + str(SPRITES_DIR / "_overview.png"))


if __name__ == "__main__":
    main()
