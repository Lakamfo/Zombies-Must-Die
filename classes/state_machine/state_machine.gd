class_name StateMachine
extends Node

@export var CURRENT_STATE: State
var states: Dictionary


func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.transition.connect(on_child_transition)
		else:
			DebugOutput.print_info("State machine contains non State classes")
	CURRENT_STATE.enter(CURRENT_STATE)


func _process(delta: float) -> void:
	CURRENT_STATE.update(delta)


func _physics_process(delta: float) -> void:
	CURRENT_STATE.physics_update(delta)


func on_child_transition(new_state_name: StringName) -> void:
	var new_state = states.get(new_state_name)
	if new_state != null:
		if new_state != CURRENT_STATE:
			CURRENT_STATE.exit(new_state)
			new_state.enter(CURRENT_STATE)
			CURRENT_STATE = new_state
	else:
		DebugOutput.print_info("State : %s doesn`t exist" % new_state_name)
