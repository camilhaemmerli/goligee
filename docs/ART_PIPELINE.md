# Goligee -- AI Art Pipeline

> How to generate ~800+ pixel art sprites for the game using AI tools with manual cleanup.

---

## Tool Stack

### Primary: PixelLab ($22/mo Pro)

Purpose-built pixel art generation. Use for all final production sprites.

| Feature | Why It Matters |
|---------|----------------|
| 8-direction rotation | All 8 isometric views from one reference sprite |
| Character creation | Persistent server-side characters for consistent animation |
| Walk cycle animation | 4-frame walk cycles for all 8 directions in one API call |
| Wang-style tilesets | Auto-connected tileset generation |
| Map objects | Transparent-background environment objects |
| Style reference | Upload golden standards, all output matches |
| Aseprite integration | Generate and refine in pixel art editor |

Known limitation: minimum output is 32x32px.

- Site: https://www.pixellab.ai/
- Pricing: $9/mo Starter (1000 images), $22/mo Pro (6000 images)

### Key PixelLab API Endpoints

| Endpoint | Purpose | Size Limits |
|----------|---------|-------------|
| `/generate-8-rotations-v2` | 8 consistent rotations from 1 reference | 32-84px |
| `/create-character-with-8-directions` | Persistent character with 8 directional views | 32-400px |
| `/characters/animations` | Animate stored characters (walk, run, death) | inherited |
| `/map-objects` | Transparent-bg environment objects | 32-400px |
| `/create-image-pixflux` | General sprite generation | 16-400px |
| `/animate-with-text-v2` | Animate static sprite from text | 32-128px |
| `/create-tileset` | Wang-style connected tilesets | 32px tiles |
| `/inpaint` | Edit specific regions of a sprite | varies |

### Secondary: Gemini 2.5 Flash Image (API)

Dirt cheap (~$0.01-0.04/image) for rapid concept exploration.

- Godot plugin: https://github.com/SynidSweet/godot-ai-image-generator
- Good for: concept art, exploring variations, UI mockups, effect concepts
- Requires post-processing: pixelation pass, palette enforcement
- Not a replacement for PixelLab for final sprites

### Cleanup: Aseprite ($20 or compile free)

- Purchase: https://store.steampowered.com/app/431730/Aseprite/
- Free build: https://github.com/aseprite/aseprite/blob/main/INSTALL.md
- Install the PixelLab Aseprite plugin for direct AI generation
- Workflow: palette enforcement, grid fixes, animation timing, sprite sheet export
- Expect ~20% manual touch-up on AI output

### Alternative: Retro Diffusion

FLUX-based, grid-aligned pixel art generation. Good fallback if PixelLab doesn't work well for a specific asset type. Prompt-driven consistency. See https://runware.ai/blog/retro-diffusion-creating-authentic-pixel-art-with-ai-at-scale

---

## Prompt Architecture

### Scene/Environment Prompt (tiles, props, buildings, tower bases)

```
16-bit isometric pixel art, isometric 3/4 view,
light source from top-left casting shadows to bottom-right,
left faces brightest, right faces mid-tone, bottom faces darkest,
satirical riot control police state setting,
Soviet brutalist architecture influence, panelka apartment blocks,
raw concrete angular geometry, crumbling prefab facades,
broken windows and rusted playgrounds,
comically exaggerated militarized police equipment,
dark night scene lit by harsh overhead floodlights from top-left,
cold concrete and gunmetal gray palette with warning amber and emergency red accents,
desaturated muted tones, oppressive authoritarian dystopia,
post-Soviet urban decay, graffiti and grime, razor barbed wire,
clean pixel grid, no anti-aliasing, detailed 16-bit shading
```

### Character Prompt (enemies, isolated sprites)

> **Important:** Do NOT use the full scene prompt for characters -- it causes background bleed.
> Use this minimal character-only template instead:

```
pixel art character sprite, isometric 3/4 view, facing south-east,
walking pose, dark muted colors, gunmetal gray and warm accents,
16-bit style
```

### Turret/Weapon Prompt (tower turret heads)

```
pixel art weapon sprite, top-down isometric view,
centered weapon head only, no base no platform,
dark metallic military equipment, clean pixel grid,
transparent background
```

### Palette Enforcement

Always include hex values in prompts. Reference `moodboard/COLOR_PALETTE.md` for the full palette.

**Core grays (80% of pixels):**
```
#0E0E12 #161618 #1A1A1E #1E1E22 #28282C #2E2E32
#3A3A3E #484850 #585860 #606068 #808898
```

**Warm accents (20% of pixels):**
```
#C8A040 #D8A040 #E8A040 #D06030 #D04040 #903020
```

See `docs/PROMPT_TEMPLATES.md` for copy-paste-ready prompts per asset category.

---

## Tower Architecture: Base + Turret

Towers use a **two-layer sprite system** for smooth aiming without runtime rotation:

```
BaseTower (Node2D)
├── Sprite2D (BaseSprite)     ← base_{name}.png (64x64, static platform)
├── TurretSprite (Sprite2D)   ← turret_{name}_{dir}.png (48x48, swapped by angle)
├── MuzzlePoint (Marker2D)    ← projectile spawn + muzzle flash position
├── RangeArea (Area2D)
├── WeaponComponent
├── TargetingComponent
└── UpgradeComponent
```

### How It Works

1. **Base sprite** is static -- the platform/housing that never moves
2. **Turret sprite** is swapped between 8 pre-rendered directions based on target angle
3. All 8 turret directions are generated from a single SE reference using `/generate-8-rotations-v2`
4. This ensures visual consistency across all 8 views (same weapon, same style)
5. **Bases scale up with evolution** -- higher tiers get progressively larger base platforms to visually communicate power growth

### Base Size Progression

| Tier | Base Size | Notes |
|------|-----------|-------|
| Base (tier 0) | 64x64 | Starting platform |
| Tier 5 variants | 80x80+ | Larger, more imposing platform |

Each tower type has a unique base design. Each tier 5 variant also gets its own unique, larger base.

### Turret Aiming Logic

```gdscript
const DIRS = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]

func _aim_at(target_pos: Vector2) -> void:
    var angle = global_position.angle_to_point(target_pos)
    var adjusted = angle + PI / 2.0  # 0=south
    var idx = wrapi(roundi(adjusted / (TAU / 8.0)), 0, 8)
    turret_sprite.texture = turret_textures[idx]
```

### Generation Flow

```
1. Generate 1 turret reference (SE, 48x48) via /create-image-pixflux
2. Feed reference to /generate-8-rotations-v2 → 8 consistent turret sprites
3. Generate 1 base platform (64x64) via /map-objects
4. Repeat for all 8 tower types
```

**API cost: 8 turret refs + 8 rotation calls + 8 bases = 24 calls → 72 sprites**

---

## Enemy Architecture: 8-Direction Walk Cycles

Enemies use **persistent PixelLab characters** with animated walk cycles:

```
BaseEnemy (Node2D)
├── AnimatedSprite2D          ← SpriteFrames with animations:
│                                walk_{dir}  (8 walk cycles)
│                                hit_{dir}   (optional hit flinch)
│                                death_{dir} (optional death anim, fallback: death_se)
├── HealthComponent
├── ResistanceComponent
├── StatusEffectManager
├── LootComponent
└── HealthBar
```

### How It Works

1. Create a character on PixelLab servers via `/create-character-with-8-directions`
2. Store the returned `character_id` in `tools/.character_manifest.json`
3. Animate the character via `/characters/animations` with `template_animation_id: "walking-4-frames"`
4. `directions: null` animates all 8 directions in one call → 32 walk frames per enemy

### Direction Detection

```gdscript
const DIR_NAMES = ["e", "ne", "n", "nw", "w", "sw", "s", "se"]

func _update_animation_direction(move_dir: Vector2) -> void:
    var angle = move_dir.angle()
    var idx = wrapi(roundi(angle / (TAU / 8.0)), 0, 8)
    var dir_name = DIR_NAMES[idx]
    animated_sprite.play("walk_" + dir_name)
```

### Generation Flow

```
1. Create character (8 directional views) via /create-character-with-8-directions
2. Store character_id in manifest
3. Generate walk animations via /characters/animations (walking-4-frames)
4. Generate death animations via /characters/animations (falling-back-death)
5. Repeat for all 16 enemy types
```

**API cost: 16 character calls + 16 walk anim + 16 death anim = 48 calls → 800+ sprites**

### Hit & Death Visual System

- **Hit reaction**: 1.5px micro-knockback opposite to movement (0.1s). If `hit_{dir}` animation exists in SpriteFrames, plays 1 frame then resumes walk. Falls back to white flash shader if no hit anim.
- **Death corpse**: Plays `death_{dir}` animation (fallback `death_se`). Tints corpse dark (#3A3A3E), sets z_index=-1. Corpse lingers 2.5s, fades out over 0.5s. Global cap of 30 corpses (oldest auto-freed).
- **EnemySkinData** has optional `corpse_texture: Texture2D` for static corpse frames.

---

## City Background

Decorative city layer behind the play field for atmosphere:

```
Game (Node2D)
├── CityBackground (Node2D, z_index=-10)
│   ├── BuildingsLeft (Node2D)      ← panelka blocks along left edge
│   ├── BuildingsRight (Node2D)     ← buildings along right edge
│   ├── GovernmentBuilding (Node2D) ← the building being defended
│   ├── AnimatedDetails (Node2D)
│   │   ├── BurningBarrel (AnimatedSprite2D, 4-frame loop)
│   │   ├── WavingFlag (AnimatedSprite2D, 4-frame loop)
│   │   ├── FlickerWindow (Sprite2D + shader)
│   │   └── SteamVent (GPUParticles2D)
│   └── BackgroundDim (CanvasModulate)
├── World (Node2D, y_sort_enabled=true)
│   ├── TileMapLayer
│   ├── Towers / Enemies / Projectiles / Effects
└── HUD (CanvasLayer)
```

### Generation

- Buildings: `/map-objects` at 128x128 to 256x192 with `remove_background()` post-process
- Animated details: `/animate-with-text-v2` for 4-frame loops (barrel, flag, neon sign)
- Shader effects: window flicker, searchlight sweep (zero API calls)

---

## Production Workflow

### Phase A: Foundation Test (1 tower + 1 enemy)

Test the full pipeline before batch-generating everything:

1. Generate 1 turret ref (rubber_bullet SE) → run 8-rotation → verify consistency
2. Generate 1 base (rubber_bullet) → verify it layers with turret in Godot
3. Create 1 enemy character (rioter) → generate walk cycle → verify frames
4. **Review results before proceeding**

```bash
python tools/generate_assets.py --test-foundation
```

### Phase B: Full Tower Set

```bash
python tools/generate_assets.py --phase turrets
python tools/generate_assets.py --phase bases
```

| Step | API Calls | Output |
|------|-----------|--------|
| Turret refs (SE) | 8 | 8 reference sprites |
| 8-rotations | 8 | 64 turret direction sprites |
| Base platforms | 8 | 8 base sprites |
| **Total** | **24** | **80 sprites** |

### Phase C: Full Enemy Set

```bash
python tools/generate_assets.py --phase enemy-chars
python tools/generate_assets.py --phase enemy-anims
```

| Step | API Calls | Output |
|------|-----------|--------|
| Character creation (8-dir) | 16 | 128 directional views |
| Walk animations (8-dir × 4 frames) | 16 | 512 walk frames |
| **Total** | **32** | **640 sprites** |

### Phase D: Projectiles + Effects

```bash
python tools/generate_assets.py --phase projectiles
python tools/generate_assets.py --phase effects
```

| Step | API Calls | Output |
|------|-----------|--------|
| Projectiles | 8 | 8 sprites |
| Effects | 13 | 13 sprites |
| **Total** | **21** | **21 sprites** |

### Phase E: City Background

```bash
python tools/generate_assets.py --phase city
python tools/generate_assets.py --phase animated
```

| Step | API Calls | Output |
|------|-----------|--------|
| City buildings | 8 | 8 building sprites |
| Animated details | 3 | 12 animation frames |
| **Total** | **11** | **20 sprites** |

### Phase F: Tilesets, Props, UI, Bosses

```bash
python tools/generate_assets.py --phase tilesets
python tools/generate_assets.py --phase props
python tools/generate_assets.py --phase ui
python tools/generate_assets.py --phase bosses
```

### Run Everything

```bash
python tools/generate_assets.py --phase all
```

---

## File Naming Convention

Towers and enemies use **per-type subfolders** for organization. All other categories use flat naming.

```
# Towers (subfolder per tower type)
assets/sprites/towers/{id}/base.png                    # rubber_bullet/base.png (64x64)
assets/sprites/towers/{id}/turret_ref.png              # rubber_bullet/turret_ref.png (SE reference)
assets/sprites/towers/{id}/turret_{dir}.png            # rubber_bullet/turret_se.png (48x48)
assets/sprites/towers/{id}/tier5{a|b|c}_turret_{dir}.png  # rubber_bullet/tier5a_turret_se.png

# Enemies (subfolder per enemy type)
assets/sprites/enemies/{id}/walk_{dir}_{frame}.png     # rioter/walk_se_01.png (32x32)

# City background (flat)
assets/sprites/buildings/building_{name}.png           # building_panelka_tall.png
assets/sprites/animated/anim_{name}_{frame}.png        # anim_burning_barrel_01.png

# Other categories (flat)
assets/sprites/bosses/boss_{id}_{state}_{frame}.png    # boss_demagogue_attack_03.png
assets/sprites/effects/effect_{type}_{frame}.png       # effect_explosion_kinetic_02.png
assets/sprites/tiles/tile_{type}_{variant}.png         # tile_ground_cracked.png
assets/sprites/projectiles/proj_{type}.png             # proj_tear_gas.png
assets/sprites/ui/icon_{name}.png                      # icon_tower_rubber_bullet.png
assets/sprites/props/prop_{name}.png                   # prop_barricade_01.png
```

### Sprite Counts Per Tower

Each tower needs **at minimum** 1 base + 8 turret directions = 9 sprites.
With tier 5 variants (each needing its own base + 8 turret directions), totals reach **41+ sprites per tower**.

Each evolution gets a **progressively larger base platform** (base tier → T5 = increasing size to show power growth).

| Component | Sprites | Formula |
|-----------|---------|---------|
| Base platform (base tier) | 1 | 64x64, unique per tower type |
| Turret ref (SE) | 1 | Reference for rotation generation |
| Base tier turrets | 8 | 8 directions, 48x48 |
| Tier 5 variant base | 1 each | Unique, larger than base tier |
| Tier 5 variant turrets | 8 each | 8 dirs × number of T5 variants |
| **Example: Rubber Bullet** | **37** | 1 base + 1 ref + 8 turrets + 3×(1 base + 8 turrets) |

### Directions (8 directions)

```
S, SW, W, NW, N, NE, E, SE
```

All towers and enemies use full 8-direction sprites.

---

## Sprite Sizes

All sprites are generated at **2x resolution** for quality, then displayed at native scale in-engine (Godot nearest-neighbor filtering).

| Category | Logical Size | File Size (2x) | Notes |
|----------|-------------|-----------------|-------|
| Enemy characters | 16x16 | 32x32 | Generated at 32x32 (PixelLab minimum for character endpoint) |
| Tower bases | 32x32 | 64x64 | Static platform, generated via `/map-objects` |
| Tower turrets | 24x24 | 48x48 | 8 directions, generated via `/generate-8-rotations-v2` |
| Boss enemies | 48x48 | 96x96 | 3x base unit |
| Iso tiles | 32x16 | 64x32 | 2:1 ratio |
| Projectiles | 8x8 to 16x16 | 16x16 to 32x32 | Varies by type |
| Effects | 16x16 to 32x32 | 32x32 to 64x64 | Varies by type |
| City buildings | 64x64 to 128x96 | 128x128 to 256x192 | Background decoration |
| UI icons | 16x16 or 32x32 | 32x32 or 64x64 | Consistent within category |

> **Note:** PixelLab minimum output is 32x32. The character creation endpoint requires 32x32 minimum. Smaller logical sprites (8x8 projectiles) are generated at 32x32 and trimmed/scaled as needed.

---

## API Budget

| Phase | API Calls | Sprites Produced |
|-------|-----------|-----------------|
| Tower turret refs (SE) | 8 | 8 |
| Tower 8-rotations | 8 | 64 |
| Tower bases | 8 | 8 |
| Enemy characters (8-dir) | 16 | 128 |
| Enemy walk cycles (8-dir) | 16 | 512 |
| Projectiles | 8 | 8 |
| Effects | 13 | 13 |
| City buildings | 8 | 8 |
| Animated details | 3 | 12 |
| Tilesets (optional) | 3 | ~50 |
| **Total** | **~91** | **~811** |

Leaves ~1750+ generations for iterations and future content (of 2000/month Pro plan).

---

## Asset Sync & Tracking

After ANY sprite change, run:

```bash
python tools/sync_assets.py
```

This script is the **single source of truth** for asset tracking:
- Scans `assets/sprites/` on disk
- Regenerates `docs/ASSET_CHECKLIST.md` with accurate per-file statuses
- Regenerates overview sheet PNGs in `assets/sprites/_overview/`
- `generate_assets.py` auto-calls sync after generation

> **Do NOT edit `ASSET_CHECKLIST.md` manually** -- it is auto-generated.

### Character Manifest

PixelLab character IDs are stored in `tools/.character_manifest.json` so walk cycles and other animations can be generated from persistent server-side characters:

```json
{
  "rioter": "char_abc123",
  "masked": "char_def456",
  ...
}
```

---

## Cost Estimate

| Item | Cost |
|------|------|
| PixelLab Pro (2 months) | ~$44 |
| Gemini API (~500 concept images) | ~$5-15 |
| Aseprite (purchase or compile free) | $0-20 |
| **Total** | **~$50-80** |

---

## Quality Checklist (per sprite)

Before marking any sprite as "done":

- [ ] Correct pixel dimensions (no sub-pixel or fractional sizes)
- [ ] No anti-aliasing (nearest-neighbor only)
- [ ] Colors snap to palette (see `moodboard/COLOR_PALETTE.md`)
- [ ] 80/20 gray/accent ratio maintained
- [ ] Clean pixel grid (no stray pixels, no orphan dots)
- [ ] Reads clearly at 1x zoom (no detail lost at native resolution)
- [ ] Isometric angle consistent (3/4 view, 2:1 tile ratio)
- [ ] Transparent background (PNG with alpha)
- [ ] Animation frames consistent (same anchor point, same bounding box)
- [ ] Tower turret consistency: all 8 directions look like the same weapon
- [ ] Enemy walk cycle consistency: character appearance matches across all frames/directions

---

## References

- [PixelLab](https://www.pixellab.ai/) -- primary generation tool
- [PixelLab Review](https://www.jonathanyu.xyz/2025/12/31/pixellab-review-the-best-ai-tool-for-2d-pixel-art-games/)
- [Retro Diffusion](https://runware.ai/blog/retro-diffusion-creating-authentic-pixel-art-with-ai-at-scale)
- [Godot AI Image Generator](https://github.com/SynidSweet/godot-ai-image-generator)
- [Gemini 2.5 Flash Image](https://developers.googleblog.com/en/introducing-gemini-2-5-flash-image/)
- [Scenario Iso Tiles](https://www.scenario.com/blog/build-isometric-game-tiles-ai)
