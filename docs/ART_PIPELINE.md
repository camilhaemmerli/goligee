# Goligee -- AI Art Pipeline

> How to generate ~400+ pixel art sprites for the game using AI tools with manual cleanup.

---

## Tool Stack

### Primary: PixelLab ($22/mo Pro)

Purpose-built pixel art generation. Use for all final production sprites.

| Feature | Why It Matters |
|---------|----------------|
| Directional rotation | 4/8 isometric views from one design |
| Style reference | Upload golden standards, all output matches |
| Aseprite integration | Generate and refine in pixel art editor |
| Animation support | Walk cycles, attack animations (4-8 frames) |
| Tileset tools | Map and environment tile generation |

Known limitation: quality drops below 16x16px (our minimum is 16x16, so fine).

- Site: https://www.pixellab.ai/
- Pricing: $9/mo Starter (1000 images), $22/mo Pro (6000 images)

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

### Base Prompt (prepend to ALL generations)

```
8-bit isometric pixel art, urban dystopia riot control setting,
night scene with harsh institutional lighting, cold concrete
and gunmetal gray palette with warning amber and emergency red
accents, desaturated muted colors, no anti-aliasing, clean pixel
grid, oppressive authoritarian atmosphere, post-apocalyptic urban
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

## Production Workflow

### Phase 1: Style Lock (Week 1)

Create 5 "golden standard" sprites that define the exact visual style:

1. **Ground tile** (32x16 iso) -- cracked asphalt with warning markings
2. **Rubber Bullet Turret** (32x32) -- idle state, metallic institutional
3. **Rioter** (16x16) -- basic walk pose, civilian with protest gear
4. **Bullet tracer** (8x8 or smaller) -- kinetic projectile
5. **Explosion effect** (32x32) -- impact flash with smoke

Iterate these 5 until they're perfect. Use them as **style references** for all future generation. Lock and don't change.

### Phase 2: Foundation Assets (Week 2)

| Category | Assets | Count |
|----------|--------|-------|
| Tiles | Ground, path, wall, elevation variants | 8-12 |
| Towers | Rubber Bullet, Tear Gas, Water Cannon (idle + active) | 6 |
| Enemies | Rioter, Masked Protestor, Shield Wall (4-dir walk) | 12 |
| Projectiles | Bullet, lobbed gas, water splash | 3 |

Test in-engine after each batch: import to Godot, verify isometric rendering, depth sorting.

### Phase 3: Full Roster (Week 3-4)

| Category | Assets | Count |
|----------|--------|-------|
| Towers | Remaining 5 towers (idle + active) | 10 |
| Enemies | Remaining 9 standard enemies (4-dir walk) | 36 |
| Bosses | 5 boss enemies (48x48, idle + attack) | 10 |
| Projectiles | All remaining types | 5 |
| Effects | Impact/explosion per damage type | 8 |
| Status FX | Stun, freeze, burn, poison, shield overlays | 5 |

### Phase 4: Polish (Week 5)

| Category | Assets | Count |
|----------|--------|-------|
| Towers | Tier 5 ultimate visual variants | 8 |
| Props | Rubble, vehicles, barriers, floodlights | 10-15 |
| UI | Tower icons, damage type icons, currency, buttons | 20-30 |
| Animations | Refinement pass on all walk/attack cycles | -- |
| Atlases | Sprite sheet assembly per category | -- |

---

## File Naming Convention

```
assets/sprites/towers/tower_{id}_{state}.png        # tower_rubber_bullet_idle.png
assets/sprites/enemies/enemy_{id}_{dir}_{frame}.png  # enemy_rioter_se_01.png
assets/sprites/bosses/boss_{id}_{state}_{frame}.png  # boss_demagogue_attack_03.png
assets/sprites/effects/effect_{type}_{frame}.png      # effect_explosion_kinetic_02.png
assets/sprites/tiles/tile_{type}_{variant}.png        # tile_ground_cracked.png
assets/sprites/ui/icon_{name}.png                     # icon_tower_rubber_bullet.png
assets/sprites/projectiles/proj_{type}.png            # proj_tear_gas.png
assets/sprites/props/prop_{name}.png                  # prop_barricade_01.png
```

### Directions (for character sprites)

```
N, NE, E, SE, S, SW, W, NW
```

Minimum: 4 directions (SE, SW, NE, NW) for isometric. 8 if quality allows.

### States

- **Towers**: `idle`, `active`, `tier5`
- **Enemies**: `walk`, `attack`, `death`, `special`
- **Bosses**: `idle`, `attack`, `phase2`, `death`

---

## Sprite Sizes

All sprites are generated at **2x resolution** for quality, then displayed at native scale in-engine (Godot nearest-neighbor filtering).

| Category | Logical Size | File Size (2x) | Notes |
|----------|-------------|-----------------|-------|
| Standard enemies | 16x16 | 32x32 | Base unit |
| Towers | 32x32 | 64x64 | Mounted on platform |
| Tower evolutions | 32x40-56 | 64x80-112 | Taller for upgrade tiers |
| Boss enemies | 48x48 | 96x96 | 3x base unit |
| Iso tiles | 32x16 | 64x32 | 2:1 ratio |
| Projectiles | 8x8 to 16x16 | 16x16 to 32x32 | Varies by type |
| Effects | 16x16 to 32x32 | 32x32 to 64x64 | Varies by type |
| UI icons | 16x16 or 32x32 | 32x32 or 64x64 | Consistent within category |

> **Note:** PixelLab minimum output is 32x32. Smaller logical sprites (8x8 projectiles) are generated at 32x32 and trimmed/scaled as needed.

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

---

## References

- [PixelLab](https://www.pixellab.ai/) -- primary generation tool
- [PixelLab Review](https://www.jonathanyu.xyz/2025/12/31/pixellab-review-the-best-ai-tool-for-2d-pixel-art-games/)
- [Retro Diffusion](https://runware.ai/blog/retro-diffusion-creating-authentic-pixel-art-with-ai-at-scale)
- [Godot AI Image Generator](https://github.com/SynidSweet/godot-ai-image-generator)
- [Gemini 2.5 Flash Image](https://developers.googleblog.com/en/introducing-gemini-2-5-flash-image/)
- [Scenario Iso Tiles](https://www.scenario.com/blog/build-isometric-game-tiles-ai)
