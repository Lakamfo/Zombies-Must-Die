extends Node3D

@export var trap_activator: ElectricTrapActivator

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if trap_activator is ElectricTrapActivator:
		trap_activator.started.connect(
			func():
				animation_player.play("Po_Bo|Level_Down")
		)
		trap_activator.ended.connect(
			func():
				animation_player.play_backwards("Po_Bo|Level_Down")
		)
