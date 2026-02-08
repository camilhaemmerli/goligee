class_name StatusEffectManager
extends Node
## Manages active status effects (debuffs) on an enemy.

signal effect_applied(effect_type: Enums.StatusEffectType)
signal effect_removed(effect_type: Enums.StatusEffectType)

## Active effects: key = StatusEffectType, value = Array of {data, remaining_time, stacks}
var _active_effects: Dictionary = {}


func apply_effect(data: StatusEffectData) -> void:
	if randf() > data.apply_chance:
		return

	var effect_type := data.effect_type

	if not _active_effects.has(effect_type):
		_active_effects[effect_type] = []

	var stack_list: Array = _active_effects[effect_type]

	if stack_list.size() < data.stack_limit:
		stack_list.append({
			"data": data,
			"remaining": data.duration,
		})
		effect_applied.emit(effect_type)
	else:
		# Refresh the oldest stack's duration
		if not stack_list.is_empty():
			stack_list[0]["remaining"] = data.duration


func _process(delta: float) -> void:
	var to_remove: Array[Enums.StatusEffectType] = []

	for effect_type in _active_effects:
		var stack_list: Array = _active_effects[effect_type]

		# Tick down durations
		var i := stack_list.size() - 1
		while i >= 0:
			stack_list[i]["remaining"] -= delta
			if stack_list[i]["remaining"] <= 0.0:
				stack_list.remove_at(i)
			i -= 1

		if stack_list.is_empty():
			to_remove.append(effect_type)

	for effect_type in to_remove:
		_active_effects.erase(effect_type)
		effect_removed.emit(effect_type)


func has_effect(effect_type: Enums.StatusEffectType) -> bool:
	return _active_effects.has(effect_type) and not _active_effects[effect_type].is_empty()


func get_slow_factor() -> float:
	## Returns the combined slow multiplier (1.0 = no slow, 0.0 = frozen).
	if has_effect(Enums.StatusEffectType.FREEZE):
		return 0.0
	if has_effect(Enums.StatusEffectType.STUN):
		return 0.0

	var factor := 1.0
	if _active_effects.has(Enums.StatusEffectType.SLOW):
		for stack in _active_effects[Enums.StatusEffectType.SLOW]:
			var data: StatusEffectData = stack["data"]
			factor *= (1.0 - data.potency)
	return max(factor, 0.0)


func get_dot_damage(delta: float) -> float:
	## Returns total damage-over-time to apply this frame.
	var total := 0.0

	for effect_type in [Enums.StatusEffectType.POISON, Enums.StatusEffectType.BURN]:
		if _active_effects.has(effect_type):
			for stack in _active_effects[effect_type]:
				var data: StatusEffectData = stack["data"]
				total += data.potency * delta

	return total


func get_vulnerability_modifier() -> float:
	## Returns damage multiplier from MARK effects.
	var modifier := 1.0
	if _active_effects.has(Enums.StatusEffectType.MARK):
		for stack in _active_effects[Enums.StatusEffectType.MARK]:
			var data: StatusEffectData = stack["data"]
			modifier += data.potency
	return modifier


func purge_all() -> void:
	for effect_type in _active_effects.keys():
		effect_removed.emit(effect_type)
	_active_effects.clear()
