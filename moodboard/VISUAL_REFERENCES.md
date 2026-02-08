# Goligee -- Visual References & Inspiration

## Primary Inspiration

### Superbrothers: Sword & Sworcery EP
- **File**: `reference-superbrothers-sworcery.jpg`
- **Why**: Masterclass in atmospheric pixel art. Limited palette, silhouette-heavy,
  emotional depth through value contrast. The twilight palette defines our color language.
- **Take from it**: Color palette, fog/atmosphere treatment, silhouette style,
  sense of scale and loneliness

---

## Game Style References

### Pixel Art & Atmosphere
| Game | What to Reference |
|------|-------------------|
| **Hyper Light Drifter** | Color palette usage, particle effects, screen shake, atmospheric fog |
| **Dead Cells** | Fluid pixel animation, particle-heavy combat, explosion effects |
| **Celeste** | Clean pixel art with atmospheric backgrounds, parallax fog layers |
| **Eastward** | Isometric-ish pixel environments, warm/cool lighting contrast |
| **Octopath Traveler** | "HD-2D" aesthetic -- pixel art with modern lighting and particles |

### Tower Defense Visual References
| Game | What to Reference |
|------|-------------------|
| **Kingdom Rush** | Isometric layout, tower upgrade visual progression, enemy variety |
| **Bloons TD 6** | Upgrade path visual spectacle, particle-heavy tier 5 towers |
| **Dungeon Warfare 2** | Dark atmosphere in a TD, trap/tower visual feedback |
| **Orcs Must Die 3** | Satisfying explosion effects, enemy death animations |
| **Element TD 2** | Elemental damage type visual coding, clean UI |

### Isometric Pixel Art
| Game | What to Reference |
|------|-------------------|
| **Hades** | Isometric perspective, atmospheric lighting, particle systems |
| **Into the Breach** | Clean isometric grid, readable unit designs, strategic clarity |
| **Transistor** | Atmospheric isometric world, color palette mood |
| **The Last Night** | Pixel art + modern lighting/particles hybrid aesthetic |

---

## Visual Pillars

### 1. Atmospheric Depth
- Multi-layer parallax fog
- Depth-based color desaturation (far objects fade toward sky color)
- Volumetric-looking fog particles near ground level
- Subtle ambient particle effects (dust motes, fireflies, embers)

### 2. Silhouette Readability
- Every tower and enemy type should be instantly recognizable by silhouette alone
- Dark foreground elements against lighter backgrounds
- Clear shape language: towers = angular/structured, enemies = organic/chaotic

### 3. Spectacular Effects
- Explosions should be the most colorful thing on screen (using accent palette)
- Screen shake on heavy impacts
- Lingering particle trails on projectiles
- Death animations with satisfying particle bursts
- Tier 5 tower attacks should be visual events

### 4. 8-Bit Constraint Discipline
- Tile sizes: 32x16 isometric tiles (2:1 ratio)
- Sprite sizes: 16x16 base, 32x32 for large units, 48x48 for bosses
- Animation frames: 4-8 frames per animation (true 8-bit feel)
- No sub-pixel rendering or anti-aliasing on sprites
- Nearest-neighbor scaling only
- Post-processing effects (fog, bloom) can be smooth/modern -- they are "the atmosphere"

### 5. Color Discipline
- Sprites use the defined palette strictly
- Effects and particles can blend/interpolate between palette colors
- Each damage type has its own sub-palette (see COLOR_PALETTE.md)
- Night/twilight is the default atmosphere -- the world is perpetually at dusk

---

## Mood Keywords
`twilight` `atmospheric` `melancholic` `ethereal` `ancient` `ruined`
`mystical` `silhouetted` `foggy` `violet` `dusk` `crystalline`

## Anti-Mood (what we are NOT)
`bright` `cheerful` `cartoonish` `neon` `saturated` `daytime` `cute` `clean`
