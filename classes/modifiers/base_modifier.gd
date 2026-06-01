#"res://classes/modifiers/base_modifier.gd"
extends RefCounted
class_name BaseModifier

var modifier_name : StringName = &"Base"

func apply(_event_name: StringName, _data: Dictionary) -> void:
	pass
