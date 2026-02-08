class_name HUD
extends CanvasLayer
## Top-level HUD showing gold, lives, wave counter, and game speed.

@onready var gold_label: Label = $TopBar/GoldLabel
@onready var lives_label: Label = $TopBar/LivesLabel
@onready var wave_label: Label = $TopBar/WaveLabel
@onready var speed_label: Label = $TopBar/SpeedLabel
@onready var enemies_label: Label = $TopBar/EnemiesLabel


func _ready() -> void:
	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.lives_changed.connect(_on_lives_changed)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_enemies_remaining.connect(_on_enemies_remaining)
	SignalBus.game_speed_changed.connect(_on_speed_changed)
	SignalBus.game_over.connect(_on_game_over)


func _on_gold_changed(amount: int) -> void:
	gold_label.text = str(amount)


func _on_lives_changed(amount: int) -> void:
	lives_label.text = str(amount)


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Wave " + str(wave_number)


func _on_enemies_remaining(count: int) -> void:
	enemies_label.text = str(count) + " remaining"


func _on_speed_changed(speed: Enums.GameSpeed) -> void:
	match speed:
		Enums.GameSpeed.PAUSED:
			speed_label.text = "PAUSED"
		Enums.GameSpeed.NORMAL:
			speed_label.text = "1x"
		Enums.GameSpeed.FAST:
			speed_label.text = "2x"
		Enums.GameSpeed.ULTRA:
			speed_label.text = "3x"


func _on_game_over(victory: bool) -> void:
	if victory:
		wave_label.text = "VICTORY"
	else:
		wave_label.text = "DEFEAT"
