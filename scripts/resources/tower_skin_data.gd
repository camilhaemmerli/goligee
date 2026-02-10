class_name TowerSkinData
extends Resource
## Visual skin for a tower type. Referenced by ThemeData.
## Towers use a base+turret architecture: static base platform + rotating turret head.

@export var display_name: String
@export var description: String
@export var icon: Texture2D

@export_group("Base + Turret")
## Static base/platform sprite (64x64). Does not rotate.
@export var base_texture: Texture2D
## Turret head sprites for 8 directions: S, SW, W, NW, N, NE, E, SE (48x48).
@export var turret_textures: Array[Texture2D] = []
## Y offset for turret sprite relative to base (negative = upward).
@export var turret_y_offset: float = -26.0

@export_group("Legacy")
## Legacy single sprite (used if base_texture is null).
@export var sprite_sheet: Texture2D
@export var animation_frames: SpriteFrames
@export var tier_sprites: Array[Texture2D] = []
