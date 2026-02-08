extends Node
## Tracks player gold. All gold transactions go through here.

var gold: int = 200


func _ready() -> void:
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.game_started.connect(_on_game_started)


func _on_game_started() -> void:
	gold = 200
	SignalBus.gold_changed.emit(gold)


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
