extends PlayerMovementState

class_name IdlePlayerState

@export var SPEED: float = 5.0
@export var acceleration: float = 0.1
@export var deceleration: float = 0.05


func physics_update(delta: float):
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, acceleration, deceleration)
	PLAYER.update_velocity()

	if PLAYER.velocity.y < 0:
		transition.emit("falling_player_state")

	if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
		transition.emit("jumping_player_state")

	if Input.is_action_pressed("crouch") and PLAYER.is_on_floor():
		transition.emit("crouching_player_state")

	if PLAYER.velocity.length() > 0.1 and PLAYER.is_on_floor():
		transition.emit("walking_player_state")
