extends CanvasLayer
class_name ManifestationBriefing
## Modal popup: wave 1 shows a presidential letter then chains to a demonstrator
## taunt; subsequent manifestation groups (wave 6, 11, …) show only the
## demonstrator taunt. Pauses the game tree while visible.

const PRESIDENT_WELCOME := "These... AGITATORS are at my gates! I built this palace with taxpayer money — MY money — and I will NOT let some sign-waving delinquents ruin the view from my gold-plated balcony. You there, yes YOU — make them go away. Permanently."

# Paper/parchment palette
const PAPER_BG      := Color("#F0E8D0")
const PAPER_TEXT     := Color("#2A1A0A")
const PAPER_BORDER   := Color("#8B7355")
const PAPER_ACCENT   := Color("#C4A96B")
const PAPER_SUBTLE   := Color("#6B5A3E")

# Concrete palette (demonstrator panels)
const CONCRETE_BG    := Color("#3A3A3E")
const CONCRETE_BORDER := Color("#1A1A1E")
const CONCRETE_INNER  := Color("#5A5A60")

const PRESIDENTIAL_SIZE := Vector2(640, 480)
const DEMONSTRATOR_SIZE := Vector2(600, 420)

var _blackletter_font: Font
var _panel: PanelContainer
var _wave_number_stored: int
var _is_second_briefing: bool = false


func _ready() -> void:
	layer = 10
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")


func show_briefing(wave_number: int) -> void:
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wave_number_stored = wave_number

	_build_outer_scaffold()

	if wave_number == 1:
		_build_presidential_letter()
	else:
		_build_demonstrator_briefing()

	_animate_entrance()


# ---------------------------------------------------------------------------
# Scaffold: backdrop + center container + _panel shell
# ---------------------------------------------------------------------------
func _build_outer_scaffold() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.8)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.name = "Center"
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	center.add_child(_panel)


# ---------------------------------------------------------------------------
# Presidential letter (wave 1 — first popup)
# ---------------------------------------------------------------------------
func _build_presidential_letter() -> void:
	_panel.custom_minimum_size = PRESIDENTIAL_SIZE

	# Outer panel — parchment with brown border
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_BG
	style.border_color = PAPER_BORDER
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)

	# Inner frame — thinner accent border
	var inner_frame := PanelContainer.new()
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = PAPER_BG
	inner_style.border_color = PAPER_ACCENT
	inner_style.border_width_left = 2
	inner_style.border_width_right = 2
	inner_style.border_width_top = 2
	inner_style.border_width_bottom = 2
	inner_style.content_margin_left = 18
	inner_style.content_margin_right = 18
	inner_style.content_margin_top = 18
	inner_style.content_margin_bottom = 18
	inner_frame.add_theme_stylebox_override("panel", inner_style)
	_panel.add_child(inner_frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	inner_frame.add_child(vbox)

	# --- Header row: letterhead + passport photo ---
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	vbox.add_child(header_row)

	# Letterhead column
	var letterhead_col := VBoxContainer.new()
	letterhead_col.add_theme_constant_override("separation", 4)
	letterhead_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(letterhead_col)

	var office_label := Label.new()
	office_label.text = "OFFICE OF THE PRESIDENT"
	office_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	office_label.add_theme_font_size_override("font_size", 18)
	office_label.add_theme_color_override("font_color", PAPER_TEXT)
	if _blackletter_font:
		office_label.add_theme_font_override("font", _blackletter_font)
	letterhead_col.add_child(office_label)

	# Amber divider
	var divider := ColorRect.new()
	divider.color = PAPER_ACCENT
	divider.custom_minimum_size = Vector2(0, 2)
	letterhead_col.add_child(divider)

	var classification := Label.new()
	classification.text = "EYES ONLY — CLASSIFICATION: SUPREME"
	classification.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	classification.add_theme_font_size_override("font_size", 12)
	classification.add_theme_color_override("font_color", PAPER_SUBTLE)
	letterhead_col.add_child(classification)

	# Passport photo anchor
	var photo_anchor := Control.new()
	photo_anchor.custom_minimum_size = Vector2(70, 80)
	header_row.add_child(photo_anchor)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(60, 60)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = Vector2(5, 10)
	portrait.pivot_offset = Vector2(30, 30)
	portrait.rotation_degrees = -6.0
	var pres_path := "res://assets/ui/president_portrait.png"
	if ResourceLoader.exists(pres_path):
		portrait.texture = load(pres_path)
	else:
		portrait.texture = _make_placeholder_portrait()
	photo_anchor.add_child(portrait)

	# --- Salutation ---
	var salutation := Label.new()
	salutation.text = "Most Esteemed Director of Order,"
	salutation.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	salutation.add_theme_font_size_override("font_size", 14)
	salutation.add_theme_color_override("font_color", PAPER_SUBTLE)
	vbox.add_child(salutation)

	# --- Body message ---
	var message := RichTextLabel.new()
	message.bbcode_enabled = false
	message.fit_content = true
	message.scroll_active = false
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.add_theme_font_size_override("normal_font_size", 14)
	message.add_theme_color_override("default_color", PAPER_TEXT)
	message.text = PRESIDENT_WELCOME
	vbox.add_child(message)

	# --- Signature block ---
	var sig_rule := ColorRect.new()
	sig_rule.color = PAPER_BORDER
	sig_rule.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sig_rule)

	var signature := Label.new()
	signature.text = "— THE PRESIDENT"
	signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	signature.add_theme_font_size_override("font_size", 16)
	signature.add_theme_color_override("font_color", PAPER_TEXT)
	if _blackletter_font:
		signature.add_theme_font_override("font", _blackletter_font)
	vbox.add_child(signature)

	# --- Button ---
	var btn := _make_button("YES, MR. PRESIDENT")
	btn.pressed.connect(_on_first_dismiss)
	vbox.add_child(btn)


# ---------------------------------------------------------------------------
# Demonstrator briefing (wave 6+ or chained from wave 1)
# ---------------------------------------------------------------------------
func _build_demonstrator_briefing() -> void:
	var group: int
	var leader_id: String
	var manif_name: String
	var leader_msg: String

	if _is_second_briefing:
		group = 1
		leader_id = "rioter"
		manif_name = "THE FIRST GATHERING"
		leader_msg = WaveNames.get_leader_message(1)
	else:
		group = WaveNames.get_manifestation_group(_wave_number_stored)
		leader_id = WaveNames.get_manifestation_leader_id(_wave_number_stored)
		manif_name = WaveNames.get_manifestation_name(_wave_number_stored)
		leader_msg = WaveNames.get_leader_message(group)

	var display_name := leader_id.to_upper().replace("_", " ")

	_panel.custom_minimum_size = DEMONSTRATOR_SIZE

	# Outer panel — concrete grey
	var style := StyleBoxFlat.new()
	style.bg_color = CONCRETE_BG
	style.border_color = CONCRETE_BORDER
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)

	# Inner frame
	var inner_frame := PanelContainer.new()
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = CONCRETE_BG
	inner_style.border_color = CONCRETE_INNER
	inner_style.border_width_left = 2
	inner_style.border_width_right = 2
	inner_style.border_width_top = 2
	inner_style.border_width_bottom = 2
	inner_style.content_margin_left = 14
	inner_style.content_margin_right = 14
	inner_style.content_margin_top = 14
	inner_style.content_margin_bottom = 14
	inner_frame.add_theme_stylebox_override("panel", inner_style)
	_panel.add_child(inner_frame)

	# Crack lines
	_add_crack_lines(inner_frame, DEMONSTRATOR_SIZE)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	inner_frame.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = manif_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#F0F0F0"))
	if _blackletter_font:
		title.add_theme_font_override("font", _blackletter_font)
	vbox.add_child(title)

	# Content row: portrait + message
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# Portrait column
	var portrait_col := VBoxContainer.new()
	portrait_col.add_theme_constant_override("separation", 2)
	content.add_child(portrait_col)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(80, 80)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var portrait_tex := ThemeManager.get_wave_portrait(leader_id)
	if portrait_tex:
		portrait.texture = portrait_tex
	else:
		portrait.texture = _make_placeholder_portrait()
	portrait_col.add_child(portrait)

	var leader_label := Label.new()
	leader_label.text = display_name
	leader_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leader_label.add_theme_font_size_override("font_size", 11)
	leader_label.add_theme_color_override("font_color", Color("#808898"))
	leader_label.custom_minimum_size = Vector2(80, 0)
	portrait_col.add_child(leader_label)

	# Message
	var message := RichTextLabel.new()
	message.bbcode_enabled = false
	message.fit_content = true
	message.scroll_active = false
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.add_theme_font_size_override("normal_font_size", 14)
	message.add_theme_color_override("default_color", Color.WHITE)
	message.text = leader_msg
	content.add_child(message)

	# Button
	var btn := _make_button("DEPLOY COUNTERMEASURES")
	btn.pressed.connect(_dismiss)
	vbox.add_child(btn)


# ---------------------------------------------------------------------------
# Wave-1 chaining: presidential letter → demonstrator taunt
# ---------------------------------------------------------------------------
func _on_first_dismiss() -> void:
	# Remove all panel children (letter content) but keep scaffold
	for child in _panel.get_children():
		_panel.remove_child(child)
		child.free()

	_is_second_briefing = true
	_build_demonstrator_briefing()
	_animate_entrance()


# ---------------------------------------------------------------------------
# Final dismiss
# ---------------------------------------------------------------------------
func _dismiss() -> void:
	get_tree().paused = false
	SignalBus.presidential_briefing_dismissed.emit()
	queue_free()


# ---------------------------------------------------------------------------
# Entrance animation (shared)
# ---------------------------------------------------------------------------
func _animate_entrance() -> void:
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


# ---------------------------------------------------------------------------
# Shared button builder
# ---------------------------------------------------------------------------
func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 48)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _blackletter_font:
		btn.add_theme_font_override("font", _blackletter_font)
	btn.add_theme_font_size_override("font_size", 16)
	ButtonStyles.apply_primary(btn)
	return btn


# ---------------------------------------------------------------------------
# Placeholder portrait
# ---------------------------------------------------------------------------
func _make_placeholder_portrait() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color("#2A2A30"))
	for y in range(16, 48):
		for x in range(22, 42):
			var dx := (x - 32.0) / 10.0
			var dy := (y - 32.0) / 16.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color("#8B3A2A"))
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------
# Crack lines (demonstrator panels only) — relative to panel size
# ---------------------------------------------------------------------------
func _add_crack_lines(parent: Control, panel_size: Vector2) -> void:
	var w := panel_size.x
	var h := panel_size.y
	var cracks: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0, h * 0.07), Vector2(w * 0.02, h * 0.09), Vector2(w * 0.013, h * 0.125)]),
		PackedVector2Array([Vector2(w * 0.925, 0), Vector2(w * 0.912, h * 0.043), Vector2(w * 0.93, h * 0.064)]),
		PackedVector2Array([Vector2(w * 0.125, h * 0.82), Vector2(w * 0.15, h * 0.804), Vector2(w * 0.137, h * 0.786)]),
	]
	for pts in cracks:
		var line := Line2D.new()
		line.points = pts
		line.width = 1.0
		line.default_color = Color("#2A2A2E")
		line.z_index = 1
		parent.add_child(line)
