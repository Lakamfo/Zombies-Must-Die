extends ScrollContainer

class_name ScrollContainerMouse

var is_dragging: bool = false
var last_drag_position: Vector2 = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and !_is_ui_under_mouse():
				is_dragging = true
				last_drag_position = get_global_mouse_position()
			else:
				is_dragging = false
		elif !event.pressed:
			is_dragging = false

	elif event is InputEventMouseMotion and is_dragging:
		var current_position: Vector2 = get_global_mouse_position()
		var drag_delta: Vector2 = last_drag_position - current_position
		scroll_vertical += int(drag_delta.y)
		last_drag_position = current_position


func _is_ui_under_mouse() -> bool:
	var ui_element: Control = get_viewport().gui_get_hovered_control()

	if not ui_element:
		return false

	if ui_element.is_in_group(&"scroll_block"):
		return true

	if ui_element is Slider or ui_element is OptionButton:
		return true

	return false
