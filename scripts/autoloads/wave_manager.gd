extends Node
## Manages wave progression, enemy spawning, and between-wave timers.

signal spawn_enemy_requested(enemy_data: EnemyData, spawn_point_index: int, modifiers: Dictionary)

@export var waves: Array[WaveData] = []

var current_wave_index: int = -1
var enemies_alive: int = 0
var is_spawning: bool = false
var _between_wave_timer: float = 0.0
var _waiting_for_next_wave: bool = false

# Engagement: perfect wave streak
var perfect_streak: int = 0
var _wave_had_leak: bool = false

# Crowd diversity: pool of regular protestor types to mix at spawn time.
# Special enemies (bosses, vehicles, stealth) keep their original type.
var _crowd_pool: Array[EnemyData] = []
const _CROWD_PATHS: PackedStringArray = [
	"res://data/enemies/rioter.tres",
	"res://data/enemies/blonde_protestor.tres",
	"res://data/enemies/goth_protestor.tres",
	"res://data/enemies/student.tres",
	"res://data/enemies/grandma.tres",
	"res://data/enemies/masked.tres",
]
const _SPECIAL_IDS: PackedStringArray = [
	"shield_wall", "union_boss", "armored_van", "infiltrator",
]


func _ready() -> void:
	SignalBus.enemy_killed.connect(_on_enemy_died)
	SignalBus.enemy_reached_end.connect(_on_enemy_reached_end)
	_load_crowd_pool()


func _load_crowd_pool() -> void:
	for path in _CROWD_PATHS:
		if ResourceLoader.exists(path):
			var data := load(path) as EnemyData
			if data:
				_crowd_pool.append(data)


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

	# Manifestation briefing at the start of each 5-wave group (1, 6, 11, ...)
	if (wave.wave_number - 1) % 5 == 0:
		SignalBus.presidential_briefing_requested.emit(wave.wave_number)
		await SignalBus.presidential_briefing_dismissed

	_wave_had_leak = false
	SignalBus.wave_started.emit(wave.wave_number)
	is_spawning = true
	_waiting_for_next_wave = false
	_spawn_wave(wave)


func _spawn_wave(wave: WaveData) -> void:
	# Build a flat timeline from all sequences, then sort by time.
	# This interleaves different enemy types instead of spawning in batches.
	var timeline: Array[Dictionary] = []
	var late_scale := _get_late_wave_hp_scale()

	for seq in wave.spawn_sequences:
		var t := seq.start_delay
		var is_crowd := not _crowd_pool.is_empty() and seq.enemy_data.enemy_id not in _SPECIAL_IDS
		for i in seq.count:
			var enemy: EnemyData = _crowd_pool[randi() % _crowd_pool.size()] if is_crowd else seq.enemy_data
			timeline.append({
				"time": t,
				"enemy_data": enemy,
				"spawn_point_index": seq.spawn_point_index,
				"modifiers": {
					"hp_multiplier": seq.hp_multiplier * late_scale,
					"speed_multiplier": seq.speed_multiplier,
					"armor_bonus": seq.armor_bonus,
				},
			})
			t += seq.spawn_interval

	timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])

	var elapsed := 0.0
	for entry in timeline:
		var wait: float = entry["time"] - elapsed
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		elapsed = entry["time"]

		enemies_alive += 1
		spawn_enemy_requested.emit(entry["enemy_data"], entry["spawn_point_index"], entry["modifiers"])
		SignalBus.wave_enemies_remaining.emit(enemies_alive)

	is_spawning = false


func _get_late_wave_hp_scale() -> float:
	# After wave 5, add +10% HP per wave beyond 5
	if current_wave_index >= 5:
		return 1.0 + (current_wave_index - 5) * 0.1
	return 1.0


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
