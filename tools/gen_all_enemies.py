#!/usr/bin/env python3
"""Batch-generate all missing enemy sprites.

For each enemy: generate SE reference -> rotate 8 dirs -> create walk frames.
"""
import sys, os, base64, time
sys.path.insert(0, os.path.dirname(__file__))

from generate_assets import (
    _load_env_key, PixelLabClient, CHAR_PROMPT, NEGATIVE,
    remove_background, CHROMA_BG
)
from PIL import Image, ImageDraw, ImageFont
from io import BytesIO

SPRITE_BASE = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "enemies")
CORRECTED_DIRS = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]

# Refined enemy definitions -- desc, size, stats for .tres
ENEMIES_TO_GEN = {
    "rioter": {
        "desc": "young angry man in torn hoodie and baggy jeans, bandana over face, "
                "clenched fists, lean wiry build, scuffed sneakers, forward-leaning sprint",
        "size": (32, 32),
    },
    "masked": {
        "desc": "protestor in surplus gas mask and improvised tactical vest over black hoodie, "
                "swim goggles pushed up on forehead, heavy boots, cautious crouching walk",
        "size": (32, 32),
    },
    "shield_wall": {
        "desc": "stocky hulking figure carrying large makeshift plywood and sheet-metal riot shield, "
                "construction helmet, knee pads, heavy winter coat, slow determined advance",
        "size": (32, 32),
    },
    "molotov": {
        "desc": "wiry teenager in track jacket, arm cocked back holding glass bottle with lit burning rag, "
                "orange fire glow on face, bandana mask, light and fast on feet",
        "size": (32, 32),
    },
    "drone_op": {
        "desc": "tech-savvy protestor hunched over drone controller, oversized headphones, "
                "tactical backpack bristling with antennas, cargo pants, green screen glow on face",
        "size": (32, 32),
    },
    "street_medic": {
        "desc": "volunteer medic in white armband with red cross, surgical mask, "
                "stuffed medical backpack, latex gloves, running hunched forward with first aid kit",
        "size": (32, 32),
    },
    "armored_van": {
        "desc": "boxy improvised armored vehicle, welded rusty metal plates bolted to old van, "
                "barricade ram on front bumper, narrow viewport slits, dark heavy silhouette, exhaust smoke",
        "size": (48, 48),
    },
    "infiltrator": {
        "desc": "slender figure in dark hoodie pulled low over face, crouched low sneaking pose, "
                "all-black clothing blending into shadow, gloved hands, silent careful steps",
        "size": (32, 32),
    },
    "tunnel_rat": {
        "desc": "hunched small figure in dirty coveralls with mining helmet and headlamp, "
                "dust goggles, pickaxe strapped to back, dust mask, dirt-caked boots",
        "size": (32, 32),
    },
    "journalist": {
        "desc": "reporter in rumpled blazer with bright yellow PRESS vest, "
                "press badge lanyard, holding camera up to eye, determined stride, messenger bag",
        "size": (32, 32),
    },
    "family": {
        "desc": "parent in winter coat holding small child by the hand, child clutching stuffed toy, "
                "both in civilian clothes, protective hunched posture, walking together as one unit",
        "size": (32, 32),
    },
    "student": {
        "desc": "young woman with oversized university hoodie and backpack full of books, "
                "round glasses, jeans and converse sneakers, holding hand-painted protest sign, idealistic stride",
        "size": (32, 32),
    },
}


def generate_enemy(client, name, info):
    """Generate one enemy: SE ref -> 8 rotations -> walk frames."""
    w, h = info["size"]
    ref_path = os.path.join(SPRITE_BASE, name)
    os.makedirs(ref_path, exist_ok=True)

    # Check if already done
    existing = sum(1 for d in CORRECTED_DIRS
                   if os.path.exists(os.path.join(ref_path, f"walk_{d}_01.png")))
    if existing == 8:
        print(f"  {name}: already has 8 directions, skipping")
        return True

    prompt = (
        f"{CHAR_PROMPT}, single character {CHROMA_BG}, "
        f"facing south-east, walking pose, {info['desc']}"
    )
    print(f"  {name}: generating SE reference ({w}x{h})...")

    try:
        img_bytes = client.generate_image(
            prompt, w, h, isometric=True,
            negative_description=NEGATIVE,
        )
    except Exception as e:
        print(f"  {name}: FAILED to generate SE ref: {e}")
        return False

    clean_bytes = remove_background(img_bytes)
    img = Image.open(BytesIO(clean_bytes)).convert("RGBA")
    img.save(os.path.join(ref_path, "walk_se_01.png"))

    # Rotate
    print(f"  {name}: rotating to 8 directions...")
    buf = BytesIO()
    img.save(buf, "PNG")
    ref_b64 = base64.b64encode(buf.getvalue()).decode()

    try:
        rotations = client.rotate_8_directions(ref_b64, w, h, view="low top-down")
    except Exception as e:
        print(f"  {name}: FAILED rotation: {e}")
        return False

    for i, (api_dir, img_data) in enumerate(rotations):
        corrected = CORRECTED_DIRS[i] if i < len(CORRECTED_DIRS) else api_dir
        clean = remove_background(img_data)
        with open(os.path.join(ref_path, f"walk_{corrected}_01.png"), "wb") as f:
            f.write(clean)

    # Walk frames (bob animation)
    for d in CORRECTED_DIRS:
        r = Image.open(os.path.join(ref_path, f"walk_{d}_01.png")).convert("RGBA")
        ww, hh = r.size
        frames = [r.copy()]
        f2 = Image.new("RGBA", (ww, hh), (0, 0, 0, 0))
        f2.paste(r, (0, 1))
        frames.append(f2)
        frames.append(r.copy())
        f4 = Image.new("RGBA", (ww, hh), (0, 0, 0, 0))
        f4.paste(r.crop((0, 1, ww, hh)), (0, 0))
        frames.append(f4)
        for fi, frame in enumerate(frames, 1):
            frame.save(os.path.join(ref_path, f"walk_{d}_{fi:02d}.png"))

    print(f"  {name}: DONE (32 walk frames)")
    return True


def make_preview(name):
    """Create a preview sprite sheet for one enemy."""
    ref_path = os.path.join(SPRITE_BASE, name)
    sample = Image.open(os.path.join(ref_path, "walk_s_01.png"))
    w, h = sample.size
    scale = 4 if w <= 32 else 3
    label_offset = 80
    sheet_w = label_offset + w * 4 * scale + 3 * 2
    sheet_h = h * 8 * scale + 7 * 2
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (40, 40, 40, 255))
    for row, d in enumerate(CORRECTED_DIRS):
        for col in range(4):
            sprite = Image.open(os.path.join(ref_path, f"walk_{d}_{col+1:02d}.png")).convert("RGBA")
            scaled = sprite.resize((w * scale, h * scale), Image.NEAREST)
            sheet.paste(scaled, (label_offset + col * (w * scale + 2), row * (h * scale + 2)), scaled)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 18)
    except Exception:
        font = ImageFont.load_default()
    for row, d in enumerate(CORRECTED_DIRS):
        draw.text((5, row * (h * scale + 2) + (h * scale) // 2 - 10),
                  d.upper(), fill=(255, 255, 255, 255), font=font)
    out = f"/tmp/{name}_spritesheet.png"
    sheet.save(out)
    return out


def main():
    key = _load_env_key("PIXELLAB_API_KEY")
    if not key:
        print("ERROR: No PIXELLAB_API_KEY")
        sys.exit(1)

    client = PixelLabClient(key)
    names = list(ENEMIES_TO_GEN.keys())
    total = len(names)
    succeeded = []
    failed = []

    print(f"\n=== Generating {total} enemies ===\n")

    for i, name in enumerate(names, 1):
        print(f"\n[{i}/{total}] {name}")
        ok = generate_enemy(client, name, ENEMIES_TO_GEN[name])
        if ok:
            succeeded.append(name)
        else:
            failed.append(name)
        # Small delay between enemies to avoid rate limiting
        if i < total:
            time.sleep(2)

    # Generate preview sheets for all succeeded
    print(f"\n=== Generating preview sheets ===\n")
    previews = []
    for name in succeeded:
        p = make_preview(name)
        previews.append(p)
        print(f"  {name}: {p}")

    print(f"\n=== SUMMARY ===")
    print(f"  Succeeded: {len(succeeded)}/{total} -- {', '.join(succeeded)}")
    if failed:
        print(f"  Failed: {len(failed)}/{total} -- {', '.join(failed)}")
    print(f"\nPreview sheets saved to /tmp/*_spritesheet.png")


if __name__ == "__main__":
    main()
