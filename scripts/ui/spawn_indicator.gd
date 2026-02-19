class_name SpawnIndicator
extends Node2D
## Prominent pulsating play icon at the enemy spawn point.
## First click shows "START WAVE" label. After 3s delay, second click starts wave.

signal clicked

const COL_RED := Color("#D04040")
const COL_RED_BRIGHT := Color("#E05050")
const COL_RED_DIM := Color("#8A2020")
const COL_RED_GLOW := Color("#D0404040")  # with alpha

var _area: Area2D
var _pulse_t: float = 0.0
var _label: Label
var _state: int = 0  # 0=waiting first click, 1=showing label, 2=ready to start
var _delay_timer: float = 0.0


func _ready() -> void:
	visible = false
	z_index = 10

	# Click detection — larger radius for prominent icon
	_area = Area2D.new()
	_area.input_pickable = true
	_area.input_event.connect(_on_area_input)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 36.0
	shape.shape = circle
	_area.add_child(shape)
	add_child(_area)

	# "START WAVE" label
	_label = Label.new()
	_label.text = "START WAVE"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color("#1A1A1E"))
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(-40, 28)
	_label.size = Vector2(80, 20)
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_t += delta * 2.5
	if _state == 1:
		_delay_timer -= delta
		if _delay_timer <= 0.0:
			_state = 2
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var pulse := (sin(_pulse_t) + 1.0) * 0.5  # 0..1
	var s := lerpf(0.92, 1.12, pulse)
	var alpha := lerpf(0.7, 1.0, pulse)

	# Outer glow circle
	var glow_radius := 30.0 * s
	draw_circle(Vector2.ZERO, glow_radius, Color(COL_RED, alpha * 0.15))
	draw_circle(Vector2.ZERO, glow_radius * 0.85, Color(COL_RED, alpha * 0.1))

	# Dark circle background
	draw_circle(Vector2.ZERO, 22.0 * s, Color("#1A1A20"))

	# Red ring border (like approval bar styling)
	draw_arc(Vector2.ZERO, 22.0 * s, 0.0, TAU, 48, COL_RED_BRIGHT.lerp(COL_RED_DIM, 1.0 - pulse), 2.5)

	# Play triangle — large and centered
	var tri_sz := 12.0 * s
	var tri_offset := 2.0 * s  # slight right offset to visually center the triangle
	var tri_pts := PackedVector2Array([
		Vector2(-tri_sz * 0.55 + tri_offset, -tri_sz),
		Vector2(tri_sz * 0.85 + tri_offset, 0),
		Vector2(-tri_sz * 0.55 + tri_offset, tri_sz),
	])
	var tri_color := COL_RED_BRIGHT.lerp(Color.WHITE, pulse * 0.3)
	tri_color.a = alpha
	draw_colored_polygon(tri_pts, tri_color)

	# Inner triangle highlight
	var inner_sz := tri_sz * 0.5
	var inner_pts := PackedVector2Array([
		Vector2(-inner_sz * 0.55 + tri_offset, -inner_sz),
		Vector2(inner_sz * 0.85 + tri_offset, 0),
		Vector2(-inner_sz * 0.55 + tri_offset, inner_sz),
	])
	draw_colored_polygon(inner_pts, Color(1.0, 1.0, 1.0, alpha * 0.25))

	# Pulsing ring expansion effect
	var ring_alpha := (1.0 - pulse) * 0.3 * alpha
	if ring_alpha > 0.01:
		var ring_r := lerpf(24.0, 36.0, pulse)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(COL_RED, ring_alpha), 1.5)


func show_indicator() -> void:
	_pulse_t = 0.0
	_state = 0
	_delay_timer = 0.0
	_label.visible = false
	visible = true
	# Entrance pop
	scale = Vector2(0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func hide_indicator() -> void:
	visible = false
	_label.visible = false
	_state = 0


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	if _state == 0:
		# First click — show "START WAVE" and begin 3s delay
		_state = 1
		_delay_timer = 3.0
		_label.visible = true
		# Pop the label in
		_label.modulate = Color(1, 1, 1, 0)
		var tween := create_tween()
		tween.tween_property(_label, "modulate", Color.WHITE, 0.25)
	elif _state == 2:
		# Second click after delay — start the wave
		clicked.emit()
