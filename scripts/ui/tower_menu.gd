class_name TowerMenu
extends PanelContainer
## Compact tower build menu — simple row of buttons.

@export var tower_list: Array[TowerData] = []

@onready var button_container: HBoxContainer = $HBox


func _ready() -> void:
	_build_buttons()
	SignalBus.build_mode_exited.connect(_on_build_mode_exited)


func _build_buttons() -> void:
	for child in button_container.get_children():
		child.queue_free()

	for tower_data in tower_list:
		var btn := Button.new()
		btn.text = tower_data.get_display_name() + " $" + str(tower_data.build_cost)
		btn.custom_minimum_size = Vector2(0, 22)
		btn.pressed.connect(_on_tower_selected.bind(tower_data))
		button_container.add_child(btn)


func _on_tower_selected(tower_data: TowerData) -> void:
	if EconomyManager.can_afford(tower_data.build_cost):
		SignalBus.build_mode_entered.emit(tower_data)


func _on_build_mode_exited() -> void:
	for btn in button_container.get_children():
		if btn is Button:
			btn.button_pressed = false


func _process(_delta: float) -> void:
	for i in button_container.get_child_count():
		if i >= tower_list.size():
			break
		var btn := button_container.get_child(i) as Button
		if btn:
			btn.disabled = not EconomyManager.can_afford(tower_list[i].build_cost)
