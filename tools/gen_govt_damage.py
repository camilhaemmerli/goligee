#!/usr/bin/env python3
"""Generate 5 damage-state variants of the government building.

Derives all variants from the pristine sprite using pixel-level
manipulations appropriate for pixel art (no smooth filters).

Usage:
    python3 tools/gen_govt_damage.py [--force]
"""

import sys
import random
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites"
BUILDINGS_DIR = SPRITES_DIR / "buildings"
SRC = BUILDINGS_DIR / "building_government_dome.png"


def load() -> np.ndarray:
    """Load source as RGBA uint8 array."""
    return np.array(Image.open(SRC).convert("RGBA"))


def opaque(arr: np.ndarray) -> np.ndarray:
    """Boolean mask of opaque pixels."""
    return arr[:, :, 3] > 10


def erode_edge(mask: np.ndarray, iterations: int = 1) -> np.ndarray:
    """Find pixels on the edge of the opaque region."""
    eroded = ndimage.binary_erosion(mask, iterations=iterations)
    return mask & ~eroded


def save(arr: np.ndarray, name: str):
    out = BUILDINGS_DIR / name
    Image.fromarray(arr.astype(np.uint8)).save(out)
    print(f"    Saved: {out.relative_to(PROJECT_ROOT)}")


# -- Damage effects ----------------------------------------------------------

def add_graffiti(arr: np.ndarray, seed: int = 42) -> np.ndarray:
    """Small rectangular pixel blocks of color on wall areas."""
    rng = random.Random(seed)
    result = arr.copy()
    mask = opaque(arr)
    h, w = mask.shape
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return result

    # Only target the middle/lower portion (walls, not dome or fence base)
    y_min, y_max = ys.min(), ys.max()
    y_range = y_max - y_min
    wall_top = y_min + int(y_range * 0.35)  # skip dome area
    wall_bot = y_max - int(y_range * 0.12)  # skip fence/base

    colors = [
        (180, 40, 40),   # red
        (40, 160, 40),   # green
        (200, 170, 30),  # yellow
        (40, 40, 180),   # blue
        (180, 80, 30),   # orange
    ]

    for _ in range(18):
        # Pick a random opaque pixel in wall zone
        attempts = 0
        while attempts < 50:
            idx = rng.randint(0, len(xs) - 1)
            px, py = int(xs[idx]), int(ys[idx])
            if wall_top <= py <= wall_bot:
                break
            attempts += 1

        color = rng.choice(colors)
        bw = rng.choice([2, 3, 4])
        bh = rng.choice([2, 3])

        for dy in range(bh):
            for dx in range(bw):
                ny, nx = py + dy, px + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx]:
                    result[ny, nx, :3] = color
                    result[ny, nx, 3] = 220

    return result


def add_cracks(arr: np.ndarray, count: int = 8, max_len: int = 25,
               seed: int = 42) -> np.ndarray:
    """Pixel-grid-aligned jagged dark cracks."""
    rng = random.Random(seed)
    result = arr.copy()
    mask = opaque(arr)
    h, w = mask.shape
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return result

    crack_color = np.array([25, 20, 18, 230], dtype=np.uint8)

    for _ in range(count):
        idx = rng.randint(0, len(xs) - 1)
        cx, cy = int(xs[idx]), int(ys[idx])

        for _ in range(max_len):
            if 0 <= cy < h and 0 <= cx < w and mask[cy, cx]:
                result[cy, cx] = crack_color
                # Make cracks 2px wide sometimes
                if rng.random() > 0.5 and cx + 1 < w and mask[cy, cx + 1]:
                    result[cy, cx + 1] = crack_color

            # Move in pixel-grid directions (down-biased)
            direction = rng.choice([
                (0, 1), (0, 1), (0, 1),   # down (most common)
                (1, 1), (-1, 1),            # diagonal down
                (1, 0), (-1, 0),            # horizontal
            ])
            cx += direction[0]
            cy += direction[1]

    return result


def darken_dithered(arr: np.ndarray, intensity: float = 0.3,
                    seed: int = 42) -> np.ndarray:
    """Darken opaque pixels using a dithered checkerboard pattern."""
    rng = np.random.RandomState(seed)
    result = arr.astype(np.float32)
    mask = opaque(arr)
    h, w = mask.shape

    # Checkerboard dither: only darken ~50% of pixels
    checker = np.indices((h, w)).sum(axis=0) % 2 == 0
    darken_mask = mask & checker

    # Random per-pixel darken amount
    amount = rng.uniform(1.0 - intensity, 1.0, size=(h, w))
    for c in range(3):
        result[:, :, c] = np.where(darken_mask, result[:, :, c] * amount, result[:, :, c])

    return np.clip(result, 0, 255).astype(np.uint8)


def erode_pixels(arr: np.ndarray, iterations: int = 2, seed: int = 42) -> np.ndarray:
    """Remove random pixels from edges of the building silhouette."""
    rng = np.random.RandomState(seed)
    result = arr.copy()
    mask = opaque(arr)

    edge = erode_edge(mask, iterations=1)
    # Remove a random fraction of edge pixels
    edge_ys, edge_xs = np.where(edge)
    n_remove = int(len(edge_xs) * 0.4 * iterations)
    indices = rng.choice(len(edge_xs), size=min(n_remove, len(edge_xs)), replace=False)
    for i in indices:
        result[edge_ys[i], edge_xs[i], 3] = 0

    if iterations > 1:
        # Second pass: erode from the new edge
        mask2 = result[:, :, 3] > 10
        edge2 = erode_edge(mask2, iterations=1)
        edge_ys2, edge_xs2 = np.where(edge2)
        n_remove2 = int(len(edge_xs2) * 0.25 * (iterations - 1))
        if len(edge_xs2) > 0:
            indices2 = rng.choice(len(edge_xs2), size=min(n_remove2, len(edge_xs2)), replace=False)
            for i in indices2:
                result[edge_ys2[i], edge_xs2[i], 3] = 0

    return result


def break_windows(arr: np.ndarray, seed: int = 42) -> np.ndarray:
    """Darken some of the lighter interior pixels (simulates broken windows)."""
    rng = np.random.RandomState(seed)
    result = arr.copy()
    mask = opaque(arr)

    # Find relatively bright pixels (windows tend to be brighter)
    brightness = arr[:, :, :3].mean(axis=2)
    bright_mask = mask & (brightness > 120)
    ys, xs = np.where(bright_mask)

    if len(xs) == 0:
        return result

    n_break = int(len(xs) * 0.3)
    indices = rng.choice(len(xs), size=min(n_break, len(xs)), replace=False)
    for i in indices:
        result[ys[i], xs[i], :3] = [20, 18, 25]  # dark broken window

    return result


def collapse_right_half(arr: np.ndarray, seed: int = 99) -> np.ndarray:
    """Remove the right portion with a jagged vertical cut, keep left standing."""
    rng = random.Random(seed)
    result = arr.copy()
    mask = opaque(arr)
    h, w = mask.shape

    # Find the horizontal center of the actual building content
    ys, xs = np.where(mask)
    x_min, x_max = xs.min(), xs.max()
    x_mid = x_min + int((x_max - x_min) * 0.55)  # slightly right of center

    # Jagged cut line
    cut_x = [x_mid + rng.randint(-6, 6) for _ in range(h)]

    for y in range(h):
        for x in range(cut_x[y], w):
            result[y, x, 3] = 0

    # Darken pixels near the cut edge (exposed interior)
    for y in range(h):
        for dx in range(-8, 0):
            x = cut_x[y] + dx
            if 0 <= x < w and result[y, x, 3] > 10:
                factor = 0.4 + 0.06 * abs(dx)  # darker closer to edge
                result[y, x, :3] = np.clip(result[y, x, :3].astype(float) * factor, 0, 255).astype(np.uint8)

    # Scatter some debris pixels below the cut area
    y_max = ys.max()
    for _ in range(40):
        dy = rng.randint(-3, 5)
        dx = rng.randint(-15, 15)
        rx = x_mid + dx
        ry = y_max - rng.randint(0, 6) + dy
        if 0 <= ry < h and 0 <= rx < w and result[ry, rx, 3] == 0:
            gray = rng.randint(50, 90)
            result[ry, rx] = [gray, gray - 3, gray - 8, 200]

    return result


def make_rubble(arr: np.ndarray, seed: int = 42) -> np.ndarray:
    """Keep only the bottom portion, heavily darken and add debris."""
    rng = np.random.RandomState(seed)
    result = arr.copy()
    mask = opaque(arr)
    h, w = mask.shape
    ys, xs = np.where(mask)

    if len(xs) == 0:
        return result

    y_min, y_max = ys.min(), ys.max()
    y_range = y_max - y_min

    # Keep bottom 25%
    y_cut = y_max - int(y_range * 0.25)
    result[:y_cut, :, 3] = 0

    # Jagged top edge on remaining
    py_rng = random.Random(seed)
    for x in range(w):
        jitter = py_rng.randint(-4, 4)
        for y in range(max(0, y_cut + jitter)):
            result[y, x, 3] = 0

    # Heavily darken remaining
    remaining = result[:, :, 3] > 10
    result[remaining, :3] = np.clip(
        result[remaining, :3].astype(float) * 0.45, 0, 255
    ).astype(np.uint8)

    # Add noise to remaining pixels
    noise = rng.randint(-15, 15, size=(h, w, 3))
    rem_mask = result[:, :, 3] > 10
    result[rem_mask, :3] = np.clip(
        result[rem_mask, :3].astype(int) + noise[rem_mask], 0, 255
    ).astype(np.uint8)

    # Scatter debris around the rubble area
    x_min, x_max = xs.min(), xs.max()
    x_mid = (x_min + x_max) // 2
    for _ in range(80):
        dx = rng.randint(-30, 30)
        dy = rng.randint(-8, 4)
        rx = x_mid + dx
        ry = y_max + dy
        if 0 <= ry < h and 0 <= rx < w:
            gray = rng.randint(35, 80)
            result[ry, rx] = [gray, gray - 3, gray - 7, 180 + rng.randint(0, 50)]

    return result


# -- Main pipeline ------------------------------------------------------------

def generate_all(force: bool = False):
    src = load()
    print(f"  Source: {SRC.name} ({src.shape[1]}x{src.shape[0]})")

    stages = [
        ("dmg1", "graffiti"),
        ("dmg2", "cracks"),
        ("dmg3", "heavy damage"),
        ("dmg4", "half destroyed"),
        ("dmg5", "rubble"),
    ]

    for key, label in stages:
        out = BUILDINGS_DIR / f"building_government_dome_{key}.png"
        if out.exists() and not force:
            print(f"  Skipping {key} ({label}) -- exists")
            continue

        print(f"  Generating {key} ({label})...", flush=True)

        if key == "dmg1":
            result = add_graffiti(src, seed=42)
            result = add_cracks(result, count=3, max_len=12, seed=100)

        elif key == "dmg2":
            result = add_cracks(src, count=10, max_len=22, seed=200)
            result = break_windows(result, seed=201)
            result = darken_dithered(result, intensity=0.12, seed=202)
            result = erode_pixels(result, iterations=1, seed=203)

        elif key == "dmg3":
            result = add_cracks(src, count=20, max_len=35, seed=300)
            result = break_windows(result, seed=301)
            result = darken_dithered(result, intensity=0.3, seed=302)
            result = erode_pixels(result, iterations=3, seed=303)

        elif key == "dmg4":
            result = collapse_right_half(src, seed=400)
            result = add_cracks(result, count=15, max_len=25, seed=401)
            result = darken_dithered(result, intensity=0.35, seed=402)
            result = erode_pixels(result, iterations=2, seed=403)

        elif key == "dmg5":
            result = make_rubble(src, seed=500)

        save(result, f"building_government_dome_{key}.png")

    print("\n  Done!")


def main():
    force = "--force" in sys.argv
    print("\n=== GOVERNMENT BUILDING DAMAGE VARIANTS ===\n")
    generate_all(force)

    print("\n  Running asset sync...")
    import subprocess
    subprocess.run([sys.executable, str(PROJECT_ROOT / "tools" / "sync_assets.py")],
                   cwd=str(PROJECT_ROOT))


if __name__ == "__main__":
    main()
