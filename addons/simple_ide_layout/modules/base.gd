## Base class for the plugins modules. Any module should be 
## independent from other modules and guarantee that it's functionality
## will be reverted once disabled.
extends Node
class_name SIL_BaseModule

## Default settings of module, goes to Editor Settings
var default_settings : Dictionary[String, Variant]

## Settings path
const SIMPLE_IDE_LAYOUT : String = "simple_ide/"

## Enable module. Start of the module lifetime
func enable() -> void:
	# Setup all the changes that the module presents
	pass

## Disable module. End of the module lifetime
func disable() -> void:
	# Revert all the changes made by the module
	pass

## Adds settings to Editor Settings
func _init_editor_settings(
	settings : Dictionary[String, Variant]
) -> void:
	
	var _editor_settings = EditorInterface.get_editor_settings()
	for key in settings.keys():
		if not _editor_settings.has_setting(key):
			_editor_settings.set_setting(key, settings[key])
		
		_editor_settings.set_initial_value(key, settings[key], false)
		_editor_settings.add_property_info({
			"name": key,
			"type": typeof(settings[key])
		})


## Remove settings from Editor Settings
func _remove_editor_settings(
	settings : Dictionary[String, Variant]
) -> void:
	
	var _editor_settings = EditorInterface.get_editor_settings()
	for key in settings.keys():
		if _editor_settings.has_setting(key):
			_editor_settings.erase(key)


## Gets settings from Editor Settings
func _get_settings(
	settings : Dictionary[String, Variant] = default_settings
) -> Dictionary:
	
	var s = EditorInterface.get_editor_settings()
	var _dictionary : Dictionary[String, Variant]
	
	for key in settings.keys():
		_dictionary[key] = s.get_setting(key)
	
	return _dictionary
