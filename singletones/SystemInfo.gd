extends Node

## Singleton for system information
## Contains read-only data about OS, device and performance

#region System Information
@onready var device_os: String = OS.get_name()
var has_touch_screen: bool = DisplayServer.is_touchscreen_available()
var screen_size: Vector2i = DisplayServer.screen_get_size()
var window: Window = get_window()
#endregion

#region Frame Timing
var fixed_delta_procces: float = 0.0166666667
var fixed_delta_physics_process: float = 0.0166666667
#endregion

#region Game Launch State
var game_launch_state: bool = true
#endregion


func _process(delta: float) -> void:
	fixed_delta_procces = min(delta, 0.0166666667)


func _physics_process(delta: float) -> void:
	fixed_delta_physics_process = min(delta, 0.0166666667)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	await get_tree().process_frame
	game_launch_state = false
