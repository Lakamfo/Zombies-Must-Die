class_name WeaponStats
extends Resource

@export_category("Basic")
@export var upgrade_level : int = 0
@export var weapon_upgrade_name : String = ""
@export var weapon_stats_upgrade: WeaponStats
##Rate of fire per minute
@export var fire_rate = 800
##Rate of burst mode fire per minute
@export var burst_fire_rate = 0
##Default fire mode
@export_enum("semi", "auto", "burst") var fire_mode: int = 1
@export_flags("semi", "auto", "burst") var available_shooting_modes = 3
##Maximum engagement distance
@export var fire_distance: float = 50
##Lenght maps to fire distance
@export var fire_range_damage: Curve = preload("res://player/weapon_logic/damage_curve.tres")

##Affects the reclining force of the RigidBody
@export var bullet_rigid_impact_power: float = 1.0
## Affects the penetration
@export var bullet_impact_power: float = 1.0
@export var max_penetration_count: int = 3
##FOV magnifying while aiming
@export var aim_camera_zoom: float = 2.0
@export var aim_weapon_camera_zoom: float = 1.2

@export_group("Bullets")
@export var clip_size: int = 30:
	set(value):
		clip_size = value
@export var magazine_size: int = 300:
	set(value):
		magazine_size = value
##Additional bullet in chamber when tactical reloaded
@export var bullet_in_chamber: bool = true
@export var burst_size: int = 3

@export var buckshot_size: int = 0
@export var buckshot_spread_max_angle: int = 5

## remaining bullets in the clip are lost after reloading if this setting setted to True
@export var reload_penalty: bool = false

@export_group("Trigger")
@export var trigger_delay_enabled: bool = false
@export_range(0.0, 1.0) var trigger_delay: float

@export_group("Damage")
##Base damage.
##Damage depends on the body part and is calculated using the formula:
##result_damage = (damage * part_mult) * fire_range_distance.sample(distance to enemy / fire_distance)
@export var damage: float = 27

@export var head_mult: float = 2
@export var torso_mult: float = 1
@export var limbs_mult: float = 1

@export_group("Recoil")

@export_subgroup("Basic Recoil")
@export var max_hip_camera_kick: Vector3
@export var min_hip_camera_kick: Vector3
@export var max_aim_camera_kick: Vector3
@export var min_aim_camera_kick: Vector3
##Does nothing
@export var random_mult: float = 1

##How fast camera snaps to kick
@export var snappinnes = 6
##How fast camera returns to normal rotation
@export var return_speed = 2

@export_subgroup('Layered Recoil')
@export var layered_recoil_enabled: bool = false
@export var layered_recoil: RecoilData

@export_subgroup("NonStop paremetres")
##If this option is activated, the camera's recoil accumulates
@export var non_stop_mult_enabled: bool = true
@export var max_non_stop_mult: float = 5
@export var min_non_stop_mult: float = 1
##How much accumulates per shoot
@export var non_stop_increase: float = 0.05
##Waiting for the last shot to reset the recoil
@export var non_stop_reset_threshold: float = 0.5

@export_group("Position & Procedural animation")
##Procedural animations for aiming
@export var procedural_animation_enabled: bool = true
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_in: Tween.EaseType = Tween.EASE_IN
@export var ease_out: Tween.EaseType = Tween.EASE_OUT

@export_subgroup("Hip")
@export var standart_position: Vector3
@export var standart_rotation: Vector3
@export_subgroup("Aim")
@export var aim_position: Vector3
@export var aim_rotation: Vector3
##How long does the animation last in seconds
@export var aim_speed: float = 1.0
@export_subgroup("Weapon Bob", "bob")
@export var bob_enabled: bool = true
@export_range(-0.5, 0.5) var bob_range: float = 0.04
@export_range(1, 5) var bob_freq: float = 2.3
@export_subgroup("Weapon Sway", "sway")
@export var sway_use_custom_values: bool = true
## How strongly the weapon rotates in response to mouse movement (degrees)
@export var sway_amplitude: float = 3.0
@export var sway_amplitude_in_scope: float = 0.75
## Spring stiffness — how fast the weapon pulls toward the target rotation
@export var sway_spring_stiffness: float = 300.0
## Damping — suppresses oscillation. At 2*sqrt(stiffness) = critical (no bounce)
## Critical for stiffness=200 -> ~28.3. Higher values = overdamped (sluggish, no overshoot)
@export var sway_spring_damping: float = 22.0 
## How quickly the mouse delta decays back to zero
@export var sway_mouse_decay: float = 32.0
## Strength of roll tilt when strafing
@export var sway_strafe_roll_strength: float = 1.5
@export var sway_strafe_roll_strength_in_scope: float = 0.5
@export var sway_position_multiplier : float = 0.03
@export_subgroup("Weapon Recoil Position Mults", "weapon_recoil_pos")
@export var weapon_recoil_pos_x : float = 0.015
@export var weapon_recoil_pos_y : float = 0.03
@export var weapon_recoil_pos_z : float = 0.015

@export_group("Upgrade Shaders")
@export var upgrade_shader: Shader = preload("res://player/weapons/shaders/upgrade_lines.gdshader")


@export_group("Shell")
@export var manual_shell_eject: bool = false
@export_enum("9mm:0", "7mm:1", "5mm:2") var shell_type: int = 0
@export var min_impulse: Vector3
@export var max_impulse: Vector3
@export_subgroup("Custom shell model")
@export var custom_model: PackedScene
@export_group("Tracer")
@export var use_custom_tracer: bool = false
@export var custom_tracer_scene: PackedScene

@export_group("Sounds & Animations")
## if single loading is true, _animations_reload[0] = reload_start; _animations_reload[1] = reload_cycle; _animations_reload[2] = reload_end.
##Reload cycle animation should be looped for properly work.
@export var single_loading: bool = false
@export_placeholder("You can write several animations separated by commas") var idle_animation: String = ""
@export_placeholder("You can write several animations separated by commas") var aim_idle_animation: String = ""
@export_placeholder("You can write several animations separated by commas") var take_out_animation: String = ""
@export_subgroup("Fire Animations")
@export_placeholder("You can write several animations separated by commas") var fire_animation: String = ""
@export_placeholder("You can write several animations separated by commas") var aim_fire_animation: String = ""
@export_placeholder("You can write several animations separated by commas") var last_fire_animation: String = ""
@export_placeholder("You can write several animations separated by commas") var last_aim_fire_animation: String = ""
#@export_placeholder("You can write several animations separated by commas") var aim_reload_animation : String = ""
@export_subgroup("Reload Animations")
@export_placeholder("You can write several animations separated by commas") var tactical_reload_animation: String = ""
@export_placeholder("You can write several animations separated by commas") var reload_animation: String = ""
@export_subgroup("Inspect Animations")
@export_placeholder("You can write several animations separated by commas") var inspect_with_ammo: String = ""
@export_placeholder("You can write several animations separated by commas") var inspect_without_ammo: String = ""
@export_subgroup("Audio")
@export var pitch_min : float = 0.9
@export var pitch_max : float = 1.1

@export_group("UI")
@export var icon: CompressedTexture2D = preload("res://default_resources/icon.svg")
@export var hit_marker_standart_color: Color = Color(1, 1, 1)
@export var hit_marker_critical_color: Color = Color(0.72428458929062, 0.14479520916939, 0.22202762961388)
