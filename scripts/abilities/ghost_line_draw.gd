extends Node2D
## Draws a line indicator for airstrike placement ghost.
## Shows the strike corridor at a fixed isometric diagonal angle.

var valid: bool = true

const LINE_HALF_LENGTH = 300.0
const FLIGHT_DIR = Vector2(0.894, 0.447)  # Vector2(1, 0.5).normalized(), isometric SE
const DASH_LENGTH = 8.0
const GAP_LENGTH = 6.0

const COL_VALID = Color("#F0A030", 0.5)
const COL_VALID_GLOW = Color("#F0A030", 0.15)
const COL_INVALID = Color("#C04040", 0.5)


func _draw() -> void:
	var col := COL_VALID if valid else COL_INVALID
	var glow_col := COL_VALID_GLOW if valid else Color("#C04040", 0.1)
	var start := -FLIGHT_DIR * LINE_HALF_LENGTH
	var end_pt := FLIGHT_DIR * LINE_HALF_LENGTH

	# Glow corridor (wide, semi-transparent)
	var perp := Vector2(-FLIGHT_DIR.y, FLIGHT_DIR.x) * 20.0
	var corridor := PackedVector2Array([
		start + perp, end_pt + perp, end_pt - perp, start - perp,
	])
	draw_colored_polygon(corridor, glow_col)

	# Dashed line
	var total_length := LINE_HALF_LENGTH * 2.0
	var dir := FLIGHT_DIR
	var pos := start
	var drawn := 0.0
	while drawn < total_length:
		var seg := minf(DASH_LENGTH, total_length - drawn)
		var seg_end := pos + dir * seg
		draw_line(pos, seg_end, col, 1.5)
		drawn += seg + GAP_LENGTH
		pos = seg_end + dir * GAP_LENGTH

	# Arrow tip showing flight direction
	var arrow_tip := FLIGHT_DIR * 40.0
	var arrow_perp := Vector2(-FLIGHT_DIR.y, FLIGHT_DIR.x)
	draw_line(arrow_tip, arrow_tip - FLIGHT_DIR * 10.0 + arrow_perp * 5.0, col, 1.5)
	draw_line(arrow_tip, arrow_tip - FLIGHT_DIR * 10.0 - arrow_perp * 5.0, col, 1.5)
