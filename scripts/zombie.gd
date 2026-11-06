extends CharacterBody3D

signal died(zombie: Node3D)
signal attacked
signal hit_received

@export var max_health := 100
@export var move_speed := 2.1
var health := 100
var target: Node3D
var attack_cooldown := 0.0
var visual: Node3D
var body_material: StandardMaterial3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var animation_clock := 0.0
var hit_flash := 0.0

func _ready() -> void:
	add_to_group("zombies")
	health = max_health
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.9
	collision.shape = capsule
	add_child(collision)
	_build_zombie_visual()

func _build_zombie_visual() -> void:
	visual = Node3D.new()
	visual.name = "ZombieVisual"
	add_child(visual)
	body_material = _material(Color(0.34, 0.43, 0.25))
	var torn_clothes := _material(Color(0.20, 0.24, 0.19))
	var skin := _material(Color(0.43, 0.52, 0.31))
	var dark := _material(Color(0.09, 0.12, 0.08))
	var eye_material := _material(Color(0.82, 0.48, 0.16))
	_add_capsule(visual, "Torso", 0.30, 0.91, Vector3(0, 0.10, 0), body_material)
	_add_sphere(visual, "Head", 0.235, Vector3(0, 0.78, 0), skin)
	_add_sphere(visual, "LeftEar", 0.06, Vector3(-0.22, 0.79, 0), skin)
	_add_sphere(visual, "RightEar", 0.06, Vector3(0.22, 0.79, 0), skin)
	_add_sphere(visual, "Nose", 0.045, Vector3(0, 0.76, -0.22), skin)
	_add_sphere(visual, "LeftEyeSocket", 0.043, Vector3(-0.085, 0.82, -0.19), dark)
	_add_sphere(visual, "RightEyeSocket", 0.043, Vector3(0.085, 0.82, -0.19), dark)
	_add_sphere(visual, "Jaw", 0.15, Vector3(0, 0.66, -0.10), dark)
	_add_sphere(visual, "LeftEye", 0.035, Vector3(-0.085, 0.81, -0.205), eye_material)
	_add_sphere(visual, "RightEye", 0.035, Vector3(0.085, 0.81, -0.205), eye_material)
	_add_capsule(visual, "Rag", 0.13, 0.44, Vector3(0, 0.27, 0.19), torn_clothes)
	left_arm = _pivot("LeftArm", Vector3(-0.34, 0.39, 0))
	right_arm = _pivot("RightArm", Vector3(0.34, 0.39, 0))
	visual.add_child(left_arm)
	visual.add_child(right_arm)
	_add_capsule(left_arm, "Sleeve", 0.12, 0.67, Vector3(0, -0.29, 0), torn_clothes)
	_add_sphere(left_arm, "Hand", 0.105, Vector3(0, -0.64, -0.015), skin)
	for finger in range(4):
		_add_capsule(left_arm, "Finger_%d" % finger, 0.022, 0.105, Vector3(-0.06 + finger * 0.04, -0.73, -0.04), skin)
	_add_capsule(right_arm, "Sleeve", 0.12, 0.67, Vector3(0, -0.29, 0), torn_clothes)
	_add_sphere(right_arm, "Hand", 0.105, Vector3(0, -0.64, -0.015), skin)
	for finger in range(4):
		_add_capsule(right_arm, "Finger_%d" % finger, 0.022, 0.105, Vector3(-0.06 + finger * 0.04, -0.73, -0.04), skin)
	left_leg = _pivot("LeftLeg", Vector3(-0.16, -0.22, 0))
	right_leg = _pivot("RightLeg", Vector3(0.16, -0.22, 0))
	visual.add_child(left_leg)
	visual.add_child(right_leg)
	_add_capsule(left_leg, "Leg", 0.14, 0.62, Vector3(0, -0.30, 0), dark)
	_add_capsule(right_leg, "Leg", 0.14, 0.77, Vector3(0, -0.34, 0), dark)
	_add_box(left_leg, "Foot", Vector3(0.22, 0.15, 0.31), Vector3(0, -0.56, -0.04), torn_clothes)
	_add_box(right_leg, "Foot", Vector3(0.22, 0.15, 0.31), Vector3(0, -0.75, -0.04), torn_clothes)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.95
	return result

func _pivot(label: String, pos: Vector3) -> Node3D:
	var result := Node3D.new()
	result.name = label
	result.position = pos
	return result

func _add_capsule(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	instance.mesh = shape
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _add_sphere(parent: Node3D, label: String, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	instance.mesh = shape
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _add_box(parent: Node3D, label: String, dimensions: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var shape := BoxMesh.new()
	shape.size = dimensions
	instance.mesh = shape
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	var to_player := target.global_position - global_position
	to_player.y = 0
	var distance := to_player.length()
	var is_attacking := distance <= 1.45
	if not is_attacking:
		var direction := to_player.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 7.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)
		if attack_cooldown <= 0.0:
			attacked.emit()
			target.call("apply_damage", 8)
			attack_cooldown = 1.25
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.4
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	animation_clock += delta * (8.5 if moving else 2.0)
	var swing := sin(animation_clock) * (0.62 if moving else 0.035)
	if is_attacking and attack_cooldown > 0.85:
		swing = -0.75
	left_arm.rotation.x = lerpf(left_arm.rotation.x, -swing - 0.38, delta * 7.0)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, swing - 0.38, delta * 7.0)
	left_leg.rotation.x = lerpf(left_leg.rotation.x, swing, delta * 8.0)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, -swing, delta * 8.0)
	visual.position.y = sin(animation_clock * 2.0) * (0.025 if moving else 0.008)
	body_material.albedo_color = Color(0.62, 0.30, 0.22) if hit_flash > 0.0 else Color(0.34, 0.43, 0.25)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	hit_received.emit()
	hit_flash = 0.16
	if health <= 0:
		died.emit(self)
		queue_free()
