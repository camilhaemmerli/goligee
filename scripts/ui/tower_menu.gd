class_name TowerMenu
extends PanelContainer
## Tower build menu — brutalist "Authorization Card" strip.

@export var tower_list: Array[TowerData] = []

@onready var button_container: HBoxContainer = $HBox

const CARD_SIZE := Vector2(64, 76)
const ICON_SIZE := 40
const BUTTON_GAP := 4

# Brutalist palette
const CARD_BG       := Color("#1A1A1E")
const CARD_BORDER   := Color("#28282C")
const CARD_HOVER    := Color("#4A4A50")
const CARD_SELECTED := Color("#A23813")  # RUST
const CARD_DISABLED_ALPHA := 0.55

# Price pill
const PILL_BG   := Color("#08080A")
const PILL_TEXT  := Color("#F2D864")

# Damage type accent colors (top 2px line)
const DAMAGE_TYPE_COLORS := {
	Enums.DamageType.KINETIC: Color("#9A9AA0"),
	Enums.DamageType.CHEMICAL: Color("#70A040"),
	Enums.DamageType.HYDRAULIC: Color("#50A0D0"),
	Enums.DamageType.ELECTRIC: Color("#D8A040"),
	Enums.DamageType.SONIC: Color("#70A040"),
	Enums.DamageType.DIRECTED_ENERGY: Color("#A060C0"),
	Enums.DamageType.CYBER: Color("#50A0D0"),
	Enums.DamageType.PSYCHOLOGICAL: Color("#808898"),
}


func _ready() -> void:
	# Make the outer PanelContainer transparent
	var transparent := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", transparent)

	button_container.add_theme_constant_override("separation", BUTTON_GAP)

	SignalBus.build_mode_exited.connect(_on_build_mode_exited)


func _build_buttons() -> void:
	for child in button_container.get_children():
		child.queue_free()

	for tower_data in tower_list:
		var btn := _create_tower_button(tower_data)
		button_container.add_child(btn)


func _create_tower_button(tower_data: TowerData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.tooltip_text = tower_data.get_display_name()
	btn.pressed.connect(_on_tower_selected.bind(tower_data))
	btn.clip_contents = true

	# Get damage type accent color
	var accent_color: Color = DAMAGE_TYPE_COLORS.get(tower_data.damage_type, Color("#9A9AA0"))

	# Brutalist card backgrounds per state — sharp corners (0 radius)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(0)
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		sb.content_margin_top = 4
		sb.content_margin_bottom = 2

		match state:
			"normal":
				sb.bg_color = CARD_BG
				sb.border_color = CARD_BORDER
			"hover":
				sb.bg_color = CARD_BG
				sb.border_color = CARD_HOVER
			"pressed":
				sb.bg_color = CARD_BG
				sb.border_color = CARD_SELECTED
			"disabled":
				sb.bg_color = CARD_BG
				sb.border_color = CARD_BORDER

		sb.set_border_width_all(2)
		# Top accent line — damage type color
		sb.border_width_top = 3
		if state == "normal" or state == "disabled":
			sb.border_color = CARD_BORDER
		# The accent goes via the expand margin trick:
		# We set top border to accent color via a sub-element instead

		btn.add_theme_stylebox_override(state, sb)

	btn.text = ""

	# -- Accent line (top 2px colored by damage type) --
	var accent_line := ColorRect.new()
	accent_line.color = accent_color
	accent_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent_line.offset_top = 0
	accent_line.offset_bottom = 2
	accent_line.offset_left = 0
	accent_line.offset_right = 0
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(accent_line)

	# -- Icon --
	var icon_tex := tower_data.get_icon()
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 6
		icon_rect.offset_top = 4
		icon_rect.offset_right = -6
		icon_rect.offset_bottom = -18  # room for pill
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)

	# -- Price pill (bottom-center) --
	var pill := _make_price_pill(tower_data.build_cost)
	pill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.offset_top = -14
	pill.offset_bottom = -2
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(pill)

	return btn


func _make_price_pill(cost: int) -> PanelContainer:
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL_BG
	sb.set_corner_radius_all(0)  # sharp corners
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", sb)

	var label := Label.new()
	label.text = "$" + str(cost)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", PILL_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return pill


func _on_tower_selected(tower_data: TowerData) -> void:
	if EconomyManager.can_afford(tower_data.build_cost):
		SignalBus.build_mode_entered.emit(tower_data)


func _on_build_mode_exited() -> void:
	for btn in button_container.get_children():
		if btn is Button:
			btn.button_pressed = false


func _process(_delta: float) -> void:
	for i in button_container.get_child_count():
		if i >= tower_list.size():
			break
		var btn := button_container.get_child(i) as Button
		if btn:
			var can_afford := EconomyManager.can_afford(tower_list[i].build_cost)
			btn.disabled = not can_afford
			btn.modulate.a = 1.0 if can_afford else CARD_DISABLED_ALPHA
