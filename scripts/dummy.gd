class_name Dummy
extends CharacterBody2D

@export_group("Health")
@export var max_health: float = 100.0
@export var dummy_color: Color = Color(0.9, 0.2, 0.2, 1.0)

@export_group("AI")
@export var ai_enabled: bool = true
@export var ai_move_speed: float = 150.0
@export var ai_reaction_delay: float = 0.5
@export var ai_aim_error_deg: float = 10.0
@export var ai_use_stamina: bool = false

@export_group("AI Attack")
@export var ai_attack_range: float = 140.0
@export var ai_attack_arc_deg: float = 90.0
@export var ai_attack_cooldown: float = 3.0
@export var ai_swing_duration: float = 0.1
@export var ai_damage_back: float = 50.0
@export var ai_damage_side: float = 30.0
@export var ai_damage_front: float = 17.5

@export_group("AI Vision")
@export var ai_center_cone_deg: float = 45.0
@export var ai_peripheral_cone_deg: float = 120.0
@export var ai_vision_range: float = 400.0

@export_group("AI Patrol")
@export var patrol_enabled: bool = true
@export var patrol_radius: float = 150.0
@export var patrol_wait_time: float = 2.0
@export var patrol_speed: float = 80.0

var health: float = 100.0
var _damage_popups: Array[Dictionary] = []
var _is_down: bool = false

var _target: Node2D = null
var _reaction_timer: float = 0.0
var _cooldown_remaining: float = 0.0
var _swing_timer: float = 0.0
var _swing_progress: float = 0.0
var _target_rotation: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _alert_timer: float = 0.0
var _patrol_origin: Vector2 = Vector2.ZERO
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_wait_timer: float = 0.0


func _ready() -> void:
	add_to_group("targets")
	health = max_health
	_target_rotation = rotation
	_patrol_origin = global_position
	_pick_patrol_point()


func _physics_process(delta: float) -> void:
	if _is_down:
		return

	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta

	if _swing_timer > 0.0:
		_swing_timer -= delta
		_swing_progress = 1.0 - (_swing_timer / ai_swing_duration)

	# Knockback decay (rotate toward target while knocked back)
	if _knockback_velocity.length() > 5.0:
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
		if _target:
			var to_target := (_target.global_position - global_position).angle()
			var angle_diff := wrapf(to_target - rotation, -PI, PI)
			var rot_speed := 18.0 if _alert_timer > 0.0 else 6.0
			rotation += clampf(angle_diff, -rot_speed * delta, rot_speed * delta)
		move_and_slide()
		return

	_knockback_velocity = Vector2.ZERO

	if not ai_enabled:
		return

	if _alert_timer > 0.0:
		_alert_timer -= delta
	else:
		_detect_player()

	if _target and _reaction_timer > 0.0:
		_reaction_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _target:
		_chase_and_attack(delta)
	else:
		_patrol(delta)


func _detect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		_target = null
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()

	if distance > ai_vision_range:
		_target = null
		return

	var angle_diff := absf(wrapf(to_player.angle() - rotation, -PI, PI))
	var half_peripheral := deg_to_rad(ai_peripheral_cone_deg) * 0.5

	if angle_diff > half_peripheral:
		_target = null
		return

	# Wall check
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)

	if not hit.is_empty():
		_target = null
		return

	if _target == null:
		_reaction_timer = ai_reaction_delay
	_target = player


func _patrol(delta: float) -> void:
	if not patrol_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _patrol_wait_timer > 0.0:
		_patrol_wait_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_point: Vector2 = _patrol_target - global_position
	var distance := to_point.length()

	if distance < 20.0:
		_patrol_wait_timer = patrol_wait_time
		_pick_patrol_point()
		return

	var desired_angle := to_point.angle()
	var angle_diff := wrapf(desired_angle - rotation, -PI, PI)
	var max_rotate := 4.0 * delta
	rotation += clampf(angle_diff, -max_rotate, max_rotate)

	velocity = Vector2.RIGHT.rotated(rotation) * patrol_speed
	move_and_slide()


func _pick_patrol_point() -> void:
	var angle := randf() * TAU
	_patrol_target = _patrol_origin + Vector2(cos(angle), sin(angle)) * randf_range(60.0, patrol_radius)


func _chase_and_attack(delta: float) -> void:
	var to_target: Vector2 = _target.global_position - global_position
	var desired_angle := to_target.angle()

	# Aim error
	desired_angle += deg_to_rad(randf_range(-ai_aim_error_deg, ai_aim_error_deg))

	# Rotate toward target (faster when alert from hit)
	var angle_diff := wrapf(desired_angle - rotation, -PI, PI)
	var rot_speed := 18.0 if _alert_timer > 0.0 else 6.0
	var max_rotate := rot_speed * delta
	rotation += clampf(angle_diff, -max_rotate, max_rotate)

	# Move toward target
	var distance := to_target.length()
	if distance > ai_attack_range * 0.7:
		velocity = Vector2.RIGHT.rotated(rotation) * ai_move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Attack if in range and cone
	var attack_angle_diff := absf(wrapf(to_target.angle() - rotation, -PI, PI))
	var half_center := deg_to_rad(ai_center_cone_deg) * 0.5

	if distance <= ai_attack_range and attack_angle_diff <= half_center and _cooldown_remaining <= 0.0:
		_perform_attack()


func _perform_attack() -> void:
	_cooldown_remaining = ai_attack_cooldown
	_swing_timer = ai_swing_duration
	_swing_progress = 0.0

	var half_arc := deg_to_rad(ai_attack_arc_deg) * 0.5

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	if distance > ai_attack_range:
		return

	var angle_diff := absf(wrapf(to_player.angle() - rotation, -PI, PI))
	if angle_diff > half_arc:
		return

	# Wall check
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		return

	if player.has_method("take_damage"):
		var attack_dir := Vector2.RIGHT.rotated(rotation)
		var player_facing := Vector2.RIGHT.rotated(player.rotation)
		var dot := attack_dir.dot(player_facing)
		var t := (dot + 1.0) * 0.5
		var damage: float
		if t > 0.66:
			damage = lerpf(ai_damage_side, ai_damage_back, (t - 0.66) / 0.34)
		elif t > 0.33:
			damage = lerpf(ai_damage_front, ai_damage_side, (t - 0.33) / 0.33)
		else:
			damage = lerpf(ai_damage_front * 0.85, ai_damage_front, t / 0.33)
		player.take_damage(damage, global_position)


func take_damage(amount: float, from_pos: Vector2) -> void:
	health -= amount
	_damage_popups.append({
		"value": amount,
		"timer": 1.5,
		"offset": Vector2(randf_range(-20, 20), -30),
	})
	queue_redraw()

	# Knockback (80% of attack range)
	var knockback_dir := (global_position - from_pos).normalized()
	_knockback_velocity = knockback_dir * (ai_attack_range * 0.8 * 10.0)

	# Alert on hit - know attacker, rotate faster temporarily
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_target = player
		_reaction_timer = 0.0
		_alert_timer = 3.0

	if health <= 0.0:
		health = 0.0
		_is_down = true
		_knockback_velocity = Vector2.ZERO


func _process(delta: float) -> void:
	var changed := false
	for i in range(_damage_popups.size() - 1, -1, -1):
		_damage_popups[i].timer -= delta
		_damage_popups[i].offset.y -= 40.0 * delta
		if _damage_popups[i].timer <= 0.0:
			_damage_popups.remove_at(i)
		changed = true
	if changed or not _is_down:
		queue_redraw()


func _draw() -> void:
	if _is_down:
		draw_circle(Vector2.ZERO, 12.0, Color(0.3, 0.3, 0.3, 0.5))
		return

	draw_circle(Vector2.ZERO, 12.0, dummy_color)
	draw_line(Vector2.ZERO, Vector2(16, 0), Color.WHITE, 2.0)

	# Vision cone debug
	_draw_cone(ai_peripheral_cone_deg, ai_vision_range, Color(1.0, 0.3, 0.3, 0.06))
	_draw_cone(ai_center_cone_deg, ai_vision_range, Color(1.0, 0.5, 0.1, 0.12))

	# Swing animation
	if _swing_timer > 0.0:
		var half_arc := deg_to_rad(ai_attack_arc_deg) * 0.5
		var swing_angle := lerpf(-half_arc, half_arc, _swing_progress)
		var arc_points := PackedVector2Array()
		arc_points.append(Vector2.ZERO)
		for i in range(13):
			var t_arc := float(i) / 12.0
			var a := lerpf(-half_arc, swing_angle, t_arc)
			arc_points.append(Vector2(cos(a), sin(a)) * ai_attack_range)
		draw_colored_polygon(arc_points, Color(1.0, 0.3, 0.3, 0.3))

	# Health bar
	var bar_width: float = 30.0
	var bar_start := Vector2(-bar_width * 0.5, -22)
	draw_rect(Rect2(bar_start, Vector2(bar_width, 4)), Color(0.2, 0.2, 0.2, 0.8))
	var hp_ratio := health / max_health
	var hp_color := Color.GREEN if hp_ratio > 0.5 else Color(1.0, 0.5, 0.0) if hp_ratio > 0.25 else Color.RED
	draw_rect(Rect2(bar_start, Vector2(bar_width * hp_ratio, 4)), hp_color)

	# Cooldown bar
	if _cooldown_remaining > 0.0:
		var cd_start := Vector2(-bar_width * 0.5, -28)
		var cd_ratio := _cooldown_remaining / ai_attack_cooldown
		draw_rect(Rect2(cd_start, Vector2(bar_width, 3)), Color(0.3, 0.3, 0.3, 0.6))
		draw_rect(Rect2(cd_start, Vector2(bar_width * (1.0 - cd_ratio), 3)), Color.RED)

	# Damage popups
	for popup in _damage_popups:
		var font := ThemeDB.fallback_font
		var text := "%.0f" % popup.value
		draw_string(font, popup.offset, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)


func _draw_cone(angle_deg: float, radius: float, color: Color) -> void:
	var half_angle := deg_to_rad(angle_deg) * 0.5
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(25):
		var t := float(i) / 24.0
		var a := -half_angle + t * half_angle * 2.0
		points.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, color)
