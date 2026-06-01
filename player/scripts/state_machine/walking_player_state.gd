extends PlayerMovementState

class_name WalkingPlayerState

@export var SPEED: float = 4.5
@export var acceleration: float = 0.1
@export var deceleration: float = 0.05


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
		transition.emit("running_player_state")
		return

	if PLAYER.velocity.length() < 0.1:
		transition.emit("idle_player_state")
		return

	if Input.is_action_pressed("crouch") and PLAYER.is_on_floor():
		transition.emit("crouching_player_state")
		return
