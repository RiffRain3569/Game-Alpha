extends CharacterBody2D

@export_group("Movement")
@export var move_speed: float = 300.0
@export var backward_multiplier: float = 0.5
@export var strafe_multiplier: float = 0.7
@export var sprint_multiplier: float = 1.8

@export_group("Rotation")
@export var rotation_speed_cap: float = 6.0

@export_group("Stamina")
@export var stamina_max: float = 100.0
@export var stamina_drain_rate: float = 135.0
@export var stamina_recover_rate: float = 33.0
@export var stamina_recover_rate_moving: float = 5.0
@export var stamina_recover_delay: float = 3.0
@export var hit_recovery_bonus: float = 30.0
@export var hit_recovery_duration: float = 1.0

@export_group("Melee Attack")
@export var attack_range: float = 140.0
@export var attack_arc_deg: float = 90.0
@export var attack_cooldown: float = 3.0
@export var swing_duration: float = 0.1
@export var damage_back: float = 50.0
@export var damage_side: float = 30.0
@export var damage_front: float = 17.5

var input_direction: Vector2 = Vector2.ZERO
var _cooldown_remaining: float = 0.0
var _swing_timer: float = 0.0
var _swing_progress: float = 0.0
var _target_rotation: float = 0.0
var _stamina: float = 100.0
var _hit_recovery_timer: float = 0.0
var _stamina_delay_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO

@onready var _vision_cone: VisionCone = $VisionCone


func _ready() -> void:
	_stamina = stamina_max
	_target_rotation = rotation
	add_to_group("player")


func _physics_process(delta: float) -> void:
	# Knockback
	if _knockback_velocity.length() > 5.0:
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
		move_and_slide()
		return
	_knockback_velocity = Vector2.ZERO

	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Stamina sprint
	var is_sprinting := false
	var holding_sprint := Input.is_action_pressed("sprint")
	if holding_sprint and _stamina > 0.0 and input_direction != Vector2.ZERO:
		is_sprinting = true
		_stamina -= stamina_drain_rate * delta
		_stamina = maxf(_stamina, 0.0)
		_stamina_delay_timer = 0.0

	var speed := move_speed
	if input_direction != Vector2.ZERO:
		var facing := Vector2.RIGHT.rotated(rotation)
		var dot := facing.dot(input_direction.normalized())
		# dot=1: forward, dot=-1: backward, dot=0: strafe
		var dir_mult: float
		if dot >= 0.0:
			dir_mult = lerpf(strafe_multiplier, 1.0, dot)
		else:
			dir_mult = lerpf(strafe_multiplier, backward_multiplier, -dot)
		speed *= dir_mult
	if is_sprinting:
		speed *= sprint_multiplier

	velocity = input_direction * speed
	move_and_slide()

	# Stamina recovery
	if not is_sprinting:
		if holding_sprint and input_direction != Vector2.ZERO:
			_stamina_delay_timer = 0.0
		else:
			var current_speed := velocity.length()
			var is_still := current_speed < move_speed * 0.3
			if is_still:
				_stamina_delay_timer += delta
			else:
				_stamina_delay_timer = 0.0
			var recover: float
			if is_still and _stamina_delay_timer >= stamina_recover_delay:
				recover = stamina_recover_rate
			else:
				recover = stamina_recover_rate_moving
			if _hit_recovery_timer > 0.0:
				recover += hit_recovery_bonus
			_stamina = minf(_stamina + recover * delta, stamina_max)

	if _hit_recovery_timer > 0.0:
		_hit_recovery_timer -= delta

	# Rotation with speed cap
	var mouse_pos := get_global_mouse_position()
	_target_rotation = (mouse_pos - global_position).angle()
	var angle_diff := wrapf(_target_rotation - rotation, -PI, PI)
	var max_rotate := rotation_speed_cap * delta
	rotation += clampf(angle_diff, -max_rotate, max_rotate)

	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta

	if _swing_timer > 0.0:
		_swing_timer -= delta
		_swing_progress = 1.0 - (_swing_timer / swing_duration)

	if Input.is_action_just_pressed("attack") and _cooldown_remaining <= 0.0:
		_perform_attack()

	var targets: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("targets"):
		if node is Node2D and node != self:
			targets.append(node as Node2D)
	_vision_cone.detect(targets)

	for result in _vision_cone.get_last_results():
		if result.target:
			match result.level:
				DetectionResult.Level.FULL:
					result.target.modulate.a = 1.0
				DetectionResult.Level.PARTIAL:
					result.target.modulate.a = 0.5
				DetectionResult.Level.NONE:
					result.target.modulate.a = 0.2


func take_damage(_amount: float, from_pos: Vector2) -> void:
	_hit_recovery_timer = hit_recovery_duration
	var knockback_dir := (global_position - from_pos).normalized()
	_knockback_velocity = knockback_dir * (attack_range * 0.8 * 10.0)


func _perform_attack() -> void:
	_cooldown_remaining = attack_cooldown
	_swing_timer = swing_duration
	_swing_progress = 0.0

	var half_arc := deg_to_rad(attack_arc_deg) * 0.5

	var space_state := get_world_2d().direct_space_state

	for node in get_tree().get_nodes_in_group("targets"):
		if node == self or not node is Node2D:
			continue
		var to_target: Vector2 = node.global_position - global_position
		var distance := to_target.length()
		if distance > attack_range:
			continue

		var attack_angle_diff := absf(wrapf(to_target.angle() - rotation, -PI, PI))
		if attack_angle_diff > half_arc:
			continue

		# Wall check
		var query := PhysicsRayQueryParameters2D.create(global_position, node.global_position)
		query.collision_mask = 1
		query.exclude = [get_rid()]
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			continue

		var damage := _calc_angle_damage(node)
		if node.has_method("take_damage"):
			node.take_damage(damage, global_position)


func _calc_angle_damage(target: Node2D) -> float:
	var attack_dir: Vector2 = Vector2.RIGHT.rotated(rotation)
	var target_facing: Vector2 = Vector2.RIGHT.rotated(target.rotation)
	var dot: float = attack_dir.dot(target_facing)
	var t: float = (dot + 1.0) * 0.5
	if t > 0.66:
		return lerpf(damage_side, damage_back, (t - 0.66) / 0.34)
	elif t > 0.33:
		return lerpf(damage_front, damage_side, (t - 0.33) / 0.33)
	else:
		return lerpf(damage_front * 0.85, damage_front, t / 0.33)


func _draw() -> void:
	_vision_cone.draw_debug(self)

	if input_direction != Vector2.ZERO:
		draw_line(Vector2.ZERO, input_direction.rotated(-rotation) * 50.0, Color.YELLOW, 2.0)
	draw_line(Vector2.ZERO, Vector2(60, 0), Color.RED, 1.5)

	# Swing animation
	if _swing_timer > 0.0:
		var half_arc := deg_to_rad(attack_arc_deg) * 0.5
		var swing_angle := lerpf(-half_arc, half_arc, _swing_progress)
		var arc_points := PackedVector2Array()
		arc_points.append(Vector2.ZERO)
		var segments := 12
		for i in range(segments + 1):
			var t_arc := float(i) / float(segments)
			var a := lerpf(-half_arc, swing_angle, t_arc)
			arc_points.append(Vector2(cos(a), sin(a)) * attack_range)
		draw_colored_polygon(arc_points, Color(1.0, 1.0, 1.0, 0.3))
		var bat_end := Vector2(cos(swing_angle), sin(swing_angle)) * attack_range
		draw_line(Vector2.ZERO, bat_end, Color.WHITE, 3.0)

	# Cooldown gauge
	var cd_ratio := clampf(_cooldown_remaining / attack_cooldown, 0.0, 1.0)
	var bar_start := Vector2(-15, -30)
	draw_rect(Rect2(bar_start, Vector2(30, 4)), Color(0.3, 0.3, 0.3, 0.8))
	var cd_color := Color.RED if cd_ratio > 0.0 else Color.GREEN
	draw_rect(Rect2(bar_start, Vector2(30 * (1.0 - cd_ratio), 4)), cd_color)

	# Stamina gauge
	var stam_start := Vector2(-15, -36)
	draw_rect(Rect2(stam_start, Vector2(30, 4)), Color(0.3, 0.3, 0.3, 0.8))
	var stam_ratio := _stamina / stamina_max
	var stam_color := Color(0.2, 0.8, 1.0) if _hit_recovery_timer <= 0.0 else Color(0.4, 1.0, 0.6)
	draw_rect(Rect2(stam_start, Vector2(30 * stam_ratio, 4)), stam_color)


func _process(_delta: float) -> void:
	queue_redraw()
