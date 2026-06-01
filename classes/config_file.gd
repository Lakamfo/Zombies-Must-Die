extends Node

class_name old_config_file_handler

var config_file = ConfigFile.new()

@export var config_name = "game_config"
@export var config_extension = "ini"
@onready var file_path = OS.get_user_data_dir() + "/" + config_name + "." + config_extension

var standart_config: Dictionary = {
	"display_settings": {
		"display_monitor": 0,
		"display_mode": 0,
		"scaling_mode": 0,
		"render_resolution": 50,
		"fsr_sharpness": 0.2,
		"custom_framerate": 0,
		"vsync": true,
	},
	"graphics_settings": {
		"ssao": 0,
		"msaa": 0,
		"taa": false,
		"glow": false,
		"sdfgi": false,
		"ssr": false,
		"decals": false,
		"fxaa": false,
		"ssil": false,
		"volumetric_fog": false,
		"shaders_quality": 1,
	},
	"volume_settings": {
		"master_volume": 1,
		"weapon_volume": 1,
		"music_volume": 1,
		"sfx_volume": 1,
	},
	"input": {
		"mouse_speed": 0.0005,
	},
	"keybinding": {
		"move_forward": "W",
	},
}


func config_load(path: String = file_path):
	config_file = ConfigFile.new()
	var data = standart_config

	config_file.load(path)

	for section in config_file.get_sections():
		for parameter in config_file.get_section_keys(section):
			data[section][parameter] = config_file.get_value(section, parameter)

	return data


func config_update_file(path: String = file_path):
	config_file.load(path)


func config_save(settings: Dictionary = standart_config, path: String = file_path):
	config_file = ConfigFile.new()

	for section in settings.keys():
		for parameter in settings.get(section):
			config_file.set_value(section, parameter, settings.get(section).get(parameter))

	config_file.save(path)


func get_config_file() -> ConfigFile:
	return config_file
