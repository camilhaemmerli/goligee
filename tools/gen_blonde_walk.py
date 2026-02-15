#!/usr/bin/env python3
"""Generate blonde_protestor walk cycle from static sprites.

Creates a 4-frame walk bob: neutral -> lean-forward -> neutral -> lean-back.
Simple but effective for small pixel art at game scale.
"""
import os
from PIL import Image

ENEMY_NAME = "blonde_protestor"
SPRITE_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "enemies", ENEMY_NAME)
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


def create_walk_frames(ref_img: Image.Image) -> list[Image.Image]:
    """Create 4 walk frames from a static reference.

    Frame 1: original (neutral)
    Frame 2: shifted 1px down (foot plant)
    Frame 3: original (neutral, pass-through)
    Frame 4: shifted 1px up (push-off)
    """
    w, h = ref_img.size
    frames = []

    # Frame 1: neutral
    frames.append(ref_img.copy())

    # Frame 2: 1px down (foot plant / weight shift)
    f2 = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    f2.paste(ref_img, (0, 1))
    frames.append(f2)

    # Frame 3: neutral (pass-through)
    frames.append(ref_img.copy())

    # Frame 4: 1px up (push-off / bounce)
    f4 = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Crop top row off the source and paste 1px higher
    cropped = ref_img.crop((0, 1, w, h))
    f4.paste(cropped, (0, 0))
    frames.append(f4)

    return frames


def main():
    total = 0

    for dir_name in DIRS:
        ref_path = os.path.join(SPRITE_DIR, f"walk_{dir_name}_01.png")
        if not os.path.exists(ref_path):
            print(f"  SKIP {dir_name}: no reference sprite")
            continue

        ref_img = Image.open(ref_path).convert("RGBA")
        frames = create_walk_frames(ref_img)

        for frame_idx, frame in enumerate(frames, 1):
            out_path = os.path.join(SPRITE_DIR, f"walk_{dir_name}_{frame_idx:02d}.png")
            frame.save(out_path, "PNG")
            total += 1

        print(f"  walk_{dir_name}: {len(frames)} frames")

    print(f"\nDone! Saved {total} walk frames across {len(DIRS)} directions")
    print("Run 'python tools/sync_assets.py' to update checklist & overview sheets")


if __name__ == "__main__":
    main()
