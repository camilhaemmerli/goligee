extends Node
## Manages wave progression, enemy spawning, and between-wave timers.

signal spawn_enemy_requested(enemy_data: EnemyData, spawn_point_index: int, modifiers: Dictionary)

@export var waves: Array[WaveData] = []

var current_wave_index: int = -1
var enemies_alive: int = 0
var is_spawning: bool = false
var _between_wave_timer: float = 0.0
var _waiting_for_next_wave: bool = false


func _ready() -> void:
	SignalBus.enemy_killed.connect(_on_enemy_died)
	SignalBus.enemy_reached_end.connect(_on_enemy_died)


func start_waves() -> void:
	current_wave_index = -1
	enemies_alive = 0
	_start_next_wave()


func _start_next_wave() -> void:
	current_wave_index += 1
	if current_wave_index >= waves.size():
		SignalBus.all_waves_completed.emit()
		return

	var wave := waves[current_wave_index]
	SignalBus.wave_started.emit(wave.wave_number)
	is_spawning = true
	_waiting_for_next_wave = false
	_spawn_wave(wave)


func _spawn_wave(wave: WaveData) -> void:
	for seq in wave.spawn_sequences:
		_spawn_sequence(seq)
	# After all coroutines launch, the wave is fully queued.
	# Completion is tracked by enemies_alive reaching 0.


func _spawn_sequence(seq: SpawnSequenceData) -> void:
	if seq.start_delay > 0.0:
		await get_tree().create_timer(seq.start_delay).timeout

	for i in seq.count:
		var modifiers := {
			"hp_multiplier": seq.hp_multiplier,
			"speed_multiplier": seq.speed_multiplier,
			"armor_bonus": seq.armor_bonus,
		}
		enemies_alive += 1
		spawn_enemy_requested.emit(seq.enemy_data, seq.spawn_point_index, modifiers)
		SignalBus.wave_enemies_remaining.emit(enemies_alive)

		if i < seq.count - 1 and seq.spawn_interval > 0.0:
			await get_tree().create_timer(seq.spawn_interval).timeout

	is_spawning = false


func _on_enemy_died(_enemy: Node2D, _value: int = 0) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	SignalBus.wave_enemies_remaining.emit(enemies_alive)

	if enemies_alive <= 0 and not is_spawning:
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	var wave := waves[current_wave_index]
	if wave.gold_bonus > 0:
		EconomyManager.add_gold(wave.gold_bonus)
	SignalBus.wave_completed.emit(wave.wave_number)
	_waiting_for_next_wave = true
	_between_wave_timer = 5.0


func _process(delta: float) -> void:
	if _waiting_for_next_wave:
		_between_wave_timer -= delta
		if _between_wave_timer <= 0.0:
			_start_next_wave()
