class_name StatusEffect
extends RefCounted

enum StatusType {
	PANIC,
	FATIGUE,
	INFECTION,
	STUN
}

var type : StatusType = StatusType.PANIC 
var duration : float = 10.0
var intensity : float = 1.0

func apply(_player : Player) -> void:
	pass

func remove(_player : Player) -> void:
	pass

func update(_player : Player, _delta : float) -> void:
	pass

func get_modifiers() -> Dictionary[StringName, float]:
	return {}
