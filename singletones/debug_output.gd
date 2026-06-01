extends Node

@export var debug_active: bool = true


func _ready() -> void:
	if debug_active:
		debug_active = OS.is_debug_build()


func print_data(data: String):
	if !debug_active:
		return

	print(data)


func print_info(data: String):
	if !debug_active:
		return
	var time = Time.get_time_dict_from_system()

	print_rich("%02d:%02d:%02d [color=green][b][INFO][/b][/color] : %s" % [time.hour, time.minute, time.second, data])


func print_debug_unique(data: String):
	if !debug_active:
		return
	var time = Time.get_time_dict_from_system()

	print_rich("%02d:%02d:%02d [color=purple][b][DEBUG][/b][/color] : %s" % [time.hour, time.minute, time.second, data])


func print_warning(data: String):
	if !debug_active:
		return
	var time = Time.get_time_dict_from_system()

	print_rich("%02d:%02d:%02d [color=yellow][b][WARNING][/b][/color] : %s" % [time.hour, time.minute, time.second, data])


func print_error(data: String):
	if !debug_active:
		return
	var time = Time.get_time_dict_from_system()

	print_rich("%02d:%02d:%02d [color=red][b][ERROR][/b][/color] : %s" % [time.hour, time.minute, time.second, data])
