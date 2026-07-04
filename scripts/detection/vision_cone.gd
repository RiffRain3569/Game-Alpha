class_name VisionCone
extends DetectionChannel

@export_group("Vision Cone")
@export var center_cone_angle_deg: float = 45.0
@export var peripheral_cone_angle_deg: float = 120.0
@export var vision_range: float = 400.0

@export_group("Debug Colors")
@export var center_color: Color = Color(1.0, 0.9, 0.0, 0.25)
@export var peripheral_color: Color = Color(0.3, 0.6, 1.0, 0.12)
@export var line_full_color: Color = Color(1.0, 0.2, 0.1, 0.8)
@export var line_partial_color: Color = Color(0.3, 0.6, 1.0, 0.6)

@export_group("Raycast")
@export_flags_2d_physics var wall_mask: int = 1

var _last_results: Array[DetectionResult] = []


func detect(targets: Array[Node2D]) -> Array[DetectionResult]:
	_last_results.clear()
	var owner_pos: Vector2 = global_position
	var owner_angle: float = global_rotation
	var space_state := get_world_2d().direct_space_state

	var exclude_rids: Array[RID] = []
	var parent_body := get_parent() as PhysicsBody2D
	if parent_body:
		exclude_rids.append(parent_body.get_rid())

	for target in targets:
		var result := DetectionResult.new()
		result.target = target

		var to_target: Vector2 = target.global_position - owner_pos
		var distance: float = to_target.length()

		if distance > vision_range or distance < 0.001:
			result.level = DetectionResult.Level.NONE
			_last_results.append(result)
			continue

		var angle_diff: float = absf(wrapf(to_target.angle() - owner_angle, -PI, PI))
		var half_center: float = deg_to_rad(center_cone_angle_deg) * 0.5
		var half_peripheral: float = deg_to_rad(peripheral_cone_angle_deg) * 0.5

		var in_center: bool = angle_diff <= half_center
		var in_peripheral: bool = angle_diff <= half_peripheral

		if not in_peripheral:
			result.level = DetectionResult.Level.NONE
			_last_results.append(result)
			continue

		var query := PhysicsRayQueryParameters2D.create(owner_pos, target.global_position)
		query.collision_mask = wall_mask
		query.exclude = exclude_rids

		var hit: Dictionary = space_state.intersect_ray(query)

		if not hit.is_empty():
			result.level = DetectionResult.Level.NONE
			_last_results.append(result)
			continue

		if in_center:
			result.level = DetectionResult.Level.FULL
			result.position_accuracy = 1.0
		else:
			result.level = DetectionResult.Level.PARTIAL
			result.position_accuracy = 0.5

		result.detected_position = target.global_position
		_last_results.append(result)

	return _last_results


func get_last_results() -> Array[DetectionResult]:
	return _last_results


func draw_debug(canvas: CanvasItem) -> void:
	_draw_cone_with_walls(canvas, peripheral_cone_angle_deg, vision_range, peripheral_color)
	_draw_cone_with_walls(canvas, center_cone_angle_deg, vision_range, center_color)
	_draw_detection_lines(canvas)


func _draw_cone_with_walls(canvas: CanvasItem, angle_deg: float, radius: float, color: Color) -> void:
	var half_angle: float = deg_to_rad(angle_deg) * 0.5
	var segment_count: int = 48
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)

	var space_state := get_world_2d().direct_space_state
	var origin: Vector2 = global_position

	var exclude_rids: Array[RID] = []
	var parent_body := get_parent() as PhysicsBody2D
	if parent_body:
		exclude_rids.append(parent_body.get_rid())

	for i in range(segment_count + 1):
		var t: float = float(i) / float(segment_count)
		var angle: float = -half_angle + t * half_angle * 2.0
		var dir := Vector2(cos(angle), sin(angle))
		var end_point: Vector2 = dir * radius

		var world_end: Vector2 = origin + dir.rotated(global_rotation) * radius
		var query := PhysicsRayQueryParameters2D.create(origin, world_end)
		query.collision_mask = wall_mask
		query.exclude = exclude_rids

		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_dist: float = (hit.position - origin).length()
			end_point = dir * hit_dist

		points.append(end_point)

	canvas.draw_colored_polygon(points, color)


func _draw_detection_lines(canvas: CanvasItem) -> void:
	for result in _last_results:
		if result.level == DetectionResult.Level.NONE or result.target == null:
			continue
		var target_local: Vector2 = canvas.to_local(result.target.global_position)
		var color: Color
		if result.level == DetectionResult.Level.FULL:
			color = line_full_color
		else:
			color = line_partial_color
		canvas.draw_line(Vector2.ZERO, target_local, color, 2.0)
		canvas.draw_circle(target_local, 6.0, color)
