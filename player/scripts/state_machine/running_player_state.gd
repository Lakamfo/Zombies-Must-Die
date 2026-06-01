class_name RunningPlayerState
extends PlayerMovementState

@export var SPEED: float = 6.0
@export var acceleration: float = 0.1
@export var deceleration: float = 0.02
@export var stamina_drain : float = 1.0

func physics_update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, acceleration, deceleration)
	PLAYER.update_velocity()
	
	if PLAYER.velocity.y < 0:
		transition.emit("falling_player_state")
		return

	if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
		transition.emit("jumping_player_state")
		return
	
	if can_run():
		PLAYER.stamina_component.try_use(stamina_drain * delta)
	else:
		transition.emit("walking_player_state")
		return
	
	if Input.is_action_pressed("crouch") and PLAYER.is_on_floor():
		transition.emit("crouching_player_state")
		return
