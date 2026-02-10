#!/usr/bin/env python3
"""
Goligee Asset Sync -- Scan sprites on disk, update ASSET_CHECKLIST.md, and
regenerate overview sheet PNGs.

Run after ANY sprite change to keep docs and overviews in sync:

    python tools/sync_assets.py            # Full sync (checklist + overviews)
    python tools/sync_assets.py --check    # Dry-run: report mismatches only
    python tools/sync_assets.py --overviews # Regenerate overview sheets only
    python tools/sync_assets.py --checklist # Update checklist only

Requires: pip install Pillow
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import NamedTuple

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow required. Run: pip install Pillow")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites"
OVERVIEW_DIR = SPRITES_DIR / "_overview"
CHECKLIST_PATH = PROJECT_ROOT / "docs" / "ASSET_CHECKLIST.md"

# ---------------------------------------------------------------------------
# Asset registry -- single source of truth for what sprites are expected
# ---------------------------------------------------------------------------

class AssetEntry(NamedTuple):
    category: str
    filename: str
    display_name: str
    size: str
    phase: str


# -- Towers: base + turret architecture --

TOWER_IDS = [
    ("rubber_bullet", "Rubber Bullet Turret"),
    ("tear_gas", "Tear Gas Launcher"),
    ("water_cannon", "Water Cannon"),
    ("taser_grid", "Taser Grid"),
    ("surveillance", "Surveillance Hub"),
    ("pepper_spray", "Pepper Spray Emitter"),
    ("lrad", "LRAD Cannon"),
    ("microwave", "Microwave Emitter"),
]

TURRET_DIRS = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]

TOWER_TIER5 = [
    ("rubber_bullet_tier5a", "DEADSHOT", "Rubber Bullet A5"),
    ("rubber_bullet_tier5b", "BULLET HELL", "Rubber Bullet B5"),
    ("rubber_bullet_tier5c", "EXPERIMENTAL ORDNANCE", "Rubber Bullet C5"),
    ("tear_gas_tier5a", "NERVE AGENT DEPLOYER", "Tear Gas A5"),
    ("taser_grid_tier5a", "ARC REACTOR", "Taser Grid A5"),
    ("water_cannon_tier5a", "TSUNAMI CANNON", "Water Cannon A5"),
    ("surveillance_tier5a", "PANOPTICON", "Surveillance A5"),
    ("microwave_tier5a", "DEATH RAY", "Microwave A5"),
]

# -- Enemies: 16 enemies, 8-direction walk cycles --

ENEMY_IDS = [
    ("rioter", "Rioter", "32x32"),
    ("masked", "Masked Protestor", "32x32"),
    ("shield_wall", "Shield Wall", "32x32"),
    ("molotov", "Molotov Thrower", "32x32"),
    ("drone_op", "Drone Operator", "32x32"),
    ("goth_protestor", "Goth Protestor", "32x32"),
    ("street_medic", "Street Medic", "32x32"),
    ("armored_van", "Armored Van", "32x32"),
    ("infiltrator", "Infiltrator", "32x32"),
    ("blonde_protestor", "Blonde Protestor", "32x32"),
    ("tunnel_rat", "Tunnel Rat", "32x32"),
    ("union_boss", "Union Boss", "32x32"),
    ("journalist", "Journalist", "32x32"),
    ("grandma", "Grandma", "32x32"),
    ("family", "Family", "32x32"),
    ("student", "Student", "32x32"),
]

ENEMY_DIRS = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
ENEMY_FRAMES = ["01", "02", "03", "04"]

# -- Bosses --

BOSS_IDS = [
    ("demagogue", "The Demagogue", "idle,attack,phase2,death"),
    ("hacktivist", "The Hacktivist", "idle,attack,death"),
    ("barricade", "The Barricade", "idle,attack,death"),
    ("influencer", "The Influencer", "idle,attack,split,death"),
    ("ghost_protocol", "Ghost Protocol", "idle,attack,teleport,death"),
]

# -- Projectiles --

PROJECTILE_IDS = [
    ("rubber_bullet", "Rubber bullet tracer", "8x8"),
    ("tear_gas", "Tear gas canister", "12x12"),
    ("water_blast", "Water blast", "16x16"),
    ("electric_arc", "Electric arc", "12x12"),
    ("sonic_wave", "Sonic wave", "16x8"),
    ("heat_beam", "Heat beam", "16x4"),
    ("pepper_spray", "Pepper spray cloud", "16x16"),
    ("surveillance_ping", "Surveillance ping", "8x8"),
]

# -- Effects --

EFFECT_EXPLOSION_IDS = [
    ("kinetic", "Kinetic impact", "16x16", 4),
    ("chemical", "Chemical burst", "32x32", 4),
    ("fire", "Fire explosion", "32x32", 6),
    ("electric", "Electric discharge", "24x24", 4),
    ("water", "Water splash", "24x24", 4),
    ("sonic", "Sonic shockwave", "24x24", 4),
    ("energy", "Energy flash", "24x24", 4),
    ("cyber", "Cyber glitch", "16x16", 4),
]

EFFECT_STATUS_IDS = [
    ("stun", "Stun stars", "16x16", 4),
    ("freeze", "Freeze/slow", "16x16", 2),
    ("burn", "Burn DOT", "16x16", 4),
    ("poison", "Poison DOT", "16x16", 4),
    ("shield", "Shield", "16x16", 2),
]

# -- Tiles --

TILE_IDS = [
    ("ground_cracked", "Ground -- cracked asphalt", "2-3"),
    ("path", "Path -- warning yellow", "2"),
    ("wall", "Wall -- concrete", "2"),
    ("platform", "Elevated -- platform", "1"),
    ("scorched", "Scorched ground", "1"),
    ("flooded", "Flooded street", "1"),
    ("toxic", "Toxic spill", "1"),
    ("rubble", "Rubble", "1-2"),
]

# -- City Buildings --

BUILDING_IDS = [
    ("panelka_tall", "Panelka (tall)", "128x192"),
    ("panelka_wide", "Panelka (wide)", "192x128"),
    ("panelka_ruined", "Panelka (ruined)", "128x160"),
    ("government", "Government Building", "192x192"),
    ("guard_booth", "Guard Booth", "64x64"),
    ("checkpoint", "Checkpoint", "96x64"),
]

# -- Animated Details --

ANIMATED_IDS = [
    ("burning_barrel", "Burning Barrel", "64x64", 4),
    ("waving_flag", "Waving Flag", "64x64", 4),
    ("neon_sign", "Neon Sign", "64x64", 4),
]

# -- UI Icons --

UI_TOWER_ICONS = [tid for tid, _ in TOWER_IDS]
UI_DMG_ICONS = ["kinetic", "chemical", "hydraulic", "electric", "sonic", "energy", "cyber", "psychological"]
UI_HUD_ICONS = ["budget", "approval", "incident", "speed_1x", "speed_2x", "speed_3x", "upgrade", "sell", "locked"]
UI_ABILITY_ICONS = ["airstrike", "freeze", "funding"]

# -- Props --

PROP_IDS = [
    ("barricade", "Concrete barricade", "32x24"),
    ("burnt_car", "Burnt vehicle", "48x32"),
    ("floodlight", "Floodlight", "16x32"),
    ("razor_wire", "Razor wire", "32x8"),
    ("rubble_small", "Rubble pile (small)", "16x16"),
    ("rubble_large", "Rubble pile (large)", "32x24"),
    ("dumpster", "Dumpster", "24x16"),
    ("street_lamp", "Street lamp (broken)", "8x32"),
    ("signs_ground", "Protest signs (ground)", "16x8"),
    ("traffic_cone", "Traffic cone", "8x8"),
    ("burning_barrel", "Burning barrel", "16x16"),
    ("sandbags", "Sandbag wall", "32x16"),
]


# ---------------------------------------------------------------------------
# Scanner
# ---------------------------------------------------------------------------

def scan_sprites() -> dict[str, set[str]]:
    """Return {category: set_of_relative_paths} for all .png files under sprites/.

    For categories with subfolders (towers, enemies), paths include the subfolder:
    e.g. "rubber_bullet/base.png", "rioter/walk_se_01.png"
    For flat categories, paths are just filenames: e.g. "proj_rubber_bullet.png"
    """
    result: dict[str, set[str]] = {}
    for cat_dir in sorted(SPRITES_DIR.iterdir()):
        if not cat_dir.is_dir() or cat_dir.name.startswith("_"):
            continue
        pngs: set[str] = set()
        # Scan flat PNGs
        for f in cat_dir.glob("*.png"):
            pngs.add(f.name)
        # Scan subfolder PNGs (towers/rubber_bullet/base.png -> "rubber_bullet/base.png")
        for sub_dir in sorted(cat_dir.iterdir()):
            if sub_dir.is_dir() and not sub_dir.name.startswith("_"):
                for f in sub_dir.glob("*.png"):
                    pngs.add(f"{sub_dir.name}/{f.name}")
        result[cat_dir.name] = pngs
    return result


def file_exists(category: str, filename: str, disk: dict[str, set[str]]) -> bool:
    return filename in disk.get(category, set())


# ---------------------------------------------------------------------------
# Checklist generator
# ---------------------------------------------------------------------------

def status_icon(exists: bool) -> str:
    return "[x]" if exists else "[ ]"


def generate_checklist(disk: dict[str, set[str]]) -> str:
    lines: list[str] = []
    total_expected = 0
    total_done = 0

    def w(s: str = "") -> None:
        lines.append(s)

    w("# Goligee -- Asset Checklist")
    w()
    w("> Auto-generated by `tools/sync_assets.py`. Do NOT edit manually.")
    w("> Run `python tools/sync_assets.py` after any sprite change to update.")
    w("> Status: `[ ]` pending, `[x]` done")
    w()
    w("---")
    w()

    # -- Tiles --
    w("## Tiles (32x16)")
    w()
    w("| # | Tile | Variants | Files | Status |")
    w("|---|------|----------|-------|--------|")
    tile_done = 0
    tile_total = 0
    for i, (tid, name, variants) in enumerate(TILE_IDS, 1):
        matching = [f for f in disk.get("tiles", set()) if f.startswith(f"tile_{tid}")]
        exists = len(matching) > 0
        tile_total += 1
        if exists:
            tile_done += 1
        w(f"| {i} | {name} | {variants} | `tiles/tile_{tid}*.png` | {status_icon(exists)} {', '.join(matching) if exists else ''} |")
    total_expected += tile_total
    total_done += tile_done
    w()
    w(f"**Progress: {tile_done}/{tile_total} tiles**")
    w()
    w("---")
    w()

    # -- Towers (Base + Turret) --
    w("## Towers -- Base + Turret Architecture")
    w()
    w("Each tower needs: 1 base platform (64x64) + 8 turret directions (48x48).")
    w()
    w("| # | Tower | Base | Turret Dirs | Status |")
    w("|---|-------|------|-------------|--------|")
    tower_done = 0
    tower_total = 0
    for i, (tid, name) in enumerate(TOWER_IDS, 1):
        base_file = f"{tid}/base.png"
        base_ok = file_exists("towers", base_file, disk)
        tower_total += 1
        if base_ok:
            tower_done += 1

        turret_count = 0
        for d in TURRET_DIRS:
            turret_file = f"{tid}/turret_{d}.png"
            tower_total += 1
            if file_exists("towers", turret_file, disk):
                turret_count += 1
                tower_done += 1

        all_ok = base_ok and turret_count == 8
        status = status_icon(all_ok)
        if not all_ok and (base_ok or turret_count > 0):
            parts = []
            if base_ok:
                parts.append("base")
            if turret_count > 0:
                parts.append(f"{turret_count}/8 turrets")
            status = f"[~] {', '.join(parts)}"
        w(f"| {i} | {name} | {status_icon(base_ok)} | {turret_count}/8 | {status} |")

    legacy_found = 0

    total_expected += tower_total
    total_done += tower_done
    w()
    w(f"**Progress: {tower_done}/{tower_total} tower sprites** (base+turret)")
    if legacy_found > 0:
        w(f"*Legacy idle/active files found: {legacy_found}*")
    w()

    # Tier 5
    w("### Tier 5 Variants (Phase 4)")
    w()
    w("Each tier 5 variant needs 8 turret directions (like the base tier).")
    w()
    w("| # | Tier 5 Tower | Path | Base | Turret Dirs | Status |")
    w("|---|-------------|------|------|-------------|--------|")
    t5_done = 0
    t5_total = 0
    for i, (tid, t5name, path) in enumerate(TOWER_TIER5, 1):
        # tid is like "rubber_bullet_tier5a" -> tower_id = "rubber_bullet", variant = "tier5a"
        parts = tid.rsplit("_", 1)
        tower_id = parts[0].rsplit("_", 1)[0]  # e.g. "rubber_bullet"
        variant = tid.replace(tower_id + "_", "")  # e.g. "tier5a"
        # Base for this variant
        base_file = f"{tower_id}/{variant}_base.png"
        base_ok = file_exists("towers", base_file, disk)
        t5_total += 1
        if base_ok:
            t5_done += 1
        # Turret directions for this variant
        turret_count = 0
        for d in TURRET_DIRS:
            turret_file = f"{tower_id}/{variant}_turret_{d}.png"
            t5_total += 1
            if file_exists("towers", turret_file, disk):
                turret_count += 1
                t5_done += 1
        all_ok = base_ok and turret_count == 8
        status = status_icon(all_ok)
        if not all_ok and (base_ok or turret_count > 0):
            parts_done = []
            if base_ok:
                parts_done.append("base")
            if turret_count > 0:
                parts_done.append(f"{turret_count}/8 turrets")
            status = f"[~] {', '.join(parts_done)}"
        elif not all_ok:
            status = "[ ]"
        w(f"| {i} | {t5name} | {path} | {status_icon(base_ok)} | {turret_count}/8 | {status} |")
    total_expected += t5_total
    total_done += t5_done
    w()
    w(f"**Progress: {t5_done}/{t5_total} tier 5 turret sprites**")
    w()
    w("---")
    w()

    # -- Enemies (8-direction walk cycles) --
    w("## Standard Enemies (32x32)")
    w()
    w("Each enemy needs: 8-direction walk cycle (4 frames each = 32 frames per enemy).")
    w()
    w("| # | Enemy | Size | SE_01 | Total Frames | Status |")
    w("|---|-------|------|-------|--------------|--------|")
    enemy_frame_done = 0
    enemy_frame_total = 0
    for i, (eid, name, size) in enumerate(ENEMY_IDS, 1):
        se01 = f"{eid}/walk_se_01.png"
        se01_ok = file_exists("enemies", se01, disk)
        all_frames = []
        for d in ENEMY_DIRS:
            for f in ENEMY_FRAMES:
                fname = f"{eid}/walk_{d}_{f}.png"
                all_frames.append(fname)
                enemy_frame_total += 1
                if file_exists("enemies", fname, disk):
                    enemy_frame_done += 1
        existing = [f for f in all_frames if file_exists("enemies", f, disk)]
        count = len(existing)
        expected = 32  # 8 dirs x 4 frames
        status = status_icon(count == expected)
        if 0 < count < expected:
            dirs_done = set()
            for f in existing:
                parts = f.split("/")[-1].replace("walk_", "").replace(".png", "").rsplit("_", 1)
                if len(parts) == 2:
                    dirs_done.add(parts[0].upper())
            status = f"[~] {count}/{expected} ({', '.join(sorted(dirs_done))})"
        elif count == 0:
            status = "[ ]"
        w(f"| {i} | {name} | {size} | {status_icon(se01_ok)} | {count}/{expected} | {status} |")
    total_expected += enemy_frame_total
    total_done += enemy_frame_done
    w()
    w(f"**Progress: {enemy_frame_done}/{enemy_frame_total} enemy frames**")
    w()
    w("---")
    w()

    # -- Bosses --
    w("## Boss Enemies (48x48)")
    w()
    w("| # | Boss | States | Files Found | Status |")
    w("|---|------|--------|-------------|--------|")
    boss_done = 0
    boss_total = 0
    for i, (bid, name, states_str) in enumerate(BOSS_IDS, 1):
        states = states_str.split(",")
        found = [f for f in disk.get("bosses", set()) if f.startswith(f"boss_{bid}_")]
        expected = len(states) * 4
        boss_total += expected
        boss_done += len(found)
        status = status_icon(len(found) >= expected)
        if 0 < len(found) < expected:
            status = f"[~] {len(found)}/{expected}"
        elif len(found) == 0:
            status = "[ ]"
        w(f"| {i} | {name} | {states_str} | {len(found)}/{expected} | {status} |")
    total_expected += boss_total
    total_done += boss_done
    w()
    w(f"**Progress: {boss_done}/{boss_total} boss frames**")
    w()
    w("---")
    w()

    # -- Projectiles --
    w("## Projectiles (8x8 to 16x16)")
    w()
    w("| # | Projectile | Size | File | Status |")
    w("|---|-----------|------|------|--------|")
    proj_done = 0
    proj_total = 0
    for i, (pid, name, size) in enumerate(PROJECTILE_IDS, 1):
        fname = f"proj_{pid}.png"
        exists = file_exists("projectiles", fname, disk)
        proj_total += 1
        if exists:
            proj_done += 1
        w(f"| {i} | {name} | {size} | `projectiles/{fname}` | {status_icon(exists)} |")
    total_expected += proj_total
    total_done += proj_done
    w()
    w(f"**Progress: {proj_done}/{proj_total} projectile sprites**")
    w()
    w("---")
    w()

    # -- Effects --
    w("## Effects (16x16 to 32x32)")
    w()
    w("### Impact/Explosion Effects")
    w()
    w("| # | Effect | Size | Frames | Found | Status |")
    w("|---|--------|------|--------|-------|--------|")
    fx_done = 0
    fx_total = 0
    for i, (eid, name, size, frames) in enumerate(EFFECT_EXPLOSION_IDS, 1):
        found = 0
        for f in range(1, frames + 1):
            fname = f"effect_explosion_{eid}_{f:02d}.png"
            fx_total += 1
            if file_exists("effects", fname, disk):
                found += 1
                fx_done += 1
        status = status_icon(found == frames)
        if 0 < found < frames:
            status = f"[~] {found}/{frames}"
        elif found == 0:
            status = "[ ]"
        w(f"| {i} | {name} | {size} | {frames} | {found}/{frames} | {status} |")

    w()
    w("### Status Effect Overlays")
    w()
    w("| # | Status | Size | Frames | Found | Status |")
    w("|---|--------|------|--------|-------|--------|")
    for i, (sid, name, size, frames) in enumerate(EFFECT_STATUS_IDS, 1):
        found = 0
        for f in range(1, frames + 1):
            fname = f"effect_status_{sid}_{f:02d}.png"
            fx_total += 1
            if file_exists("effects", fname, disk):
                found += 1
                fx_done += 1
        status = status_icon(found == frames)
        if 0 < found < frames:
            status = f"[~] {found}/{frames}"
        elif found == 0:
            status = "[ ]"
        w(f"| {i} | {name} | {size} | {frames} | {found}/{frames} | {status} |")
    total_expected += fx_total
    total_done += fx_done
    w()
    w(f"**Progress: {fx_done}/{fx_total} effect frames**")
    w()
    w("---")
    w()

    # -- City Buildings --
    w("## City Buildings (background)")
    w()
    w("| # | Building | Size | File | Status |")
    w("|---|----------|------|------|--------|")
    bldg_done = 0
    bldg_total = 0
    for i, (bid, name, size) in enumerate(BUILDING_IDS, 1):
        fname = f"building_{bid}.png"
        exists = file_exists("buildings", fname, disk)
        bldg_total += 1
        if exists:
            bldg_done += 1
        w(f"| {i} | {name} | {size} | `buildings/{fname}` | {status_icon(exists)} |")
    total_expected += bldg_total
    total_done += bldg_done
    w()
    w(f"**Progress: {bldg_done}/{bldg_total} building sprites**")
    w()
    w("---")
    w()

    # -- Animated Details --
    w("## Animated Details")
    w()
    w("| # | Detail | Size | Frames | Found | Status |")
    w("|---|--------|------|--------|-------|--------|")
    anim_done = 0
    anim_total = 0
    for i, (aid, name, size, frames) in enumerate(ANIMATED_IDS, 1):
        found = 0
        for f in range(1, frames + 1):
            fname = f"anim_{aid}_{f:02d}.png"
            anim_total += 1
            if file_exists("animated", fname, disk):
                found += 1
                anim_done += 1
        status = status_icon(found == frames)
        if 0 < found < frames:
            status = f"[~] {found}/{frames}"
        elif found == 0:
            status = "[ ]"
        w(f"| {i} | {name} | {size} | {frames} | {found}/{frames} | {status} |")
    total_expected += anim_total
    total_done += anim_done
    w()
    w(f"**Progress: {anim_done}/{anim_total} animated frames**")
    w()
    w("---")
    w()

    # -- UI Icons --
    w("## UI Icons (16x16 or 32x32)")
    w()
    ui_done = 0
    ui_total = 0

    w("### Tower Build Menu Icons")
    w()
    w("| # | Icon | File | Status |")
    w("|---|------|------|--------|")
    for i, tid in enumerate(UI_TOWER_ICONS, 1):
        fname = f"icon_tower_{tid}.png"
        exists = file_exists("ui", fname, disk)
        ui_total += 1
        if exists:
            ui_done += 1
        w(f"| {i} | {dict(TOWER_IDS).get(tid, tid)} | `ui/{fname}` | {status_icon(exists)} |")

    w()
    w("### Damage Type Icons")
    w()
    w("| # | Icon | File | Status |")
    w("|---|------|------|--------|")
    for i, did in enumerate(UI_DMG_ICONS, 1):
        fname = f"icon_dmg_{did}.png"
        exists = file_exists("ui", fname, disk)
        ui_total += 1
        if exists:
            ui_done += 1
        w(f"| {i} | {did.capitalize()} | `ui/{fname}` | {status_icon(exists)} |")

    w()
    w("### HUD Icons")
    w()
    w("| # | Icon | File | Status |")
    w("|---|------|------|--------|")
    for i, hid in enumerate(UI_HUD_ICONS, 1):
        fname = f"icon_{hid}.png"
        exists = file_exists("ui", fname, disk)
        ui_total += 1
        if exists:
            ui_done += 1
        w(f"| {i} | {hid.replace('_', ' ').title()} | `ui/{fname}` | {status_icon(exists)} |")

    w()
    w("### Active Ability Icons")
    w()
    w("| # | Icon | File | Status |")
    w("|---|------|------|--------|")
    for i, aid in enumerate(UI_ABILITY_ICONS, 1):
        fname = f"icon_ability_{aid}.png"
        exists = file_exists("ui", fname, disk)
        ui_total += 1
        if exists:
            ui_done += 1
        w(f"| {i} | {aid.capitalize()} | `ui/{fname}` | {status_icon(exists)} |")
    total_expected += ui_total
    total_done += ui_done
    w()
    w(f"**Progress: {ui_done}/{ui_total} UI icon sprites**")
    w()
    w("---")
    w()

    # -- Props --
    w("## Environment Props")
    w()
    w("| # | Prop | Size | File | Status |")
    w("|---|------|------|------|--------|")
    prop_done = 0
    prop_total = 0
    for i, (pid, name, size) in enumerate(PROP_IDS, 1):
        fname = f"prop_{pid}.png"
        exists = file_exists("props", fname, disk)
        prop_total += 1
        if exists:
            prop_done += 1
        w(f"| {i} | {name} | {size} | `props/{fname}` | {status_icon(exists)} |")
    total_expected += prop_total
    total_done += prop_done
    w()
    w(f"**Progress: {prop_done}/{prop_total} prop sprites**")
    w()
    w("---")
    w()

    # -- Summary --
    w("## Summary")
    w()
    w("| Category | Done | Total |")
    w("|----------|------|-------|")
    w(f"| Tiles | {sum(1 for t,_,_ in TILE_IDS if any(f.startswith(f'tile_{t}') for f in disk.get('tiles', set())))} | {len(TILE_IDS)} |")
    w(f"| Towers (base+turret) | {tower_done} | {tower_total} |")
    w(f"| Towers (tier 5 turrets) | {t5_done} | {t5_total} |")
    w(f"| Enemy frames | {enemy_frame_done} | {enemy_frame_total} |")
    w(f"| Boss frames | {boss_done} | {boss_total} |")
    w(f"| Projectiles | {proj_done} | {proj_total} |")
    w(f"| Effect frames | {fx_done} | {fx_total} |")
    w(f"| City buildings | {bldg_done} | {bldg_total} |")
    w(f"| Animated details | {anim_done} | {anim_total} |")
    w(f"| UI icons | {ui_done} | {ui_total} |")
    w(f"| Props | {prop_done} | {prop_total} |")
    w(f"| **TOTAL** | **{total_done}** | **{total_expected}** |")
    w()

    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Overview sheet generator
# ---------------------------------------------------------------------------

BG_COLOR = (24, 24, 28)
LABEL_COLOR = (200, 200, 208)
HEADER_COLOR = (200, 160, 64)
BORDER_COLOR = (58, 58, 62)
SCALE = 2
CELL_PAD = 6 * SCALE
LABEL_H = 16 * SCALE
HEADER_H = 24 * SCALE
FONT_SIZE = 10 * SCALE
HEADER_FONT_SIZE = 14 * SCALE


def _load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in [
        "/System/Library/Fonts/Menlo.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def _load_category_entries(category: str, disk: dict[str, set[str]]) -> list[tuple[str, Image.Image]]:
    cat_dir = SPRITES_DIR / category
    if not cat_dir.is_dir():
        return []
    pngs = sorted(f for f in disk.get(category, set()))
    entries: list[tuple[str, Image.Image]] = []
    for rel_path in pngs:
        fpath = cat_dir / rel_path
        try:
            img = Image.open(fpath).convert("RGBA")
            img = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
            label = rel_path.replace(".png", "").replace("/", "_")
            entries.append((label, img))
        except Exception:
            continue
    return entries


def _draw_grid(
    sheet: Image.Image,
    draw: ImageDraw.Draw,
    entries: list[tuple[str, Image.Image]],
    font: ImageFont.FreeTypeFont,
    offset_y: int = 0,
    max_cols: int = 8,
) -> tuple[int, int]:
    if not entries:
        return (0, 0)

    max_w = max(img.width for _, img in entries)
    max_h = max(img.height for _, img in entries)

    cols = min(max_cols, len(entries))
    rows = (len(entries) + cols - 1) // cols

    cell_w = max_w + CELL_PAD * 2
    cell_h = max_h + CELL_PAD * 2 + LABEL_H

    for idx, (label, img) in enumerate(entries):
        col = idx % cols
        row = idx // cols
        x0 = CELL_PAD + col * cell_w
        y0 = offset_y + CELL_PAD + row * cell_h

        draw.rectangle(
            [x0, y0, x0 + cell_w - 1, y0 + cell_h - 1],
            outline=BORDER_COLOR,
        )

        sx = x0 + (cell_w - img.width) // 2
        sy = y0 + CELL_PAD
        sheet.paste(img, (sx, sy), img)

        max_label_chars = cell_w // (FONT_SIZE // 2 + 1)
        display_label = label[:max_label_chars]
        lx = x0 + CELL_PAD
        ly = y0 + cell_h - LABEL_H - 2
        draw.text((lx, ly), display_label, fill=LABEL_COLOR, font=font)

    total_w = cols * cell_w + CELL_PAD * 2
    total_h = rows * cell_h + CELL_PAD * 2
    return (total_w, total_h)


def generate_overview(category: str, disk: dict[str, set[str]]) -> Path | None:
    entries = _load_category_entries(category, disk)
    if not entries:
        return None

    max_w = max(img.width for _, img in entries)
    max_h = max(img.height for _, img in entries)

    cols = min(8, len(entries))
    rows = (len(entries) + cols - 1) // cols

    cell_w = max_w + CELL_PAD * 2
    cell_h = max_h + CELL_PAD * 2 + LABEL_H

    sheet_w = cols * cell_w + CELL_PAD * 2
    sheet_h = rows * cell_h + CELL_PAD * 2

    sheet = Image.new("RGBA", (sheet_w, sheet_h), BG_COLOR + (255,))
    draw = ImageDraw.Draw(sheet)
    font = _load_font(FONT_SIZE)

    _draw_grid(sheet, draw, entries, font)

    OVERVIEW_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OVERVIEW_DIR / f"overview_{category}.png"
    sheet.save(out_path, "PNG")
    return out_path


def generate_total_overview(disk: dict[str, set[str]]) -> Path | None:
    category_order = [
        "towers", "enemies", "projectiles", "effects",
        "buildings", "animated",
        "tiles", "bosses", "props", "ui",
    ]
    categories_with_sprites = [c for c in category_order if disk.get(c)]

    if not categories_with_sprites:
        return None

    font = _load_font(FONT_SIZE)
    header_font = _load_font(HEADER_FONT_SIZE)

    sections: list[tuple[str, list[tuple[str, Image.Image]]]] = []
    total_height = CELL_PAD
    max_width = 0

    for cat in categories_with_sprites:
        entries = _load_category_entries(cat, disk)
        if not entries:
            continue

        sections.append((cat, entries))

        max_w = max(img.width for _, img in entries)
        max_h = max(img.height for _, img in entries)
        cols = min(8, len(entries))
        rows = (len(entries) + cols - 1) // cols
        cell_w = max_w + CELL_PAD * 2
        cell_h = max_h + CELL_PAD * 2 + LABEL_H

        section_w = cols * cell_w + CELL_PAD * 2
        section_h = HEADER_H + rows * cell_h + CELL_PAD * 2

        max_width = max(max_width, section_w)
        total_height += section_h + CELL_PAD

    if not sections:
        return None

    sheet = Image.new("RGBA", (max_width, total_height), BG_COLOR + (255,))
    draw = ImageDraw.Draw(sheet)

    y_offset = CELL_PAD
    for cat, entries in sections:
        label = cat.upper()
        count = len(entries)
        header_text = f"{label} ({count})"
        draw.text((CELL_PAD, y_offset), header_text, fill=HEADER_COLOR, font=header_font)
        y_offset += HEADER_H

        _, section_h = _draw_grid(sheet, draw, entries, font, offset_y=y_offset)
        y_offset += section_h + CELL_PAD

    sheet = sheet.crop((0, 0, max_width, y_offset))

    OVERVIEW_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OVERVIEW_DIR / "overview_TOTAL.png"
    sheet.save(out_path, "PNG")
    return out_path


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Sync asset checklist and overview sheets")
    parser.add_argument("--check", action="store_true", help="Dry run: report status only")
    parser.add_argument("--overviews", action="store_true", help="Regenerate overview sheets only")
    parser.add_argument("--checklist", action="store_true", help="Update checklist only")
    args = parser.parse_args()

    do_both = not args.overviews and not args.checklist
    do_checklist = do_both or args.checklist
    do_overviews = do_both or args.overviews

    disk = scan_sprites()

    print("=== Goligee Asset Sync ===")
    for cat in sorted(disk.keys()):
        print(f"  {cat}: {len(disk[cat])} sprites")
    print()

    if do_checklist:
        checklist = generate_checklist(disk)
        if args.check:
            print("--- Checklist (dry run) ---")
            print(checklist)
        else:
            CHECKLIST_PATH.parent.mkdir(parents=True, exist_ok=True)
            CHECKLIST_PATH.write_text(checklist)
            print(f"Updated: {CHECKLIST_PATH.relative_to(PROJECT_ROOT)}")

    if do_overviews and not args.check:
        categories = [c for c in disk.keys() if disk[c]]
        for cat in categories:
            out = generate_overview(cat, disk)
            if out:
                print(f"Generated: {out.relative_to(PROJECT_ROOT)}")
            else:
                print(f"Skipped: {cat} (no sprites)")

        out = generate_total_overview(disk)
        if out:
            print(f"Generated: {out.relative_to(PROJECT_ROOT)}")

    print("\nDone.")


if __name__ == "__main__":
    main()
