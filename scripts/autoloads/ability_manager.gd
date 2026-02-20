extends Node
## Manages special ability ("Executive Decree") placement, cooldowns, and unlocks.
## Autoload singleton -- state machine with IDLE and PLACING states.

signal cooldown_updated(ability_id: String, ratio: float)

var _current_state: Enums.AbilityState = Enums.AbilityState.IDLE
var _abilities: Array[SpecialAbilityData] = []
var _tile_map: TileMapLayer
var _effects_container: Node2D

## Cooldown tracking: ability_id -> remaining seconds
var _cooldown_timers: Dictionary = {}
## Unlock tracking: ability_id -> bool
var _unlocked: Dictionary = {}
## Currently placing this ability
var _placing_data: SpecialAbilityData

## Placement ghost
var _ghost: Node2D
var _ghost_radius_draw: Node2D
var _ghost_valid: bool = false


func initialize(abilities: Array[SpecialAbilityData], tile_map: TileMapLayer, effects_container: Node2D) -> void:
	_abilities = abilities
	_tile_map = tile_map
	_effects_container = effects_container

	for ability in abilities:
		_cooldown_timers[ability.ability_id] = 0.0
		_unlocked[ability.ability_id] = ability.unlock_wave <= 1

	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.build_mode_entered.connect(_on_build_mode_entered)
	SignalBus.ability_completed.connect(_on_ability_completed)


func _process(delta: float) -> void:
	# Tick cooldowns
	for ability_id in _cooldown_timers:
		if _cooldown_timers[ability_id] > 0.0:
			_cooldown_timers[ability_id] = maxf(_cooldown_timers[ability_id] - delta, 0.0)
			cooldown_updated.emit(ability_id, get_cooldown_ratio(ability_id))

	# Update ghost position when placing
	if _current_state == Enums.AbilityState.PLACING and _ghost and _tile_map:
		var world_pos := _ghost.get_global_mouse_position()
		_ghost.global_position = world_pos
		var valid := _validate_placement(world_pos)
		if valid != _ghost_valid:
			_ghost_valid = valid
			_update_ghost_color()


func _unhandled_input(event: InputEvent) -> void:
	if _current_state != Enums.AbilityState.PLACING:
		return

	if event.is_action_pressed("select"):
		var world_pos := _ghost.get_global_mouse_position()
		confirm_placement(world_pos)
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("cancel"):
		cancel_placement()
		get_viewport().set_input_as_handled()


# -- Public API --

func start_placement(ability_data: SpecialAbilityData) -> void:
	if not is_ready_to_use(ability_data.ability_id):
		return

	# Instant-cast abilities: skip placement, activate immediately
	if ability_data.placement_type == SpecialAbilityData.PlacementType.INSTANT:
		_instant_activate(ability_data)
		return

	# Cancel any tower placement first
	SignalBus.build_mode_exited.emit()

	_placing_data = ability_data
	_current_state = Enums.AbilityState.PLACING
	_create_ghost(ability_data)
	SignalBus.ability_placement_started.emit(ability_data)


func cancel_placement() -> void:
	_current_state = Enums.AbilityState.IDLE
	_placing_data = null
	_destroy_ghost()
	SignalBus.ability_placement_cancelled.emit()


func confirm_placement(world_pos: Vector2) -> void:
	if not _placing_data:
		return
	if not _validate_placement(world_pos):
		return

	var ability_data := _placing_data
	var ability_id := ability_data.ability_id

	# Start cooldown
	_cooldown_timers[ability_id] = ability_data.cooldown

	# Exit placement state
	_current_state = Enums.AbilityState.IDLE
	_placing_data = null
	_destroy_ghost()

	# Emit signal -- game.gd will spawn the ability scene
	SignalBus.ability_activated.emit(ability_id, world_pos)


func is_placing() -> bool:
	return _current_state == Enums.AbilityState.PLACING


func is_ready_to_use(ability_id: String) -> bool:
	return _unlocked.get(ability_id, false) and _cooldown_timers.get(ability_id, 0.0) <= 0.0


func is_unlocked(ability_id: String) -> bool:
	return _unlocked.get(ability_id, false)


func get_cooldown_ratio(ability_id: String) -> float:
	var remaining: float = _cooldown_timers.get(ability_id, 0.0)
	if remaining <= 0.0:
		return 0.0
	for ability in _abilities:
		if ability.ability_id == ability_id:
			return remaining / ability.cooldown if ability.cooldown > 0.0 else 0.0
	return 0.0


func get_ability_data(ability_id: String) -> SpecialAbilityData:
	for ability in _abilities:
		if ability.ability_id == ability_id:
			return ability
	return null


func get_abilities() -> Array[SpecialAbilityData]:
	return _abilities


## Find nearest path and its exit point for abilities that walk backward.
## Returns {spawn_index: int, path: PackedVector2Array} or empty dict.
func find_nearest_path_and_exit(world_pos: Vector2) -> Dictionary:
	var best_dist := INF
	var best_index := -1
	var best_path := PackedVector2Array()

	for i in PathfindingManager._spawn_tiles.size():
		var path := PathfindingManager.get_path_for_spawn(i)
		if path.is_empty():
			continue
		# Find closest point on this path to world_pos
		for j in range(path.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(world_pos, path[j], path[j + 1])
			var dist := world_pos.distance_to(closest)
			if dist < best_dist:
				best_dist = dist
				best_index = i
				best_path = path

	if best_index < 0:
		return {}
	return {"spawn_index": best_index, "path": best_path}


## Get the primary path (index 0) exit position for instant-cast abilities.
func get_primary_path_exit() -> Vector2:
	var path := PathfindingManager.get_path_for_spawn(0)
	if path.is_empty():
		return Vector2.ZERO
	return path[path.size() - 1]


# -- Private --

func _instant_activate(ability_data: SpecialAbilityData) -> void:
	var ability_id := ability_data.ability_id

	# Cancel any tower placement
	SignalBus.build_mode_exited.emit()

	# Start cooldown
	_cooldown_timers[ability_id] = ability_data.cooldown

	# Use the primary path's exit position (gov building end)
	var exit_pos := get_primary_path_exit()

	# Brief UI feedback
	SignalBus.ability_placement_started.emit(ability_data)
	# Immediately emit activated (no placement phase)
	SignalBus.ability_activated.emit(ability_id, exit_pos)
	# Clear placement state
	SignalBus.ability_placement_cancelled.emit()


func _on_wave_started(wave_number: int) -> void:
	for ability in _abilities:
		if not _unlocked.get(ability.ability_id, false) and wave_number >= ability.unlock_wave:
			_unlocked[ability.ability_id] = true
			SignalBus.ability_unlocked.emit(ability)


func _on_build_mode_entered(_tower_data: TowerData) -> void:
	# Cancel ability placement when player starts placing a tower
	if _current_state == Enums.AbilityState.PLACING:
		cancel_placement()


func _on_ability_completed(_ability_id: String) -> void:
	pass  # Reserved for future use (e.g. UI feedback)


func _validate_placement(world_pos: Vector2) -> bool:
	if not _placing_data:
		return false
	# LINE and POINT placement: always valid (gas airstrike can strike anywhere)
	if _placing_data.placement_type == SpecialAbilityData.PlacementType.LINE:
		return true
	if not _placing_data.requires_path_proximity:
		return true
	# Check path proximity
	var result := find_nearest_path_and_exit(world_pos)
	if result.is_empty():
		return false
	var path: PackedVector2Array = result["path"]
	# Find minimum distance to any path segment
	var min_dist := INF
	for i in range(path.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(world_pos, path[i], path[i + 1])
		min_dist = minf(min_dist, world_pos.distance_to(closest))
	return min_dist <= _placing_data.path_proximity_radius


func _create_ghost(ability_data: SpecialAbilityData) -> void:
	_destroy_ghost()
	_ghost = Node2D.new()
	_ghost.z_index = 50
	_ghost.z_as_relative = false

	if ability_data.placement_type == SpecialAbilityData.PlacementType.LINE:
		# Line indicator for airstrike
		_ghost_radius_draw = _GhostLineDraw.new()
		_ghost_radius_draw.valid = true
		_ghost_radius_draw.z_index = -1
		_ghost.add_child(_ghost_radius_draw)
	else:
		# Circle radius indicator
		_ghost_radius_draw = _GhostRadiusDraw.new()
		_ghost_radius_draw.radius = ability_data.effect_radius
		_ghost_radius_draw.valid = true
		_ghost.add_child(_ghost_radius_draw)

	# Small crosshair
	var crosshair := _CrosshairDraw.new()
	_ghost.add_child(crosshair)

	# Add to scene tree via effects container's parent (World)
	if _effects_container:
		_effects_container.get_parent().add_child(_ghost)
	else:
		get_tree().current_scene.add_child(_ghost)

	_ghost_valid = false
	_update_ghost_color()


func _destroy_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_radius_draw = null


func _update_ghost_color() -> void:
	if _ghost_radius_draw and is_instance_valid(_ghost_radius_draw):
		_ghost_radius_draw.valid = _ghost_valid
		_ghost_radius_draw.queue_redraw()


# -- Inner draw scripts (attached at runtime) --

## Draws a radius circle around the placement point.
const _GhostRadiusDraw = preload("res://scripts/abilities/ghost_radius_draw.gd")
const _CrosshairDraw = preload("res://scripts/abilities/crosshair_draw.gd")
const _GhostLineDraw = preload("res://scripts/abilities/ghost_line_draw.gd")
