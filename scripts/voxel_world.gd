extends Node3D

const WORLD_SIZE := 64
const MAX_HEIGHT := 32
const BLOCK_AIR := 0
const BLOCK_GRASS := 1
const BLOCK_DIRT := 2
const BLOCK_STONE := 3
const BLOCK_WOOD := 4
const BLOCK_LEAVES := 5
const BLOCK_PLANKS := 6
const BLOCK_CRAFTING_TABLE := 7
const TILE_SIZE := 16
const ATLAS_TILES := 8

var blocks: Dictionary = {}
var base_blocks: Dictionary = {}
var edited_blocks: Dictionary = {}
var terrain_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var terrain_body: StaticBody3D
var terrain_mesh: ArrayMesh
var block_atlas: Texture2D
var terrain_material: StandardMaterial3D
var mesh_rebuild_queued := false
var edit_revision := 0

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
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_texture = block_atlas
	terrain_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	terrain_material.roughness = 1.0
	terrain_material.cull_mode = BaseMaterial3D.CULL_BACK
	_generate_world()

func _generate_world() -> void:
	blocks.clear()
	var surface_heights: Dictionary = {}
	for x in range(WORLD_SIZE):
		for z in range(WORLD_SIZE):
			var broad := terrain_noise.get_noise_2d(float(x), float(z))
			var detail := detail_noise.get_noise_2d(float(x) + 1700.0, float(z) + 1700.0)
			var surface := clampi(11 + roundi(broad * 8.0 + detail * 2.2), 3, MAX_HEIGHT - 3)
			surface_heights[Vector2i(x, z)] = surface
			for y in range(surface + 1):
				var block_type := BLOCK_STONE
				if y == surface:
					block_type = BLOCK_GRASS
				elif y >= surface - 3:
					block_type = BLOCK_DIRT
				blocks[Vector3i(x, y, z)] = block_type

	# Deterministic small trees. No per-block scene nodes are created.
	for x in range(3, WORLD_SIZE - 3):
		for z in range(3, WORLD_SIZE - 3):
			var hash_value := absi(x * 73856093 ^ z * 19349663 ^ 481516)
			if hash_value % 100 >= 2:
				continue
			var surface: int = int(surface_heights[Vector2i(x, z)])
			if surface < 10:
				continue
			var trunk_height := 3 + (hash_value % 2)
			for ty in range(1, trunk_height + 1):
				blocks[Vector3i(x, surface + ty, z)] = BLOCK_WOOD
			var crown_y := surface + trunk_height
			for lx in range(-2, 3):
				for lz in range(-2, 3):
					for ly in range(-1, 3):
						if absi(lx) + absi(lz) + absi(ly) > 5:
							continue
						var leaf_cell := Vector3i(x + lx, crown_y + ly, z + lz)
						if not blocks.has(leaf_cell):
							blocks[leaf_cell] = BLOCK_LEAVES

	base_blocks = blocks.duplicate()
	edited_blocks.clear()
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
	if removed_type == BLOCK_AIR or cell.x < 0 or cell.x >= WORLD_SIZE or cell.z < 0 or cell.z >= WORLD_SIZE or cell.y < 0 or cell.y >= MAX_HEIGHT:
		return BLOCK_AIR
	blocks.erase(cell)
	edited_blocks[cell] = BLOCK_AIR
	edit_revision += 1
	_queue_mesh_rebuild()
	world_changed.emit()
	return removed_type

func place_block(cell: Vector3i, block_type: int = BLOCK_DIRT) -> bool:
	if get_block(cell) != BLOCK_AIR or cell.x < 0 or cell.x >= WORLD_SIZE or cell.z < 0 or cell.z >= WORLD_SIZE or cell.y < 0 or cell.y >= MAX_HEIGHT:
		return false
	if not is_placeable_block(block_type):
		return false
	blocks[cell] = block_type
	edited_blocks[cell] = block_type
	edit_revision += 1
	_queue_mesh_rebuild()
	world_changed.emit()
	return true

func is_placeable_block(block_type: int) -> bool:
	return block_type >= BLOCK_GRASS and block_type <= BLOCK_CRAFTING_TABLE

func has_block_near(world_position: Vector3, block_type: int, radius: int = 4) -> bool:
	var center := Vector3i(floori(world_position.x), floori(world_position.y), floori(world_position.z))
	var min_y := maxi(0, center.y - 3)
	var max_y := mini(MAX_HEIGHT - 1, center.y + 1)
	for x in range(center.x - radius, center.x + radius + 1):
		for z in range(center.z - radius, center.z + radius + 1):
			for y in range(min_y, max_y + 1):
				if get_block(Vector3i(x, y, z)) == block_type:
					return true
	return false

# Saves only player edits. The generated terrain is deterministic and is rebuilt from the seed.
func serialize_blocks() -> Array:
	var result: Array = []
	for cell_variant in edited_blocks.keys():
		var cell: Vector3i = cell_variant
		result.append([cell.x, cell.y, cell.z, int(edited_blocks[cell])])
	return result

# legacy_snapshot=true imports the previous version-2 full-world save and converts it to sparse edits.
func load_blocks(saved_blocks: Array, legacy_snapshot: bool = false) -> void:
	if legacy_snapshot:
		var loaded: Dictionary = {}
		for entry in saved_blocks:
			if entry is Array and entry.size() == 4:
				var cell := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
				var block_type := int(entry[3])
				if block_type >= BLOCK_GRASS and block_type <= BLOCK_CRAFTING_TABLE and cell.x >= 0 and cell.x < WORLD_SIZE and cell.z >= 0 and cell.z < WORLD_SIZE and cell.y >= 0 and cell.y < MAX_HEIGHT:
					loaded[cell] = block_type
		blocks = loaded
		edited_blocks.clear()
		for cell_variant in base_blocks.keys():
			var cell: Vector3i = cell_variant
			var base_type := int(base_blocks[cell])
			var loaded_type := int(blocks.get(cell, BLOCK_AIR))
			if base_type != loaded_type:
				edited_blocks[cell] = loaded_type
		for cell_variant in blocks.keys():
			var cell: Vector3i = cell_variant
			if not base_blocks.has(cell):
				edited_blocks[cell] = int(blocks[cell])
	else:
		blocks = base_blocks.duplicate()
		edited_blocks.clear()
		for entry in saved_blocks:
			if entry is Array and entry.size() == 4:
				var cell := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
				var block_type := int(entry[3])
				if cell.x < 0 or cell.x >= WORLD_SIZE or cell.z < 0 or cell.z >= WORLD_SIZE or cell.y < 0 or cell.y >= MAX_HEIGHT or block_type < BLOCK_AIR or block_type > BLOCK_CRAFTING_TABLE:
					continue
				edited_blocks[cell] = block_type
				if block_type == BLOCK_AIR:
					blocks.erase(cell)
				else:
					blocks[cell] = block_type
	edit_revision += 1
	_rebuild_mesh()

func _create_block_atlas() -> Texture2D:
	var image := Image.create(TILE_SIZE * ATLAS_TILES, TILE_SIZE, false, Image.FORMAT_RGBA8)
	for tile in range(ATLAS_TILES):
		for py in range(TILE_SIZE):
			for px in range(TILE_SIZE):
				var variation := float(((px * 17 + py * 31 + tile * 13) % 11) - 5) / 100.0
				var color := Color(0.4, 0.4, 0.4)
				match tile:
					0:
						color = Color(0.30 + variation, 0.66 + variation, 0.20 + variation)
					1:
						color = Color(0.30 + variation, 0.64 + variation, 0.19 + variation) if py < 3 else Color(0.43 + variation, 0.29 + variation, 0.16 + variation)
					2:
						color = Color(0.43 + variation, 0.28 + variation, 0.16 + variation)
					3:
						color = Color(0.47 + variation, 0.49 + variation, 0.52 + variation)
					4:
						color = Color(0.39 + variation, 0.25 + variation, 0.12 + variation) if px < 3 or px > 12 else Color(0.55 + variation, 0.37 + variation, 0.19 + variation)
					5:
						color = Color(0.16 + variation, 0.43 + variation, 0.12 + variation)
					6:
						color = Color(0.62 + variation, 0.43 + variation, 0.23 + variation)
					7:
						color = Color(0.48 + variation, 0.29 + variation, 0.13 + variation) if py < 4 or px < 3 or px > 12 else Color(0.66 + variation, 0.47 + variation, 0.25 + variation)
				image.set_pixel(tile * TILE_SIZE + px, py, color)
	return ImageTexture.create_from_image(image)

func _queue_mesh_rebuild() -> void:
	if mesh_rebuild_queued:
		return
	mesh_rebuild_queued = true
	call_deferred("_rebuild_mesh")

func _rebuild_mesh() -> void:
	mesh_rebuild_queued = false
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell_variant in blocks.keys():
		var cell: Vector3i = cell_variant
		var block_type: int = blocks[cell]
		_add_visible_faces(surface_tool, cell, block_type)
	terrain_mesh = surface_tool.commit()
	if terrain_mesh == null or terrain_mesh.get_surface_count() == 0:
		if is_instance_valid(terrain_body):
			terrain_body.queue_free()
			terrain_body = null
		return
	terrain_mesh.surface_set_material(0, terrain_material)
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
	var top_tile := 0
	var side_tile := 1
	match block_type:
		BLOCK_GRASS:
			top_tile = 0
			side_tile = 1
		BLOCK_DIRT:
			top_tile = 2
			side_tile = 2
		BLOCK_STONE:
			top_tile = 3
			side_tile = 3
		BLOCK_WOOD:
			top_tile = 4
			side_tile = 4
		BLOCK_LEAVES:
			top_tile = 5
			side_tile = 5
		BLOCK_PLANKS:
			top_tile = 6
			side_tile = 6
		BLOCK_CRAFTING_TABLE:
			top_tile = 7
			side_tile = 7
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
	var u0 := float(tile) / float(ATLAS_TILES)
	var u1 := float(tile + 1) / float(ATLAS_TILES)
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
