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
var _approval_tween: Tween

# Wave circle (top-right)
var _wave_circle_container: Control
var _wave_number_label: Label
var _wave_title_flash: Label
var _wave_title_tween: Tween
var _wave_circle_tex: TextureRect
var _wave_progress_ring: Control  # custom draw arc

# Wave progress tracking
var _wave_total: int = 0
var _wave_gone: int = 0

# Speed toggle (single button, cycles 1x→2x→3x)
var _speed_btn: Button
var _current_speed_idx: int = 0

# Approval bar custom draw
var _approval_draw: Control
var _approval_ratio: float = 1.0
var _approval_pulse_phase: float = 0.0

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
var _victory_banner: TextureRect
var _confetti_nodes: Array[Control] = []

# Kill counter (bottom-right, above upgrade panel)
var _kill_counter_label: Label
var _selected_tower_ref: BaseTower

var _banner_tween: Tween
var _lives_pulse_tween: Tween
var _blackletter_font: Font
var _current_manifestation_leader: String = ""

# Colors
const COL_PANEL_BG := Color("#1A1A1E")
const COL_PANEL_BORDER := Color("#121216")
const COL_CARD_BORDER := Color("#28282C")
const COL_MUTED := Color("#808898")
const COL_GOLD := Color("#F2D864")
const COL_AMBER := Color("#F0F0F0")
const COL_GREEN := Color("#A0D8A0")
const COL_RED := Color("#D04040")
const COL_PILL_BG := Color("#08080A")
const COL_CIRCLE_BG := Color("#D8CFC0")  # light beige

# Approval bar colors
const COL_APPROVAL_FULL := Color("#A0D8A0")
const COL_APPROVAL_LOW := Color("#D04040")
const COL_BAR_BG := Color("#1E1E22")

const APPROVAL_BAR_W := 180.0
const APPROVAL_BAR_H := 16.0
const HUD_MARGIN := 36.0  # inner margin from viewport edges


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
	_budget_container.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	_budget_container.custom_minimum_size = Vector2(220, 68)
	_budget_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_budget_container)

	var header := Label.new()
	header.text = "TAXPAYER BUDGET"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color.WHITE)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_budget_container.add_child(header)

	_budget_value_label = Label.new()
	_budget_value_label.text = "$0"
	_budget_value_label.position = Vector2(0, 20)
	_budget_value_label.add_theme_font_size_override("font_size", 42)
	_budget_value_label.add_theme_color_override("font_color", Color.WHITE)
	if _blackletter_font:
		_budget_value_label.add_theme_font_override("font", _blackletter_font)
	_budget_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_budget_container.add_child(_budget_value_label)

	# Floating change label
	_budget_change_label = Label.new()
	_budget_change_label.position = Vector2(HUD_MARGIN, HUD_MARGIN + 66)
	_budget_change_label.add_theme_font_size_override("font_size", 14)
	_budget_change_label.modulate.a = 0.0
	_budget_change_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_budget_change_label)


# ---------------------------------------------------------------------------
# Approval bar (bottom-right) — custom drawn with rounded corners + 3D gradient
# ---------------------------------------------------------------------------

func _create_approval_bar() -> void:
	_approval_container = Control.new()
	_approval_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_approval_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_approval_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_approval_container.offset_right = -HUD_MARGIN
	_approval_container.offset_bottom = -HUD_MARGIN
	_approval_container.offset_left = -HUD_MARGIN - APPROVAL_BAR_W - 4.0
	_approval_container.offset_top = -HUD_MARGIN - (APPROVAL_BAR_H + 4.0)
	_approval_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_approval_container)

	# Custom draw control for the bar
	_approval_draw = Control.new()
	_approval_draw.position = Vector2.ZERO
	_approval_draw.custom_minimum_size = Vector2(APPROVAL_BAR_W + 4, APPROVAL_BAR_H + 4)
	_approval_draw.size = Vector2(APPROVAL_BAR_W + 4, APPROVAL_BAR_H + 4)
	_approval_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_approval_draw.draw.connect(_draw_approval_bar)
	_approval_container.add_child(_approval_draw)


# ---------------------------------------------------------------------------
# Wave circle (top-right)
# ---------------------------------------------------------------------------

func _create_wave_circle() -> void:
	const CIRCLE_SIZE := 100
	const BOX_PAD := 10
	const BOX_W := CIRCLE_SIZE + BOX_PAD * 2
	const HEADER_H := 24  # height of the wave name header line

	# Wave title flash — center screen, appears briefly on wave start
	_wave_title_flash = Label.new()
	_wave_title_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_title_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_title_flash.set_anchors_preset(Control.PRESET_CENTER)
	_wave_title_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_title_flash.grow_vertical = Control.GROW_DIRECTION_BOTH
	_wave_title_flash.offset_left = -240.0
	_wave_title_flash.offset_right = 240.0
	_wave_title_flash.offset_top = -30.0
	_wave_title_flash.offset_bottom = 30.0
	_wave_title_flash.add_theme_font_size_override("font_size", 28)
	_wave_title_flash.add_theme_color_override("font_color", Color.WHITE)
	_wave_title_flash.add_theme_color_override("font_outline_color", Color("#1A1A1E"))
	_wave_title_flash.add_theme_constant_override("outline_size", 4)
	if _blackletter_font:
		_wave_title_flash.add_theme_font_override("font", _blackletter_font)
	_wave_title_flash.modulate.a = 0.0
	_wave_title_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_title_flash)

	# Dark semi-transparent box — below the wave name header
	var box_top := HUD_MARGIN + HEADER_H + 4
	var box_h := CIRCLE_SIZE + BOX_PAD * 2  # circle + padding

	_wave_circle_container = Control.new()
	_wave_circle_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wave_circle_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_wave_circle_container.grow_vertical = Control.GROW_DIRECTION_END
	_wave_circle_container.offset_right = -HUD_MARGIN
	_wave_circle_container.offset_left = -HUD_MARGIN - BOX_W
	_wave_circle_container.offset_top = box_top
	_wave_circle_container.offset_bottom = box_top + box_h
	_wave_circle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_circle_container)

	# Inner layout — centered content
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.position = Vector2(BOX_PAD, BOX_PAD)
	vbox.size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_circle_container.add_child(vbox)

	# Circle holder (fixed size, centered in vbox)
	var circle_holder := Control.new()
	circle_holder.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	circle_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circle_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(circle_holder)

	# Progress ring (drawn behind circle)
	_wave_progress_ring = Control.new()
	_wave_progress_ring.position = Vector2.ZERO
	_wave_progress_ring.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	_wave_progress_ring.size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	_wave_progress_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_progress_ring.draw.connect(_draw_progress_ring)
	circle_holder.add_child(_wave_progress_ring)

	# Circle background
	_wave_circle_tex = TextureRect.new()
	_wave_circle_tex.texture = _make_fallback_circle()
	_wave_circle_tex.position = Vector2.ZERO
	_wave_circle_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wave_circle_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_holder.add_child(_wave_circle_tex)

	# Wave number centered in circle
	_wave_number_label = Label.new()
	_wave_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_number_label.position = Vector2.ZERO
	_wave_number_label.size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	_wave_number_label.add_theme_font_size_override("font_size", 34)
	_wave_number_label.add_theme_color_override("font_color", Color.WHITE)
	if _blackletter_font:
		_wave_number_label.add_theme_font_override("font", _blackletter_font)
	_wave_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_holder.add_child(_wave_number_label)



# ---------------------------------------------------------------------------
# Speed toggle (discreet grey button, bottom-center)
# ---------------------------------------------------------------------------

const _SPEED_LABELS := ["1x", "2x", "3x"]

func _create_speed_controls() -> void:
	_speed_btn = Button.new()
	_speed_btn.text = "1x"
	_speed_btn.custom_minimum_size = Vector2(46, 24)
	_speed_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_speed_btn.grow_horizontal = Control.GROW_DIRECTION_END
	_speed_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_speed_btn.offset_left = HUD_MARGIN
	_speed_btn.offset_right = HUD_MARGIN + 46.0
	_speed_btn.offset_bottom = -HUD_MARGIN
	_speed_btn.offset_top = -(HUD_MARGIN + 24.0)
	_speed_btn.pressed.connect(_on_speed_toggle_pressed)

	ButtonStyles.apply_utility(_speed_btn)
	_speed_btn.add_theme_font_size_override("font_size", 12)
	add_child(_speed_btn)


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
	_wave_banner.add_theme_font_size_override("font_size", 22)
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
	_streak_label.offset_top = 26.0
	_streak_label.add_theme_font_size_override("font_size", 14)
	_streak_label.add_theme_color_override("font_color", Color.WHITE)
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_streak_label)

	_last_stand_label = Label.new()
	_last_stand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_stand_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_last_stand_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_last_stand_label.offset_top = 44.0
	_last_stand_label.add_theme_font_size_override("font_size", 16)
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
	_send_wave_btn.custom_minimum_size = Vector2(120, 32)
	_send_wave_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_send_wave_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_send_wave_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_send_wave_btn.offset_top = -62.0
	_send_wave_btn.offset_bottom = -30.0
	_send_wave_btn.offset_left = -60.0
	_send_wave_btn.offset_right = 60.0
	_send_wave_btn.visible = false
	_send_wave_btn.pressed.connect(_on_send_wave_pressed)

	ButtonStyles.apply_accent(_send_wave_btn)
	_send_wave_btn.add_theme_font_size_override("font_size", 13)
	if _blackletter_font:
		_send_wave_btn.add_theme_font_override("font", _blackletter_font)
	add_child(_send_wave_btn)


# ---------------------------------------------------------------------------
# Cancel build button
# ---------------------------------------------------------------------------

func _create_cancel_build_btn() -> void:
	_cancel_build_btn = Button.new()
	_cancel_build_btn.text = "X"
	_cancel_build_btn.custom_minimum_size = Vector2(38, 38)
	_cancel_build_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_cancel_build_btn.grow_horizontal = Control.GROW_DIRECTION_END
	_cancel_build_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cancel_build_btn.offset_left = HUD_MARGIN
	_cancel_build_btn.offset_bottom = -(HUD_MARGIN + 50.0)
	_cancel_build_btn.offset_top = -(HUD_MARGIN + 88.0)
	_cancel_build_btn.offset_right = HUD_MARGIN + 38.0
	_cancel_build_btn.visible = false
	_cancel_build_btn.pressed.connect(func(): SignalBus.build_mode_exited.emit())

	ButtonStyles.apply_accent(_cancel_build_btn)
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
	_kill_counter_label.offset_right = -HUD_MARGIN
	_kill_counter_label.offset_bottom = -(HUD_MARGIN + 80.0)
	_kill_counter_label.offset_left = -(HUD_MARGIN + 140.0)
	_kill_counter_label.add_theme_font_size_override("font_size", 12)
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

	# Victory banner image (hidden by default, shown on victory)
	_victory_banner = TextureRect.new()
	var banner_tex := load("res://assets/sprites/ui/victory_banner.png")
	if banner_tex:
		_victory_banner.texture = banner_tex
	_victory_banner.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_victory_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_victory_banner.set_anchors_preset(Control.PRESET_CENTER)
	_victory_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_victory_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_victory_banner.offset_left = -160.0
	_victory_banner.offset_right = 160.0
	_victory_banner.offset_top = -180.0
	_victory_banner.offset_bottom = 140.0
	_victory_banner.visible = false
	_game_over_overlay.add_child(_victory_banner)

	_game_over_label = Label.new()
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_game_over_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_game_over_label.offset_top = -40.0
	_game_over_label.add_theme_font_size_override("font_size", 30)
	if _blackletter_font:
		_game_over_label.add_theme_font_override("font", _blackletter_font)
	_game_over_overlay.add_child(_game_over_label)

	_restart_btn = Button.new()
	_restart_btn.text = "RESTART"
	_restart_btn.custom_minimum_size = Vector2(140, 38)
	_restart_btn.set_anchors_preset(Control.PRESET_CENTER)
	_restart_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_restart_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	_restart_btn.offset_top = 10.0
	_restart_btn.offset_bottom = 48.0
	_restart_btn.offset_left = -70.0
	_restart_btn.offset_right = 70.0
	_restart_btn.pressed.connect(_on_restart_pressed)
	ButtonStyles.apply_primary(_restart_btn)
	if _blackletter_font:
		_restart_btn.add_theme_font_override("font", _blackletter_font)
	_restart_btn.add_theme_font_size_override("font_size", 18)
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
		_budget_change_label.position.y = HUD_MARGIN + 66.0
		var ft := create_tween()
		ft.set_parallel(true)
		ft.tween_property(_budget_change_label, "position:y", HUD_MARGIN + 50.0, 0.6)
		ft.tween_property(_budget_change_label, "modulate:a", 0.0, 0.6).set_delay(0.2)


func _update_approval_bar(lives: int) -> void:
	var target := float(lives) / float(_max_approval) if _max_approval > 0 else 0.0
	target = clampf(target, 0.0, 1.0)

	# Smooth tween the ratio
	if _approval_tween:
		_approval_tween.kill()
	_approval_tween = create_tween()
	_approval_tween.tween_method(_set_approval_ratio, _approval_ratio, target, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _set_approval_ratio(val: float) -> void:
	_approval_ratio = val
	_approval_draw.queue_redraw()


func _draw_approval_bar() -> void:
	var w := APPROVAL_BAR_W + 4.0
	var h := APPROVAL_BAR_H + 4.0
	var radius := 4.0

	# Background (dark inset)
	var bg_rect := Rect2(0, 0, w, h)
	_approval_draw.draw_rect(bg_rect, Color("#0E0E12"), true)  # will be covered by rounded
	# Draw rounded bg manually via stylebox approach — use draw primitives
	var bg_points := _rounded_rect_points(0, 0, w, h, radius)
	_approval_draw.draw_colored_polygon(bg_points, Color("#1A1A20"))

	# Fill bar with 3D red gradient
	var fill_w := _approval_ratio * (w - 4.0)
	if fill_w > 1.0:
		var fx := 2.0
		var fy := 2.0
		var fw := fill_w
		var fh := h - 4.0
		var fr := minf(radius - 1.0, fw * 0.5)

		# Pulse — subtle brightness oscillation
		var pulse := 0.03 * sin(_approval_pulse_phase * 3.0)

		# Draw gradient: brighter at top, darker at bottom (3D bevel)
		var steps := int(fh)
		for row in steps:
			var t := float(row) / float(steps)
			# Top highlight → mid color → bottom shadow
			var base_r := 0.75 + pulse
			var base_g := 0.12
			var base_b := 0.12
			var highlight := 1.0 - t * 0.5  # 1.0 at top, 0.5 at bottom
			var col := Color(base_r * highlight, base_g * highlight, base_b * highlight)
			var ry := fy + row
			# Clip to rounded rect shape
			var inset := 0.0
			if row < fr:
				inset = fr - sqrt(maxf(fr * fr - (fr - row) * (fr - row), 0.0))
			elif row > fh - fr:
				var dy := row - (fh - fr)
				inset = fr - sqrt(maxf(fr * fr - dy * dy, 0.0))
			var lx := fx + inset
			var rw := fw - inset * 2.0
			if rw > 0.0:
				_approval_draw.draw_rect(Rect2(lx, ry, rw, 1.0), col)

		# Specular highlight line at top
		if fw > 4.0:
			var spec_col := Color(1.0, 0.5, 0.5, 0.3 + pulse * 2.0)
			_approval_draw.draw_rect(Rect2(fx + fr, fy + 1, fw - fr * 2.0, 1.0), spec_col)

	# Outer rounded border
	var border_points := _rounded_rect_points(0, 0, w, h, radius)
	_approval_draw.draw_polyline(border_points, Color("#3A1A1A"), 1.0, true)


func _rounded_rect_points(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segments := 8
	# Top-left corner
	for i in range(segments + 1):
		var angle := PI + float(i) / float(segments) * (PI / 2.0)
		pts.append(Vector2(x + r + cos(angle) * r, y + r + sin(angle) * r))
	# Top-right corner
	for i in range(segments + 1):
		var angle := -PI / 2.0 + float(i) / float(segments) * (PI / 2.0)
		pts.append(Vector2(x + w - r + cos(angle) * r, y + r + sin(angle) * r))
	# Bottom-right corner
	for i in range(segments + 1):
		var angle := float(i) / float(segments) * (PI / 2.0)
		pts.append(Vector2(x + w - r + cos(angle) * r, y + h - r + sin(angle) * r))
	# Bottom-left corner
	for i in range(segments + 1):
		var angle := PI / 2.0 + float(i) / float(segments) * (PI / 2.0)
		pts.append(Vector2(x + r + cos(angle) * r, y + h - r + sin(angle) * r))
	pts.append(pts[0])  # close
	return pts


func _make_fallback_circle() -> ImageTexture:
	const SIZE := 100
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
	const SIZE := 100
	const HALF := SIZE / 2
	var radius := HALF - 5.0
	var center := Vector2(HALF, HALF)

	# Get portrait image and resize to fill circle area
	var src := portrait_tex.get_image()
	if not src:
		return _make_fallback_circle()
	src = src.duplicate()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var fill := int(radius * 2)
	src.resize(fill, fill, Image.INTERPOLATE_NEAREST)

	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var px_offset := HALF - fill / 2

	for y in SIZE:
		for x in SIZE:
			var dist := Vector2(x, y).distance_to(center)
			if dist <= radius:
				var sx := x - px_offset
				var sy := y - px_offset
				# Start with beige background
				var final_col := COL_CIRCLE_BG
				if sx >= 0 and sx < fill and sy >= 0 and sy < fill:
					var px: Color = src.get_pixel(sx, sy)
					# Alpha-blend portrait over beige
					final_col = Color(
						COL_CIRCLE_BG.r * (1.0 - px.a) + px.r * px.a,
						COL_CIRCLE_BG.g * (1.0 - px.a) + px.g * px.a,
						COL_CIRCLE_BG.b * (1.0 - px.a) + px.b * px.a,
						1.0
					)
				# Anti-alias circle edge
				if dist > radius - 1.0:
					final_col.a *= (radius - dist + 1.0)
				img.set_pixel(x, y, final_col)
			elif dist <= radius + 1.0:
				var edge_alpha := 1.0 - (dist - radius)
				img.set_pixel(x, y, Color(COL_CIRCLE_BG.r, COL_CIRCLE_BG.g, COL_CIRCLE_BG.b, edge_alpha))

	return ImageTexture.create_from_image(img)


func _update_wave_circle(wave_number: int) -> void:
	_wave_number_label.text = str(wave_number)

	# Flash wave title briefly at center screen
	var manif_name := WaveNames.get_manifestation_name(wave_number)
	var wave_name := WaveNames.get_wave_name(wave_number)
	_flash_wave_title(manif_name + " — " + wave_name)

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
	_wave_circle_tex.pivot_offset = Vector2(50, 50)
	_wave_number_label.pivot_offset = _wave_number_label.size / 2.0
	var bt := create_tween()
	bt.tween_property(_wave_circle_tex, "scale", Vector2(1.15, 1.15), 0.1)
	bt.tween_property(_wave_circle_tex, "scale", Vector2(1.0, 1.0), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _draw_progress_ring() -> void:
	# Draw a circular arc showing wave progress (enemies gone / total)
	var center := Vector2(50, 50)  # half of 100px circle
	var outer_r := 49.0
	var ring_width := 4.0
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

func _process(delta: float) -> void:
	var timer := WaveManager.get_between_wave_timer()
	if timer > 0.0:
		_send_wave_btn.visible = true
		var bonus := WaveManager.get_call_wave_bonus()
		_send_wave_btn.text = "SEND WAVE" + (" +$" + str(bonus) if bonus > 0 else "")
	else:
		_send_wave_btn.visible = false

	# Subtle pulse on the approval bar
	_approval_pulse_phase += delta
	_approval_draw.queue_redraw()


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
		_game_over_label.add_theme_color_override("font_color", COL_GOLD)
		_game_over_label.add_theme_font_size_override("font_size", 36)
		_game_over_label.offset_top = 148.0
		_game_over_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		_game_over_overlay.visible = true
		_game_over_label.modulate.a = 0.0
		_restart_btn.modulate.a = 0.0
		_restart_btn.offset_top = 190.0
		_restart_btn.offset_bottom = 228.0
		# Banner: start small + transparent, scale up with bounce
		_victory_banner.visible = true
		_victory_banner.modulate.a = 0.0
		_victory_banner.pivot_offset = _victory_banner.size / 2.0
		_victory_banner.scale = Vector2(0.5, 0.5)
		# Animated entrance
		var tw := create_tween()
		tw.tween_property(_game_over_overlay, "color:a", 0.8, 0.8) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_victory_banner, "modulate:a", 1.0, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(_victory_banner, "scale", Vector2(1.05, 1.05), 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(_victory_banner, "scale", Vector2(1.0, 1.0), 0.2) \
			.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_game_over_label, "modulate:a", 1.0, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_restart_btn, "modulate:a", 1.0, 0.4) \
			.set_ease(Tween.EASE_OUT)
		tw.tween_callback(_spawn_confetti)
		# Gentle title pulse loop
		tw.tween_callback(func():
			var pulse := create_tween().set_loops()
			pulse.tween_property(_game_over_label, "modulate",
				Color(1.3, 1.2, 0.8, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
			pulse.tween_property(_game_over_label, "modulate",
				Color(1.0, 1.0, 1.0, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
		)
	else:
		_game_over_label.text = "REGIME CHANGE"
		_game_over_label.add_theme_color_override("font_color", COL_RED)
		_game_over_label.add_theme_font_size_override("font_size", 42)
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


func _flash_wave_title(title_text: String) -> void:
	_wave_title_flash.text = title_text
	if _wave_title_tween:
		_wave_title_tween.kill()
	_wave_title_tween = create_tween()
	_wave_title_flash.modulate.a = 0.0
	_wave_title_flash.scale = Vector2(0.8, 0.8)
	_wave_title_flash.pivot_offset = _wave_title_flash.size / 2.0
	_wave_title_tween.tween_property(_wave_title_flash, "modulate:a", 1.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_wave_title_tween.parallel().tween_property(_wave_title_flash, "scale", Vector2.ONE, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_wave_title_tween.tween_interval(1.2)
	_wave_title_tween.tween_property(_wave_title_flash, "modulate:a", 0.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


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
	# Pulse the approval bar intensely
	if _lives_pulse_tween:
		_lives_pulse_tween.kill()
	_lives_pulse_tween = create_tween().set_loops()
	_lives_pulse_tween.tween_property(_approval_draw, "modulate", Color(2.0, 0.6, 0.6), 0.4)
	_lives_pulse_tween.tween_property(_approval_draw, "modulate", Color.WHITE, 0.4)


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
	stats_label.offset_top = 236.0 if victory else 56.0
	stats_label.add_theme_font_size_override("font_size", 12)
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
			what_if.offset_top = 86.0
			what_if.add_theme_font_size_override("font_size", 13)
			what_if.add_theme_color_override("font_color", COL_AMBER)
			what_if.text = "Last " + ename + " escaped with " + str(hp) + " HP"
			_game_over_overlay.add_child(what_if)


func _spawn_confetti() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var colors: Array[Color] = [
		COL_GOLD, COL_AMBER, COL_GREEN, Color("#F0E0C0"),
		Color("#D06030"), Color("#50A0D0"), Color.WHITE,
	]
	for i in 40:
		var particle := ColorRect.new()
		var c: Color = colors[i % colors.size()]
		particle.color = c
		var w := randf_range(3.0, 7.0)
		var h := randf_range(3.0, 10.0)
		particle.custom_minimum_size = Vector2(w, h)
		particle.size = Vector2(w, h)
		var start_x := randf_range(0.0, vp_size.x)
		var start_y := randf_range(-60.0, -20.0)
		particle.position = Vector2(start_x, start_y)
		particle.rotation = randf_range(0.0, TAU)
		particle.modulate.a = randf_range(0.7, 1.0)
		_game_over_overlay.add_child(particle)
		_confetti_nodes.append(particle)
		# Animate: fall down with drift + spin
		var end_y := vp_size.y + 40.0
		var drift := randf_range(-80.0, 80.0)
		var duration := randf_range(2.5, 5.0)
		var delay := randf_range(0.0, 1.5)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(particle, "position:y", end_y, duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(particle, "position:x",
			start_x + drift, duration)
		tw.parallel().tween_property(particle, "rotation",
			particle.rotation + randf_range(TAU * 2, TAU * 5), duration)
		tw.parallel().tween_property(particle, "modulate:a", 0.0,
			duration * 0.3).set_delay(duration * 0.7)
	# Repeat confetti waves
	var loop_tw := create_tween()
	loop_tw.tween_interval(4.0)
	loop_tw.tween_callback(_spawn_confetti_wave)


func _spawn_confetti_wave() -> void:
	# Clean up old particles
	for node in _confetti_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_confetti_nodes.clear()
	_spawn_confetti()


func _on_build_mode_entered_hud(_tower_data: TowerData) -> void:
	if _cancel_build_btn:
		_cancel_build_btn.visible = true


func _on_build_mode_exited_hud() -> void:
	if _cancel_build_btn:
		_cancel_build_btn.visible = false
