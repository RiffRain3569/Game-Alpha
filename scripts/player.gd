extends CharacterBody2D

@export_group("Movement")
@export var move_speed: float = 300.0
@export var sprint_multiplier: float = 1.8

@export_group("Melee Attack")
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 3.0
@export var damage_back: float = 50.0
@export var damage_side: float = 30.0
@export var damage_front: float = 17.5

var input_direction: Vector2 = Vector2.ZERO
var _cooldown_remaining: float = 0.0

@onready var _vision_cone: VisionCone = $VisionCone


func _physics_process(delta: float) -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var speed := move_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	velocity = input_direction * speed
	move_and_slide()

	var mouse_pos := get_global_mouse_position()
	rotation = (mouse_pos - global_position).angle()

	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta

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


func _perform_attack() -> void:
	_cooldown_remaining = attack_cooldown

	for node in get_tree().get_nodes_in_group("targets"):
		if node == self or not node is Node2D:
			continue
		var to_target: Vector2 = node.global_position - global_position
		var distance := to_target.length()
		if distance > attack_range:
			continue

		var attack_angle_diff := absf(wrapf(to_target.angle() - rotation, -PI, PI))
		if attack_angle_diff > deg_to_rad(30.0):
			continue

		var damage := _calc_angle_damage(node)
		if node.has_method("take_damage"):
			node.take_damage(damage, global_position)


func _calc_angle_damage(target: Node2D) -> float:
	var attack_dir: Vector2 = Vector2.RIGHT.rotated(rotation)
	var target_facing: Vector2 = Vector2.RIGHT.rotated(target.rotation)
	var dot: float = attack_dir.dot(target_facing)
	# dot=1: 같은 방향(후면 공격), dot=-1: 마주봄(정면 공격)
	var t: float = (dot + 1.0) * 0.5  # 0=정면, 1=후면
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

	# 각목 히트박스 (쿨��운 직후 잠깐 표시)
	if _cooldown_remaining > attack_cooldown - 0.15:
		var hit_end := Vector2(attack_range, 0)
		draw_line(Vector2.ZERO, hit_end, Color.WHITE, 4.0)

	# 쿨다운 게이지
	var cd_ratio := clampf(_cooldown_remaining / attack_cooldown, 0.0, 1.0)
	var bar_start := Vector2(-15, -25)
	draw_rect(Rect2(bar_start, Vector2(30, 4)), Color(0.3, 0.3, 0.3, 0.8))
	var cd_color := Color.RED if cd_ratio > 0.0 else Color.GREEN
	draw_rect(Rect2(bar_start, Vector2(30 * (1.0 - cd_ratio), 4)), cd_color)


func _process(_delta: float) -> void:
	queue_redraw()
