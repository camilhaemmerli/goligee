extends Node
## Tracks player gold. All gold transactions go through here.
## Internal gold is stored at BUDGET_SCALE (×1000) for granular display.

const BUDGET_SCALE := 1000
const STARTING_GOLD := 15

var gold: int = STARTING_GOLD * BUDGET_SCALE

# Income tracking for affordability projections
var _gold_per_wave: Array[int] = []
var _gold_at_wave_start: int = 0


func _ready() -> void:
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.game_started.connect(_on_game_started)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_completed.connect(_on_wave_completed)


func _on_game_started() -> void:
	gold = STARTING_GOLD * BUDGET_SCALE
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
	add_gold(reward * BUDGET_SCALE)


## Add raw (already-scaled) gold amount.
func add_gold(amount: int) -> void:
	gold += amount
	SignalBus.gold_changed.emit(gold)


## Add gold from a data-file value (e.g. wave bonus, sell refund). Scales by BUDGET_SCALE.
func add_gold_data(amount: int) -> void:
	add_gold(amount * BUDGET_SCALE)


## Spend gold for a data-file cost (tower build_cost, upgrade tier cost). Scales by BUDGET_SCALE.
func spend_gold(amount: int) -> bool:
	var cost := amount * BUDGET_SCALE
	if gold >= cost:
		gold -= cost
		SignalBus.gold_changed.emit(gold)
		return true
	return false


## Check if player can afford a data-file cost (tower build_cost, upgrade tier cost).
func can_afford(amount: int) -> bool:
	return gold >= amount * BUDGET_SCALE


## Apply between-wave interest: 8% of current gold, min 4k balance, max 8k interest.
func apply_interest() -> void:
	if gold < 4 * BUDGET_SCALE:
		return
	var interest := clampi(int(gold * 0.08), 0, 8 * BUDGET_SCALE)
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


## Format a raw (scaled) gold amount for display. E.g. 15000 → "$15k", 1500 → "$1.5k".
static func format_gold(amount: int) -> String:
	if amount == 0:
		return "$0"
	var negative := amount < 0
	var abs_amount := absi(amount)
	var prefix := "-" if negative else ""
	if abs_amount >= 1000:
		var k := abs_amount / 1000
		var hundreds := (abs_amount % 1000) / 100
		if hundreds > 0:
			return prefix + "$" + str(k) + "." + str(hundreds) + "k"
		return prefix + "$" + str(k) + "k"
	return prefix + "$" + str(abs_amount)


## Format a raw (scaled) gold amount without "$" prefix. E.g. 15000 → "15k".
static func format_gold_plain(amount: int) -> String:
	if amount == 0:
		return "0"
	var negative := amount < 0
	var abs_amount := absi(amount)
	var prefix := "-" if negative else ""
	if abs_amount >= 1000:
		var k := abs_amount / 1000
		var hundreds := (abs_amount % 1000) / 100
		if hundreds > 0:
			return prefix + str(k) + "." + str(hundreds) + "k"
		return prefix + str(k) + "k"
	return prefix + str(abs_amount)


## Format a raw (scaled) gold amount as full number. E.g. 15000 → "$15,000".
static func format_gold_full(amount: int) -> String:
	if amount == 0:
		return "$0"
	var negative := amount < 0
	var abs_amount := absi(amount)
	var prefix := "-" if negative else ""
	# Add thousands separators
	var s := str(abs_amount)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return prefix + "$" + result


## Format a data-file cost for display. E.g. 5 → "$5k", 12 → "$12k".
static func format_cost(amount: int) -> String:
	return format_gold(amount * BUDGET_SCALE)
