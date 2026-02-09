#!/usr/bin/env python3
"""
Goligee Asset Generator -- Batch generate pixel art sprites via PixelLab API.

Usage:
    python tools/generate_assets.py --phase golden      # Phase 1: 5 golden standards
    python tools/generate_assets.py --phase tiles       # Tile set
    python tools/generate_assets.py --phase towers      # All 8 towers (idle + active)
    python tools/generate_assets.py --phase enemies     # All 12 standard enemies
    python tools/generate_assets.py --phase bosses      # All 5 bosses
    python tools/generate_assets.py --phase projectiles # All projectiles
    python tools/generate_assets.py --phase effects     # Impact/status effects
    python tools/generate_assets.py --phase ui          # UI icons
    python tools/generate_assets.py --phase props       # Environment props
    python tools/generate_assets.py --phase all         # Everything
    python tools/generate_assets.py --single "rioter"   # Generate one specific asset by name

Requires: pip install pixellab Pillow
Env:      PIXELLAB_API_KEY in .env or environment
"""

from __future__ import annotations

import argparse
import base64
import io
import json
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

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites"
ENV_FILE = PROJECT_ROOT / ".env"

API_BASE = "https://api.pixellab.ai/v2"

# Palette image: a small swatch containing our key colors, used as color_image
# for palette enforcement. Generated on first run and cached.
PALETTE_CACHE = PROJECT_ROOT / "tools" / ".palette_swatch.png"

# ---------------------------------------------------------------------------
# Palette -- hex values from moodboard/COLOR_PALETTE.md
# ---------------------------------------------------------------------------

PALETTE_COLORS = [
    # 80% cold base
    "#0E0E12", "#161618", "#1A1A1E", "#1E1E22", "#28282C", "#2E2E32",
    "#3A3A3E", "#484850", "#585860", "#606068", "#808898",
    # 20% warm accents
    "#C8A040", "#D8A040", "#E8A040", "#D06030", "#D04040", "#903020",
    # Tower colors
    "#5080A0", "#3868A0",
    # Enemy tints
    "#D06040", "#A84030", "#802818", "#E89060",
    # Effect colors
    "#F0E0C0", "#70A040", "#50A0D0", "#6090B0",
    # UI
    "#A0D8A0", "#88C888", "#9A9AA0",
]


def hex_to_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def create_palette_swatch() -> str:
    """Create a small image containing all palette colors, return as base64."""
    if PALETTE_CACHE.exists():
        with open(PALETTE_CACHE, "rb") as f:
            return base64.b64encode(f.read()).decode()

    cols = len(PALETTE_COLORS)
    img = Image.new("RGB", (cols, 1))
    for i, c in enumerate(PALETTE_COLORS):
        img.putpixel((i, 0), hex_to_rgb(c))
    # Scale up so the API can read it
    img = img.resize((cols * 4, 4), Image.NEAREST)

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    PALETTE_CACHE.parent.mkdir(parents=True, exist_ok=True)
    with open(PALETTE_CACHE, "wb") as f:
        f.write(buf.getvalue())
    return base64.b64encode(buf.getvalue()).decode()


# ---------------------------------------------------------------------------
# API Client
# ---------------------------------------------------------------------------

class PixelLabClient:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        })
        self.palette_b64 = create_palette_swatch()

    def _post(self, endpoint: str, payload: dict) -> dict:
        url = f"{API_BASE}/{endpoint}"
        resp = self.session.post(url, json=payload, timeout=120)
        if resp.status_code == 429:
            print("  Rate limited, waiting 30s...")
            time.sleep(30)
            resp = self.session.post(url, json=payload, timeout=120)
        if not resp.ok:
            print(f"  API error {resp.status_code}: {resp.text[:500]}")
            resp.raise_for_status()
        return resp.json()

    def _get(self, endpoint: str) -> dict:
        url = f"{API_BASE}/{endpoint}"
        resp = self.session.get(url, timeout=60)
        resp.raise_for_status()
        return resp.json()

    def wait_for_job(self, job_id: str, poll_interval: float = 5.0,
                     max_wait: float = 300.0) -> dict:
        """Poll a background job until completion."""
        elapsed = 0.0
        while elapsed < max_wait:
            result = self._get(f"background-jobs/{job_id}")
            status = result.get("status", "")
            if status == "completed":
                return result
            if status == "failed":
                raise RuntimeError(f"Job {job_id} failed: {result}")
            time.sleep(poll_interval)
            elapsed += poll_interval
            print(f"  Waiting for job {job_id}... ({elapsed:.0f}s)")
        raise TimeoutError(f"Job {job_id} did not complete in {max_wait}s")

    def generate_image(self, description: str, width: int, height: int,
                       *, isometric: bool = False, no_background: bool = True,
                       seed: int | None = None) -> bytes:
        """Generate a single image via pixflux. Min 32x32."""
        # API requires minimum 32x32 canvas
        api_w = max(width, 32)
        api_h = max(height, 32)
        payload = {
            "description": description,
            "image_size": {"width": api_w, "height": api_h},
            "isometric": isometric,
            "no_background": no_background,
            "color_image": {"base64": self.palette_b64},
            "text_guidance_scale": 8.0,
        }
        if seed is not None:
            payload["seed"] = seed
        result = self._post("create-image-pixflux", payload)
        return self._extract_image(result)

    def generate_isometric_tile(self, description: str, size: int = 32,
                                shape: str = "thin tile",
                                seed: int | None = None) -> bytes:
        """Generate an isometric tile (async)."""
        payload = {
            "description": description,
            "image_size": {"width": size, "height": size},
            "isometric_tile_size": size,
            "isometric_tile_shape": shape,
            "text_guidance_scale": 8.0,
        }
        if seed is not None:
            payload["seed"] = seed
        result = self._post("create-isometric-tile", payload)
        job_id = result.get("background_job_id") or result.get("job_id")
        if job_id:
            result = self.wait_for_job(job_id)
        return self._extract_image(result)

    def generate_character_4dir(self, description: str, width: int, height: int,
                                *, isometric: bool = True,
                                seed: int | None = None) -> dict:
        """Generate character with 4 directional views (async)."""
        payload = {
            "description": description,
            "image_size": {"width": width, "height": height},
            "isometric": isometric,
            "color_image": {"base64": self.palette_b64},
            "text_guidance_scale": 8.0,
        }
        if seed is not None:
            payload["seed"] = seed
        result = self._post("create-character-with-4-directions", payload)
        job_id = result.get("background_job_id") or result.get("job_id")
        if job_id:
            result = self.wait_for_job(job_id)
        return result

    def generate_map_object(self, description: str, width: int, height: int,
                            *, seed: int | None = None) -> bytes:
        """Generate a map/environment object with transparent background."""
        payload = {
            "description": description,
            "image_size": {"width": width, "height": height},
            "view": "high",
            "color_image": {"base64": self.palette_b64},
            "text_guidance_scale": 8.0,
        }
        if seed is not None:
            payload["seed"] = seed
        result = self._post("map-objects", payload)
        return self._extract_image(result)

    def _extract_image(self, result: dict) -> bytes:
        """Extract image bytes from API response and convert to PNG."""
        img_data = self._find_image_data(result)
        if not img_data:
            print(f"  WARNING: Could not extract image from response keys: {list(result.keys())}")
            debug_path = PROJECT_ROOT / "tools" / ".last_response.json"
            with open(debug_path, "w") as f:
                json.dump(result, f, indent=2, default=str)
            print(f"  Response saved to {debug_path}")
            return b""
        return img_data

    def _find_image_data(self, result: dict) -> bytes:
        """Search for image data in various response shapes."""
        # For async jobs: last_response.image or last_response.quantized_image
        last_resp = result.get("last_response", {})
        if isinstance(last_resp, dict):
            for img_key in ("quantized_image", "image"):
                img_obj = last_resp.get(img_key, {})
                if isinstance(img_obj, dict) and img_obj.get("base64"):
                    return self._rgba_to_png(img_obj)

        # Direct response: image, data, result
        for key in ("image", "data", "result"):
            val = result.get(key)
            if isinstance(val, dict):
                if val.get("type") == "rgba_bytes" and val.get("base64"):
                    return self._rgba_to_png(val)
                b64 = val.get("base64") or val.get("image_base64")
                if b64:
                    return base64.b64decode(b64)

        # Images array
        images = result.get("images", [])
        if images:
            first = images[0]
            if isinstance(first, dict):
                if first.get("type") == "rgba_bytes" and first.get("base64"):
                    return self._rgba_to_png(first)
                b64 = first.get("base64") or first.get("image_base64")
                if b64:
                    return base64.b64decode(b64)
            elif isinstance(first, str):
                return base64.b64decode(first)

        return b""

    def _rgba_to_png(self, img_obj: dict) -> bytes:
        """Convert raw RGBA byte data from the API to a PNG file."""
        raw = base64.b64decode(img_obj["base64"])
        w = img_obj.get("width", 32)
        h = img_obj.get("height", 32)
        try:
            img = Image.frombytes("RGBA", (w, h), raw)
        except ValueError:
            # Fallback: might already be PNG
            return raw
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()


def save_image(data: bytes, rel_path: str) -> Path:
    """Save image bytes to sprites dir, return full path."""
    out = SPRITES_DIR / rel_path
    out.parent.mkdir(parents=True, exist_ok=True)
    if data:
        with open(out, "wb") as f:
            f.write(data)
        print(f"  Saved: {out.relative_to(PROJECT_ROOT)}")
    else:
        print(f"  SKIPPED (no image data): {rel_path}")
    return out


# ---------------------------------------------------------------------------
# Prompt Definitions
# ---------------------------------------------------------------------------

BASE_PROMPT = (
    "16-bit isometric pixel art, isometric 3/4 view, "
    "light source from top-left casting shadows to bottom-right, "
    "left faces brightest, right faces mid-tone, bottom faces darkest, "
    "satirical riot control police state setting, "
    "Soviet brutalist architecture influence, raw concrete angular geometry, "
    "comically exaggerated militarized police equipment, "
    "dark night scene lit by harsh overhead floodlights from top-left, "
    "cold concrete and gunmetal gray palette with warning amber and emergency red accents, "
    "desaturated muted tones, oppressive authoritarian dystopia, "
    "post-apocalyptic urban decay, graffiti and grime, razor barbed wire, "
    "clean pixel grid, no anti-aliasing, detailed 16-bit shading"
)

# -- Towers ----------------------------------------------------------------

TOWERS = {
    "rubber_bullet": {
        "desc": "rotating mounted turret with dual barrels, ammo belt feed, "
                "compact military design, muzzle suppressor, kinetic weapon, "
                "silver metallic barrel, warning stripes",
        "active": "muzzle flash, shell casings ejecting, barrel recoil, firing state",
    },
    "tear_gas": {
        "desc": "multi-tube grenade launcher rack, 6 angled launch tubes, "
                "chemical weapon, hazmat yellow markings, chemical green accent, "
                "vented housing, gas mask motif",
        "active": "gas cloud trailing, launched canister in flight, smoke wisps",
    },
    "taser_grid": {
        "desc": "tesla coil tower design, twin conductor prongs on top, "
                "insulated base housing, high voltage warning signage, electric blue glow",
        "active": "electric arc between prongs, chain lightning, sparks flying",
    },
    "water_cannon": {
        "desc": "industrial fire hose nozzle on swivel mount, large water tank base, "
                "pressurized hydraulic system, pipe fittings and gauges, chrome nozzle",
        "active": "water stream spraying, splash particles, pressurized burst",
    },
    "surveillance": {
        "desc": "satellite dish with camera cluster, radar spinner on top, "
                "multiple CCTV cameras pointing outward, antenna array, screen glow, "
                "red recording light, dark housing",
        "active": "scanning beam sweep, data particles floating, rotating dish animation",
    },
    "pepper_spray": {
        "desc": "industrial aerosol nozzle array, chemical tank with warning labels, "
                "pressurized canister design, spray cone emitter head, chemical green, "
                "hazmat orange, warning stripes",
        "active": "continuous spray cone, mist particles dispersing, chemical cloud",
    },
    "lrad": {
        "desc": "large parabolic speaker dish, concentric ring emitter face, "
                "sound wave visual, military audio device, amber warning glow, "
                "dark metal housing",
        "active": "visible sonic waves emanating, distortion ripples, vibration lines",
    },
    "microwave": {
        "desc": "flat panel directed energy weapon, heat emitter grid face, "
                "sci-fi energy weapon, cooling fins on sides, heat shimmer, "
                "emitter face pattern, industrial mounting bracket",
        "active": "heat beam firing, shimmer distortion in front, target glow",
    },
}

# -- Standard Enemies ------------------------------------------------------

ENEMIES = {
    "rioter": {
        "desc": "basic civilian protestor, hoodie and jeans, bandana face mask, "
                "carrying crude protest sign, lean aggressive stance, sneaking posture",
        "size": (16, 16),
    },
    "masked": {
        "desc": "gas mask wearing protestor, tactical vest over hoodie, "
                "medium build, determined stance, goggles and respirator, "
                "medium armor plating visible",
        "size": (16, 16),
    },
    "shield_wall": {
        "desc": "large riot shield carrier, heavy improvised armor, "
                "makeshift plywood and metal shield, slow heavy stance, bulky silhouette",
        "size": (16, 16),
    },
    "molotov": {
        "desc": "slim agile protestor, arm raised holding bottle with lit rag, "
                "fire glow from molotov, bandana mask, light fast build, arsonist posture",
        "size": (16, 16),
    },
    "drone_op": {
        "desc": "tech-savvy protestor with drone controller, small quadcopter hovering above, "
                "backpack with antenna, goggles, screen glow",
        "size": (16, 16),
    },
    "flash_mob": {
        "desc": "cluster of 3-4 tiny figures merged together, crowd blob, "
                "mixed civilian clothing, protest signs sticking up, chaotic grouping",
        "size": (16, 16),
    },
    "street_medic": {
        "desc": "first aid cross armband, medical backpack, face mask, "
                "running support posture, white cross on arm, healing aura shimmer",
        "size": (16, 16),
    },
    "armored_van": {
        "desc": "improvised armored vehicle, welded metal plates on van, "
                "barricade ram front, small viewport slits, heavy dark silhouette",
        "size": (24, 16),
    },
    "infiltrator": {
        "desc": "dark hooded figure, crouched sneaking pose, "
                "near-invisible stealth shimmer, shadow-blend clothing, very dark body",
        "size": (16, 16),
    },
    "swarm": {
        "desc": "tiny phone-wielding figure, single small protestor, "
                "very simple 4-color sprite, minimal detail, bright screen glow, swarm unit",
        "size": (8, 8),
    },
    "tunnel_rat": {
        "desc": "hunched figure with mining helmet, goggles and dust mask, "
                "digging tools on back, low crouching pose, dirt-stained, headlamp glow",
        "size": (16, 16),
    },
    "union_boss": {
        "desc": "large intimidating figure, hard hat and hi-vis vest, "
                "megaphone in hand, commanding presence, heavy build, authority stance",
        "size": (20, 20),
    },
}

# -- Bosses ----------------------------------------------------------------

BOSSES = {
    "demagogue": {
        "desc": "charismatic leader on elevated platform with megaphone, "
                "long coat flowing, dramatic pointing gesture, raised wooden stage beneath feet, "
                "crowd energy aura, propaganda banner backdrop",
    },
    "hacktivist": {
        "desc": "hooded hacker figure with multiple floating holographic screens, "
                "green terminal text glow, typing gesture, digital glitch effects, "
                "bot minion silhouettes nearby, shield shimmer",
    },
    "barricade": {
        "desc": "massive walking barricade structure, humanoid shape made of "
                "welded metal sheets, car doors, wooden planks, rebar, "
                "debris shedding, enormous heavy silhouette",
    },
    "influencer": {
        "desc": "flashy narcissistic figure with ring light halo, "
                "phone held up for selfie, designer protest outfit, "
                "follower silhouettes trailing, glamour glow, social media icons floating",
    },
    "ghost_protocol": {
        "desc": "flickering translucent figure, phasing in and out of reality, "
                "glitch visual effects, teleport afterimage trail, "
                "cycling color shift between silver and purple, multiple ghost positions",
    },
}

# -- Tiles -----------------------------------------------------------------

TILES = {
    "ground_cracked": "cracked urban asphalt, subtle crack lines, worn road surface, urban decay",
    "ground_clean": "clean asphalt surface, smooth pavement, minimal cracks",
    "path_warning": "hazard-marked path, diagonal warning stripes, worn caution paint",
    "path_worn": "faded path markings, old yellow paint barely visible, worn walkway",
    "wall_concrete": "raised concrete wall block, brutalist architecture, cinder block texture",
    "wall_damaged": "damaged concrete wall, chunks missing, rebar exposed, battle-scarred",
    "platform": "raised metal platform, industrial grating texture, tower placement pad, reinforced edges",
    "scorched": "fire-damaged asphalt, scorch marks and ash, char marks, burnt debris",
    "flooded": "shallow water on asphalt, reflective puddle surface, ripple effect",
    "toxic": "chemical spill on ground, green-tinted puddle, toxic warning, corrosive",
    "rubble": "collapsed debris pile, concrete chunks and rebar, destroyed building remnants",
}

# -- Projectiles -----------------------------------------------------------

PROJECTILES = {
    "rubber_bullet": ("small silver bullet with tracer trail, kinetic projectile, motion streak", 8),
    "tear_gas": ("lobbed cylindrical canister, arc trajectory, chemical green, smoke trail, tumbling", 12),
    "water_blast": ("pressurized water stream burst, spray pattern, cool blue to white, splash droplets", 16),
    "electric_arc": ("jagged lightning bolt, chain link, electric blue, bright core, spark endpoints", 12),
    "sonic_wave": ("concentric arc wave lines, expanding rings, amber, distortion ripple", 16),
    "heat_beam": ("straight directed energy beam, shimmer heat haze, orange core, red edge", 16),
    "pepper_spray": ("expanding aerosol cone, mist particles, green to yellow-green, dispersing", 16),
    "surveillance_ping": ("scanning pulse, radar blip, terminal green, circular ripple, data ping", 8),
}

# -- Effects ---------------------------------------------------------------

EFFECTS = {
    "explosion_kinetic": ("bullet impact burst, debris spray, flash, spark, smoke", 16),
    "explosion_chemical": ("gas cloud expansion, chemical reaction, green cloud, dissipating edges", 32),
    "explosion_fire": ("fireball explosion, flash core to fire bloom, smoke trail", 32),
    "explosion_electric": ("electrical discharge burst, arc flash, blue core, radial lightning", 24),
    "explosion_water": ("water impact splash, concentric droplet ring, mist", 24),
    "explosion_sonic": ("sonic shockwave ring, concentric expanding circles, amber distortion", 24),
    "explosion_energy": ("directed energy flash, beam impact, purple to white, heat shimmer", 24),
    "explosion_cyber": ("digital glitch burst, fragmented pixels, data corruption effect, green", 16),
    "status_stun": ("spinning stars above head, dazed indicator, electric blue and yellow orbit", 16),
    "status_freeze": ("ice crystal overlay, frost particles, cryo blue, ice formation", 16),
    "status_burn": ("small flame wisps, burning indicator, fire orange, ember, smoke wisps", 16),
    "status_poison": ("toxic bubble particles rising, corrosion drops, green bubbles, drip", 16),
    "status_shield": ("hexagonal energy shield overlay, barrier glow, shield blue, hex pattern", 16),
}

# -- Props -----------------------------------------------------------------

PROPS = {
    "barricade": ("concrete jersey barrier, riot police barricade, caution stripe", 32, 24),
    "burnt_car": ("burnt-out car wreck, smashed windows, fire damage, charred metal, rust", 48, 32),
    "floodlight": ("tall portable floodlight on tripod stand, harsh light cone, industrial metal", 16, 32),
    "razor_wire": ("coiled razor wire barrier, military grade, steel, sharp gleam highlights", 32, 8),
    "rubble_small": ("small rubble pile, concrete chunks, dust", 16, 16),
    "rubble_large": ("large collapsed building debris, concrete and rebar, dust particles", 32, 24),
    "dumpster": ("metal dumpster, graffiti, dented, urban decay", 24, 16),
    "street_lamp": ("broken street lamp, shattered bulb, bent pole, urban ruin", 8, 32),
    "signs_ground": ("discarded protest signs on ground, trampled cardboard", 16, 8),
    "traffic_cone": ("orange traffic cone, knocked over, urban clutter", 8, 8),
    "burning_barrel": ("burning oil drum, fire inside, warm glow, hobo fire", 16, 16),
    "sandbags": ("sandbag wall fortification, military barrier, stacked bags", 32, 16),
}

# -- UI Icons --------------------------------------------------------------

UI_ICONS = {
    # Tower build menu icons
    "tower_rubber_bullet": "simplified rubber bullet turret silhouette, dual barrels, kinetic silver",
    "tower_tear_gas": "simplified grenade launcher rack silhouette, chemical green accent",
    "tower_taser_grid": "simplified tesla coil silhouette, electric blue glow",
    "tower_water_cannon": "simplified water hose turret silhouette, cool blue accent",
    "tower_surveillance": "simplified satellite dish silhouette, terminal green glow",
    "tower_pepper_spray": "simplified spray nozzle silhouette, chemical orange accent",
    "tower_lrad": "simplified speaker dish silhouette, amber warning glow",
    "tower_microwave": "simplified energy panel silhouette, heat shimmer orange",
    # Damage type icons
    "dmg_kinetic": "bullet shape icon, kinetic silver, simple bold",
    "dmg_chemical": "droplet/flask icon, chemical green, hazard symbol",
    "dmg_hydraulic": "water wave icon, cool blue, pressure burst",
    "dmg_electric": "lightning bolt icon, electric blue, sharp edges",
    "dmg_sonic": "sound wave rings icon, amber, concentric arcs",
    "dmg_energy": "beam ray icon, purple, directed energy",
    "dmg_cyber": "circuit chip icon, terminal green, digital",
    "dmg_psychological": "eye icon, slate gray, surveillance feel",
    # HUD icons
    "budget": "authoritarian eagle stamp coin, amber currency, institutional feel",
    "approval": "approval meter shield badge, green when high, official insignia",
    "incident": "wave counter exclamation, warning amber, alert indicator",
    "speed_1x": "single arrow play button, terminal green, speed control",
    "speed_2x": "double arrow fast forward, terminal green, speed control",
    "speed_3x": "triple arrow fastest, terminal green, speed control",
    "upgrade": "upward arrow, amber highlight, improvement indicator",
    "sell": "downward arrow with coin, red accent, sell/demolish",
    "locked": "padlock icon, gunmetal gray, locked state",
    # Ability icons
    "ability_airstrike": "crosshair with explosion, emergency red, airstrike target",
    "ability_freeze": "snowflake crystal, cryo blue, flash freeze",
    "ability_funding": "double coin stack, bright amber, emergency funding",
}


# ---------------------------------------------------------------------------
# Generation Functions
# ---------------------------------------------------------------------------

def gen_golden_standards(client: PixelLabClient):
    """Phase 1: Generate 5 golden standard sprites."""
    print("\n=== PHASE 1: Golden Standards ===\n")

    # 1. Ground tile
    print("[1/5] Ground tile (cracked asphalt)...")
    img = client.generate_isometric_tile(
        "8-bit pixel art isometric floor tile, cracked urban asphalt road, "
        "police boot prints stamped into pavement, faded riot zone spray paint, "
        "dark gray concrete #3A3A3E, oppressive urban decay, "
        "no anti-aliasing, clean pixel grid, night lighting",
        size=32, shape="thin tile",
    )
    save_image(img, "tiles/tile_ground_cracked.png")

    # 2. Rubber Bullet Turret (idle)
    print("[2/5] Rubber Bullet Turret (idle)...")
    img = client.generate_image(
        "8-bit pixel art, isometric 3/4 view, single game sprite, transparent background, "
        "comically oversized riot police turret mounted on concrete platform, "
        "absurdly large rotating dual-barrel rubber bullet gun, "
        "massive ammo belt feeding into it, tiny POLICE stencil on side, "
        "ridiculously militarized for shooting rubber bullets, "
        "dark gunmetal gray #484850 body, warning stripes #C8A040, "
        "red warning light on top #D04040, institutional oppressive design, "
        "satirical excessive force equipment, night scene harsh lighting",
        32, 32, isometric=True,
    )
    save_image(img, "towers/tower_rubber_bullet_idle.png")

    # 3. Rioter (walk SE)
    print("[3/5] Rioter (SE walk pose)...")
    img = client.generate_image(
        "8-bit pixel art, isometric 3/4 view, single game character sprite, "
        "transparent background, small angry protestor character walking south-east, "
        "wearing hoodie and bandana mask, waving a tiny protest sign, "
        "comically determined expression, sneakers, "
        "warm reddish skin tone #D06040, dark clothing, "
        "exaggerated angry body language, satirical cartoon protester, "
        "urban night scene, desaturated muted colors, no anti-aliasing",
        32, 32, isometric=True,
    )
    save_image(img, "enemies/enemy_rioter_se_01.png")

    # 4. Bullet tracer
    print("[4/5] Rubber bullet projectile...")
    img = client.generate_image(
        "8-bit pixel art, single tiny game projectile sprite on transparent background, "
        "comically oversized rubber bullet flying through air, "
        "silver metallic #9A9AA0 bullet with bright yellow tracer trail #C8A040, "
        "motion lines, speed blur, small spark trail, "
        "simple clean sprite, no anti-aliasing, dark background contrast",
        32, 32,
    )
    save_image(img, "projectiles/proj_rubber_bullet.png")

    # 5. Kinetic explosion
    print("[5/5] Kinetic impact explosion...")
    img = client.generate_image(
        "8-bit pixel art, single game explosion effect sprite on transparent background, "
        "rubber bullet impact burst, small circular shockwave, "
        "bright white flash center #F0E0C0, orange sparks #E8A040 flying outward, "
        "gray smoke puff #383838, debris particles, "
        "cartoony impact effect, exaggerated for tiny rubber bullet, "
        "clean pixel art, no anti-aliasing",
        32, 32,
    )
    save_image(img, "effects/effect_explosion_kinetic_01.png")

    print("\nGolden standards complete! Review these 5 sprites and iterate before proceeding.")


def gen_tiles(client: PixelLabClient):
    """Generate all isometric tiles."""
    print("\n=== TILES ===\n")
    for i, (name, desc) in enumerate(TILES.items(), 1):
        print(f"[{i}/{len(TILES)}] tile_{name}...")
        img = client.generate_isometric_tile(
            f"{BASE_PROMPT}, isometric floor tile, seamless tiling edges, {desc}",
            size=32, shape="thin tile",
        )
        save_image(img, f"tiles/tile_{name}.png")


def gen_towers(client: PixelLabClient):
    """Generate all towers (idle + active states)."""
    print("\n=== TOWERS ===\n")
    tower_base = (
        f"{BASE_PROMPT}, riot control equipment, mounted on concrete platform, "
        f"isometric 3/4 view, metallic industrial design, single game sprite"
    )
    total = len(TOWERS) * 2
    idx = 0
    for name, info in TOWERS.items():
        for state in ("idle", "active"):
            idx += 1
            print(f"[{idx}/{total}] tower_{name}_{state}...")
            desc = f"{tower_base}, {info['desc']}"
            if state == "active":
                desc += f", {info['active']}"
            img = client.generate_image(desc, 32, 32, isometric=True)
            save_image(img, f"towers/tower_{name}_{state}.png")


def gen_enemies(client: PixelLabClient):
    """Generate all standard enemies (SE direction, single frame for now)."""
    print("\n=== STANDARD ENEMIES ===\n")
    for i, (name, info) in enumerate(ENEMIES.items(), 1):
        w, h = info["size"]
        print(f"[{i}/{len(ENEMIES)}] enemy_{name}_se...")
        # Clamp minimum size to 16 for API (PixelLab min is 16)
        api_w = max(w, 16)
        api_h = max(h, 16)
        img = client.generate_image(
            f"{BASE_PROMPT}, protestor character, isometric 3/4 view, "
            f"facing south-east, walking pose, single game sprite, {info['desc']}",
            api_w, api_h, isometric=True,
        )
        save_image(img, f"enemies/enemy_{name}_se_01.png")


def gen_bosses(client: PixelLabClient):
    """Generate all boss enemies."""
    print("\n=== BOSS ENEMIES ===\n")
    for i, (name, info) in enumerate(BOSSES.items(), 1):
        print(f"[{i}/{len(BOSSES)}] boss_{name}_idle...")
        img = client.generate_image(
            f"{BASE_PROMPT}, boss character, imposing large figure, "
            f"isometric 3/4 view, detailed for size, single game sprite, "
            f"{info['desc']}",
            48, 48, isometric=True,
        )
        save_image(img, f"bosses/boss_{name}_idle.png")


def gen_projectiles(client: PixelLabClient):
    """Generate all projectile sprites."""
    print("\n=== PROJECTILES ===\n")
    for i, (name, (desc, size)) in enumerate(PROJECTILES.items(), 1):
        print(f"[{i}/{len(PROJECTILES)}] proj_{name}...")
        # Clamp minimum to 16 for API
        api_size = max(size, 16)
        img = client.generate_image(
            f"{BASE_PROMPT}, game projectile sprite, small, "
            f"motion blur suggestion, {desc}",
            api_size, api_size,
        )
        save_image(img, f"projectiles/proj_{name}.png")


def gen_effects(client: PixelLabClient):
    """Generate all effect sprites."""
    print("\n=== EFFECTS ===\n")
    for i, (name, (desc, size)) in enumerate(EFFECTS.items(), 1):
        print(f"[{i}/{len(EFFECTS)}] effect_{name}...")
        img = client.generate_image(
            f"{BASE_PROMPT}, game effect sprite, animation frame, {desc}",
            size, size,
        )
        save_image(img, f"effects/effect_{name}_01.png")


def gen_props(client: PixelLabClient):
    """Generate environment props."""
    print("\n=== ENVIRONMENT PROPS ===\n")
    for i, (name, (desc, w, h)) in enumerate(PROPS.items(), 1):
        print(f"[{i}/{len(PROPS)}] prop_{name}...")
        # Clamp minimum to 16
        api_w = max(w, 16)
        api_h = max(h, 16)
        img = client.generate_map_object(
            f"{BASE_PROMPT}, environment prop, isometric 3/4 view, urban debris, {desc}",
            api_w, api_h,
        )
        save_image(img, f"props/prop_{name}.png")


def gen_ui(client: PixelLabClient):
    """Generate UI icons."""
    print("\n=== UI ICONS ===\n")
    for i, (name, desc) in enumerate(UI_ICONS.items(), 1):
        print(f"[{i}/{len(UI_ICONS)}] icon_{name}...")
        # Tower icons at 32x32, others at 16x16
        size = 32 if name.startswith("tower_") or name.startswith("ability_") else 16
        img = client.generate_image(
            f"pixel art game icon, clean sharp edges, no anti-aliasing, "
            f"dark theme, transparent background, {desc}",
            size, size,
        )
        save_image(img, f"ui/icon_{name}.png")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def load_api_key() -> str:
    """Load API key from .env file or environment."""
    key = os.environ.get("PIXELLAB_API_KEY")
    if key:
        return key
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    print("ERROR: PIXELLAB_API_KEY not found. Set it in .env or as environment variable.")
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Generate Goligee pixel art assets via PixelLab API")
    parser.add_argument("--phase", choices=[
        "golden", "tiles", "towers", "enemies", "bosses",
        "projectiles", "effects", "ui", "props", "all",
    ], help="Which phase/category to generate")
    parser.add_argument("--single", type=str, help="Generate a single asset by name (e.g., 'rioter')")
    parser.add_argument("--seed", type=int, default=None, help="Global seed for reproducibility")
    args = parser.parse_args()

    if not args.phase and not args.single:
        parser.print_help()
        sys.exit(0)

    api_key = load_api_key()
    client = PixelLabClient(api_key)

    # Check balance
    try:
        balance = client._get("balance")
        print(f"Account balance: {json.dumps(balance, indent=2)}")
    except Exception as e:
        print(f"Could not check balance: {e}")

    phase_map = {
        "golden": gen_golden_standards,
        "tiles": gen_tiles,
        "towers": gen_towers,
        "enemies": gen_enemies,
        "bosses": gen_bosses,
        "projectiles": gen_projectiles,
        "effects": gen_effects,
        "ui": gen_ui,
        "props": gen_props,
    }

    if args.phase == "all":
        for phase_name, func in phase_map.items():
            func(client)
    elif args.phase:
        phase_map[args.phase](client)
    elif args.single:
        # Find and generate a single asset by name
        name = args.single.lower()
        if name in TOWERS:
            print(f"Generating tower: {name}")
            gen_single_tower(client, name)
        elif name in ENEMIES:
            print(f"Generating enemy: {name}")
            gen_single_enemy(client, name)
        elif name in BOSSES:
            print(f"Generating boss: {name}")
            gen_single_boss(client, name)
        else:
            print(f"Asset '{name}' not found in towers/enemies/bosses.")
            sys.exit(1)

    print("\nDone!")


def gen_single_tower(client: PixelLabClient, name: str):
    info = TOWERS[name]
    tower_base = (
        f"{BASE_PROMPT}, riot control equipment, mounted on concrete platform, "
        f"isometric 3/4 view, metallic industrial design, single game sprite"
    )
    for state in ("idle", "active"):
        desc = f"{tower_base}, {info['desc']}"
        if state == "active":
            desc += f", {info['active']}"
        img = client.generate_image(desc, 32, 32, isometric=True)
        save_image(img, f"towers/tower_{name}_{state}.png")


def gen_single_enemy(client: PixelLabClient, name: str):
    info = ENEMIES[name]
    w, h = info["size"]
    api_w, api_h = max(w, 16), max(h, 16)
    img = client.generate_image(
        f"{BASE_PROMPT}, protestor character, isometric 3/4 view, "
        f"facing south-east, walking pose, single game sprite, {info['desc']}",
        api_w, api_h, isometric=True,
    )
    save_image(img, f"enemies/enemy_{name}_se_01.png")


def gen_single_boss(client: PixelLabClient, name: str):
    info = BOSSES[name]
    img = client.generate_image(
        f"{BASE_PROMPT}, boss character, imposing large figure, "
        f"isometric 3/4 view, detailed for size, single game sprite, "
        f"{info['desc']}",
        48, 48, isometric=True,
    )
    save_image(img, f"bosses/boss_{name}_idle.png")


if __name__ == "__main__":
    main()
