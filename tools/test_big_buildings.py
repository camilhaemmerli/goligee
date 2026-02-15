#!/usr/bin/env python3
"""Generate floor structures, props, and more buildings via PixelLab pixflux + Retro Diffusion."""
from __future__ import annotations
import base64, io, os, sys, time
from pathlib import Path
from PIL import Image
import requests

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites"
ENV_FILE = PROJECT_ROOT / ".env"

def load_env_key(name):
    if name in os.environ: return os.environ[name]
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if line.strip().startswith(f"{name}="):
                return line.strip().split("=", 1)[1].strip().strip('"').strip("'")
    return None

sys.path.insert(0, str(Path(__file__).parent))
from generate_assets import (
    PixelLabClient, RetroDiffusionClient, remove_background,
    STYLE, LIGHTING, THEME, SCENE_PROMPT
)

# Government dome as style reference for RD
ref_path = SPRITES_DIR / "buildings" / "building_government_dome.png"
ref_b64 = None
if ref_path.exists():
    img = Image.open(ref_path).convert("RGB")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    ref_b64 = base64.b64encode(buf.getvalue()).decode()

# --- PIXELLAB BUILDINGS (bigger, using pixflux endpoint) ---
PL_BUILDINGS = {
    "panelka_corner": {
        "prompt": f"{SCENE_PROMPT}, detailed building, Soviet panelka apartment L-shaped corner building, 8 stories, two wings meeting at right angle, prefab concrete panels, lit windows, balconies, night scene",
        "size": (256, 256),
    },
    "apartment_brutalist": {
        "prompt": f"{SCENE_PROMPT}, detailed building, massive brutalist apartment block, stepped terraces, raw exposed concrete, geometric window pattern, rooftop water tanks, night scene harsh lighting",
        "size": (256, 256),
    },
    "hospital_block": {
        "prompt": f"{SCENE_PROMPT}, detailed building, Soviet hospital building, white-grey concrete, red cross sign, ambulance bay entrance, barred ground floor windows, institutional, night scene",
        "size": (256, 192),
    },
    "school_soviet": {
        "prompt": f"{SCENE_PROMPT}, detailed building, Soviet school building, 3 stories, wide horizontal, many windows, concrete facade, hammer and book relief, chain fence yard, night",
        "size": (256, 192),
    },
    "cinema_palace": {
        "prompt": f"{SCENE_PROMPT}, detailed building, Soviet cinema palace, art deco brutalist entrance, large neon sign letters, concrete columns, ornamental relief, warm light from foyer, night",
        "size": (224, 224),
    },
    "communications_tower": {
        "prompt": f"{SCENE_PROMPT}, detailed building, Soviet radio communications tower, tall lattice antenna structure, concrete base building, satellite dishes, red warning lights, night",
        "size": (128, 256),
    },
    "garage_blocks": {
        "prompt": f"{SCENE_PROMPT}, detailed building, row of Soviet metal garages, corrugated doors, some open some closed, puddles, rusted walls, stacked tires, night",
        "size": (256, 128),
    },
    "train_station": {
        "prompt": f"{SCENE_PROMPT}, detailed building, Soviet train station building, clock tower, arched entrance hall, concrete platform canopy, tracks visible, night scene floodlit",
        "size": (256, 224),
    },
}

# --- FLOOR STRUCTURES & PROPS (PixelLab pixflux) ---
PL_FLOOR = {
    "trashcan_cluster": {
        "prompt": f"{SCENE_PROMPT}, isometric floor prop, cluster of metal trash cans and garbage bags, overflowing refuse, stray cat, urban litter, night",
        "size": (128, 96),
    },
    "manhole_steam": {
        "prompt": f"{SCENE_PROMPT}, isometric floor detail, open manhole cover with steam rising, cracked asphalt around it, orange safety cones, night",
        "size": (96, 96),
    },
    "bench_broken": {
        "prompt": f"{SCENE_PROMPT}, isometric floor prop, broken wooden park bench, missing slats, graffiti, fallen leaves around, night",
        "size": (128, 80),
    },
    "newspaper_stand": {
        "prompt": f"{SCENE_PROMPT}, isometric floor prop, Soviet newspaper kiosk stand, small glass booth, Pravda sign, shuttered, dim bulb, night",
        "size": (128, 128),
    },
    "puddle_debris": {
        "prompt": f"{SCENE_PROMPT}, isometric floor detail, large rain puddle with floating debris, broken glass, cigarette butts, reflections of lights, wet asphalt, night",
        "size": (128, 64),
    },
    "concrete_barriers": {
        "prompt": f"{SCENE_PROMPT}, isometric floor prop, row of heavy concrete jersey barriers, police tape stretched between them, scuff marks, night",
        "size": (192, 96),
    },
    "phone_booth": {
        "prompt": f"{SCENE_PROMPT}, isometric prop, Soviet phone booth, glass panels cracked, receiver hanging by cord, dim interior light, vandalized, night",
        "size": (96, 160),
    },
    "dumpster_overflowing": {
        "prompt": f"{SCENE_PROMPT}, isometric floor prop, large green metal dumpster overflowing with garbage bags, rats, stained ground, night",
        "size": (128, 96),
    },
    "tire_stack": {
        "prompt": f"{SCENE_PROMPT}, isometric floor prop, stack of old car tires, some burning with small flames, black smoke wisps, protest barricade, night",
        "size": (96, 96),
    },
    "street_debris": {
        "prompt": f"{SCENE_PROMPT}, isometric floor detail, scattered street debris, broken bottles, torn protest signs, bricks, spent tear gas canisters, night",
        "size": (160, 80),
    },
}

# --- RETRO DIFFUSION BUILDINGS (more at 256 max) ---
RD_BUILDINGS = {
    "panelka_curved": {
        "prompt": "curved Soviet apartment block, 9 stories, sweeping concrete arc shape, balconies along curve, uniform windows with some lights, brutalist monumental, night harsh lighting",
        "size": (256, 224),
    },
    "hotel_soviet": {
        "prompt": "massive Soviet tourist hotel, 20 stories, rectangular concrete slab, ground floor restaurant windows glowing, rooftop antenna, Intourist sign, imposing brutalist tower, night",
        "size": (192, 256),
    },
    "depot_trolleybus": {
        "prompt": "Soviet trolleybus depot, wide concrete building, multiple garage bays, overhead wire infrastructure, parked trolleybus visible inside, industrial, night",
        "size": (256, 160),
    },
    "warehouse_district": {
        "prompt": "Soviet industrial warehouse, long low brick building, loading docks, rusty rolling doors, forklift outside, chain-link fence, security light, night",
        "size": (256, 160),
    },
    "residential_tower": {
        "prompt": "Soviet residential high-rise tower, 16 stories, concrete panel construction, elevator shaft visible on exterior, clothes drying on balconies, satellite dishes, night",
        "size": (160, 256),
    },
    "cultural_palace": {
        "prompt": "Soviet palace of culture, ornate but decayed neoclassical facade, grand columns, hammer and sickle medallion, wide entrance steps, dim warm lighting, monumental, night",
        "size": (256, 224),
    },
}


def gen_pixellab(client, name, prompt, w, h, out_dir, prefix="building"):
    out = out_dir / f"{prefix}_{name}.png"
    print(f"  [PL] {name} ({w}x{h})...")
    try:
        img = client.generate_image(
            prompt, w, h,
            isometric=True,
            transparent_background=True,
            negative_description="characters, people, ground plane, flat floor",
        )
        if img:
            img = remove_background(img)
            with open(out, "wb") as f:
                f.write(img)
            print(f"       OK - {len(img)} bytes")
            return True
    except Exception as e:
        print(f"       FAILED: {e}")
    return False


def gen_rd(client, name, prompt, w, h, out_dir, ref=None, prefix="building"):
    out = out_dir / f"{prefix}_{name}.png"
    print(f"  [RD] {name} ({w}x{h})...")
    refs = [ref] if ref else None
    try:
        images = client.generate(
            prompt, w, h,
            style="rd_pro__isometric",
            reference_images=refs,
            remove_bg=True,
        )
        if images:
            img_bytes = remove_background(images[0])
            with open(out, "wb") as f:
                f.write(img_bytes)
            print(f"       OK - {len(img_bytes)} bytes")
            return True
    except Exception as e:
        print(f"       FAILED: {e}")
        if "Not enough balance" in str(e):
            return "NO_CREDITS"
    return False


def main():
    pl_key = load_env_key("PIXELLAB_API_KEY")
    rd_key = load_env_key("RD_API_KEY")
    if not pl_key:
        print("ERROR: PIXELLAB_API_KEY not found"); sys.exit(1)

    pl_client = PixelLabClient(pl_key)
    buildings_dir = SPRITES_DIR / "buildings"
    props_dir = SPRITES_DIR / "props"
    buildings_dir.mkdir(parents=True, exist_ok=True)
    props_dir.mkdir(parents=True, exist_ok=True)

    # --- PixelLab buildings ---
    print(f"\n=== PIXELLAB BUILDINGS ({len(PL_BUILDINGS)}) ===\n")
    for i, (name, info) in enumerate(PL_BUILDINGS.items(), 1):
        print(f"[{i}/{len(PL_BUILDINGS)}]", end="")
        gen_pixellab(pl_client, name, info["prompt"], *info["size"], buildings_dir)
        time.sleep(3)

    # --- Floor structures / props via PixelLab ---
    print(f"\n=== FLOOR PROPS ({len(PL_FLOOR)}) ===\n")
    for i, (name, info) in enumerate(PL_FLOOR.items(), 1):
        print(f"[{i}/{len(PL_FLOOR)}]", end="")
        gen_pixellab(pl_client, name, info["prompt"], *info["size"], props_dir, prefix="prop")
        time.sleep(3)

    # --- Retro Diffusion buildings ---
    if rd_key:
        rd_client = RetroDiffusionClient(rd_key)
        print(f"\n=== RETRO DIFFUSION BUILDINGS ({len(RD_BUILDINGS)}) ===\n")
        for i, (name, info) in enumerate(RD_BUILDINGS.items(), 1):
            print(f"[{i}/{len(RD_BUILDINGS)}]", end="")
            result = gen_rd(rd_client, name, info["prompt"], *info["size"], buildings_dir, ref_b64)
            if result == "NO_CREDITS":
                print("  OUT OF CREDITS - stopping RD.")
                break
            time.sleep(4)
    else:
        print("\nSkipping RD buildings (no RD_API_KEY)")

    print("\nRunning sync...")
    os.system("python3 tools/sync_assets.py")
    print("Done!")


if __name__ == "__main__":
    main()
