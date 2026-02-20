extends Node
## Manages the active visual theme. Provides skin lookups and shader
## parameter application so gameplay code never references visual assets directly.

signal theme_changed()

var current_theme: ThemeData

# 8-direction turret order matches BaseTower.DIRS.
const TOWER_TURRET_DIRS = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]

# Temporary asset folder aliases to keep older naming conventions working.
const TOWER_ASSET_ALIASES = {
	"surveillance_hub": "surveillance",
	"lrad_cannon": "lrad",
	"microwave_emitter": "microwave",
}

# Per-tower turret Y offset (turret drawn above base).
const TURRET_Y_OFFSETS = {
	"rubber_bullet": 0.0,
	"taser_grid": -14.0,
	"surveillance": -18.0,
	"pepper_spray": -14.0,
	"microwave": -13.0,
	"water_cannon": -14.0,
	"lrad": -14.0,
	"tear_gas": -14.0,
}


func apply_theme(theme: ThemeData) -> void:
	current_theme = theme
	apply_clear_color()
	theme_changed.emit()


func populate_tower_skins_from_assets(theme: ThemeData, tower_list: Array[TowerData]) -> void:
	"""Populate tower skins from on-disk sprites if present."""
	if not theme:
		return
	if not theme.tower_skins:
		theme.tower_skins = {}

	for tower_data in tower_list:
		if not tower_data or not tower_data.tower_id:
			continue
		if theme.tower_skins.has(tower_data.tower_id):
			continue

		var skin := _load_tower_skin_from_assets(tower_data)
		if skin:
			theme.tower_skins[tower_data.tower_id] = skin


func _load_tower_skin_from_assets(tower_data: TowerData) -> TowerSkinData:
	var tower_id := tower_data.tower_id
	var folder_id := tower_id
	var base_path := "res://assets/sprites/towers/%s/base.png" % folder_id
	if not ResourceLoader.exists(base_path):
		var alias: String = TOWER_ASSET_ALIASES.get(tower_id, "")
		if alias != "":
			folder_id = alias
			base_path = "res://assets/sprites/towers/%s/base.png" % folder_id

	if not ResourceLoader.exists(base_path):
		return null

	var base_tex := load(base_path) as Texture2D
	if not base_tex:
		return null

	var turret_textures: Array[Texture2D] = []
	for dir in TOWER_TURRET_DIRS:
		var turret_path := "res://assets/sprites/towers/%s/turret_%s.png" % [folder_id, dir]
		if not ResourceLoader.exists(turret_path):
			return null
		var turret_tex := load(turret_path) as Texture2D
		if not turret_tex:
			return null
		turret_textures.append(turret_tex)

	# Load optional firing-pose turret textures
	var fire_turret_textures: Array[Texture2D] = []
	var first_fire_path := "res://assets/sprites/towers/%s/turret_fire_%s.png" % [folder_id, TOWER_TURRET_DIRS[0]]
	if ResourceLoader.exists(first_fire_path):
		for dir in TOWER_TURRET_DIRS:
			var fire_path := "res://assets/sprites/towers/%s/turret_fire_%s.png" % [folder_id, dir]
			if ResourceLoader.exists(fire_path):
				var fire_tex := load(fire_path) as Texture2D
				if fire_tex:
					fire_turret_textures.append(fire_tex)

	var skin := TowerSkinData.new()
	skin.display_name = tower_data.tower_name
	skin.description = tower_data.description
	skin.base_texture = base_tex
	skin.turret_textures = turret_textures
	if fire_turret_textures.size() == 8:
		skin.fire_turret_textures = fire_turret_textures

	# Apply per-tower turret Y offset (try folder_id first, then tower_id).
	if TURRET_Y_OFFSETS.has(folder_id):
		skin.turret_y_offset = TURRET_Y_OFFSETS[folder_id]
	elif TURRET_Y_OFFSETS.has(tower_id):
		skin.turret_y_offset = TURRET_Y_OFFSETS[tower_id]

	var icon := _load_tower_icon(tower_id, folder_id)
	if icon:
		skin.icon = icon

	return skin


func _load_tower_icon(tower_id: String, folder_id: String) -> Texture2D:
	# Symbolic icons first (smooth 128px silhouettes)
	var symbolic := "res://assets/sprites/ui/symbolic_tower_%s.png" % tower_id
	if ResourceLoader.exists(symbolic):
		return load(symbolic) as Texture2D
	if folder_id != tower_id:
		var symbolic_alias := "res://assets/sprites/ui/symbolic_tower_%s.png" % folder_id
		if ResourceLoader.exists(symbolic_alias):
			return load(symbolic_alias) as Texture2D
	var primary := "res://assets/sprites/ui/icon_tower_%s.png" % tower_id
	if ResourceLoader.exists(primary):
		return load(primary) as Texture2D
	if folder_id != tower_id:
		var alias := "res://assets/sprites/ui/icon_tower_%s.png" % folder_id
		if ResourceLoader.exists(alias):
			return load(alias) as Texture2D
	return null


func populate_enemy_skins_from_assets(theme: ThemeData) -> void:
	"""Populate enemy skins from on-disk walk sprites if present."""
	if not theme:
		return
	if not theme.enemy_skins:
		theme.enemy_skins = {}

	var base_dir := "res://assets/sprites/enemies/"
	var dir := DirAccess.open(base_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir() and not folder.begins_with("_"):
			if not theme.enemy_skins.has(folder):
				var skin := _load_enemy_skin_from_assets(folder)
				if skin:
					theme.enemy_skins[folder] = skin
		folder = dir.get_next()
	dir.list_dir_end()


const ENEMY_WALK_DIRS = ["e", "ne", "n", "nw", "w", "sw", "s", "se"]

func _load_enemy_skin_from_assets(enemy_id: String) -> EnemySkinData:
	var folder := "res://assets/sprites/enemies/%s/" % enemy_id
	# Check that at least the SE walk frame exists
	var test_path := folder + "walk_se_01.png"
	if not ResourceLoader.exists(test_path):
		return null

	var frames := SpriteFrames.new()
	# Remove the default animation that SpriteFrames creates
	if frames.has_animation("default"):
		frames.remove_animation("default")

	for anim_dir in ENEMY_WALK_DIRS:
		var anim_name: String = "walk_" + anim_dir
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 5.0)
		# Load all frames for this direction (walk_{dir}_01.png, walk_{dir}_02.png, ...)
		var frame_idx := 1
		while true:
			var frame_path := folder + "walk_%s_%02d.png" % [anim_dir, frame_idx]
			if not ResourceLoader.exists(frame_path):
				break
			var tex := load(frame_path) as Texture2D
			if tex:
				frames.add_frame(anim_name, tex)
			frame_idx += 1

	var skin := EnemySkinData.new()
	skin.display_name = enemy_id.capitalize().replace("_", " ")
	skin.description = ""
	skin.animation_frames = frames
	skin.tint = Color.WHITE
	return skin


func get_palette() -> ThemePalette:
	if current_theme and current_theme.palette:
		return current_theme.palette
	return null


func get_tower_skin(tower_id: String) -> TowerSkinData:
	if current_theme and current_theme.tower_skins.has(tower_id):
		return current_theme.tower_skins[tower_id]
	return null


func get_enemy_skin(enemy_id: String) -> EnemySkinData:
	if current_theme and current_theme.enemy_skins.has(enemy_id):
		return current_theme.enemy_skins[enemy_id]
	return null




var _portrait_cache: Dictionary = {}

func get_wave_portrait(enemy_id: String) -> Texture2D:
	if _portrait_cache.has(enemy_id):
		return _portrait_cache[enemy_id]
	# Try dedicated portrait first
	var portrait_path := "res://assets/sprites/ui/wave_portrait_%s.png" % enemy_id
	if ResourceLoader.exists(portrait_path):
		var tex := load(portrait_path) as Texture2D
		if tex:
			_portrait_cache[enemy_id] = tex
			return tex
	# Fall back to walk_se_01 from enemy sprite folder
	var fallback_path := "res://assets/sprites/enemies/%s/walk_se_01.png" % enemy_id
	if ResourceLoader.exists(fallback_path):
		var tex := load(fallback_path) as Texture2D
		if tex:
			_portrait_cache[enemy_id] = tex
			return tex
	_portrait_cache[enemy_id] = null
	return null


func get_projectile_skin(projectile_id: String) -> ProjectileSkinData:
	if current_theme and current_theme.projectile_skins.has(projectile_id):
		return current_theme.projectile_skins[projectile_id]
	return null


func apply_shader_params(material: ShaderMaterial, shader_name: String) -> void:
	if not current_theme:
		return

	var params: Dictionary = {}
	match shader_name:
		"fog":
			var palette := get_palette()
			if palette:
				params["fog_color_near"] = palette.fog_near
				params["fog_color_far"] = palette.fog_far
			params.merge(current_theme.fog_params, true)
		"ground_smoke":
			var palette := get_palette()
			if palette:
				params["smoke_color"] = palette.ground_smoke_color
		"atmosphere":
			var palette := get_palette()
			if palette:
				params["tint_color"] = palette.atmosphere_tint
			params.merge(current_theme.atmosphere_params, true)
		"damage_flash":
			params["flash_color"] = current_theme.damage_flash_color

	for key in params:
		material.set_shader_parameter(key, params[key])


func get_damage_type_color(damage_type: Enums.DamageType) -> Color:
	var palette := get_palette()
	if palette:
		return palette.get_damage_type_color(damage_type)
	return Color.WHITE


func apply_clear_color() -> void:
	var palette := get_palette()
	if palette:
		RenderingServer.set_default_clear_color(palette.clear_color)
