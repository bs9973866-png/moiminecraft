extends Node3D

const WORLD_SIZE := 64
const MAX_HEIGHT := 32
const BLOCK_AIR := 0
const BLOCK_GRASS := 1
const BLOCK_DIRT := 2
const BLOCK_STONE := 3
const TILE_SIZE := 16

var blocks: Dictionary = {}
var terrain_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var terrain_body: StaticBody3D
var terrain_mesh: ArrayMesh
var block_atlas: Texture2D

signal world_changed

func _ready() -> void:
	terrain_noise.seed = 481516
	terrain_noise.frequency = 0.028
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_gain = 0.48
	detail_noise.seed = 91273
	detail_noise.frequency = 0.095
	detail_noise.fractal_octaves = 3
	block_atlas = _create_block_atlas()
	_generate_world()

func _generate_world() -> void:
	blocks.clear()
	for x in range(WORLD_SIZE):
		for z in range(WORLD_SIZE):
			var broad := terrain_noise.get_noise_2d(float(x), float(z))
			var detail := detail_noise.get_noise_2d(float(x) + 1700.0, float(z) + 1700.0)
			var surface := clampi(11 + roundi(broad * 8.0 + detail * 2.2), 3, MAX_HEIGHT - 3)
			for y in range(surface + 1):
				var block_type := BLOCK_STONE
				if y == surface:
					block_type = BLOCK_GRASS
				elif y >= surface - 3:
					block_type = BLOCK_DIRT
				blocks[Vector3i(x, y, z)] = block_type
	_rebuild_mesh()

func get_spawn_position() -> Vector3:
	var x := WORLD_SIZE / 2
	var z := WORLD_SIZE / 2
	var y := 12
	while y < MAX_HEIGHT - 1 and get_block(Vector3i(x, y, z)) != BLOCK_AIR:
		y += 1
	return Vector3(float(x) + 0.5, float(y) + 0.1, float(z) + 0.5)

func get_block(cell: Vector3i) -> int:
	return int(blocks.get(cell, BLOCK_AIR))

func break_block(cell: Vector3i) -> int:
	var removed_type := get_block(cell)
	if removed_type == BLOCK_AIR:
		return BLOCK_AIR
	blocks.erase(cell)
	_rebuild_mesh()
	world_changed.emit()
	return removed_type

func place_block(cell: Vector3i, block_type: int = BLOCK_DIRT) -> bool:
	if get_block(cell) != BLOCK_AIR or cell.y < 0 or cell.y >= MAX_HEIGHT:
		return false
	if block_type <= BLOCK_AIR or block_type > BLOCK_STONE:
		return false
	blocks[cell] = block_type
	_rebuild_mesh()
	world_changed.emit()
	return true

func serialize_blocks() -> Array:
	var result: Array = []
	for cell_variant in blocks.keys():
		var cell: Vector3i = cell_variant
		result.append([cell.x, cell.y, cell.z, int(blocks[cell])])
	return result

func load_blocks(saved_blocks: Array) -> void:
	blocks.clear()
	for entry in saved_blocks:
		if entry is Array and entry.size() == 4:
			var cell := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
			var block_type := int(entry[3])
			if block_type > BLOCK_AIR and block_type <= BLOCK_STONE and cell.y >= 0 and cell.y < MAX_HEIGHT:
				blocks[cell] = block_type
	_rebuild_mesh()

func _create_block_atlas() -> Texture2D:
	var image := Image.create(TILE_SIZE * 4, TILE_SIZE, false, Image.FORMAT_RGBA8)
	for tile in range(4):
		for py in range(TILE_SIZE):
			for px in range(TILE_SIZE):
				var variation := float(((px * 17 + py * 31 + tile * 13) % 11) - 5) / 100.0
				var color := Color(0.4, 0.4, 0.4)
				match tile:
					0:
						color = Color(0.30 + variation, 0.66 + variation, 0.20 + variation)
					1:
						if py < 3:
							color = Color(0.30 + variation, 0.64 + variation, 0.19 + variation)
						else:
							color = Color(0.43 + variation, 0.29 + variation, 0.16 + variation)
					2:
						color = Color(0.43 + variation, 0.28 + variation, 0.16 + variation)
					3:
						color = Color(0.47 + variation, 0.49 + variation, 0.52 + variation)
				image.set_pixel(tile * TILE_SIZE + px, py, color)
	var texture := ImageTexture.create_from_image(image)
	return texture

func _rebuild_mesh() -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell_variant in blocks.keys():
		var cell: Vector3i = cell_variant
		var block_type: int = blocks[cell]
		_add_visible_faces(surface_tool, cell, block_type)
	terrain_mesh = surface_tool.commit()
	if terrain_mesh == null or terrain_mesh.get_surface_count() == 0:
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = block_atlas
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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

func _add_visible_faces(st: SurfaceTool, cell: Vector3i, block_type: int) -> void:
	var x := float(cell.x)
	var y := float(cell.y)
	var z := float(cell.z)
	var top_tile := 0 if block_type == BLOCK_GRASS else (2 if block_type == BLOCK_DIRT else 3)
	var side_tile := 1 if block_type == BLOCK_GRASS else (2 if block_type == BLOCK_DIRT else 3)
	if get_block(cell + Vector3i.UP) == BLOCK_AIR:
		_quad(st, Vector3(x,y+1,z), Vector3(x,y+1,z+1), Vector3(x+1,y+1,z+1), Vector3(x+1,y+1,z), top_tile)
	if get_block(cell + Vector3i.DOWN) == BLOCK_AIR:
		_quad(st, Vector3(x,y,z), Vector3(x+1,y,z), Vector3(x+1,y,z+1), Vector3(x,y,z+1), side_tile)
	if get_block(cell + Vector3i.LEFT) == BLOCK_AIR:
		_quad(st, Vector3(x,y,z+1), Vector3(x,y+1,z+1), Vector3(x,y+1,z), Vector3(x,y,z), side_tile)
	if get_block(cell + Vector3i.RIGHT) == BLOCK_AIR:
		_quad(st, Vector3(x+1,y,z), Vector3(x+1,y+1,z), Vector3(x+1,y+1,z+1), Vector3(x+1,y,z+1), side_tile)
	if get_block(cell + Vector3i(0,0,-1)) == BLOCK_AIR:
		_quad(st, Vector3(x,y,z), Vector3(x,y+1,z), Vector3(x+1,y+1,z), Vector3(x+1,y,z), side_tile)
	if get_block(cell + Vector3i(0,0,1)) == BLOCK_AIR:
		_quad(st, Vector3(x,y,z+1), Vector3(x+1,y,z+1), Vector3(x+1,y+1,z+1), Vector3(x,y+1,z+1), side_tile)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tile: int) -> void:
	var u0 := float(tile) / 4.0
	var u1 := float(tile + 1) / 4.0
	st.set_uv(Vector2(u0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(u0, 1.0))
	st.add_vertex(b)
	st.set_uv(Vector2(u1, 1.0))
	st.add_vertex(c)
	st.set_uv(Vector2(u0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(u1, 1.0))
	st.add_vertex(c)
	st.set_uv(Vector2(u1, 0.0))
	st.add_vertex(d)
