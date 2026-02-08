extends Node
## Manages the active visual theme. Provides skin lookups and shader
## parameter application so gameplay code never references visual assets directly.

signal theme_changed()

var current_theme: ThemeData


func apply_theme(theme: ThemeData) -> void:
	current_theme = theme
	apply_clear_color()
	theme_changed.emit()


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
