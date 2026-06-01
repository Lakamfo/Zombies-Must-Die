class_name CrouchingPlayerState
extends PlayerMovementState

@export var SPEED = 2.5
@export var acceleration: float = 0.1
@export var deceleration: float = 0.05
@export_range(1, 6, 0.1) var CROUCH_SPEED: float = 4.0
@onready var CROUCH_SHAPECAST = %celling_check_shape_cast_3d
@export var crouch_sfx: AudioStreamPlayer3D 

var CHECK_PERIOD: float = 0.1

const CROUCH_IN = preload("res://sounds/sfx/crouch_in.mp3")
const CROUCH_OUT = preload("res://sounds/sfx/crouch_out.mp3")


func physics_update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED)
	PLAYER.update_velocity()

	if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
		#ANIMATION.play("crouch", -1.0, -CROUCH_SPEED * 2)
		#transition.emit("jumping_player_state")
		#uncrouch()
		pass

	if not Input.is_action_pressed("crouch"):
		uncrouch()


func enter(_previous_state: State):
	ANIMATION.play("crouch", -1.0, CROUCH_SPEED)
	if not crouch_sfx.playing:
		crouch_sfx.stream = CROUCH_IN
		crouch_sfx.play()


func uncrouch():
	if not CROUCH_SHAPECAST.is_colliding() and not Input.is_action_pressed("crouch"):
		ANIMATION.play("crouch", -1.0, -CROUCH_SPEED * 1.5, true)
		if ANIMATION.is_playing():
			if not crouch_sfx.playing:
				crouch_sfx.stream = CROUCH_OUT
				crouch_sfx.play()
			await ANIMATION.animation_finished
			transition.emit("idle_player_state")
	elif CROUCH_SHAPECAST.is_colliding():
		await get_tree().create_timer(CHECK_PERIOD, false).timeout
		uncrouch()
