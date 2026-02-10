# Prompt Structure -- Slot-Based "Prompt Grid"

Structured prompt templates for consistent asset generation via PixelLab API.
Each category defines **slots** that control style, material, sizing, and composition.

## Towers

Towers use a **2-piece composition**: base (body + built-in ground) and turret (rotates independently).

### Canvas

Both base and turret share the same canvas: **64x64 at 2x = 128x128 API pixels**.

- **Base**: ground diamond (64x32) at bottom, body extends upward, top ~30% empty (turret mount zone)
- **Turret**: weapon block centered at (64, 64), barrel extends outward. Enough margin for longest barrel to not clip during rotation.

In Godot: turret Sprite2D positioned so its center aligns with top of base body.

### Slot Definitions

#### Shared Slots (same for base & turret of one tower type)

| Slot | Type | Description |
|------|------|-------------|
| `material` | str | Surface texture language shared across base and turret |
| `accent_hex` | str | Hex color code for accent highlights |
| `accent_name` | str | Human-readable accent color name |

#### Base Slots

| Slot | Type | Values | Description |
|------|------|--------|-------------|
| `body_desc` | str | -- | Architectural body description |
| `body_height` | enum | `"short"` / `"medium"` / `"tall"` | Maps to 40% / 55% / 70% of canvas |
| `ground_desc` | str | -- | Ground platform variant (default: "standard reinforced slab") |

#### Turret Slots

| Slot | Type | Values | Description |
|------|------|--------|-------------|
| `weapon_desc` | str | -- | Weapon hardware description |
| `weapon_shape` | str | -- | Overall silhouette / form factor |
| `weapon_size` | enum | `"small"` / `"medium"` / `"large"` | Maps to small / medium-sized / large prominent |

### Assembly Rules

Prompts are assembled deterministically from slots via `build_base_prompt()` and `build_turret_prompt()` in `tools/generate_assets.py`.

**Base prompt order**:
```
{STYLE}, {LIGHTING},
{TOWER_BASE_STRUCTURE},
{material},
{TOWER_GRIT},
{accent_name} {accent_hex} accent highlights,
{body_desc},
body occupies {body_height → %} of canvas,
{TOWER_GROUND}, {ground_desc},
empty flat roof for turret mount, no weapon on top
```

**Turret prompt order**:
```
{STYLE}, {LIGHTING},
{TOWER_TURRET_STRUCTURE},
{material},
{TOWER_GRIT},
{accent_name} {accent_hex} accent highlights,
{weapon_size → text} {weapon_desc},
{weapon_shape}
```

**Negative prompts** enforce piece separation:
- Base: no weapons, turrets, guns, barrels, etc.
- Turret: no base, platform, ground, body, etc.

### Adding a New Tower

1. Add an entry to `TOWERS` dict in `tools/generate_assets.py`
2. Fill all 9 slots (3 shared + 3 base + 3 turret)
3. Run `python tools/generate_assets.py --single <tower_name>`
4. Review base.png and turret rotations for style consistency

### Shared Constants

These structural fragments are the same for every tower and never change:

| Constant | Purpose |
|----------|---------|
| `STYLE` | Universal pixel art style (16-bit iso, clean grid, etc.) |
| `LIGHTING` | 3-face isometric lighting from top-left |
| `TOWER_BASE_STRUCTURE` | Base is a single architectural block on transparent bg |
| `TOWER_TURRET_STRUCTURE` | Turret is isolated weapon head centered on artboard |
| `TOWER_GROUND` | 1-tile iso diamond at base, flush with bottom edge, debris/litter |
| `TOWER_GRIT` | Universal weathering layer: dirt, rust, chipped paint, scratches |
| `BASE_NEGATIVE` | Excludes weapons/turrets from base generation |
| `TURRET_NEGATIVE` | Excludes architecture/ground from turret generation |

---

## Other Categories (future)

The same slot pattern will extend to enemies, buildings, props, etc. as needed.
Each category will define its own slots and assembly functions.
