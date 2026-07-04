extends CharacterBody2D

@export var move_speed: float = 300.0
@export var sprint_multiplier: float = 1.8

var input_direction: Vector2 = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var speed = move_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	velocity = input_direction * speed
	move_and_slide()

	var mouse_pos = get_global_mouse_position()
	rotation = (mouse_pos - global_position).angle()

func _draw() -> void:
	if input_direction != Vector2.ZERO:
		draw_line(Vector2.ZERO, input_direction.rotated(-rotation) * 50.0, Color.YELLOW, 2.0)
	draw_line(Vector2.ZERO, Vector2(60, 0), Color.RED, 1.5)

func _process(_delta: float) -> void:
	queue_redraw()
