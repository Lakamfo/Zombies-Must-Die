#"res://classes/map_gen/room_template.gd"
@tool
extends Resource

class_name RoomTemplate

@export var scene: PackedScene
@export_range(1.0, 10.0, 0.1) var weight = 1.0

@export var type : Types = Types.ROOM
enum Types{START_ROOM, ROOM, HALLWAY, SHOP, END}

func get_type() -> String:
	return Types.keys()[type]
