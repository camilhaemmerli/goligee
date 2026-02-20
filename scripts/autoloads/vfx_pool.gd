extends Node
## Object pool for VFX nodes (Labels and ColorRects) to avoid per-hit allocations.

const INITIAL_LABELS = 40
const INITIAL_RECTS = 80
const MAX_POOL_LABELS = 80  # 2x initial — overflow beyond this is queue_free'd
const MAX_POOL_RECTS = 160

var _label_pool: Array[Label] = []
var _rect_pool: Array[ColorRect] = []
var _container: Node


func _ready() -> void:
	_init_pool()


func _init_pool() -> void:
	_container = Node.new()
	_container.name = "VFXPoolContainer"
	add_child(_container)

	for i in INITIAL_LABELS:
		var label := Label.new()
		label.visible = false
		_container.add_child(label)
		_label_pool.append(label)

	for i in INITIAL_RECTS:
		var rect := ColorRect.new()
		rect.visible = false
		_container.add_child(rect)
		_rect_pool.append(rect)


func reset_pool() -> void:
	# Discard stale refs (nodes freed with the old scene) and rebuild
	_label_pool.clear()
	_rect_pool.clear()
	if is_instance_valid(_container):
		_container.queue_free()
	_init_pool()


func acquire_label() -> Label:
	var label: Label
	if not _label_pool.is_empty():
		label = _label_pool.pop_back()
		# Reparent out of pool container
		_container.remove_child(label)
	else:
		label = Label.new()

	# Reset properties
	label.text = ""
	label.modulate = Color.WHITE
	label.scale = Vector2.ONE
	label.rotation = 0.0
	label.visible = true
	label.position = Vector2.ZERO
	label.z_index = 0
	label.size = Vector2.ZERO
	return label


func release_label(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.visible = false
	# Remove all theme overrides
	label.remove_theme_color_override("font_color")
	label.remove_theme_color_override("font_outline_color")
	label.remove_theme_font_size_override("font_size")
	label.remove_theme_constant_override("outline_size")

	if label.get_parent():
		label.get_parent().remove_child(label)

	if _label_pool.size() < MAX_POOL_LABELS:
		_container.add_child(label)
		_label_pool.append(label)
	else:
		label.queue_free()


func acquire_rect() -> ColorRect:
	var rect: ColorRect
	if not _rect_pool.is_empty():
		rect = _rect_pool.pop_back()
		_container.remove_child(rect)
	else:
		rect = ColorRect.new()

	# Reset properties
	rect.color = Color.WHITE
	rect.modulate = Color.WHITE
	rect.scale = Vector2.ONE
	rect.rotation = 0.0
	rect.visible = true
	rect.position = Vector2.ZERO
	rect.size = Vector2(2, 2)
	rect.z_index = 0
	return rect


func release_rect(rect: ColorRect) -> void:
	if not is_instance_valid(rect):
		return
	rect.visible = false

	if rect.get_parent():
		rect.get_parent().remove_child(rect)

	if _rect_pool.size() < MAX_POOL_RECTS:
		_container.add_child(rect)
		_rect_pool.append(rect)
	else:
		rect.queue_free()
