extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const ZombieScript = preload("res://scripts/zombie.gd")
const HudScript = preload("res://scripts/hud.gd")

var player: CharacterBody3D
var hud: Control
var world_root: Node3D
var zombies: Array[Node3D] = []
var magazine_ammo := 12
var reserve_ammo := 60
var is_reloading := false

func _ready() -> void:
	_build_environment()
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Survivor"
	add_child(player)
	player.position = Vector3(0, 1.1, 8)
	hud = Control.new()
	hud.set_script(HudScript)
	hud.name = "MobileHUD"
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.fire_requested.connect(_on_fire_requested)
	hud.reload_requested.connect(_on_reload_requested)
	hud.jump_requested.connect(_on_jump_requested)
	hud.sprint_changed.connect(_on_sprint_changed)
	for i in range(9):
		var zombie := CharacterBody3D.new()
		zombie.set_script(ZombieScript)
		zombie.name = "Walker_%02d" % i
		add_child(zombie)
		var angle := TAU * float(i) / 9.0
		zombie.position = Vector3(cos(angle) * 15.0, 1.0, sin(angle) * 15.0)
		zombie.set("target", player)
		zombie.died.connect(_on_zombie_died)
		zombies.append(zombie)

func _on_zombie_died(zombie: Node3D) -> void:
	zombies.erase(zombie)

func _process(_delta: float) -> void:
	if is_instance_valid(hud) and is_instance_valid(player):
		hud.set_status(int(player.get("health")), zombies.size(), magazine_ammo, reserve_ammo, is_reloading)

func _on_jump_requested() -> void:
	if is_instance_valid(player):
		player.call("request_jump")

func _on_sprint_changed(active: bool) -> void:
	if is_instance_valid(player):
		player.call("set_mobile_sprint", active)

func _on_reload_requested() -> void:
	if is_reloading or magazine_ammo >= 12 or reserve_ammo <= 0:
		return
	is_reloading = true
	await get_tree().create_timer(1.25).timeout
	if not is_inside_tree():
		return
	var needed := 12 - magazine_ammo
	var loaded := mini(needed, reserve_ammo)
	magazine_ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false

func _on_fire_requested() -> void:
	if is_reloading or not is_instance_valid(player) or magazine_ammo <= 0:
		return
	magazine_ammo -= 1
	var camera: Camera3D = player.get("camera")
	if not is_instance_valid(camera):
		return
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 42.0)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider and hit.collider.is_in_group("zombies"):
		hit.collider.call("take_damage", 50)

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.53, 0.58)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	world_root = Node3D.new()
	world_root.name = "AbandonedDistrict"
	add_child(world_root)
	_add_box("Road", Vector3(0, -0.25, 0), Vector3(90, 0.5, 90), Color(0.12, 0.14, 0.15))
	_add_box("RoadMarking", Vector3(0, 0.012, 0), Vector3(1.0, 0.025, 90), Color(0.72, 0.65, 0.38))
	for x in [-1, 1]:
		for z in [-1, 1]:
			for n in range(3):
				var building := _add_box("AbandonedBuilding", Vector3(x * (19 + n * 8), 3.0, z * (19 + n * 8)), Vector3(8, 6 + (n % 2) * 3, 8), Color(0.24 + n * 0.025, 0.25, 0.24))
				building.rotation.y = float(n) * 0.17
	for i in range(22):
		var tree := _add_box("DeadTreeTrunk", Vector3(randf_range(-42, 42), 1.5, randf_range(-42, 42)), Vector3(0.45, 3, 0.45), Color(0.18, 0.14, 0.1))
		tree.rotation.z = randf_range(-0.12, 0.12)

func _add_box(label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh.material_override = material
	if label == "RoadMarking":
		mesh.position = pos
		world_root.add_child(mesh)
	else:
		var body := StaticBody3D.new()
		body.name = label + "Collision"
		body.position = pos
		var collision := CollisionShape3D.new()
		var collision_shape := BoxShape3D.new()
		collision_shape.size = size
		collision.shape = collision_shape
		body.add_child(collision)
		body.add_child(mesh)
		world_root.add_child(body)
	return mesh
