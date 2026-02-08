class_name UpgradePanel
extends PanelContainer
## Shows upgrade options when a placed tower is selected.

@onready var tower_name_label: Label = $VBox/TowerNameLabel
@onready var path_container: VBoxContainer = $VBox/PathContainer
@onready var sell_button: Button = $VBox/SellButton

var _selected_tower: BaseTower


func _ready() -> void:
	SignalBus.tower_selected.connect(_on_tower_selected)
	SignalBus.tower_deselected.connect(_on_tower_deselected)
	sell_button.pressed.connect(_on_sell_pressed)
	visible = false


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
	sell_button.text = "Sell (" + str(_selected_tower.get_sell_value()) + "g)"

	# Clear old path buttons
	for child in path_container.get_children():
		child.queue_free()

	# Build upgrade path buttons
	var paths := _selected_tower.tower_data.upgrade_paths
	for path_i in paths.size():
		var path := paths[path_i]
		var current_tier: int = _selected_tower.upgrade.path_tiers[path_i]

		var hbox := HBoxContainer.new()
		var label := Label.new()
		label.text = path.path_name + " [" + str(current_tier) + "/" + str(path.tiers.size()) + "]"
		label.custom_minimum_size.x = 100
		hbox.add_child(label)

		if current_tier < path.tiers.size():
			var tier_data := path.tiers[current_tier]
			var btn := Button.new()
			btn.text = tier_data.tier_name + " (" + str(tier_data.cost) + "g)"
			btn.disabled = not _selected_tower.upgrade.can_upgrade_path(path_i)
			btn.pressed.connect(_on_upgrade_pressed.bind(path_i))
			hbox.add_child(btn)
		else:
			var maxed := Label.new()
			maxed.text = "MAXED"
			hbox.add_child(maxed)

		path_container.add_child(hbox)


func _on_upgrade_pressed(path_index: int) -> void:
	if _selected_tower:
		_selected_tower.upgrade.do_upgrade(path_index)
		_refresh()


func _on_sell_pressed() -> void:
	if _selected_tower:
		_selected_tower.sell()
		SignalBus.tower_deselected.emit()
