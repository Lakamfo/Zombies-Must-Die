extends Node

class_name SettingsUtils

static func is_mobile_device() -> bool:
	return OS.has_feature("mobile")


static func get_screen_size_inches() -> float:
	var screen_res: Vector2i = DisplayServer.screen_get_size()
	var dpi: float = DisplayServer.screen_get_dpi()

	if is_mobile_device():
		dpi -= 100

	if dpi <= 0:
		dpi = 96.0 #Default PC DPI

	return sqrt(pow(screen_res.x, 2) + pow(screen_res.y, 2)) / dpi
