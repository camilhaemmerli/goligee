#!/usr/bin/env python3
"""Crop and resize hand-picked tower icons from ~/Downloads/ into symbolic icon PNGs."""

import subprocess
from pathlib import Path
from PIL import Image

ICON_MAP = {
    "rubber_bullet": Path.home() / "Downloads/rubberbullet.jpg",
    "water_cannon":  Path.home() / "Downloads/water.jpg",
    "tear_gas":      Path.home() / "Downloads/gas.jpg",
    "taser_grid":    Path.home() / "Downloads/taser.jpg",
    "pepper_spray":  Path.home() / "Downloads/pepperspray.jpg",
    "lrad":          Path.home() / "Downloads/larp.jpg",
    "surveillance":  Path.home() / "Downloads/surveillance.png",
    "microwave":     Path.home() / "Downloads/microwave.jpg",
}

OUT_DIR = Path(__file__).resolve().parent.parent / "assets/sprites/ui"
OUT_SIZE = 128
CROP_FRACTION = 0.10  # crop 10% from each edge


def process(tower_id: str, src: Path) -> Path:
    img = Image.open(src).convert("RGB")
    w, h = img.size
    inset_x = int(w * CROP_FRACTION)
    inset_y = int(h * CROP_FRACTION)
    img = img.crop((inset_x, inset_y, w - inset_x, h - inset_y))
    img = img.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)
    out_path = OUT_DIR / f"symbolic_tower_{tower_id}.png"
    img.save(out_path)
    print(f"  {tower_id}: {src.name} -> {out_path.name} ({OUT_SIZE}x{OUT_SIZE})")
    return out_path


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    outputs = []
    for tower_id, src in ICON_MAP.items():
        if not src.exists():
            print(f"  SKIP {tower_id}: {src} not found")
            continue
        outputs.append(process(tower_id, src))
    print(f"\nDone — {len(outputs)} icons saved to {OUT_DIR}")
    if outputs:
        subprocess.run(["open", "-a", "Preview"] + [str(p) for p in outputs])


if __name__ == "__main__":
    main()
