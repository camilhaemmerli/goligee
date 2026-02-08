extends Node
## Tracks player gold. All gold transactions go through here.

var gold: int = 200

# Income tracking for affordability projections
var _gold_per_wave: Array[int] = []
var _gold_at_wave_start: int = 0


func _ready() -> void:
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.game_started.connect(_on_game_started)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_completed.connect(_on_wave_completed)


func _on_game_started() -> void:
	gold = 200
	_gold_per_wave.clear()
	_gold_at_wave_start = gold
	SignalBus.gold_changed.emit(gold)


func _on_wave_started(_wave_number: int) -> void:
	_gold_at_wave_start = gold


func _on_wave_completed(_wave_number: int) -> void:
	var earned := gold - _gold_at_wave_start
	_gold_per_wave.append(max(earned, 0))
	# Keep last 5 waves for averaging
	if _gold_per_wave.size() > 5:
		_gold_per_wave.remove_at(0)


func _on_enemy_killed(_enemy: Node2D, reward: int) -> void:
	add_gold(reward)


func add_gold(amount: int) -> void:
	gold += amount
	SignalBus.gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		SignalBus.gold_changed.emit(gold)
		return true
	return false


func can_afford(amount: int) -> bool:
	return gold >= amount


## Apply between-wave interest: 5% of current gold, min 50 balance, max 100 interest.
func apply_interest() -> void:
	if gold < 50:
		return
	var interest := clampi(int(gold * 0.05), 0, 100)
	if interest > 0:
		add_gold(interest)


## Get average gold income per wave (from recent history).
func get_avg_gold_per_wave() -> float:
	if _gold_per_wave.is_empty():
		return 0.0
	var total := 0
	for g in _gold_per_wave:
		total += g
	return float(total) / _gold_per_wave.size()
