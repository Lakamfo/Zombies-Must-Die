#"res://classes/map_gen/RoomsTrigger.gd"
extends Area3D

class_name RoomTrigger

var id: int = -1
@export var battle_area: bool = false


func _init() -> void:
	#Disable world layer
	set_collision_layer_value(1, false)
	set_collision_layer_value(1, false)
	#Enable player layer
	set_collision_layer_value(5, true)
	set_collision_mask_value(5, true)


func _ready() -> void:
	id = owner.get_meta('id', -1)
	body_entered.connect(_body_entered)
	body_exited.connect(_body_exited)


func _body_entered(body: Node3D) -> void:
	if body is Player:
		EventBus.player_entered_room.emit(id, battle_area)


func _body_exited(body: Node3D) -> void:
	if body is Player:
		EventBus.player_exited_room.emit(id, battle_area)
