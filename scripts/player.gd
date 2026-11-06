extends CharacterBody3D

signal footstep
signal jumped
signal landed

@export var walk_speed := 5.2
@export var sprint_speed := 8.0
@export var acceleration := 18.0
@export var health := 100
var gravity := 22.0
var camera_pivot: Node3D
var camera: Camera3D
var camera_spring: SpringArm3D
var visual: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var move_touch := Vector2.ZERO
var mobile_sprint := false
var jump_queued := false
var animation_clock := 0.0
var footstep_timer := 0.0
var seated := false
var crouched := false
var movement_state := "IDLE"
var collision_shape: CollisionShape3D
var standing_capsule_height := 1.8
var crouched_capsule_height := 1.22

func _ready() -> void:
	add_to_group("player")
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = standing_capsule_height
	collision_shape.shape = capsule
	add_child(collision_shape)
	_build_survivor_visual()
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.35, 0)
	camera_pivot.rotation_degrees.x = -12
	add_child(camera_pivot)
	# Spring arm pushes the camera forward when a wall/building is behind it.
	camera_spring = SpringArm3D.new()
	camera_spring.name = "CameraCollisionArm"
	camera_spring.spring_length = 5.8
	camera_spring.margin = 0.28
	camera_spring.collision_mask = 1
	camera_pivot.add_child(camera_spring)
	camera = Camera3D.new()
	camera.position = Vector3.ZERO
	camera.current = true
	camera_spring.add_child(camera)
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
	_add_sphere(visual, "LeftEar", 0.065, Vector3(-0.215, 0.79, 0), skin)
	_add_sphere(visual, "RightEar", 0.065, Vector3(0.215, 0.79, 0), skin)
	_add_sphere(visual, "Nose", 0.045, Vector3(0, 0.765, -0.225), skin)
	_add_sphere(visual, "LeftEyeWhite", 0.037, Vector3(-0.078, 0.825, -0.194), _material(Color(0.96, 0.94, 0.86)))
	_add_sphere(visual, "RightEyeWhite", 0.037, Vector3(0.078, 0.825, -0.194), _material(Color(0.96, 0.94, 0.86)))
	_add_sphere(visual, "LeftIris", 0.018, Vector3(-0.078, 0.825, -0.226), _material(Color(0.12, 0.22, 0.19)))
	_add_sphere(visual, "RightIris", 0.018, Vector3(0.078, 0.825, -0.226), _material(Color(0.12, 0.22, 0.19)))
	_add_box(visual, "Mouth", Vector3(0.075, 0.018, 0.018), Vector3(0, 0.69, -0.216), _material(Color(0.22, 0.08, 0.07)))
	_add_sphere(visual, "Hair", 0.23, Vector3(0, 0.91, 0.015), _material(Color(0.12, 0.095, 0.075)))
	_add_capsule(visual, "Neck", 0.095, 0.22, Vector3(0, 0.61, 0), skin)
	_add_box(visual, "SurvivorBackpack", Vector3(0.48, 0.62, 0.24), Vector3(0, 0.13, 0.30), _material(Color(0.12, 0.19, 0.16)))
	_add_box(visual, "BackpackTopFlap", Vector3(0.50, 0.14, 0.26), Vector3(0, 0.48, 0.30), _material(Color(0.20, 0.25, 0.19)))
	_add_box(visual, "UtilityBelt", Vector3(0.58, 0.12, 0.34), Vector3(0, -0.30, 0), _material(Color(0.10, 0.11, 0.09)))
	left_arm_pivot = _make_limb_pivot("LeftArm", Vector3(-0.34, 0.40, 0))
	right_arm_pivot = _make_limb_pivot("RightArm", Vector3(0.34, 0.40, 0))
	visual.add_child(left_arm_pivot)
	visual.add_child(right_arm_pivot)
	_add_capsule(left_arm_pivot, "Sleeve", 0.115, 0.68, Vector3(0, -0.29, 0), clothing)
	_add_sphere(left_arm_pivot, "Hand", 0.105, Vector3(0, -0.66, 0), skin)
	for finger in range(4):
		_add_capsule(left_arm_pivot, "Finger_%d" % finger, 0.022, 0.105, Vector3(-0.06 + finger * 0.04, -0.75, -0.025), skin)
	_add_capsule(right_arm_pivot, "Sleeve", 0.115, 0.68, Vector3(0, -0.29, 0), clothing)
	_add_sphere(right_arm_pivot, "Hand", 0.105, Vector3(0, -0.66, 0), skin)
	for finger in range(4):
		_add_capsule(right_arm_pivot, "Finger_%d" % finger, 0.022, 0.105, Vector3(-0.06 + finger * 0.04, -0.75, -0.025), skin)
	# Visible compact sidearm held in the survivor's right hand.
	_add_box(right_arm_pivot, "PistolGrip", Vector3(0.105, 0.22, 0.12), Vector3(0, -0.61, -0.13), _material(Color(0.075, 0.085, 0.08)))
	_add_box(right_arm_pivot, "PistolSlide", Vector3(0.13, 0.12, 0.34), Vector3(0, -0.55, -0.31), _material(Color(0.16, 0.18, 0.17)))
	_add_box(right_arm_pivot, "PistolBarrel", Vector3(0.07, 0.065, 0.15), Vector3(0, -0.55, -0.53), _material(Color(0.045, 0.05, 0.05)))
	left_leg_pivot = _make_limb_pivot("LeftLeg", Vector3(-0.16, -0.22, 0))
	right_leg_pivot = _make_limb_pivot("RightLeg", Vector3(0.16, -0.22, 0))
	visual.add_child(left_leg_pivot)
	visual.add_child(right_leg_pivot)
	_add_capsule(left_leg_pivot, "Trouser", 0.14, 0.62, Vector3(0, -0.30, 0), pants)
	_add_box(left_leg_pivot, "Boot", Vector3(0.23, 0.17, 0.34), Vector3(0, -0.56, -0.055), boots)
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
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * 0.003, -0.75, 0.25)

func set_mobile_move(value: Vector2) -> void:
	move_touch = value.limit_length(1.0)

func set_mobile_sprint(active: bool) -> void:
	mobile_sprint = active

func request_jump() -> void:
	if not seated and not crouched:
		jump_queued = true

func set_crouched(active: bool) -> void:
	if seated:
		return
	crouched = active
	if is_instance_valid(collision_shape) and collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.height = crouched_capsule_height if crouched else standing_capsule_height
	if is_instance_valid(visual):
		visual.scale.y = 0.78 if crouched else 1.0
		visual.position.y = -0.12 if crouched else 0.0
	if crouched:
		mobile_sprint = false
		jump_queued = false

func set_seated(active: bool) -> void:
	seated = active
	if not is_instance_valid(visual):
		return
	if seated:
		move_touch = Vector2.ZERO
		mobile_sprint = false
		jump_queued = false
		velocity = Vector3.ZERO
		visual.position.y = -0.34
		left_leg_pivot.rotation.x = 1.18
		right_leg_pivot.rotation.x = 1.18
		left_arm_pivot.rotation.x = -0.18
		right_arm_pivot.rotation.x = -0.18
	else:
		visual.position.y = 0.0
		left_leg_pivot.rotation.x = 0.0
		right_leg_pivot.rotation.x = 0.0
		left_arm_pivot.rotation.x = 0.0
		right_arm_pivot.rotation.x = 0.0

func add_mobile_look(value: Vector2) -> void:
	camera_pivot.rotate_y(-value.x * 0.006)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - value.y * 0.006, -0.75, 0.25)

func _physics_process(delta: float) -> void:
	if seated:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var was_on_floor := is_on_floor()
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	if move_touch.length() > 0.05:
		input_dir = Vector2(move_touch.x, -move_touch.y)
	var forward := -camera_pivot.global_transform.basis.z
	var right := camera_pivot.global_transform.basis.x
	var direction := (right * input_dir.x + forward * input_dir.y)
	direction.y = 0
	direction = direction.normalized()
	var is_moving := direction.length() > 0.1
	var is_sprinting := (mobile_sprint or Input.is_action_pressed("sprint")) and not crouched
	var speed := (walk_speed * 0.48) if crouched else (sprint_speed if is_sprinting else walk_speed)
	if not is_on_floor():
		movement_state = "JUMP"
	elif crouched:
		movement_state = "CROUCH"
	elif is_moving and is_sprinting:
		movement_state = "SPRINT"
	elif is_moving:
		movement_state = "WALK"
	else:
		movement_state = "IDLE"
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
		if jump_queued:
			velocity.y = 7.0
			jumped.emit()
	jump_queued = false
	if is_moving:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 10.0)
	animation_clock += delta * (10.0 if is_sprinting else (4.0 if crouched else 7.0))
	var swing := sin(animation_clock) * (0.34 if crouched and is_moving else (0.72 if is_moving else 0.04))
	if is_instance_valid(left_arm_pivot):
		left_arm_pivot.rotation.x = lerpf(left_arm_pivot.rotation.x, swing, delta * 9.0)
		right_arm_pivot.rotation.x = lerpf(right_arm_pivot.rotation.x, -swing, delta * 9.0)
		left_leg_pivot.rotation.x = lerpf(left_leg_pivot.rotation.x, -swing, delta * 9.0)
		right_leg_pivot.rotation.x = lerpf(right_leg_pivot.rotation.x, swing, delta * 9.0)
	move_and_slide()
	if not was_on_floor and is_on_floor():
		landed.emit()
	if is_moving and is_on_floor():
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep.emit()
			footstep_timer = 0.34 if is_sprinting else 0.48
	else:
		footstep_timer = minf(footstep_timer, 0.08)

func apply_damage(amount: int) -> void:
	health = maxi(0, health - amount)
