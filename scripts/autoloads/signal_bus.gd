extends Node
## Global event bus. All cross-system signals live here so that
## individual nodes never need direct references to each other.

# -- Enemies --
signal enemy_spawned(enemy: Node2D)
signal enemy_killed(enemy: Node2D, gold_reward: int)
signal enemy_reached_end(enemy: Node2D, lives_cost: int)
signal enemy_damaged(enemy: Node2D, amount: float, damage_type: Enums.DamageType)

# -- Towers --
signal tower_placed(tower: Node2D, tile_pos: Vector2i)
signal tower_sold(tower: Node2D, refund: int)
signal tower_upgraded(tower: Node2D, path_index: int, tier: int)

# -- Waves --
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed()
signal wave_enemies_remaining(count: int)

# -- Economy --
signal gold_changed(new_amount: int)
signal lives_changed(new_amount: int)

# -- Game State --
signal game_started()
signal game_over(victory: bool)
signal game_paused()
signal game_resumed()
signal game_speed_changed(speed: Enums.GameSpeed)
signal restart_requested()

# -- Pathfinding --
signal path_blocked()

# -- Engagement --
signal streak_changed(count: int)
signal near_miss(enemy: Node2D, hp_remaining: float)
signal last_stand_entered()
signal send_wave_bonus(gold_bonus: int)

# -- UI --
signal tower_selected(tower: Node2D)
signal tower_deselected()
signal build_mode_entered(tower_data: TowerData)
signal build_mode_exited()
