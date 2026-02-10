class_name TargetingComponent
extends Node
## Selects which enemy a tower should attack based on priority.
## Requires the tower to have an Area2D child for range detection.

@export var priority: Enums.TargetingPriority = Enums.TargetingPriority.FIRST
@export var can_target_flying: bool = true
@export var can_target_stealth: bool = false

var current_target: Node2D = null
var enemies_in_range: Array[Node2D] = []


func add_enemy(enemy: Node2D) -> void:
	if enemy not in enemies_in_range:
		enemies_in_range.append(enemy)


func remove_enemy(enemy: Node2D) -> void:
	enemies_in_range.erase(enemy)
	if current_target == enemy:
		current_target = null


func update_target(tower_position: Vector2) -> Node2D:
	# Clean up dead/freed references
	var alive: Array[Node2D] = []
	for e in enemies_in_range:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			alive.append(e)
	enemies_in_range = alive

	var valid: Array[Node2D] = []
	for e in enemies_in_range:
		if _is_valid_target(e):
			valid.append(e)
	if valid.is_empty():
		current_target = null
		return current_target

	match priority:
		Enums.TargetingPriority.FIRST:
			current_target = _get_first(valid)
		Enums.TargetingPriority.LAST:
			current_target = _get_last(valid)
		Enums.TargetingPriority.STRONGEST:
			current_target = _get_strongest(valid)
		Enums.TargetingPriority.WEAKEST:
			current_target = _get_weakest(valid)
		Enums.TargetingPriority.CLOSEST:
			current_target = _get_closest(valid, tower_position)

	return current_target


func _is_valid_target(enemy: Node2D) -> bool:
	if not can_target_flying and enemy.has_method("is_flying") and enemy.is_flying():
		return false
	if not can_target_stealth and enemy.has_method("is_stealthed") and enemy.is_stealthed():
		return false
	return true


func _get_first(enemies: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_progress := -1.0
	for e in enemies:
		if e.has_method("get_path_progress"):
			var p: float = e.get_path_progress()
			if p > best_progress:
				best_progress = p
				best = e
	return best if best else (enemies[0] if not enemies.is_empty() else null)


func _get_last(enemies: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_progress := INF
	for e in enemies:
		if e.has_method("get_path_progress"):
			var p: float = e.get_path_progress()
			if p < best_progress:
				best_progress = p
				best = e
	return best if best else (enemies[0] if not enemies.is_empty() else null)


func _get_strongest(enemies: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_hp := -1.0
	for e in enemies:
		var health := e.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.current_hp > best_hp:
			best_hp = health.current_hp
			best = e
	return best if best else (enemies[0] if not enemies.is_empty() else null)


func _get_weakest(enemies: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_hp := INF
	for e in enemies:
		var health := e.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.current_hp < best_hp:
			best_hp = health.current_hp
			best = e
	return best if best else (enemies[0] if not enemies.is_empty() else null)


func _get_closest(enemies: Array[Node2D], pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for e in enemies:
		var d := pos.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best if best else (enemies[0] if not enemies.is_empty() else null)
