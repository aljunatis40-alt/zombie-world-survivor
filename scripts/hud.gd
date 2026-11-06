extends Control

signal fire_requested
signal reload_requested
signal jump_requested
signal sprint_changed(active: bool)

const BASE_BUTTON_SIZE := Vector2(92, 64)
const BASE_FIRE_SIZE := Vector2(108, 78)
const LOOK_ZONE_RATIO := 0.48
var joystick_radius := 68.0
var ui_scale := 1.0
var status_label: Label
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var hint_label: Label
var objective_label: Label
var fire_button: Button
var reload_button: Button
var jump_button: Button
var sprint_button: Button
var move_origin := Vector2.ZERO
var move_pointer := -1
var look_pointer := -1
var joystick := Vector2.ZERO
var player_ref: Node
var sprint_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hud()
	call_deferred("_find_player")
	call_deferred("_layout_hud")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(fire_button):
		_layout_hud()

func _build_hud() -> void:
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(0.93, 0.96, 0.9))
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(status_label)

	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.025, 0.035, 0.03, 0.78)
	add_child(health_bar_bg)
	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.28, 0.78, 0.38, 0.95)
	health_bar_bg.add_child(health_bar_fill)

	objective_label = Label.new()
	objective_label.text = "MISSION 01  |  REACH THE SUPPLY CRATE  •  FOLLOW THE ORANGE FLAG"
	objective_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.34, 0.96))
	objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	objective_label.add_theme_constant_override("shadow_offset_x", 2)
	objective_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(objective_label)

	hint_label = Label.new()
	hint_label.text = "MOVE"
	hint_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.86, 0.8))
	add_child(hint_label)

	fire_button = _make_button("FIRE")
	fire_button.pressed.connect(func(): fire_requested.emit())
	reload_button = _make_button("RELOAD")
	reload_button.pressed.connect(func(): reload_requested.emit())
	jump_button = _make_button("JUMP")
	jump_button.pressed.connect(func(): jump_requested.emit())
	sprint_button = _make_button("RUN")
	sprint_button.button_down.connect(func():
		sprint_active = true
		sprint_changed.emit(true)
	)
	sprint_button.button_up.connect(func():
		sprint_active = false
		sprint_changed.emit(false)
	)

func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.09, 0.13, 0.12, 0.82)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.17, 0.25, 0.19, 0.94)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.35, 0.19, 0.12, 0.96)))
	add_child(button)
	return button

func _layout_hud() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	ui_scale = clampf(minf(size.x / 1280.0, size.y / 720.0), 0.72, 1.0)
	joystick_radius = 68.0 * ui_scale
	var margin := 24.0 * ui_scale
	var gap := 12.0 * ui_scale
	var action_size := BASE_BUTTON_SIZE * ui_scale
	var fire_size := BASE_FIRE_SIZE * ui_scale

	status_label.position = Vector2(margin, margin * 0.8)
	status_label.add_theme_font_size_override("font_size", roundi(22.0 * ui_scale))
	health_bar_bg.position = Vector2(margin, margin * 2.55)
	health_bar_bg.size = Vector2(220.0 * ui_scale, 10.0 * ui_scale)
	health_bar_fill.position = Vector2.ZERO
	health_bar_fill.size = health_bar_bg.size
	objective_label.position = Vector2(margin, margin * 3.45)
	objective_label.add_theme_font_size_override("font_size", roundi(16.0 * ui_scale))
	objective_label.size = Vector2(size.x * 0.72, 34.0 * ui_scale)
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(margin + 8.0 * ui_scale, -margin - 94.0 * ui_scale)
	hint_label.add_theme_font_size_override("font_size", roundi(14.0 * ui_scale))

	_place_button(fire_button, fire_size, Vector2(-margin - fire_size.x, -margin - fire_size.y))
	_place_button(reload_button, action_size, Vector2(-margin - fire_size.x - gap - action_size.x, -margin - action_size.y))
	_place_button(jump_button, action_size, Vector2(-margin - fire_size.x, -margin - fire_size.y - gap - action_size.y))
	_place_button(sprint_button, action_size, Vector2(-margin - fire_size.x - gap - action_size.x, -margin - fire_size.y - gap - action_size.y))
	queue_redraw()

func _place_button(button: Button, button_size: Vector2, offset: Vector2) -> void:
	button.anchor_left = 1.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.size = button_size
	button.position = offset
	button.add_theme_font_size_override("font_size", roundi(17.0 * ui_scale))

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.72, 0.78, 0.68, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

func _find_player() -> void:
	player_ref = get_parent().get_node_or_null("Survivor")

func set_status(health: int, zombie_count: int, ammo: int, reserve: int, reloading: bool = false) -> void:
	if is_instance_valid(status_label):
		var reload_text := "     RELOADING..." if reloading else ""
		status_label.text = "HP  %03d     AMMO  %02d/%02d     INFECTED  %02d%s" % [health, ammo, reserve, zombie_count, reload_text]
	if is_instance_valid(health_bar_fill):
		var ratio := clampf(float(health) / 100.0, 0.0, 1.0)
		health_bar_fill.size.x = health_bar_bg.size.x * ratio
		health_bar_fill.color = Color(0.28, 0.78, 0.38, 0.95) if ratio > 0.5 else (Color(0.95, 0.68, 0.18, 0.95) if ratio > 0.25 else Color(0.92, 0.24, 0.20, 0.98))

func _is_over_action_button(point: Vector2) -> bool:
	for button in [fire_button, reload_button, jump_button, sprint_button]:
		if is_instance_valid(button) and button.get_global_rect().has_point(point):
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < size.x * 0.42 and event.position.y > size.y * 0.42 and move_pointer == -1:
				move_pointer = event.index
				move_origin = event.position
				joystick = Vector2.ZERO
				queue_redraw()
			elif event.position.x >= size.x * LOOK_ZONE_RATIO and event.position.y > size.y * 0.18 and look_pointer == -1 and not _is_over_action_button(event.position):
				look_pointer = event.index
		else:
			if event.index == move_pointer:
				move_pointer = -1
				joystick = Vector2.ZERO
				if is_instance_valid(player_ref):
					player_ref.call("set_mobile_move", Vector2.ZERO)
				queue_redraw()
			if event.index == look_pointer:
				look_pointer = -1
	elif event is InputEventScreenDrag:
		if event.index == move_pointer:
			joystick = ((event.position - move_origin) / joystick_radius).limit_length(1.0)
			if is_instance_valid(player_ref):
				player_ref.call("set_mobile_move", joystick)
			queue_redraw()
		elif event.index == look_pointer and is_instance_valid(player_ref):
			player_ref.call("add_mobile_look", event.relative)

func _draw() -> void:
	var center := move_origin if move_pointer != -1 else Vector2(112.0 * ui_scale, size.y - 122.0 * ui_scale)
	draw_circle(center, joystick_radius, Color(0.02, 0.04, 0.03, 0.28))
	draw_arc(center, joystick_radius, 0, TAU, 48, Color(0.82, 0.88, 0.78, 0.52), 3.0 * ui_scale)
	var knob := center + joystick * joystick_radius * 0.62
	draw_circle(knob, 29.0 * ui_scale, Color(0.72, 0.82, 0.68, 0.38))
	draw_arc(knob, 29.0 * ui_scale, 0, TAU, 32, Color(0.92, 0.96, 0.88, 0.72), 2.0 * ui_scale)
	var aim_center := size * 0.5
	var reticle_color := Color(0.94, 0.96, 0.88, 0.78)
	draw_line(aim_center + Vector2(-13, 0) * ui_scale, aim_center + Vector2(-5, 0) * ui_scale, reticle_color, 2.0 * ui_scale)
	draw_line(aim_center + Vector2(5, 0) * ui_scale, aim_center + Vector2(13, 0) * ui_scale, reticle_color, 2.0 * ui_scale)
	draw_line(aim_center + Vector2(0, -13) * ui_scale, aim_center + Vector2(0, -5) * ui_scale, reticle_color, 2.0 * ui_scale)
	draw_line(aim_center + Vector2(0, 5) * ui_scale, aim_center + Vector2(0, 13) * ui_scale, reticle_color, 2.0 * ui_scale)
	draw_circle(aim_center, 1.8 * ui_scale, reticle_color)
