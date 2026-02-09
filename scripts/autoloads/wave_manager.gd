extends Node
## Manages wave progression, enemy spawning, and between-wave timers.

signal spawn_enemy_requested(enemy_data: EnemyData, spawn_point_index: int, modifiers: Dictionary)

@export var waves: Array[WaveData] = []

var current_wave_index: int = -1
var enemies_alive: int = 0
var is_spawning: bool = false
var _between_wave_timer: float = 0.0
var _waiting_for_next_wave: bool = false
var _active_sequences: int = 0

# Engagement: perfect wave streak
var perfect_streak: int = 0
var _wave_had_leak: bool = false


func _ready() -> void:
	SignalBus.enemy_killed.connect(_on_enemy_died)
	SignalBus.enemy_reached_end.connect(_on_enemy_reached_end)


func start_waves() -> void:
	current_wave_index = -1
	enemies_alive = 0
	perfect_streak = 0
	_start_next_wave()


func _start_next_wave() -> void:
	current_wave_index += 1
	if current_wave_index >= waves.size():
		SignalBus.all_waves_completed.emit()
		return

	var wave := waves[current_wave_index]
	_wave_had_leak = false
	SignalBus.wave_started.emit(wave.wave_number)
	is_spawning = true
	_waiting_for_next_wave = false
	_spawn_wave(wave)


func _spawn_wave(wave: WaveData) -> void:
	_active_sequences = wave.spawn_sequences.size()
	for seq in wave.spawn_sequences:
		_spawn_sequence(seq)


func _get_late_wave_hp_scale() -> float:
	# After wave 5, add +10% HP per wave beyond 5
	if current_wave_index >= 5:
		return 1.0 + (current_wave_index - 4) * 0.1
	return 1.0


func _spawn_sequence(seq: SpawnSequenceData) -> void:
	if seq.start_delay > 0.0:
		await get_tree().create_timer(seq.start_delay).timeout

	var late_scale := _get_late_wave_hp_scale()
	for i in seq.count:
		var modifiers := {
			"hp_multiplier": seq.hp_multiplier * late_scale,
			"speed_multiplier": seq.speed_multiplier,
			"armor_bonus": seq.armor_bonus,
		}
		enemies_alive += 1
		spawn_enemy_requested.emit(seq.enemy_data, seq.spawn_point_index, modifiers)
		SignalBus.wave_enemies_remaining.emit(enemies_alive)

		if i < seq.count - 1 and seq.spawn_interval > 0.0:
			await get_tree().create_timer(seq.spawn_interval).timeout

	_active_sequences -= 1
	if _active_sequences <= 0:
		is_spawning = false


func _on_enemy_died(_enemy: Node2D, _value: int = 0) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	SignalBus.wave_enemies_remaining.emit(enemies_alive)

	if enemies_alive <= 0 and not is_spawning:
		_on_wave_cleared()


func _on_enemy_reached_end(_enemy: Node2D, _lives_cost: int = 0) -> void:
	_wave_had_leak = true
	enemies_alive = max(enemies_alive - 1, 0)
	SignalBus.wave_enemies_remaining.emit(enemies_alive)

	if enemies_alive <= 0 and not is_spawning:
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	var wave := waves[current_wave_index]

	# Perfect streak tracking
	if not _wave_had_leak:
		perfect_streak += 1
	else:
		if perfect_streak > 0:
			SignalBus.streak_broken.emit(perfect_streak)
		perfect_streak = 0
	SignalBus.streak_changed.emit(perfect_streak)

	# Gold interest (applied before wave bonus)
	EconomyManager.apply_interest()

	# Base wave gold bonus
	var bonus := wave.gold_bonus
	# Streak bonus: +5% per streak level
	if perfect_streak > 0 and bonus > 0:
		var streak_bonus := int(bonus * perfect_streak * 0.05)
		bonus += streak_bonus

	if bonus > 0:
		EconomyManager.add_gold(bonus)

	SignalBus.wave_completed.emit(wave.wave_number)
	_waiting_for_next_wave = true
	_between_wave_timer = 5.0


## Call next wave early for a gold bonus. Returns the bonus gold earned.
func call_next_wave() -> int:
	if not _waiting_for_next_wave:
		return 0
	# Bonus based on remaining timer: up to 25% of next wave's gold_bonus
	var next_idx := current_wave_index + 1
	if next_idx >= waves.size():
		return 0
	var next_wave := waves[next_idx]
	var time_ratio := clampf(_between_wave_timer / 5.0, 0.0, 1.0)
	var bonus := int(next_wave.gold_bonus * time_ratio * 0.25)
	if bonus > 0:
		EconomyManager.add_gold(bonus)
		SignalBus.send_wave_bonus.emit(bonus)
	_between_wave_timer = 0.0
	return bonus


## Get projected bonus for calling wave now.
func get_call_wave_bonus() -> int:
	if not _waiting_for_next_wave:
		return 0
	var next_idx := current_wave_index + 1
	if next_idx >= waves.size():
		return 0
	var next_wave := waves[next_idx]
	var time_ratio := clampf(_between_wave_timer / 5.0, 0.0, 1.0)
	return int(next_wave.gold_bonus * time_ratio * 0.25)


func get_between_wave_timer() -> float:
	return _between_wave_timer if _waiting_for_next_wave else 0.0


func _process(delta: float) -> void:
	if _waiting_for_next_wave:
		_between_wave_timer -= delta
		if _between_wave_timer <= 0.0:
			_start_next_wave()
