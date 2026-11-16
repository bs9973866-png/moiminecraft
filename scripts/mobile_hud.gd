extends CanvasLayer

const SLOT_COUNT := 24
const HOTBAR_COUNT := 8
const STACK_LIMIT := 64

const ITEM_AIR := 0
const ITEM_GRASS := 1
const ITEM_DIRT := 2
const ITEM_STONE := 3
const ITEM_WOOD := 4
const ITEM_LEAVES := 5
const ITEM_PLANKS := 6
const ITEM_CRAFTING_TABLE := 7
const ITEM_STICK := 8
const ITEM_WOODEN_PICKAXE := 9
const ITEM_STONE_PICKAXE := 10

const ITEM_NAMES := {
	ITEM_GRASS: "Трава",
	ITEM_DIRT: "Земля",
	ITEM_STONE: "Камень",
	ITEM_WOOD: "Дерево",
	ITEM_LEAVES: "Листва",
	ITEM_PLANKS: "Доски",
	ITEM_CRAFTING_TABLE: "Верстак",
	ITEM_STICK: "Палка",
	ITEM_WOODEN_PICKAXE: "Дер. кирка",
	ITEM_STONE_PICKAXE: "Кам. кирка"
}

var player: Variant
var world: Variant
var root: Control
var inventory: Array[int] = []
var item_counts: Array[int] = []
var selected_slot := 0
var moving_slot := -1
var inventory_panel: PanelContainer
var inventory_grid: GridContainer
var slot_buttons: Array[Button] = []
var hotbar_buttons: Array[Button] = []
var recipe_buttons: Array[Button] = []
var recipe_status: Label
var held_axes: Dictionary = {}

var style_button: StyleBoxFlat
var style_slot: StyleBoxFlat
var style_slot_selected: StyleBoxFlat
var style_slot_moving: StyleBoxFlat
var style_hotbar: StyleBoxFlat
var style_hotbar_selected: StyleBoxFlat

signal inventory_changed

func _ready() -> void:
	inventory.resize(SLOT_COUNT)
	inventory.fill(ITEM_AIR)
	item_counts.resize(SLOT_COUNT)
	item_counts.fill(0)
	_build_styles()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	_build_controls()
	_build_inventory()
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")
	_refresh_inventory()

func _build_styles() -> void:
	style_button = _button_style(Color(0.16, 0.19, 0.29, 0.94))
	style_slot = _button_style(Color(0.13, 0.15, 0.22, 0.96))
	style_slot_selected = _button_style(Color(0.30, 0.34, 0.52, 1.0))
	style_slot_moving = _button_style(Color(0.62, 0.39, 0.16, 1.0))
	style_hotbar = _button_style(Color(0.10, 0.12, 0.18, 0.88))
	style_hotbar_selected = _button_style(Color(0.25, 0.43, 0.68, 1.0))

func _build_controls() -> void:
	_add_hold_button("◀", Vector2.ZERO, Vector2(84, 84), Vector2(-1, 0), "left")
	_add_hold_button("▶", Vector2.ZERO, Vector2(66, 66), Vector2(1, 0), "right")
	_add_hold_button("▲", Vector2.ZERO, Vector2(66, 66), Vector2(0, -1), "forward")
	_add_hold_button("▼", Vector2.ZERO, Vector2(66, 66), Vector2(0, 1), "back")
	_add_action_button("ПРЫЖОК", Vector2.ZERO, Vector2(156, 64), func(): player.jump(), "jump")
	_add_action_button("ЛОМАТЬ", Vector2.ZERO, Vector2(128, 54), func(): player.break_target(), "break")
	_add_action_button("СТАВИТЬ", Vector2.ZERO, Vector2(128, 54), func(): player.place_target(), "place")
	_add_action_button("ИНВЕНТАРЬ", Vector2.ZERO, Vector2(156, 56), toggle_inventory, "inventory")

	for i in range(HOTBAR_COUNT):
		var hotbar_button := Button.new()
		hotbar_button.custom_minimum_size = Vector2(58, 48)
		hotbar_button.add_theme_font_size_override("font_size", 13)
		hotbar_button.add_theme_color_override("font_color", Color.WHITE)
		hotbar_button.add_theme_stylebox_override("normal", style_hotbar)
		hotbar_button.pressed.connect(_select_hotbar.bind(i))
		hotbar_button.set_meta("tag", "hotbar_%d" % i)
		root.add_child(hotbar_button)
		hotbar_buttons.append(hotbar_button)

	var hint := Label.new()
	hint.text = "Правая часть экрана — обзор"
	hint.add_theme_font_size_override("font_size", 19)
	hint.modulate = Color(1, 1, 1, 0.78)
	hint.position = Vector2(18, 14)
	root.add_child(hint)

func _add_hold_button(caption: String, _offset: Vector2, size: Vector2, axis: Vector2, tag: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", style_button)
	button.add_theme_stylebox_override("pressed", style_hotbar_selected)
	button.button_down.connect(func(): _set_move_axis(axis, true))
	button.button_up.connect(func(): _set_move_axis(axis, false))
	button.set_meta("tag", tag)
	root.add_child(button)

func _add_action_button(caption: String, _offset: Vector2, size: Vector2, callback: Callable, tag: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", style_button)
	button.add_theme_stylebox_override("pressed", style_hotbar_selected)
	button.pressed.connect(callback)
	button.set_meta("tag", tag)
	root.add_child(button)

func _build_inventory() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.visible = false
	inventory_panel.custom_minimum_size = Vector2(590, 560)
	inventory_panel.add_theme_stylebox_override("panel", _button_style(Color(0.055, 0.07, 0.11, 0.98)))
	root.add_child(inventory_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 7)
	inventory_panel.add_child(outer)

	var heading := Label.new()
	heading.text = "ИНВЕНТАРЬ · 24 СЛОТА"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	outer.add_child(heading)

	inventory_grid = GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.add_theme_constant_override("h_separation", 5)
	inventory_grid.add_theme_constant_override("v_separation", 5)
	outer.add_child(inventory_grid)

	for i in range(SLOT_COUNT):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(78, 48)
		slot.add_theme_font_size_override("font_size", 14)
		slot.add_theme_color_override("font_color", Color.WHITE)
		slot.add_theme_stylebox_override("normal", style_slot)
		slot.pressed.connect(_on_inventory_slot_pressed.bind(i))
		inventory_grid.add_child(slot)
		slot_buttons.append(slot)

	var recipes_heading := Label.new()
	recipes_heading.text = "РЕЦЕПТЫ"
	recipes_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipes_heading.add_theme_font_size_override("font_size", 17)
	outer.add_child(recipes_heading)

	var recipes_grid := GridContainer.new()
	recipes_grid.columns = 2
	recipes_grid.add_theme_constant_override("h_separation", 6)
	recipes_grid.add_theme_constant_override("v_separation", 5)
	outer.add_child(recipes_grid)

	_add_recipe_button(recipes_grid, "ДОСКИ · 1 дерево → 4", _craft_planks)
	_add_recipe_button(recipes_grid, "ПАЛКИ · 2 доски → 4", _craft_sticks)
	_add_recipe_button(recipes_grid, "ВЕРСТАК · 4 доски → 1", _craft_workbench)
	_add_recipe_button(recipes_grid, "ДЕР. КИРКА · доски + палки", _craft_wooden_pickaxe)
	_add_recipe_button(recipes_grid, "КАМ. КИРКА · камень + палки", _craft_stone_pickaxe)

	recipe_status = Label.new()
	recipe_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_status.add_theme_font_size_override("font_size", 13)
	outer.add_child(recipe_status)

	var close := Button.new()
	close.text = "ЗАКРЫТЬ"
	close.custom_minimum_size = Vector2(0, 38)
	close.pressed.connect(toggle_inventory)
	outer.add_child(close)

func _add_recipe_button(parent: GridContainer, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", style_button)
	button.add_theme_stylebox_override("disabled", style_slot)
	button.pressed.connect(callback)
	parent.add_child(button)
	recipe_buttons.append(button)

func _button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.65, 0.75, 0.92, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _set_move_axis(axis: Vector2, pressed: bool) -> void:
	if pressed:
		held_axes[axis] = true
	else:
		held_axes.erase(axis)
	var result := Vector2.ZERO
	for axis_key in held_axes.keys():
		result += axis_key
	if result.length() > 1.0:
		result = result.normalized()
	if player != null:
		player.mobile_move = result

func _max_stack(item_type: int) -> int:
	if item_type == ITEM_WOODEN_PICKAXE or item_type == ITEM_STONE_PICKAXE:
		return 1
	return STACK_LIMIT

func add_block(block_type: int, amount: int = 1) -> int:
	if block_type <= ITEM_AIR or block_type > ITEM_STONE_PICKAXE or amount <= 0:
		return amount
	var remaining := amount
	for i in range(SLOT_COUNT):
		if inventory[i] == block_type and item_counts[i] < _max_stack(block_type):
			var added := mini(_max_stack(block_type) - item_counts[i], remaining)
			item_counts[i] += added
			remaining -= added
			if remaining <= 0:
				break
	if remaining > 0:
		for i in range(SLOT_COUNT):
			if item_counts[i] == 0:
				var added := mini(_max_stack(block_type), remaining)
				inventory[i] = block_type
				item_counts[i] = added
				remaining -= added
				if remaining <= 0:
					break
	if remaining != amount:
		_refresh_inventory()
		inventory_changed.emit()
	return remaining

func can_add_block(block_type: int, amount: int = 1) -> bool:
	if block_type <= ITEM_AIR or amount <= 0:
		return false
	var capacity := 0
	var limit := _max_stack(block_type)
	for i in range(SLOT_COUNT):
		if inventory[i] == block_type:
			capacity += limit - item_counts[i]
		elif item_counts[i] == 0:
			capacity += limit
		if capacity >= amount:
			return true
	return false

func get_selected_block() -> int:
	if selected_slot < 0 or selected_slot >= SLOT_COUNT or item_counts[selected_slot] <= 0:
		return ITEM_AIR
	return inventory[selected_slot]

func is_selected_placeable() -> bool:
	return world != null and world.is_placeable_block(get_selected_block())

func remove_selected_block() -> void:
	if get_selected_block() == ITEM_AIR:
		return
	item_counts[selected_slot] -= 1
	if item_counts[selected_slot] <= 0:
		item_counts[selected_slot] = 0
		inventory[selected_slot] = ITEM_AIR
	_refresh_inventory()
	inventory_changed.emit()

func has_item(item_type: int, amount: int) -> bool:
	var total := 0
	for i in range(SLOT_COUNT):
		if inventory[i] == item_type:
			total += item_counts[i]
	return total >= amount

func _consume_item(item_type: int, amount: int) -> bool:
	if not has_item(item_type, amount):
		return false
	var remaining := amount
	for i in range(SLOT_COUNT - 1, -1, -1):
		if inventory[i] != item_type:
			continue
		var taken := mini(item_counts[i], remaining)
		item_counts[i] -= taken
		remaining -= taken
		if item_counts[i] <= 0:
			item_counts[i] = 0
			inventory[i] = ITEM_AIR
		if remaining <= 0:
			break
	return remaining == 0

func _has_workbench_nearby() -> bool:
	return is_instance_valid(world) and is_instance_valid(player) and world.has_block_near(player.global_position, ITEM_CRAFTING_TABLE, 4)

func _craft(output_type: int, output_amount: int, requirements: Dictionary, needs_workbench: bool = false) -> void:
	if needs_workbench and not _has_workbench_nearby():
		_refresh_inventory()
		return
	if not can_add_block(output_type, output_amount):
		return
	for item_type in requirements.keys():
		if not has_item(int(item_type), int(requirements[item_type])):
			return
	for item_type in requirements.keys():
		_consume_item(int(item_type), int(requirements[item_type]))
	add_block(output_type, output_amount)
	_refresh_inventory()
	inventory_changed.emit()

func _craft_planks() -> void:
	_craft(ITEM_PLANKS, 4, {ITEM_WOOD: 1})

func _craft_sticks() -> void:
	_craft(ITEM_STICK, 4, {ITEM_PLANKS: 2})

func _craft_workbench() -> void:
	_craft(ITEM_CRAFTING_TABLE, 1, {ITEM_PLANKS: 4})

func _craft_wooden_pickaxe() -> void:
	_craft(ITEM_WOODEN_PICKAXE, 1, {ITEM_PLANKS: 3, ITEM_STICK: 2}, true)

func _craft_stone_pickaxe() -> void:
	_craft(ITEM_STONE_PICKAXE, 1, {ITEM_STONE: 3, ITEM_STICK: 2}, true)

func _on_inventory_slot_pressed(index: int) -> void:
	if moving_slot < 0:
		moving_slot = index
		if index < HOTBAR_COUNT:
			selected_slot = index
	elif moving_slot == index:
		moving_slot = -1
	else:
		_move_stack(moving_slot, index)
		moving_slot = -1
	_refresh_inventory()
	inventory_changed.emit()

func _move_stack(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= SLOT_COUNT or to_index < 0 or to_index >= SLOT_COUNT:
		return
	if item_counts[from_index] <= 0:
		return
	if item_counts[to_index] > 0 and inventory[from_index] == inventory[to_index] and item_counts[to_index] < _max_stack(inventory[to_index]):
		var amount := mini(_max_stack(inventory[to_index]) - item_counts[to_index], item_counts[from_index])
		item_counts[to_index] += amount
		item_counts[from_index] -= amount
		if item_counts[from_index] <= 0:
			item_counts[from_index] = 0
			inventory[from_index] = ITEM_AIR
		return
	var old_type := inventory[to_index]
	var old_count := item_counts[to_index]
	inventory[to_index] = inventory[from_index]
	item_counts[to_index] = item_counts[from_index]
	inventory[from_index] = old_type
	item_counts[from_index] = old_count
	if to_index < HOTBAR_COUNT:
		selected_slot = to_index
	elif from_index < HOTBAR_COUNT:
		selected_slot = from_index

func _select_hotbar(index: int) -> void:
	selected_slot = clampi(index, 0, HOTBAR_COUNT - 1)
	moving_slot = -1
	_refresh_inventory()
	inventory_changed.emit()

func serialize_inventory() -> Dictionary:
	return {
		"blocks": inventory.duplicate(),
		"counts": item_counts.duplicate(),
		"selected": selected_slot
	}

func load_inventory(data: Dictionary) -> void:
	inventory.fill(ITEM_AIR)
	item_counts.fill(0)
	var saved_blocks = data.get("blocks", [])
	var saved_counts = data.get("counts", [])
	for i in range(mini(SLOT_COUNT, saved_blocks.size())):
		var item_type := int(saved_blocks[i])
		inventory[i] = item_type if item_type >= ITEM_AIR and item_type <= ITEM_STONE_PICKAXE else ITEM_AIR
	for i in range(mini(SLOT_COUNT, saved_counts.size())):
		item_counts[i] = clampi(int(saved_counts[i]), 0, _max_stack(inventory[i]))
	for i in range(SLOT_COUNT):
		if item_counts[i] == 0:
			inventory[i] = ITEM_AIR
		elif inventory[i] == ITEM_AIR:
			item_counts[i] = 0
	selected_slot = clampi(int(data.get("selected", 0)), 0, HOTBAR_COUNT - 1)
	moving_slot = -1
	_refresh_inventory()

func toggle_inventory() -> void:
	inventory_panel.visible = not inventory_panel.visible
	moving_slot = -1
	held_axes.clear()
	if player != null:
		player.mobile_move = Vector2.ZERO
		player.input_locked = inventory_panel.visible
	_refresh_inventory()

func _refresh_inventory() -> void:
	for i in range(slot_buttons.size()):
		var item_type := inventory[i]
		var title: String = "Пусто" if item_type == ITEM_AIR else str(ITEM_NAMES.get(item_type, "Предмет"))
		slot_buttons[i].text = "%02d\n%s\n×%d" % [i + 1, title, item_counts[i]]
		if i == moving_slot:
			slot_buttons[i].add_theme_stylebox_override("normal", style_slot_moving)
		elif i == selected_slot:
			slot_buttons[i].add_theme_stylebox_override("normal", style_slot_selected)
		else:
			slot_buttons[i].add_theme_stylebox_override("normal", style_slot)

	for i in range(hotbar_buttons.size()):
		var item_type := inventory[i]
		var short_name: String = "—" if item_type == ITEM_AIR else str(ITEM_NAMES.get(item_type, "Предмет"))
		hotbar_buttons[i].text = "%d\n%s\n%d" % [i + 1, short_name, item_counts[i]]
		hotbar_buttons[i].add_theme_stylebox_override("normal", style_hotbar_selected if i == selected_slot else style_hotbar)

	var has_table := _has_workbench_nearby()
	if recipe_buttons.size() >= 5:
		recipe_buttons[0].disabled = not has_item(ITEM_WOOD, 1) or not can_add_block(ITEM_PLANKS, 4)
		recipe_buttons[1].disabled = not has_item(ITEM_PLANKS, 2) or not can_add_block(ITEM_STICK, 4)
		recipe_buttons[2].disabled = not has_item(ITEM_PLANKS, 4) or not can_add_block(ITEM_CRAFTING_TABLE, 1)
		recipe_buttons[3].disabled = not has_table or not has_item(ITEM_PLANKS, 3) or not has_item(ITEM_STICK, 2) or not can_add_block(ITEM_WOODEN_PICKAXE, 1)
		recipe_buttons[4].disabled = not has_table or not has_item(ITEM_STONE, 3) or not has_item(ITEM_STICK, 2) or not can_add_block(ITEM_STONE_PICKAXE, 1)
	if recipe_status != null:
		recipe_status.text = "Верстак рядом — крафт инструментов доступен" if has_table else "Поставь верстак рядом, чтобы создавать кирки"

func _layout() -> void:
	if root == null:
		return
	var size := get_viewport().get_visible_rect().size
	for child in root.get_children():
		if child is Button:
			var tag: String = child.get_meta("tag", "")
			match tag:
				"left": child.position = Vector2(22, size.y - 160)
				"right": child.position = Vector2(162, size.y - 160)
				"forward": child.position = Vector2(92, size.y - 230)
				"back": child.position = Vector2(92, size.y - 90)
				"jump": child.position = Vector2(size.x - 176, size.y - 260)
				"break": child.position = Vector2(size.x - 176, size.y - 184)
				"place": child.position = Vector2(size.x - 176, size.y - 108)
				"inventory": child.position = Vector2(size.x - 176, size.y - 62)
				_:
					if tag.begins_with("hotbar_"):
						var index := int(tag.trim_prefix("hotbar_"))
						var slot_width := minf(58.0, (size.x - 24.0) / float(HOTBAR_COUNT) - 3.0)
						var gap := 4.0
						var total := HOTBAR_COUNT * slot_width + (HOTBAR_COUNT - 1) * gap
						child.position = Vector2((size.x - total) * 0.5 + index * (slot_width + gap), size.y - 62)
						child.size = Vector2(slot_width, 48)
	if inventory_panel != null:
		var panel_width := minf(590.0, size.x - 24.0)
		var panel_height := minf(560.0, size.y - 24.0)
		inventory_panel.position = Vector2((size.x - panel_width) * 0.5, (size.y - panel_height) * 0.5)
		inventory_panel.size = Vector2(panel_width, panel_height)
