@tool
class_name PlayfieldGuide
extends Node2D
## Editor-only guide that draws the playfield boundary as a cyan diamond.
## Helps with positioning buildings and decorations relative to the game area.
## Invisible at runtime.

const MAP_W := 24
const MAP_H := 14
const HW := 32.0  # TILE_W / 2
const HH := 16.0  # TILE_H / 2


func _ready() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	# Compute outer boundary of the playfield diamond
	var top_left := _tile_center(0, 0)
	var top_right := _tile_center(MAP_W - 1, 0)
	var bot_right := _tile_center(MAP_W - 1, MAP_H - 1)
	var bot_left := _tile_center(0, MAP_H - 1)

	# Expand to tile edges (each tile is a 64x32 diamond)
	var pts := PackedVector2Array([
		top_left + Vector2(0, -HH),      # top vertex
		top_right + Vector2(HW, 0),      # right vertex
		bot_right + Vector2(0, HH),      # bottom vertex
		bot_left + Vector2(-HW, 0),      # left vertex
		top_left + Vector2(0, -HH),      # close
	])
	var color := Color(0.4, 0.7, 1.0, 0.25)
	draw_polyline(pts, color, 2.0)

	# Spawn / Goal markers
	var spawn := _tile_center(0, 6)
	var goal := _tile_center(23, 8)
	draw_circle(spawn, 6.0, Color(0.2, 1.0, 0.3, 0.35))
	draw_circle(goal, 6.0, Color(1.0, 0.3, 0.2, 0.35))


static func _tile_center(tx: int, ty: int) -> Vector2:
	return Vector2((tx - ty) * HW, (tx + ty) * HH)
