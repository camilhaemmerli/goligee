class_name WaterCannonTruck
extends Node2D
## Executive Decree #3: A riot truck drives backward along the path,
## spraying a knockback cone that pushes enemies back.

const DRIVE_SPEED = 40.0
const DRIVE_DURATION = 12.0
const SPRAY_INTERVAL = 0.15
const CONE_ANGLE = PI / 3.0  # 60 degrees
const CONE_RANGE = 56.0
const KNOCKBACK_DIST = 24.0
const DAMAGE_PER_HIT = 5.0
const SLOW_POTENCY = 0.5
const SLOW_DURATION = 1.0

const DIR_NAMES: Array[String] = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
const DIR_VECTORS: Array[Vector2] = [
	Vector2(0, 1), Vector2(-0.7071, 0.7071), Vector2(-1, 0),
	Vector2(-0.7071, -0.7071), Vector2(0, -1), Vector2(0.7071, -0.7071),
	Vector2(1, 0), Vector2(0.7071, 0.7071),
]

var _path: PackedVector2Array
var _path_index: int = 0
var _truck_sprite: Sprite2D
var _dir_textures: Dictionary = {}  ## dir_name -> Texture2D
var _spray_timer: float = 0.0
var _drive_timer: float = 0.0
var _facing_dir: Vector2 = Vector2(0, 1)  # Default facing down
var _cone_draw: Node2D
var _current_dir: String = "s"


func init(world_pos: Vector2, _tile_map: TileMapLayer) -> void:
	var result := AbilityManager.find_nearest_path_and_exit(world_pos)
	if result.is_empty():
		queue_free()
		return

	var full_path: PackedVector2Array = result["path"]
	if full_path.is_empty():
		queue_free()
		return

	# Find the closest point on the path to the placed position
	var best_seg := 0
	var best_dist := INF
	for i in range(full_path.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(world_pos, full_path[i], full_path[i + 1])
		var dist := world_pos.distance_to(closest)
		if dist < best_dist:
			best_dist = dist
			best_seg = i

	# Build a sub-path from the placed segment backward toward spawn
	# (truck drives backward = toward enemy spawn = earlier waypoints)
	var sub_path := PackedVector2Array()
	# Start at the nearest path point
	var start_pt := Geometry2D.get_closest_point_to_segment(world_pos, full_path[best_seg], full_path[best_seg + 1])
	sub_path.append(start_pt)
	# Add earlier waypoints going backward toward spawn (index 0)
	for i in range(best_seg, -1, -1):
		sub_path.append(full_path[i])
	_path = sub_path

	global_position = _path[0]
	_path_index = 1

	# Compute initial facing direction
	if _path.size() >= 2:
		_facing_dir = (_path[1] - _path[0]).normalized()

	_create_truck_sprite()
	_create_cone_draw()


func _create_truck_sprite() -> void:
	_truck_sprite = Sprite2D.new()
	# Preload all 8 directional textures
	for d in DIR_NAMES:
		var tex := load("res://assets/sprites/abilities/water_truck/%s.png" % d)
		if tex:
			_dir_textures[d] = tex
	if _dir_textures.is_empty():
		# Procedural fallback
		var img := Image.create(20, 12, false, Image.FORMAT_RGBA8)
		var body_col := Color("#2A3A5A")
		for x in range(2, 18):
			for y in range(2, 10):
				img.set_pixel(x, y, body_col)
		for x in range(14, 20):
			for y in range(3, 9):
				img.set_pixel(x, y, Color("#4A5A7A"))
		var fallback_tex := ImageTexture.create_from_image(img)
		for d in DIR_NAMES:
			_dir_textures[d] = fallback_tex
		_truck_sprite.scale = Vector2(2.0, 2.0)
	_truck_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_update_truck_direction()
	add_child(_truck_sprite)


func _dir_from_vector(dir: Vector2) -> String:
	var best_dot := -2.0
	var best_dir := "s"
	for i in DIR_VECTORS.size():
		var dot := dir.dot(DIR_VECTORS[i])
		if dot > best_dot:
			best_dot = dot
			best_dir = DIR_NAMES[i]
	return best_dir


func _update_truck_direction() -> void:
	var new_dir := _dir_from_vector(_facing_dir)
	if new_dir != _current_dir or _truck_sprite.texture == null:
		_current_dir = new_dir
		if _dir_textures.has(new_dir):
			_truck_sprite.texture = _dir_textures[new_dir]


func _create_cone_draw() -> void:
	var cone := _ConeDrawScript.new()
	cone.cone_range = CONE_RANGE
	cone.cone_angle = CONE_ANGLE
	cone.facing_dir = _facing_dir
	cone.z_index = -1
	add_child(cone)
	_cone_draw = cone


func _process(delta: float) -> void:
	_drive_timer += delta
	if _drive_timer >= DRIVE_DURATION:
		_finish()
		return

	# Move along reversed path
	if _path_index < _path.size():
		var move_budget := DRIVE_SPEED * delta
		var prev_pos := global_position
		while move_budget > 0.0 and _path_index < _path.size():
			var target := _path[_path_index]
			var to_target := target - global_position
			var dist := to_target.length()
			if dist <= move_budget:
				global_position = target
				move_budget -= dist
				_path_index += 1
			else:
				global_position += to_target.normalized() * move_budget
				move_budget = 0.0

		var move_dir := global_position - prev_pos
		if not move_dir.is_zero_approx():
			_facing_dir = move_dir.normalized()
			_update_truck_direction()
			if _cone_draw:
				_cone_draw.facing_dir = _facing_dir
				_cone_draw.queue_redraw()

	# Spray knockback cone
	_spray_timer += delta
	if _spray_timer >= SPRAY_INTERVAL:
		_spray_timer -= SPRAY_INTERVAL
		_apply_spray()


func _apply_spray() -> void:
	var enemies := SpatialGrid.get_enemies_in_radius(global_position, CONE_RANGE)
	for node in enemies:
		if not node is BaseEnemy:
			continue
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy.health.is_dead:
			continue
		# Skip flying enemies
		if enemy.is_flying():
			continue

		# Check if enemy is within the cone angle
		var to_enemy := (enemy.global_position - global_position).normalized()
		var angle_diff: float = absf(_facing_dir.angle_to(to_enemy))
		if angle_diff > CONE_ANGLE / 2.0:
			continue

		# Apply knockback: push enemy away from truck
		var push_dir := to_enemy
		if push_dir.is_zero_approx():
			push_dir = _facing_dir
		enemy.global_position += push_dir * KNOCKBACK_DIST * 0.3  # Per-tick push

		# Apply damage
		var resists: Dictionary = enemy.resistances.get_all() if enemy.resistances else {}
		var vuln_mod := enemy.get_vulnerability_modifier()
		var armor_shred := enemy.get_armor_shred()
		enemy.health.take_damage(DAMAGE_PER_HIT, Enums.DamageType.HYDRAULIC, resists, vuln_mod, 0.0, 1.0, armor_shred)

		# Apply slow
		if enemy.status_effects:
			var slow := StatusEffectData.new()
			slow.effect_type = Enums.StatusEffectType.SLOW
			slow.duration = SLOW_DURATION
			slow.potency = SLOW_POTENCY
			slow.apply_chance = 1.0
			enemy.status_effects.apply_effect(slow)


func _finish() -> void:
	SignalBus.ability_completed.emit("water_cannon_truck")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


# -- Cone visual draw helper --
class _ConeDrawScript extends Node2D:
	var cone_range: float = 56.0
	var cone_angle: float = PI / 3.0
	var facing_dir: Vector2 = Vector2(0, 1)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if cone_range <= 0.0:
			return
		var base_angle := facing_dir.angle()
		var half_angle := cone_angle / 2.0
		var segments := 16
		var points := PackedVector2Array()
		points.append(Vector2.ZERO)
		for i in range(segments + 1):
			var angle := base_angle - half_angle + (cone_angle * float(i) / float(segments))
			points.append(Vector2(cos(angle), sin(angle)) * cone_range)
		# Fill
		draw_colored_polygon(points, Color(0.5, 0.75, 1.0, 0.12))
		# Border
		for i in range(1, points.size()):
			var next := (i % (points.size() - 1)) + 1
			draw_line(points[i], points[next], Color(0.5, 0.75, 1.0, 0.3), 1.0)
		draw_line(Vector2.ZERO, points[1], Color(0.5, 0.75, 1.0, 0.3), 1.0)
		draw_line(Vector2.ZERO, points[points.size() - 1], Color(0.5, 0.75, 1.0, 0.3), 1.0)
