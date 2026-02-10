class_name EnemySkinData
extends Resource
## Visual skin for an enemy type. Referenced by ThemeData.

@export var display_name: String
@export var description: String
@export var sprite_sheet: Texture2D
@export var animation_frames: SpriteFrames
@export var corpse_texture: Texture2D  ## Optional static corpse frame
@export var tint: Color = Color.WHITE
