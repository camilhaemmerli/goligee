# Goligee -- Color Palette Reference

> Theme: Urban Dystopia / Riot Control
> Mood: Oppressive concrete sprawl, ironic authoritarianism, smog-choked post-apocalyptic city

---

## Palette Rules

1. **80/20 Rule**: 80% cold concrete/gunmetal grays, 20% warning amber/emergency red accents
2. **Black anchoring** -- use true black sparingly; most "darks" should be deep charcoal
3. **Warm = Danger** -- reserve warm tones for fires, flares, warning signs, and threats
4. **Low saturation everywhere** -- the oppressive urban feel comes from desaturated, muted hues
5. **Value over hue** -- communicate depth through lightness/darkness, not color shifts

### Clear Color

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#0E0E12` | Blackout        | Viewport clear color         |

---

## Sky / Background

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#D89050` | Smog Glow       | Brightest horizon center     |
| `#B07040` | Pollution Haze  | Mid horizon glow             |
| `#805838` | Brown Smog      | Upper-mid sky transition     |
| `#504040` | Ash Cloud       | Upper sky                    |
| `#383038` | Smoke Ceiling   | Near-dark sky zone           |
| `#282428` | Charcoal Sky    | Top-of-sky                   |
| `#706060` | Haze Highlight  | Distant smog cloud edges     |

### Sky Gradient (top to bottom)
```
#0E0E12 -> #1A1A1E -> #282428 -> #383038 -> #504040 -> #805838 -> #B07040 -> #D89050
```

---

## Terrain / Urban

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#585860` | Pale Concrete   | Brightest surface, rooftops  |
| `#4A4A50` | Worn Pavement   | Lighter road surfaces        |
| `#3A3A3E` | Cracked Asphalt | Standard ground tile (lit)   |
| `#2E2E32` | Dark Asphalt    | Ground tile shade/shadow     |
| `#28282C` | Rubble/Concrete | Wall tile, barricade base    |
| `#1E1E22` | Dark Concrete   | Wall shade, deep shadow      |

### Map Tile Reference

| Tile         | Lit Face  | Shade     |
|--------------|-----------|-----------|
| Ground       | `#3A3A3E` | `#2E2E32` |
| Path         | `#C8A040` | `#9A7830` |
| Wall         | `#28282C` | `#1E1E22` |

### Path / Warning Markings

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#C8A040` | Warning Yellow  | Path tile, hazard markings   |
| `#9A7830` | Dark Amber      | Path shade, worn markings    |
| `#706020` | Faded Caution   | Old road paint, dim markers  |

### Isometric Tile Face Mapping
```
        TOP FACE:    #585860  (lightest)
       /        \
LEFT FACE:        RIGHT FACE:
#28282C            #3A3A3E
(darkest)          (mid-tone)
```

---

## Urban Debris / Environment

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#3A3838` | Rebar Gray      | Exposed rebar, metal scrap   |
| `#2A2828` | Rubble Dark     | Collapsed structure debris   |
| `#484440` | Dust Concrete   | Pulverized concrete dust     |
| `#363030` | Burnt Ground    | Scorched pavement, burn mark |
| `#202020` | Deep Ruin       | Interior of collapsed bldgs  |

---

## Silhouettes / Darks

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#0A0A0E` | Void            | Absolute darkest areas       |
| `#0E0E12` | Near Black      | Character silhouettes        |
| `#161618` | Carbon          | Structural silhouettes       |
| `#1A1A1E` | Black Steel     | Scene framing, vignettes     |

---

## UI Colors

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#A0D8A0` | Terminal Green  | Primary text on dark BG      |
| `#D8A040` | Warning Amber   | Selected items, highlights   |
| `#808898` | Slate           | Secondary/dim text           |
| `#505860` | Gunmetal        | Inactive buttons, locked     |
| `#282830` | UI Panel Mid    | Card BG, tooltips            |
| `#1A1A1E` | Black Steel     | Panel backgrounds, overlays  |
| `#121216` | UI Panel Border | Borders, separators          |
| `#D04040` | Emergency Red   | Low health, cost warnings    |
| `#D8A040` | Progress Fill   | XP bars, wave progress       |
| `#88C888` | Confirm Green   | Affordable, ready states     |

---

## Damage Type Colors

| Type       | Primary   | Secondary | Particle  |
|------------|-----------|-----------|-----------|
| Kinetic    | `#9A9AA0` | `#707078` | `#C0C0C8` |
| Fire       | `#D06030` | `#E8A040` | `#F0D080` |
| Chemical   | `#70A040` | `#90C060` | `#B8E080` |
| Electric   | `#50A0D0` | `#80C8F0` | `#C0E8F8` |
| Concussive | `#D8A040` | `#F0C860` | `#F0E8B0` |
| Cryo       | `#6090B0` | `#90B8D0` | `#C0D8E8` |
| Corrosive  | `#608030` | `#809840` | `#A0B860` |
| EMP        | `#3878A0` | `#205880` | `#60A0C8` |

---

## Enemy Tints (slightly more saturated for visibility)

Enemies are protestors/rioters -- tinted to stand out against the gray urban backdrop.

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#D06040` | Rioter Core     | Standard enemy tint          |
| `#E89060` | Rioter Damaged  | Hit flash / damage state     |
| `#A84030` | Rioter Elite    | Stronger enemy variant       |
| `#802818` | Rioter Boss     | Boss / mini-boss tint        |
| `#C8A040` | Molotov Glow    | Fire-based enemy highlight   |
| `#60A060` | Gas Mask Green  | Chemical-resistant variant   |

---

## Tower / Defense Colors

Towers are riot control / state defense structures -- cold, institutional, metallic.

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#606068` | Tower Light     | Top/lit face                 |
| `#484850` | Tower Mid       | Side face                    |
| `#2A2A30` | Tower Dark      | Shadow face                  |
| `#5080A0` | Tower Active    | Powered/active glow (cool)   |
| `#D04040` | Tower Warning   | Overheating / danger state   |
| `#3868A0` | Shield Blue     | Barrier / shield accent      |
| `#C8A040` | Searchlight     | Spotlight / detection glow   |

---

## Explosion / Particle Effects

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#F0E0C0` | Flash Core      | Initial explosion flash      |
| `#E8A040` | Fire Bloom      | Expanding explosion halo     |
| `#D06030` | Fire Mid        | Mid-explosion, embers        |
| `#903020` | Fire Fade       | Cooling explosion            |
| `#484040` | Smoke Warm      | Hot smoke near blast         |
| `#383838` | Smoke Cool      | Dissipating smoke            |
| `#282828` | Smoke Fade      | Final wisps before vanishing |
| `#C8A040` | Spark           | Small spark/glint particles  |
| `#50A0D0` | Electric Arc    | Taser / EMP ability FX       |
| `#70A040` | Gas Cloud       | Tear gas / chemical FX       |

### Explosion Lifecycle Gradient
```
#F0E0C0 -> #E8A040 -> #D06030 -> #903020 -> #484040 -> #383838 -> #282828 -> transparent
```

### Tear Gas Lifecycle Gradient
```
#A0B060 -> #90A848 -> #70A040 -> #607840 @50% opacity -> #505840 @25% -> transparent
```

---

## Fog / Atmosphere

| Hex       | Name            | Usage                        |
|-----------|-----------------|------------------------------|
| `#383838` | Urban Smog      | Near-distance fog tint       |
| `#484440` | Dust Haze       | Mid-distance atmospheric     |
| `#504840` | Distant Smog    | Far-distance silhouette wash |
| `#282420` | Night Fog       | Nighttime atmospheric fog    |

### Depth Fog Gradient (near to far)
```
Full color -> #383838 @40% -> #484440 @60% -> #504840 @80% -> #0E0E12 @100%
```

### Smoke / Haze Overlay
```
#282828 @15% opacity -- persistent smog layer across entire scene
```

---

## Quick Reference -- 80/20 Split

### 80% Cold Base (concrete / gunmetal / charcoal)
```
#0E0E12  #161618  #1A1A1E  #1E1E22  #28282C  #2E2E32
#3A3A3E  #484850  #585860  #606068  #808898
```

### 20% Warm Accent (amber / red / fire)
```
#C8A040  #D8A040  #E8A040  #D06030  #D04040  #903020
```
