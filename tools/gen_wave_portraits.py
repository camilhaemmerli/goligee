#!/usr/bin/env python3
"""Generate wave leader bust portraits via PixelLab API.

Generates 10 unique 64x64 pixel art bust portraits (displayed at 32x32 in-game).
Uses chroma-key magenta background technique per project conventions.

Usage:
    python tools/gen_wave_portraits.py
    python tools/gen_wave_portraits.py --leaders rioter,masked
"""

import argparse
import base64
import io
import json
import os
import sys
import time
from pathlib import Path

try:
    import requests
    from PIL import Image
except ImportError:
    print("ERROR: pip install requests pillow")
    sys.exit(1)

# Project root
ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "assets" / "sprites" / "ui"

# PixelLab API
MCP_JSON = ROOT / ".mcp.json"
API_BASE = "https://api.pixellab.ai/v1"

CHROMA_BG = "on solid bright magenta #FF00FF background"

# Leader portrait prompts (bust/headshot descriptions)
LEADER_PROMPTS = {
    "rioter": "angry young man, red bandana over mouth, torn black jacket, punk hairstyle",
    "masked": "balaclava figure, only eyes visible, dark hoodie, menacing stare",
    "shield_wall": "gas mask figure, makeshift wooden shield, heavy jacket, riot gear",
    "union_boss": "burly middle-aged man, thick brown mustache, yellow hard hat, holding megaphone",
    "grandma": "elderly woman, gray hair in bun, round glasses, floral shawl, stern face",
    "goth_protestor": "goth girl, black lipstick, spiked collar, dark eyeliner, pale skin",
    "blonde_protestor": "young blonde woman, ponytail, holding phone filming, determined expression",
    "armored_van": "front view battered van with welded steel armor plates, headlights glowing",
    "student": "young person with round glasses, backpack straps visible, holding textbook",
    "infiltrator": "shadowy figure, hoodie pulled low over face, black gloves, mysterious",
}


def get_api_key() -> str:
    """Read PixelLab API key from .mcp.json."""
    if MCP_JSON.exists():
        data = json.loads(MCP_JSON.read_text())
        servers = data.get("mcpServers", {})
        pl = servers.get("pixellab", {})
        env = pl.get("env", {})
        key = env.get("PIXELLAB_API_KEY", "")
        if key:
            return key
    # Fallback to env var
    return os.environ.get("PIXELLAB_API_KEY", "")


def remove_background(img: Image.Image) -> Image.Image:
    """Remove magenta chroma-key background via flood fill from corners."""
    img = img.convert("RGBA")
    pixels = img.load()
    w, h = img.size
    target = (255, 0, 255)
    threshold = 80

    visited = set()
    queue = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for seed in queue:
        visited.add(seed)

    while queue:
        x, y = queue.pop(0)
        r, g, b, a = pixels[x, y]
        dist = abs(r - target[0]) + abs(g - target[1]) + abs(b - target[2])
        if dist < threshold:
            pixels[x, y] = (0, 0, 0, 0)
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    queue.append((nx, ny))
    return img


def generate_portrait(api_key: str, leader_id: str, prompt_desc: str) -> Image.Image | None:
    """Generate a single portrait via PixelLab generate-image endpoint."""
    full_prompt = f"pixel art bust portrait, 8-bit retro style, {prompt_desc}, {CHROMA_BG}"

    payload = {
        "prompt": full_prompt,
        "negative_prompt": "background details, scenery, full body, legs, weapons, text",
        "width": 64,
        "height": 64,
        "steps": 30,
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    print(f"  Generating {leader_id}...")
    try:
        resp = requests.post(f"{API_BASE}/generate-image", json=payload, headers=headers, timeout=60)
        resp.raise_for_status()
        data = resp.json()

        if "image" in data:
            img_data = base64.b64decode(data["image"])
            img = Image.open(io.BytesIO(img_data))
            return img
        elif "images" in data and data["images"]:
            img_data = base64.b64decode(data["images"][0])
            img = Image.open(io.BytesIO(img_data))
            return img
        else:
            print(f"  WARNING: No image in response for {leader_id}")
            return None
    except Exception as e:
        print(f"  ERROR generating {leader_id}: {e}")
        return None


def main():
    parser = argparse.ArgumentParser(description="Generate wave leader portraits")
    parser.add_argument("--leaders", type=str, default="",
                        help="Comma-separated list of leader IDs to generate (default: all)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print prompts without generating")
    args = parser.parse_args()

    api_key = get_api_key()
    if not api_key and not args.dry_run:
        print("ERROR: No PixelLab API key found in .mcp.json or PIXELLAB_API_KEY env var")
        sys.exit(1)

    # Filter leaders
    if args.leaders:
        leader_ids = [l.strip() for l in args.leaders.split(",")]
    else:
        leader_ids = list(LEADER_PROMPTS.keys())

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for leader_id in leader_ids:
        if leader_id not in LEADER_PROMPTS:
            print(f"WARNING: Unknown leader '{leader_id}', skipping")
            continue

        output_path = OUTPUT_DIR / f"wave_portrait_{leader_id}.png"
        if output_path.exists():
            print(f"  SKIP {leader_id} (already exists)")
            continue

        prompt_desc = LEADER_PROMPTS[leader_id]
        if args.dry_run:
            full_prompt = f"pixel art bust portrait, 8-bit retro style, {prompt_desc}, {CHROMA_BG}"
            print(f"  {leader_id}: {full_prompt}")
            continue

        img = generate_portrait(api_key, leader_id, prompt_desc)
        if img:
            img = remove_background(img)
            img.save(str(output_path))
            print(f"  SAVED {output_path.name}")
            time.sleep(1)  # Rate limit courtesy

    print("Done!")


if __name__ == "__main__":
    main()
