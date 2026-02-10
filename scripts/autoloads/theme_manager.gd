extends Node
## Manages the active visual theme. Provides skin lookups and shader
## parameter application so gameplay code never references visual assets directly.

signal theme_changed()

var current_theme: ThemeData

# 8-direction turret order matches BaseTower.DIRS.
const TOWER_TURRET_DIRS := ["s", "sw", "w", "nw", "n", "ne", "e", "se"]

# Temporary asset folder aliases to keep older naming conventions working.
const TOWER_ASSET_ALIASES := {
	"surveillance_hub": "surveillance",
	"lrad_cannon": "lrad",
	"microwave_emitter": "microwave",
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
		var alias := TOWER_ASSET_ALIASES.get(tower_id, "")
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

	var skin := TowerSkinData.new()
	skin.display_name = tower_data.tower_name
	skin.description = tower_data.description
	skin.base_texture = base_tex
	skin.turret_textures = turret_textures

	var icon := _load_tower_icon(tower_id, folder_id)
	if icon:
		skin.icon = icon

	return skin


func _load_tower_icon(tower_id: String, folder_id: String) -> Texture2D:
	var primary := "res://assets/sprites/ui/icon_tower_%s.png" % tower_id
	if ResourceLoader.exists(primary):
		return load(primary) as Texture2D
	if folder_id != tower_id:
		var alias := "res://assets/sprites/ui/icon_tower_%s.png" % folder_id
		if ResourceLoader.exists(alias):
			return load(alias) as Texture2D
	return null


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
