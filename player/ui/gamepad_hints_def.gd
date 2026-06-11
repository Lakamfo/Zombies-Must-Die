class_name GamePadHintsDef
extends PanelContainer

@onready var hints := {
	&"move":   $margin_container/v_box_container/accp_move,
	&"look":   $margin_container/v_box_container/accp_look,
	&"jump":   $margin_container/v_box_container/accp_jump,
	&"crouch": $margin_container/v_box_container/accp_crouch,
	&"use":    $margin_container/v_box_container/accp_use,
	&"light":  $margin_container/v_box_container/accp_light,
	&"sprint": $margin_container/v_box_container/accp_sprint,
}

var action_map := {
	&"move_forward":   &"move",
	&"move_backward":  &"move",
	&"move_left":      &"move",
	&"move_right":     &"move",
	&"rot_cam_left":   &"look",
	&"rot_cam_right":  &"look",
	&"rot_cam_up":     &"look",
	&"rot_cam_down":   &"look",
	&"jump":           &"jump",
	&"crouch":         &"crouch",
	&"flashlight":     &"light",
	&"sprint":         &"sprint",
}

var _stick_hints_hidden := false


func _ready() -> void:
	EventBus.update_settings.connect(_settings_updated)
	EventBus.ui_update_interactable.connect(_on_interactable_changed)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	_settings_updated()  



func _refresh_hints_state() -> void:
	if not Global.first_hint_counter:
		
		var gamepad_connected = not Input.get_connected_joypads().is_empty()
		hints[&"move"].visible   = gamepad_connected and not _stick_hints_hidden
		hints[&"look"].visible   = gamepad_connected and not _stick_hints_hidden
		
		hints[&"jump"].visible   = gamepad_connected
		hints[&"crouch"].visible = gamepad_connected
		hints[&"light"].visible  = gamepad_connected
		hints[&"sprint"].visible = gamepad_connected
	else:
		for hint in hints.values():
			hint.visible = false



func _update_panel_visibility() -> void:
	if not InputSettings.joy_hints or Input.get_connected_joypads().is_empty():
		visible = false
		return

	visible = hints.values().any(func(h): return h.visible)


func _settings_updated() -> void:
	_refresh_hints_state()
	_update_panel_visibility()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		_stick_hints_hidden = false
	_refresh_hints_state()
	_update_panel_visibility()



func _on_interactable_changed(desc: String) -> void:
	hints[&"use"].visible = (desc != "")
	_update_panel_visibility()



func _input(event: InputEvent) -> void:
	if not InputSettings.joy_hints:
		return
	if not Global.gamepad_connected:
		return


	if event is InputEventJoypadMotion:
		if _stick_hints_hidden:
			return

		if abs(event.axis_value) > 0.5:
			_hide_hint(&"move")
			_hide_hint(&"look")
			_stick_hints_hidden = true
			_update_panel_visibility()
		return

	if not event is InputEventJoypadButton or not event.is_pressed():
		return

	var changed := false
	for action in action_map.keys():
		if event.is_action(action):
			if _hide_hint(action_map[action]):
				changed = true

	if changed:
		_update_panel_visibility()


func _hide_hint(key: StringName) -> bool:
	var hint = hints.get(key)
	if hint and hint.visible:
		hint.hide()
		return true
	return false
