extends Node
class_name ModifiersManager

enum Modifiers {
	BaseModifier,
	LondonModifier,
	FastZombiesModifier,
	SmallZombiesOnlyModifier
}

static var modifier_registry: Dictionary = {
	Modifiers.FastZombiesModifier: {
		"script": preload("res://classes/modifiers/fast_zombies_modifier.gd"),
		"display_name": "Fast Zombies"
	},
	Modifiers.SmallZombiesOnlyModifier: {
		"script": preload("res://classes/modifiers/small_zombies_only_modifier.gd"),
		"display_name": "Small Zombies Only"
	},
	Modifiers.LondonModifier: {
		"script": preload("res://classes/modifiers/london_modifier.gd"),
		"display_name": "London Modifier"
	}
}

static var active_modifiers: Dictionary[Modifiers, BaseModifier] = {}


static func create_modifier(modifier: Modifiers) -> BaseModifier:
	var definition : Dictionary = modifier_registry.get(modifier, null)
	if definition:
		return definition["script"].new()
	push_warning("Unknown modifier: %s" % modifier)
	return null


static func get_modifier_name(modifier: Modifiers) -> String:
	var definition : Dictionary = modifier_registry.get(modifier, null)
	if definition:
		return definition["display_name"]
	return "Unknown"


static func clear_active_modifiers() -> void:
	active_modifiers.clear()


static func add_active_modifier(modifier: Modifiers, instance: BaseModifier) -> void:
	if instance:
		active_modifiers[modifier] = instance


static func trigger_event(event_name: StringName, data: Dictionary = {}) -> void:
	for modifier in active_modifiers.values():
		modifier.apply(event_name, data)
