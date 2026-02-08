class_name ThemeData
extends Resource
## Top-level theme definition. Bundles all visual skins, palette, and
## shader overrides for a complete visual identity swap.

@export var theme_id: String
@export var display_name: String

@export_group("Skins")
## tower_id -> TowerSkinData
@export var tower_skins: Dictionary = {}
## enemy_id -> EnemySkinData
@export var enemy_skins: Dictionary = {}
## projectile_id -> ProjectileSkinData
@export var projectile_skins: Dictionary = {}

@export_group("Palette")
@export var palette: ThemePalette

@export_group("Shader Overrides")
@export var fog_params: Dictionary = {}
@export var atmosphere_params: Dictionary = {}
@export var damage_flash_color: Color = Color("#E0B0B8")

@export_group("UI")
@export var ui_theme: Theme
