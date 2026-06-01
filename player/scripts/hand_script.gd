extends Node3D

@export var player: Player
@export var sway_origin: Node3D
@export var sway_position : bool = true
## How strongly the weapon rotates in response to mouse movement (degrees)
@export var sway_amplitude: float = 1.5
## Spring stiffness — how fast the weapon pulls toward the target rotation
@export var spring_stiffness: float = 200.0
## Damping — suppresses oscillation. At 2*sqrt(stiffness) = critical (no bounce)
## Critical for stiffness=200 -> ~28.3. Higher values = overdamped (sluggish, no overshoot)
@export var spring_damping: float = 22.0
## How quickly the mouse delta decays back to zero
@export var mouse_decay: float = 32.0
## Strength of roll tilt when strafing
@export var strafe_roll_strength: float = 1.5
@export var strafe_roll_strength_in_scope : float = 0.5
@export var sway_amplitude_in_scope : float = 0.75

@export var sway_position_multiplier : float = 0.015

var _velocity: Vector3 = Vector3.ZERO
var _mouse_delta: Vector2 = Vector2.ZERO
var _mouse_speed: float = 1.0
var _in_scope : bool = false
var _sway_origin_pos : Vector3 

var _default_amplitude           := sway_amplitude
var _default_stiffness           := spring_stiffness
var _default_damping             := spring_damping
var _default_mouse_decay         := mouse_decay
var _default_strafe_roll         := strafe_roll_strength
var _default_position_multiplier := sway_position_multiplier


func _ready() -> void:
	EventBus.mouse_speed_changed.connect(func(v: float): _mouse_speed = v)
	EventBus.weapon_active_object.connect(_weapon_changed)
	EventBus.weapon_scope_state_changed.connect(
		func _change_state(
		in_scope : bool
		) -> void: _in_scope = in_scope
		)
	
	_sway_origin_pos = sway_origin.position

func _weapon_changed(weapon: Weapon) -> void:
	if weapon.weapon_stats.sway_use_custom_values:
		sway_amplitude           = weapon.weapon_stats.sway_amplitude
		spring_stiffness         = weapon.weapon_stats.sway_spring_stiffness
		spring_damping           = weapon.weapon_stats.sway_spring_damping
		mouse_decay              = weapon.weapon_stats.sway_mouse_decay
		strafe_roll_strength     = weapon.weapon_stats.sway_strafe_roll_strength
		sway_amplitude_in_scope  = weapon.weapon_stats.sway_amplitude_in_scope
		strafe_roll_strength_in_scope = weapon.weapon_stats.sway_strafe_roll_strength_in_scope
		sway_position_multiplier = weapon.weapon_stats.sway_position_multiplier
	else:
		sway_amplitude        = _default_amplitude
		spring_stiffness      = _default_stiffness
		spring_damping        = _default_damping
		mouse_decay           = _default_mouse_decay
		strafe_roll_strength  = _default_strafe_roll
		sway_position_multiplier = _default_position_multiplier

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_delta += event.relative * _mouse_speed

func _process(_delta: float) -> void:
	var joy_input : Vector2 = Input.get_vector("rot_cam_left","rot_cam_right","rot_cam_down","rot_cam_up")
	joy_input.x *= -1
	
	_mouse_delta += (joy_input * _mouse_speed * 5.0)
	
	var amplitude : float = sway_amplitude_in_scope if _in_scope else sway_amplitude 
	var roll_strength : float = strafe_roll_strength_in_scope if _in_scope else strafe_roll_strength
	
	var target := Vector3(
		-clamp(_mouse_delta.y * amplitude, -8.0, 8.0),
		-clamp(_mouse_delta.x * amplitude, -8.0, 8.0),
		clamp(-player.raw_input.x * roll_strength, -5.0, 5.0)
	)


	var spring_force := (target - sway_origin.rotation_degrees) * spring_stiffness
	var damping_force := _velocity * spring_damping
	_velocity += (spring_force - damping_force) * SystemInfo.fixed_delta_procces
	
	sway_origin.rotation_degrees += _velocity * SystemInfo.fixed_delta_procces

	if sway_position and _sway_origin_pos != Vector3.ZERO:
		var target_pos := (Vector3(
			_velocity.y,
			-_velocity.x,
			0
		) * sway_position_multiplier) + _sway_origin_pos
		
		var position_return_speed : float = strafe_roll_strength
		sway_origin.position = sway_origin.position.lerp(target_pos, position_return_speed * SystemInfo.fixed_delta_procces)
	else:
		sway_origin.position = sway_origin.position.lerp(_sway_origin_pos, 10.0 * SystemInfo.fixed_delta_procces)

	_mouse_delta = _mouse_delta.lerp(Vector2.ZERO, mouse_decay * SystemInfo.fixed_delta_procces)
