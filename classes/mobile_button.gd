extends Control

class_name ActionMobileButton

@export var show_only_with_touch: bool = true
@export var action: String
@export var toggle_button: bool = false
@export var pressed_modulate: Color = Color.DARK_GRAY

var toggled: bool = false


func _ready() -> void:
	if show_only_with_touch:
		visible = DisplayServer.is_touchscreen_available()


func _input(event) -> void:
	if event is InputEventScreenTouch:
		if toggle_button:
			if not event.pressed and is_in_rect(event.position):
				toggled = not toggled

				if toggled:
					Input.action_press(action)
					modulate = pressed_modulate
				else:
					Input.action_release(action)
					modulate = Color.WHITE

			return

		if event.pressed and is_in_rect(event.position):
			Input.action_press(action)
			modulate = pressed_modulate
		elif not event.pressed:
			Input.action_release(action)
			modulate = Color.WHITE


func is_in_rect(pos) -> bool:
	return pos.x > get_rect().position.x \
	and pos.y > get_rect().position.y \
	and pos.x < get_rect().end.x \
	and pos.y < get_rect().end.y
