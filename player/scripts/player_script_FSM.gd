extends CharacterBody3D
class_name  Player

@export var animation_player : AnimationPlayer
@export var status_manager : StatusManager
@export var stamina_component : StaminaComponent

@export var can_rotate : bool = true
@export var can_move : bool = true

@export_group("Stats")
@export var score : int = 100 :
	set(value):
		score = value
		EventBus.emit_signal("ui_update_score", value)
@export_subgroup("Health")
@export var max_health : float = 100
@export var health : float = 100 : 
	set(value):
		EventBus.emit_signal("player_changed_health", value, health)
		health = value
		
		if is_laying_down and health <= 0:
			EventBus.player_die.emit()
@export var heal_time_delay : float = 5.0
@export var heal_per_second : float = 3
@export var heal_curve : Curve = preload("res://player/resources/heal_curve.tres")
@export var time_to_revive : float = 10

@export_group("Movement")
@export var default_speed : float = 5.0
@export var player_control : float = 1.0
@export var GRAVITY_MULT : float = 1.0
@export var can_jump : bool = true


@export var control_multiplayers : Dictionary = {
	"DEFAULT": 1.0,
	'CONCRETE':1.0,
	"DIRT": 0.9,
	"MUD":0.6,
	"ICE":0.3,
}

@export var weight : float = 80

@export_subgroup("Bindings")
@export var key_move_forward : String = "move_forward"
@export var key_move_backward : String = "move_backward"
@export var key_move_left : String = "move_left"
@export var key_move_right : String = "move_right"

@export_subgroup("Step")
@export var step_enabled : bool = true
@export var step_max_slope : float = 0.35
@export var step_max_height : float = 0.3
@export var step_min_height : float = 0.1
@export var ray_distant : float = 0.5

@export_group("Camera")
@export var standart_fov : float = 75 :
	set(value):
		standart_fov = value
		current_camera_fov = value
		if camera_3d:
			camera_3d.fov = value
	get:
		return standart_fov
@export var weapon_fov : float = 75 :
	set(value):
		weapon_fov = value
		if weapon_camera_3d:
			weapon_camera_3d.fov = value
@export var render_on_sinlge_layer : bool = false

var current_camera_fov : float = 75

@export var mouse_speed : float = 0.01 :
	set(value):
		mouse_speed = value
		EventBus.emit_signal("mouse_speed_changed", value)
	get:
		return mouse_speed
		
@export_subgroup("Weapon bob")
@export var bob_enabled : bool = true
@export_range(-0.5,0.5) var bob_range : float = 0.03
@export var aim_bob_factor : float = 1.0
@export_range(1,5) var bob_freq : float = 2.3

@export_subgroup('Camera bob')
@export var camera_bob_enabled : bool = true
@export_range(-0.5,0.5) var bob_range_cam : float = 0.06
@export_range(1,5) var bob_freq_cam : float = 2.3
var sin_time_bob : float = 0.0

var current_control_multiplayer : float = control_multiplayers.DIRT

var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity"):
	get:
		return gravity * GRAVITY_MULT
var mouse_relative : Vector2

var direction : Vector3 = Vector3.ZERO
var wanted_direction : Vector3

var is_heal_timer_ended : bool = true
var heal_timer : float = 0.0
var is_laying_down : bool = false

var quick_revive_active : bool = false

## Constants for status_manager
const STAT_RECOIL = &"recoil_mult"
const STAT_SPEED = &"speed_mult"
const STAT_SPREAD = &"spread_mult"

var camera_shake_enabled : bool = true
var camera_shake_base_strength : float = 0.007


@onready var neck : Node3D = $neck
@onready var weapon_bobbing: Node3D = %weapon_bobbing
@onready var camera_weapon_animation : Node3D = %camera_weapon_animation
@onready var camera_3d : Camera3D = %camera_3d
@onready var weapon_camera_viewport_container: SubViewportContainer = $viewmodel_viewport_container
@onready var weapon_camera_3d: Camera3D = %viewmodel_camera_3d
@onready var weapon_manager: WeaponManager = %weapon_manager
@onready var camera_sub_viewport: SubViewport = $viewmodel_viewport_container/sub_viewport
@onready var camera_body: Node3D = %camera_body

@onready var hand : Node3D = %hand
@onready var stair_check: RayCast3D = $stair_check
@onready var celling_check_shape_cast_3d: ShapeCast3D = $celling_check_shape_cast_3d
@onready var collision_shape_3d: CollisionShape3D = $collision_shape_3d

@onready var footsteps_module: FootStepsModule = %footsteps_module

@onready var state_machine: StateMachine = $state_machine

var current_speed : float = default_speed
var input_dir : Vector2 = Vector2.ZERO
var raw_input : Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Global.player = self
	Global.players.append(self)
	G_PenetrationSystem.exclude_bodies.append(self)
	
	render_on_sinlge_layer = GraphicsSettings.render_on_sinlge_layer
	
	if GraphicsUtils.is_opengl() or render_on_sinlge_layer:
		weapon_camera_viewport_container.hide(); weapon_camera_viewport_container.set_process_mode(Node.PROCESS_MODE_DISABLED)
		camera_3d.set_cull_mask_value(2, true)
	
	#Sub Viewport can`t render transparent texture with FSR
	if get_viewport().scaling_3d_mode == 0:
		camera_sub_viewport.scaling_3d_mode = get_viewport().scaling_3d_mode
	
	mouse_speed = InputSettings.mouse_sens
	
	if stamina_component:
		stamina_component.stamina_changed.connect(func (value : float):
			EventBus.player_stamina_changed.emit(value)
			)
		stamina_component.stamina_change_remaped.connect(func (value : float):
			EventBus.player_stamina_changed_remaped.emit(value)
			)
	EventBus.bonus_activated.connect(func activate_perk(bonus_id : StringName, _stack : int) -> void:
		match bonus_id:
			&"quick_revive":
				quick_revive_active = true
			&"juggernog":
				max_health *= 1.5
				health = max_health
			&"speed_cola":
				default_speed *= 1.2
		)
	EventBus.update_settings.connect(
		func()  -> void:
			mouse_speed = InputSettings.mouse_sens * get_window().content_scale_factor
			camera_sub_viewport.scaling_3d_scale = get_viewport().scaling_3d_scale
			camera_sub_viewport.screen_space_aa = get_viewport().screen_space_aa
			camera_sub_viewport.msaa_3d = get_viewport().msaa_3d
			
			weapon_fov = GraphicsSettings.weapon_camera_fov
			current_camera_fov = GraphicsSettings.camera_fov
			
			camera_3d.fov = current_camera_fov
			
			if GraphicsUtils.is_opengl() or GraphicsSettings.render_on_sinlge_layer:
				weapon_camera_viewport_container.hide(); weapon_camera_viewport_container.set_process_mode(Node.PROCESS_MODE_DISABLED)
				camera_3d.set_cull_mask_value(2, true)
			else:
				weapon_camera_viewport_container.show(); weapon_camera_viewport_container.set_process_mode(Node.PROCESS_MODE_INHERIT)
				camera_3d.set_cull_mask_value(2, false)
	)
	EventBus.player_revived.connect(func() -> void:
		quick_revive_active = false
		Global.bonus_controller.deactivate_bonus(&"quick_revive")
	)
	EventBus.melee_attack.connect(func () -> void:
		pass
		)
	EventBus.mouse_speed_changed.emit(mouse_speed)
	
	EventBus.add_score.connect(func (_line : String = "", added_score : int = 0)  -> void: 
		if Global.bonus_controller.is_bonus_active(&"double_points") and added_score >= 0:
			added_score *= 2
		
		score += added_score
		
		EventBus.emit_signal("ui_update_score", score)
		)
	
	if footsteps_module:
		footsteps_module.material_changed.connect(update_accel)
	
	camera_3d.fov = standart_fov
	weapon_camera_3d.fov = weapon_fov
	
	score = score
	
	EventBus.update_settings.emit()

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		mouse_relative += -event.relative * mouse_speed
	elif (event is InputEventScreenDrag):
		if event.position.x > int(DisplayServer.window_get_size().y / 4.0):
			mouse_relative += -event.relative * mouse_speed

func _process(delta: float) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var joy_input : Vector2 = Input.get_vector("rot_cam_left","rot_cam_right","rot_cam_down","rot_cam_up")
		joy_input.x *= -1
		
		mouse_relative += (joy_input * (mouse_speed * 5.0))
	
	weapon_and_camera_bobbing(delta)
	_update_camera(delta)

func _physics_process(delta : float) -> void:
	if not is_laying_down:
		if !is_heal_timer_ended:
			heal_timer += delta
			if heal_timer >= heal_time_delay: 
				is_heal_timer_ended = true
				heal_timer = 0
		
		if health < max_health:
			heal_timer += delta
			health += (heal_per_second * heal_curve.sample(remap(heal_time_delay, heal_timer, 0, 0,1))) * delta

func _push_away_rigid_bodies() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var push_dir : Vector3 = -c.get_normal()
			
			var velocity_diff_in_push_dir : float = self.velocity.dot(push_dir) - c.get_collider().linear_velocity.dot(push_dir)
			
			velocity_diff_in_push_dir = max(0., velocity_diff_in_push_dir)
			
			var mass_ratio : float = min(1., weight / c.get_collider().mass)
			
			if mass_ratio < 0.25:
				continue
			push_dir.y = 0
			
			var push_force : float = mass_ratio * 5.0
			c.get_collider().apply_impulse(push_dir * velocity_diff_in_push_dir * push_force, c.get_position() - c.get_collider().global_position)

func get_hit(dmg : float = 0, _normal : Vector3 = Vector3.ZERO) -> void:
	if dmg > 0 and health > 0:
		EventBus.emit_signal("player_changed_health", health - dmg, health)
		health -= dmg
		is_heal_timer_ended = false
		
		if health < 0 or is_zero_approx(health):
			if not is_laying_down:
				EventBus.emit_signal("player_laying_down")
			else:
				EventBus.emit_signal("player_die")
	
	camera_jump_animation()

func get_player_bottom() -> float:
	return (global_position.y - collision_shape_3d.shape.height / 2) - 0.01

func weapon_and_camera_bobbing(delta: float) -> void:
	sin_time_bob += delta * (current_speed / default_speed) * get_real_velocity().length()
	
	var weapon_params = {
		"enabled": true if camera_bob_enabled else bob_enabled,
		"target": weapon_bobbing,
		"freq": bob_freq,
		"range": bob_range_cam if not bob_enabled else (bob_range_cam + bob_range if camera_bob_enabled else bob_range),
		"aim_factor": aim_bob_factor
	}
	
	var camera_params = {
		"enabled": camera_bob_enabled,
		"target": camera_3d,
		"freq": bob_freq_cam,
		"range": bob_range_cam,
		"aim_factor": aim_bob_factor,
	}
	
	if state_machine.CURRENT_STATE is RunningPlayerState:
		camera_params.range += 0.025
		weapon_params.range += 0.025
	
	apply_bobbing(weapon_params, delta)
	apply_bobbing(camera_params, delta)

func apply_bobbing(params: Dictionary, delta: float) -> void:
	if params["enabled"] and velocity.length() >= 0.2:
		var is_aiming = weapon_manager.is_aiming
		var factor = params["aim_factor"] if is_aiming else 1
		var freq = params["freq"]
		var b_range = params["range"] / factor
		var target = params["target"]
		
		target.position.y = lerp(target.position.y, (sin(sin_time_bob * freq) * b_range) + clamp(velocity.y, -0.01, 0.01), 10 * delta)
		target.position.x = lerp(target.position.x, sin(sin_time_bob * freq * 0.5) * b_range, 10 * delta)
	else:
		params["target"].position = lerp(params["target"].position, Vector3.ZERO, delta * 2)

func camera_jump_animation() -> void:
	var camera_tween : Tween = get_tree().create_tween()
	
	camera_tween.tween_property(camera_3d,"rotation:x", deg_to_rad(-5), 0.1).set_trans(Tween.TRANS_SINE)
	camera_tween.tween_property(camera_3d,"rotation:z", randf_range(deg_to_rad(-5),deg_to_rad(5)) , 0.1).set_trans(Tween.TRANS_SINE)
	
	camera_tween.chain().tween_property(camera_3d,"rotation:x",0, 0.5).set_trans(Tween.TRANS_SPRING)
	camera_tween.parallel().tween_property(camera_3d,"rotation:z",0, 0.3).set_trans(Tween.TRANS_SPRING)

func _update_camera(_delta : float) -> void:
	
	if camera_shake_enabled:
		var value : float = status_manager.get_modifier(&"camera_shake_modifier")
		
		
		if not is_equal_approx(value, 1.0):
			var camera_strength_modified : float = value * camera_shake_base_strength
			mouse_relative += Vector2(
			randf_range(-camera_strength_modified, camera_strength_modified) / 2.0,
			randf_range(-camera_strength_modified, camera_strength_modified) / 2.0
			)
	
	rotate_y(mouse_relative.x)
	neck.rotate_x(mouse_relative.y) 
	
	neck.rotation_degrees.x = clampf(neck.rotation_degrees.x,-90,90) 
	mouse_relative = Vector2.ZERO

func update_gravity(delta : float) -> void:
	velocity.y -= gravity * delta

func update_input(SPEED: float = default_speed, acceleration: float = player_control, deceleration: float = player_control) -> void:
	raw_input = Input.get_vector(
		key_move_left, key_move_right,
		key_move_forward, key_move_backward
	)

	var joy_input := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y) 
	)
	if joy_input.length_squared() > 0.09:
		raw_input += joy_input

	input_dir = raw_input.limit_length(1.0)

	SPEED *= status_manager.get_modifier(&"speed_mult")
	current_speed = SPEED

	wanted_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	direction = lerp(direction, wanted_direction, player_control * acceleration * current_control_multiplayer)

	if direction.length_squared() > 0.001:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration)
		velocity.z = move_toward(velocity.z, 0, deceleration)


func update_velocity() -> void:
	if not can_move:
		return
	
	_push_away_rigid_bodies()
	move_and_slide()
	stairs_handler()

func update_accel(material : String = "DIRT"):
	if material in control_multiplayers:
		current_control_multiplayer = control_multiplayers[material]
	else:
		current_control_multiplayer = control_multiplayers["DEFAULT"]

func stairs_handler() -> void:
	if not step_enabled:
		return

	var step_input := Vector2(
		sign(raw_input.x) if abs(raw_input.x) > 0.1 else 0.0,
		sign(raw_input.y) if abs(raw_input.y) > 0.1 else 0.0
	)

	var half_height: float = collision_shape_3d.shape.height / 2.0
	stair_check.position = Vector3(
		step_input.x * ray_distant,
		step_max_height - half_height,
		step_input.y * ray_distant
	)
	stair_check.target_position.y = -step_max_height

	if not stair_check.is_colliding():
		return

	var surface_angle: float = acos(stair_check.get_collision_normal().dot(Vector3.UP))
	var step_height: float = abs(stair_check.get_collision_point().y - get_player_bottom())

	var can_step: bool = surface_angle <= deg_to_rad(step_max_slope) \
		and direction.length() > 0.1 \
		and is_on_floor() \
		and step_height > step_min_height \
		and step_height < step_max_height

	if can_step:
		velocity.y = current_speed * step_height * 1.25
		apply_floor_snap()
