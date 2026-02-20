class_name AbilityPanel
extends Control
## HUD panel for the 3 Executive Decree ability buttons.
## Circular buttons with cooldown ring arcs and keyboard shortcuts.

const BUTTON_SIZE = 52.0
const BUTTON_GAP = 8.0
const RING_WIDTH = 3.0
const COL_READY = Color("#D04040")
const COL_COOLDOWN_TRACK = Color("#2A2A30")
const COL_COOLDOWN_SWEEP = Color("#D04040", 0.6)
const COL_HEADER = Color("#C0B8A8")
const COL_HOTKEY = Color("#A0A8B0")
const LOCKED_ALPHA = 0.3

var _abilities: Array[SpecialAbilityData] = []
var _buttons: Array[Button] = []
var _ring_draws: Array[Control] = []  # Custom draw controls for cooldown rings
var _hotkey_labels: Array[Label] = []
var _cooldown_ratios: Dictionary = {}  # ability_id -> float (0..1)
var _placing_ability_id: String = ""
var _blackletter_font: Font


func _ready() -> void:
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	SignalBus.ability_placement_started.connect(_on_placement_started)
	SignalBus.ability_placement_cancelled.connect(_on_placement_cancelled)
	SignalBus.ability_activated.connect(_on_ability_activated)
	SignalBus.ability_unlocked.connect(_on_ability_unlocked)
	AbilityManager.cooldown_updated.connect(_on_cooldown_updated)

	# Build UI after a frame so AbilityManager is initialized
	call_deferred("_build_ui")


func _build_ui() -> void:
	_abilities = AbilityManager.get_abilities()
	if _abilities.is_empty():
		return

	# Header label
	var header := Label.new()
	header.text = "EXECUTIVE DECREES"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 9)
	header.add_theme_color_override("font_color", COL_HEADER)
	if _blackletter_font:
		header.add_theme_font_override("font", _blackletter_font)
	header.position = Vector2(0, 0)
	header.size = Vector2(_get_total_width(), 16)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	# Create buttons
	for i in _abilities.size():
		var ability := _abilities[i]
		_cooldown_ratios[ability.ability_id] = 0.0
		_create_ability_button(i, ability)


func _get_total_width() -> float:
	return _abilities.size() * BUTTON_SIZE + (_abilities.size() - 1) * BUTTON_GAP


func _create_ability_button(index: int, ability: SpecialAbilityData) -> void:
	var x_offset := index * (BUTTON_SIZE + BUTTON_GAP)
	var y_offset := 18.0  # Below header
	var is_locked := not AbilityManager.is_unlocked(ability.ability_id)

	# Button container
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.position = Vector2(x_offset, y_offset)
	btn.clip_text = true
	btn.text = ""
	btn.tooltip_text = ability.thematic_name + "\n" + ability.display_name + "\n" + ability.description
	btn.pressed.connect(_on_button_pressed.bind(ability))
	ButtonStyles.apply_icon_card(btn)
	# Reduced opacity when locked
	if is_locked:
		btn.modulate.a = LOCKED_ALPHA
	add_child(btn)
	_buttons.append(btn)

	# Icon or placeholder text
	if ability.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = ability.icon
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.position = Vector2(6, 6)
		icon_rect.size = Vector2(BUTTON_SIZE - 12, BUTTON_SIZE - 12)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)
	else:
		# Placeholder: short label in Pirata One
		var placeholder := Label.new()
		var short_names := ["AGT", "GAS", "H2O"]
		placeholder.text = short_names[index] if index < short_names.size() else "?"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.position = Vector2.ZERO
		placeholder.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		placeholder.add_theme_font_size_override("font_size", 14)
		placeholder.add_theme_color_override("font_color", Color.WHITE)
		if _blackletter_font:
			placeholder.add_theme_font_override("font", _blackletter_font)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(placeholder)

	# Cooldown ring (custom draw overlay)
	var ring := Control.new()
	ring.position = Vector2(x_offset, y_offset)
	ring.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_cooldown_ring.bind(index))
	if is_locked:
		ring.modulate.a = LOCKED_ALPHA
	add_child(ring)
	_ring_draws.append(ring)

	# Hotkey label (top-left corner)
	var hotkey := Label.new()
	hotkey.text = str(index + 1)
	hotkey.position = Vector2(x_offset + 3, y_offset + 1)
	hotkey.add_theme_font_size_override("font_size", 9)
	hotkey.add_theme_color_override("font_color", COL_HOTKEY)
	hotkey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_locked:
		hotkey.modulate.a = LOCKED_ALPHA
	add_child(hotkey)
	_hotkey_labels.append(hotkey)


func _draw_cooldown_ring(index: int) -> void:
	if index >= _abilities.size():
		return
	var ability := _abilities[index]
	var ratio: float = _cooldown_ratios.get(ability.ability_id, 0.0)
	var center := Vector2(BUTTON_SIZE / 2.0, BUTTON_SIZE / 2.0)
	var outer_r := BUTTON_SIZE / 2.0 - 1.0

	# Background track ring
	_ring_draws[index].draw_arc(center, outer_r, 0.0, TAU, 48, COL_COOLDOWN_TRACK, RING_WIDTH, true)

	if ratio <= 0.0:
		# Ready ring — full bright
		_ring_draws[index].draw_arc(center, outer_r, 0.0, TAU, 48, COL_READY, RING_WIDTH, true)
	else:
		# Cooldown sweep: fills clockwise as cooldown expires
		var ready_ratio := 1.0 - ratio
		if ready_ratio > 0.0:
			var start_angle := -PI / 2.0
			var end_angle := start_angle + TAU * ready_ratio
			_ring_draws[index].draw_arc(center, outer_r, start_angle, end_angle, 48, COL_COOLDOWN_SWEEP, RING_WIDTH, true)

	# Highlight active placement
	if ability.ability_id == _placing_ability_id:
		_ring_draws[index].draw_arc(center, outer_r + 2.0, 0.0, TAU, 48, COL_READY, 1.5, true)


func _process(_delta: float) -> void:
	# Redraw all rings each frame (cooldown ticking)
	for ring in _ring_draws:
		ring.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	# Hotkeys 1/2/3
	var key: int = event.keycode
	var index := -1
	if key == KEY_1:
		index = 0
	elif key == KEY_2:
		index = 1
	elif key == KEY_3:
		index = 2

	if index >= 0 and index < _abilities.size():
		_on_button_pressed(_abilities[index])
		get_viewport().set_input_as_handled()


# -- Signal handlers --

func _on_button_pressed(ability: SpecialAbilityData) -> void:
	if _placing_ability_id == ability.ability_id:
		# Toggle off if already placing this ability
		AbilityManager.cancel_placement()
		return
	if AbilityManager.is_ready_to_use(ability.ability_id):
		AbilityManager.start_placement(ability)


func _on_placement_started(ability_data: SpecialAbilityData) -> void:
	_placing_ability_id = ability_data.ability_id


func _on_placement_cancelled() -> void:
	_placing_ability_id = ""


func _on_ability_activated(_ability_id: String, _world_pos: Vector2) -> void:
	_placing_ability_id = ""


func _on_ability_unlocked(ability_data: SpecialAbilityData) -> void:
	# Find matching button and fade in from locked opacity
	for i in _abilities.size():
		if _abilities[i].ability_id == ability_data.ability_id:
			if i < _buttons.size():
				var btn := _buttons[i]
				var ring := _ring_draws[i] if i < _ring_draws.size() else null
				var hotkey := _hotkey_labels[i] if i < _hotkey_labels.size() else null
				# Fade in button
				var tw := btn.create_tween()
				tw.tween_property(btn, "modulate:a", 1.0, 0.5)
				# Flash
				tw.tween_property(btn, "modulate", Color(1.5, 1.2, 1.0), 0.2)
				tw.tween_property(btn, "modulate", Color.WHITE, 0.3)
				# Fade in ring overlay
				if ring:
					var ring_tw := ring.create_tween()
					ring_tw.tween_property(ring, "modulate:a", 1.0, 0.5)
				# Fade in hotkey label
				if hotkey:
					var hk_tw := hotkey.create_tween()
					hk_tw.tween_property(hotkey, "modulate:a", 1.0, 0.5)
			break


func _on_cooldown_updated(ability_id: String, ratio: float) -> void:
	_cooldown_ratios[ability_id] = ratio
