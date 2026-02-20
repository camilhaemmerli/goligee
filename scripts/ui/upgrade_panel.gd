class_name UpgradePanel
extends PanelContainer
## Shows upgrade options when a placed tower is selected.
## Brutalist styling matching the HUD theme.

@onready var tower_name_label: Label = $VBox/TowerNameLabel
@onready var path_container: VBoxContainer = $VBox/PathContainer
@onready var sell_button: Button = $VBox/SellButton

var _selected_tower: BaseTower
var _blackletter_font: Font

const COL_PANEL_BG = Color("#1A1A1E")
const COL_BORDER = Color("#28282C")
const COL_GOLD = Color("#F2D864")
const COL_MUTED = Color("#808898")


func _ready() -> void:
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")

	SignalBus.tower_selected.connect(_on_tower_selected)
	SignalBus.tower_deselected.connect(_on_tower_deselected)
	sell_button.pressed.connect(_on_sell_pressed)
	visible = false

	_apply_panel_style()


func _apply_panel_style() -> void:
	# Brutalist panel background with rounded corners
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_PANEL_BG.r, COL_PANEL_BG.g, COL_PANEL_BG.b, 0.92)
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)

	# Tower name in Pirata One, centered
	if _blackletter_font:
		tower_name_label.add_theme_font_override("font", _blackletter_font)
	tower_name_label.add_theme_font_size_override("font_size", 20)
	tower_name_label.add_theme_color_override("font_color", ButtonStyles.PRIMARY)
	tower_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Sell button — small, muted, understated
	ButtonStyles.apply_subtle(sell_button)
	sell_button.add_theme_font_size_override("font_size", 11)
	sell_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _on_tower_selected(tower: Node2D) -> void:
	if tower is BaseTower:
		_selected_tower = tower
		_refresh()
		visible = true


func _on_tower_deselected() -> void:
	_selected_tower = null
	visible = false


func _refresh() -> void:
	if not _selected_tower or not _selected_tower.tower_data:
		return

	tower_name_label.text = _selected_tower.tower_data.get_display_name()
	sell_button.text = "SELL ($" + str(_selected_tower.get_sell_value()) + ")"

	# Clear old path buttons
	for child in path_container.get_children():
		child.queue_free()

	# Build upgrade path buttons
	var paths := _selected_tower.tower_data.upgrade_paths
	for path_i in paths.size():
		var path := paths[path_i]
		var current_tier: int = _selected_tower.upgrade.path_tiers[path_i]

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)

		# Path name header
		var header := Label.new()
		header.text = path.path_name + "  " + str(current_tier) + "/" + str(path.tiers.size())
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", COL_MUTED)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(header)

		if current_tier < path.tiers.size():
			var tier_data := path.tiers[current_tier]
			var can_afford := _selected_tower.upgrade.can_upgrade_path(path_i)
			var btn := Button.new()
			btn.text = tier_data.tier_name + "  $" + str(tier_data.cost)
			btn.disabled = not can_afford
			btn.pressed.connect(_on_upgrade_pressed.bind(path_i))
			btn.custom_minimum_size = Vector2(220, 42)
			if _blackletter_font:
				btn.add_theme_font_override("font", _blackletter_font)
			btn.add_theme_font_size_override("font_size", 16)
			ButtonStyles.apply_accent(btn)
			if not can_afford:
				btn.add_theme_color_override("font_color", COL_MUTED)
			vbox.add_child(btn)
		else:
			var maxed := Label.new()
			maxed.text = "MAXED"
			maxed.add_theme_font_size_override("font_size", 13)
			maxed.add_theme_color_override("font_color", Color("#A0D8A0"))
			maxed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(maxed)

		path_container.add_child(vbox)


func _on_upgrade_pressed(path_index: int) -> void:
	if _selected_tower:
		_selected_tower.upgrade.do_upgrade(path_index)
		_refresh()


func _on_sell_pressed() -> void:
	if _selected_tower:
		_selected_tower.sell()
		SignalBus.tower_deselected.emit()
