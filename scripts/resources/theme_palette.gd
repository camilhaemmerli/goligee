class_name ThemePalette
extends Resource
## Color definitions for a visual theme.

@export_group("Sky")
@export var sky_top: Color = Color("#120E20")
@export var sky_mid: Color = Color("#4A3050")
@export var sky_horizon: Color = Color("#E0B0B8")

@export_group("Terrain")
@export var terrain_light: Color = Color("#7A6080")
@export var terrain_mid: Color = Color("#60486A")
@export var terrain_dark: Color = Color("#3A2845")

@export_group("Foliage")
@export var foliage_light: Color = Color("#402F50")
@export var foliage_mid: Color = Color("#2A1E3A")
@export var foliage_dark: Color = Color("#1E1530")

@export_group("UI")
@export var ui_text_light: Color = Color("#F0D0D8")
@export var ui_highlight: Color = Color("#E0B0B8")
@export var ui_text_dim: Color = Color("#9A6B80")
@export var ui_inactive: Color = Color("#60486A")
@export var ui_panel_mid: Color = Color("#2A1E3A")
@export var ui_panel_dark: Color = Color("#1A1428")
@export var ui_panel_border: Color = Color("#120E20")
@export var ui_warning: Color = Color("#C87878")

@export_group("Damage Types")
@export var damage_physical: Color = Color("#9A9AA0")
@export var damage_fire: Color = Color("#C87878")
@export var damage_ice: Color = Color("#90A0B8")
@export var damage_lightning: Color = Color("#D0C890")
@export var damage_poison: Color = Color("#70A070")
@export var damage_magic: Color = Color("#B070A0")
@export var damage_holy: Color = Color("#D0C8A0")
@export var damage_dark: Color = Color("#4A3050")

@export_group("Enemies")
@export var enemy_core: Color = Color("#D06070")
@export var enemy_damaged: Color = Color("#E08888")
@export var enemy_elite: Color = Color("#A04050")
@export var enemy_boss: Color = Color("#802030")

@export_group("Effects")
@export var explosion_flash: Color = Color("#F0D0D8")
@export var explosion_mid: Color = Color("#C87878")
@export var smoke_warm: Color = Color("#8A5060")
@export var smoke_cool: Color = Color("#6B4A60")
@export var magic_burst: Color = Color("#B070A0")

@export_group("Fog / Atmosphere")
@export var fog_near: Color = Color(0.29, 0.19, 0.31, 0.4)
@export var fog_far: Color = Color(0.42, 0.29, 0.37, 0.6)
@export var ground_smoke_color: Color = Color(0.28, 0.25, 0.25, 0.35)
@export var atmosphere_tint: Color = Color("#4A3050")
@export var clear_color: Color = Color(0.047, 0.039, 0.094, 1.0)
@export var damage_flash: Color = Color("#E0B0B8")

@export_group("Lighting")
@export var canvas_modulate: Color = Color(0.45, 0.45, 0.5, 1.0)
@export var floodlight_color: Color = Color("#D89050")
@export var streetlight_color: Color = Color("#C8A040")


func get_damage_type_color(damage_type: Enums.DamageType) -> Color:
	match damage_type:
		Enums.DamageType.KINETIC: return damage_physical
		Enums.DamageType.CHEMICAL: return damage_fire
		Enums.DamageType.HYDRAULIC: return damage_ice
		Enums.DamageType.ELECTRIC: return damage_lightning
		Enums.DamageType.SONIC: return damage_poison
		Enums.DamageType.DIRECTED_ENERGY: return damage_magic
		Enums.DamageType.CYBER: return damage_holy
		Enums.DamageType.PSYCHOLOGICAL: return damage_dark
		_: return damage_physical
