class_name CameraController
extends Camera2D
## Handles zoom (pinch/scroll) and pan (drag/MMB/trackpad) for the game camera.
## Attached to the Camera2D created in game.gd.

## Zoom limits
const ZOOM_MIN := 0.80
const ZOOM_MAX := 2.0
const ZOOM_DEFAULT := 0.95
const ZOOM_STEP := 0.05
const ZOOM_SPEED := 8.0  # lerp speed

## Pan
var _map_bounds := Rect2()  # world-space bounds of the playable area + border
var _panning := false
var _pan_start := Vector2.ZERO
var _cam_start := Vector2.ZERO
var _base_position := Vector2.ZERO  # logical position before shake

## Zoom
var _target_zoom := ZOOM_DEFAULT
var _pinch_distance := 0.0
var _touch_points := {}  # id -> position

## Build mode flag — when true, single-finger drag moves ghost instead of panning
var build_mode := false

## Shake offset (set each frame by game.gd)
var shake_offset := Vector2.ZERO


func _ready() -> void:
	zoom = Vector2(ZOOM_DEFAULT, ZOOM_DEFAULT)
	_target_zoom = ZOOM_DEFAULT
	_base_position = position
	SignalBus.build_mode_entered.connect(func(_td): build_mode = true)
	SignalBus.build_mode_exited.connect(func(): build_mode = false)


func setup_bounds(bounds: Rect2) -> void:
	_map_bounds = bounds


func _process(delta: float) -> void:
	# Smooth zoom interpolation
	var current := zoom.x
	if not is_equal_approx(current, _target_zoom):
		var new_zoom := lerpf(current, _target_zoom, clampf(ZOOM_SPEED * delta, 0.0, 1.0))
		zoom = Vector2(new_zoom, new_zoom)

	# Clamp logical position, then apply shake on top
	if _map_bounds.has_area():
		_base_position = _clamp_position(_base_position)
	position = (_base_position + shake_offset).round()


func _unhandled_input(event: InputEvent) -> void:
	# --- Touch tracking for pinch detection ---
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			if _touch_points.size() < 2:
				_pinch_distance = 0.0
			if _touch_points.is_empty():
				_panning = false
		return

	# --- Pinch zoom (2 fingers) ---
	if event is InputEventScreenDrag and _touch_points.size() >= 2:
		_touch_points[event.index] = event.position
		var points := _touch_points.values()
		var dist: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
		if _pinch_distance > 0.0:
			var scale_factor := dist / _pinch_distance
			_target_zoom = clamp(_target_zoom * scale_factor, ZOOM_MIN, ZOOM_MAX)
		_pinch_distance = dist
		get_viewport().set_input_as_handled()
		return

	# --- Single finger pan (mobile, not in build mode) ---
	if event is InputEventScreenDrag and _touch_points.size() == 1 and not build_mode:
		_base_position -= event.relative / zoom.x
		get_viewport().set_input_as_handled()
		return

	# --- macOS trackpad magnify gesture (pinch to zoom) ---
	if event is InputEventMagnifyGesture:
		_target_zoom = clamp(_target_zoom * event.factor, ZOOM_MIN, ZOOM_MAX)
		get_viewport().set_input_as_handled()
		return

	# --- macOS trackpad pan gesture (two-finger scroll) ---
	if event is InputEventPanGesture:
		_base_position += event.delta * (20.0 / zoom.x)
		get_viewport().set_input_as_handled()
		return

	# --- Scroll wheel zoom (desktop mouse) ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_zoom = clamp(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_zoom = clamp(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return

		# Middle mouse button pan start/stop
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true
				_pan_start = event.position
				_cam_start = _base_position
			else:
				_panning = false
			get_viewport().set_input_as_handled()
			return

	# --- Middle mouse drag pan ---
	if event is InputEventMouseMotion and _panning:
		_base_position = _cam_start + (_pan_start - get_viewport().get_mouse_position()) / zoom.x
		get_viewport().set_input_as_handled()
		return


func _clamp_position(pos: Vector2) -> Vector2:
	var vp_size := get_viewport_rect().size / zoom.x
	var half_vp := vp_size * 0.5

	# Allow some slack so the map doesn't feel claustrophobic
	var min_x := _map_bounds.position.x - half_vp.x * 0.2
	var max_x := _map_bounds.end.x + half_vp.x * 0.2
	var min_y := _map_bounds.position.y - half_vp.y * 0.2
	var max_y := _map_bounds.end.y + half_vp.y * 0.2

	# If map fits in viewport, center it
	if max_x - min_x <= vp_size.x:
		pos.x = (min_x + max_x) * 0.5
	else:
		pos.x = clamp(pos.x, min_x + half_vp.x, max_x - half_vp.x)

	if max_y - min_y <= vp_size.y:
		pos.y = (min_y + max_y) * 0.5
	else:
		pos.y = clamp(pos.y, min_y + half_vp.y, max_y - half_vp.y)

	return pos
