class_name Dummy
extends StaticBody2D

@export var dummy_color: Color = Color(0.9, 0.2, 0.2, 1.0)

func _ready() -> void:
	add_to_group("targets")

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, dummy_color)
	draw_line(Vector2.ZERO, Vector2(16, 0), Color.WHITE, 2.0)
