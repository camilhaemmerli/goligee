class_name TowerMenu
extends PanelContainer
## Compact tower build menu — simple row of buttons.

@export var tower_list: Array[TowerData] = []

@onready var button_container: HBoxContainer = $HBox

# Short labels for the build menu (keyed by tower_name).
const SHORT_NAMES := {
	"Rubber Bullet Turret": "RBT",
	"Water Cannon": "WAT",
	"Tear Gas Launcher": "GAS",
	"LRAD Cannon": "LRAD",
	"Taser Grid": "TASR",
	"Pepper Spray Emitter": "PEPR",
	"Microwave Emitter": "MWAV",
	"Surveillance Hub": "SURV",
}


func _ready() -> void:
	_build_buttons()
	SignalBus.build_mode_exited.connect(_on_build_mode_exited)


func _build_buttons() -> void:
	for child in button_container.get_children():
		child.queue_free()

	for tower_data in tower_list:
		var btn := Button.new()
		var short: String = SHORT_NAMES.get(tower_data.tower_name, tower_data.tower_name)
		btn.text = short + " $" + str(tower_data.build_cost)
		btn.add_theme_font_size_override("font_size", 8)
		btn.custom_minimum_size = Vector2(0, 18)
		btn.pressed.connect(_on_tower_selected.bind(tower_data))
		btn.tooltip_text = tower_data.get_display_name()
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
