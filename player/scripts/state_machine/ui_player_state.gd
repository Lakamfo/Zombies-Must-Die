extends PlayerMovementState
class_name UiPlayerState

var previous_state : State

func _ready() -> void:
	super()
	
	EventBus.ui_player_state.connect(_update_state)


func _update_state(value : bool) -> void:
	if value:
		transition.emit("ui_player_state")
	else:
		if previous_state:
			transition.emit(previous_state.name)
		else:
			transition.emit("idle_player_state")


func enter(_previous_state: State) -> void:
	previous_state = _previous_state
	PLAYER.velocity = Vector3.ZERO
	PLAYER.can_move = false
	MouseManager.lock(&"ui_state")

func exit(_next_state: State) -> void:
	PLAYER.can_move = true
	MouseManager.unlock(&"ui_state")


func _exit_tree() -> void:
	MouseManager.unlock(&"ui_state")
