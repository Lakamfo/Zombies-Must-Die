class_name RecoilApplier
extends Node3D

@export var apply_recoil_to_weapon_pos : bool = true

var camera_current_rotation: Vector3
var camera_target_rotation: Vector3
var camera_past_target: Vector3

var camera_snappiness: Vector3
var camera_return_speed: Vector3

var body_current_rotation: Vector3
var body_target_rotation: Vector3
var body_past_target: Vector3

var body_snappiness: Vector3
var body_return_speed: Vector3

var weapon_current_translation: Vector3
var weapon_target_translation: Vector3
var weapon_past_translation_target: Vector3

var weapon_current_rotation: Vector3
var weapon_target_rotation: Vector3
var weapon_past_target: Vector3

@onready var weapons : WeaponManager = %weapon_manager
@onready var camera_body : Node3D = %camera_body
@onready var hand : Node3D = %hand

var player : Player = owner

var weapon_recoil_pos_x : float = 0.015
var weapon_recoil_pos_y : float = 0.03
var weapon_recoil_pos_z : float = 0.05

var factor : float = 1.0


func _ready() -> void:
	await get_owner().ready
	player = owner
	
	weapons.recoil_system = self
	
	
	EventBus.weapon_recoil_camera_vector.connect(_weapon_recoil_camera_vector)
	EventBus.weapon_recoil.connect(_weapon_recoil)
	EventBus.weapon_active_object.connect(_weapon_changed)


func _process(delta: float) -> void:
	apply_recoil(true, camera_target_rotation, camera_current_rotation, camera_past_target, camera_return_speed, camera_snappiness)
	apply_recoil(false, body_target_rotation, body_current_rotation, body_past_target, body_return_speed, body_snappiness)

	if not weapons.is_manual_raycast_control:
		weapons.weapon_ray_cast_3d.rotation_degrees = weapons.rotation_degrees
	
	if apply_recoil_to_weapon_pos:
		var pos_vector : Vector3
		var weapon : Weapon = weapons.get_current_weapon()
		
		if not weapon:
			return
		
		factor = lerp(factor,
			0.1 if weapons.is_aiming else 1.0,
			weapon.weapon_stats.return_speed * delta
		)
		
		pos_vector = Vector3(
			self.rotation_degrees.y * weapon_recoil_pos_x * factor,
			self.rotation_degrees.x * weapon_recoil_pos_y * factor,
			self.rotation_degrees.x * weapon_recoil_pos_z * factor
		)
		
		hand.position = pos_vector


func apply_recoil(camera: bool, target_rotation: Vector3, current_rotation: Vector3, past_target: Vector3, return_speed: Vector3, snappiness: Vector3):
	var fixed_delta: float = SystemInfo.fixed_delta_procces
	
	if camera:
		camera_target_rotation.x = lerp(target_rotation.x, 0.0, return_speed.x * fixed_delta)
		camera_target_rotation.y = lerp(target_rotation.y, 0.0, return_speed.y * fixed_delta)
		camera_target_rotation.z = lerp(target_rotation.z, 0.0, return_speed.z * fixed_delta)

		camera_current_rotation.x = lerp(current_rotation.x, target_rotation.x, snappiness.x * fixed_delta)
		camera_current_rotation.y = lerp(current_rotation.y, target_rotation.y, snappiness.y * fixed_delta)
		camera_current_rotation.z = lerp(current_rotation.z, target_rotation.z, snappiness.z * fixed_delta)

		if target_rotation < past_target:
			rotation_degrees = target_rotation
		else:
			rotation_degrees.x = lerp(rotation_degrees.x, current_rotation.x, fixed_delta * snappiness.x)
			rotation_degrees.y = lerp(rotation_degrees.y, current_rotation.y, fixed_delta * snappiness.y)
			rotation_degrees.z = lerp(rotation_degrees.z, current_rotation.z, fixed_delta * snappiness.z)

			weapons.rotation_degrees.x = lerp(rotation_degrees.x, current_rotation.x / 2, fixed_delta * snappiness.x)
			weapons.rotation_degrees.y = lerp(rotation_degrees.y, current_rotation.y / 2, fixed_delta * snappiness.y)
			weapons.rotation_degrees.z = lerp(rotation_degrees.z, current_rotation.z / 2, fixed_delta * snappiness.z)
	else:
		body_target_rotation.x = lerp(target_rotation.x, 0.0, return_speed.x * fixed_delta)
		body_target_rotation.y = lerp(target_rotation.y, 0.0, return_speed.y * fixed_delta)
		body_target_rotation.z = lerp(target_rotation.z, 0.0, return_speed.z * fixed_delta)

		body_current_rotation.x = lerp(current_rotation.x, target_rotation.x, snappiness.x * fixed_delta)
		body_current_rotation.y = lerp(current_rotation.y, target_rotation.y, snappiness.y * fixed_delta)
		body_current_rotation.z = lerp(current_rotation.z, target_rotation.z, snappiness.z * fixed_delta)

		camera_body.rotation_degrees.x = lerp(rotation_degrees.x, current_rotation.x, fixed_delta * snappiness.x)
		camera_body.rotation_degrees.y = lerp(rotation_degrees.y, current_rotation.y, fixed_delta * snappiness.y)
		camera_body.rotation_degrees.z = lerp(rotation_degrees.z, current_rotation.z, fixed_delta * snappiness.z)


func get_spread_factor() -> float:
	return camera_current_rotation.length_squared()


func _weapon_changed(weapon : Weapon) -> void:
	weapon_recoil_pos_x = weapon.weapon_stats.weapon_recoil_pos_x
	weapon_recoil_pos_y = weapon.weapon_stats.weapon_recoil_pos_y
	weapon_recoil_pos_z = weapon.weapon_stats.weapon_recoil_pos_z


func _weapon_recoil(camera_kick: Vector3, _snappines: float, _return_speed):
	camera_target_rotation = (camera_kick * 
		player.status_manager.get_modifier(player.STAT_RECOIL)
	)
	
	camera_snappiness = Vector3(_snappines, _snappines, _snappines)
	camera_return_speed = Vector3(_return_speed, _return_speed, _return_speed)


func _weapon_recoil_camera_vector(camera_kick: Vector3, snappines: Vector3, return_speed: Vector3):
	camera_target_rotation = (camera_kick * 
		player.status_manager.get_modifier(player.STAT_RECOIL)
	)

	camera_snappiness = snappines
	camera_return_speed = return_speed
