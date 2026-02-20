#!/usr/bin/env python3
"""Generate 8-direction rotations for ability sprites (water truck + jet).

Uses PixelLab's generate-8-rotations-v2 endpoint.
Input sprites are downscaled to 64px for the API, then bg-removed and saved.

Usage:
    python3 tools/rotate_ability_sprites.py
    python3 tools/rotate_ability_sprites.py --sprite jet
"""

from __future__ import annotations

import argparse
import base64
import io
import os
import sys
import time
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

PL_API_BASE = "https://api.pixellab.ai/v2"

# API returns [s, sw, w, nw, n, ne, e, se] but E/W axis is flipped.
# Corrected labels for indices 0-7:
CORRECTED_DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

SPRITES = {
    "water_truck": {
        "source": SPRITES_DIR / "water_truck.png",
        "rot_size": (64, 64),
    },
    "jet": {
        "source": SPRITES_DIR / "jet.png",
        "rot_size": (64, 48),
    },
}


def load_api_key() -> str:
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


def downscale_to_rotation_size(src_path: Path, target_w: int, target_h: int) -> bytes:
    """Load sprite, downscale, and pad to square for rotation API."""
    img = Image.open(src_path).convert("RGBA")
    if img.width != target_w or img.height != target_h:
        img = img.resize((target_w, target_h), Image.NEAREST)
        print(f"  Downscaled {src_path.name}: {img.width}x{img.height} -> {target_w}x{target_h}")
    # API requires square images -- pad to square if needed
    if target_w != target_h:
        sq = max(target_w, target_h)
        padded = Image.new("RGBA", (sq, sq), (0, 0, 0, 0))
        ox = (sq - target_w) // 2
        oy = (sq - target_h) // 2
        padded.paste(img, (ox, oy), img)
        img = padded
        print(f"  Padded to square: {sq}x{sq}")
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


def img_to_b64(img_bytes: bytes) -> str:
    return base64.b64encode(img_bytes).decode()


def rgba_to_png(img_obj: dict) -> bytes:
    """Convert raw RGBA byte data from the API to a PNG file."""
    raw = base64.b64decode(img_obj["base64"])
    w = img_obj.get("width", 32)
    h = img_obj.get("height", 32)
    try:
        img = Image.frombytes("RGBA", (w, h), raw)
    except ValueError:
        return raw
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


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

    bg_brightness = sum(bg_color)
    if bg_brightness > 400:
        tolerance = 60
    elif bg_brightness < 90:
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


def api_post(session: requests.Session, endpoint: str, payload: dict) -> dict:
    url = f"{PL_API_BASE}/{endpoint}"
    resp = session.post(url, json=payload, timeout=480)
    if resp.status_code == 429:
        print("  Rate limited, waiting 30s...")
        time.sleep(30)
        resp = session.post(url, json=payload, timeout=480)
    if not resp.ok:
        print(f"  API error {resp.status_code}: {resp.text[:500]}")
        resp.raise_for_status()
    return resp.json()


def api_get(session: requests.Session, endpoint: str) -> dict:
    url = f"{PL_API_BASE}/{endpoint}"
    resp = session.get(url, timeout=60)
    resp.raise_for_status()
    return resp.json()


def wait_for_job(session: requests.Session, job_id: str,
                 poll_interval: float = 5.0, max_wait: float = 600.0) -> dict:
    elapsed = 0.0
    while elapsed < max_wait:
        result = api_get(session, f"background-jobs/{job_id}")
        status = result.get("status", "")
        if status == "completed":
            return result
        if status == "failed":
            raise RuntimeError(f"Job {job_id} failed: {result}")
        time.sleep(poll_interval)
        elapsed += poll_interval
        print(f"  Waiting for job {job_id}... ({elapsed:.0f}s)")
    raise TimeoutError(f"Job {job_id} did not complete in {max_wait}s")


def extract_rotation_images(result: dict) -> list[tuple[str, bytes]]:
    DIR_NAMES = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
    images = []

    last_resp = result.get("last_response", {})
    if isinstance(last_resp, dict):
        img_list = last_resp.get("rotation_images") or last_resp.get("images") or []
        for i, img_obj in enumerate(img_list):
            if i >= 8:
                break
            direction = DIR_NAMES[i] if i < len(DIR_NAMES) else f"dir{i}"
            if isinstance(img_obj, dict) and img_obj.get("base64"):
                images.append((direction, rgba_to_png(img_obj)))
            elif isinstance(img_obj, str):
                images.append((direction, base64.b64decode(img_obj)))
        if images:
            return images

    for key in ("rotation_images", "images", "directions"):
        img_list = result.get(key, [])
        if not img_list:
            continue
        for i, img_obj in enumerate(img_list):
            if i >= 8:
                break
            direction = DIR_NAMES[i] if i < len(DIR_NAMES) else f"dir{i}"
            if isinstance(img_obj, dict):
                if img_obj.get("base64"):
                    images.append((direction, rgba_to_png(img_obj)))
                elif img_obj.get("image", {}).get("base64"):
                    images.append((direction, rgba_to_png(img_obj["image"])))
            elif isinstance(img_obj, str):
                images.append((direction, base64.b64decode(img_obj)))
        if images:
            return images

    return images


def generate_rotations(session: requests.Session, ref_b64: str,
                       width: int, height: int) -> list[tuple[str, bytes]]:
    payload = {
        "reference_image": {
            "image": {"base64": ref_b64},
            "width": width,
            "height": height,
        },
        "image_size": {"width": width, "height": height},
        "view": "low top-down",
        "method": "rotate_character",
    }
    result = api_post(session, "generate-8-rotations-v2", payload)
    job_id = result.get("background_job_id") or result.get("job_id")
    if job_id:
        result = wait_for_job(session, job_id)
    return extract_rotation_images(result)


def generate_overview(sprite_name: str, dir_images: dict[str, bytes], out_dir: Path) -> None:
    """Generate an overview grid of all 8 directions."""
    dirs_order = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
    imgs = []
    for d in dirs_order:
        if d in dir_images:
            imgs.append((d, Image.open(io.BytesIO(dir_images[d])).convert("RGBA")))

    if not imgs:
        return

    cols = 4
    rows = 2
    pad = 4
    max_w = max(img.width for _, img in imgs)
    max_h = max(img.height for _, img in imgs)
    cell_w = max_w + pad * 2
    cell_h = max_h + pad * 2

    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (30, 30, 34, 255))
    for idx, (d, img) in enumerate(imgs):
        c = idx % cols
        r = idx // cols
        x = c * cell_w + pad + (max_w - img.width) // 2
        y = r * cell_h + pad + (max_h - img.height) // 2
        sheet.paste(img, (x, y), img)

    overview_path = out_dir / f"{sprite_name}_rotations.png"
    sheet.save(overview_path, "PNG")
    print(f"  Overview: {overview_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate 8-direction ability sprites")
    parser.add_argument("--sprite", type=str, default=None,
                        help="Generate only a specific sprite (water_truck, jet)")
    args = parser.parse_args()

    api_key = load_api_key()
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    })

    sprites_to_process = SPRITES
    if args.sprite:
        if args.sprite not in SPRITES:
            print(f"ERROR: Unknown sprite '{args.sprite}'. Choose from: {', '.join(SPRITES.keys())}")
            sys.exit(1)
        sprites_to_process = {args.sprite: SPRITES[args.sprite]}

    for name, spec in sprites_to_process.items():
        print(f"\n=== Rotating {name} ===")
        src = spec["source"]
        rot_w, rot_h = spec["rot_size"]

        if not src.exists():
            print(f"  ERROR: Source sprite not found: {src}")
            continue

        # Create subfolder for directional sprites
        out_dir = SPRITES_DIR / name
        out_dir.mkdir(parents=True, exist_ok=True)

        # Downscale for rotation API (padded to square)
        ref_bytes = downscale_to_rotation_size(src, rot_w, rot_h)
        sq_size = max(rot_w, rot_h)
        ref_b64 = img_to_b64(ref_bytes)

        print(f"  Calling PixelLab rotation API ({sq_size}x{sq_size})...")
        try:
            rotations = generate_rotations(session, ref_b64, sq_size, sq_size)
        except Exception as e:
            print(f"  ERROR: {e}")
            print(f"  Falling back: copying source as all 8 directions")
            for d in ["s", "sw", "w", "nw", "n", "ne", "e", "se"]:
                out_path = out_dir / f"{d}.png"
                out_path.write_bytes(ref_bytes)
            continue

        print(f"  Got {len(rotations)} rotations")

        # Apply direction correction (E/W axis flip) and save
        dir_images = {}
        for i, (api_dir, img_data) in enumerate(rotations):
            corrected_dir = CORRECTED_DIRS[i] if i < len(CORRECTED_DIRS) else api_dir

            # Remove background
            img_data = remove_background(img_data)

            out_path = out_dir / f"{corrected_dir}.png"
            out_path.write_bytes(img_data)
            dir_images[corrected_dir] = img_data
            print(f"  Saved: {corrected_dir}.png")

        # Generate overview
        generate_overview(name, dir_images, SPRITES_DIR)

    print("\nDone! Review rotations in subdirectories.")
    print("Then run: open -a Preview " + str(SPRITES_DIR))


if __name__ == "__main__":
    main()
