class_name TearGasProjectile
extends BaseProjectile
## Lobbed tear gas grenade with parabolic arc. Spawns a TearGasCloud on impact.

const FLIGHT_DURATION = 0.6
const ARC_HEIGHT = 40.0

var _start_pos: Vector2
var _end_pos: Vector2
var _flight_timer: float = 0.0
var _base_scale: Vector2

var _cloud_scene: PackedScene  # Not used — cloud is created in code


func _ready() -> void:
	# Capture target position at fire time (ground-targeted, not tracking)
	if is_instance_valid(target):
		_end_pos = target.global_position
	else:
		# Fallback: fire in the direction we were aimed
		_end_pos = global_position + _direction * 150.0

	_start_pos = global_position
	_base_scale = Vector2.ONE

	# Override sprite to show a grenade canister
	if sprite and not sprite.texture:
		_apply_themed_sprite()


func _apply_themed_sprite() -> void:
	sprite.texture = EntitySprites.create_tear_gas_canister()


func _process(delta: float) -> void:
	# Skip base class tracking — we do our own arc movement
	_timer += delta
	if _timer >= lifetime:
		_fade_trail()
		queue_free()
		return

	_flight_timer += delta
	var t := clampf(_flight_timer / FLIGHT_DURATION, 0.0, 1.0)

	# Parabolic arc: -4h * t * (t - 1) gives peak h at t=0.5
	var arc_offset := -4.0 * ARC_HEIGHT * t * (t - 1.0)

	# Linear interpolation for horizontal movement
	var ground_pos := _start_pos.lerp(_end_pos, t)
	global_position = ground_pos + Vector2(0, -arc_offset)

	# Scale 1.0 → 1.3 → 1.0 during flight to simulate isometric height
	var scale_factor := 1.0 + 0.3 * sin(t * PI)
	sprite.scale = _base_scale * scale_factor

	# Rotate the canister sprite for tumbling effect
	sprite.rotation = t * TAU * 1.5

	# Trail update (from base class)
	if _trail:
		_trail_points.append(global_position)
		if _trail_points.size() > MAX_TRAIL_POINTS:
			_trail_points = _trail_points.slice(_trail_points.size() - MAX_TRAIL_POINTS)
		_trail.points = _trail_points

	# Impact when arc completes
	if t >= 1.0:
		_on_impact()


func _on_impact() -> void:
	# Apply initial AoE damage at landing site
	if aoe_radius > 0.0:
		_apply_aoe_damage(_end_pos)

	# Spawn impact particles
	_spawn_impact_particles()

	# Spawn the lingering smoke cloud
	var cloud := TearGasCloud.new()
	cloud.global_position = _end_pos
	cloud.init(damage, damage_type, on_hit_effects, source_tower)

	var effects_container := get_tree().get_first_node_in_group("effects")
	if effects_container:
		effects_container.add_child(cloud)
	else:
		get_tree().current_scene.add_child(cloud)

	SignalBus.chemical_impact.emit(_end_pos, 1.0)
	_fade_trail()
	queue_free()
