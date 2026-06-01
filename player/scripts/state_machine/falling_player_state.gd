extends PlayerMovementState

class_name FallingPlayerState

@export var SPEED: float = 6.0
@export var acceleration: float = 0.02
@export var deceleration: float = 0.02

var player_top_position: Vector3

@export var min_speed_damage: float = 8.0
@export var fall_damage_curve: Curve
@export var fatal_damage_speed: float = 30

@export var fall_damage_sfx: AudioStreamPlayer3D 

var fall_speed: float = 0.0


func physics_update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, acceleration, deceleration)
	PLAYER.update_velocity()

	if PLAYER.is_on_floor():
		transition.emit("idle_player_state")

		if fall_speed > min_speed_damage:
			var final_damage = (fall_damage_curve.sample(fall_speed / fatal_damage_speed) * PLAYER.max_health) + 1
			PLAYER.get_hit(final_damage)
			fall_damage_sfx.play()
	else:
		fall_speed = -1 * PLAYER.velocity.y


func exit(_next_state: State):
	FOOTSTEPS.force_play()
