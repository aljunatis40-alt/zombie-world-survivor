extends CharacterBody3D

@export var max_health := 100
@export var move_speed := 2.1
var health := 100
var target: Node3D
var attack_cooldown := 0.0
var visual: MeshInstance3D

func _ready() -> void:
	add_to_group("zombies")
	health = max_health
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.9
	collision.shape = capsule
	add_child(collision)
	visual = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.46
	mesh.height = 1.85
	visual.mesh = mesh
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.36, 0.48, 0.27)
	skin.roughness = 1.0
	visual.material_override = skin
	add_child(visual)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var to_player := target.global_position - global_position
	to_player.y = 0
	var distance := to_player.length()
	if distance > 1.35:
		var direction := to_player.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		visual.rotation.y = atan2(direction.x, direction.z)
	else:
		velocity.x = 0
		velocity.z = 0
		if attack_cooldown <= 0.0:
			target.call("apply_damage", 8)
			attack_cooldown = 1.25
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.4
	move_and_slide()

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
