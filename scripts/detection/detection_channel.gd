class_name DetectionChannel
extends Node2D

func detect(targets: Array[Node2D]) -> Array[DetectionResult]:
	push_error("DetectionChannel.detect() must be overridden: " + name)
	return []

func draw_debug(canvas: CanvasItem) -> void:
	pass

func get_last_results() -> Array[DetectionResult]:
	return []
