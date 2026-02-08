# Goligee -- Color Palette Reference

> Inspired by Superbrothers: Sword & Sworcery EP
> Mood: Melancholic twilight, contemplative grandeur, atmospheric 8-bit

---

## Palette Rules

1. **80/20 Rule**: 80% cool blue-violets, 20% warm pink/salmon accents
2. **Low saturation everywhere** -- the misty, humid feel comes from desaturated hues
3. **Value over hue** -- communicate depth through lightness/darkness, not color shifts
4. **Warm = Important** -- reserve warm tones for player actions, threats, and critical UI
5. **Black anchoring** -- use true black sparingly; most "darks" should be deep violet

---

## Sky / Background

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#E0B0B8` | Salmon Glow     | Brightest horizon center     |
| `#D4A0B0` | Dusty Rose      | Mid horizon glow             |
| `#C48A9A` | Muted Rose      | Upper-mid sky transition     |
| `#9A6B80` | Mauve Dusk      | Upper sky                    |
| `#6B4A60` | Twilight Plum   | Near-dark sky zone           |
| `#4A3050` | Deep Twilight   | Top-of-sky                   |
| `#B8A0B0` | Pale Lavender   | Wispy cloud highlights       |

### Sky Gradient (top to bottom)
```
#120E20 -> #241C35 -> #4A3050 -> #6B4A60 -> #9A6B80 -> #C48A9A -> #D4A0B0 -> #E0B0B8
```

---

## Terrain / Stone

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#7A6080` | Pale Stone      | Brightest rock, bridge top   |
| `#6E5878` | Weathered Rock  | Lighter cliff ledges         |
| `#60486A` | Dusky Stone     | Lit rock surfaces            |
| `#503B5A` | Medium Rock     | General rock body            |
| `#4D3858` | Shadow Stone    | Mid-shadow cliff faces       |
| `#3A2845` | Dark Cliff      | Darkest rock, deep shadow    |

### Isometric Tile Face Mapping
```
        TOP FACE:    #7A6080  (lightest)
       /        \
LEFT FACE:        RIGHT FACE:
#4D3858            #60486A
(darkest)          (mid-tone)
```

---

## Foliage / Vegetation

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#402F50` | Light Foliage   | Edges catching ambient light |
| `#352848` | Mid Foliage     | Slightly lit leaf clusters   |
| `#2A1E3A` | Dark Foliage    | Main tree body, dense bushes |
| `#221838` | Forest Shadow   | Ground-level undergrowth     |
| `#1E1530` | Deepest Canopy  | Darkest bush/tree interiors  |

---

## Silhouettes / Darks

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#0E0A18` | Void            | Absolute darkest areas       |
| `#120E20` | Near Black      | Character silhouettes        |
| `#1A1428` | Ink Violet      | Structural silhouettes       |
| `#241C35` | Dark Frame      | Scene framing, vignettes     |

---

## Accent / Highlights

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#F0D0D8` | Pale Blush      | Extreme bright highlights    |
| `#E0B0B8` | Salmon Glow     | Horizon glow, backlit edges  |
| `#D09098` | Rose Highlight  | Warm rim light               |
| `#C87878` | Warm Coral      | Flags, ribbons, small accents|
| `#8A5060` | Muted Berry     | Warm mid-tone accents        |

---

## UI Colors

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#F0D0D8` | UI Text Light   | Primary text on dark BG      |
| `#E0B0B8` | UI Highlight    | Selected items, active btns  |
| `#9A6B80` | UI Text Dim     | Secondary/disabled text      |
| `#60486A` | UI Inactive     | Inactive buttons, locked     |
| `#2A1E3A` | UI Panel Mid    | Card BG, tooltips            |
| `#1A1428` | UI Panel Dark   | Panel backgrounds, overlays  |
| `#120E20` | UI Panel Border | Borders, separators          |
| `#C87878` | UI Warning      | Low health, cost warnings    |

---

## Explosion / Particle Effects

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#F0D0D8` | Flash Core      | Initial explosion flash      |
| `#E0B0B8` | Warm Bloom      | Expanding explosion halo     |
| `#C87878` | Fire Mid        | Mid-explosion, embers        |
| `#8A5060` | Smoke Warm      | Cooling explosion            |
| `#6B4A60` | Smoke Cool      | Dissipating smoke            |
| `#4A3050` | Smoke Fade      | Final wisps before vanishing |
| `#D4A0B0` | Sparkle         | Small spark/glint particles  |
| `#B070A0` | Magic Burst     | Magical/special ability FX   |
| `#905070` | Energy Trail    | Projectile trails            |

### Explosion Lifecycle Gradient
```
#F0D0D8 -> #E0B0B8 -> #C87878 -> #8A5060 -> #6B4A60 -> #4A3050 -> transparent
```

### Depth Fog Gradient (near to far)
```
Full color -> #4A3050 @50% -> #6B4A60 @70% -> #9A6B80 @100%
```

---

## Enemy Tints (slightly more saturated for visibility)

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#D06070` | Enemy Core      | Standard enemy tint          |
| `#E08888` | Enemy Damaged   | Hit flash / damage state     |
| `#A04050` | Enemy Elite     | Stronger enemy variant       |
| `#802030` | Enemy Boss      | Boss / mini-boss tint        |

---

## Tower / Defense Colors

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#7A6080` | Tower Light     | Top/lit face                 |
| `#60486A` | Tower Mid       | Side face                    |
| `#3A2845` | Tower Dark      | Shadow face                  |
| `#90A0B8` | Tower Active    | Powered/active glow (cool)   |
| `#A0D0C0` | Tower Heal      | Healing/support accent       |

---

## Damage Type Colors

| Type       | Primary   | Secondary | Particle  |
|------------|-----------|-----------|-----------|
| Physical   | `#9A9AA0` | `#707078` | `#C0C0C8` |
| Fire       | `#C87878` | `#E0B0B8` | `#F0D0D8` |
| Ice        | `#90A0B8` | `#A0D0C0` | `#D0E0F0` |
| Lightning  | `#D0C890` | `#F0E0B0` | `#F0F0D0` |
| Poison     | `#70A070` | `#508050` | `#90C090` |
| Magic      | `#B070A0` | `#905070` | `#D0A0C0` |
| Holy       | `#D0C8A0` | `#F0E8D0` | `#F0F0E0` |
| Dark       | `#4A3050` | `#241C35` | `#6B4A60` |
