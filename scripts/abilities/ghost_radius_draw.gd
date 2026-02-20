extends Node2D
## Draws a circle radius indicator for ability placement ghost.

var radius: float = 48.0
var valid: bool = true

const COL_VALID = Color("#40C040", 0.3)
const COL_VALID_BORDER = Color("#40C040", 0.6)
const COL_INVALID = Color("#C04040", 0.3)
const COL_INVALID_BORDER = Color("#C04040", 0.6)


func _draw() -> void:
	var fill_col := COL_VALID if valid else COL_INVALID
	var border_col := COL_VALID_BORDER if valid else COL_INVALID_BORDER
	draw_circle(Vector2.ZERO, radius, fill_col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, border_col, 1.0, true)
