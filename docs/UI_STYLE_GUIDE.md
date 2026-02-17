# UI Style Guide

Centralized reference for all in-game UI styling. Every button in the game
uses `ButtonStyles` (`scripts/ui/button_styles.gd`) — a static utility class.

---

## Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| **Primary** | `#D04040` | Button bg, active accents, selected borders |
| Primary Hover | `#D85050` | Button hover state |
| Primary Pressed | `#B03030` | Button pressed state |
| Highlight | `#E86060` | 3D top bevel edge |
| Shadow | `#801818` | 3D bottom bevel, shadow_color |
| Panel BG | `#1A1A1E` | Dark backgrounds |
| Surface | `#2A2A30` | Secondary surfaces, utility buttons |
| Text Primary | `#FFFFFF` | Buttons, headings |
| Text Muted | `#808898` | Secondary labels, disabled text |
| Disabled Border | `#3A3A40` | Disabled button borders |

---

## 3D Button Technique

All buttons use `StyleBoxFlat` with asymmetric borders + `shadow_offset` to
create a raised "3D" effect that inverts on press.

### Normal (raised)
- `bg_color = #D04040`
- `border_color = #E86060` (highlight on top)
- `border_width_top = 2`, others `= 1`
- `shadow_color = #801818`, `shadow_size = 2`, `shadow_offset = Vector2(0, 1)`

### Hover (brighter)
- `bg_color = #D85050`
- `shadow_size = 3`

### Pressed (pushed in)
- `bg_color = #B03030`
- `border_color = #801818` (dark on top now)
- `border_width_bottom = 2`, `border_width_top = 1`
- `shadow_size = 0`
- `content_margin_top += 1` (text shifts down 1px)

### Disabled
- `bg_color = #2A2A30`, border `#3A3A40`, font `#808898`

### Focus
- `StyleBoxEmpty` (no ring — brutalist)

---

## Button Variants

### `apply_primary(btn)`
Red bg, 3D bevel, white text. The default action button.
Used by: start screen, presidential briefing, restart.

### `apply_accent(btn)`
Dark bg (`#1A1A1E`), red border + 3D bevel. Text turns red on hover.
Used by: send wave, cancel build, upgrade path buttons.

### `apply_subtle(btn)`
Transparent bg, muted text, red text on hover. No border.
Used by: sell button.

### `apply_icon_card(btn, corner_radius)`
Dark bg, grey border, red border on hover/press. No text color changes.
Used by: tower cards in build menu.

### `apply_utility(btn)`
Small dark surface bg (`#2A2A30`), grey border, muted text.
Used by: speed toggle.

---

## Per-Component Reference

| Component | File | Variant | Notes |
|-----------|------|---------|-------|
| Start button | `start_screen.gd` | `apply_primary` | +40px horiz margins, +8px shadow, glow pulse |
| Presidential briefing | `presidential_briefing.gd` | `apply_primary` | Standard |
| Upgrade buttons | `upgrade_panel.gd` | `apply_accent` | 180px min width |
| Sell button | `upgrade_panel.gd` | `apply_subtle` | 7px font, centered |
| Send wave | `hud.gd` | `apply_accent` | 9px font, bottom-center |
| Cancel build | `hud.gd` | `apply_accent` | "X" label, 28x28 |
| Speed toggle | `hud.gd` | `apply_utility` | 8px font, 32x16 |
| Restart | `hud.gd` | `apply_primary` | Game over overlay |
| Tower cards | `tower_menu.gd` | `apply_icon_card` | 64x64, disabled alpha 0.55 |

---

## Typography

- **Pirata One** (blackletter) — banners, headers, button text on major actions
- Default Godot font — small labels, stats, secondary info

## Naming Conventions

Theme vocabulary (see GAME_DESIGN.md):
- Gold → "Budget" / "Taxpayer Budget"
- Lives → "Approval" (approval rating %)
- Waves → "Incidents"
- Enemies → "Agitators"
