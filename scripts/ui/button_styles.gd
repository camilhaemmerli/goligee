class_name ButtonStyles
## Static utility for consistent button styling across all UI.
## Uses a 3D raised-bevel technique with asymmetric borders + shadow.

# -- Color palette --
const PRIMARY       := Color("#D04040")
const PRIMARY_HOVER := Color("#D85050")
const PRIMARY_PRESS := Color("#B03030")
const HIGHLIGHT     := Color("#E86060")  # top bevel / bright edge
const SHADOW        := Color("#801818")  # bottom bevel / shadow
const PANEL_BG      := Color("#1A1A1E")
const SURFACE       := Color("#2A2A30")
const TEXT_PRIMARY   := Color("#FFFFFF")
const TEXT_MUTED     := Color("#808898")
const DISABLED_BG   := Color("#2A2A30")
const DISABLED_BORDER := Color("#3A3A40")


## Red bg, 3D bevel, white text — the default action button.
static func apply_primary(btn: Button) -> void:
	# Normal (raised)
	var normal := StyleBoxFlat.new()
	normal.bg_color = PRIMARY
	normal.border_color = HIGHLIGHT
	normal.border_width_top = 2
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.shadow_color = SHADOW
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 1)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)

	# Hover (brighter)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PRIMARY_HOVER
	hover.shadow_size = 3
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed (pushed in — inverted bevel)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = PRIMARY_PRESS
	pressed.border_color = SHADOW
	pressed.border_width_top = 1
	pressed.border_width_left = 1
	pressed.border_width_right = 1
	pressed.border_width_bottom = 2
	pressed.shadow_size = 0
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	pressed.content_margin_top = 5  # +1 text shift down
	pressed.content_margin_bottom = 3
	btn.add_theme_stylebox_override("pressed", pressed)

	# Disabled
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = DISABLED_BG
	disabled.border_color = DISABLED_BORDER
	disabled.set_border_width_all(1)
	disabled.shadow_size = 0
	disabled.content_margin_left = 12
	disabled.content_margin_right = 12
	disabled.content_margin_top = 4
	disabled.content_margin_bottom = 4
	btn.add_theme_stylebox_override("disabled", disabled)

	# Focus — empty (brutalist, no ring)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Font colors
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)


## Dark bg, red border + 3D bevel — for send wave, cancel, upgrade actions.
static func apply_accent(btn: Button) -> void:
	# Normal
	var normal := StyleBoxFlat.new()
	normal.bg_color = PANEL_BG
	normal.border_color = PRIMARY
	normal.border_width_top = 2
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.shadow_color = SHADOW
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 1)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)

	# Hover
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#252528")
	hover.border_color = PRIMARY_HOVER
	hover.shadow_size = 3
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed (inverted bevel)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = PRIMARY_PRESS
	pressed.border_color = SHADOW
	pressed.border_width_top = 1
	pressed.border_width_left = 1
	pressed.border_width_right = 1
	pressed.border_width_bottom = 2
	pressed.shadow_size = 0
	pressed.content_margin_left = 10
	pressed.content_margin_right = 10
	pressed.content_margin_top = 5
	pressed.content_margin_bottom = 3
	btn.add_theme_stylebox_override("pressed", pressed)

	# Disabled
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = PANEL_BG
	disabled.border_color = DISABLED_BORDER
	disabled.set_border_width_all(1)
	disabled.shadow_size = 0
	disabled.content_margin_left = 10
	disabled.content_margin_right = 10
	disabled.content_margin_top = 4
	disabled.content_margin_bottom = 4
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", PRIMARY_HOVER)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)


## Transparent bg, muted text, red hover text — for sell button.
static func apply_subtle(btn: Button) -> void:
	# Normal — transparent
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.set_border_width_all(0)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 1
	normal.content_margin_bottom = 1
	btn.add_theme_stylebox_override("normal", normal)

	# Hover — faint white overlay
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.06)
	hover.set_border_width_all(0)
	hover.set_corner_radius_all(3)
	hover.content_margin_left = 6
	hover.content_margin_right = 6
	hover.content_margin_top = 1
	hover.content_margin_bottom = 1
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(1, 1, 1, 0.1)
	pressed.set_border_width_all(0)
	pressed.set_corner_radius_all(3)
	pressed.content_margin_left = 6
	pressed.content_margin_right = 6
	pressed.content_margin_top = 2
	pressed.content_margin_bottom = 0
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	btn.add_theme_color_override("font_color", TEXT_MUTED)
	btn.add_theme_color_override("font_hover_color", PRIMARY)
	btn.add_theme_color_override("font_pressed_color", PRIMARY_PRESS)


## Dark bg, red selected/pressed border — for tower cards.
static func apply_icon_card(btn: Button, corner_radius: int = 4) -> void:
	# Normal
	var normal := StyleBoxFlat.new()
	normal.bg_color = PANEL_BG
	normal.border_color = Color("#28282C")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(corner_radius)
	normal.content_margin_left = 2
	normal.content_margin_right = 2
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)

	# Hover — red border
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = PRIMARY
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed — brighter red border
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_color = PRIMARY_HOVER
	btn.add_theme_stylebox_override("pressed", pressed)

	# Disabled
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = PANEL_BG
	disabled.border_color = Color("#28282C")
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Small dark bg, muted text — for speed toggle and minor controls.
static func apply_utility(btn: Button) -> void:
	# Normal
	var normal := StyleBoxFlat.new()
	normal.bg_color = SURFACE
	normal.border_color = Color("#3A3A40")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 1
	normal.content_margin_bottom = 1
	btn.add_theme_stylebox_override("normal", normal)

	# Hover
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#3A3A40")
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#4A4A50")
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	btn.add_theme_color_override("font_color", TEXT_MUTED)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
