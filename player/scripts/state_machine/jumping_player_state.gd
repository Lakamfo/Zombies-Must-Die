extends PlayerMovementState
class_name JumpingPlayerState

@export var SPEED: float = 6.0
@export var acceleration: float = 0.02
@export var deceleration: float = 0.02
@export var stamina_drain : float = 1.5

@export var JUMP_VELOCITY: float = 4.5
@export_range(1, 2, 0.1) var INPUT_MULTIPLIER: float = 1.5


func enter(_previous_state: State):
	if not PLAYER.can_jump:
		transition.emit("walking_player_state")
		return
	if not PLAYER.stamina_component.try_use(stamina_drain):
		return
	
	PLAYER.velocity.y += JUMP_VELOCITY
	PLAYER.camera_jump_animation()
	PLAYER.direction *= INPUT_MULTIPLIER
	
	
	FOOTSTEPS.force_play()


func physics_update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, acceleration, deceleration)
	PLAYER.update_velocity()

	if PLAYER.velocity.y < 0:
		transition.emit("falling_player_state")

	if PLAYER.is_on_floor():
		transition.emit("idle_player_state")
