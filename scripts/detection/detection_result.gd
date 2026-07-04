class_name DetectionResult
extends RefCounted

enum Level {
	NONE,
	PARTIAL,
	FULL,
}

var level: Level = Level.NONE
var target: Node2D = null
var position_accuracy: float = 0.0
var detected_position: Vector2 = Vector2.ZERO
