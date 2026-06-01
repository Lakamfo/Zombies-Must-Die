extends State

class_name PlayerMovementState

var PLAYER: Player
var ANIMATION: AnimationPlayer
var FOOTSTEPS: AudioStreamPlayer3D


func _ready() -> void:
	await owner.ready
	PLAYER = owner as Player
	ANIMATION = PLAYER.animation_player
	FOOTSTEPS = PLAYER.footsteps_module

func can_run() -> bool:
	return Input.is_action_pressed("sprint") \
		and PLAYER.stamina_component.is_stamina_zero() \
		and PLAYER.is_on_floor() \
		and not Global.weapon_manager.is_aiming
