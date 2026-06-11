extends Node

## Singleton for managing input and window settings
## Responsible for mouse sensitivity, window mode, multiplayer settings

var mouse_sens: float = 0.005
var is_multiplayer: bool = false

var default_fullscreen_window_mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN
var scaling_mode: int = 0

var joy_vibration : bool = false
var joy_hints : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.use_accumulated_input = false


func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_F11 and event.is_pressed() and not event.is_echo():
			toggle_fullscreen()

		# Open user data folder
		if Input.is_action_just_pressed("open_files"):
			OS.shell_open(OS.get_user_data_dir())


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
	or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(default_fullscreen_window_mode)
