class_name TowerMenu
extends PanelContainer
## Tower build menu. Shows available towers with affordability indicators.

@export var tower_list: Array[TowerData] = []

@onready var button_container: HBoxContainer = $MarginContainer/HBoxContainer

# Parallel arrays for rich button UI elements
var _indicator_labels: Array[Label] = []
var _progress_bars: Array[ColorRect] = []
var _card_backgrounds: Array[ColorRect] = []


func _ready() -> void:
	_build_buttons()
	SignalBus.build_mode_exited.connect(_on_build_mode_exited)


func _build_buttons() -> void:
	for child in button_container.get_children():
		child.queue_free()

	_indicator_labels.clear()
	_progress_bars.clear()
	_card_backgrounds.clear()

	for tower_data in tower_list:
		# Card container
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(56, 64)

		# Main button
		var btn := Button.new()
		btn.text = tower_data.get_display_name() + "\n" + str(tower_data.build_cost) + "g"
		btn.custom_minimum_size = Vector2(56, 40)
		btn.pressed.connect(_on_tower_selected.bind(tower_data))
		card.add_child(btn)

		# Progress bar background (shows affordability %)
		var progress_bg := ColorRect.new()
		progress_bg.custom_minimum_size = Vector2(56, 4)
		progress_bg.color = Color("#1A1A1E")
		card.add_child(progress_bg)

		var progress_fill := ColorRect.new()
		progress_fill.custom_minimum_size = Vector2(0, 4)
		progress_fill.color = Color("#D8A040")
		progress_fill.size = Vector2(0, 4)
		progress_bg.add_child(progress_fill)

		# Indicator label (gold needed / waves estimate)
		var indicator := Label.new()
		indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		indicator.add_theme_font_size_override("font_size", 8)
		indicator.add_theme_color_override("font_color", Color("#808898"))
		indicator.custom_minimum_size = Vector2(56, 12)
		card.add_child(indicator)

		button_container.add_child(card)
		_indicator_labels.append(indicator)
		_progress_bars.append(progress_fill)
		_card_backgrounds.append(progress_bg)


func _on_tower_selected(tower_data: TowerData) -> void:
	if EconomyManager.can_afford(tower_data.build_cost):
		SignalBus.build_mode_entered.emit(tower_data)


func _on_build_mode_exited() -> void:
	# Deselect all buttons
	for card in button_container.get_children():
		var btn := card.get_child(0) as Button
		if btn:
			btn.button_pressed = false


func _process(_delta: float) -> void:
	var avg_income := EconomyManager.get_avg_gold_per_wave()

	for i in button_container.get_child_count():
		if i >= tower_list.size():
			break
		var card := button_container.get_child(i)
		var btn := card.get_child(0) as Button
		if not btn:
			continue

		var cost := tower_list[i].build_cost
		var affordable := EconomyManager.can_afford(cost)
		btn.disabled = not affordable

		if i >= _indicator_labels.size():
			continue

		var indicator := _indicator_labels[i]
		var progress_fill := _progress_bars[i]
		var progress_bg := _card_backgrounds[i]

		if affordable:
			indicator.text = ""
			progress_fill.custom_minimum_size.x = progress_bg.size.x
		else:
			var gold_needed := cost - EconomyManager.gold
			var ratio := clampf(float(EconomyManager.gold) / float(cost), 0.0, 1.0)
			progress_fill.custom_minimum_size.x = progress_bg.size.x * ratio

			if avg_income > 0.0:
				var waves_needed := ceili(float(gold_needed) / avg_income)
				indicator.text = "DEFICIT: " + str(gold_needed) + " (~" + str(waves_needed) + " inc.)"
			else:
				indicator.text = "DEFICIT: " + str(gold_needed)
