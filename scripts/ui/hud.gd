class_name HUD
extends CanvasLayer
## Compact HUD overlay — single info line at top, minimal footprint.

@onready var info_label: Label = $TopBar/InfoLabel
@onready var speed_label: Label = $TopBar/SpeedLabel

var _budget: int = 0
var _approval: int = 0
var _incident: int = 0
var _active_count: int = 0

var _wave_banner: Label
var _streak_label: Label
var _last_stand_label: Label
var _send_wave_btn: Button
var _wave_preview_label: Label
var _game_over_overlay: ColorRect
var _game_over_label: Label
var _restart_btn: Button

var _banner_tween: Tween
var _lives_pulse_tween: Tween

var _kill_counter_label: Label
var _selected_tower_ref: BaseTower

var _blackletter_font: Font


func _ready() -> void:
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")
	info_label.add_theme_font_size_override("font_size", 10)
	speed_label.add_theme_font_size_override("font_size", 10)

	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.lives_changed.connect(_on_lives_changed)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_completed.connect(_on_wave_completed)
	SignalBus.wave_enemies_remaining.connect(_on_enemies_remaining)
	SignalBus.game_speed_changed.connect(_on_speed_changed)
	SignalBus.game_over.connect(_on_game_over)
	SignalBus.streak_changed.connect(_on_streak_changed)
	SignalBus.last_stand_entered.connect(_on_last_stand_entered)
	SignalBus.streak_broken.connect(_on_streak_broken)
	SignalBus.tower_selected.connect(_on_tower_selected_hud)
	SignalBus.tower_deselected.connect(_on_tower_deselected_hud)
	SignalBus.enemy_killed.connect(_on_enemy_killed_hud)
	SignalBus.tower_kill_milestone.connect(_on_tower_kill_milestone)

	_create_engagement_ui()
	_refresh_info()


func _refresh_info() -> void:
	info_label.text = (
		"$" + str(_budget)
		+ "  " + str(_approval) + "%"
		+ "  INC " + str(_incident)
		+ "  " + str(_active_count) + " active"
	)


func _create_engagement_ui() -> void:
	# Wave banner (centered)
	_wave_banner = Label.new()
	_wave_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_banner.anchors_preset = Control.PRESET_CENTER
	_wave_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_wave_banner.add_theme_font_size_override("font_size", 16)
	_wave_banner.add_theme_color_override("font_color", Color("#A0D8A0"))
	if _blackletter_font:
		_wave_banner.add_theme_font_override("font", _blackletter_font)
	_wave_banner.modulate.a = 0.0
	_wave_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_banner)

	# Streak counter
	_streak_label = Label.new()
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.anchors_preset = Control.PRESET_CENTER_TOP
	_streak_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_streak_label.offset_top = 22.0
	_streak_label.add_theme_font_size_override("font_size", 9)
	_streak_label.add_theme_color_override("font_color", Color.WHITE)
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_streak_label)

	# Last stand
	_last_stand_label = Label.new()
	_last_stand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_stand_label.anchors_preset = Control.PRESET_CENTER_TOP
	_last_stand_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_last_stand_label.offset_top = 34.0
	_last_stand_label.add_theme_font_size_override("font_size", 10)
	_last_stand_label.add_theme_color_override("font_color", Color("#D04040"))
	if _blackletter_font:
		_last_stand_label.add_theme_font_override("font", _blackletter_font)
	_last_stand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_last_stand_label)

	# Speed buttons
	var speed_box := HBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 1)
	for pair: Array in [["1x", Enums.GameSpeed.NORMAL], ["2x", Enums.GameSpeed.FAST], ["3x", Enums.GameSpeed.ULTRA]]:
		var btn := Button.new()
		btn.text = pair[0]
		btn.custom_minimum_size = Vector2(22, 16)
		btn.pressed.connect(GameManager.set_speed.bind(pair[1]))
		speed_box.add_child(btn)
	$TopBar.add_child(speed_box)

	# Send wave button
	_send_wave_btn = Button.new()
	_send_wave_btn.text = "SEND WAVE"
	_send_wave_btn.custom_minimum_size = Vector2(80, 20)
	_send_wave_btn.anchors_preset = Control.PRESET_CENTER_BOTTOM
	_send_wave_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_send_wave_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_send_wave_btn.offset_top = -52.0
	_send_wave_btn.offset_bottom = -32.0
	_send_wave_btn.offset_left = -40.0
	_send_wave_btn.offset_right = 40.0
	_send_wave_btn.visible = false
	_send_wave_btn.pressed.connect(_on_send_wave_pressed)
	add_child(_send_wave_btn)

	# Wave preview (top right)
	_wave_preview_label = Label.new()
	_wave_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_preview_label.anchors_preset = Control.PRESET_TOP_RIGHT
	_wave_preview_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_wave_preview_label.offset_top = 20.0
	_wave_preview_label.offset_right = -4.0
	_wave_preview_label.offset_left = -160.0
	_wave_preview_label.add_theme_font_size_override("font_size", 8)
	_wave_preview_label.add_theme_color_override("font_color", Color("#808898"))
	_wave_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_preview_label)

	# Game over overlay
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
	_game_over_label.offset_top = -30.0
	_game_over_label.add_theme_font_size_override("font_size", 24)
	if _blackletter_font:
		_game_over_label.add_theme_font_override("font", _blackletter_font)
	_game_over_overlay.add_child(_game_over_label)

	_restart_btn = Button.new()
	_restart_btn.text = "RESTART"
	_restart_btn.custom_minimum_size = Vector2(100, 28)
	_restart_btn.anchors_preset = Control.PRESET_CENTER
	_restart_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_restart_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	_restart_btn.offset_top = 10.0
	_restart_btn.offset_bottom = 38.0
	_restart_btn.offset_left = -50.0
	_restart_btn.offset_right = 50.0
	_restart_btn.pressed.connect(_on_restart_pressed)
	_game_over_overlay.add_child(_restart_btn)

	# Kill counter
	_kill_counter_label = Label.new()
	_kill_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kill_counter_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	_kill_counter_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_kill_counter_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_kill_counter_label.offset_right = -4.0
	_kill_counter_label.offset_bottom = -32.0
	_kill_counter_label.offset_left = -120.0
	_kill_counter_label.add_theme_font_size_override("font_size", 8)
	_kill_counter_label.add_theme_color_override("font_color", Color("#A0D8A0"))
	_kill_counter_label.visible = false
	_kill_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kill_counter_label)


func _process(_delta: float) -> void:
	var timer := WaveManager.get_between_wave_timer()
	if timer > 0.0:
		_send_wave_btn.visible = true
		var bonus := WaveManager.get_call_wave_bonus()
		_send_wave_btn.text = "SEND WAVE" + (" +$" + str(bonus) if bonus > 0 else "")
	else:
		_send_wave_btn.visible = false


func _on_gold_changed(amount: int) -> void:
	_budget = amount
	_refresh_info()


func _on_lives_changed(amount: int) -> void:
	_approval = amount
	_refresh_info()


func _on_wave_started(wave_number: int) -> void:
	_incident = wave_number
	_refresh_info()
	_update_wave_preview()


func _on_wave_completed(wave_number: int) -> void:
	_show_wave_banner(wave_number)


func _on_enemies_remaining(count: int) -> void:
	_active_count = count
	_refresh_info()


func _on_speed_changed(speed: Enums.GameSpeed) -> void:
	match speed:
		Enums.GameSpeed.PAUSED:
			speed_label.text = "STANDBY"
		Enums.GameSpeed.NORMAL:
			speed_label.text = "1x"
		Enums.GameSpeed.FAST:
			speed_label.text = "2x"
		Enums.GameSpeed.ULTRA:
			speed_label.text = "3x"


func _on_game_over(victory: bool) -> void:
	if victory:
		_game_over_label.text = "ORDER RESTORED"
		_game_over_label.add_theme_color_override("font_color", Color("#A0D8A0"))
	else:
		_game_over_label.text = "REGIME CHANGE"
		_game_over_label.add_theme_color_override("font_color", Color("#D04040"))
	_game_over_overlay.visible = true
	_send_wave_btn.visible = false
	_kill_counter_label.visible = false
	_build_post_game_ui(victory)


# -- Engagement handlers --

func _show_wave_banner(wave_number: int) -> void:
	_wave_banner.text = "INCIDENT " + str(wave_number) + " CONTAINED"
	if WaveManager.perfect_streak > 0:
		_wave_banner.add_theme_color_override("font_color", Color("#D8A040"))
	else:
		_wave_banner.add_theme_color_override("font_color", Color("#A0D8A0"))
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_wave_banner.modulate.a = 0.0
	_banner_tween.tween_property(_wave_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(1.5)
	_banner_tween.tween_property(_wave_banner, "modulate:a", 0.0, 0.25)


func _on_streak_changed(count: int) -> void:
	if count <= 0:
		_streak_label.text = ""
		return
	_streak_label.text = "ZERO TOLERANCE: " + str(count)
	if count >= 5:
		_streak_label.add_theme_color_override("font_color", Color("#D8A040"))
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
	if _lives_pulse_tween:
		_lives_pulse_tween.kill()
	_lives_pulse_tween = create_tween().set_loops()
	_lives_pulse_tween.tween_property(info_label, "modulate", Color("#D04040"), 0.4)
	_lives_pulse_tween.tween_property(info_label, "modulate", Color.WHITE, 0.4)


func _on_send_wave_pressed() -> void:
	WaveManager.call_next_wave()


func _update_wave_preview() -> void:
	var preview := ""
	var idx := WaveManager.current_wave_index
	for offset in [1, 2]:
		var i: int = idx + offset
		if i >= WaveManager.waves.size():
			break
		var wave: WaveData = WaveManager.waves[i]
		preview += "Inc " + str(wave.wave_number) + ": "
		var counts: Dictionary = {}
		for seq in wave.spawn_sequences:
			if seq.enemy_data:
				var n := seq.enemy_data.get_display_name()
				counts[n] = counts.get(n, 0) + seq.count
		var parts: Array[String] = []
		for enemy_name in counts:
			parts.append(str(counts[enemy_name]) + "x " + enemy_name)
		preview += ", ".join(parts) + "\n"
	_wave_preview_label.text = preview.strip_edges()


func _on_restart_pressed() -> void:
	SignalBus.restart_requested.emit()


func _on_streak_broken(old_streak: int) -> void:
	if old_streak <= 0:
		return
	_streak_label.text = "ZERO TOLERANCE: BROKEN"
	_streak_label.add_theme_color_override("font_color", Color("#D04040"))
	var tween := create_tween()
	_streak_label.pivot_offset = _streak_label.size / 2.0
	tween.tween_property(_streak_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(_streak_label, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(1.0)
	tween.tween_property(_streak_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		_streak_label.text = ""
		_streak_label.modulate.a = 1.0
		_streak_label.scale = Vector2.ONE
	)


func _on_tower_selected_hud(tower: Node2D) -> void:
	if tower is BaseTower:
		_selected_tower_ref = tower
		_update_kill_counter()
		_kill_counter_label.visible = true


func _on_tower_deselected_hud() -> void:
	_selected_tower_ref = null
	_kill_counter_label.visible = false


func _on_enemy_killed_hud(_enemy: Node2D, _gold: int) -> void:
	if _selected_tower_ref and is_instance_valid(_selected_tower_ref):
		call_deferred("_update_kill_counter")


func _update_kill_counter() -> void:
	if not _selected_tower_ref or not is_instance_valid(_selected_tower_ref):
		return
	var count := _selected_tower_ref.kill_count
	var title := _get_kill_title(count)
	_kill_counter_label.text = str(count) + " dispersals"
	if title != "":
		_kill_counter_label.text += " [" + title + "]"


static func _get_kill_title(count: int) -> String:
	if count >= 1000: return "ABSOLUTE AUTHORITY"
	if count >= 500: return "SUPREME ENFORCER"
	if count >= 250: return "IRON FIST"
	if count >= 100: return "VETERAN OPERATIVE"
	if count >= 50: return "SEASONED AGENT"
	if count >= 25: return "FIRST COMMENDATION"
	return ""


func _on_tower_kill_milestone(tower: Node2D, kc: int) -> void:
	if not tower is BaseTower:
		return
	var tname: String = tower.tower_data.get_display_name() if tower.tower_data else "Unit"
	_wave_banner.text = tname + ": " + _get_kill_title(kc)
	_wave_banner.add_theme_color_override("font_color", Color("#D8A040"))
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_wave_banner.modulate.a = 0.0
	_banner_tween.tween_property(_wave_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(1.5)
	_banner_tween.tween_property(_wave_banner, "modulate:a", 0.0, 0.3)


func _build_post_game_ui(victory: bool) -> void:
	var game_node := get_tree().current_scene
	if not "_stats" in game_node:
		return
	var stats: Dictionary = game_node._stats

	var stats_label := Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.anchors_preset = Control.PRESET_CENTER
	stats_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stats_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	stats_label.offset_top = 50.0
	stats_label.add_theme_font_size_override("font_size", 8)
	stats_label.add_theme_color_override("font_color", Color("#A0A8B0"))

	var secs: int = int(stats.get("time_played", 0.0))
	var text := "Waves: " + str(stats.get("waves_survived", 0))
	text += " | Kills: " + str(stats.get("total_kills", 0))
	text += " | DMG: " + str(int(stats.get("total_damage", 0.0)))
	text += " | Peak DPS: " + str(int(stats.get("peak_dps", 0.0)))
	text += "\nStreak: " + str(stats.get("zero_tolerance_waves", 0))
	text += " | " + str(secs / 60) + "m" + str(secs % 60) + "s"

	var max_kills := 0
	var mvp_name := ""
	for tower in game_node.tower_container.get_children():
		if tower is BaseTower and tower.kill_count > max_kills:
			max_kills = tower.kill_count
			mvp_name = tower.tower_data.get_display_name() if tower.tower_data else "Unknown"
	if mvp_name != "":
		text += " | MVP: " + mvp_name + " (" + str(max_kills) + ")"

	stats_label.text = text
	_game_over_overlay.add_child(stats_label)

	if not victory:
		var leaking: Array = stats.get("leaking_enemies", [])
		if not leaking.is_empty():
			var last: Dictionary = leaking[leaking.size() - 1]
			var hp: int = int(last.get("remaining_hp", 0.0))
			var ename: String = last.get("name", "agitator")
			var what_if := Label.new()
			what_if.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			what_if.anchors_preset = Control.PRESET_CENTER
			what_if.grow_horizontal = Control.GROW_DIRECTION_BOTH
			what_if.offset_top = 80.0
			what_if.add_theme_font_size_override("font_size", 9)
			what_if.add_theme_color_override("font_color", Color("#D8A040"))
			what_if.text = "Last " + ename + " escaped with " + str(hp) + " HP"
			_game_over_overlay.add_child(what_if)
