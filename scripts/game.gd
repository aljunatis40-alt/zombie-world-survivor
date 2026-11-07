extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const ZombieScript = preload("res://scripts/zombie.gd")
const HudScript = preload("res://scripts/hud.gd")

var player: CharacterBody3D
var hud: Control
var hud_layer: CanvasLayer
var world_root: Node3D
var zombies: Array[Node3D] = []
var magazine_ammo := 12
var reserve_ammo := 60
var is_reloading := false
var sound_players: Dictionary = {}
var bench_positions: Array[Vector3] = []
var medkits := 2
var crate_opened := false

func _ready() -> void:
	_build_audio()
	_build_environment()
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Survivor"
	add_child(player)
	player.position = Vector3(0, 1.1, 8)
	# A Control under Node3D is not drawn as a screen HUD. Put it on a CanvasLayer.
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDCanvas"
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Control.new()
	hud.set_script(HudScript)
	hud.name = "MobileHUD"
	hud_layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.fire_requested.connect(_on_fire_requested)
	hud.reload_requested.connect(_on_reload_requested)
	hud.jump_requested.connect(_on_jump_requested)
	hud.sprint_changed.connect(_on_sprint_changed)
	hud.sit_requested.connect(_on_sit_requested)
	hud.crouch_changed.connect(_on_crouch_changed)
	hud.aim_changed.connect(_on_aim_changed)
	hud.heal_requested.connect(_on_heal_requested)
	hud.inventory_toggled.connect(_on_inventory_toggled)
	hud.interact_requested.connect(_on_interact_requested)
	player.connect("footstep", func(): _play_sound("footstep"))
	player.connect("jumped", func(): _play_sound("jump"))
	player.connect("landed", func(): _play_sound("land"))
	for i in range(9):
		var zombie := CharacterBody3D.new()
		zombie.set_script(ZombieScript)
		zombie.name = "Walker_%02d" % i
		add_child(zombie)
		var angle := TAU * float(i) / 9.0
		zombie.position = Vector3(cos(angle) * 25.0, 1.0, sin(angle) * 25.0)
		zombie.set("target", player)
		zombie.died.connect(_on_zombie_died)
		zombie.connect("attacked", func(): _play_sound("zombie"))
		zombie.connect("hit_received", func(): _play_sound("hit"))
		zombies.append(zombie)
	_validate_mesh_instances(self)

func _on_zombie_died(zombie: Node3D) -> void:
	_play_sound("zombie_down")
	zombies.erase(zombie)

func _process(_delta: float) -> void:
	if is_instance_valid(hud) and is_instance_valid(player):
		hud.set_status(int(player.get("health")), zombies.size(), magazine_ammo, reserve_ammo, is_reloading)
		var camera: Camera3D = player.get("camera")
		if is_instance_valid(camera):
			hud.set_inventory_text("SURVIVOR INVENTORY\\n\\n9mm: %d / %d\\nMedkits: %d\\n\\nTap INTERACT near supply crate." % [magazine_ammo, reserve_ammo, medkits])
		var objective_position := Vector3(0, 0, -25.2)
		var to_objective := objective_position - player.global_position
		var distance := to_objective.length()
		var local_direction := camera.global_transform.basis.inverse() * to_objective.normalized()
		hud.set_objective_navigation(local_direction, distance)

func _on_jump_requested() -> void:
	if is_instance_valid(player):
		player.call("request_jump")

func _on_sprint_changed(active: bool) -> void:
	if is_instance_valid(player):
		player.call("set_mobile_sprint", active)

func _on_crouch_changed(active: bool) -> void:
	if is_instance_valid(player):
		player.call("set_crouched", active)

func _on_aim_changed(active: bool) -> void:
	if is_instance_valid(player):
		player.call("set_mobile_aim", active)

func _on_heal_requested() -> void:
	if not is_instance_valid(player):
		return
	var current_health := int(player.get("health"))
	if current_health >= 100:
		hud.heal_button.text = "FULL HP"
		return
	if medkits <= 0:
		hud.heal_button.text = "NO KIT"
		return
	medkits -= 1
	player.set("health", mini(100, current_health + 35))
	_play_sound("reload")
	hud.heal_button.text = "HEALED"

func _on_inventory_toggled() -> void:
	if is_instance_valid(hud):
		hud.toggle_inventory()

func _on_interact_requested() -> void:
	if not is_instance_valid(player):
		return
	if crate_opened:
		hud.interact_button.text = "EMPTY"
		return
	var crate_position := Vector3(0, 0, -25.2)
	var distance := Vector2(player.global_position.x - crate_position.x, player.global_position.z - crate_position.z).length()
	if distance > 3.8:
		hud.interact_button.text = "TOO FAR"
		return
	crate_opened = true
	reserve_ammo += 24
	medkits += 1
	hud.interact_button.text = "LOOTED"
	_play_sound("reload")

func _on_reload_requested() -> void:
	if is_reloading or magazine_ammo >= 12 or reserve_ammo <= 0:
		return
	is_reloading = true
	_play_sound("reload")
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
	_play_sound("fire")
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


func _build_audio() -> void:
	var definitions := {
		"footstep": [92.0, 0.10, 0.34, 0.30],
		"jump": [210.0, 0.16, 0.28, 0.08],
		"land": [68.0, 0.13, 0.42, 0.48],
		"fire": [125.0, 0.11, 0.52, 0.72],
		"reload": [740.0, 0.20, 0.30, 0.64],
		"zombie": [78.0, 0.34, 0.34, 0.38],
		"hit": [155.0, 0.09, 0.30, 0.58],
		"zombie_down": [58.0, 0.24, 0.26, 0.30]
	}
	for sound_name in definitions:
		var values: Array = definitions[sound_name]
		var player_audio := AudioStreamPlayer.new()
		player_audio.name = "SFX_" + sound_name
		player_audio.volume_db = -5.0
		player_audio.stream = _make_sfx(values[0], values[1], values[2], values[3])
		add_child(player_audio)
		sound_players[sound_name] = player_audio

func _make_sfx(frequency: float, duration: float, volume: float, noise_mix: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var progress := float(i) / float(sample_count)
		var envelope := minf(1.0, progress * 18.0) * pow(1.0 - progress, 1.65)
		var tone := sin(TAU * frequency * t) * (1.0 - noise_mix)
		var noise := sin(float(i) * 12.9898) * 43758.5453
		noise = (fposmod(noise, 1.0) * 2.0 - 1.0) * noise_mix
		if frequency < 100.0:
			tone *= 0.72 + 0.28 * sin(TAU * 7.0 * t)
		var sample := clampf((tone + noise) * envelope * volume, -1.0, 1.0)
		var pcm := clampi(roundi(sample * 32767.0), -32768, 32767)
		samples[i * 2] = pcm & 0xff
		samples[i * 2 + 1] = (pcm >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples
	return stream

func _play_sound(sound_name: String) -> void:
	var audio: AudioStreamPlayer = sound_players.get(sound_name)
	if is_instance_valid(audio):
		audio.stop()
		audio.play()

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
	_add_box("DistrictGround", Vector3(0, -0.35, 0), Vector3(5400, 0.5, 5400), Color(0.20, 0.22, 0.18))
	_add_box("MainRoad", Vector3(0, -0.055, 0), Vector3(12, 0.12, 5400), Color(0.105, 0.12, 0.125))
	_add_box("CrossRoad", Vector3(0, -0.05, 0), Vector3(5400, 0.12, 12), Color(0.105, 0.12, 0.125))
	for side in [-1, 1]:
		_add_box("MainSidewalk", Vector3(side * 7.4, 0.02, 0), Vector3(2.6, 0.18, 5400), Color(0.39, 0.39, 0.34))
		_add_box("CrossSidewalk", Vector3(0, 0.025, side * 7.4), Vector3(5400, 0.18, 2.6), Color(0.39, 0.39, 0.34))
		_add_box("RoadEdgeLine", Vector3(side * 5.8, 0.025, 0), Vector3(0.12, 0.025, 5400), Color(0.78, 0.72, 0.52))
	for z_mark in range(-2700, 2701, 45):
		_add_box("LaneDash", Vector3(0, 0.025, float(z_mark)), Vector3(0.18, 0.025, 3.2), Color(0.83, 0.78, 0.61))
	for cross_mark in range(-4, 5):
		_add_box("CrosswalkStripe", Vector3(float(cross_mark) * 1.15, 0.035, -6.2), Vector3(0.68, 0.035, 1.0), Color(0.82, 0.81, 0.72))
	_build_extended_road_network()
	_build_safe_zone()
	_build_objective_marker()
	for x in [-1, 1]:
		for z in [-1, 1]:
			for n in range(3):
				var building_pos := Vector3(x * (19 + n * 8), 3.0, z * (19 + n * 8))
				var building_height := 6.0 + float(n % 2) * 3.0
				var building := _add_box("AbandonedBuilding", building_pos, Vector3(8, building_height, 8), Color(0.24 + n * 0.025, 0.25, 0.24))
				building.rotation.y = float(n) * 0.17
				_decorate_building(building, building_height, n)
	for i in range(64):
		var tree_pos := Vector3(randf_range(-2650, 2650), 1.5, randf_range(-2650, 2650))
		var tree := _add_box("DeadTreeTrunk", tree_pos, Vector3(0.45, 3, 0.45), Color(0.18, 0.14, 0.1))
		tree.rotation.z = randf_range(-0.12, 0.12)
		var canopy := _detail_box(tree, "DeadBranch", Vector3(0.18, 2.0, 0.18), Vector3(0, 1.65, 0), Color(0.16, 0.13, 0.10))
		canopy.rotation.z = randf_range(-0.65, 0.65)
	for i in range(10):
		var lamp_x := -2250.0 + float(i) * 500.0
		_add_street_lamp(Vector3(lamp_x, 0, -5.5))
	for i in range(40):
		var debris_pos := Vector3(randf_range(-2650, 2650), 0.22, randf_range(-2650, 2650))
		var debris := _add_box("StreetDebris", debris_pos, Vector3(randf_range(0.35, 1.2), 0.4, randf_range(0.3, 0.9)), Color(0.28, 0.25, 0.19))
		debris.rotation.y = randf_range(0, TAU)
	_build_outer_districts()
	_build_parked_vehicles()
	_build_park_and_shops()
	_build_philippine_public_transport()


func _build_extended_road_network() -> void:
	# Open-world grid: 5.4km avenues with wide blocks and fewer visual markings.
	for offset_i in range(-2250, 2251, 450):
		if offset_i == 0:
			continue
		var offset := float(offset_i)
		_add_box("NorthSouthStreet", Vector3(offset, -0.045, 0), Vector3(8.0, 0.10, 5400.0), Color(0.13, 0.145, 0.15))
		_add_box("EastWestStreet", Vector3(0, -0.04, offset), Vector3(5400.0, 0.10, 8.0), Color(0.13, 0.145, 0.15))
		for side in [-1.0, 1.0]:
			_add_box("StreetCurb", Vector3(offset + side * 4.3, 0.015, 0), Vector3(0.22, 0.16, 5400.0), Color(0.42, 0.42, 0.37))
			_add_box("StreetCurb", Vector3(0, 0.015, offset + side * 4.3), Vector3(5400.0, 0.16, 0.22), Color(0.42, 0.42, 0.37))
	for mark in range(-2700, 2701, 90):
		_detail_box(world_root, "MainAvenueLaneDash", Vector3(0.16, 0.035, 5.0), Vector3(0, 0.035, float(mark)), Color(0.82, 0.76, 0.58))
		_detail_box(world_root, "CrossAvenueLaneDash", Vector3(5.0, 0.035, 0.16), Vector3(float(mark), 0.035, 0), Color(0.82, 0.76, 0.58))

func _build_outer_districts() -> void:
	# Fifty varied buildings across the expanded districts; broad spacing avoids a crowded skyline.
	var building_index := 0
	for grid_x in range(-2, 3):
		for grid_z in range(-2, 3):
			for lot in range(2):
				var center_x := float(grid_x) * 900.0 + (180.0 if lot == 0 else -180.0)
				var center_z := float(grid_z) * 900.0 + (150.0 if lot == 0 else -150.0)
				if absf(center_x) < 250.0 and absf(center_z) < 250.0:
					continue
				var height := 8.0 + float(building_index % 5) * 3.2
				var width := 16.0 + float(building_index % 4) * 4.0
				var depth := 15.0 + float((building_index + 2) % 4) * 3.5
				var size := Vector3(width, height, depth)
				var center := Vector3(center_x, height * 0.5, center_z)
				var building := _add_box("OuterDistrictBuilding_%02d" % building_index, center, size, Color(0.22 + float(building_index % 4) * 0.025, 0.24, 0.22))
				building.rotation.y = float(building_index % 5) * 0.07
				_detail_box(building, "OuterRoofRim", Vector3(size.x + 0.5, 0.30, size.z + 0.5), Vector3(0, height * 0.5, 0), Color(0.13, 0.15, 0.14))
				_detail_box(building, "OuterRoofVent", Vector3(2.0, 1.0, 1.5), Vector3(2.0, height * 0.5 + 0.55, 1.5), Color(0.34, 0.36, 0.33))
				_detail_box(building, "OuterDoor", Vector3(1.8, 2.5, 0.16), Vector3(0, -height * 0.5 + 1.25, -depth * 0.5 - 0.09), Color(0.13, 0.11, 0.08))
				building_index += 1

func _build_parked_vehicles() -> void:
	var vehicle_spots: Array[Vector3] = [
		Vector3(-13, 0, -34), Vector3(14, 0, 32), Vector3(-13, 0, 58), Vector3(14, 0, -62),
		Vector3(-58, 0, -13), Vector3(62, 0, 14), Vector3(-103, 0, -13), Vector3(108, 0, 14),
		Vector3(-58, 0, 103), Vector3(62, 0, -108), Vector3(-108, 0, 103), Vector3(108, 0, -103)
	]
	for i in range(vehicle_spots.size()):
		var vehicle := Node3D.new()
		vehicle.name = "AbandonedVehicle_%02d" % i
		vehicle.position = vehicle_spots[i]
		vehicle.rotation.y = PI * 0.5 if i % 2 == 0 else 0.0
		world_root.add_child(vehicle)
		var body_color := Color(0.20 + float(i % 4) * 0.045, 0.23, 0.21)
		_detail_box(vehicle, "VehicleBody", Vector3(2.0, 0.72, 4.0), Vector3(0, 0.72, 0), body_color)
		_detail_box(vehicle, "VehicleCabin", Vector3(1.72, 0.72, 2.0), Vector3(0, 1.38, -0.12), Color(0.12, 0.18, 0.19))
		_detail_box(vehicle, "CrackedWindshield", Vector3(1.62, 0.56, 0.06), Vector3(0, 1.42, -1.15), Color(0.18, 0.27, 0.28))
		for wheel_x in [-1.02, 1.02]:
			for wheel_z in [-1.25, 1.25]:
				var wheel := _detail_box(vehicle, "VehicleWheel", Vector3(0.34, 0.68, 0.68), Vector3(wheel_x, 0.48, wheel_z), Color(0.055, 0.06, 0.055))
				wheel.rotation.z = PI * 0.5


func _on_sit_requested() -> void:
	if not is_instance_valid(player):
		return
	if bool(player.get("seated")):
		player.call("set_seated", false)
		hud.sit_button.text = "SIT"
		return
	var nearest_distance := INF
	for bench_position in bench_positions:
		var distance := Vector2(player.global_position.x - bench_position.x, player.global_position.z - bench_position.z).length()
		if distance < nearest_distance:
			nearest_distance = distance
	if nearest_distance <= 3.2:
		player.call("set_seated", true)
		hud.sit_button.text = "STAND"
	else:
		hud.sit_button.text = "NEAR BENCH"

func _build_park_and_shops() -> void:
	# Small neighborhood park with walkways, benches and shade trees.
	_add_box("NeighborhoodParkLawn", Vector3(65, -0.02, 0), Vector3(54, 0.12, 48), Color(0.16, 0.29, 0.16))
	_add_box("ParkWalkway", Vector3(65, 0.055, 0), Vector3(3.0, 0.08, 46), Color(0.48, 0.46, 0.38))
	for bench_index in range(4):
		var bench_pos := Vector3(54.0 + float(bench_index % 2) * 22.0, 0, -9.0 + float(bench_index / 2) * 18.0)
		bench_positions.append(bench_pos)
		_add_box("ParkBenchSeat", bench_pos + Vector3(0, 0.58, 0), Vector3(2.2, 0.16, 0.72), Color(0.36, 0.22, 0.12))
		_add_box("ParkBenchBack", bench_pos + Vector3(0, 1.08, 0.30), Vector3(2.2, 0.85, 0.14), Color(0.31, 0.19, 0.11))
		for leg_x in [-0.82, 0.82]:
			_add_box("ParkBenchLeg", bench_pos + Vector3(leg_x, 0.28, 0), Vector3(0.13, 0.56, 0.13), Color(0.12, 0.13, 0.12))
	for tree_index in range(12):
		var angle := TAU * float(tree_index) / 12.0
		var tree_pos := Vector3(65 + cos(angle) * 14.0, 1.4, sin(angle) * 13.0)
		_add_box("ParkTreeTrunk", tree_pos, Vector3(0.55, 2.8, 0.55), Color(0.24, 0.16, 0.10))
		_detail_box(world_root, "ParkTreeCanopy", Vector3(2.8, 3.0, 2.8), tree_pos + Vector3(0, 2.4, 0), Color(0.18, 0.31, 0.17))
	for lamp_index in range(2):
		_add_street_lamp(Vector3(51 + float(lamp_index % 2) * 28.0, 0, -12 + float(lamp_index / 2) * 24.0))
	var park_sign := _detail_box(world_root, "ParkWelcomeSign", Vector3(5.5, 1.0, 0.18), Vector3(65, 2.2, -16.0), Color(0.10, 0.27, 0.16))
	var park_label := Label3D.new()
	park_label.text = "BARANGAY PARK  •  REST AREA"
	park_label.font_size = 36
	park_label.pixel_size = 0.012
	park_label.modulate = Color(0.94, 0.88, 0.68)
	park_label.position = Vector3(0, 0, -0.12)
	park_sign.add_child(park_label)

	# Filipino neighborhood food stops; text-only signs, no copied brand logos.
	_add_shop("Mang Inasal Inspired Grill", Vector3(-112, 0, -27), "MANG INASAL", Color(0.68, 0.28, 0.10))
	_add_shop("Jollibee Inspired Chicken Shop", Vector3(-112, 0, 0), "JOLLIBEE", Color(0.72, 0.12, 0.12))
	_add_shop("McDonalds Inspired Burger Shop", Vector3(-112, 0, 27), "McDONALD'S", Color(0.72, 0.16, 0.10))

func _add_shop(shop_name: String, center: Vector3, sign_text: String, sign_color: Color) -> void:
	var shop := _add_box(shop_name, center + Vector3(0, 3.4, 0), Vector3(13, 6.8, 9), Color(0.34, 0.32, 0.27))
	shop.name = shop_name.replace(" ", "_")
	_detail_box(shop, "ShopFrontGlass", Vector3(9.2, 3.0, 0.12), Vector3(0, -0.65, -4.58), Color(0.12, 0.20, 0.21))
	_detail_box(shop, "ShopDoor", Vector3(1.35, 2.7, 0.16), Vector3(0, -1.05, -4.68), Color(0.16, 0.18, 0.16))
	var sign_board := _detail_box(shop, "ShopSignBoard", Vector3(11.8, 1.35, 0.28), Vector3(0, 2.25, -4.72), sign_color)
	var sign_label := Label3D.new()
	sign_label.text = sign_text
	sign_label.font_size = 64
	sign_label.pixel_size = 0.012
	sign_label.modulate = Color(1.0, 0.93, 0.78)
	sign_label.position = Vector3(0, -0.10, -0.18)
	sign_board.add_child(sign_label)
	_detail_box(shop, "ShopAwning", Vector3(13.5, 0.22, 1.1), Vector3(0, 0.10, -5.0), Color(0.17, 0.18, 0.16))

func _build_philippine_public_transport() -> void:
	_build_jeepney(Vector3(18, 0, 52))
	_build_city_bus(Vector3(-18, 0, 52))

func _build_jeepney(position: Vector3) -> void:
	var jeep := Node3D.new()
	jeep.name = "ModernPhilippineJeepney"
	jeep.position = position
	jeep.rotation.y = PI * 0.5
	world_root.add_child(jeep)
	_detail_box(jeep, "JeepneyLowerBody", Vector3(2.5, 1.15, 6.2), Vector3(0, 1.05, 0), Color(0.16, 0.34, 0.31))
	_detail_box(jeep, "JeepneyRoof", Vector3(2.45, 0.20, 5.9), Vector3(0, 2.35, 0.05), Color(0.78, 0.62, 0.20))
	_detail_box(jeep, "JeepneyWindshield", Vector3(2.1, 0.85, 0.10), Vector3(0, 1.78, -3.08), Color(0.13, 0.22, 0.25))
	for side in [-1.0, 1.0]:
		_detail_box(jeep, "JeepneySideWindows", Vector3(0.10, 0.82, 4.65), Vector3(side * 1.27, 1.78, 0.0), Color(0.13, 0.23, 0.25))
		_detail_box(jeep, "JeepneyChromeTrim", Vector3(0.08, 0.12, 5.8), Vector3(side * 1.30, 1.35, 0), Color(0.72, 0.70, 0.60))
		for wheel_z in [-2.0, 2.0]:
			var tire := _detail_box(jeep, "JeepneyTire", Vector3(0.42, 0.88, 0.88), Vector3(side * 1.28, 0.52, wheel_z), Color(0.045, 0.05, 0.05))
			tire.rotation.z = PI * 0.5
	var route_sign := Label3D.new()
	route_sign.text = "CITY • TERMINAL"
	route_sign.font_size = 34
	route_sign.pixel_size = 0.012
	route_sign.modulate = Color(1.0, 0.92, 0.55)
	route_sign.position = Vector3(0, 2.02, -3.15)
	jeep.add_child(route_sign)

func _build_city_bus(position: Vector3) -> void:
	var bus := Node3D.new()
	bus.name = "ModernPhilippineCityBus"
	bus.position = position
	bus.rotation.y = -PI * 0.5
	world_root.add_child(bus)
	_detail_box(bus, "CityBusBody", Vector3(2.75, 3.0, 10.0), Vector3(0, 1.8, 0), Color(0.72, 0.73, 0.67))
	_detail_box(bus, "CityBusWindowBand", Vector3(2.80, 1.15, 8.7), Vector3(0, 2.48, 0.0), Color(0.12, 0.22, 0.26))
	_detail_box(bus, "CityBusFrontGlass", Vector3(2.2, 1.15, 0.12), Vector3(0, 2.42, -5.04), Color(0.12, 0.22, 0.26))
	_detail_box(bus, "CityBusLowerFront", Vector3(2.6, 0.72, 0.16), Vector3(0, 0.98, -5.08), Color(0.16, 0.29, 0.38))
	for side in [-1.0, 1.0]:
		for wheel_z in [-3.4, 3.4]:
			var tire := _detail_box(bus, "CityBusTire", Vector3(0.42, 0.92, 0.92), Vector3(side * 1.40, 0.58, wheel_z), Color(0.045, 0.05, 0.05))
			tire.rotation.z = PI * 0.5
	var bus_sign := Label3D.new()
	bus_sign.text = "METRO • CITY BUS"
	bus_sign.font_size = 38
	bus_sign.pixel_size = 0.012
	bus_sign.modulate = Color(0.96, 0.94, 0.78)
	bus_sign.position = Vector3(0, 3.35, -5.12)
	bus.add_child(bus_sign)

func _build_safe_zone() -> void:
	_add_box("SafeZoneFloor", Vector3(0, -0.035, 8), Vector3(10, 0.10, 8), Color(0.19, 0.27, 0.20))
	for x in [-5.0, 5.0]:
		for z in [4.0, 12.0]:
			_detail_box(world_root, "SafeZoneBeacon", Vector3(0.22, 2.8, 0.22), Vector3(x, 1.4, z), Color(0.22, 0.82, 0.40))
			_detail_box(world_root, "SafeZoneLamp", Vector3(0.48, 0.16, 0.48), Vector3(x, 2.85, z), Color(0.48, 0.95, 0.46))
	_add_box("SafeZoneSign", Vector3(0, 2.1, 3.7), Vector3(4.2, 0.85, 0.16), Color(0.10, 0.28, 0.16))

func _build_objective_marker() -> void:
	var marker_position := Vector3(0, 0, -27)
	_detail_box(world_root, "ObjectivePole", Vector3(0.18, 5.5, 0.18), marker_position + Vector3(0, 2.75, 0), Color(0.16, 0.18, 0.16))
	_detail_box(world_root, "ObjectiveFlag", Vector3(2.1, 0.95, 0.12), marker_position + Vector3(1.0, 4.8, 0), Color(0.86, 0.58, 0.16))
	_detail_box(world_root, "SupplyCrate", Vector3(1.5, 1.1, 1.2), marker_position + Vector3(0, 0.55, 1.8), Color(0.34, 0.25, 0.13))
	_detail_box(world_root, "SupplyCrateLid", Vector3(1.58, 0.12, 1.28), marker_position + Vector3(0, 1.12, 1.8), Color(0.52, 0.39, 0.19))

func _decorate_building(building: MeshInstance3D, height: float, variant: int) -> void:
	var glass_colors := [Color(0.10, 0.19, 0.22), Color(0.16, 0.24, 0.25), Color(0.22, 0.20, 0.16)]
	var glass: Color = glass_colors[variant % glass_colors.size()]
	var frame := Color(0.12, 0.13, 0.12)
	var facade := Color(0.32, 0.31, 0.27)
	for floor_index in range(int(height / 3.0)):
		var y := -height * 0.5 + 1.75 + float(floor_index) * 2.65
		for column in range(3):
			var x := -2.65 + float(column) * 2.65
			_detail_box(building, "WindowFrame", Vector3(1.42, 1.35, 0.13), Vector3(x, y, -4.04), frame)
			_detail_box(building, "BrokenWindowGlass", Vector3(1.18, 1.10, 0.06), Vector3(x, y, -4.12), glass)
			_detail_box(building, "WindowSill", Vector3(1.58, 0.12, 0.22), Vector3(x, y - 0.72, -4.12), facade)
			if (column + floor_index + variant) % 3 == 0:
				_detail_box(building, "BoardedWindow", Vector3(1.22, 0.12, 0.08), Vector3(x, y, -4.19), Color(0.24, 0.17, 0.11))
			_detail_box(building, "SideWindow", Vector3(0.12, 1.18, 1.35), Vector3(-4.04, y, x), frame)
			_detail_box(building, "SideGlass", Vector3(0.06, 0.98, 1.12), Vector3(-4.12, y, x), glass)
	_detail_box(building, "EntranceDoor", Vector3(1.45, 2.35, 0.16), Vector3(0, -height * 0.5 + 1.18, -4.08), Color(0.12, 0.10, 0.075))
	_detail_box(building, "DoorPanel", Vector3(1.12, 1.85, 0.06), Vector3(0, -height * 0.5 + 1.18, -4.18), Color(0.25, 0.20, 0.14))
	_detail_box(building, "RoofRim", Vector3(8.5, 0.28, 8.5), Vector3(0, height * 0.5 + 0.08, 0), Color(0.15, 0.16, 0.15))
	_detail_box(building, "RooftopAC", Vector3(1.5, 0.8, 1.0), Vector3(2.3, height * 0.5 + 0.55, 1.8), Color(0.36, 0.37, 0.34))
	_detail_box(building, "ACVent", Vector3(0.08, 0.48, 0.72), Vector3(1.52, height * 0.5 + 0.55, 1.8), Color(0.10, 0.12, 0.12))
	_detail_box(building, "RooftopTank", Vector3(1.2, 1.0, 1.2), Vector3(-2.2, height * 0.5 + 0.55, -1.8), Color(0.22, 0.27, 0.25))

func _detail_box(parent: Node3D, label: String, dimensions: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _add_street_lamp(pos: Vector3) -> void:
	var pole := _detail_box(world_root, "StreetLampPole", Vector3(0.16, 5.4, 0.16), pos + Vector3(0, 2.7, 0), Color(0.12, 0.14, 0.14))
	_detail_box(world_root, "StreetLampArm", Vector3(1.3, 0.14, 0.14), pos + Vector3(0.55, 5.25, 0), Color(0.12, 0.14, 0.14))
	_detail_box(world_root, "StreetLampHead", Vector3(0.62, 0.22, 0.42), pos + Vector3(1.12, 5.12, 0), Color(0.72, 0.63, 0.36))
	pole.rotation.z = -0.02

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


func _validate_mesh_instances(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh == null:
			push_error("NULL_MESH: %s has no mesh resource" % child.get_path())
		_validate_mesh_instances(child)
