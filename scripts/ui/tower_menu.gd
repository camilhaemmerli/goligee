class_name TowerMenu
extends PanelContainer
## Tower build menu — brutalist "Authorization Card" strip.

@export var tower_list: Array[TowerData] = []

@onready var button_container: HBoxContainer = $HBox

const CARD_SIZE := Vector2(64, 64)
const BUTTON_GAP := 4
const CORNER_RADIUS := 4

# Brutalist palette
const CARD_BG       := Color("#1A1A1E")
const CARD_BORDER   := Color("#28282C")
const CARD_HOVER    := Color("#4A4A50")
const CARD_SELECTED := Color("#A23813")  # RUST
const CARD_DISABLED_ALPHA := 0.55

var _blackletter_font: Font


func _ready() -> void:
	# Make the outer PanelContainer transparent
	var transparent := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", transparent)
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")

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
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.tooltip_text = tower_data.get_display_name()
	btn.pressed.connect(_on_tower_selected.bind(tower_data))
	btn.clip_contents = true

	# Rounded card backgrounds per state
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(CORNER_RADIUS)
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		sb.content_margin_top = 2
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
		btn.add_theme_stylebox_override(state, sb)

	btn.text = ""

	# -- Icon (fills the card) --
	var icon_tex := tower_data.get_icon()
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 4
		icon_rect.offset_top = 4
		icon_rect.offset_right = -4
		icon_rect.offset_bottom = -4
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)

	# -- Price label (top-center, white, Pirata One) --
	var price_label := Label.new()
	price_label.text = "$" + str(tower_data.build_cost)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", Color.WHITE)
	price_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	price_label.add_theme_constant_override("shadow_offset_x", 1)
	price_label.add_theme_constant_override("shadow_offset_y", 1)
	if _blackletter_font:
		price_label.add_theme_font_override("font", _blackletter_font)
	price_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	price_label.offset_top = 2
	price_label.offset_bottom = 20
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(price_label)

	return btn


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
