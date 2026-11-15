extends CharacterBody3D

const SPEED := 6.0
const JUMP_VELOCITY := 5.2
const LOOK_SENSITIVITY := 0.004
const REACH := 6.0

var world: Variant
var hud: Variant
var mobile_move := Vector2.ZERO
var look_pitch := 0.0
var camera: Camera3D

func _ready() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)

	camera = Camera3D.new()
	camera.position = Vector3(0, 1.58, 0)
	camera.current = true
	camera.fov = 78.0
	add_child(camera)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mobile_move.length() > 0.05:
		input_vector = mobile_move
	var direction := (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 7.0 * delta)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jump()
	move_and_slide()

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
			_rotate_look(event.relative)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rotate_look(event.relative)

func _rotate_look(relative: Vector2) -> void:
	rotate_y(-relative.x * LOOK_SENSITIVITY)
	look_pitch = clampf(look_pitch - relative.y * LOOK_SENSITIVITY, -1.45, 1.45)
	camera.rotation.x = look_pitch

func break_target() -> void:
	_edit_target(false)

func place_target() -> void:
	_edit_target(true)

func _edit_target(placing: bool) -> void:
	if not is_instance_valid(world):
		return
	var origin := camera.global_position
	var target := origin + (-camera.global_transform.basis.z * REACH)
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var normal: Vector3 = hit.normal
	var point: Vector3 = hit.position
	var cell: Vector3i
	if placing:
		cell = Vector3i(floori(point.x + normal.x * 0.02), floori(point.y + normal.y * 0.02), floori(point.z + normal.z * 0.02))
		if global_position.distance_to(Vector3(cell) + Vector3.ONE * 0.5) < 1.2:
			return
		world.place_block(cell)
	else:
		cell = Vector3i(floori(point.x - normal.x * 0.02), floori(point.y - normal.y * 0.02), floori(point.z - normal.z * 0.02))
		world.break_block(cell)
