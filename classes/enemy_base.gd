class_name EnemyBase
extends CharacterBody3D

@export_category("Nodes")
@export var skeleton: Skeleton3D
@export var animation_tree: AnimationTree
@export var navigation_agent_3d: NavigationAgent3D
@export var visible_on_screen_notifier: VisibleOnScreenNotifier3D
@export var physical_bone_simulator_3d: PhysicalBoneSimulator3D

@export_category("Behavior")
@export_subgroup("LifeTime")
@export var lifetime_enabled: bool = true
@export var lifetime: float = 30.0

@export_subgroup("Bonus")
@export var pickup_scene: PackedScene = preload("res://objects/interactable/pickup/pickup.tscn")

@export_category("Misc")
@export var weight: float = 80
@export var ragdoll_enabled: bool = false
@export var update_path_tick: int = 10
@export_range(0.5, 2, 0.1) var difficulty: float = 1

var spawned_by_wave_logic: bool = false
var is_ready: bool = false
var is_dead: bool = false

var lifetime_timer: float = 0.0

var current_tick: int = update_path_tick

var path: Vector3 = Vector3.ZERO


func _ready() -> void:
	self.call_deferred("_actor_setup")
	if visible_on_screen_notifier:
		visible_on_screen_notifier.screen_exited.connect(
			func handler_screen() -> void:
				if is_dead:
					queue_free()
		)
	if navigation_agent_3d:
		navigation_agent_3d.velocity_computed.connect(_set_computed_velocity)

	EventBus.enemy_spawned.emit(self)
	ModifiersManager.trigger_event(&"enemy_spawned", { "enemy": self })


func _actor_setup() -> void:
	set_collision_layer_value(CollisionsLayerName.CollisionName.ENEMY_BLOCK, true)

	for x in 3:
		await get_tree().physics_frame

	self.is_ready = true

	current_tick = randi_range(0, update_path_tick)
	count_tick()


func count_tick() -> void:
	self.current_tick += 1

	if self.current_tick >= self.update_path_tick:
		self.current_tick = 0

		self.update_path()


func is_on_screen(delta: float) -> void:
	if visible_on_screen_notifier:
		if not visible_on_screen_notifier.is_on_screen():
			lifetime_timer += delta

			if animation_tree:
				animation_tree.process_mode = Node.PROCESS_MODE_DISABLED

			if lifetime_timer > lifetime:
				die()
		else:
			if animation_tree:
				animation_tree.process_mode = Node.PROCESS_MODE_INHERIT


func get_closest_target() -> Player:
	var closest_target: Player = null
	var closest_target_distance: float = INF

	for target in Global.players:
		if is_instance_valid(target):
			if global_position.distance_to(target.global_position) < closest_target_distance:
				closest_target = target
				closest_target_distance = global_position.distance_to(target.global_position)

	return closest_target as Player


func update_rotation():
	var dir = (path - global_position).normalized()

	var target_rotation = Quaternion(Vector3.UP, atan2(-dir.x, -dir.z))
	var current_rotation = global_transform.basis.get_rotation_quaternion()

	var new_rotation = current_rotation.slerp(target_rotation, 0.1)
	var new_transform = global_transform

	new_transform.basis = Basis(new_rotation)
	global_transform = new_transform


func update_path():
	if not is_ready:
		return

	if (get_closest_target() != null):
		navigation_agent_3d.target_position = get_closest_target().global_position

	path = navigation_agent_3d.get_next_path_position()


func update_velocity(new_velocity: Vector3):
	if navigation_agent_3d:
		if navigation_agent_3d.avoidance_enabled:
			navigation_agent_3d.set_velocity(new_velocity)
		else:
			velocity = new_velocity


func _set_computed_velocity(safe_velocity: Vector3):
	velocity = safe_velocity


func get_hit(_dmg: float, _position: Vector3 = Vector3.ZERO, _body_part: int = 0):
	pass


func die():
	if is_dead:
		return
	is_dead = true

	if spawned_by_wave_logic:
		EventBus.emit_signal("game_enemy_killed")

	if navigation_agent_3d:
		navigation_agent_3d.avoidance_enabled = false
	if skeleton and ragdoll_enabled:
		skeleton.physical_bones_start_simulation()
	set_collision_layer_value(CollisionsLayerName.CollisionName.ENEMY_BLOCK, false)
