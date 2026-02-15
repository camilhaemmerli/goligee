extends Node
## Manages proximity-based tower synergies. Recalculates damage/rate/range
## multipliers whenever towers are placed, sold, or upgraded.

signal synergy_changed(tower: Node2D)

## Synergy definition format:
##   id: unique string
##   name: display name (themed)
##   tower_a / tower_b: tower_id strings (same = self-synergy)
##   bonus_a / bonus_b: damage multiplier per stack (e.g. 1.25 = +25%)
##   rate_a / rate_b: fire rate multiplier per stack (optional, default 1.0)
##   max_stacks: cap on how many neighbors count
const SYNERGIES := [
	{
		"id": "power_grid",
		"name": "POWER GRID",
		"tower_a": "taser_grid",
		"tower_b": "taser_grid",
		"bonus_a": 1.20,
		"bonus_b": 1.20,
		"max_stacks": 2,
	},
	{
		"id": "redundant_monitoring",
		"name": "REDUNDANT MONITORING",
		"tower_a": "surveillance_hub",
		"tower_b": "surveillance_hub",
		"bonus_a": 0.90,
		"bonus_b": 0.90,
		"max_stacks": 2,
	},
	{
		"id": "conductivity_protocol",
		"name": "CONDUCTIVITY PROTOCOL",
		"tower_a": "water_cannon",
		"tower_b": "taser_grid",
		"bonus_a": 1.25,
		"bonus_b": 1.25,
		"max_stacks": 1,
	},
	{
		"id": "sensory_overload",
		"name": "SENSORY OVERLOAD",
		"tower_a": "lrad_cannon",
		"tower_b": "pepper_spray",
		"bonus_a": 1.20,
		"bonus_b": 1.20,
		"max_stacks": 1,
	},
	{
		"id": "intelligence_briefing",
		"name": "INTELLIGENCE BRIEFING",
		"tower_a": "surveillance_hub",
		"tower_b": "rubber_bullet",
		"bonus_a": 1.0,
		"bonus_b": 1.0,
		"rate_a": 1.0,
		"rate_b": 1.40,
		"max_stacks": 1,
	},
	{
		"id": "chemical_cocktail",
		"name": "CHEMICAL COCKTAIL",
		"tower_a": "tear_gas",
		"tower_b": "pepper_spray",
		"bonus_a": 1.15,
		"bonus_b": 1.15,
		"max_stacks": 1,
	},
	{
		"id": "scorched_earth",
		"name": "SCORCHED EARTH",
		"tower_a": "microwave_emitter",
		"tower_b": "tear_gas",
		"bonus_a": 1.15,
		"bonus_b": 1.10,
		"max_stacks": 1,
	},
]

const SYNERGY_RANGE := 3  ## Chebyshev distance in tiles

## Map of tile position → tower reference
var _tower_grid: Dictionary = {}  # Vector2i -> BaseTower

## Map of tower instance_id → active synergy info
## { instance_id: { "damage_mult": float, "rate_mult": float, "synergies": [...] } }
var _tower_synergies: Dictionary = {}


func _ready() -> void:
	SignalBus.tower_placed.connect(_on_tower_placed)
	SignalBus.tower_sold.connect(_on_tower_sold)
	SignalBus.tower_upgraded.connect(_on_tower_upgraded)


func _on_tower_placed(tower: Node2D, tile_pos: Vector2i) -> void:
	if not tower is BaseTower:
		return
	_tower_grid[tile_pos] = tower
	_recalculate_for_tower(tower, tile_pos)
	_recalculate_neighbors(tile_pos)


func _on_tower_sold(tower: Node2D, _refund: int) -> void:
	if not tower is BaseTower:
		return
	var tile_pos: Vector2i = tower._tile_pos
	_tower_grid.erase(tile_pos)
	_tower_synergies.erase(tower.get_instance_id())
	_recalculate_neighbors(tile_pos)


func _on_tower_upgraded(tower: Node2D, _path_index: int, _tier: int) -> void:
	if not tower is BaseTower:
		return
	# Re-apply synergy on top of new upgrade values
	_apply_synergy_to_tower(tower)


func _recalculate_neighbors(center_tile: Vector2i) -> void:
	for dx in range(-SYNERGY_RANGE, SYNERGY_RANGE + 1):
		for dy in range(-SYNERGY_RANGE, SYNERGY_RANGE + 1):
			if dx == 0 and dy == 0:
				continue
			var neighbor_tile := center_tile + Vector2i(dx, dy)
			if _tower_grid.has(neighbor_tile):
				var neighbor: BaseTower = _tower_grid[neighbor_tile]
				_recalculate_for_tower(neighbor, neighbor_tile)


func _recalculate_for_tower(tower: BaseTower, tile_pos: Vector2i) -> void:
	var tower_id: String = tower.tower_data.tower_id if tower.tower_data else ""
	if tower_id.is_empty():
		return

	var damage_mult := 1.0
	var rate_mult := 1.0
	var active_synergies: Array = []

	for synergy in SYNERGIES:
		var is_a: bool = (tower_id == synergy["tower_a"])
		var is_b: bool = (tower_id == synergy["tower_b"])
		if not is_a and not is_b:
			continue

		# Find matching partners within range
		var partner_id: String
		var bonus: float
		var rate_bonus: float
		if synergy["tower_a"] == synergy["tower_b"]:
			# Self-synergy: look for same tower type
			partner_id = tower_id
			bonus = synergy["bonus_a"]
			rate_bonus = synergy.get("rate_a", 1.0)
		elif is_a:
			partner_id = synergy["tower_b"]
			bonus = synergy["bonus_a"]
			rate_bonus = synergy.get("rate_a", 1.0)
		else:
			partner_id = synergy["tower_a"]
			bonus = synergy["bonus_b"]
			rate_bonus = synergy.get("rate_b", 1.0)

		var stack_count := 0
		for dx in range(-SYNERGY_RANGE, SYNERGY_RANGE + 1):
			for dy in range(-SYNERGY_RANGE, SYNERGY_RANGE + 1):
				if dx == 0 and dy == 0:
					continue
				var check_tile := tile_pos + Vector2i(dx, dy)
				if not _tower_grid.has(check_tile):
					continue
				var neighbor: BaseTower = _tower_grid[check_tile]
				if neighbor == tower:
					continue
				var neighbor_id: String = neighbor.tower_data.tower_id if neighbor.tower_data else ""
				if neighbor_id == partner_id:
					stack_count += 1
					if stack_count >= synergy["max_stacks"]:
						break
			if stack_count >= synergy["max_stacks"]:
				break

		if stack_count > 0:
			damage_mult *= pow(bonus, stack_count)
			rate_mult *= pow(rate_bonus, stack_count)
			active_synergies.append({
				"id": synergy["id"],
				"name": synergy["name"],
				"stacks": stack_count,
				"is_buff": bonus >= 1.0 and rate_bonus >= 1.0,
			})

	_tower_synergies[tower.get_instance_id()] = {
		"damage_mult": damage_mult,
		"rate_mult": rate_mult,
		"synergies": active_synergies,
	}

	if not active_synergies.is_empty():
		print("[Synergy] ", tower_id, " @ ", tile_pos, " → ", active_synergies, " (dmg x", snapped(damage_mult, 0.01), ", rate x", snapped(rate_mult, 0.01), ")")

	_apply_synergy_to_tower(tower)
	synergy_changed.emit(tower)


func _apply_synergy_to_tower(tower: BaseTower) -> void:
	var info: Dictionary = _tower_synergies.get(tower.get_instance_id(), {})
	var damage_mult: float = info.get("damage_mult", 1.0)
	var rate_mult: float = info.get("rate_mult", 1.0)
	tower.weapon.apply_synergy(damage_mult)
	tower.apply_synergy_rate(rate_mult)


## Returns array of active synergy dicts for a tower, or empty array.
func get_tower_synergies(tower: BaseTower) -> Array:
	var info: Dictionary = _tower_synergies.get(tower.get_instance_id(), {})
	return info.get("synergies", [])


## Returns display-friendly synergy names for a tower.
func get_synergy_names(tower: BaseTower) -> PackedStringArray:
	var names := PackedStringArray()
	for s in get_tower_synergies(tower):
		names.append(s["name"])
	return names


## Returns the overall damage multiplier for a tower (for UI display).
func get_damage_multiplier(tower: BaseTower) -> float:
	var info: Dictionary = _tower_synergies.get(tower.get_instance_id(), {})
	return info.get("damage_mult", 1.0)


## Returns the overall rate multiplier for a tower (for UI display).
func get_rate_multiplier(tower: BaseTower) -> float:
	var info: Dictionary = _tower_synergies.get(tower.get_instance_id(), {})
	return info.get("rate_mult", 1.0)
