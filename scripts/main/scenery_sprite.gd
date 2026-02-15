@tool
class_name ScenerySprite
extends Sprite2D
## Drag-and-drop scenery sprite for placing buildings, props, and decorations
## in the Godot 2D viewport.
##
## Usage:
##   1. Add a ScenerySprite node as a child of any container (e.g. CityBackground)
##   2. Pick a PNG file via the "Sprite File" property in the Inspector
##   3. Drag the node to position it in the viewport
##   4. Adjust scale, z_index, modulate, etc. as needed
##
## The sprite is anchored at the bottom-center by default so buildings
## "stand" on the ground. Disable anchor_bottom for centered sprites.

@export_file("*.png") var sprite_file: String = "":
	set(value):
		sprite_file = value
		_update_texture()

@export var anchor_bottom: bool = true:
	set(value):
		anchor_bottom = value
		_update_offset()

@export var foreground: bool = false:
	set(value):
		foreground = value
		_apply_foreground()


func _ready() -> void:
	_update_texture()
	_apply_foreground()


func _update_texture() -> void:
	if sprite_file.is_empty():
		texture = null
		return
	if not ResourceLoader.exists(sprite_file):
		push_warning("ScenerySprite: file not found — %s" % sprite_file)
		texture = null
		return
	texture = load(sprite_file)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_update_offset()


func _apply_foreground() -> void:
	if foreground:
		z_as_relative = false
		z_index = 2
	else:
		z_as_relative = true
		z_index = 0


func _update_offset() -> void:
	if texture and anchor_bottom:
		offset.y = -texture.get_height() / 2.0
	elif texture:
		offset = Vector2.ZERO
