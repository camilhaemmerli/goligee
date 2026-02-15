class_name HUD
extends CanvasLayer
## Brutalist-themed HUD overlay — budget, approval bar, wave circle, tower cards.

var _budget: int = 0
var _approval: int = 0
var _max_approval: int = 20
var _incident: int = 0
var _active_count: int = 0

# Budget display (top-left)
var _budget_container: Control
var _budget_value_label: Label
var _budget_change_label: Label
var _budget_tween: Tween

# Approval bar (bottom-right)
var _approval_container: Control
var _approval_bar_bg: ColorRect
var _approval_bar_fill: ColorRect
var _approval_label: Label
var _approval_tween: Tween

# Wave circle (top-right)
var _wave_circle_container: Control
var _wave_number_label: Label
var _wave_name_label: Label
var _wave_circle_tex: TextureRect
var _wave_progress_ring: Control  # custom draw arc

# Wave progress tracking
var _wave_total: int = 0
var _wave_gone: int = 0

# Speed toggle (single button, cycles 1x→2x→3x)
var _speed_btn: Button
var _current_speed_idx: int = 0
var _speed_pulse_tween: Tween

# Center banners
var _wave_banner: Label
var _streak_label: Label
var _last_stand_label: Label

# Bottom
var _send_wave_btn: Button
var _cancel_build_btn: Button

# Game over
var _game_over_overlay: ColorRect
var _game_over_label: Label
var _restart_btn: Button

# Kill counter (bottom-right, above upgrade panel)
var _kill_counter_label: Label
var _selected_tower_ref: BaseTower

var _banner_tween: Tween
var _lives_pulse_tween: Tween
var _blackletter_font: Font
var _current_manifestation_leader: String = ""
var _manifestation_name_label: Label

# Colors
const COL_PANEL_BG := Color("#1A1A1E")
const COL_PANEL_BORDER := Color("#121216")
const COL_CARD_BORDER := Color("#28282C")
const COL_MUTED := Color("#808898")
const COL_GOLD := Color("#F2D864")
const COL_RUST := Color("#A23813")
const COL_AMBER := Color("#D8A040")
const COL_GREEN := Color("#A0D8A0")
const COL_RED := Color("#D04040")
const COL_PILL_BG := Color("#08080A")
const COL_CIRCLE_BG := Color("#D8CFC0")  # light beige

# Approval bar colors
const COL_APPROVAL_FULL := Color("#A0D8A0")
const COL_APPROVAL_LOW := Color("#D04040")
const COL_BAR_BG := Color("#1E1E22")

const APPROVAL_BAR_W := 140.0
const APPROVAL_BAR_H := 12.0


func _ready() -> void:
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")

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
	SignalBus.enemy_reached_end.connect(_on_enemy_leaked_hud)
	SignalBus.build_mode_entered.connect(_on_build_mode_entered_hud)
	SignalBus.build_mode_exited.connect(_on_build_mode_exited_hud)

	_create_budget_display()
	_create_approval_bar()
	_create_wave_circle()
	_create_speed_controls()
	_create_center_banners()
	_create_send_wave_btn()
	_create_game_over_overlay()
	_create_kill_counter()
	_create_cancel_build_btn()


# ---------------------------------------------------------------------------
# Budget display (top-left)
# ---------------------------------------------------------------------------

func _create_budget_display() -> void:
	_budget_container = Control.new()
	_budget_container.position = Vector2(8, 4)
	_budget_container.custom_minimum_size = Vector2(160, 44)
	_budget_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_budget_container)

	var header := Label.new()
	header.text = "TAXPAYER BUDGET"
	header.add_theme_font_size_override("font_size", 9)
	header.add_theme_color_override("font_color", Color.WHITE)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_budget_container.add_child(header)

	_budget_value_label = Label.new()
	_budget_value_label.text = "$0"
	_budget_value_label.position = Vector2(0, 12)
	_budget_value_label.add_theme_font_size_override("font_size", 28)
	_budget_value_label.add_theme_color_override("font_color", Color.WHITE)
	if _blackletter_font:
		_budget_value_label.add_theme_font_override("font", _blackletter_font)
	_budget_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_budget_container.add_child(_budget_value_label)

	# Floating change label
	_budget_change_label = Label.new()
	_budget_change_label.position = Vector2(8, 58)
	_budget_change_label.add_theme_font_size_override("font_size", 10)
	_budget_change_label.modulate.a = 0.0
	_budget_change_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_budget_change_label)


# ---------------------------------------------------------------------------
# Approval bar (bottom-right)
# ---------------------------------------------------------------------------

func _create_approval_bar() -> void:
	_approval_container = Control.new()
	_approval_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_approval_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_approval_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_approval_container.offset_right = -8.0
	_approval_container.offset_bottom = -36.0
	_approval_container.offset_left = -8.0 - APPROVAL_BAR_W - 4.0
	_approval_container.offset_top = -36.0 - 28.0
	_approval_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_approval_container)

	var header := Label.new()
	header.text = "APPROVAL RATING"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_theme_font_size_override("font_size", 6)
	header.add_theme_color_override("font_color", COL_MUTED)
	header.position = Vector2(0, 0)
	header.size = Vector2(APPROVAL_BAR_W + 4, 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_approval_container.add_child(header)

	# Bar background with border
	var bar_border := ColorRect.new()
	bar_border.color = COL_PANEL_BORDER
	bar_border.position = Vector2(0, 11)
	bar_border.size = Vector2(APPROVAL_BAR_W + 4, APPROVAL_BAR_H + 4)
	bar_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_approval_container.add_child(bar_border)

	_approval_bar_bg = ColorRect.new()
	_approval_bar_bg.color = COL_BAR_BG
	_approval_bar_bg.position = Vector2(2, 13)
	_approval_bar_bg.size = Vector2(APPROVAL_BAR_W, APPROVAL_BAR_H)
	_approval_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_approval_container.add_child(_approval_bar_bg)

	_approval_bar_fill = ColorRect.new()
	_approval_bar_fill.color = COL_APPROVAL_FULL
	_approval_bar_fill.position = Vector2(2, 13)
	_approval_bar_fill.size = Vector2(APPROVAL_BAR_W, APPROVAL_BAR_H)
	_approval_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_approval_container.add_child(_approval_bar_fill)

	_approval_label = Label.new()
	_approval_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_approval_label.position = Vector2(2, 12)
	_approval_label.size = Vector2(APPROVAL_BAR_W, APPROVAL_BAR_H + 2)
	_approval_label.add_theme_font_size_override("font_size", 8)
	_approval_label.add_theme_color_override("font_color", Color.WHITE)
	_approval_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_approval_container.add_child(_approval_label)


# ---------------------------------------------------------------------------
# Wave circle (top-right)
# ---------------------------------------------------------------------------

func _create_wave_circle() -> void:
	# 60px circle, inset from top-right corner
	const CIRCLE_SIZE := 60
	const CIRCLE_HALF := CIRCLE_SIZE / 2

	_wave_circle_container = Control.new()
	_wave_circle_container.position = Vector2(876, 10)
	_wave_circle_container.custom_minimum_size = Vector2(CIRCLE_SIZE + 8, CIRCLE_SIZE + 28)
	_wave_circle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_circle_container)

	# Progress ring (drawn behind circle, slightly larger)
	_wave_progress_ring = Control.new()
	_wave_progress_ring.position = Vector2(16, 0)
	_wave_progress_ring.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	_wave_progress_ring.size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	_wave_progress_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_progress_ring.draw.connect(_draw_progress_ring)
	_wave_circle_container.add_child(_wave_progress_ring)

	# Circle background — starts as fallback rust, replaced by portrait on first wave
	_wave_circle_tex = TextureRect.new()
	_wave_circle_tex.texture = _make_fallback_circle()
	_wave_circle_tex.position = Vector2(16, 0)
	_wave_circle_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wave_circle_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_circle_container.add_child(_wave_circle_tex)

	# Wave number centered in circle
	_wave_number_label = Label.new()
	_wave_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_number_label.position = Vector2(16, 0)
	_wave_number_label.size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	_wave_number_label.add_theme_font_size_override("font_size", 20)
	_wave_number_label.add_theme_color_override("font_color", Color.WHITE)
	if _blackletter_font:
		_wave_number_label.add_theme_font_override("font", _blackletter_font)
	_wave_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_circle_container.add_child(_wave_number_label)

	# Manifestation name below circle (right-aligned to circle right edge)
	_manifestation_name_label = Label.new()
	_manifestation_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_manifestation_name_label.position = Vector2(-60, CIRCLE_SIZE + 2)
	_manifestation_name_label.size = Vector2(136, 10)
	_manifestation_name_label.add_theme_font_size_override("font_size", 6)
	_manifestation_name_label.add_theme_color_override("font_color", COL_MUTED)
	_manifestation_name_label.clip_text = true
	_manifestation_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_circle_container.add_child(_manifestation_name_label)

	# Wave name below manifestation name
	_wave_name_label = Label.new()
	_wave_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_name_label.position = Vector2(-60, CIRCLE_SIZE + 12)
	_wave_name_label.size = Vector2(136, 12)
	_wave_name_label.add_theme_font_size_override("font_size", 7)
	_wave_name_label.add_theme_color_override("font_color", COL_AMBER)
	_wave_name_label.clip_text = true
	_wave_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_circle_container.add_child(_wave_name_label)


# ---------------------------------------------------------------------------
# Speed toggle (single cycling button, top-right below circle)
# ---------------------------------------------------------------------------

const _SPEED_LABELS := ["1x", "2x", "3x"]
const _SPEED_VALUES: Array[int] = [0, 1, 2]  # Enums.GameSpeed indices

func _create_speed_controls() -> void:
	_speed_btn = Button.new()
	_speed_btn.text = "1x"
	_speed_btn.custom_minimum_size = Vector2(40, 22)
	_speed_btn.position = Vector2(920, 88)
	_speed_btn.pressed.connect(_on_speed_toggle_pressed)

	_apply_speed_btn_style()

	_speed_btn.add_theme_font_size_override("font_size", 11)
	_speed_btn.add_theme_color_override("font_color", Color.WHITE)
	if _blackletter_font:
		_speed_btn.add_theme_font_override("font", _blackletter_font)
	add_child(_speed_btn)

	# Start pulsating
	_start_speed_pulse()


func _apply_speed_btn_style() -> void:
	for state_name in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = COL_RUST if state_name != "hover" else Color("#C04820")
		sb.border_color = Color("#1A1A1E")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		_speed_btn.add_theme_stylebox_override(state_name, sb)


func _start_speed_pulse() -> void:
	if _speed_pulse_tween:
		_speed_pulse_tween.kill()
	_speed_pulse_tween = create_tween().set_loops()
	_speed_pulse_tween.tween_property(_speed_btn, "modulate", Color(1.3, 0.7, 0.7), 0.6)
	_speed_pulse_tween.tween_property(_speed_btn, "modulate", Color.WHITE, 0.6)


func _on_speed_toggle_pressed() -> void:
	_current_speed_idx = (_current_speed_idx + 1) % 3
	_speed_btn.text = _SPEED_LABELS[_current_speed_idx]
	match _current_speed_idx:
		0: GameManager.set_speed(Enums.GameSpeed.NORMAL)
		1: GameManager.set_speed(Enums.GameSpeed.FAST)
		2: GameManager.set_speed(Enums.GameSpeed.ULTRA)


# ---------------------------------------------------------------------------
# Center banners (wave complete, streak, last stand)
# ---------------------------------------------------------------------------

func _create_center_banners() -> void:
	_wave_banner = Label.new()
	_wave_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_banner.set_anchors_preset(Control.PRESET_CENTER)
	_wave_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_wave_banner.add_theme_font_size_override("font_size", 16)
	_wave_banner.add_theme_color_override("font_color", COL_GREEN)
	if _blackletter_font:
		_wave_banner.add_theme_font_override("font", _blackletter_font)
	_wave_banner.modulate.a = 0.0
	_wave_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_banner)

	_streak_label = Label.new()
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_streak_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_streak_label.offset_top = 22.0
	_streak_label.add_theme_font_size_override("font_size", 9)
	_streak_label.add_theme_color_override("font_color", Color.WHITE)
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_streak_label)

	_last_stand_label = Label.new()
	_last_stand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_stand_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_last_stand_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_last_stand_label.offset_top = 34.0
	_last_stand_label.add_theme_font_size_override("font_size", 10)
	_last_stand_label.add_theme_color_override("font_color", COL_RED)
	if _blackletter_font:
		_last_stand_label.add_theme_font_override("font", _blackletter_font)
	_last_stand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_last_stand_label)


# ---------------------------------------------------------------------------
# Send wave button
# ---------------------------------------------------------------------------

func _create_send_wave_btn() -> void:
	_send_wave_btn = Button.new()
	_send_wave_btn.text = "SEND WAVE"
	_send_wave_btn.custom_minimum_size = Vector2(90, 22)
	_send_wave_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_send_wave_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_send_wave_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_send_wave_btn.offset_top = -54.0
	_send_wave_btn.offset_bottom = -32.0
	_send_wave_btn.offset_left = -45.0
	_send_wave_btn.offset_right = 45.0
	_send_wave_btn.visible = false
	_send_wave_btn.pressed.connect(_on_send_wave_pressed)

	# Brutalist button style
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(0)
		sb.border_color = COL_RUST if state == "normal" else Color("#C04820")
		sb.set_border_width_all(2)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		match state:
			"normal": sb.bg_color = Color("#1A1A1E")
			"hover": sb.bg_color = Color("#252528")
			"pressed": sb.bg_color = COL_RUST
		_send_wave_btn.add_theme_stylebox_override(state, sb)

	_send_wave_btn.add_theme_font_size_override("font_size", 9)
	_send_wave_btn.add_theme_color_override("font_color", Color.WHITE)
	if _blackletter_font:
		_send_wave_btn.add_theme_font_override("font", _blackletter_font)
	add_child(_send_wave_btn)


# ---------------------------------------------------------------------------
# Cancel build button
# ---------------------------------------------------------------------------

func _create_cancel_build_btn() -> void:
	_cancel_build_btn = Button.new()
	_cancel_build_btn.text = "X"
	_cancel_build_btn.custom_minimum_size = Vector2(28, 28)
	_cancel_build_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_cancel_build_btn.grow_horizontal = Control.GROW_DIRECTION_END
	_cancel_build_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cancel_build_btn.offset_left = 4.0
	_cancel_build_btn.offset_bottom = -34.0
	_cancel_build_btn.offset_top = -62.0
	_cancel_build_btn.offset_right = 32.0
	_cancel_build_btn.visible = false
	_cancel_build_btn.pressed.connect(func(): SignalBus.build_mode_exited.emit())

	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL_BG
	sb.border_color = COL_RUST
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	_cancel_build_btn.add_theme_stylebox_override("normal", sb)

	add_child(_cancel_build_btn)


# ---------------------------------------------------------------------------
# Kill counter
# ---------------------------------------------------------------------------

func _create_kill_counter() -> void:
	_kill_counter_label = Label.new()
	_kill_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kill_counter_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_kill_counter_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_kill_counter_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_kill_counter_label.offset_right = -8.0
	_kill_counter_label.offset_bottom = -68.0
	_kill_counter_label.offset_left = -160.0
	_kill_counter_label.add_theme_font_size_override("font_size", 8)
	_kill_counter_label.add_theme_color_override("font_color", COL_GREEN)
	_kill_counter_label.visible = false
	_kill_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kill_counter_label)


# ---------------------------------------------------------------------------
# Game over overlay
# ---------------------------------------------------------------------------

func _create_game_over_overlay() -> void:
	_game_over_overlay = ColorRect.new()
	_game_over_overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	_game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over_overlay.visible = false
	add_child(_game_over_overlay)

	_game_over_label = Label.new()
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.set_anchors_preset(Control.PRESET_CENTER)
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
	_restart_btn.set_anchors_preset(Control.PRESET_CENTER)
	_restart_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_restart_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	_restart_btn.offset_top = 10.0
	_restart_btn.offset_bottom = 38.0
	_restart_btn.offset_left = -50.0
	_restart_btn.offset_right = 50.0
	_restart_btn.pressed.connect(_on_restart_pressed)
	_game_over_overlay.add_child(_restart_btn)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _update_budget_display(old_amount: int, new_amount: int) -> void:
	_budget_value_label.text = "$" + str(new_amount)

	# Pulse scale
	if _budget_tween:
		_budget_tween.kill()
	_budget_tween = create_tween()
	_budget_container.pivot_offset = _budget_container.custom_minimum_size / 2.0
	_budget_tween.tween_property(_budget_container, "scale", Vector2(1.12, 1.12), 0.08)
	_budget_tween.tween_property(_budget_container, "scale", Vector2(1.0, 1.0), 0.08)

	# Float change text
	var diff := new_amount - old_amount
	if diff != 0:
		_budget_change_label.text = ("+" if diff > 0 else "") + str(diff)
		_budget_change_label.add_theme_color_override("font_color", COL_GREEN if diff > 0 else COL_RED)
		_budget_change_label.modulate.a = 1.0
		_budget_change_label.position.y = 58.0
		var ft := create_tween()
		ft.set_parallel(true)
		ft.tween_property(_budget_change_label, "position:y", 44.0, 0.6)
		ft.tween_property(_budget_change_label, "modulate:a", 0.0, 0.6).set_delay(0.2)


func _update_approval_bar(lives: int) -> void:
	var ratio := float(lives) / float(_max_approval) if _max_approval > 0 else 0.0
	ratio = clampf(ratio, 0.0, 1.0)
	var target_w := ratio * APPROVAL_BAR_W

	# Color lerp green → red
	_approval_bar_fill.color = COL_APPROVAL_FULL.lerp(COL_APPROVAL_LOW, 1.0 - ratio)

	# Smooth tween
	if _approval_tween:
		_approval_tween.kill()
	_approval_tween = create_tween()
	_approval_tween.tween_property(_approval_bar_fill, "size:x", target_w, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_approval_label.text = str(lives) + "/" + str(_max_approval)

	# Pulse red at critical
	if lives <= 2 and lives > 0:
		if _lives_pulse_tween:
			_lives_pulse_tween.kill()
		_lives_pulse_tween = create_tween().set_loops()
		_lives_pulse_tween.tween_property(_approval_bar_fill, "modulate", Color(1.5, 0.6, 0.6), 0.3)
		_lives_pulse_tween.tween_property(_approval_bar_fill, "modulate", Color.WHITE, 0.3)
	elif _lives_pulse_tween:
		_lives_pulse_tween.kill()
		_lives_pulse_tween = null
		_approval_bar_fill.modulate = Color.WHITE


func _make_fallback_circle() -> ImageTexture:
	const SIZE := 60
	const HALF := SIZE / 2
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(HALF, HALF)
	var radius := HALF - 5.0
	for y in SIZE:
		for x in SIZE:
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius:
				img.set_pixel(x, y, COL_CIRCLE_BG)
			elif dist <= radius + 1.0:
				var edge_alpha := 1.0 - (dist - radius)
				img.set_pixel(x, y, Color(COL_CIRCLE_BG.r, COL_CIRCLE_BG.g, COL_CIRCLE_BG.b, edge_alpha))
	return ImageTexture.create_from_image(img)


func _make_circle_portrait(portrait_tex: Texture2D) -> ImageTexture:
	const SIZE := 60
	const HALF := SIZE / 2
	var radius := HALF - 5.0
	var center := Vector2(HALF, HALF)

	# Get portrait image and resize to fill circle area
	var src := portrait_tex.get_image()
	if not src:
		return _make_fallback_circle()
	src = src.duplicate()
	var fill := int(radius * 2)
	src.resize(fill, fill, Image.INTERPOLATE_NEAREST)

	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var offset := HALF - fill / 2

	for y in SIZE:
		for x in SIZE:
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius:
				var sx := x - offset
				var sy := y - offset
				if sx >= 0 and sx < fill and sy >= 0 and sy < fill:
					var col := src.get_pixel(sx, sy)
					if dist > radius - 1.0:
						col.a *= (radius - dist + 1.0)
					img.set_pixel(x, y, col)
				else:
					img.set_pixel(x, y, COL_CIRCLE_BG)
			elif dist <= radius + 1.0:
				var edge_alpha := 1.0 - (dist - radius)
				img.set_pixel(x, y, Color(COL_CIRCLE_BG.r, COL_CIRCLE_BG.g, COL_CIRCLE_BG.b, edge_alpha))

	return ImageTexture.create_from_image(img)


func _update_wave_circle(wave_number: int) -> void:
	_wave_number_label.text = str(wave_number)

	_wave_name_label.text = WaveNames.get_wave_name(wave_number)

	# Manifestation name
	_manifestation_name_label.text = WaveNames.get_manifestation_name(wave_number)

	# Update circle portrait when manifestation leader changes
	var manif_leader := WaveNames.get_manifestation_leader_id(wave_number)
	if manif_leader != _current_manifestation_leader:
		_current_manifestation_leader = manif_leader
		var manif_tex := ThemeManager.get_wave_portrait(manif_leader)
		if manif_tex:
			_wave_circle_tex.texture = _make_circle_portrait(manif_tex)
		else:
			_wave_circle_tex.texture = _make_fallback_circle()

	# Compute total enemies for this wave
	_wave_gone = 0
	_wave_total = 0
	var wave_idx := wave_number - 1
	if wave_idx >= 0 and wave_idx < WaveManager.waves.size():
		var wave_data: WaveData = WaveManager.waves[wave_idx]
		for seq in wave_data.spawn_sequences:
			_wave_total += seq.count
	_wave_progress_ring.queue_redraw()

	# Bounce tween
	_wave_circle_tex.pivot_offset = Vector2(30, 30)
	_wave_number_label.pivot_offset = _wave_number_label.size / 2.0
	var bt := create_tween()
	bt.tween_property(_wave_circle_tex, "scale", Vector2(1.15, 1.15), 0.1)
	bt.tween_property(_wave_circle_tex, "scale", Vector2(1.0, 1.0), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _draw_progress_ring() -> void:
	# Draw a circular arc showing wave progress (enemies gone / total)
	var center := Vector2(30, 30)  # half of 60px circle
	var outer_r := 29.0
	var ring_width := 3.0
	var point_count := 64

	# Background track (dark ring)
	_wave_progress_ring.draw_arc(center, outer_r, 0.0, TAU, point_count, Color("#2A2A30"), ring_width, true)

	if _wave_total <= 0:
		return

	var ratio := clampf(float(_wave_gone) / float(_wave_total), 0.0, 1.0)
	if ratio <= 0.0:
		return

	# Progress arc — starts at top (-PI/2), sweeps clockwise
	var start_angle := -PI / 2.0
	var end_angle := start_angle + TAU * ratio

	# Color: lerp from amber to green as wave clears
	var arc_color := COL_AMBER.lerp(COL_GREEN, ratio)
	_wave_progress_ring.draw_arc(center, outer_r, start_angle, end_angle, point_count, arc_color, ring_width, true)


# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var timer := WaveManager.get_between_wave_timer()
	if timer > 0.0:
		_send_wave_btn.visible = true
		var bonus := WaveManager.get_call_wave_bonus()
		_send_wave_btn.text = "SEND WAVE" + (" +$" + str(bonus) if bonus > 0 else "")
	else:
		_send_wave_btn.visible = false


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_gold_changed(amount: int) -> void:
	var old := _budget
	_budget = amount
	_update_budget_display(old, amount)


func _on_lives_changed(amount: int) -> void:
	_approval = amount
	_update_approval_bar(amount)


func _on_wave_started(wave_number: int) -> void:
	_incident = wave_number
	_update_wave_circle(wave_number)


func _on_wave_completed(wave_number: int) -> void:
	_show_wave_banner(wave_number)


func _on_enemies_remaining(count: int) -> void:
	_active_count = count


func _on_speed_changed(speed: Enums.GameSpeed) -> void:
	# Sync toggle label with external speed changes
	match speed:
		Enums.GameSpeed.NORMAL:
			_current_speed_idx = 0
		Enums.GameSpeed.FAST:
			_current_speed_idx = 1
		Enums.GameSpeed.ULTRA:
			_current_speed_idx = 2
	_speed_btn.text = _SPEED_LABELS[_current_speed_idx]


func _on_game_over(victory: bool) -> void:
	_send_wave_btn.visible = false
	_kill_counter_label.visible = false

	if victory:
		_game_over_label.text = "ORDER RESTORED"
		_game_over_label.add_theme_color_override("font_color", COL_GREEN)
		_game_over_label.add_theme_font_size_override("font_size", 24)
		_game_over_overlay.visible = true
	else:
		_game_over_label.text = "REGIME CHANGE"
		_game_over_label.add_theme_color_override("font_color", COL_RED)
		_game_over_label.add_theme_font_size_override("font_size", 36)
		_game_over_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		_game_over_overlay.visible = true
		_game_over_label.modulate.a = 0.0
		_restart_btn.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_game_over_overlay, "color:a", 0.75, 1.2) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_game_over_label, "modulate:a", 1.0, 0.8) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_restart_btn, "modulate:a", 1.0, 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_build_post_game_ui(victory)


# -- Engagement handlers --

func _show_wave_banner(wave_number: int) -> void:
	var wave_name := WaveNames.get_wave_name(wave_number)
	_wave_banner.text = wave_name + " CONTAINED"
	if WaveManager.perfect_streak > 0:
		_wave_banner.add_theme_color_override("font_color", COL_AMBER)
	else:
		_wave_banner.add_theme_color_override("font_color", COL_GREEN)
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
		_streak_label.add_theme_color_override("font_color", COL_AMBER)
		var tween := create_tween().set_loops()
		tween.tween_property(_streak_label, "modulate:a", 0.5, 0.5)
		tween.tween_property(_streak_label, "modulate:a", 1.0, 0.5)
	elif count >= 3:
		_streak_label.add_theme_color_override("font_color", COL_AMBER)
		_streak_label.modulate.a = 1.0
	else:
		_streak_label.add_theme_color_override("font_color", Color.WHITE)
		_streak_label.modulate.a = 1.0


func _on_last_stand_entered() -> void:
	_last_stand_label.text = "MARTIAL LAW"
	# Pulse the approval bar red instead of the old info_label
	if _lives_pulse_tween:
		_lives_pulse_tween.kill()
	_lives_pulse_tween = create_tween().set_loops()
	_lives_pulse_tween.tween_property(_approval_bar_fill, "modulate", Color(2.0, 0.4, 0.4), 0.4)
	_lives_pulse_tween.tween_property(_approval_bar_fill, "modulate", Color.WHITE, 0.4)


func _on_send_wave_pressed() -> void:
	WaveManager.call_next_wave()


func _on_restart_pressed() -> void:
	SignalBus.restart_requested.emit()


func _on_streak_broken(old_streak: int) -> void:
	if old_streak <= 0:
		return
	_streak_label.text = "ZERO TOLERANCE: BROKEN"
	_streak_label.add_theme_color_override("font_color", COL_RED)
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
	_wave_gone += 1
	_wave_progress_ring.queue_redraw()
	if _selected_tower_ref and is_instance_valid(_selected_tower_ref):
		call_deferred("_update_kill_counter")


func _on_enemy_leaked_hud(_enemy: Node2D, _lives_cost: int) -> void:
	_wave_gone += 1
	_wave_progress_ring.queue_redraw()


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
	_wave_banner.add_theme_color_override("font_color", COL_AMBER)
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
	stats_label.set_anchors_preset(Control.PRESET_CENTER)
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
			what_if.set_anchors_preset(Control.PRESET_CENTER)
			what_if.grow_horizontal = Control.GROW_DIRECTION_BOTH
			what_if.offset_top = 80.0
			what_if.add_theme_font_size_override("font_size", 9)
			what_if.add_theme_color_override("font_color", COL_AMBER)
			what_if.text = "Last " + ename + " escaped with " + str(hp) + " HP"
			_game_over_overlay.add_child(what_if)


func _on_build_mode_entered_hud(_tower_data: TowerData) -> void:
	if _cancel_build_btn:
		_cancel_build_btn.visible = true


func _on_build_mode_exited_hud() -> void:
	if _cancel_build_btn:
		_cancel_build_btn.visible = false
