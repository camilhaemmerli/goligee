class_name UpgradePanel
extends PanelContainer
## Fixed-height upgrade modal. Stat bars show green delta on preview.
## Layout: title, targeting, stat bars, [info area], path buttons, sell.

enum State { HIDDEN, STATS, PREVIEW }

var _state: int = State.HIDDEN
var _selected_tower: BaseTower
var _preview_path: int = -1
var _blackletter_font: Font

# UI nodes (built programmatically)
var _main_vbox: VBoxContainer
var _top_vbox: VBoxContainer
var _bottom_vbox: VBoxContainer
var _tower_name_label: Label
var _targeting_label: Label
var _stats_vbox: VBoxContainer
var _info_vbox: VBoxContainer  # upgrade description + effect unlocks
var _path_hbox: HBoxContainer
var _sell_button: Button
var _path_buttons: Array[Button] = []
var _stat_bars: Array[Dictionary] = []

const PANEL_WIDTH = 300.0
const PANEL_HEIGHT = 280.0

const COL_PANEL_BG = Color("#1A1A1E")
const COL_BORDER   = Color("#28282C")
const COL_GOLD     = Color("#F2D864")
const COL_MUTED    = Color("#808898")
const COL_BAR_BG   = Color("#1E1E22")
const COL_BAR_FILL = Color("#D04040")
const COL_BAR_GREEN = Color("#60C060")
const COL_BAR_SPEC = Color(1.0, 0.4, 0.4, 0.3)
const COL_BAR_BORDER = Color("#2A2A30")
const BAR_HEIGHT = 10.0

const STAT_MAX := {
	"base_damage": 120.0,
	"fire_rate": 5.0,
	"base_range": 8.0,
	"area_of_effect": 5.0,
	"pierce_count": 10.0,
	"chain_targets": 8.0,
	"slow": 1.0,
}

const STAT_LABELS := {
	"base_damage": "DAMAGE",
	"fire_rate": "FIRE RATE",
	"base_range": "RANGE",
	"area_of_effect": "SPLASH",
	"pierce_count": "PIERCE",
	"chain_targets": "CHAIN",
	"slow": "SLOW",
}

const ALL_STAT_NAMES: Array[String] = [
	"base_damage", "fire_rate", "base_range",
	"area_of_effect", "pierce_count", "chain_targets",
]


func _ready() -> void:
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")
	_selected_tower = null
	_preview_path = -1
	_state = State.HIDDEN

	SignalBus.tower_selected.connect(_on_tower_selected)
	SignalBus.tower_deselected.connect(_on_tower_deselected)
	visible = false

	_clear_children(self)
	_build_ui()
	_apply_panel_style()


func _exit_tree() -> void:
	_selected_tower = null
	_stat_bars.clear()
	_path_buttons.clear()


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_ui() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 6)
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_main_vbox)

	# -- Top content (expands to push buttons down) --
	_top_vbox = VBoxContainer.new()
	_top_vbox.add_theme_constant_override("separation", 6)
	_top_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_child(_top_vbox)

	# Tower name
	_tower_name_label = Label.new()
	_tower_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _blackletter_font:
		_tower_name_label.add_theme_font_override("font", _blackletter_font)
	_tower_name_label.add_theme_font_size_override("font_size", 24)
	_tower_name_label.add_theme_color_override("font_color", ButtonStyles.PRIMARY)
	_top_vbox.add_child(_tower_name_label)

	# Targeting label (ground / ground+air)
	_targeting_label = Label.new()
	_targeting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_targeting_label.add_theme_font_size_override("font_size", 9)
	_targeting_label.add_theme_color_override("font_color", COL_MUTED)
	_top_vbox.add_child(_targeting_label)

	# Stats container
	_stats_vbox = VBoxContainer.new()
	_stats_vbox.add_theme_constant_override("separation", 3)
	_top_vbox.add_child(_stats_vbox)

	# Info area (upgrade description + effect unlocks, between stats and buttons)
	_info_vbox = VBoxContainer.new()
	_info_vbox.add_theme_constant_override("separation", 3)
	_top_vbox.add_child(_info_vbox)

	# -- Bottom content (pinned to bottom) --
	_bottom_vbox = VBoxContainer.new()
	_bottom_vbox.add_theme_constant_override("separation", 4)
	_main_vbox.add_child(_bottom_vbox)

	# Path buttons
	_path_hbox = HBoxContainer.new()
	_path_hbox.add_theme_constant_override("separation", 6)
	_path_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom_vbox.add_child(_path_hbox)

	# Sell button
	_sell_button = Button.new()
	_sell_button.pressed.connect(_on_sell_pressed)
	ButtonStyles.apply_subtle(_sell_button)
	_sell_button.add_theme_font_size_override("font_size", 11)
	_sell_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bottom_vbox.add_child(_sell_button)


func _apply_panel_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_PANEL_BG.r, COL_PANEL_BG.g, COL_PANEL_BG.b, 0.92)
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_tower_selected(tower: Node2D) -> void:
	if not is_instance_valid(tower) or not tower is BaseTower:
		return
	_selected_tower = tower
	_preview_path = -1
	_state = State.STATS
	_refresh()
	visible = true


func _on_tower_deselected() -> void:
	_selected_tower = null
	_preview_path = -1
	_state = State.HIDDEN
	if is_inside_tree():
		visible = false


# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if not is_instance_valid(_selected_tower) or not _selected_tower.tower_data:
		return

	var td := _selected_tower.tower_data
	_tower_name_label.text = td.get_display_name()
	_sell_button.text = "SELL (" + EconomyManager.format_cost(_selected_tower.get_sell_value()) + ")"

	if td.can_target_flying:
		_targeting_label.text = "\u25bc\u25b2  Ground + Air"
	else:
		_targeting_label.text = "\u25bc  Ground Only"

	_rebuild_stat_bars()
	_rebuild_path_buttons()

	if _preview_path >= 0:
		_show_preview(_preview_path)
	else:
		_hide_preview()


# ---------------------------------------------------------------------------
# Stat bars
# ---------------------------------------------------------------------------

func _rebuild_stat_bars() -> void:
	_clear_children(_stats_vbox)
	_stat_bars.clear()

	for stat_name in _get_visible_stats():
		var current_val := _get_tower_stat(stat_name)
		var max_val: float = STAT_MAX.get(stat_name, 100.0)
		var ratio := clampf(current_val / max_val, 0.0, 1.0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var label := Label.new()
		label.text = STAT_LABELS.get(stat_name, stat_name.to_upper())
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", COL_MUTED)
		label.custom_minimum_size.x = 58
		row.add_child(label)

		var bar := Control.new()
		bar.custom_minimum_size = Vector2(120, BAR_HEIGHT)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.set_meta("ratio", ratio)
		bar.set_meta("preview_ratio", -1.0)
		bar.draw.connect(_draw_bar.bind(bar))
		row.add_child(bar)

		var val_label := Label.new()
		val_label.text = _format_stat(stat_name, current_val)
		val_label.add_theme_font_size_override("font_size", 9)
		val_label.add_theme_color_override("font_color", Color.WHITE)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_label.custom_minimum_size.x = 46
		row.add_child(val_label)

		_stats_vbox.add_child(row)
		_stat_bars.append({
			"name": stat_name,
			"bar": bar,
			"value_label": val_label,
			"max_val": max_val,
		})


# ---------------------------------------------------------------------------
# Path buttons
# ---------------------------------------------------------------------------

func _rebuild_path_buttons() -> void:
	_clear_children(_path_hbox)
	_path_buttons.clear()

	if not is_instance_valid(_selected_tower) or not _selected_tower.tower_data:
		return
	var paths := _selected_tower.tower_data.upgrade_paths
	var inner_w := PANEL_WIDTH - 28.0 - 4.0
	var col_w := (inner_w - 6.0 * maxf(paths.size() - 1, 0)) / maxf(paths.size(), 1)

	for path_i in paths.size():
		var path := paths[path_i]
		var current_tier: int = _selected_tower.upgrade.path_tiers[path_i]

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.custom_minimum_size.x = col_w

		var header := Label.new()
		header.text = path.path_name + "  " + str(current_tier) + "/" + str(path.tiers.size())
		header.add_theme_font_size_override("font_size", 8)
		header.add_theme_color_override("font_color", COL_MUTED)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(header)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(col_w, 36)
		btn.clip_text = true

		if current_tier < path.tiers.size():
			var tier_data := path.tiers[current_tier]
			var can_afford := _selected_tower.upgrade.can_upgrade_path(path_i)
			var is_locked := not UpgradeRegistry.can_upgrade(
				_selected_tower.upgrade.path_tiers, path_i,
				_selected_tower.upgrade.max_paths_used,
				_selected_tower.upgrade.max_deep_tier)

			if _preview_path == path_i:
				btn.text = "Authorize " + EconomyManager.format_cost(tier_data.cost)
				ButtonStyles.apply_primary(btn)
				if not can_afford:
					btn.disabled = true
					btn.add_theme_color_override("font_color", COL_MUTED)
			else:
				btn.text = tier_data.tier_name + "  " + EconomyManager.format_cost(tier_data.cost)
				ButtonStyles.apply_accent(btn)
				if not can_afford or is_locked:
					btn.disabled = true
					btn.add_theme_color_override("font_color", COL_MUTED)

			btn.pressed.connect(_on_path_btn_pressed.bind(path_i))
		else:
			btn.text = "Maxed"
			btn.disabled = true
			ButtonStyles.apply_utility(btn)
			btn.add_theme_color_override("font_color", Color("#A0D8A0"))

		btn.add_theme_font_size_override("font_size", 13)

		col.add_child(btn)
		_path_hbox.add_child(col)
		_path_buttons.append(btn)


func _on_path_btn_pressed(path_index: int) -> void:
	if _preview_path == path_index:
		_do_upgrade(path_index)
	else:
		_preview_path = path_index
		_state = State.PREVIEW
		_refresh()


func _do_upgrade(path_index: int) -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.upgrade.do_upgrade(path_index)
		_preview_path = -1
		_state = State.STATS
		_refresh()


# ---------------------------------------------------------------------------
# Preview: green deltas on stat bars + info area
# ---------------------------------------------------------------------------

func _show_preview(path_index: int) -> void:
	_clear_children(_info_vbox)

	if not is_instance_valid(_selected_tower) or not _selected_tower.tower_data:
		return
	var paths := _selected_tower.tower_data.upgrade_paths
	if path_index >= paths.size():
		return
	var path := paths[path_index]
	var current_tier: int = _selected_tower.upgrade.path_tiers[path_index]
	if current_tier >= path.tiers.size():
		return
	var tier_data := path.tiers[current_tier]

	# Update stat bar green deltas + value labels
	_update_row1_previews(tier_data.stat_modifiers)

	# -- Info area: description + effect unlocks --

	if tier_data.description:
		var desc := Label.new()
		desc.text = tier_data.description
		desc.add_theme_font_size_override("font_size", 9)
		desc.add_theme_color_override("font_color", COL_MUTED)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_vbox.add_child(desc)

	if tier_data.unlocks_ability:
		var effect := tier_data.unlocks_ability
		var effect_label := Label.new()
		var effect_name: String = Enums.StatusEffectType.keys()[effect.effect_type]
		var effect_text := "UNLOCKS: " + effect_name

		match effect.effect_type:
			Enums.StatusEffectType.POISON, Enums.StatusEffectType.BURN:
				effect_text += " (" + str(effect.potency) + " DPS, " + str(effect.duration) + "s)"
			Enums.StatusEffectType.SLOW:
				effect_text += " (" + str(int(effect.potency * 100)) + "%, " + str(effect.duration) + "s)"
			_:
				effect_text += " (" + str(effect.potency) + ", " + str(effect.duration) + "s)"

		effect_label.text = effect_text
		effect_label.add_theme_font_size_override("font_size", 10)
		effect_label.add_theme_color_override("font_color", Color.WHITE)
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_vbox.add_child(effect_label)


func _hide_preview() -> void:
	_clear_children(_info_vbox)
	for bar_data in _stat_bars:
		if not is_instance_valid(bar_data["bar"]):
			continue
		bar_data["bar"].set_meta("preview_ratio", -1.0)
		bar_data["bar"].queue_redraw()
		bar_data["value_label"].add_theme_color_override("font_color", Color.WHITE)
		var current_val := _get_tower_stat(bar_data["name"])
		bar_data["value_label"].text = _format_stat(bar_data["name"], current_val)


func _update_row1_previews(extra_mods: Array[StatModifierData]) -> void:
	for bar_data in _stat_bars:
		if not is_instance_valid(bar_data["bar"]):
			continue
		var stat_name: String = bar_data["name"]
		var current_val := _get_tower_stat(stat_name)
		var preview_val := _compute_preview_stat(stat_name, extra_mods)
		var max_val: float = bar_data["max_val"]

		if absf(preview_val - current_val) > 0.01:
			var preview_ratio := clampf(preview_val / max_val, 0.0, 1.0)
			bar_data["bar"].set_meta("preview_ratio", preview_ratio)
			bar_data["value_label"].text = _format_stat(stat_name, current_val) + " > " + _format_stat(stat_name, preview_val)
			bar_data["value_label"].add_theme_color_override("font_color", COL_BAR_GREEN)
		else:
			bar_data["bar"].set_meta("preview_ratio", -1.0)
			bar_data["value_label"].text = _format_stat(stat_name, current_val)
			bar_data["value_label"].add_theme_color_override("font_color", Color.WHITE)
		bar_data["bar"].queue_redraw()


# ---------------------------------------------------------------------------
# Bar drawing
# ---------------------------------------------------------------------------

func _draw_bar(bar: Control) -> void:
	if not is_instance_valid(bar):
		return
	var w := bar.size.x
	var h := bar.size.y
	var ratio: float = bar.get_meta("ratio", 0.0)
	var preview_ratio: float = bar.get_meta("preview_ratio", -1.0)

	bar.draw_rect(Rect2(0, 0, w, h), COL_BAR_BG)

	var fill_w := ratio * w
	if fill_w > 0.5:
		bar.draw_rect(Rect2(0, 0, fill_w, h), COL_BAR_FILL)
		bar.draw_rect(Rect2(0, 0, fill_w, 1), COL_BAR_SPEC)

	if preview_ratio > ratio:
		var delta_x := fill_w
		var delta_w := (preview_ratio - ratio) * w
		bar.draw_rect(Rect2(delta_x, 0, delta_w, h), COL_BAR_GREEN)

	bar.draw_rect(Rect2(0, 0, w, h), COL_BAR_BORDER, false, 1.0)


# ---------------------------------------------------------------------------
# Stat computation
# ---------------------------------------------------------------------------

func _get_visible_stats() -> Array[String]:
	if not is_instance_valid(_selected_tower) or not _selected_tower.tower_data:
		return []
	var td := _selected_tower.tower_data
	var stats: Array[String] = ["base_damage", "fire_rate", "base_range"]

	if td.area_of_effect > 0 or _selected_tower.weapon.final_aoe > 0:
		stats.append("area_of_effect")
	if td.pierce_count > 1 or _selected_tower.weapon.final_pierce > 1:
		stats.append("pierce_count")
	if td.chain_targets > 0 or _selected_tower.weapon.chain_targets > 0:
		stats.append("chain_targets")
	if _get_slow_potency() > 0.0:
		stats.append("slow")

	return stats


func _get_tower_stat(stat_name: String) -> float:
	if not is_instance_valid(_selected_tower):
		return 0.0
	match stat_name:
		"base_damage":
			return _selected_tower.weapon.final_damage
		"fire_rate":
			return _selected_tower.get_current_fire_rate()
		"base_range":
			return _selected_tower.get_current_range()
		"area_of_effect":
			return _selected_tower.weapon.final_aoe
		"pierce_count":
			return float(_selected_tower.weapon.final_pierce)
		"chain_targets":
			return float(_selected_tower.weapon.chain_targets)
		"slow":
			return _get_slow_potency()
	return 0.0


func _get_slow_potency() -> float:
	if not is_instance_valid(_selected_tower):
		return 0.0
	var max_slow := 0.0
	for eff in _selected_tower.weapon.on_hit_effects:
		if eff.effect_type == Enums.StatusEffectType.SLOW:
			max_slow = maxf(max_slow, eff.potency)
	return max_slow


func _compute_preview_stat(stat_name: String, extra_mods: Array[StatModifierData]) -> float:
	if not is_instance_valid(_selected_tower) or not _selected_tower.tower_data:
		return 0.0
	var td := _selected_tower.tower_data

	var base_val: float
	match stat_name:
		"base_damage": base_val = td.base_damage
		"fire_rate": base_val = td.fire_rate
		"base_range": base_val = td.base_range
		"area_of_effect": base_val = td.area_of_effect
		"pierce_count": base_val = float(td.pierce_count)
		"chain_targets": base_val = float(td.chain_targets)
		"slow": return _get_slow_potency()
		_: return 0.0

	var result := base_val
	for mod in _selected_tower.upgrade.active_modifiers:
		if mod.stat_name == stat_name:
			result = _apply_mod(result, mod)
	for mod in extra_mods:
		if mod.stat_name == stat_name:
			result = _apply_mod(result, mod)

	if stat_name == "base_damage":
		result *= _selected_tower.weapon.synergy_damage_mult
	elif stat_name == "fire_rate":
		result *= _selected_tower._synergy_rate_mult

	return result


func _apply_mod(base: float, mod: StatModifierData) -> float:
	match mod.operation:
		Enums.ModifierOp.ADD:
			return base + mod.value
		Enums.ModifierOp.MULTIPLY:
			return base * mod.value
		Enums.ModifierOp.SET:
			return mod.value
	return base


func _format_stat(stat_name: String, value: float) -> String:
	match stat_name:
		"pierce_count", "chain_targets":
			return str(int(value))
		"slow":
			return str(int(value * 100)) + "%"
		_:
			if absf(value - roundf(value)) < 0.01:
				return str(int(value))
			return str(snapped(value, 0.1))


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_sell_pressed() -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.sell()
		SignalBus.tower_deselected.emit()
