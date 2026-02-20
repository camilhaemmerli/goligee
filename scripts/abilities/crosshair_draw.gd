extends Node2D
## Draws a small crosshair at the placement point.

const SIZE = 6.0
const COL = Color("#F0F0F0", 0.7)


func _draw() -> void:
	draw_line(Vector2(-SIZE, 0), Vector2(SIZE, 0), COL, 1.0)
	draw_line(Vector2(0, -SIZE), Vector2(0, SIZE), COL, 1.0)
