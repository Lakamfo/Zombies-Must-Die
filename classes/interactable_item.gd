class_name InteractableItems
extends PhysicsBody3D


@export_multiline var interactable_text: String
@export var interact_key: String = "interact_button":
	set(value):
		interact_key = value.to_lower()
@export var hold_to_interact: bool = false
@export var enabled: bool = true

var is_focused: bool = false :
	set(value):
		is_focused = value
		focus_changed.emit(value)

var force_update_ui: bool = false

signal focus_changed(focused : bool)


func action():
	pass


func get_hit(_dmg: float = 0, _point: Vector3 = Vector3.ZERO):
	pass


func get_description() -> String:
	return interactable_text if enabled else ""

##TIP, to access the fields of the class to which the script is attached, you need to use "self" 
##TIP, if interact_key is not action, use OS.get_keycode_string()
func action_to_string() -> String:
	return InputMap.action_get_events(interact_key)[0].as_text().trim_suffix(" - Physical")


func action_to_variant() -> Variant:
	return InputDisplayHelper.get_action_icon_path(interact_key)


func get_formatted_description(description : String = interactable_text) -> String:
	var icon_path : String = action_to_variant()
	
	if icon_path != "":
		return "[center][img=24x24 valign=center]%s[/img][/center]  " %icon_path + tr(description)
	else:
		return tr(description)
