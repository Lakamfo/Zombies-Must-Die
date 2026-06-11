class_name GamePadHintsGun
extends PanelContainer

@onready var hints := {
	&"fire":    $margin_container/v_box_container/accp_fire,
	&"aim":     $margin_container/v_box_container/accp_aim,
	&"reload":  $margin_container/v_box_container/accp_reload,
	&"prev":    $margin_container/v_box_container/accp_prev,
	&"next":    $margin_container/v_box_container/accp_next,
	&"mattack": $margin_container/v_box_container/accp_mattack,
}

var action_map := {
	&"mouse_1":          &"fire",
	&"mouse_2":          &"aim",
	&"melee_attack":     &"mattack",
	&"swap_weapon_left": &"prev",
	&"swap_weapon_right":&"next",
}

func _ready() -> void:
	EventBus.update_settings.connect(_settings_updated)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	EventBus.weapon_fired.connect(_on_weapon_changed)
	EventBus.weapon_clip_changed.connect(_on_clip_changed)
	EventBus.weapon_active_object.connect(_on_weapon_changed)
	EventBus.weapon_inventory_update.connect(_on_inventory_changed)
	
	_settings_updated()


func _refresh_hints_state() -> void:
	if not Global.first_hint_counter:
		var gamepad_connected = not Input.get_connected_joypads().is_empty()
		for key in [&"fire", &"aim", &"mattack"]:
			hints[key].visible = gamepad_connected
	else:
		for hint in hints.values():
			hint.visible = false


func _update_panel_visibility() -> void:
	if not InputSettings.joy_hints or Input.get_connected_joypads().is_empty():
		visible = false
		return
	
	visible = hints.values().any(func(h): return h.visible)


func _settings_updated() -> void:
	_refresh_hints_state()
	_update_panel_visibility()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_hints_state()
	_update_panel_visibility()


func _on_clip_changed(amount: int) -> void:
	hints[&"reload"].visible = (amount == 0)
	_update_panel_visibility()



func _on_weapon_changed(weapon) -> void:
	hints[&"reload"].visible = (weapon != null and weapon.clip == 0)
	_update_panel_visibility()



func _on_inventory_changed(weapons_list: Array) -> void:
	var show_switch = weapons_list.size() > 1
	hints[&"prev"].visible = show_switch
	hints[&"next"].visible = show_switch
	_update_panel_visibility()



func _input(event: InputEvent) -> void:
	if not InputSettings.joy_hints:
		return
	if not event is InputEventJoypadButton or not event.is_pressed():
		return
	
	var changed := false
	for action in action_map.keys():
		if event.is_action(action):
			if _hide_hint(action_map[action]):
				changed = true
	
	if changed:
		_update_panel_visibility()


func _hide_hint(key: StringName) -> bool:
	var hint = hints.get(key)
	if hint and hint.visible:
		hint.hide()
		return true
	return false
