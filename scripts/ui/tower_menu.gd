class_name TowerMenu
extends PanelContainer
## Tower build menu — brutalist "Authorization Card" strip.

@export var tower_list: Array[TowerData] = []

@onready var button_container: HBoxContainer = $HBox

const CARD_SIZE := Vector2(78, 78)
const BUTTON_GAP := 6
const CORNER_RADIUS := 12

const CARD_DISABLED_ALPHA := 0.55

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
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.tooltip_text = tower_data.get_display_name()
	btn.pressed.connect(_on_tower_selected.bind(tower_data))
	btn.clip_contents = true
	btn.pivot_offset = CARD_SIZE * 0.5
	btn.button_down.connect(_on_card_down.bind(btn))
	btn.button_up.connect(_on_card_up.bind(btn))

	ButtonStyles.apply_icon_card(btn, CORNER_RADIUS)

	btn.text = ""

	# -- Icon (fills the card) --
	var icon_tex := tower_data.get_icon()
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 4
		icon_rect.offset_top = 4
		icon_rect.offset_right = -4
		icon_rect.offset_bottom = -4
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)

	# -- Price label (bottom-right, white, default font) --
	var price_label := Label.new()
	price_label.text = "$" + str(tower_data.build_cost)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", Color.WHITE)
	price_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	price_label.add_theme_constant_override("shadow_offset_x", 1)
	price_label.add_theme_constant_override("shadow_offset_y", 1)
	price_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	price_label.offset_left = -40
	price_label.offset_top = -20
	price_label.offset_right = -4
	price_label.offset_bottom = -3
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(price_label)

	# "GROUND" indicator for towers that cannot target flying enemies
	if not tower_data.can_target_flying:
		var ground_label := Label.new()
		ground_label.text = "GROUND"
		ground_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ground_label.add_theme_font_size_override("font_size", 8)
		ground_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		ground_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		ground_label.add_theme_constant_override("shadow_offset_x", 1)
		ground_label.add_theme_constant_override("shadow_offset_y", 1)
		ground_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		ground_label.offset_left = 4
		ground_label.offset_top = -16
		ground_label.offset_right = 50
		ground_label.offset_bottom = -3
		ground_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(ground_label)

	return btn


func _on_card_down(btn: Button) -> void:
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.06).set_ease(Tween.EASE_OUT)


func _on_card_up(btn: Button) -> void:
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
