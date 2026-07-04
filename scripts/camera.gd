extends Camera2D

@export var look_offset_strength: float = 0.25
@export var offset_max_distance: float = 120.0
@export var smoothing_speed: float = 5.0

var _target_offset: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	if look_offset_strength <= 0.0:
		offset = Vector2.ZERO
		return

	var look_dir = Vector2.RIGHT.rotated(get_parent().rotation)
	_target_offset = look_dir * offset_max_distance * look_offset_strength
	offset = offset.lerp(_target_offset, smoothing_speed * delta)
