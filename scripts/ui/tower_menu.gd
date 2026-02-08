class_name TowerMenu
extends PanelContainer
## Tower build menu. Shows available towers and handles selection.

@export var tower_list: Array[TowerData] = []

@onready var button_container: HBoxContainer = $MarginContainer/HBoxContainer


func _ready() -> void:
	_build_buttons()
	SignalBus.build_mode_exited.connect(_on_build_mode_exited)


func _build_buttons() -> void:
	for child in button_container.get_children():
		child.queue_free()

	for tower_data in tower_list:
		var btn := Button.new()
		btn.text = tower_data.get_display_name() + "\n" + str(tower_data.build_cost) + "g"
		btn.custom_minimum_size = Vector2(64, 48)
		btn.pressed.connect(_on_tower_selected.bind(tower_data))
		button_container.add_child(btn)


func _on_tower_selected(tower_data: TowerData) -> void:
	if EconomyManager.can_afford(tower_data.build_cost):
		SignalBus.build_mode_entered.emit(tower_data)


func _on_build_mode_exited() -> void:
	# Deselect all buttons
	for btn in button_container.get_children():
		if btn is Button:
			btn.button_pressed = false


func _process(_delta: float) -> void:
	# Update affordability visual state
	for i in button_container.get_child_count():
		var btn := button_container.get_child(i) as Button
		if btn and i < tower_list.size():
			btn.disabled = not EconomyManager.can_afford(tower_list[i].build_cost)
