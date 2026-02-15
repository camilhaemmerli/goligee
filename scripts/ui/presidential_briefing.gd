extends CanvasLayer
class_name ManifestationBriefing
## Modal popup: wave 1 shows a presidential welcome; subsequent groups show
## the manifestation leader taunting the player. Pauses the game tree while
## visible; dismissed with a single button.

const PRESIDENT_WELCOME := "These... AGITATORS are at my gates! I built this palace with taxpayer money — MY money — and I will NOT let some sign-waving delinquents ruin the view from my gold-plated balcony. You there, yes YOU — make them go away. Permanently."

var _blackletter_font: Font
var _panel: PanelContainer


func _ready() -> void:
	layer = 10
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")


func show_briefing(wave_number: int) -> void:
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	var group := WaveNames.get_manifestation_group(wave_number)
	var is_president := (wave_number == 1)

	var leader_id := WaveNames.get_manifestation_leader_id(wave_number)
	var manif_name := "PRESIDENTIAL BRIEFING" if is_president else WaveNames.get_manifestation_name(wave_number)
	var leader_msg := PRESIDENT_WELCOME if is_president else WaveNames.get_leader_message(group)
	var display_name := "THE PRESIDENT" if is_president else leader_id.to_upper().replace("_", " ")
	var btn_text := "YES, MR. PRESIDENT" if is_president else "DEPLOY COUNTERMEASURES"
	var title_color := Color("#808898") if is_president else Color("#D8A040")

	# --- Backdrop (full-screen darken) ---
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.8)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# --- CenterContainer to properly center the panel ---
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# --- Panel ---
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 280)

	# Concrete-grey style
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3A3A3E")
	style.border_color = Color("#1A1A1E")
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	# Inner frame (lighter border inset)
	var inner_frame := PanelContainer.new()
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color("#3A3A3E")
	inner_style.border_color = Color("#5A5A60")
	inner_style.border_width_left = 2
	inner_style.border_width_right = 2
	inner_style.border_width_top = 2
	inner_style.border_width_bottom = 2
	inner_style.content_margin_left = 10
	inner_style.content_margin_right = 10
	inner_style.content_margin_top = 10
	inner_style.content_margin_bottom = 10
	inner_frame.add_theme_stylebox_override("panel", inner_style)
	_panel.add_child(inner_frame)

	# Crack lines (procedural decoration)
	_add_crack_lines(inner_frame)

	# Main vertical layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	inner_frame.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = manif_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", title_color)
	if _blackletter_font:
		title.add_theme_font_override("font", _blackletter_font)
	vbox.add_child(title)

	# Content row: portrait + message
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# Portrait column: portrait + leader name
	var portrait_col := VBoxContainer.new()
	portrait_col.add_theme_constant_override("separation", 2)
	content.add_child(portrait_col)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if is_president:
		var pres_path := "res://assets/ui/president_portrait.png"
		if ResourceLoader.exists(pres_path):
			portrait.texture = load(pres_path)
		else:
			portrait.texture = _make_placeholder_portrait()
	else:
		var portrait_tex := ThemeManager.get_wave_portrait(leader_id)
		if portrait_tex:
			portrait.texture = portrait_tex
		else:
			portrait.texture = _make_placeholder_portrait()
	portrait_col.add_child(portrait)

	# Leader name label
	var leader_label := Label.new()
	leader_label.text = display_name
	leader_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leader_label.add_theme_font_size_override("font_size", 7)
	leader_label.add_theme_color_override("font_color", Color("#808898"))
	leader_label.custom_minimum_size = Vector2(64, 0)
	portrait_col.add_child(leader_label)

	# Message
	var message := RichTextLabel.new()
	message.bbcode_enabled = false
	message.fit_content = true
	message.scroll_active = false
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.add_theme_font_size_override("normal_font_size", 9)
	message.add_theme_color_override("default_color", Color.WHITE)
	message.text = leader_msg
	content.add_child(message)

	# Dismiss button
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(220, 32)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _blackletter_font:
		btn.add_theme_font_override("font", _blackletter_font)
	btn.add_theme_font_size_override("font_size", 11)

	# Button style — rust bg, dark border
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color("#8B3A2A") if state_name != "hover" else Color("#A04030")
		btn_style.border_color = Color("#1A1A1E")
		btn_style.border_width_left = 2
		btn_style.border_width_right = 2
		btn_style.border_width_top = 2
		btn_style.border_width_bottom = 2
		btn_style.content_margin_left = 8
		btn_style.content_margin_right = 8
		btn_style.content_margin_top = 4
		btn_style.content_margin_bottom = 4
		btn.add_theme_stylebox_override(state_name, btn_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color("#FFD080"))
	btn.pressed.connect(_dismiss)
	vbox.add_child(btn)

	# Entrance animation
	_panel.pivot_offset = _panel.custom_minimum_size / 2.0
	_panel.scale = Vector2(0.9, 0.9)
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3) \
		.set_ease(Tween.EASE_OUT)


func _dismiss() -> void:
	get_tree().paused = false
	SignalBus.presidential_briefing_dismissed.emit()
	queue_free()


func _make_placeholder_portrait() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color("#2A2A30"))
	# Raised fist silhouette
	for y in range(16, 48):
		for x in range(22, 42):
			var dx := (x - 32.0) / 10.0
			var dy := (y - 32.0) / 16.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color("#8B3A2A"))
	return ImageTexture.create_from_image(img)


func _add_crack_lines(parent: Control) -> void:
	var cracks: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0, 20), Vector2(8, 25), Vector2(5, 35)]),
		PackedVector2Array([Vector2(370, 0), Vector2(365, 12), Vector2(372, 18)]),
		PackedVector2Array([Vector2(50, 230), Vector2(60, 225), Vector2(55, 220)]),
	]
	for pts in cracks:
		var line := Line2D.new()
		line.points = pts
		line.width = 1.0
		line.default_color = Color("#2A2A2E")
		line.z_index = 1
		parent.add_child(line)
