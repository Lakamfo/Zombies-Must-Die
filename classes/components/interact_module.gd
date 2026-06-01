extends Node

@export var enabled: bool = true:
	set(value):
		if not value:
			process_mode = Node.PROCESS_MODE_DISABLED
		else:
			process_mode = Node.PROCESS_MODE_INHERIT

@export var interact_raycast: RayCast3D
var previous_interactable_object: PhysicsBody3D
var previous_interact_key: String = "f"


func _ready() -> void:
	interact_raycast.add_exception(get_owner())

	if not enabled:
		process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(_delta: float) -> void:
	interactlabe_items()


func interactlabe_items() -> void:
	var collider = interact_raycast.get_collider()

	if (collider is InteractableItems) and previous_interactable_object != collider:
		previous_interactable_object = collider
		previous_interact_key = collider.interact_key

		collider.is_focused = true
		EventBus.emit_signal("ui_update_interactable", collider.get_description())
	elif !(collider is InteractableItems):
		if previous_interactable_object:
			if is_instance_valid(previous_interactable_object):
				previous_interactable_object.is_focused = false

		previous_interactable_object = null
		EventBus.emit_signal("ui_update_interactable", "")
	if (collider is InteractableItems):
		if collider.force_update_ui:
			EventBus.emit_signal("ui_update_interactable", collider.get_description())
			collider.force_update_ui = false

	if previous_interactable_object:
		if previous_interactable_object.hold_to_interact:
			if Input.is_action_pressed(previous_interact_key):
				previous_interactable_object.action()

				EventBus.emit_signal("ui_update_interactable", collider.get_description())
		else:
			if Input.is_action_just_pressed(previous_interact_key):
				previous_interactable_object.action()

				EventBus.emit_signal("ui_update_interactable", collider.get_description())
