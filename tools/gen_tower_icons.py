#!/usr/bin/env python3
"""Generate simplified tower selection icons for the UI via Retro Diffusion.

Each tower gets a clean symbolic icon at 88x82px with transparent background.
Saved to assets/sprites/ui/.

Usage:
    python3 tools/gen_tower_icons.py
    python3 tools/gen_tower_icons.py --towers rubber_bullet,tear_gas
"""

import argparse
import base64
import io
import os
import subprocess
import sys
import time
from collections import deque
from pathlib import Path

import requests
from PIL import Image

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites"
UI_DIR = SPRITES_DIR / "ui"
ENV_FILE = PROJECT_ROOT / ".env"

RD_API_BASE = "https://api.retrodiffusion.ai/v1"

# ---------------------------------------------------------------------------
# Background removal
# ---------------------------------------------------------------------------

def remove_background(img_bytes: bytes, tolerance: int = 30) -> bytes:
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


# ---------------------------------------------------------------------------
# Tower icon definitions
# ---------------------------------------------------------------------------

TOWER_ICONS = {
    "rubber_bullet": {
        "prompt": "single riot control gun, short barrel launcher with round drum magazine, dark gunmetal silver metal, weapon icon",
    },
    "tear_gas": {
        "prompt": "single tear gas grenade canister with green toxic smoke wisps rising from top, chemical green metal cylinder, weapon icon",
    },
    "taser_grid": {
        "prompt": "single bright blue electric lightning bolt symbol, jagged electricity spark, glowing electric blue, energy icon",
    },
    "water_cannon": {
        "prompt": "single water cannon nozzle with blue pressurized water jet spray stream, industrial chrome nozzle, weapon icon",
    },
    "surveillance": {
        "prompt": "single CCTV security camera with small red recording light dot, dark metal surveillance camera on short mount bracket, tech icon",
    },
    "pepper_spray": {
        "prompt": "single pepper spray aerosol can with orange chemical mist cloud spray, hazmat orange canister, weapon icon",
    },
    "lrad": {
        "prompt": "single large amber orange parabolic speaker dish, concentric sound wave rings emanating forward, acoustic weapon icon",
    },
    "microwave": {
        "prompt": "single flat rectangular directed energy emitter panel, orange glowing heat grid face with heat shimmer waves, tech weapon icon",
    },
}

TARGET_W = 88
TARGET_H = 82
# RD isometric style requires min 96px — generate at 96x96 then crop
GEN_SIZE = 96


def load_rd_key() -> str:
    key = os.environ.get("RD_API_KEY")
    if key:
        return key
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if line.startswith("RD_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("ERROR: Set RD_API_KEY in env or .env")


def generate_icon(session: requests.Session, prompt: str, w: int, h: int) -> bytes:
    """Generate a single icon via Retro Diffusion."""
    full_prompt = (
        f"pixel art game UI icon, clean sharp edges, simplified symbol, "
        f"centered on canvas, dark muted colors, single object, "
        f"front view, {prompt}"
    )

    payload = {
        "prompt": full_prompt,
        "width": w,
        "height": h,
        "num_images": 1,
        "prompt_style": "rd_pro__isometric",
        "remove_bg": True,
    }

    url = f"{RD_API_BASE}/inferences"
    resp = session.post(url, json=payload, timeout=120)
    if resp.status_code == 429:
        print("  Rate limited, waiting 30s...")
        time.sleep(30)
        resp = session.post(url, json=payload, timeout=120)
    if not resp.ok:
        print(f"  RD API error {resp.status_code}: {resp.text[:500]}")
        resp.raise_for_status()

    data = resp.json()
    remaining = data.get("remaining_balance", data.get("remaining_credits", "?"))
    cost = data.get("credit_cost", "?")
    print(f"  Credits: {cost} used, balance: ${remaining}")

    b64_images = data.get("base64_images", [])
    if not b64_images:
        raise RuntimeError("No images in response")

    return base64.b64decode(b64_images[0])


def main():
    parser = argparse.ArgumentParser(description="Generate tower UI icons")
    parser.add_argument("--towers", type=str, default=None,
                        help="Comma-separated tower names (default: all)")
    args = parser.parse_args()

    api_key = load_rd_key()
    session = requests.Session()
    session.headers["X-RD-Token"] = api_key

    UI_DIR.mkdir(parents=True, exist_ok=True)

    tower_names = (
        args.towers.split(",") if args.towers
        else list(TOWER_ICONS.keys())
    )

    total = len(tower_names)
    generated = []

    for i, name in enumerate(tower_names, 1):
        if name not in TOWER_ICONS:
            print(f"  Unknown tower: {name}, skipping")
            continue

        info = TOWER_ICONS[name]
        out_path = UI_DIR / f"icon_{name}.png"
        print(f"\n[{i}/{total}] Generating icon: {name}")

        try:
            img_bytes = generate_icon(session, info["prompt"], GEN_SIZE, GEN_SIZE)

            # Extra background removal pass as fallback
            img_bytes = remove_background(img_bytes, tolerance=40)

            # Crop from center to target size
            img = Image.open(io.BytesIO(img_bytes)).convert("RGBA")
            left = (GEN_SIZE - TARGET_W) // 2
            top = (GEN_SIZE - TARGET_H) // 2
            img = img.crop((left, top, left + TARGET_W, top + TARGET_H))
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            img_bytes = buf.getvalue()

            with open(out_path, "wb") as f:
                f.write(img_bytes)
            print(f"  Saved: {out_path.relative_to(PROJECT_ROOT)}")
            generated.append(out_path)
        except Exception as e:
            print(f"  FAILED: {e}")

    # Open all in Preview
    if generated:
        subprocess.Popen(["open", "-a", "Preview"] + [str(f) for f in generated])

    print(f"\nDone! Generated {len(generated)}/{total} tower icons in {UI_DIR.relative_to(PROJECT_ROOT)}/")


if __name__ == "__main__":
    main()
