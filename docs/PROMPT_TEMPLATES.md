# Goligee -- AI Prompt Templates

> Copy-paste-ready prompts for generating game sprites with PixelLab, Retro Diffusion, or Gemini.
> Palette hex values baked in. See `moodboard/COLOR_PALETTE.md` for full reference.

---

## Base Prompt (prepend to everything)

```
8-bit isometric pixel art, urban dystopia riot control setting,
night scene with harsh institutional lighting, cold concrete
and gunmetal gray palette with warning amber and emergency red
accents, desaturated muted colors, no anti-aliasing, clean pixel
grid, oppressive authoritarian atmosphere, post-apocalyptic urban
```

---

## Towers (32x32)

### Template

```
{base_prompt}, riot control equipment, mounted on concrete platform,
isometric 3/4 view, metallic industrial design, single game sprite,
transparent background, tower light #606068, tower mid #484850,
tower dark #2A2A30, active glow #5080A0,
{specific_description}
```

### Rubber Bullet Turret

```
{tower_template},
rotating mounted turret with dual barrels, ammo belt feed,
compact military design, muzzle suppressor, kinetic weapon,
silver metallic barrel #9A9AA0, warning stripes #C8A040
```

**Active state**: Add `muzzle flash #F0E0C0, shell casings ejecting, barrel recoil`

### Tear Gas Launcher

```
{tower_template},
multi-tube grenade launcher rack, 6 angled launch tubes,
chemical weapon, hazmat yellow markings #C8A040,
chemical green accent #70A040, vented housing, gas mask motif
```

**Active state**: Add `gas cloud #70A040 at 50% opacity, launched canister trail`

### Taser Grid

```
{tower_template},
tesla coil tower design, twin conductor prongs on top,
electrical arcs between prongs, insulated base housing,
electric blue glow #50A0D0, warning high voltage signage
```

**Active state**: Add `electric arc #50A0D0, chain lightning #80C8F0, sparks #C0E8F8`

### Water Cannon

```
{tower_template},
industrial fire hose nozzle on swivel mount, large water tank base,
pressurized hydraulic system, pipe fittings and gauges,
cool blue accent #6090B0, chrome nozzle #9A9AA0
```

**Active state**: Add `water stream spray #90B8D0, splash particles #C0D8E8`

### Surveillance Hub

```
{tower_template},
satellite dish with camera cluster, radar spinner on top,
multiple CCTV cameras pointing outward, antenna array,
screen glow #A0D8A0, red recording light #D04040, dark housing
```

**Active state**: Add `scanning beam sweep #A0D8A0, data particles, rotating dish`

### Pepper Spray Emitter

```
{tower_template},
industrial aerosol nozzle array, chemical tank with warning labels,
pressurized canister design, spray cone emitter head,
chemical green #70A040, hazmat orange #D06030, warning stripes
```

**Active state**: Add `continuous spray cone #90C060, mist particles #B8E080`

### LRAD Cannon

```
{tower_template},
large parabolic speaker dish, concentric ring emitter face,
sound wave visual emanating forward, military audio device,
amber warning glow #D8A040, dark metal housing #2A2A30
```

**Active state**: Add `visible sonic waves #D8A040, distortion ripples, vibration lines`

### Microwave Emitter

```
{tower_template},
flat panel directed energy weapon, heat emitter grid face,
sci-fi energy weapon design, cooling fins on sides,
purple directed energy glow #8060A0, heat shimmer,
emitter face pattern, industrial mounting bracket
```

**Active state**: Add `heat beam #D06030, shimmer distortion, target glow #E8A040`

---

## Standard Enemies (16x16)

### Template

```
{base_prompt}, protestor character, isometric 3/4 view,
single game sprite, transparent background,
{specific_description}
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

### Flash Mob

```
{enemy_template},
cluster of 3-4 tiny figures merged together, crowd blob,
mixed civilian clothing, protest signs sticking up,
unarmored mass, chaotic grouping, split-able appearance
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
{enemy_template} but 24x16 size,
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

### Social Media Swarm

```
{enemy_template} but 8x8 size,
tiny phone-wielding figure, single small protestor,
very simple 4-color sprite, minimal detail,
bright screen glow #A0D8A0, swarm unit
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

```
{base_prompt}, boss character, imposing large figure,
isometric 3/4 view, 48x48 pixel sprite, detailed for size,
transparent background, boss tint #802818,
{specific_description}
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

```
{base_prompt}, isometric floor tile, 2:1 diamond ratio,
32x16 pixels, three-face shading (top lightest, right mid, left darkest),
seamless tiling edges, transparent background,
{specific_description}
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

```
{base_prompt}, game projectile sprite, small,
transparent background, motion blur suggestion,
{specific_description}
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

```
{base_prompt}, game effect sprite, transparent background,
animation frame, {specific_description}
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

## UI Icons (16x16)

### Template

```
pixel art game icon, 16x16, clean sharp edges, no anti-aliasing,
transparent background, dark theme, {specific_description}
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

```
{base_prompt}, environment prop, isometric 3/4 view,
transparent background, urban debris/fixture,
{specific_description}
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

## Tips for Best Results

1. **Always generate at 2x or 4x target resolution** then downscale with nearest-neighbor -- produces cleaner pixels
2. **Generate multiple variations** (4-8) per prompt and pick the best, don't try to get it perfect in one shot
3. **Use PixelLab's style reference** after locking your golden standards -- consistency > individual quality
4. **Post-process in Aseprite**: palette swap to exact hex values, fix any anti-aliased edges, clean orphan pixels
5. **Test in-engine early** -- a sprite that looks good in isolation may not read well at game zoom level
6. **Batch by category** -- do all towers, then all enemies, etc. Context switching hurts consistency
