extends CharacterBody3D

@export var walk_speed := 5.2
@export var sprint_speed := 8.0
@export var acceleration := 18.0
@export var health := 100
var gravity := 22.0
var camera_pivot: Node3D
var camera: Camera3D
var visual: MeshInstance3D
var move_touch := Vector2.ZERO
var look_touch := Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	add_child(collision)
	visual = MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.75
	visual.mesh = body_mesh
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.18, 0.32, 0.27)
	visual.material_override = suit
	add_child(visual)
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.35, 0)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 2.0, 5.8)
	camera.rotation_degrees.x = -12
	camera.current = true
	camera_pivot.add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not OS.has_feature("mobile") else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * 0.003)
		camera.rotation.x = clamp(camera.rotation.x - event.relative.y * 0.003, -0.75, 0.25)

func set_mobile_move(value: Vector2) -> void:
	move_touch = value.limit_length(1.0)

func add_mobile_look(value: Vector2) -> void:
	camera_pivot.rotate_y(-value.x * 0.006)
	camera.rotation.x = clamp(camera.rotation.x - value.y * 0.006, -0.75, 0.25)

func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if move_touch.length() > 0.05:
		input_dir = move_touch
	var forward := -camera_pivot.global_transform.basis.z
	var right := camera_pivot.global_transform.basis.x
	var direction := (right * input_dir.x + forward * input_dir.y)
	direction.y = 0
	direction = direction.normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	if direction.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), delta * 10.0)
	move_and_slide()

func apply_damage(amount: int) -> void:
	health = maxi(0, health - amount)
