class_name GamePadHintsGun
extends PanelContainer

@onready var accp_fire = $margin_container/v_box_container/accp_fire
@onready var accp_aim = $margin_container/v_box_container/accp_aim
@onready var accp_reload = $margin_container/v_box_container/accp_reload

func _input(event: InputEvent) -> void:
	if not Global.gamepad_connected:
		visible = false
		return
	
	if event.is_action_pressed("mouse_2"):
		accp_fire.hide()
	if event.is_action_pressed("mouse_1"):
		accp_aim.hide()
		
	# Context hint: if empty ammo
	if Global.player.weapon_manager.get_current_weapon() != null:
		accp_reload.visible = Global.player.weapon_manager.get_current_weapon().clip == 0
