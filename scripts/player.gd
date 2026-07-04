extends CharacterBody2D

@export var move_speed: float = 300.0
@export var sprint_multiplier: float = 1.8

var input_direction: Vector2 = Vector2.ZERO

@onready var _vision_cone: VisionCone = $VisionCone


func _physics_process(_delta: float) -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var speed := move_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	velocity = input_direction * speed
	move_and_slide()

	var mouse_pos := get_global_mouse_position()
	rotation = (mouse_pos - global_position).angle()

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


func _draw() -> void:
	_vision_cone.draw_debug(self)

	if input_direction != Vector2.ZERO:
		draw_line(Vector2.ZERO, input_direction.rotated(-rotation) * 50.0, Color.YELLOW, 2.0)
	draw_line(Vector2.ZERO, Vector2(60, 0), Color.RED, 1.5)


func _process(_delta: float) -> void:
	queue_redraw()
