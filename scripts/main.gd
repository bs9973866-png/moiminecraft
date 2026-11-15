extends Node3D

const WorldScript = preload("res://scripts/voxel_world.gd")
const PlayerScript = preload("res://scripts/player_controller.gd")
const HudScript = preload("res://scripts/mobile_hud.gd")
const SAVE_PATH := "user://novacraft_save.json"

var world: Variant
var hud: Variant
var is_loading := false

func _ready() -> void:
	_build_environment()
	world = WorldScript.new()
	world.name = "VoxelWorld"
	add_child(world)

	var player = PlayerScript.new()
	player.name = "Player"
	player.position = world.get_spawn_position() + Vector3(0.0, 1.5, 0.0)
	add_child(player)
	player.world = world

	hud = HudScript.new()
	hud.name = "MobileHUD"
	add_child(hud)
	hud.player = player
	player.hud = hud

	world.world_changed.connect(_save_game)
	hud.inventory_changed.connect(_save_game)
	call_deferred("_load_game")

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("NovaCraft: не удалось открыть сохранение")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) < 2:
		push_warning("NovaCraft: старое сохранение пропущено, создан новый мир")
		return
	is_loading = true
	if parsed.has("world") and parsed["world"] is Array:
		world.load_blocks(parsed["world"])
	if parsed.has("inventory") and parsed["inventory"] is Dictionary:
		hud.load_inventory(parsed["inventory"])
	is_loading = false

func _save_game() -> void:
	if is_loading or not is_instance_valid(world) or not is_instance_valid(hud):
		return
	var data := {
		"version": 2,
		"world": world.serialize_blocks(),
		"inventory": hud.serialize_inventory()
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("NovaCraft: не удалось записать сохранение")
		return
	file.store_string(JSON.stringify(data))
	file.flush()

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.22, 0.42)
	sky_material.sky_horizon_color = Color(0.62, 0.78, 0.95)
	sky_material.ground_bottom_color = Color(0.12, 0.13, 0.16)
	sky_material.ground_horizon_color = Color(0.48, 0.58, 0.68)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
