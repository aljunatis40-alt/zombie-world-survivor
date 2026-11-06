extends CharacterBody3D

@export var walk_speed := 5.2
@export var sprint_speed := 8.0
@export var acceleration := 18.0
@export var health := 100
var gravity := 22.0
var camera_pivot: Node3D
var camera: Camera3D
var visual: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var move_touch := Vector2.ZERO
var mobile_sprint := false
var jump_queued := false
var animation_clock := 0.0

func _ready() -> void:
	add_to_group("player")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	add_child(collision)
	_build_survivor_visual()
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.35, 0)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 2.0, 5.8)
	camera.rotation_degrees.x = -12
	camera.current = true
	camera_pivot.add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not OS.has_feature("mobile") else Input.MOUSE_MODE_VISIBLE

func _build_survivor_visual() -> void:
	visual = Node3D.new()
	visual.name = "SurvivorVisual"
	add_child(visual)
	var clothing := _material(Color(0.16, 0.29, 0.25))
	var pants := _material(Color(0.12, 0.16, 0.15))
	var skin := _material(Color(0.72, 0.52, 0.39))
	var boots := _material(Color(0.075, 0.065, 0.055))
	_add_capsule(visual, "Jacket", 0.29, 0.88, Vector3(0, 0.12, 0), clothing)
	_add_sphere(visual, "Head", 0.225, Vector3(0, 0.78, 0), skin)
	_add_sphere(visual, "Hair", 0.23, Vector3(0, 0.91, 0.015), _material(Color(0.12, 0.095, 0.075)))
	_add_capsule(visual, "Neck", 0.095, 0.22, Vector3(0, 0.61, 0), skin)
	left_arm_pivot = _make_limb_pivot("LeftArm", Vector3(-0.34, 0.40, 0))
	right_arm_pivot = _make_limb_pivot("RightArm", Vector3(0.34, 0.40, 0))
	visual.add_child(left_arm_pivot)
	visual.add_child(right_arm_pivot)
	_add_capsule(left_arm_pivot, "Sleeve", 0.115, 0.68, Vector3(0, -0.29, 0), clothing)
	_add_sphere(left_arm_pivot, "Hand", 0.105, Vector3(0, -0.66, 0), skin)
	_add_capsule(right_arm_pivot, "Sleeve", 0.115, 0.68, Vector3(0, -0.29, 0), clothing)
	_add_sphere(right_arm_pivot, "Hand", 0.105, Vector3(0, -0.66, 0), skin)
	left_leg_pivot = _make_limb_pivot("LeftLeg", Vector3(-0.16, -0.28, 0))
	right_leg_pivot = _make_limb_pivot("RightLeg", Vector3(0.16, -0.28, 0))
	visual.add_child(left_leg_pivot)
	visual.add_child(right_leg_pivot)
	_add_capsule(left_leg_pivot, "Trouser", 0.14, 0.78, Vector3(0, -0.34, 0), pants)
	_add_box(left_leg_pivot, "Boot", Vector3(0.23, 0.17, 0.34), Vector3(0, -0.77, -0.055), boots)
	_add_capsule(right_leg_pivot, "Trouser", 0.14, 0.78, Vector3(0, -0.34, 0), pants)
	_add_box(right_leg_pivot, "Boot", Vector3(0.23, 0.17, 0.34), Vector3(0, -0.77, -0.055), boots)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

func _make_limb_pivot(label: String, pivot_position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = pivot_position
	return pivot

func _add_capsule(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _add_sphere(parent: Node3D, label: String, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _add_box(parent: Node3D, label: String, dimensions: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * 0.003)
		camera.rotation.x = clamp(camera.rotation.x - event.relative.y * 0.003, -0.75, 0.25)

func set_mobile_move(value: Vector2) -> void:
	move_touch = value.limit_length(1.0)

func set_mobile_sprint(active: bool) -> void:
	mobile_sprint = active

func request_jump() -> void:
	jump_queued = true

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
	var is_moving := direction.length() > 0.1
	var is_sprinting := mobile_sprint or Input.is_action_pressed("sprint")
	var speed := sprint_speed if is_sprinting else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
		if jump_queued:
			velocity.y = 7.0
	jump_queued = false
	if is_moving:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), delta * 10.0)
	animation_clock += delta * (10.0 if is_sprinting else 7.0)
	var swing := sin(animation_clock) * (0.72 if is_moving else 0.04)
	if is_instance_valid(left_arm_pivot):
		left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, swing, delta * 9.0)
		right_arm_pivot.rotation.x = lerpf(right_arm_pivot.rotation.x, -swing, delta * 9.0)
		left_leg_pivot.rotation.x = lerpf(left_leg_pivot.rotation.x, -swing, delta * 9.0)
		right_leg_pivot.rotation.x = lerpf(right_leg_pivot.rotation.x, swing, delta * 9.0)
	move_and_slide()

func apply_damage(amount: int) -> void:
	health = maxi(0, health - amount)
