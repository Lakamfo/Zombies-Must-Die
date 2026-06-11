class_name GamePadHints
extends PanelContainer

@export var show_always_with_gamepad : bool = false

func _ready() -> void:
	EventBus.update_settings.connect(_settings_updated)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	_update_visibility()


func _update_visibility() -> void:
	var joy_hints_enabled = InputSettings.joy_hints  
	var gamepad_connected = not Input.get_connected_joypads().is_empty()
	
	visible = (joy_hints_enabled or show_always_with_gamepad) and gamepad_connected


func _settings_updated() -> void:
	_update_visibility()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_visibility()
