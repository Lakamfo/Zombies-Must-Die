extends Node3D

class_name Hitbox

enum Type { Head, Torso, Limb }
@export var type = Type.Head
@export var set_material : bool = true

func _ready() -> void:
	#add_to_group("dynamic_object")
	if set_material:
		set_meta(&"material", &"FLESH")


func get_hit(dmg: float = 0.0, _position: Vector3 = Vector3.ZERO):
	owner.get_hit(dmg, _position, type)
