extends RefCounted
class_name InputDisplayHelper

const XBOX_PATH = "res://addons/kenney-input-prompts/xbox_vector/"
const SONY_PATH = "res://addons/kenney-input-prompts/sony_vector/"

enum JoypadType { XBOX, PLAYSTATION, NINTENDO, GENERIC }

#region Public static methods
static func get_event_text(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return _mouse_button_text(event.button_index)
	elif event is InputEventKey:
		return event.as_text().replacen(" - Physical", "")
	else:
		return ""


static func get_event_icon(event: InputEvent) -> Texture2D:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var path = _get_event_icon_path(event)
		if ResourceLoader.exists(path):
			return load(path)
	return null


static func has_gamepad_binding(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false


static func get_action_display(action_name: StringName, prefer_gamepad: bool = true) -> Variant:
	var events = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "?"
	
	
	if prefer_gamepad and Input.get_connected_joypads().size() > 0:
		for event in events:
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				
				var icon = get_event_icon(event)
				if icon:
					return icon
				else:
					return _gamepad_event_to_text(event)

	for event in events:
		if event is InputEventKey or event is InputEventMouseButton:
			return get_event_text(event)

	return events[0].as_text().replacen(" - Physical", "")


static func get_action_icon_path(action_name: StringName, prefer_gamepad: bool = true) -> String:
	var events = InputMap.action_get_events(action_name)
	if events.is_empty():
		return ""
	
	if prefer_gamepad and Input.get_connected_joypads().size() > 0:
		for event in events:
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				var path = _get_event_icon_path(event)
				if path:
					return path
	return ""
#endregion

#region Private static helpers
static func _mouse_button_text(button_index: int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT:   return "LMB"
		MOUSE_BUTTON_RIGHT:  return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		_: return "Mouse %d" % button_index

static func _get_event_icon_path(event: InputEvent) -> String:
	var type = _get_joypad_type()
	
	if event is InputEventJoypadButton:
		return _get_button_icon(event.button_index, type)
	elif event is InputEventJoypadMotion:
		return _get_axis_icon(event.axis, event.axis_value, type)
	return ""

static func _get_joypad_type() -> JoypadType:
	var joypads : Array[int] = Input.get_connected_joypads()
	if joypads.is_empty():
		return JoypadType.GENERIC
	var joy_name = Input.get_joy_name(joypads[0]).to_lower()
	if "xbox" in joy_name or "xinput" in joy_name:
		return JoypadType.XBOX
	elif "playstation" in joy_name or "dualshock" in joy_name or "dualsense" in joy_name or "ps4" in joy_name:
		return JoypadType.PLAYSTATION
	elif "nintendo" in joy_name or "switch" in joy_name:
		return JoypadType.NINTENDO
	return JoypadType.GENERIC

static func _get_button_icon(button_index: int, type: JoypadType) -> String:
	var is_ps : bool = type == JoypadType.PLAYSTATION
	match button_index:
		JOY_BUTTON_A:
			return SONY_PATH + "playstation_button_cross.svg" if is_ps else XBOX_PATH + "xbox_button_a.svg"
		JOY_BUTTON_B:
			return SONY_PATH + "playstation_button_circle.svg" if is_ps else XBOX_PATH + "xbox_button_b.svg"
		JOY_BUTTON_X:
			return SONY_PATH + "playstation_button_square.svg" if is_ps else XBOX_PATH + "xbox_button_x.svg"
		JOY_BUTTON_Y:
			return SONY_PATH + "playstation_button_triangle.svg" if is_ps else XBOX_PATH + "xbox_button_y.svg"
		JOY_BUTTON_LEFT_SHOULDER:
			return SONY_PATH + "playstation_trigger_l1.svg" if is_ps else XBOX_PATH + "xbox_lb.svg"
		JOY_BUTTON_RIGHT_SHOULDER:
			return SONY_PATH + "playstation_trigger_r1.svg" if is_ps else XBOX_PATH + "xbox_rb.svg"
		JOY_BUTTON_LEFT_STICK:
			return SONY_PATH + "playstation_button_l3.svg" if is_ps else XBOX_PATH + "xbox_ls.svg"
		JOY_BUTTON_RIGHT_STICK:
			return SONY_PATH + "playstation_button_r3.svg" if is_ps else XBOX_PATH + "xbox_rs.svg"
		JOY_BUTTON_BACK:
			return SONY_PATH + "playstation4_button_share.svg" if is_ps else XBOX_PATH + "xbox_button_view.svg"
		JOY_BUTTON_START:
			return SONY_PATH + "playstation4_button_options.svg" if is_ps else XBOX_PATH + "xbox_button_menu.svg"
		JOY_BUTTON_DPAD_UP:
			return SONY_PATH + "playstation_dpad_up.svg" if is_ps else XBOX_PATH + "xbox_dpad_up.svg"
		JOY_BUTTON_DPAD_DOWN:
			return SONY_PATH + "playstation_dpad_down.svg" if is_ps else XBOX_PATH + "xbox_dpad_down.svg"
		JOY_BUTTON_DPAD_LEFT:
			return SONY_PATH + "playstation_dpad_left.svg" if is_ps else XBOX_PATH + "xbox_dpad_left.svg"
		JOY_BUTTON_DPAD_RIGHT:
			return SONY_PATH + "playstation_dpad_right.svg" if is_ps else XBOX_PATH + "xbox_dpad_right.svg"
		_:
			return ""

static func _get_axis_icon(axis: int, axis_value: float, type: JoypadType) -> String:
	var is_ps = type == JoypadType.PLAYSTATION
	match axis:
		JOY_AXIS_LEFT_X:
			if is_ps:
				return SONY_PATH + ("playstation_stick_l_left.svg" if axis_value < 0 else "playstation_stick_l_right.svg")
			return XBOX_PATH + ("xbox_stick_l_left.svg" if axis_value < 0 else "xbox_stick_l_right.svg")
		JOY_AXIS_LEFT_Y:
			if is_ps:
				return SONY_PATH + ("playstation_stick_l_up.svg" if axis_value < 0 else "playstation_stick_l_down.svg")
			return XBOX_PATH + ("xbox_stick_l_up.svg" if axis_value < 0 else "xbox_stick_l_down.svg")
		JOY_AXIS_RIGHT_X:
			if is_ps:
				return SONY_PATH + ("playstation_stick_r_left.svg" if axis_value < 0 else "playstation_stick_r_right.svg")
			return XBOX_PATH + ("xbox_stick_r_left.svg" if axis_value < 0 else "xbox_stick_r_right.svg")
		JOY_AXIS_RIGHT_Y:
			if is_ps:
				return SONY_PATH + ("playstation_stick_r_up.svg" if axis_value < 0 else "playstation_stick_r_down.svg")
			return XBOX_PATH + ("xbox_stick_r_up.svg" if axis_value < 0 else "xbox_stick_r_down.svg")
		JOY_AXIS_TRIGGER_LEFT:
			return SONY_PATH + "playstation_trigger_l2.svg" if is_ps else XBOX_PATH + "xbox_lt.svg"
		JOY_AXIS_TRIGGER_RIGHT:
			return SONY_PATH + "playstation_trigger_r2.svg" if is_ps else XBOX_PATH + "xbox_rt.svg"
		_:
			return ""


static func _gamepad_event_to_text(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return "B%d" % event.button_index
	elif event is InputEventJoypadMotion:
		return "A%d" % event.axis
	return "?"
#endregion
