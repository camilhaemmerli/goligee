class_name HUD
extends CanvasLayer
## Top-level HUD showing budget, approval, incident counter, game speed, and engagement UI.

@onready var gold_label: Label = $TopBar/GoldLabel
@onready var lives_label: Label = $TopBar/LivesLabel
@onready var wave_label: Label = $TopBar/WaveLabel
@onready var speed_label: Label = $TopBar/SpeedLabel
@onready var enemies_label: Label = $TopBar/EnemiesLabel

# Engagement UI elements (created in code)
var _wave_banner: Label
var _streak_label: Label
var _last_stand_label: Label
var _send_wave_btn: Button
var _speed_1x_btn: Button
var _speed_2x_btn: Button
var _speed_3x_btn: Button
var _wave_preview_label: Label
var _game_over_overlay: ColorRect
var _game_over_label: Label
var _restart_btn: Button

var _banner_tween: Tween
var _lives_pulse_tween: Tween

var _blackletter_font: Font


func _ready() -> void:
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")
	if _blackletter_font:
		wave_label.add_theme_font_override("font", _blackletter_font)
	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.lives_changed.connect(_on_lives_changed)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_completed.connect(_on_wave_completed)
	SignalBus.wave_enemies_remaining.connect(_on_enemies_remaining)
	SignalBus.game_speed_changed.connect(_on_speed_changed)
	SignalBus.game_over.connect(_on_game_over)
	SignalBus.streak_changed.connect(_on_streak_changed)
	SignalBus.last_stand_entered.connect(_on_last_stand_entered)

	_create_engagement_ui()


func _create_engagement_ui() -> void:
	# Wave complete banner (centered)
	_wave_banner = Label.new()
	_wave_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_banner.anchors_preset = Control.PRESET_CENTER
	_wave_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_wave_banner.add_theme_font_size_override("font_size", 20)
	_wave_banner.add_theme_color_override("font_color", Color("#A0D8A0"))
	if _blackletter_font:
		_wave_banner.add_theme_font_override("font", _blackletter_font)
	_wave_banner.modulate.a = 0.0
	_wave_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_banner)

	# Streak counter (below wave label area)
	_streak_label = Label.new()
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.anchors_preset = Control.PRESET_CENTER_TOP
	_streak_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_streak_label.offset_top = 28.0
	_streak_label.add_theme_font_size_override("font_size", 11)
	_streak_label.add_theme_color_override("font_color", Color.WHITE)
	_streak_label.text = ""
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_streak_label)

	# Last Stand indicator
	_last_stand_label = Label.new()
	_last_stand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_stand_label.anchors_preset = Control.PRESET_CENTER_TOP
	_last_stand_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_last_stand_label.offset_top = 44.0
	_last_stand_label.add_theme_font_size_override("font_size", 12)
	_last_stand_label.add_theme_color_override("font_color", Color("#D04040"))
	if _blackletter_font:
		_last_stand_label.add_theme_font_override("font", _blackletter_font)
	_last_stand_label.text = ""
	_last_stand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_last_stand_label)

	# Speed control buttons (added to top bar)
	var speed_container := HBoxContainer.new()
	speed_container.add_theme_constant_override("separation", 2)

	_speed_1x_btn = Button.new()
	_speed_1x_btn.text = "STD"
	_speed_1x_btn.custom_minimum_size = Vector2(28, 20)
	_speed_1x_btn.pressed.connect(func(): GameManager.set_speed(Enums.GameSpeed.NORMAL))
	speed_container.add_child(_speed_1x_btn)

	_speed_2x_btn = Button.new()
	_speed_2x_btn.text = "RPD"
	_speed_2x_btn.custom_minimum_size = Vector2(28, 20)
	_speed_2x_btn.pressed.connect(func(): GameManager.set_speed(Enums.GameSpeed.FAST))
	speed_container.add_child(_speed_2x_btn)

	_speed_3x_btn = Button.new()
	_speed_3x_btn.text = "EMG"
	_speed_3x_btn.custom_minimum_size = Vector2(28, 20)
	_speed_3x_btn.pressed.connect(func(): GameManager.set_speed(Enums.GameSpeed.ULTRA))
	speed_container.add_child(_speed_3x_btn)

	$TopBar.add_child(speed_container)

	# Send Wave button (bottom center, above tower menu)
	_send_wave_btn = Button.new()
	_send_wave_btn.text = "RELEASE AGITATORS"
	_send_wave_btn.custom_minimum_size = Vector2(140, 28)
	_send_wave_btn.anchors_preset = Control.PRESET_CENTER_BOTTOM
	_send_wave_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_send_wave_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_send_wave_btn.offset_top = -96.0
	_send_wave_btn.offset_bottom = -68.0
	_send_wave_btn.offset_left = -50.0
	_send_wave_btn.offset_right = 50.0
	_send_wave_btn.visible = false
	_send_wave_btn.pressed.connect(_on_send_wave_pressed)
	add_child(_send_wave_btn)

	# Wave preview (top right area)
	_wave_preview_label = Label.new()
	_wave_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_preview_label.anchors_preset = Control.PRESET_TOP_RIGHT
	_wave_preview_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_wave_preview_label.offset_top = 28.0
	_wave_preview_label.offset_right = -8.0
	_wave_preview_label.offset_left = -200.0
	_wave_preview_label.add_theme_font_size_override("font_size", 9)
	_wave_preview_label.add_theme_color_override("font_color", Color("#808898"))
	_wave_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_preview_label)

	# Game over overlay (hidden until game ends)
	_game_over_overlay = ColorRect.new()
	_game_over_overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	_game_over_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over_overlay.visible = false
	add_child(_game_over_overlay)

	_game_over_label = Label.new()
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.anchors_preset = Control.PRESET_CENTER
	_game_over_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_game_over_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_game_over_label.offset_top = -40.0
	_game_over_label.add_theme_font_size_override("font_size", 28)
	if _blackletter_font:
		_game_over_label.add_theme_font_override("font", _blackletter_font)
	_game_over_overlay.add_child(_game_over_label)

	_restart_btn = Button.new()
	_restart_btn.text = "REASSERT CONTROL"
	_restart_btn.custom_minimum_size = Vector2(160, 36)
	_restart_btn.anchors_preset = Control.PRESET_CENTER
	_restart_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_restart_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	_restart_btn.offset_top = 20.0
	_restart_btn.offset_bottom = 56.0
	_restart_btn.offset_left = -80.0
	_restart_btn.offset_right = 80.0
	_restart_btn.pressed.connect(_on_restart_pressed)
	_game_over_overlay.add_child(_restart_btn)


func _process(_delta: float) -> void:
	# Update send wave button visibility and text
	var timer := WaveManager.get_between_wave_timer()
	if timer > 0.0:
		_send_wave_btn.visible = true
		var bonus := WaveManager.get_call_wave_bonus()
		if bonus > 0:
			_send_wave_btn.text = "RELEASE AGITATORS (+" + str(bonus) + " budget)"
		else:
			_send_wave_btn.text = "RELEASE AGITATORS"
	else:
		_send_wave_btn.visible = false


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "BUDGET: " + str(amount)


func _on_lives_changed(amount: int) -> void:
	lives_label.text = "APPROVAL: " + str(amount) + "%"


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "INCIDENT " + str(wave_number)
	_update_wave_preview()


func _on_wave_completed(wave_number: int) -> void:
	_show_wave_banner(wave_number)


func _on_enemies_remaining(count: int) -> void:
	enemies_label.text = str(count) + " AGITATORS ACTIVE"


func _on_speed_changed(speed: Enums.GameSpeed) -> void:
	match speed:
		Enums.GameSpeed.PAUSED:
			speed_label.text = "STANDBY"
		Enums.GameSpeed.NORMAL:
			speed_label.text = "STANDARD"
		Enums.GameSpeed.FAST:
			speed_label.text = "RAPID"
		Enums.GameSpeed.ULTRA:
			speed_label.text = "EMERGENCY"


func _on_game_over(victory: bool) -> void:
	if victory:
		wave_label.text = "ORDER RESTORED"
		_game_over_label.text = "ORDER RESTORED"
		_game_over_label.add_theme_color_override("font_color", Color("#A0D8A0"))
	else:
		wave_label.text = "REGIME CHANGE"
		_game_over_label.text = "REGIME CHANGE"
		_game_over_label.add_theme_color_override("font_color", Color("#D04040"))
	_game_over_overlay.visible = true
	_send_wave_btn.visible = false


# -- Engagement UI handlers --

func _show_wave_banner(wave_number: int) -> void:
	_wave_banner.text = "INCIDENT " + str(wave_number) + " CONTAINED"

	# Amber tint if on a streak
	if WaveManager.perfect_streak > 0:
		_wave_banner.add_theme_color_override("font_color", Color("#D8A040"))
	else:
		_wave_banner.add_theme_color_override("font_color", Color("#A0D8A0"))

	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_wave_banner.modulate.a = 0.0
	_wave_banner.position.y = 10.0
	_banner_tween.tween_property(_wave_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_property(_wave_banner, "position:y", 0.0, 0.3).set_parallel()
	_banner_tween.tween_interval(2.0)
	_banner_tween.tween_property(_wave_banner, "modulate:a", 0.0, 0.3)


func _on_streak_changed(count: int) -> void:
	if count <= 0:
		_streak_label.text = ""
		return

	_streak_label.text = "ZERO TOLERANCE: " + str(count)

	# Escalating color
	if count >= 5:
		_streak_label.add_theme_color_override("font_color", Color("#D8A040"))
		# Pulsing effect
		var tween := create_tween().set_loops()
		tween.tween_property(_streak_label, "modulate:a", 0.5, 0.5)
		tween.tween_property(_streak_label, "modulate:a", 1.0, 0.5)
	elif count >= 3:
		_streak_label.add_theme_color_override("font_color", Color("#D8A040"))
		_streak_label.modulate.a = 1.0
	else:
		_streak_label.add_theme_color_override("font_color", Color.WHITE)
		_streak_label.modulate.a = 1.0


func _on_last_stand_entered() -> void:
	_last_stand_label.text = "MARTIAL LAW"

	# Pulse the lives label red
	if _lives_pulse_tween:
		_lives_pulse_tween.kill()
	_lives_pulse_tween = create_tween().set_loops()
	_lives_pulse_tween.tween_property(lives_label, "modulate", Color("#D04040"), 0.4)
	_lives_pulse_tween.tween_property(lives_label, "modulate", Color.WHITE, 0.4)


func _on_send_wave_pressed() -> void:
	WaveManager.call_next_wave()


func _update_wave_preview() -> void:
	var preview_text := ""
	var current_idx := WaveManager.current_wave_index
	for offset: int in [1, 2]:
		var idx: int = current_idx + offset
		if idx >= WaveManager.waves.size():
			break
		var wave: WaveData = WaveManager.waves[idx]
		preview_text += "Incident " + str(wave.wave_number) + ": "
		var enemy_counts: Dictionary = {}
		for seq in wave.spawn_sequences:
			if seq.enemy_data:
				var name_key := seq.enemy_data.get_display_name()
				enemy_counts[name_key] = enemy_counts.get(name_key, 0) + seq.count
		var parts: Array[String] = []
		for enemy_name in enemy_counts:
			parts.append(str(enemy_counts[enemy_name]) + "x " + enemy_name)
		preview_text += ", ".join(parts) + "\n"

	_wave_preview_label.text = preview_text.strip_edges()


func _on_restart_pressed() -> void:
	SignalBus.restart_requested.emit()
