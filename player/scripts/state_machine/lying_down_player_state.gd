class_name LyingDownPlayerState
extends PlayerMovementState

@export_range(50, 200, 1.0) var PLAYER_HEALTH: float = 200.0
@export_range(1, 6, 0.1) var LAY_SPEED: float = 4.0

var timer: float = 0.0
var revive_timer: float = 0.0
var player_default_health: float = 0


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pass


func _ready() -> void:
	super()
	EventBus.player_laying_down.connect(
		func change_state():
			transition.emit("lying_down_player_state")
	)


func enter(_previous_state: State):
	ANIMATION.play("lay_down", -1.0, LAY_SPEED)
	player_default_health = PLAYER.max_health

	PLAYER.max_health = PLAYER_HEALTH * 2
	PLAYER.health = PLAYER_HEALTH
	PLAYER.is_laying_down = true

	PLAYER.velocity = Vector3.ZERO

	timer = 0
	
	if not InputSettings.is_multiplayer and PLAYER.quick_revive_active:
		EventBus.ui_message.emit(tr(&"KEY_PLAYER_REVIVING"), PLAYER.time_to_revive / 2)


func exit(_next_state: State):
	PLAYER.is_laying_down = false
	PLAYER.max_health = player_default_health
	PLAYER.health = player_default_health / 2

	ANIMATION.play("RESET")


func physics_update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_velocity()
	revive_player(delta)
	timer += delta

	if timer >= 1:
		PLAYER.health -= 1
		timer = 0.0


func revive_player(delta: float) -> void:
	if not InputSettings.is_multiplayer and PLAYER.quick_revive_active:
		revive_timer += delta

		if (revive_timer) > PLAYER.time_to_revive / 2:
			revive_timer = 0.0

			EventBus.player_revived.emit()
			transition.emit("idle_player_state")
	else:
		return
