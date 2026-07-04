extends Control

var _player: CharacterBody2D
var _dummy: CharacterBody2D
var _vision_cone: Node2D
var _sliders: Dictionary = {}
var _scroll: ScrollContainer
var _vbox: VBoxContainer

var _player_start_pos: Vector2
var _dummy_start_pos: Vector2

const PARAMS := [
	["== PLAYER ==", "", "", 0, 0, 0],
	["Move Speed", "player", "move_speed", 100.0, 600.0, 300.0],
	["Backward Mult", "player", "backward_multiplier", 0.2, 1.0, 0.5],
	["Strafe Mult", "player", "strafe_multiplier", 0.3, 1.0, 0.7],
	["Sprint Mult", "player", "sprint_multiplier", 1.0, 3.0, 1.8],
	["Rotation Cap", "player", "rotation_speed_cap", 1.0, 20.0, 6.0],
	["== STAMINA ==", "", "", 0, 0, 0],
	["Stamina Max", "player", "stamina_max", 30.0, 200.0, 100.0],
	["Stamina Drain", "player", "stamina_drain_rate", 20.0, 300.0, 135.0],
	["Stamina Recover", "player", "stamina_recover_rate", 5.0, 100.0, 33.0],
	["Recover Moving", "player", "stamina_recover_rate_moving", 1.0, 30.0, 5.0],
	["Recover Delay", "player", "stamina_recover_delay", 0.0, 10.0, 3.0],
	["Hit Recovery Bonus", "player", "hit_recovery_bonus", 0.0, 80.0, 30.0],
	["== ATTACK ==", "", "", 0, 0, 0],
	["Attack Range", "player", "attack_range", 50.0, 300.0, 140.0],
	["Attack Arc", "player", "attack_arc_deg", 30.0, 180.0, 90.0],
	["Attack Cooldown", "player", "attack_cooldown", 0.5, 8.0, 3.0],
	["Dmg Back", "player", "damage_back", 10.0, 100.0, 50.0],
	["Dmg Side", "player", "damage_side", 5.0, 80.0, 30.0],
	["Dmg Front", "player", "damage_front", 5.0, 50.0, 17.5],
	["== VISION ==", "", "", 0, 0, 0],
	["Center Cone", "vision", "center_cone_angle_deg", 10.0, 180.0, 45.0],
	["Peripheral Cone", "vision", "peripheral_cone_angle_deg", 30.0, 360.0, 120.0],
	["Vision Range", "vision", "vision_range", 100.0, 800.0, 400.0],
	["== AI ==", "", "", 0, 0, 0],
	["AI Enabled", "dummy", "ai_enabled", 0.0, 1.0, 1.0],
	["AI Move Speed", "dummy", "ai_move_speed", 50.0, 400.0, 150.0],
	["AI Reaction Delay", "dummy", "ai_reaction_delay", 0.0, 3.0, 0.5],
	["AI Aim Error", "dummy", "ai_aim_error_deg", 0.0, 45.0, 10.0],
	["AI Attack Range", "dummy", "ai_attack_range", 50.0, 300.0, 140.0],
	["AI Cooldown", "dummy", "ai_attack_cooldown", 0.5, 8.0, 3.0],
	["AI Vision Range", "dummy", "ai_vision_range", 100.0, 800.0, 400.0],
]


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_dummy = get_tree().get_first_node_in_group("targets")
	if _player:
		_vision_cone = _player.get_node("VisionCone")
		_player_start_pos = _player.global_position
	if _dummy:
		_dummy_start_pos = _dummy.global_position

	_build_ui()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_right = 260.0
	panel.offset_bottom = 0.0
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	panel.add_theme_stylebox_override("panel", style)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_vbox)

	# Reset button
	var reset_btn := Button.new()
	reset_btn.text = "RESET"
	reset_btn.pressed.connect(_on_reset)
	_vbox.add_child(reset_btn)

	# Sliders
	for param in PARAMS:
		var label_text: String = param[0]
		var target: String = param[1]
		var prop: String = param[2]

		if target == "":
			var header := Label.new()
			header.text = label_text
			header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
			_vbox.add_child(header)
			continue

		var container := VBoxContainer.new()
		_vbox.add_child(container)

		var min_val: float = param[3]
		var max_val: float = param[4]
		var default_val: float = param[5]

		var lbl := Label.new()
		lbl.text = "%s: %.1f" % [label_text, default_val]
		lbl.add_theme_font_size_override("font_size", 12)
		container.add_child(lbl)

		var slider := HSlider.new()
		slider.min_value = min_val
		slider.max_value = max_val
		slider.step = 0.1 if max_val <= 10.0 else 1.0
		slider.value = default_val
		slider.custom_minimum_size.x = 220
		slider.custom_minimum_size.y = 20
		container.add_child(slider)

		var key := "%s.%s" % [target, prop]
		_sliders[key] = {"slider": slider, "label": lbl, "name": label_text, "target": target, "prop": prop}
		slider.value_changed.connect(_on_slider_changed.bind(key))


func _on_slider_changed(value: float, key: String) -> void:
	var data: Dictionary = _sliders[key]
	data.label.text = "%s: %.1f" % [data.name, value]

	var target_node: Node = null
	match data.target:
		"player":
			target_node = _player
		"dummy":
			target_node = _dummy
		"vision":
			target_node = _vision_cone

	if target_node == null:
		return

	var prop: String = data.prop
	if prop == "ai_enabled":
		target_node.set(prop, value > 0.5)
	else:
		target_node.set(prop, value)


func _on_reset() -> void:
	if _player:
		_player.global_position = _player_start_pos
		_player.set("_stamina", _player.get("stamina_max"))
		_player.set("_cooldown_remaining", 0.0)
		_player.set("_knockback_velocity", Vector2.ZERO)
	if _dummy:
		_dummy.global_position = _dummy_start_pos
		_dummy.set("health", _dummy.get("max_health"))
		_dummy.set("_is_down", false)
		_dummy.set("_target", null)
		_dummy.set("_cooldown_remaining", 0.0)
		_dummy.set("_knockback_velocity", Vector2.ZERO)
		_dummy.set("_alert_timer", 0.0)
		_dummy.modulate = Color.WHITE
		_dummy.queue_redraw()
