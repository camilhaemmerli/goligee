# Goligee -- AI Prompt Templates

> Copy-paste-ready prompts for generating game sprites with PixelLab.
> Palette hex values baked in. See `moodboard/COLOR_PALETTE.md` for full reference.
> Prompts are **composable layers** -- see below. Code lives in `tools/generate_assets.py`.

---

## Composable Prompt Layers

Instead of one monolithic base prompt, we decompose into four layers that compose per-category. This avoids redundancy and prevents theme/scene words from bleeding into character sprites.

### Layer 1: STYLE (all generators)

```
16-bit isometric pixel art, isometric 3/4 view,
clean pixel grid, no anti-aliasing, detailed shading
```

### Layer 2: LIGHTING (scene + sprite generators, NOT characters)

```
light source from top-left casting shadows to bottom-right,
left faces brightest, right faces mid-tone, bottom faces darkest
```

### Layer 3: THEME (scene generators ONLY -- tiles, buildings, tilesets)

```
satirical riot control police state setting,
Soviet brutalist architecture, raw concrete angular geometry,
dark night scene lit by harsh overhead floodlights,
oppressive authoritarian dystopia, post-Soviet urban decay
```

### Layer 4: NEGATIVE (all transparent-bg generators)

```
background, scene, environment, building, architecture, street,
urban, night sky, ground, floor, landscape
```

### Composed Per-Category Prompts

| Prompt | Composition | Used by |
|--------|-------------|---------|
| `SCENE_PROMPT` | STYLE + LIGHTING + THEME | Tiles, buildings, tilesets |
| `SPRITE_PROMPT` | STYLE + LIGHTING + "single isolated game sprite on transparent background" | Turrets, projectiles, effects, animated details, props |
| `CHAR_PROMPT` | STYLE + "dark muted colors, warm accents" | Enemies, bosses |
| `UI_PROMPT` | "pixel art game icon, clean sharp edges, no anti-aliasing, dark theme, transparent background" | UI icons |

> **Key design decisions:**
> - **No color words in base prompts.** The palette swatch image (`color_image`) pins colors. Per-asset descriptions can still mention specific accents (e.g., "electric blue glow").
> - **Characters stay SHORT.** Scene/environment words cause background bleed even with `no_background=True`.
> - **NEGATIVE is applied** to all generators producing transparent-bg sprites (turrets, projectiles, effects, bosses).

---

## Tower Turrets (48x48, weapon head only)

Each tower is split into a **base platform** (static) and a **turret head** (8 directions).
Generate the turret SE reference first, then use `/generate-8-rotations-v2` for all 8 directions.

### Turret Template

Uses `SPRITE_PROMPT` + turret description. Negative prompt = `NEGATIVE`.

```
{SPRITE_PROMPT}, {turret_description}
```

### Rubber Bullet Turret

```
{turret_template},
rotating mounted turret with dual barrels, ammo belt feed,
compact military design, muzzle suppressor, kinetic weapon,
silver metallic barrel #9A9AA0, warning stripes #C8A040
```

### Tear Gas Launcher

```
{turret_template},
multi-tube grenade launcher rack, 6 angled launch tubes,
chemical weapon, hazmat yellow markings #C8A040,
chemical green accent #70A040, vented housing
```

### Taser Grid

```
{turret_template},
tesla coil prongs, twin conductor tips,
electrical arc gap between prongs,
electric blue glow #50A0D0, insulated connectors
```

### Water Cannon

```
{turret_template},
industrial fire hose nozzle on swivel mount,
pressurized hydraulic fittings, chrome barrel,
cool blue accent #6090B0, chrome nozzle #9A9AA0
```

### Surveillance Hub

```
{turret_template},
satellite dish with camera cluster, small radar spinner,
CCTV camera pointing forward, antenna,
screen glow #A0D8A0, red recording light #D04040
```

### Pepper Spray Emitter

```
{turret_template},
aerosol spray nozzle head, pressurized canister tip,
spray cone emitter face,
chemical green #70A040, hazmat orange #D06030
```

### LRAD Cannon

```
{turret_template},
parabolic speaker dish, concentric ring emitter face,
military audio device barrel,
amber warning glow #D8A040, dark metal #2A2A30
```

### Microwave Emitter

```
{turret_template},
flat panel directed energy emitter, heat grid face,
cooling fins on sides, sci-fi energy barrel,
purple glow #8060A0, emitter pattern
```

---

## Tower Bases (64x64, static platform)

Generated via `/map-objects` endpoint with `view="low top-down"`. One per tower type.

### Base Template

Uses `SPRITE_PROMPT` + "tower platform base" + base description.

```
{SPRITE_PROMPT}, tower platform base, isometric 3/4 view, {base_description}
```

### Per-Tower Base Descriptions

| Tower | Base Description |
|-------|------------------|
| Rubber Bullet | `compact gun emplacement, ammo crate beside, metallic platform` |
| Tear Gas | `chemical storage rack, hazmat warning labels, ventilated housing` |
| Taser Grid | `insulated electrical platform, high voltage warning signs, rubber base` |
| Water Cannon | `large water tank platform, pipe fittings and pressure gauges, hydraulic base` |
| Surveillance | `electronics housing with antenna mounts, dark server rack base` |
| Pepper Spray | `chemical tank platform, pressurized canister housing, warning stripes` |
| LRAD | `heavy duty speaker mount platform, power generator base` |
| Microwave | `cooling vent platform, power conduit housing, heat-resistant base` |

---

## Standard Enemies (32x32, 8-direction walk cycles)

Each enemy is created as a **persistent PixelLab character** via `/create-character-with-8-directions`,
then animated via `/characters/animations` with `walking-4-frames` template.

### Template

Uses `CHAR_PROMPT` (short, no scene words). Created via `/create-character-with-8-directions`.

```
{CHAR_PROMPT}, {enemy_description}
```

### Rioter

```
{enemy_template},
basic civilian protestor, hoodie and jeans, bandana face mask,
carrying a crude protest sign, lean aggressive stance,
rioter core #D06040, light armor, sneaking posture
```

### Masked Protestor

```
{enemy_template},
gas mask wearing protestor, tactical vest over hoodie,
medium build, determined stance, goggles and respirator,
darker tint #A84030, medium armor plating visible
```

### Shield Wall

```
{enemy_template},
large riot shield carrier, heavy improvised armor,
makeshift plywood and metal shield, slow heavy stance,
bulky silhouette, heavy armor #802818, fortified look
```

### Molotov Thrower

```
{enemy_template},
slim agile protestor, arm raised holding bottle with rag,
fire glow from molotov #E8A040 #D06030, bandana mask,
light fast build, arsonist posture, flame highlight
```

### Drone Operator

```
{enemy_template},
tech-savvy protestor with drone controller, small quadcopter hovering above,
backpack with antenna, goggles, flying unit,
screen glow #A0D8A0, drone propeller blur
```

### Goth Protestor

```
{enemy_template},
goth punk girl, black hair, pale skin,
black tank top, short black skirt, fishnet stockings, combat boots,
spiked choker, dark makeup, carrying small flag, confident stride
```

### Street Medic

```
{enemy_template},
first aid cross armband, medical backpack, face mask,
kneeling/running support posture, white cross #C0C0C8 on arm,
light armor, healing aura shimmer #88C888
```

### Armored Van

```
{enemy_template} at 32x32 size,
improvised armored vehicle, welded metal plates on van,
barricade ram front, small viewport slits,
fortified armor #28282C, heavy dark silhouette, slow massive
```

### Infiltrator

```
{enemy_template},
dark hooded figure, crouched sneaking pose,
near-invisible stealth shimmer effect, shadow-blend clothing,
void dark #0A0A0E body, slight transparency suggestion
```

### Blonde Protestor

```
{enemy_template},
blonde girl, long flowing blonde hair,
crop top, shorts, sneakers, holding megaphone,
sassy confident walk, bright hair contrasting dark outfit
```

### Tunnel Rat

```
{enemy_template},
hunched figure with mining helmet, goggles and dust mask,
digging tools on back, low crouching pose,
medium armor, dirt-stained #484440, headlamp glow #D8A040
```

### Union Boss

```
{enemy_template} but 20x20 size,
large intimidating figure, hard hat and hi-vis vest,
megaphone in hand, commanding presence, heavy build,
heavy armor #A84030, boss aura, authority stance
```

---

## Boss Enemies (48x48)

### Template

Uses `CHAR_PROMPT` (short). Negative prompt = `NEGATIVE`. `transparent_background=True`.

```
{CHAR_PROMPT}, boss character, imposing large figure,
detailed for size, single game sprite, {boss_description}
```

### The Demagogue

```
{boss_template},
charismatic leader on elevated platform with megaphone,
long coat flowing, dramatic pointing gesture,
raised wooden stage/crate beneath feet,
crowd energy aura #D8A040, propaganda banner backdrop,
at 50% HP descends from platform -- show both states
```

### The Hacktivist

```
{boss_template},
hooded hacker figure with multiple floating holographic screens,
green terminal text glow #A0D8A0, typing gesture,
digital glitch effects around body, matrix-style,
bot minion silhouettes nearby, shield regen shimmer #3868A0
```

### The Barricade

```
{boss_template},
massive walking barricade structure, humanoid shape made of
welded metal sheets, car doors, wooden planks, rebar,
debris shedding as damaged, fortified armor throughout,
enormous heavy silhouette, construction debris particles
```

### The Influencer

```
{boss_template},
flashy narcissistic figure with ring light halo,
phone held up for selfie, designer protest outfit,
follower silhouettes trailing behind, split personality hint,
glamour glow #E8A040, social media icons floating around
```

### Ghost Protocol

```
{boss_template},
flickering translucent figure, phasing in and out of reality,
glitch visual effects, teleport afterimage trail,
cycling color shift between silver #9A9AA0 and purple #8060A0,
stealth shimmer, multiple ghost positions overlapping
```

---

## Isometric Tiles (32x16)

### Template

Uses `SCENE_PROMPT`. Generated via `/create-isometric-tile`.

```
{SCENE_PROMPT}, isometric floor tile, seamless tiling edges, {tile_description}
```

### Ground -- Cracked Asphalt

```
{tile_template},
cracked urban asphalt, subtle crack lines,
top face #3A3A3E, right face #2E2E32, left face #28282C,
worn road surface, urban decay
```

### Path -- Warning Yellow

```
{tile_template},
hazard-marked path, diagonal warning stripes,
top face #C8A040, right face #9A7830, left face #706020,
worn caution paint, institutional walkway
```

### Wall -- Concrete

```
{tile_template},
raised concrete wall block, brutalist architecture,
top face #585860, right face #28282C, left face #1E1E22,
industrial cinder block texture
```

### Elevated -- Platform

```
{tile_template},
raised metal platform, industrial grating texture,
top face #585860, right face #484850, left face #28282C,
tower placement pad, reinforced edges
```

### Scorched Ground

```
{tile_template},
fire-damaged asphalt, scorch marks and ash,
top face #363030, right face #2A2828, left face #202020,
burnt debris particles, char marks
```

### Flooded Street

```
{tile_template},
shallow water on asphalt, reflective puddle surface,
top face #3A3A3E with blue tint #6090B0 reflection,
right face #2E2E32, left face #28282C,
ripple effect suggestion
```

### Toxic Spill

```
{tile_template},
chemical spill on ground, green-tinted puddle,
top face #3A3A3E with green tint #70A040 pooling,
right face #2E2E32, left face #28282C,
toxic warning, corrosive look
```

### Rubble

```
{tile_template},
collapsed debris pile, concrete chunks and rebar,
top face #484440, right face #3A3838, left face #2A2828,
destroyed building remnants, dust particles
```

---

## Projectiles (8x8 to 16x16)

### Template

Uses `SPRITE_PROMPT`. Negative prompt = `NEGATIVE`.

```
{SPRITE_PROMPT}, game projectile sprite, small, motion blur suggestion, {projectile_description}
```

### Rubber Bullet

```
{proj_template}, 8x8,
small silver bullet with tracer trail,
kinetic silver #9A9AA0, trail #C0C0C8, motion streak
```

### Tear Gas Canister

```
{proj_template}, 12x12,
lobbed cylindrical canister, arc trajectory,
chemical green #70A040, smoke trail, tumbling rotation
```

### Water Blast

```
{proj_template}, 16x16,
pressurized water stream burst, spray pattern,
cool blue #6090B0 to white #C0D8E8, splash droplets
```

### Electric Arc

```
{proj_template}, 12x12,
jagged lightning bolt, chain link,
electric blue #50A0D0, bright core #C0E8F8, spark endpoints
```

### Sonic Wave

```
{proj_template}, 16x8,
concentric arc wave lines, expanding rings,
amber #D8A040, distortion ripple effect
```

### Heat Beam

```
{proj_template}, 16x4,
straight directed energy beam, shimmer heat haze,
orange core #D06030, red edge #903020, heat distortion
```

### Pepper Spray Cloud

```
{proj_template}, 16x16,
expanding aerosol cone, mist particles,
green #70A040 to yellow-green #B8E080, dispersing
```

### Surveillance Ping

```
{proj_template}, 8x8,
scanning pulse, radar blip,
terminal green #A0D8A0, circular ripple, data ping
```

---

## Effects (16x16 to 32x32)

### Template

Uses `SPRITE_PROMPT`. Negative prompt = `NEGATIVE`.

```
{SPRITE_PROMPT}, game effect sprite, animation frame, {effect_description}
```

### Explosion -- Kinetic Impact

```
{effect_template}, 16x16,
small bullet impact burst, debris spray,
flash #F0E0C0, spark #C0C0C8, smoke #383838
```

### Explosion -- Chemical Burst

```
{effect_template}, 32x32,
gas cloud expansion, chemical reaction,
green cloud #70A040 to #90C060, dissipating edges,
toxic mist particles
```

### Explosion -- Fire

```
{effect_template}, 32x32,
fireball explosion lifecycle,
flash core #F0E0C0 -> fire bloom #E8A040 -> mid fire #D06030 -> fade #903020,
smoke trail #484040 -> #383838 -> transparent
```

### Explosion -- Electric

```
{effect_template}, 24x24,
electrical discharge burst, arc flash,
blue core #50A0D0, arcs #80C8F0, sparks #C0E8F8,
radial lightning bolts
```

### Explosion -- Water Splash

```
{effect_template}, 24x24,
water impact splash, concentric droplet ring,
splash #90B8D0, droplets #C0D8E8, mist #6090B0
```

### Status -- Stun Stars

```
{effect_template}, 16x16,
spinning stars/circles above head, dazed indicator,
electric blue #50A0D0, yellow #D8A040, orbit pattern
```

### Status -- Freeze/Slow

```
{effect_template}, 16x16,
ice crystal overlay, frost particles,
cryo blue #6090B0, ice #90B8D0, frost #C0D8E8
```

### Status -- Burn DOT

```
{effect_template}, 16x16,
small flame wisps on target, burning indicator,
fire orange #D06030, ember #E8A040, smoke wisps #484040
```

### Status -- Poison DOT

```
{effect_template}, 16x16,
toxic bubble particles rising, corrosion drops,
corrosive green #608030, bubble #809840, drip #A0B860
```

### Status -- Shield

```
{effect_template}, 16x16,
hexagonal energy shield overlay, barrier glow,
shield blue #3868A0, edge glow #5080A0, hex pattern
```

---

## UI Icons (32x32)

### Template

Uses `UI_PROMPT` constant. `transparent_background=True`.

```
{UI_PROMPT}, {icon_description}
```

### Tower Icons (for build menu)

```
{ui_template}, simplified tower silhouette,
tower type: {tower_name}, recognizable at small size,
gunmetal frame #484850, icon fill matching tower accent color
```

### Damage Type Icons

```
{ui_template}, damage type symbol,
kinetic: bullet shape #9A9AA0
chemical: droplet/flask #70A040
hydraulic: water wave #6090B0
electric: lightning bolt #50A0D0
sonic: sound wave rings #D8A040
directed energy: beam ray #8060A0
cyber: circuit chip #A0D8A0
psychological: eye/brain #808898
```

### Currency Icon

```
{ui_template}, budget/gold coin,
authoritarian eagle stamp, amber coin #D8A040,
dark outline #28282C, institutional currency feel
```

### Approval Rating Icon

```
{ui_template}, approval/lives counter,
approval meter or shield badge, red when low #D04040,
green when high #88C888, official insignia style
```

---

## Environment Props (variable sizes)

### Template

Uses `SPRITE_PROMPT`. Generated via `/map-objects` with `view="low top-down"`.

```
{SPRITE_PROMPT}, environment prop, urban debris, {prop_description}
```

### Concrete Barricade

```
{prop_template}, 32x24,
jersey barrier / concrete roadblock, riot police barricade,
concrete gray #28282C to #3A3A3E, caution stripe #C8A040
```

### Burnt Vehicle

```
{prop_template}, 48x32,
burnt-out car wreck, smashed windows, fire damage,
charred metal #2A2828, rust #903020, broken glass
```

### Floodlight

```
{prop_template}, 16x32,
tall portable floodlight on tripod stand,
harsh light cone #F0E0C0, industrial metal #484850
```

### Razor Wire

```
{prop_template}, 32x8,
coiled razor wire barrier, military grade,
steel #9A9AA0, sharp gleam highlights #C0C0C8
```

### Rubble Pile

```
{prop_template}, 32x24,
collapsed building debris, concrete chunks and rebar,
mixed grays #484440 #3A3838, dust particles
```

---

## City Buildings (128x128 to 256x192)

Generated via `/map-objects` endpoint with `remove_background()` post-processing.
These are decorative background elements placed behind the play field.

### Template

Uses `SCENE_PROMPT` (buildings ARE scenes, so theme words are appropriate).

```
{SCENE_PROMPT}, building sprite, {building_description}
```

### Panelka Tall

```
{building_template},
tall Soviet apartment block, panelka prefab concrete,
8-10 floors, broken windows, crumbling facade, laundry lines,
balconies with junk, satellite dishes, graffiti,
concrete gray #3A3A3E to #585860
```

### Panelka Wide

```
{building_template},
wide Soviet apartment block, panelka prefab,
5 floors, long horizontal facade, repeating window pattern,
some windows lit with warm amber #C8A040, peeling plaster
```

### Panelka Ruined

```
{building_template},
partially collapsed apartment block, exposed rebar,
rubble at base, fire damage on upper floors,
dark scorch marks #2A2828, broken structure
```

### Government Building

```
{building_template},
imposing government building, Soviet neoclassical style,
columns and heavy stone facade, propaganda banners,
floodlit from below, institutional authority,
guarded entrance, iron fence, official insignia
```

### Guard Booth

```
{building_template} at 64x64,
small guard checkpoint booth, bulletproof glass,
barrier arm, CCTV camera on top,
institutional gray #484850, red warning light #D04040
```

---

## Animated Details (32-64px, 4-frame loops)

Reference frame uses `SPRITE_PROMPT`. Animated via `/animate-with-text-v2` endpoint.

### Burning Barrel

```
pixel art animated sprite, burning oil drum barrel,
fire flickering from top, orange flames #D06030 #E8A040,
dark metal barrel #2A2A30, smoke wisps rising,
4 frame animation loop, transparent background
```

### Waving Flag

```
pixel art animated sprite, tattered protest flag on pole,
cloth waving in wind, faded red fabric #903020,
metal pole #9A9AA0, 4 frame wave cycle,
transparent background
```

### Flickering Neon Sign

```
pixel art animated sprite, broken neon sign,
buzzing on/off cycle, cyrillic text suggestion,
neon glow #D8A040, dark housing #1E1E22,
4 frame flicker loop, transparent background
```

---

## Tips for Best Results

1. **Always generate at 2x or 4x target resolution** then downscale with nearest-neighbor -- produces cleaner pixels
2. **Generate multiple variations** (4-8) per prompt and pick the best, don't try to get it perfect in one shot
3. **Use PixelLab's style reference** after locking your golden standards -- consistency > individual quality
4. **Post-process in Aseprite**: palette swap to exact hex values, fix any anti-aliased edges, clean orphan pixels
5. **Test in-engine early** -- a sprite that looks good in isolation may not read well at game zoom level
6. **Batch by category** -- do all towers, then all enemies, etc. Context switching hurts consistency

### Prompt Architecture Lessons (from production)

7. **No color words in base prompts.** The palette swatch image (`color_image`) pins the palette. Verbal color words in prompts can conflict with/override the swatch. Use colors only in per-asset descriptions where needed (e.g., "electric blue glow" for taser).
8. **Character sprites need SHORT prompts** -- CHAR_PROMPT is just STYLE + "dark muted colors, warm accents". Scene/environment words cause background bleed even with `no_background=True`.
9. **`no_background` API flag is unreliable alone** -- must be paired with prompt discipline. The flag hints, but prompt text dominates.
10. **NEGATIVE prompt is essential** for transparent-bg sprites -- apply to turrets, projectiles, effects, and bosses.
11. **SCENE_PROMPT is for environment assets only** (tiles, buildings, tilesets). Never use for isolated sprites or characters.
