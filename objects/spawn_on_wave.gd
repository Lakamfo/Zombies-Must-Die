extends Node3D
class_name SpawnOnWave

@export var wave : int = 10
@export var object : PackedScene
@export_category("Message")
@export var print_message : bool = false
@export var message : String
@export var message_lifetime : float = 2.0

func _ready() -> void:
	EventBus.wave_started.connect(_wave_started)


func _wave_started(current_wave : int) -> void:
	if not current_wave == wave:
		return
	
	var obj : Node3D = object.instantiate()
	add_child(obj)
	
	if print_message:
		EventBus.ui_message.emit(tr(message), message_lifetime)
