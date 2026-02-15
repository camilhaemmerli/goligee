"""Regenerate only the rubber_bullet turret reference (fast iteration)."""
from __future__ import annotations
import subprocess, sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "tools"))
from generate_assets import (
    PixelLabClient, build_turret_prompt, TOWERS, TURRET_NEGATIVE,
    remove_background, save_image, load_api_key,
)

def main():
    client = PixelLabClient(load_api_key())
    info = TOWERS["rubber_bullet"]
    prompt = build_turret_prompt(info)
    print(f"Prompt:\n{prompt}\n")

    print("Generating turret reference...")
    img = client.generate_image(
        prompt, 64, 64,
        isometric=True,
        negative_description=TURRET_NEGATIVE,
    )
    if img:
        img = remove_background(img)
    save_image(img, "towers/rubber_bullet/turret_ref.png")
    # Open in Preview
    ref_path = PROJECT_ROOT / "assets" / "sprites" / "towers" / "rubber_bullet" / "turret_ref.png"
    subprocess.run(["open", "-a", "Preview", str(ref_path)])
    print("Done! Check Preview.")

if __name__ == "__main__":
    main()
