class_name IntroComic
extends CanvasLayer
## Cinematic intro comic overlay. Pans through 3 comic panels with fade
## transitions while the game music plays underneath. Tap to skip.

signal finished

const PANEL_COUNT := 3
const HOLD_TIME := 2.5   # seconds per panel
const FADE_TIME := 0.6   # fade between panels
const FINAL_HOLD := 1.5  # hold on last panel before fading out

var _root: Control
var _bg: ColorRect
var _panel_rect: TextureRect
var _tex: Texture2D
var _hint_label: Label
var _tween: Tween
var _panel_idx: int = -1
var _can_skip: bool = false
var _done: bool = false


func _ready() -> void:
	layer = 20  # above everything
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Root control to fill viewport — CanvasLayer children need this
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)

	# Full-screen black background
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)

	# Panel display — centered, will show one panel at a time
	_panel_rect = TextureRect.new()
	_panel_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_rect.modulate.a = 0.0
	_panel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel_rect)

	# "Tap to continue" hint
	_hint_label = Label.new()
	_hint_label.text = "TAP TO CONTINUE"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_bottom = -20.0
	_hint_label.offset_top = -40.0
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_hint_label.modulate.a = 0.0
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint_label)

	# Load the comic texture
	var path := "res://assets/sprites/ui/intro_comic.jpg"
	if ResourceLoader.exists(path):
		_tex = load(path) as Texture2D

	_start_sequence()


func _start_sequence() -> void:
	if not _tex:
		_finish()
		return

	# Brief black hold before first panel
	_tween = create_tween()
	_tween.tween_interval(0.8)
	_tween.tween_callback(_show_next_panel)


func _show_next_panel() -> void:
	_panel_idx += 1
	if _panel_idx >= PANEL_COUNT:
		_fade_out()
		return

	# Extract panel region from the 1024x1024 image (3 equal horizontal strips)
	var panel_h := _tex.get_height() / PANEL_COUNT
	var region := Rect2(0, _panel_idx * panel_h, _tex.get_width(), panel_h)
	var atlas := AtlasTexture.new()
	atlas.atlas = _tex
	atlas.region = region
	_panel_rect.texture = atlas

	# Fade in panel
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_panel_rect.modulate.a = 0.0
	_tween.tween_property(_panel_rect, "modulate:a", 1.0, FADE_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Show skip hint after first panel fades in
	if _panel_idx == 0:
		_tween.parallel().tween_property(_hint_label, "modulate:a", 1.0, 1.0)
		_can_skip = true

	# Auto-advance after hold
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_callback(_show_next_panel)


func _fade_out() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(FINAL_HOLD)
	_tween.tween_property(_panel_rect, "modulate:a", 0.0, FADE_TIME)
	_tween.parallel().tween_property(_hint_label, "modulate:a", 0.0, 0.3)
	_tween.tween_property(_bg, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(_finish)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _on_input(event: InputEvent) -> void:
	if not _can_skip:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _panel_idx < PANEL_COUNT:
			_fade_out()
		else:
			_finish()
	elif event is InputEventScreenTouch and event.pressed:
		if _panel_idx < PANEL_COUNT:
			_fade_out()
		else:
			_finish()
