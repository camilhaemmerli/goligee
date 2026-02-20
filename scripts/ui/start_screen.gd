extends Control
## Start screen — matches Figma design (Frame 2, node 7:90).
## Two-layer title (rust shadow + white front), protest-scene background,
## rust-coloured start button with dark border.

var _blackletter_font: Font
var _music_player: AudioStreamPlayer


const THEME_SONG_PATH = "res://assets/audio/music/theme_song.mp3"
const MUSIC_FADE_IN = 2.0
const MUSIC_FADE_OUT = 1.2
const MUSIC_VOLUME_DB = -6.0


var _fade_overlay: ColorRect
var _btn_glow_tween: Tween


func _ready() -> void:
	_blackletter_font = load("res://assets/fonts/PirataOne-Regular.ttf")
	mouse_default_cursor_shape = CURSOR_ARROW

	_setup_background()
	_setup_title()
	_setup_start_button()
	_setup_fade_in()
	_setup_music()


# ---------------------------------------------------------------------------
# Background
# ---------------------------------------------------------------------------

func _setup_background() -> void:
	# Dark fill behind everything
	var fill := ColorRect.new()
	fill.color = Color("#0E0E12")
	fill.anchors_preset = PRESET_FULL_RECT
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fill)

	var bg_path := "res://assets/ui/start_bg.png"
	var tex := load(bg_path) as Texture2D
	if tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(tex_rect)
		print("BG loaded: ", tex.get_width(), "x", tex.get_height(), " rect=", tex_rect.size)
	else:
		push_warning("start_bg.png failed to load")


func _setup_gradient_placeholder() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color("#0E0E12"), Color("#1A1820"), Color("#292030"),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])

	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = 960
	grad_tex.height = 540

	var tex_rect := TextureRect.new()
	tex_rect.texture = grad_tex
	tex_rect.anchors_preset = PRESET_FULL_RECT
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(tex_rect)


# ---------------------------------------------------------------------------
# Title — pre-rendered PNG from Figma (exact stroke/border match)
# ---------------------------------------------------------------------------

func _setup_title() -> void:
	var title_path := "res://assets/ui/title.png"
	if not ResourceLoader.exists(title_path):
		return

	var title_tex := load(title_path) as Texture2D
	var tex_rect := TextureRect.new()
	tex_rect.texture = title_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT

	# Size the title to ~50% of viewport width, centered in upper area
	var title_w := 460.0
	var title_h := title_w * (float(title_tex.get_height()) / title_tex.get_width())
	tex_rect.set_anchors_preset(PRESET_CENTER_TOP)
	tex_rect.position = Vector2(-title_w / 2.0, 30)
	tex_rect.size = Vector2(title_w, title_h)
	tex_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(tex_rect)

	# Dramatic fade-in: hold black, then slowly reveal title with subtle scale
	tex_rect.modulate.a = 0.0
	tex_rect.pivot_offset = Vector2(title_w / 2.0, title_h / 2.0)
	tex_rect.scale = Vector2(1.08, 1.08)
	var tween := create_tween()
	tween.tween_interval(1.5)  # hold in darkness
	tween.tween_property(tex_rect, "modulate:a", 1.0, 2.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(tex_rect, "scale", Vector2.ONE, 2.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# ---------------------------------------------------------------------------
# Start button
# ---------------------------------------------------------------------------

func _setup_start_button() -> void:
	var btn := Button.new()
	btn.text = "Start"
	btn.add_theme_font_override("font", _blackletter_font)
	btn.add_theme_font_size_override("font_size", 34)

	# Apply primary 3D bevel, then override margins + shadow for the big start btn
	ButtonStyles.apply_primary(btn)

	# Larger margins and shadow for the hero button
	var normal := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	normal.content_margin_left = 40
	normal.content_margin_right = 40
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.shadow_size = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := btn.get_theme_stylebox("hover").duplicate() as StyleBoxFlat
	hover.content_margin_left = 40
	hover.content_margin_right = 40
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	hover.shadow_size = 12
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := btn.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	pressed.content_margin_left = 40
	pressed.content_margin_right = 40
	pressed.content_margin_top = 9
	pressed.content_margin_bottom = 7
	btn.add_theme_stylebox_override("pressed", pressed)

	# Centered, near bottom (~75% down the screen)
	btn.set_anchors_preset(PRESET_CENTER_BOTTOM)
	btn.position.y = -120
	btn.grow_horizontal = GROW_DIRECTION_BOTH

	btn.pressed.connect(_on_start_pressed)
	add_child(btn)

	# Start invisible, fade in well after title has emerged from the black
	btn.modulate.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_interval(3.8)  # black(1s) + title reveal(~2.8s)
	fade_tween.tween_property(btn, "modulate:a", 1.0, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_callback(_start_glow_pulse.bind(btn, normal))


func _start_glow_pulse(btn: Button, style: StyleBoxFlat) -> void:
	# Eerie pulsating border glow — cycles between dim and bright
	var dim_border := Color("#B03030")
	var bright_border := Color("#F08070")
	var dim_shadow := Color("#D0404060")
	var bright_shadow := Color("#D04040D0")

	_btn_glow_tween = create_tween().set_loops()
	_btn_glow_tween.tween_method(func(t: float) -> void:
		style.border_color = dim_border.lerp(bright_border, t)
		style.shadow_color = dim_shadow.lerp(bright_shadow, t)
		style.shadow_size = int(lerpf(6.0, 14.0, t))
	, 0.0, 1.0, 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_btn_glow_tween.tween_method(func(t: float) -> void:
		style.border_color = bright_border.lerp(dim_border, t)
		style.shadow_color = bright_shadow.lerp(dim_shadow, t)
		style.shadow_size = int(lerpf(14.0, 6.0, t))
	, 0.0, 1.0, 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _setup_fade_in() -> void:
	# Full-screen black overlay — holds pure black, then slowly dissolves
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.anchors_preset = PRESET_FULL_RECT
	_fade_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)

	var tween := create_tween()
	tween.tween_interval(1.0)  # sit in darkness
	tween.tween_property(_fade_overlay, "color:a", 0.0, 3.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_fade_overlay.queue_free)


func _on_start_pressed() -> void:
	if _btn_glow_tween:
		_btn_glow_tween.kill()
	# Fade out music then switch scene.
	if _music_player and _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, MUSIC_FADE_OUT)
		tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main/game.tscn"))
	else:
		get_tree().change_scene_to_file("res://scenes/main/game.tscn")


# ---------------------------------------------------------------------------
# Theme music
# ---------------------------------------------------------------------------

func _setup_music() -> void:
	if not ResourceLoader.exists(THEME_SONG_PATH):
		return

	var stream := load(THEME_SONG_PATH) as AudioStream
	if not stream:
		return

	# Enable looping (AudioStreamMP3)
	if stream.has_method("set_loop"):
		stream.set("loop", true)
	elif "loop" in stream:
		stream.loop = true

	_music_player = AudioStreamPlayer.new()
	_music_player.stream = stream
	_music_player.bus = &"Master"
	_music_player.volume_db = -40.0  # Start silent
	add_child(_music_player)
	_music_player.play()

	# Fade in
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
