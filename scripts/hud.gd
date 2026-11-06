extends Control

signal fire_requested
signal reload_requested
signal jump_requested
signal sprint_changed(active: bool)

const JOYSTICK_RADIUS := 68.0
const LOOK_ZONE_RATIO := 0.48
const BUTTON_SIZE := Vector2(92, 64)
var status_label: Label
var hint_label: Label
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

func _build_hud() -> void:
	status_label = Label.new()
	status_label.position = Vector2(28, 22)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(0.93, 0.96, 0.9))
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(status_label)

	hint_label = Label.new()
	hint_label.text = "MOVE"
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(34, -108)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.86, 0.8))
	add_child(hint_label)

	fire_button = _make_button("FIRE", Vector2(-132, -118), Vector2(108, 78))
	fire_button.pressed.connect(func(): fire_requested.emit())
	reload_button = _make_button("RELOAD", Vector2(-244, -92), BUTTON_SIZE)
	reload_button.pressed.connect(func(): reload_requested.emit())
	jump_button = _make_button("JUMP", Vector2(-132, -210), BUTTON_SIZE)
	jump_button.pressed.connect(func(): jump_requested.emit())
	sprint_button = _make_button("RUN", Vector2(-244, -210), BUTTON_SIZE)
	sprint_button.button_down.connect(func():
		sprint_active = true
		sprint_changed.emit(true)
	)
	sprint_button.button_up.connect(func():
		sprint_active = false
		sprint_changed.emit(false)
	)

func _make_button(label: String, offset: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.size = button_size
	button.anchor_left = 1
	button.anchor_top = 1
	button.anchor_right = 1
	button.anchor_bottom = 1
	button.position = offset
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.09, 0.13, 0.12, 0.82)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.17, 0.25, 0.19, 0.94)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.35, 0.19, 0.12, 0.96)))
	add_child(button)
	return button

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

func set_status(health: int, zombie_count: int, ammo: int, reserve: int) -> void:
	if is_instance_valid(status_label):
		status_label.text = "HP  %03d     AMMO  %02d/%02d     INFECTED  %02d" % [health, ammo, reserve, zombie_count]

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
			joystick = ((event.position - move_origin) / JOYSTICK_RADIUS).limit_length(1.0)
			if is_instance_valid(player_ref):
				player_ref.call("set_mobile_move", joystick)
			queue_redraw()
		elif event.index == look_pointer and is_instance_valid(player_ref):
			player_ref.call("add_mobile_look", event.relative)

func _draw() -> void:
	var center := move_origin if move_pointer != -1 else Vector2(112, size.y - 122)
	draw_circle(center, JOYSTICK_RADIUS, Color(0.02, 0.04, 0.03, 0.28))
	draw_arc(center, JOYSTICK_RADIUS, 0, TAU, 48, Color(0.82, 0.88, 0.78, 0.52), 3.0)
	var knob := center + joystick * JOYSTICK_RADIUS * 0.62
	draw_circle(knob, 29, Color(0.72, 0.82, 0.68, 0.38))
	draw_arc(knob, 29, 0, TAU, 32, Color(0.92, 0.96, 0.88, 0.72), 2.0)
