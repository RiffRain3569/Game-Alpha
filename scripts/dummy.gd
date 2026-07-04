class_name Dummy
extends StaticBody2D

@export var max_health: float = 100.0
@export var dummy_color: Color = Color(0.9, 0.2, 0.2, 1.0)

var health: float = 100.0
var _damage_popups: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("targets")
	health = max_health


func take_damage(amount: float, from_pos: Vector2) -> void:
	health -= amount
	_damage_popups.append({
		"value": amount,
		"timer": 1.5,
		"offset": Vector2(randf_range(-20, 20), -30),
	})
	queue_redraw()

	if health <= 0.0:
		health = 0.0
		_on_down()


func _on_down() -> void:
	modulate = Color(0.3, 0.3, 0.3, 0.5)


func _process(delta: float) -> void:
	var changed := false
	for i in range(_damage_popups.size() - 1, -1, -1):
		_damage_popups[i].timer -= delta
		_damage_popups[i].offset.y -= 40.0 * delta
		if _damage_popups[i].timer <= 0.0:
			_damage_popups.remove_at(i)
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	if health <= 0.0:
		draw_circle(Vector2.ZERO, 12.0, Color(0.3, 0.3, 0.3, 0.5))
		return

	draw_circle(Vector2.ZERO, 12.0, dummy_color)
	draw_line(Vector2.ZERO, Vector2(16, 0), Color.WHITE, 2.0)

	# 체력 바
	var bar_width: float = 30.0
	var bar_start := Vector2(-bar_width * 0.5, -22)
	draw_rect(Rect2(bar_start, Vector2(bar_width, 4)), Color(0.2, 0.2, 0.2, 0.8))
	var hp_ratio := health / max_health
	var hp_color := Color.GREEN if hp_ratio > 0.5 else Color(1.0, 0.5, 0.0) if hp_ratio > 0.25 else Color.RED
	draw_rect(Rect2(bar_start, Vector2(bar_width * hp_ratio, 4)), hp_color)

	# 데미지 팝업
	for popup in _damage_popups:
		var font := ThemeDB.fallback_font
		var text := "%.0f" % popup.value
		draw_string(font, popup.offset, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)
