extends Node
## Stores and resolves stat modifiers from upgrades. When a tower
## upgrades, its modifier stack is updated here and final stats recomputed.


func apply_modifiers(base_value: float, modifiers: Array[StatModifierData]) -> float:
	## Apply a stack of modifiers to a base stat value.
	## Order: SET first (last wins), then ADD, then MULTIPLY.
	var result := base_value
	var has_set := false

	# SET overrides (last one wins)
	for mod in modifiers:
		if mod.operation == Enums.ModifierOp.SET:
			result = mod.value
			has_set = true

	if not has_set:
		result = base_value

	# Additive pass
	for mod in modifiers:
		if mod.operation == Enums.ModifierOp.ADD:
			result += mod.value

	# Multiplicative pass
	for mod in modifiers:
		if mod.operation == Enums.ModifierOp.MULTIPLY:
			result *= mod.value

	return result


func get_upgrade_cost(tower_data: TowerData, path_index: int, tier: int) -> int:
	if path_index >= tower_data.upgrade_paths.size():
		return -1
	var path := tower_data.upgrade_paths[path_index]
	if tier >= path.tiers.size():
		return -1
	return path.tiers[tier].cost


func can_upgrade(current_paths: Array[int], path_index: int, max_paths: int, max_deep_tier: int) -> bool:
	## Enforce crosspathing rules:
	## - At most `max_paths` paths can be used (typically 2)
	## - At most 1 path can exceed `max_deep_tier` (typically tier 2)
	var paths_used := 0
	var deep_paths := 0

	for i in current_paths.size():
		var tier_val: int = current_paths[i]
		if i == path_index:
			tier_val += 1  # Simulate upgrading this path
		if tier_val > 0:
			paths_used += 1
		if tier_val > max_deep_tier:
			deep_paths += 1

	if paths_used > max_paths:
		return false
	if deep_paths > 1:
		return false
	return true
