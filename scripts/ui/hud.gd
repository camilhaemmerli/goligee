class_name HUD
extends CanvasLayer
## Top-level HUD showing gold, lives, wave counter, game speed, and engagement UI.

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

var _banner_tween: Tween
var _lives_pulse_tween: Tween


func _ready() -> void:
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
	_wave_banner.add_theme_color_override("font_color", Color("#E0D0D8"))
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
	_last_stand_label.add_theme_color_override("font_color", Color("#D06070"))
	_last_stand_label.text = ""
	_last_stand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_last_stand_label)

	# Speed control buttons (added to top bar)
	var speed_container := HBoxContainer.new()
	speed_container.add_theme_constant_override("separation", 2)

	_speed_1x_btn = Button.new()
	_speed_1x_btn.text = "1x"
	_speed_1x_btn.custom_minimum_size = Vector2(28, 20)
	_speed_1x_btn.pressed.connect(func(): GameManager.set_speed(Enums.GameSpeed.NORMAL))
	speed_container.add_child(_speed_1x_btn)

	_speed_2x_btn = Button.new()
	_speed_2x_btn.text = "2x"
	_speed_2x_btn.custom_minimum_size = Vector2(28, 20)
	_speed_2x_btn.pressed.connect(func(): GameManager.set_speed(Enums.GameSpeed.FAST))
	speed_container.add_child(_speed_2x_btn)

	_speed_3x_btn = Button.new()
	_speed_3x_btn.text = "3x"
	_speed_3x_btn.custom_minimum_size = Vector2(28, 20)
	_speed_3x_btn.pressed.connect(func(): GameManager.set_speed(Enums.GameSpeed.ULTRA))
	speed_container.add_child(_speed_3x_btn)

	$TopBar.add_child(speed_container)

	# Send Wave button (bottom center, above tower menu)
	_send_wave_btn = Button.new()
	_send_wave_btn.text = "Send Wave"
	_send_wave_btn.custom_minimum_size = Vector2(100, 28)
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
	_wave_preview_label.add_theme_color_override("font_color", Color("#9090B0"))
	_wave_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_preview_label)


func _process(_delta: float) -> void:
	# Update send wave button visibility and text
	var timer := WaveManager.get_between_wave_timer()
	if timer > 0.0:
		_send_wave_btn.visible = true
		var bonus := WaveManager.get_call_wave_bonus()
		if bonus > 0:
			_send_wave_btn.text = "Send Wave (+" + str(bonus) + "g)"
		else:
			_send_wave_btn.text = "Send Wave"
	else:
		_send_wave_btn.visible = false


func _on_gold_changed(amount: int) -> void:
	gold_label.text = str(amount)


func _on_lives_changed(amount: int) -> void:
	lives_label.text = str(amount)


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Wave " + str(wave_number)
	_update_wave_preview()


func _on_wave_completed(wave_number: int) -> void:
	_show_wave_banner(wave_number)


func _on_enemies_remaining(count: int) -> void:
	enemies_label.text = str(count) + " remaining"


func _on_speed_changed(speed: Enums.GameSpeed) -> void:
	match speed:
		Enums.GameSpeed.PAUSED:
			speed_label.text = "PAUSED"
		Enums.GameSpeed.NORMAL:
			speed_label.text = "1x"
		Enums.GameSpeed.FAST:
			speed_label.text = "2x"
		Enums.GameSpeed.ULTRA:
			speed_label.text = "3x"


func _on_game_over(victory: bool) -> void:
	if victory:
		wave_label.text = "VICTORY"
	else:
		wave_label.text = "DEFEAT"


# -- Engagement UI handlers --

func _show_wave_banner(wave_number: int) -> void:
	_wave_banner.text = "Wave " + str(wave_number) + " Complete!"

	# Golden tint if on a streak
	if WaveManager.perfect_streak > 0:
		_wave_banner.add_theme_color_override("font_color", Color("#E0C060"))
	else:
		_wave_banner.add_theme_color_override("font_color", Color("#E0D0D8"))

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

	_streak_label.text = "Perfect Streak: " + str(count)

	# Escalating color
	if count >= 5:
		_streak_label.add_theme_color_override("font_color", Color("#E0C060"))
		# Pulsing effect
		var tween := create_tween().set_loops()
		tween.tween_property(_streak_label, "modulate:a", 0.5, 0.5)
		tween.tween_property(_streak_label, "modulate:a", 1.0, 0.5)
	elif count >= 3:
		_streak_label.add_theme_color_override("font_color", Color("#E0C060"))
		_streak_label.modulate.a = 1.0
	else:
		_streak_label.add_theme_color_override("font_color", Color.WHITE)
		_streak_label.modulate.a = 1.0


func _on_last_stand_entered() -> void:
	_last_stand_label.text = "LAST STAND"

	# Pulse the lives label red
	if _lives_pulse_tween:
		_lives_pulse_tween.kill()
	_lives_pulse_tween = create_tween().set_loops()
	_lives_pulse_tween.tween_property(lives_label, "modulate", Color("#D06070"), 0.4)
	_lives_pulse_tween.tween_property(lives_label, "modulate", Color.WHITE, 0.4)


func _on_send_wave_pressed() -> void:
	WaveManager.call_next_wave()


func _update_wave_preview() -> void:
	var preview_text := ""
	var current_idx := WaveManager.current_wave_index
	for offset in [1, 2]:
		var idx := current_idx + offset
		if idx >= WaveManager.waves.size():
			break
		var wave: WaveData = WaveManager.waves[idx]
		preview_text += "Wave " + str(wave.wave_number) + ": "
		var enemy_counts := {}
		for seq in wave.spawn_sequences:
			if seq.enemy_data:
				var name_key := seq.enemy_data.get_display_name()
				enemy_counts[name_key] = enemy_counts.get(name_key, 0) + seq.count
		var parts: Array[String] = []
		for enemy_name in enemy_counts:
			parts.append(str(enemy_counts[enemy_name]) + "x " + enemy_name)
		preview_text += ", ".join(parts) + "\n"

	_wave_preview_label.text = preview_text.strip_edges()
