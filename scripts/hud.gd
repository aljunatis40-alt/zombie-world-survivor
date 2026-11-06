extends Control

signal fire_requested

var status_label: Label
var fire_button: Button
var move_origin := Vector2.ZERO
var move_pointer := -1
var look_pointer := -1
var joystick := Vector2.ZERO
var player_ref: Node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	status_label = Label.new()
	status_label.position = Vector2(24, 20)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	add_child(status_label)
	fire_button = Button.new()
	fire_button.text = "FIRE"
	fire_button.size = Vector2(104, 72)
	fire_button.anchor_left = 1
	fire_button.anchor_top = 1
	fire_button.anchor_right = 1
	fire_button.anchor_bottom = 1
	fire_button.position = Vector2(-138, -112)
	fire_button.add_theme_font_size_override("font_size", 20)
	fire_button.pressed.connect(func(): fire_requested.emit())
	add_child(fire_button)
	var hint := Label.new()
	hint.text = "LEFT: MOVE     RIGHT: LOOK"
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1
	hint.anchor_bottom = 1
	hint.position = Vector2(-120, -34)
	hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.82))
	add_child(hint)
	call_deferred("_find_player")

func _find_player() -> void:
	player_ref = get_parent().get_node_or_null("Survivor")

func set_status(health: int, zombie_count: int) -> void:
	if is_instance_valid(status_label):
		status_label.text = "SURVIVOR  %d HP     INFECTED: %d" % [health, zombie_count]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < size.x * 0.45 and move_pointer == -1:
				move_pointer = event.index
				move_origin = event.position
				joystick = Vector2.ZERO
			elif event.position.x >= size.x * 0.45:
				look_pointer = event.index
		else:
			if event.index == move_pointer:
				move_pointer = -1
				joystick = Vector2.ZERO
				if is_instance_valid(player_ref):
					player_ref.call("set_mobile_move", Vector2.ZERO)
			if event.index == look_pointer:
				look_pointer = -1
	elif event is InputEventScreenDrag:
		if event.index == move_pointer:
			joystick = ((event.position - move_origin) / 65.0).limit_length(1.0)
			if is_instance_valid(player_ref):
				player_ref.call("set_mobile_move", joystick)
		elif event.index == look_pointer and is_instance_valid(player_ref):
			player_ref.call("add_mobile_look", event.relative)
