class_name UpgradeComponent
extends Node
## Tracks upgrade state for a tower. Enforces crosspathing rules.

signal upgraded(path_index: int, tier: int)

## How many upgrade paths can be used (typically 2)
@export var max_paths_used: int = 2
## Only 1 path can exceed this tier (typically 2)
@export var max_deep_tier: int = 2

## Current tier for each path (0 = no upgrades)
var path_tiers: Array[int] = [0, 0, 0]
## Accumulated stat modifiers from all upgrades
var active_modifiers: Array[StatModifierData] = []

var _tower_data: TowerData


func init(tower_data: TowerData) -> void:
	_tower_data = tower_data
	path_tiers = [0, 0, 0]
	active_modifiers.clear()


func can_upgrade_path(path_index: int) -> bool:
	if not _tower_data or path_index >= _tower_data.upgrade_paths.size():
		return false

	var path := _tower_data.upgrade_paths[path_index]
	var next_tier := path_tiers[path_index]
	if next_tier >= path.tiers.size():
		return false

	# Check crosspathing rules
	if not UpgradeRegistry.can_upgrade(path_tiers, path_index, max_paths_used, max_deep_tier):
		return false

	# Check cost
	var cost := path.tiers[next_tier].cost
	return EconomyManager.can_afford(cost)


func do_upgrade(path_index: int) -> bool:
	if not can_upgrade_path(path_index):
		return false

	var path := _tower_data.upgrade_paths[path_index]
	var tier_data := path.tiers[path_tiers[path_index]]

	if not EconomyManager.spend_gold(tier_data.cost):
		return false

	# Collect new modifiers
	for mod in tier_data.stat_modifiers:
		active_modifiers.append(mod)

	path_tiers[path_index] += 1
	upgraded.emit(path_index, path_tiers[path_index])
	SignalBus.tower_upgraded.emit(get_parent(), path_index, path_tiers[path_index])
	return true


func get_total_invested() -> int:
	var total := _tower_data.build_cost if _tower_data else 0
	for path_i in path_tiers.size():
		if not _tower_data or path_i >= _tower_data.upgrade_paths.size():
			continue
		var path := _tower_data.upgrade_paths[path_i]
		for tier_i in path_tiers[path_i]:
			if tier_i < path.tiers.size():
				total += path.tiers[tier_i].cost
	return total
