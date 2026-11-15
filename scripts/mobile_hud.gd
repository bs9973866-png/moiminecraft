extends CanvasLayer

const BLOCK_NAMES := {1: "Трава", 2: "Земля", 3: "Камень"}
const BLOCK_SHORT := {1: "Т", 2: "З", 3: "К"}
const SLOT_COUNT := 24
const HOTBAR_COUNT := 8

var player: Variant
var root: Control
var inventory: Array[int] = []
var item_counts: Array[int] = []
var selected_slot := 0
var inventory_panel: PanelContainer
var inventory_grid: GridContainer
var slot_buttons: Array[Button] = []
var hotbar_label: Label
var held_axes: Dictionary = {}

signal inventory_changed

func _ready() -> void:
	inventory.resize(SLOT_COUNT)
	inventory.fill(0)
	item_counts.resize(SLOT_COUNT)
	item_counts.fill(0)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	_build_controls()
	_build_inventory()
	get_viewport().size_changed.connect(_layout)
	_refresh_inventory()

func _build_controls() -> void:
	_add_hold_button("◀", Vector2.ZERO, Vector2(66, 66), Vector2(-1, 0), "left")
	_add_hold_button("▶", Vector2.ZERO, Vector2(66, 66), Vector2(1, 0), "right")
	_add_hold_button("▲", Vector2.ZERO, Vector2(66, 66), Vector2(0, -1), "forward")
	_add_hold_button("▼", Vector2.ZERO, Vector2(66, 66), Vector2(0, 1), "back")
	_add_action_button("ПРЫЖОК", Vector2.ZERO, Vector2(128, 54), func(): player.jump(), "jump")
	_add_action_button("ЛОМАТЬ", Vector2.ZERO, Vector2(128, 54), func(): player.break_target(), "break")
	_add_action_button("СТАВИТЬ", Vector2.ZERO, Vector2(128, 54), func(): player.place_target(), "place")
	_add_action_button("ИНВЕНТАРЬ", Vector2.ZERO, Vector2(128, 46), toggle_inventory, "inventory")
	var hint := Label.new()
	hint.text = "Правая часть экрана — обзор"
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(1, 1, 1, 0.78)
	hint.position = Vector2(18, 14)
	root.add_child(hint)
	hotbar_label = Label.new()
	hotbar_label.add_theme_font_size_override("font_size", 16)
	hotbar_label.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(hotbar_label)

func _add_hold_button(caption: String, _offset: Vector2, size: Vector2, axis: Vector2, tag: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.12, 0.18, 0.78)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.28, 0.48, 0.70, 0.95)))
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
	button.add_theme_stylebox_override("normal", _button_style(Color(0.16, 0.19, 0.29, 0.88)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.34, 0.40, 0.62, 1.0)))
	button.pressed.connect(callback)
	button.set_meta("tag", tag)
	root.add_child(button)

func _build_inventory() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.visible = false
	inventory_panel.custom_minimum_size = Vector2(420, 300)
	inventory_panel.add_theme_stylebox_override("panel", _button_style(Color(0.055, 0.07, 0.11, 0.96)))
	root.add_child(inventory_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	inventory_panel.add_child(outer)
	var heading := Label.new()
	heading.text = "ИНВЕНТАРЬ · 24 СЛОТА"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	outer.add_child(heading)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.add_theme_constant_override("h_separation", 6)
	inventory_grid.add_theme_constant_override("v_separation", 6)
	outer.add_child(inventory_grid)
	for i in range(SLOT_COUNT):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(58, 48)
		slot.add_theme_font_size_override("font_size", 14)
		slot.add_theme_color_override("font_color", Color.WHITE)
		slot.add_theme_stylebox_override("normal", _button_style(Color(0.13, 0.15, 0.22, 0.96)))
		slot.pressed.connect(func(): _select_slot(i))
		inventory_grid.add_child(slot)
		slot_buttons.append(slot)
	var close := Button.new()
	close.text = "ЗАКРЫТЬ"
	close.pressed.connect(toggle_inventory)
	outer.add_child(close)

func _button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.65, 0.75, 0.92, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
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

func add_block(block_type: int) -> void:
	for i in range(SLOT_COUNT):
		if inventory[i] == block_type and item_counts[i] < 64:
			item_counts[i] += 1
			_refresh_inventory()
			return
	for i in range(SLOT_COUNT):
		if inventory[i] == 0:
			inventory[i] = block_type
			item_counts[i] = 1
			_refresh_inventory()
			return

func get_selected_block() -> int:
	if selected_slot < 0 or selected_slot >= SLOT_COUNT:
		return 0
	return inventory[selected_slot]

func remove_selected_block() -> void:
	if get_selected_block() != 0:
		item_counts[selected_slot] -= 1
		if item_counts[selected_slot] <= 0:
			item_counts[selected_slot] = 0
			inventory[selected_slot] = 0
		_refresh_inventory()
	inventory_changed.emit()

func serialize_inventory() -> Dictionary:
	return {
		"blocks": inventory.duplicate(),
		"counts": item_counts.duplicate(),
		"selected": selected_slot
	}

func load_inventory(data: Dictionary) -> void:
	var saved_blocks = data.get("blocks", [])
	var saved_counts = data.get("counts", [])
	for i in range(mini(SLOT_COUNT, saved_blocks.size())):
		inventory[i] = clampi(int(saved_blocks[i]), 0, 3)
	for i in range(mini(SLOT_COUNT, saved_counts.size())):
		item_counts[i] = clampi(int(saved_counts[i]), 0, 64)
	for i in range(SLOT_COUNT):
		if item_counts[i] == 0:
			inventory[i] = 0
		elif inventory[i] == 0:
			item_counts[i] = 0
	selected_slot = clampi(int(data.get("selected", 0)), 0, SLOT_COUNT - 1)
	_refresh_inventory()

func _select_slot(index: int) -> void:
	selected_slot = index
	_refresh_inventory()
	inventory_changed.emit()

func toggle_inventory() -> void:
	inventory_panel.visible = not inventory_panel.visible
	_refresh_inventory()

func _refresh_inventory() -> void:
	for i in range(slot_buttons.size()):
		var block_type := inventory[i]
		var title := "Пусто" if block_type == 0 else BLOCK_NAMES.get(block_type, "Блок")
		slot_buttons[i].text = "%02d\n%s\n×%d" % [i + 1, title, item_counts[i]]
		if i == selected_slot:
			slot_buttons[i].add_theme_stylebox_override("normal", _button_style(Color(0.30, 0.34, 0.52, 1.0)))
		else:
			slot_buttons[i].add_theme_stylebox_override("normal", _button_style(Color(0.13, 0.15, 0.22, 0.96)))
	var parts: Array[String] = []
	for i in range(HOTBAR_COUNT):
		var b := inventory[i]
		parts.append("[%s %s]" % [">" if i == selected_slot else " ", BLOCK_SHORT.get(b, "·") if b != 0 else "·"])
	hotbar_label.text = "  ".join(parts)

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
				"jump": child.position = Vector2(size.x - 150, size.y - 220)
				"break": child.position = Vector2(size.x - 150, size.y - 154)
				"place": child.position = Vector2(size.x - 150, size.y - 88)
				"inventory": child.position = Vector2(size.x - 150, size.y - 32)
		if child == hotbar_label:
			hotbar_label.position = Vector2(maxf(250.0, size.x * 0.5 - 180.0), size.y - 54)
	if inventory_panel != null:
		inventory_panel.position = Vector2(size.x * 0.5 - 210.0, size.y * 0.5 - 150.0)
