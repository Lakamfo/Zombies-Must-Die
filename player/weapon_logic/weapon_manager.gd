class_name WeaponManager
extends Node3D

#region Signals
signal weapon_changed
#endregion

#region Exports
@export var scope_audio_stream_player: AudioStreamPlayer3D
@export var max_weapons_in_inventory: int = 2
@export var double_tap_multiplier: float = 1.2

@export_group("Melee")
@export var melee_damage: float = 20
@export var melee_cooldown: float = 2

@export_group("Other")
@export var aim_speed: float = 1.0
#endregion

#region Variables
var active_weapon: int = 0
var is_reloading: bool = false
var is_doubletap_active: bool = false
var is_haste: bool = false
var is_manual_raycast_control: bool = false
var is_melee_active: bool = false

var is_aiming: bool = false:
	set(value):
		is_aiming = value
		_handle_aim_audio(value)

var recoil_system: RecoilApplier 

var _melee_timer: Timer = Timer.new()
var _tween: Tween

const WEAPON_REGISTRY: Dictionary = {
	0: ["MP5SD", "res://player/weapons/in_game/mp5sd/mp5sd.tscn"],
	1: ["FSP45", "res://player/weapons/in_game/fsp45/fsp_45.tscn"],
	2: ["M4A1", "res://player/weapons/in_game/m4a1/m4a1_scripted.tscn"],
	3: ["M680", "res://player/weapons/in_game/model680/model_680.tscn"],
	4: ["MK14", "res://player/weapons/in_game/mk14/mk14.tscn"],
	5: ["REVOLVER_6", "res://player/weapons/in_game/revolver_6/revolver_6.tscn"],
	6: ["SG552", "res://player/weapons/in_game/sg552/sg552_scene.tscn"]
}
var inventory_weapons_list: Array[Weapon] = []

const SOUND_SCOPE_IN = preload("res://player/weapons/sounds/scope_in.mp3")
const SOUND_SCOPE_OUT = preload("res://player/weapons/sounds/scope_out.mp3")
#endregion

#region Onready variables
@onready var weapon_ray_cast_3d: RayCast3D = %weapon_ray_cast_3d
@onready var melee_zone: Area3D = $melee_zone
@onready var knife: FPSAnimation = $knife
@onready var can_animated: FPSAnimation = $can_animated
@onready var player: Player = get_owner()
#endregion

#region Lifecycle methods
func _ready() -> void:
	_connect_events()
	_setup_melee_timer()
	
	weapon_ray_cast_3d.add_exception(get_owner())
	Global.weapon_manager = self


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not is_melee_active:
		_handle_wheel_input(event)


func _process(_delta: float) -> void:
	if is_melee_active:
		return

	_handle_keyboard_swap()


func _physics_process(_delta: float) -> void:
	_handle_melee_input()
	_handle_numeric_input()
#endregion

#region Public methods
func add_weapon(weapon_id: int = -1) -> bool:
	if inventory_weapons_list.size() >= 9:
		return false

	var weapon_info = WEAPON_REGISTRY.get(weapon_id)
	if not weapon_info:
		return false
		
	var weapon_name: String = weapon_info[0].to_upper()
	var weapon_path: String = weapon_info[1]

	for weapon in inventory_weapons_list:
		if weapon.weapon_name.to_upper() == weapon_name:
			weapon.magazine = weapon.weapon_stats.magazine_size
			return false

	var weapon_instance: Weapon
	if WeaponCache.preload_weapons and WeaponCache.preloaded_scenes:
		weapon_instance = WeaponCache.preloaded_scenes[weapon_path].instantiate()
	else:
		weapon_instance = load(weapon_path).instantiate()

	inventory_weapons_list.append(weapon_instance)
	EventBus.weapon_add_ui.emit(weapon_instance.weapon_stats.icon)

	if is_doubletap_active:
		weapon_instance.weapon_stats.fire_rate *= double_tap_multiplier 
		weapon_instance.weapon_stats.burst_fire_rate *= double_tap_multiplier 

	weapon_instance.is_haste = is_haste
	add_child(weapon_instance, true)

	for weapon in inventory_weapons_list:
		weapon.visible = false

	if inventory_weapons_list.size() > max_weapons_in_inventory:
		remove_weapon(active_weapon)

	_change_active_weapon(active_weapon, weapon_instance)
	return true


func remove_weapon(weapon_id_inventory: int = -1) -> void:
	if weapon_id_inventory < 0 or weapon_id_inventory >= inventory_weapons_list.size():
		return
	inventory_weapons_list[weapon_id_inventory].queue_free()
	inventory_weapons_list.remove_at(weapon_id_inventory)
	EventBus.weapon_remove_ui.emit(weapon_id_inventory)


func get_current_weapon() -> Weapon:
	if inventory_weapons_list.size() > 0:
		return inventory_weapons_list[active_weapon]
	return null


func get_inventory() -> Array[Weapon]:
	return inventory_weapons_list


func get_weapon_id_list() -> Dictionary:
	var id_map = {}
	for id in WEAPON_REGISTRY:
		id_map[WEAPON_REGISTRY[id][0].to_upper()] = id
	return id_map


func get_packed_weapon_list() -> Array[String]:
	var paths: Array[String] = []
	for id in WEAPON_REGISTRY:
		paths.append(WEAPON_REGISTRY[id][1])
	return paths


func get_random_weapon_id() -> int:
	return WEAPON_REGISTRY.keys().pick_random()


func get_weapon_name_from_id(id: int = 0) -> String:
	if WEAPON_REGISTRY.has(id):
		return WEAPON_REGISTRY[id][0]
	return "null"


func get_id_by_name(p_name: String) -> int:
	for id in WEAPON_REGISTRY:
		if WEAPON_REGISTRY[id][0].to_upper() == p_name.to_upper():
			return id
	return -1


func get_ray_end_point() -> Vector3:
	return weapon_ray_cast_3d.global_transform * weapon_ray_cast_3d.target_position


func weapon_in_inventory(weapon_id: int) -> bool:
	var target_name = get_weapon_name_from_id(weapon_id)
	for weapon in inventory_weapons_list:
		if weapon.weapon_name == target_name:
			return true
	return false
#endregion

#region Private methods
func _connect_events() -> void:
	EventBus.weapon_added_ui.connect(
		func(id: int, element: Control):
			inventory_weapons_list[id].set_ui_element(element) 
	)
	EventBus.weapon_reload.connect(
		func(is_reload: bool):
			is_reloading = is_reload
	)
	EventBus.weapon_aim.connect(_scope_aim_handler)
	EventBus.weapon_add_ammo.connect(
		func(amount: int):
			inventory_weapons_list[active_weapon].magazine += amount
	)
	EventBus.bonus_activated.connect(_on_bonus_activated)
	
	if knife:
		knife.animation_ended.connect(_on_fps_animation_ended)
	if can_animated:
		can_animated.animation_ended.connect(_on_fps_animation_ended)


func _setup_melee_timer() -> void:
	_melee_timer.one_shot = true
	add_child(_melee_timer)


func _handle_aim_audio(value: bool) -> void:
	if not scope_audio_stream_player:
		return
	scope_audio_stream_player.stream = SOUND_SCOPE_IN if value else SOUND_SCOPE_OUT
	scope_audio_stream_player.pitch_scale = 1.0 / (aim_speed * 5)
	scope_audio_stream_player.play()


func _handle_wheel_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if event.is_pressed():
			if is_aiming:
				return
			if is_reloading:
				get_current_weapon().break_reloading()

			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_step_weapon(-1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_step_weapon(1)


func _handle_keyboard_swap() -> void:
	if Input.is_action_just_pressed('swap_weapon_left'):
		_step_weapon(-1)
	elif Input.is_action_just_pressed('swap_weapon_right'):
		_step_weapon(1)


func _handle_numeric_input() -> void:
	for number in range(1, inventory_weapons_list.size() + 1):
		if Input.is_action_just_pressed("weapon_" + str(number)):
			if is_aiming:
				return
			if is_reloading:
				get_current_weapon().break_reloading()

			active_weapon = number - 1
			_change_active_weapon(active_weapon)
			break


func _handle_melee_attack() -> void:
	_melee_timer.start(melee_cooldown)
	EventBus.melee_attack.emit()

	if inventory_weapons_list.size() > 0:
		get_current_weapon().change_visible(false)

	knife.attack()
	is_melee_active = true

	for body in melee_zone.get_overlapping_bodies():
		if not body is Player and body.has_method("get_hit"):
			EventBus.weapon_hitted.emit(Color(1, 1, 1))
			body.get_hit(knife.damage, Vector3.ZERO)


func _handle_melee_input() -> void:
	if Input.is_action_just_pressed("melee_attack") and _melee_timer.is_stopped() and knife:
		_handle_melee_attack()


func _step_weapon(dir: int) -> void:
	var new_active = active_weapon + dir
	if new_active >= 0 and new_active < inventory_weapons_list.size():
		active_weapon = new_active
		_change_active_weapon(active_weapon)


func _change_active_weapon(id: int, weapon_instance: Weapon = null) -> void:
	if is_melee_active:
		return

	if (inventory_weapons_list.size() - 1) <= 1 and weapon_instance:
		weapon_instance.change_visible(true)

	if is_instance_valid(Global.player):
		Global.player.camera_weapon_animation.rotation_degrees = Vector3.ZERO

	for weapon in inventory_weapons_list:
		if weapon != inventory_weapons_list[id]:
			weapon.change_visible(false)
			weapon.set_process_mode(Node.PROCESS_MODE_DISABLED)

	var current = inventory_weapons_list[id]
	current.change_visible(true)
	current.set_process_mode(Node.PROCESS_MODE_INHERIT)
	active_weapon = id

	current.weapon_ray_cast_3d = weapon_ray_cast_3d
	weapon_ray_cast_3d.target_position.z = -current.weapon_stats.fire_distance

	is_manual_raycast_control = current.weapon_stats.buckshot_size > 0

	if is_instance_valid(Global.player):
		Global.player.bob_enabled = current.weapon_stats.bob_enabled
		Global.player.bob_range = current.weapon_stats.bob_range
		Global.player.bob_freq = current.weapon_stats.bob_freq

	EventBus.weapon_active.emit(active_weapon)
	EventBus.weapon_active_object.emit(current)
	weapon_changed.emit()
#endregion

#region Event handlers
func _on_fps_animation_ended() -> void:
	if inventory_weapons_list.size() > 0:
		get_current_weapon().change_visible(true)
	is_melee_active = false


func _scope_aim_handler(
	_magnifying: float,
	_weapon_magnifying: float,
	_speed: float,
	in_scope: bool = false,
	_transition: Tween.TransitionType = Tween.TRANS_SINE,
	_ease: Tween.EaseType = Tween.EASE_OUT 
) -> void:
	aim_speed = _speed
	is_aiming = in_scope
	
	if _tween:
		_tween.kill()
	
	_tween = get_tree().create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	
	var current = get_current_weapon()
	if current:
		_tween.tween_property(current, "current_fov", player.weapon_fov / _weapon_magnifying, _speed)\
			.set_trans(_transition).set_ease(_ease)
	
	_tween.tween_property(player.weapon_camera_3d, "fov", player.weapon_fov / _weapon_magnifying, _speed)\
		.set_trans(_transition).set_ease(_ease)
	
	if in_scope:
		_tween.tween_property(player.camera_3d, "fov", player.standart_fov / _magnifying, _speed)\
			.set_trans(_transition).set_ease(_ease)
	else:
		_tween.tween_property(player.camera_3d, "fov", player.standart_fov, _speed)\
			.set_trans(_transition).set_ease(_ease)
	
	_tween.play()
	EventBus.ui_update_crosshair.emit(in_scope)


func _on_bonus_activated(_bonus_id: String, _stacks: int) -> void:
	match _bonus_id:
		&"double_tap":
			is_doubletap_active = true
			for weapon in inventory_weapons_list:
				weapon.weapon_stats.fire_rate *= double_tap_multiplier 
				weapon.weapon_stats.burst_fire_rate *= double_tap_multiplier 
			melee_cooldown *= 0.8
		&"max_ammo":
			for weapon in inventory_weapons_list:
				weapon.clip = weapon.weapon_stats.clip_size
				weapon.magazine = weapon.weapon_stats.magazine_size
		&"speed_cola":
			is_haste = true
			for weapon in inventory_weapons_list:
				weapon.is_haste = is_haste
	
	var bonus = Global.bonus_registry.get_bonus(_bonus_id)
	if not bonus or not bonus.source == BonusDefinition.Source.MACHINE:
		return
	
	can_animated.play()
	if inventory_weapons_list.size() > 0:
		get_current_weapon().change_visible(false)
#endregion
