class_name SpecialAbilityData
extends Resource
## Data definition for a deployable special ability ("Executive Decree").

enum PlacementType {
	INSTANT,  ## No placement needed — activates immediately on primary path
	POINT,    ## Click a map position (circle ghost)
	LINE,     ## Click a map position (line ghost showing strike corridor)
}

@export var ability_id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var thematic_name: String  ## "EXECUTIVE DECREE #1/2/3"

@export_group("Timing")
@export var cooldown: float = 60.0
@export var duration: float = 6.0

@export_group("Unlock")
@export var unlock_wave: int = 1

@export_group("Placement")
@export var placement_type: PlacementType = PlacementType.POINT
@export var requires_path_proximity: bool = true
@export var path_proximity_radius: float = 64.0

@export_group("Effect")
@export var effect_radius: float = 48.0
