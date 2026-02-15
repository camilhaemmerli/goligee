"""Generate only the rubber_bullet base (no turrets) with custom prompt."""
from __future__ import annotations
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "tools"))
from generate_assets import (
    PixelLabClient, BASE_NEGATIVE,
    remove_background, save_image, load_api_key,
)

CUSTOM_PROMPT = (
    "16-bit isometric pixel art, isometric 3/4 view, clean pixel grid, no anti-aliasing, "
    "light source from top-left casting shadows to bottom-right, "
    "left faces brightest, right faces mid-tone, bottom faces darkest, "
    "on solid bright magenta #FF00FF background, "
    "very low flat wide isometric trapezoidal platform, wider at bottom narrower at top, "
    "only 10 pixels tall, extremely flat and wide, "
    "dark gunmetal steel with black and yellow diagonal hazard warning stripes on sides, "
    "flat metal plate on top for turret mount, rivets along edges, "
    "isometric diamond ground slab underneath, flush with bottom edge, "
    "no weapon, no turret, no tall structure"
)

def main():
    client = PixelLabClient(load_api_key())
    print(f"Prompt:\n{CUSTOM_PROMPT}\n")
    print("Generating base at 64x64 via PixelLab...")

    img = client.generate_image(
        CUSTOM_PROMPT, 64, 64,
        isometric=True,
        negative_description=BASE_NEGATIVE,
    )
    if img:
        img = remove_background(img)
    save_image(img, "towers/rubber_bullet/base.png")
    print("Done!")

if __name__ == "__main__":
    main()
