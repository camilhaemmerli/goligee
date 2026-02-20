class_name PlatformRenderer
extends Node2D
## Draws the visible side faces of the raised platform, giving the isometric
## playing field physical depth — a chunk of city floating in dark void.

const TILE_W = 64
const TILE_H = 32
const DEPTH = 56  # pixels of visible side-face height

# Layer colors for the cross-section (top to bottom)
const ASPHALT = Color("#3A3A3E")
const CONCRETE = Color("#2E2E32")
const REBAR = Color("#242428")
const DIRT = Color("#1A1A1E")
const DEEP = Color("#121216")
const VOID = Color("#0E0E12")

# Detail line colors
const PIPE_COLOR = Color("#1E1E22")
const ROCK_COLOR = Color("#28282C")

var _tile_map: TileMapLayer
var _map_w: int
var _map_h: int


func setup(tile_map: TileMapLayer, map_w: int, map_h: int) -> void:
	_tile_map = tile_map
	_map_w = map_w
	_map_h = map_h
	queue_redraw()


func _draw() -> void:
	if not _tile_map:
		return
	_draw_bottom_faces()
	_draw_left_faces()
	_draw_right_faces()


func _draw_bottom_faces() -> void:
	# Bottom edge: row MAP_H-1, all columns
	for x in _map_w:
		var pos := _tile_map.map_to_local(Vector2i(x, _map_h - 1))
		_draw_south_face(pos, 1.0)


func _draw_left_faces() -> void:
	# Left edge: col 0, all rows
	for y in _map_h:
		var pos := _tile_map.map_to_local(Vector2i(0, y))
		_draw_west_face(pos, 0.75)


func _draw_right_faces() -> void:
	# Right edge: col MAP_W-1, all rows
	for y in _map_h:
		var pos := _tile_map.map_to_local(Vector2i(_map_w - 1, y))
		_draw_east_face(pos, 0.88)


func _draw_south_face(tile_center: Vector2, brightness: float) -> void:
	# The bottom vertex of the isometric diamond
	var bottom := tile_center + Vector2(0, TILE_H / 2.0)
	var left := tile_center + Vector2(-TILE_W / 2.0, 0)
	var right := tile_center + Vector2(TILE_W / 2.0, 0)

	# Left trapezoid (bottom-left face)
	var bl_top_left := left
	var bl_top_right := bottom
	var bl_bot_right := bottom + Vector2(0, DEPTH)
	var bl_bot_left := left + Vector2(0, DEPTH)
	_draw_face_with_layers(
		[bl_top_left, bl_top_right, bl_bot_right, bl_bot_left],
		brightness * 0.85
	)

	# Right trapezoid (bottom-right face)
	var br_top_left := bottom
	var br_top_right := right
	var br_bot_right := right + Vector2(0, DEPTH)
	var br_bot_left := bottom + Vector2(0, DEPTH)
	_draw_face_with_layers(
		[br_top_left, br_top_right, br_bot_right, br_bot_left],
		brightness * 1.0
	)


func _draw_west_face(tile_center: Vector2, brightness: float) -> void:
	var top := tile_center + Vector2(0, -TILE_H / 2.0)
	var left := tile_center + Vector2(-TILE_W / 2.0, 0)

	var face := PackedVector2Array([
		left,
		top,
		top + Vector2(0, DEPTH),
		left + Vector2(0, DEPTH),
	])
	_draw_face_with_layers(Array(face), brightness * 0.7)


func _draw_east_face(tile_center: Vector2, brightness: float) -> void:
	var top := tile_center + Vector2(0, -TILE_H / 2.0)
	var right := tile_center + Vector2(TILE_W / 2.0, 0)

	var face := PackedVector2Array([
		top,
		right,
		right + Vector2(0, DEPTH),
		top + Vector2(0, DEPTH),
	])
	_draw_face_with_layers(Array(face), brightness * 0.92)


func _draw_face_with_layers(corners: Array, brightness: float) -> void:
	# Draw the face as horizontal layer bands from top to bottom
	var layer_defs := [
		{"frac": 0.0,  "color": ASPHALT},
		{"frac": 0.12, "color": CONCRETE},
		{"frac": 0.35, "color": REBAR},
		{"frac": 0.55, "color": DIRT},
		{"frac": 0.78, "color": DEEP},
		{"frac": 1.0,  "color": VOID},
	]

	for i in range(layer_defs.size() - 1):
		var t0: float = layer_defs[i]["frac"]
		var t1: float = layer_defs[i + 1]["frac"]
		var c0: Color = (layer_defs[i]["color"] as Color)
		var c1: Color = (layer_defs[i + 1]["color"] as Color)
		var mid_color := c0.lerp(c1, 0.5)
		mid_color = _apply_brightness(mid_color, brightness)

		# Interpolate between top and bottom edges of the quad
		var band := PackedVector2Array([
			_lerp_quad_y(corners, t0, true),
			_lerp_quad_y(corners, t0, false),
			_lerp_quad_y(corners, t1, false),
			_lerp_quad_y(corners, t1, true),
		])
		draw_colored_polygon(band, mid_color)

	# Draw detail lines (cross-section markings)
	_draw_detail_lines(corners, brightness)


func _draw_detail_lines(corners: Array, brightness: float) -> void:
	# Horizontal lines at specific depth fractions suggesting layers
	var line_fracs := [0.12, 0.35, 0.55, 0.78]
	for frac in line_fracs:
		var left_pt := _lerp_quad_y(corners, frac, true)
		var right_pt := _lerp_quad_y(corners, frac, false)
		var line_color := _apply_brightness(Color("#1A1A1E"), brightness * 0.8)
		draw_line(left_pt, right_pt, line_color, 1.0)

	# Scattered detail pixels (pipes, rocks, roots)
	var seed_base := int(corners[0].x * 7 + corners[0].y * 13)
	for i in 4:
		var h := _simple_hash(seed_base + i * 37)
		var frac_y := 0.15 + (h % 60) / 100.0
		var frac_x := 0.2 + ((h / 7) % 60) / 100.0
		var pt := _lerp_quad_xy(corners, frac_x, frac_y)
		var detail_color: Color
		if i % 2 == 0:
			detail_color = _apply_brightness(PIPE_COLOR, brightness)
		else:
			detail_color = _apply_brightness(ROCK_COLOR, brightness * 1.1)
		draw_circle(pt, 1.0, detail_color)


func _lerp_quad_y(corners: Array, t: float, is_left: bool) -> Vector2:
	# corners: [top_left, top_right, bot_right, bot_left]
	if is_left:
		return corners[0].lerp(corners[3], t)
	else:
		return corners[1].lerp(corners[2], t)


func _lerp_quad_xy(corners: Array, tx: float, ty: float) -> Vector2:
	var top := (corners[0] as Vector2).lerp(corners[1] as Vector2, tx)
	var bot := (corners[3] as Vector2).lerp(corners[2] as Vector2, tx)
	return top.lerp(bot, ty)


func _apply_brightness(color: Color, factor: float) -> Color:
	return Color(
		clampf(color.r * factor, 0.0, 1.0),
		clampf(color.g * factor, 0.0, 1.0),
		clampf(color.b * factor, 0.0, 1.0),
		color.a
	)


func _simple_hash(val: int) -> int:
	var v := (val * 2654435761) & 0xFFFFFF
	return absi(v)
