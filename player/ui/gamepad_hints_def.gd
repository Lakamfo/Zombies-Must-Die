class_name GamePadHintsDef
extends PanelContainer

@onready var accp_move = $margin_container/v_box_container/accp_move
@onready var accp_look = $margin_container/v_box_container/accp_look
@onready var accp_jump = $margin_container/v_box_container/accp_jump
@onready var accp_crouch = $margin_container/v_box_container/accp_crouch
@onready var accp_use = $margin_container/v_box_container/accp_use
@onready var accp_light = $margin_container/v_box_container/accp_light

func _ready() -> void:
	EventBus.ui_update_interactable.connect(func(desc:String): accp_use.visible = desc != "")
	
	if not Global.first_hint_counter:
		accp_move.hide()
		accp_look.hide()
		accp_jump.hide()
		accp_crouch.hide()
		accp_light.hide()
		hide()

func _input(event: InputEvent) -> void:
	if not Global.gamepad_connected:
		visible = false
		return
	
	if 	event.is_action_pressed("move_forward") or \
		event.is_action_pressed("move_backward") or \
		event.is_action_pressed("move_left") or \
		event.is_action_pressed("move_right"):
		accp_move.hide()
	if 	event.is_action_pressed("rot_cam_left") or \
		event.is_action_pressed("rot_cam_right") or \
		event.is_action_pressed("rot_cam_up") or \
		event.is_action_pressed("rot_cam_down"):
		accp_look.hide()
	if event.is_action_pressed("jump"):
		accp_jump.hide()
	if event.is_action_pressed("crouch"):
		accp_crouch.hide()
	if event.is_action_pressed("flashlight"):
		accp_light.hide()
		
	visible = !( !accp_move.visible and !accp_jump.visible and !accp_crouch.visible and !accp_look.visible and !accp_use.visible and !accp_light.visible)
