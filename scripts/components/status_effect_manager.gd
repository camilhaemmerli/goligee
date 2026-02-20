class_name StatusEffectManager
extends Node
## Manages active status effects (debuffs) on an enemy.

signal effect_applied(effect_type: Enums.StatusEffectType)
signal effect_removed(effect_type: Enums.StatusEffectType)

## Active effects: key = StatusEffectType, value = Array of {data, remaining_time, stacks}
var _active_effects: Dictionary = {}

## Cache — recomputed only when effects change
var _cache_dirty: bool = true
var _cached_slow: float = 1.0
var _cached_dot_dps: float = 0.0
var _cached_vuln: float = 1.0
var _cached_armor_shred: float = 0.0


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
		_cache_dirty = true
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
				_cache_dirty = true
			i -= 1

		if stack_list.is_empty():
			to_remove.append(effect_type)

	if not to_remove.is_empty():
		_cache_dirty = true
	for effect_type in to_remove:
		_active_effects.erase(effect_type)
		effect_removed.emit(effect_type)


func has_effect(effect_type: Enums.StatusEffectType) -> bool:
	return _active_effects.has(effect_type) and not _active_effects[effect_type].is_empty()


func _recompute_cache() -> void:
	_cache_dirty = false

	# Slow
	if has_effect(Enums.StatusEffectType.FREEZE) or has_effect(Enums.StatusEffectType.STUN):
		_cached_slow = 0.0
	else:
		var factor := 1.0
		if _active_effects.has(Enums.StatusEffectType.SLOW):
			for stack in _active_effects[Enums.StatusEffectType.SLOW]:
				var data: StatusEffectData = stack["data"]
				factor *= (1.0 - data.potency)
		_cached_slow = max(factor, 0.0)

	# DoT DPS
	var dot_total := 0.0
	for effect_type in [Enums.StatusEffectType.POISON, Enums.StatusEffectType.BURN]:
		if _active_effects.has(effect_type):
			for stack in _active_effects[effect_type]:
				var data: StatusEffectData = stack["data"]
				dot_total += data.potency
	_cached_dot_dps = dot_total

	# Vulnerability
	var vuln := 1.0
	if _active_effects.has(Enums.StatusEffectType.MARK):
		for stack in _active_effects[Enums.StatusEffectType.MARK]:
			var data: StatusEffectData = stack["data"]
			vuln += data.potency
	_cached_vuln = vuln

	# Armor shred
	var shred := 0.0
	if _active_effects.has(Enums.StatusEffectType.ARMOR_SHRED):
		for stack in _active_effects[Enums.StatusEffectType.ARMOR_SHRED]:
			var data: StatusEffectData = stack["data"]
			shred += data.potency
	_cached_armor_shred = min(shred, 1.0)


func get_slow_factor() -> float:
	if _cache_dirty:
		_recompute_cache()
	return _cached_slow


func get_dot_damage(delta: float) -> float:
	if _cache_dirty:
		_recompute_cache()
	return _cached_dot_dps * delta


func get_vulnerability_modifier() -> float:
	if _cache_dirty:
		_recompute_cache()
	return _cached_vuln


func get_armor_shred() -> float:
	if _cache_dirty:
		_recompute_cache()
	return _cached_armor_shred


func purge_all() -> void:
	for effect_type in _active_effects.keys():
		effect_removed.emit(effect_type)
	_active_effects.clear()
	_cache_dirty = true
