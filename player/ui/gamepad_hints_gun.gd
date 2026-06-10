class_name GamePadHintsGun
extends PanelContainer

@onready var accp_fire = $margin_container/v_box_container/accp_fire
@onready var accp_aim = $margin_container/v_box_container/accp_aim
@onready var accp_reload = $margin_container/v_box_container/accp_reload
@onready var accp_prev = $margin_container/v_box_container/accp_prev
@onready var accp_next = $margin_container/v_box_container/accp_next
@onready var accp_mattack = $margin_container/v_box_container/accp_mattack

func _ready() -> void:
	if not Global.first_hint_counter:
		accp_fire.hide()
		accp_aim.hide()
		accp_mattack.hide()
		hide()

func _input(event: InputEvent) -> void:
	if not Global.gamepad_connected:
		visible = false
		return
	
	if event.is_action_pressed("mouse_1"):
		accp_fire.hide()
	if event.is_action_pressed("mouse_2"):
		accp_aim.hide()
	if event.is_action_pressed("melee_attack"):
		accp_mattack.hide()
		
	# Context hint: if empty ammo
	if Global.player.weapon_manager.get_current_weapon() != null:
		accp_reload.visible = Global.player.weapon_manager.get_current_weapon().clip == 0
		
	if Global.player.weapon_manager.inventory_weapons_list.size() > 1:
		accp_prev.show()
		accp_next.show()

	visible = !( !accp_fire.visible and !accp_aim.visible and !accp_reload.visible and !accp_prev.visible and !accp_next.visible and !accp_mattack.visible)
