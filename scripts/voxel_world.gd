extends Node3D

const WORLD_SIZE := 48
const MAX_HEIGHT := 28
const BLOCK_AIR := 0
const BLOCK_GRASS := 1
const BLOCK_DIRT := 2
const BLOCK_STONE := 3

var blocks: Dictionary = {}
var terrain_noise := FastNoiseLite.new()
var terrain_body: StaticBody3D
var terrain_mesh: ArrayMesh

func _ready() -> void:
	terrain_noise.seed = 481516
	terrain_noise.frequency = 0.035
	_generate_world()

func _generate_world() -> void:
	for x in range(WORLD_SIZE):
		for z in range(WORLD_SIZE):
			var broad := terrain_noise.get_noise_2d(x, z)
			var detail := terrain_noise.get_noise_2d(x + 1700, z + 1700)
			var surface := clampi(10 + int((broad + 1.0) * 3.8 + detail * 1.5), 5, MAX_HEIGHT - 2)
			for y in range(surface + 1):
				var block_type := BLOCK_STONE
				if y == surface:
					block_type = BLOCK_GRASS
				elif y >= surface - 3:
					block_type = BLOCK_DIRT
				blocks[Vector3i(x, y, z)] = block_type
	_rebuild_mesh()

func get_block(cell: Vector3i) -> int:
	return int(blocks.get(cell, BLOCK_AIR))

func break_block(cell: Vector3i) -> bool:
	if get_block(cell) == BLOCK_AIR:
		return false
	blocks.erase(cell)
	_rebuild_mesh()
	return true

func place_block(cell: Vector3i) -> bool:
	if get_block(cell) != BLOCK_AIR or cell.y < 0 or cell.y >= MAX_HEIGHT:
		return false
	blocks[cell] = BLOCK_DIRT
	_rebuild_mesh()
	return true

func _rebuild_mesh() -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell_variant in blocks.keys():
		var cell: Vector3i = cell_variant
		var block_type: int = blocks[cell]
		var base_color := _block_color(block_type)
		_add_visible_faces(surface_tool, cell, base_color)
	terrain_mesh = surface_tool.commit()
	if terrain_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	terrain_mesh.surface_set_material(0, material)

	if is_instance_valid(terrain_body):
		terrain_body.queue_free()
	terrain_body = StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = terrain_mesh
	terrain_body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(collision)
	add_child(terrain_body)

func _add_visible_faces(st: SurfaceTool, cell: Vector3i, color: Color) -> void:
	var x := float(cell.x)
	var y := float(cell.y)
	var z := float(cell.z)
	if get_block(cell + Vector3i.UP) == BLOCK_AIR:
		_quad(st, Vector3(x,y+1,z), Vector3(x,y+1,z+1), Vector3(x+1,y+1,z+1), Vector3(x+1,y+1,z), color)
	if get_block(cell + Vector3i.DOWN) == BLOCK_AIR:
		_quad(st, Vector3(x,y,z), Vector3(x+1,y,z), Vector3(x+1,y,z+1), Vector3(x,y,z+1), color.darkened(0.25))
	if get_block(cell + Vector3i.LEFT) == BLOCK_AIR:
		_quad(st, Vector3(x,y,z+1), Vector3(x,y+1,z+1), Vector3(x,y+1,z), Vector3(x,y,z), color.darkened(0.12))
	if get_block(cell + Vector3i.RIGHT) == BLOCK_AIR:
		_quad(st, Vector3(x+1,y,z), Vector3(x+1,y+1,z), Vector3(x+1,y+1,z+1), Vector3(x+1,y,z+1), color.darkened(0.12))
	if get_block(cell + Vector3i(0,0,-1)) == BLOCK_AIR:
		_quad(st, Vector3(x+1,y,z), Vector3(x+1,y+1,z), Vector3(x,y+1,z), Vector3(x,y,z), color.darkened(0.08))
	if get_block(cell + Vector3i(0,0,1)) == BLOCK_AIR:
		_quad(st, Vector3(x,y,z+1), Vector3(x,y+1,z+1), Vector3(x+1,y+1,z+1), Vector3(x+1,y,z+1), color.darkened(0.08))

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

func _block_color(block_type: int) -> Color:
	match block_type:
		BLOCK_GRASS:
			return Color(0.34, 0.66, 0.25)
		BLOCK_DIRT:
			return Color(0.46, 0.30, 0.18)
		_:
			return Color(0.48, 0.50, 0.53)
