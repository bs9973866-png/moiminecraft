extends Node3D

const WorldScript = preload("res://scripts/voxel_world.gd")
const PlayerScript = preload("res://scripts/player_controller.gd")
const HudScript = preload("res://scripts/mobile_hud.gd")

func _ready() -> void:
	_build_environment()
	var world = WorldScript.new()
	world.name = "VoxelWorld"
	add_child(world)

	var player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(24.0, 23.0, 24.0)
	add_child(player)
	player.world = world

	var hud = HudScript.new()
	hud.name = "MobileHUD"
	add_child(hud)
	hud.player = player
	player.hud = hud

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
