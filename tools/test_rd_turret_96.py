"""Quick test: generate rubber_bullet turret at 96px via Retro Diffusion."""
from __future__ import annotations
import os, sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "tools"))
from generate_assets import (
    RetroDiffusionClient, build_turret_prompt, TOWERS,
    remove_background, save_image, _load_env_key,
)

def main():
    key = _load_env_key("RD_API_KEY")
    if not key:
        print("ERROR: RD_API_KEY not found in .env")
        sys.exit(1)

    rd = RetroDiffusionClient(key)
    info = TOWERS["rubber_bullet"]
    prompt = build_turret_prompt(info)
    print(f"Prompt:\n{prompt}\n")
    print("Generating turret at 96x96 via RD...")

    images = rd.generate(prompt, 96, 96, style="rd_pro__isometric", remove_bg=True)
    if not images:
        print("No images returned!")
        return

    img = remove_background(images[0])
    out = PROJECT_ROOT / "assets" / "sprites" / "_debug" / "rd_turret_96.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(img)
    print(f"Saved: {out}")

    import subprocess
    subprocess.run(["open", "-a", "Preview", str(out)])

if __name__ == "__main__":
    main()
