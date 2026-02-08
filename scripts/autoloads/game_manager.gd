extends Node
## Central game state controller. Manages pause, speed, win/lose conditions.

var current_speed: Enums.GameSpeed = Enums.GameSpeed.NORMAL
var lives: int = 20
var is_game_over: bool = false
var is_last_stand: bool = false

var _speed_scales := {
	Enums.GameSpeed.PAUSED: 0.0,
	Enums.GameSpeed.NORMAL: 1.0,
	Enums.GameSpeed.FAST: 2.0,
	Enums.GameSpeed.ULTRA: 3.0,
}


func _ready() -> void:
	SignalBus.enemy_reached_end.connect(_on_enemy_reached_end)
	SignalBus.all_waves_completed.connect(_on_all_waves_completed)


func start_game() -> void:
	lives = 20
	is_game_over = false
	is_last_stand = false
	current_speed = Enums.GameSpeed.NORMAL
	Engine.time_scale = 1.0
	SignalBus.lives_changed.emit(lives)
	SignalBus.game_started.emit()


func set_speed(speed: Enums.GameSpeed) -> void:
	current_speed = speed
	Engine.time_scale = _speed_scales[speed]
	SignalBus.game_speed_changed.emit(speed)


func toggle_pause() -> void:
	if current_speed == Enums.GameSpeed.PAUSED:
		set_speed(Enums.GameSpeed.NORMAL)
		SignalBus.game_resumed.emit()
	else:
		set_speed(Enums.GameSpeed.PAUSED)
		SignalBus.game_paused.emit()


func _on_enemy_reached_end(_enemy: Node2D, cost: int) -> void:
	if is_game_over:
		return
	lives = max(lives - cost, 0)
	SignalBus.lives_changed.emit(lives)

	# Last Stand detection
	if lives == 1 and not is_last_stand:
		is_last_stand = true
		SignalBus.last_stand_entered.emit()

	if lives <= 0:
		is_game_over = true
		SignalBus.game_over.emit(false)


func _on_all_waves_completed() -> void:
	if not is_game_over:
		is_game_over = true
		SignalBus.game_over.emit(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("speed_up"):
		match current_speed:
			Enums.GameSpeed.NORMAL:
				set_speed(Enums.GameSpeed.FAST)
			Enums.GameSpeed.FAST:
				set_speed(Enums.GameSpeed.ULTRA)
			Enums.GameSpeed.ULTRA:
				set_speed(Enums.GameSpeed.NORMAL)
