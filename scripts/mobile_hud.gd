extends CanvasLayer

var player: Variant
var root: Control

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	_build_controls()
	get_viewport().size_changed.connect(_layout)

func _build_controls() -> void:
	_add_hold_button("◀", Vector2(22, -142), Vector2(66, 66), func(pressed: bool): _set_move_axis(Vector2(-1, 0), pressed), "left")
	_add_hold_button("▶", Vector2(162, -142), Vector2(66, 66), func(pressed: bool): _set_move_axis(Vector2(1, 0), pressed), "right")
	_add_hold_button("▲", Vector2(92, -212), Vector2(66, 66), func(pressed: bool): _set_move_axis(Vector2(0, -1), pressed), "forward")
	_add_hold_button("▼", Vector2(92, -72), Vector2(66, 66), func(pressed: bool): _set_move_axis(Vector2(0, 1), pressed), "back")
	_add_action_button("ПРЫЖОК", Vector2(-150, -220), Vector2(128, 54), func(): player.jump(), "jump")
	_add_action_button("ЛОМАТЬ", Vector2(-150, -154), Vector2(128, 54), func(): player.break_target(), "break")
	_add_action_button("СТАВИТЬ", Vector2(-150, -88), Vector2(128, 54), func(): player.place_target(), "place")
	var hint := Label.new()
	hint.text = "Проводи пальцем по правой части экрана — обзор"
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(1, 1, 1, 0.78)
	hint.position = Vector2(18, 14)
	root.add_child(hint)
	_layout()

func _add_hold_button(caption: String, offset: Vector2, size: Vector2, callback: Callable, tag: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.12, 0.18, 0.78)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.28, 0.48, 0.70, 0.95)))
	button.button_down.connect(func(): callback.call(true))
	button.button_up.connect(func(): callback.call(false))
	button.set_meta("tag", tag)
	root.add_child(button)

func _add_action_button(caption: String, offset: Vector2, size: Vector2, callback: Callable, tag: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.16, 0.19, 0.29, 0.88)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.34, 0.40, 0.62, 1.0)))
	button.pressed.connect(callback)
	button.set_meta("tag", tag)
	root.add_child(button)

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

var held_axes: Dictionary = {}

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
	player.mobile_move = result

func _layout() -> void:
	if root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	for child in root.get_children():
		if not child is Button:
			continue
		var tag: String = child.get_meta("tag", "")
		match tag:
			"left":
				child.position = Vector2(22, viewport_size.y - 160)
			"right":
				child.position = Vector2(162, viewport_size.y - 160)
			"forward":
				child.position = Vector2(92, viewport_size.y - 230)
			"back":
				child.position = Vector2(92, viewport_size.y - 90)
			"jump":
				child.position = Vector2(viewport_size.x - 150, viewport_size.y - 220)
			"break":
				child.position = Vector2(viewport_size.x - 150, viewport_size.y - 154)
			"place":
				child.position = Vector2(viewport_size.x - 150, viewport_size.y - 88)
