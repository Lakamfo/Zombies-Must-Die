extends Node

#==== WEAPON STUFF ====#
signal weapon_recoil(camera_kick: Vector3, snappines: float, return_speed: float)
signal weapon_fired(weapon : Weapon)

signal weapon_recoil_camera_vector(camera_kick: Vector3, snappines: Vector3, return_speed: Vector3)
signal weapon_recoil_body_vector(body_kick: Vector3, snappines: Vector3, return_speed: Vector3)

signal weapon_manual_spread(rand_rot: Vector3)
signal weapon_camera_fov_changed(fov : float)
signal weapon_aim(magnifying: float, weapon_camera_magnifying : float, aim_speed: float, in_scope: bool, transition: Tween.TransitionType, ease_in : Tween.EaseType)
signal weapon_scope_state_changed(in_scope : bool)
signal weapon_reload(is_reloading: bool)
signal weapon_hitted(hit_color: Color)
signal weapon_fire_mode_changed(fire_mode: int)
signal melee_attack()

signal weapon_add_ammo(ammount: int)

#==== WEAPON STUFF UI RELATED ====#
signal weapon_remove_ui(weapon_index: int)
signal weapon_active(weapon_index: int)
signal weapon_active_object(weapon : Weapon)
signal weapon_add_ui(texture: CompressedTexture2D)
signal weapon_added_ui(weapon_index: int, ui_element: Control)

#==== SETTINGS ====#
signal mouse_speed_changed(mouse_speed: float)
signal update_settings

#==== WAVE LOGIC ====#
signal game_enemy_killed
signal enemy_spawned(enemy: Node)

signal delete_spawn_positions(arr: Array[Node])
signal add_spawn_positions(arr: Array[Node])
signal delete_all_spawn_positions

signal wave_ended(wave: int)
signal wave_started(wave: int)

#==== PLAYER EVENTS ====#
signal add_score(line: String, score: int)
signal player_changed_health(health: float, old_health: float)
signal player_die
signal player_laying_down
signal player_revived()
signal player_stamina_changed(value : float)
signal player_stamina_changed_remaped(value : float)

signal player_added_status_effect(status : StatusEffect.StatusType)
signal player_removed_status_effect(status : StatusEffect.StatusType)

#==== UI EVENTS ====#
signal ui_player_state(active : bool)
signal ui_update_crosshair(visible: bool)
signal ui_update_score(score: int)
signal ui_update_interactable(description: String)

signal ui_message(message: String, lifetime : float, params : Array)

signal ui_update_wave(wave: int)
signal ui_update_difficulty(difficulty: float)

signal ui_add_time_bonus(text: String, time: int)

#==== GAME OTHER ====#
signal game_electricity_turn(enabled : bool)

#==== GAME POWER UPS ====#
signal bonus_activated(bonus_id: StringName, stacks: int)
signal bonus_refreshed(bonus_id: StringName)
signal bonus_deactivated(bonus_id: StringName)
signal bonus_purchased(bonus_id: StringName, price: int)
signal bonus_time_updated(bonus_id: StringName, time_left: float)

# deprecated,use bonus_activated
signal bonus_double_points
signal bonus_instant_kill
signal bonus_double_points_expired
signal bonus_instant_kill_expired

signal bonus_full_repair
signal bonus_nuke_all
signal bonus_full_ammo

signal bonus_juggernog
signal bonus_quick_revive
signal bonus_speed_cola
signal bonus_double_tap

# deprecated,use bonus_activated
signal bonus_collected(what: BonusDefinition)
signal pickup_collected(what: int)

#==== SCENE MANAGER ====#
signal scene_changed
signal scene_loaded

#==== NAV MESH ====#
signal update_navigation_mesh

#==== MAP GEN ====#
signal player_entered_room(id: int, battle_area: bool)
signal player_exited_room(id: int, battle_area: bool)
signal player_entered_new_battle_room(id: int)
signal player_entered_new_room(id: int)
