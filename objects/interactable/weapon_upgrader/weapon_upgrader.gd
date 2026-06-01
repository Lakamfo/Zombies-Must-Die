extends InteractableItems

@export var base_upgrade_cost: int = 25000
@export var animation_player : AnimationPlayer


func _ready() -> void:
	Global.weapon_manager.weapon_changed.connect(func(): force_update_ui = true)


func action():
	var current_weapon: Weapon = Global.weapon_manager.get_current_weapon()
	if current_weapon != null:
		if current_weapon.weapon_stats.weapon_stats_upgrade == null:
			return
		var upgrade_cost : int = base_upgrade_cost * get_weapon_next_level()
		
		if Global.player.score > upgrade_cost:
			EventBus.add_score.emit(tr(&"KEY_OBJECT_PACKAPUNCH_MESSAGE") %[current_weapon.weapon_name.to_upper()], -upgrade_cost) 
			if animation_player:
				animation_player.play(&"use")
			apply_upgrade(current_weapon)


func apply_upgrade(weapon: Weapon):
	weapon.weapon_stats = weapon.weapon_stats.weapon_stats_upgrade


func get_weapon_next_level() -> int:
	var current_weapon: Weapon = Global.weapon_manager.get_current_weapon()
	return current_weapon.weapon_stats.upgrade_level + 1


func get_description() -> String:
	var current_weapon: Weapon = Global.weapon_manager.get_current_weapon()
	if current_weapon != null:
		if not current_weapon.weapon_stats.weapon_stats_upgrade:
			return tr("KEY_OBJECT_PACKAPUNCH_MAX_LVL")
		return (get_formatted_description(&"KEY_OBJECT_PACKAPUNCH_USE") %[base_upgrade_cost * get_weapon_next_level()])
	return ""
