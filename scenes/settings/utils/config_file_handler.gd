extends Node

class_name ConfigFileHandler

@export var config_name: String = "settings"
@export var config_extension: String = "ini"
@onready var file_path: String = "user://" + config_name + "." + config_extension

var _config: ConfigFile = ConfigFile.new()


func get_config_file() -> ConfigFile:
	config_load({ })
	return _config


func config_load(data: Dictionary, path: String = "") -> Dictionary:
	if path.is_empty():
		path = file_path

	var err := _config.load(path)

	if err == ERR_DOES_NOT_EXIST:
		for section in data.keys():
			for parameter in data[section].keys():
				_config.set_value(section, parameter, data[section][parameter])
		_config.save(path)
		return data

	if err != OK:
		push_warning("Failed to load config file: %s (Error: %d)" % [path, err])
		return data

	for section in _config.get_sections():
		if not data.has(section):
			data[section] = { }
		for parameter in _config.get_section_keys(section):
			data[section][parameter] = _config.get_value(section, parameter)

	return data


func config_load_filtered(_data: Dictionary, path: String = "") -> Dictionary:
	if path.is_empty():
		path = file_path
	var data: Dictionary = _data.duplicate(true)

	var err := _config.load(path)

	if err == ERR_DOES_NOT_EXIST:
		for section in data.keys():
			for parameter in data[section].keys():
				_config.set_value(section, parameter, data[section][parameter])
		_config.save(path)
		return data

	if err != OK:
		push_warning("Failed to load config file: %s (Error: %d)" % [path, err])
		return data

	for section in data.keys():
		if not _config.has_section(section):
			continue
		for parameter in data[section].keys():
			if _config.has_section_key(section, parameter):
				data[section][parameter] = _config.get_value(section, parameter)

	return data


func config_set_value(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
	config_update_file()


func config_save(source: Dictionary, path: String = file_path) -> void:
	if path.is_empty():
		path = file_path

	for section in source.keys():
		for key in source[section].keys():
			_config.set_value(section, key, source[section][key])

	var err := _config.save(path)
	if err != OK:
		push_warning("Failed to save config file: %s (Error: %d)" % [path, err])


func config_update_file(path: String = "") -> void:
	if path.is_empty():
		path = file_path

	var err := _config.save(path)
	if err != OK:
		push_warning("Failed to update config file: %s (Error: %d)" % [path, err])
