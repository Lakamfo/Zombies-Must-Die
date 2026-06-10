extends ScrollContainerMouse

@export var config_file_handler: ConfigFileHandler

@export var input_actions: Dictionary = {
	"move_forward": "KEY_SETTINGS_MOVE_FORWARD",
	"move_left": "KEY_SETTINGS_MOVE_LEFT",
	"move_backward": "KEY_SETTINGS_MOVE_BACKWARD",
	"move_right": "KEY_SETTINGS_MOVE_RIGHT",
	"jump": "KEY_SETTINGS_MOVE_JUMP",
	"crouch": "KEY_SETTINGS_MOVE_CROUCH",
	'sprint': 'KEY_SETTINGS_SPRINT',
	"melee_attack": "KEY_SETTINGS_MELEE_ATTACK",
	"reload": "KEY_SETTINGS_RELOAD",
	"interact_button": "KEY_SETTINGS_INTERACT_BUTTON",
	"flashlight": "KEY_SETTINGS_FLASHLIGHT",
	"inspect": "KEY_SETTINGS_INSPECT",
	"change_fire_mode": "KEY_SETTINGS_FIRE_MODE",
	"pause": "KEY_SETTINGS_PAUSE",
	"open_files": "KEY_SETTINGS_OPEN_FILES",
	"open_screenshots_folder": "KEY_SETTINGS_OPEN_SCREENSHOTS",
	"take_screenshot": "KEY_SETTINGS_TAKE_SCREENSHOT",
}

@onready var input_button_scene = preload("res://scenes/settings/scenes/input_remap_button.tscn")
@onready var action_list: VBoxContainer = %input_action_list

@onready var mouse_sensitivity_label: Label = %mouse_sensitivity_label
@onready var mouse_sensitivity_slider: HSlider = %mouse_sensitivity_slider

@onready var joy_vibration_button: CheckButton = %joy_vibration_button

@onready var reset_actions_bt: Button = %reset_actions_bt

var is_remapping: bool = false
var action_to_remap = null
var remaping_button: Button = null

var input_actions_translated: Dictionary

const XBOX_PATH = "res://addons/kenney-input-prompts/xbox_vector/"
const SONY_PATH = "res://addons/kenney-input-prompts/sony_vector/"

enum JoypadType { XBOX, PLAYSTATION, NINTENDO, GENERIC }


func _ready() -> void:
	super()
	
	await owner.locale_loaded

	for action in input_actions.keys():
		input_actions_translated[action] = tr(input_actions[action])

	init_keymapping()
	handle_mouse_sensitivity()
	handle_joy_vibration()

	Input.joy_connection_changed.connect(func(_device, _connected):
		_create_action_list()
	)


func init_keymapping() -> void:
	reset_actions_bt.pressed.connect(reset_actions)

	_load_keybindings_from_settings()
	_create_action_list()


func handle_joy_vibration() -> void:
	var restore_value: Dictionary = config_file_handler.config_load_filtered(
		{ 'input': { 'joy_vibration': true } }
	)
	joy_vibration_button.toggled.connect(func jvb(value : bool) -> void:
		InputSettings.joy_vibration = value
		config_file_handler.config_save({'input': { 'joy_vibration': value }})
		)
	
	joy_vibration_button.set_pressed(restore_value['input']['joy_vibration'])


func handle_mouse_sensitivity() -> void:
	var restore_value: Dictionary = config_file_handler. \
	config_load_filtered({ 'input': { 'mouse_sensitivity': 0.002 } })

	mouse_sensitivity_slider.value_changed.connect(
		func update_label(value: float):
			mouse_sensitivity_label.text = tr(&'KEY_SETTING_MOUSE_SENSITIVITY') % [(value * 100.0)]
			mouse_sensitivity_slider.accept_event()
	)
	mouse_sensitivity_slider.drag_ended.connect(
		func update(_updated: bool):
			InputSettings.mouse_sens = mouse_sensitivity_slider.value
			config_file_handler.config_save({ 'input': { 'mouse_sensitivity': InputSettings.mouse_sens } })
			EventBus.update_settings.emit()
	)

	mouse_sensitivity_slider.value = restore_value['input']['mouse_sensitivity']
	InputSettings.mouse_sens = mouse_sensitivity_slider.value


func _serialize_input_event(event: InputEvent) -> String:
	var dict = {}
	
	if event is InputEventKey:
		dict["type"] = "key"
		dict["physical_keycode"] = event.physical_keycode
		dict["alt"] = event.alt_pressed
		dict["ctrl"] = event.ctrl_pressed
		dict["shift"] = event.shift_pressed
		dict["meta"] = event.meta_pressed
	elif event is InputEventMouseButton:
		dict["type"] = "mouse"
		dict["button_index"] = event.button_index
	elif event is InputEventJoypadButton:
		dict["type"] = "joy_button"
		dict["button_index"] = event.button_index
	elif event is InputEventJoypadMotion:
		dict["type"] = "joy_axis"
		dict["axis"] = event.axis
		dict["axis_value"] = event.axis_value
	
	return JSON.stringify(dict)

func _deserialize_input_event(data_str: String) -> InputEvent:
	var dict = JSON.parse_string(data_str)
	if dict == null:
		return null
	
	match dict.get("type"):
		"key":
			var ev = InputEventKey.new()
			ev.physical_keycode = dict.get("physical_keycode", KEY_NONE)
			ev.alt_pressed = dict.get("alt", false)
			ev.ctrl_pressed = dict.get("ctrl", false)
			ev.shift_pressed = dict.get("shift", false)
			ev.meta_pressed = dict.get("meta", false)
			return ev
		"mouse":
			var ev = InputEventMouseButton.new()
			ev.button_index = dict.get("button_index", MOUSE_BUTTON_NONE)
			return ev
		"joy_button":
			var ev = InputEventJoypadButton.new()
			ev.button_index = dict.get("button_index", -1)
			return ev
		"joy_axis":
			var ev = InputEventJoypadMotion.new()
			ev.axis = dict.get("axis", -1)
			ev.axis_value = dict.get("axis_value", 0.0)
			return ev
	
	return null


func _create_action_list(reset: bool = false):
	if reset:
		InputMap.load_from_project_settings()

	for item in action_list.get_children():
		item.queue_free()

	for action in input_actions:
		var button = input_button_scene.instantiate()
		var action_label = button.find_child('action_name')

		action_label.text = input_actions[action]
		_update_action_list_from_events(button, InputMap.action_get_events(action))

		action_list.add_child(button)
		button.pressed.connect(input_button_pressed.bind(button, action))


func input_button_pressed(button, action):
	if not is_remapping:
		is_remapping = true

		action_to_remap = action
		remaping_button = button

		button.find_child("label_input").text = tr("KEY_SETTINGS_PRESS_BUTTON_TO_MAP")


func _input(event: InputEvent) -> void:
	super(event)
	if not is_remapping:
		return

	if event is InputEventJoypadMotion and abs(event.axis_value) < 0.9:
		return

	if event is InputEventKey and event.is_released():
		var is_modifier = (
			event.keycode == KEY_ALT or
			event.keycode == KEY_CTRL or
			event.keycode == KEY_SHIFT or
			event.keycode == KEY_META 
		)
		if is_modifier:
			return

		var press_event = InputEventKey.new()
		press_event.pressed = true
		press_event.physical_keycode = event.physical_keycode
		press_event.alt_pressed = event.alt_pressed
		press_event.ctrl_pressed = event.ctrl_pressed
		press_event.shift_pressed = event.shift_pressed
		press_event.meta_pressed = event.meta_pressed

		_apply_remap(press_event)
		accept_event()
		return

	if event is InputEventMouseButton and event.is_pressed() and not event.double_click:
		_apply_remap(event)
		accept_event()
		return

	if event is InputEventJoypadButton and event.is_pressed():
		_apply_remap(event)
		accept_event()
		return

	if event is InputEventJoypadMotion:
		if abs(event.axis_value) >= 0.9:
			_apply_remap(event)
			accept_event()
		return


func _apply_remap(event: InputEvent):
	var existing = InputMap.action_get_events(action_to_remap)
	for existing_event in existing:
		if _same_device_type(existing_event, event):
			InputMap.action_erase_event(action_to_remap, existing_event)

	InputMap.action_add_event(action_to_remap, event)

	save_keybinding(action_to_remap, event)

	_update_action_list(remaping_button, event)

	is_remapping = false
	action_to_remap = null
	remaping_button = null


func _same_device_type(a: InputEvent, b: InputEvent) -> bool:
	var is_kb = func(e): return e is InputEventKey || e is InputEventMouseButton
	var is_gp = func(e): return e is InputEventJoypadButton || e is InputEventJoypadMotion
	return (is_kb.call(a) && is_kb.call(b)) || (is_gp.call(a) && is_gp.call(b))


func _update_action_list(button, _event):
	var events = InputMap.action_get_events(action_to_remap)
	_update_action_list_from_events(button, events)


func _update_action_list_from_events(button, events: Array):
	var kb_label: Label = button.find_child("label_input")
	var gp_icon: TextureRect = button.find_child("label_input_gamepad")

	var kb_text := ""
	var gp_icon_path := ""

	for event in events:
		if event is InputEventKey || event is InputEventMouseButton:
			if kb_text == "":
				kb_text = InputDisplayHelper.get_event_text(event)
		elif event is InputEventJoypadButton || event is InputEventJoypadMotion:
			if gp_icon_path == "":
				gp_icon.texture = InputDisplayHelper.get_event_icon(event)

	kb_label.text = kb_text if kb_text != "" else "-"



func reset_actions():
	InputMap.load_from_project_settings()

	for action in input_actions:
		var events = InputMap.action_get_events(action)
		for event in events:
			save_keybinding(action, event)

	_create_action_list(true)


func save_keybinding(action: StringName, event: InputEvent):
	var suffix = "_kb" if (event is InputEventKey or event is InputEventMouseButton) else "_gp"
	var event_str = _serialize_input_event(event)
	if event_str != "":
		config_file_handler.config_set_value("keybinding", action + suffix, event_str)


func load_keybindings():
	var config: ConfigFile = config_file_handler.get_config_file()
	var keybindings = {}

	if not config.has_section("keybinding"):
		return keybindings

	var keys = config.get_section_keys("keybinding")
	for key in keys:
		var event_str = config.get_value("keybinding", key)
		var input_event = _deserialize_input_event(event_str)
		
		if input_event:
			var action = key.trim_suffix("_kb").trim_suffix("_gp")
			if not keybindings.has(action):
				keybindings[action] = []
			keybindings[action].append(input_event)

	return keybindings


func _load_keybindings_from_settings():
	var keybindings = load_keybindings()

	for action in keybindings.keys():
		for event in keybindings[action]:
			var existing = InputMap.action_get_events(action)
			for existing_event in existing:
				if _same_device_type(existing_event, event):
					InputMap.action_erase_event(action, existing_event)
			InputMap.action_add_event(action, event)
