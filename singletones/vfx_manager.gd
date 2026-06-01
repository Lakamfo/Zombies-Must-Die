# res://singletones/VFXManager.gd
class_name VFXManagerClass
extends Node

#region Inner classes
class VFXEntry:
	var node: Node3D
	var pool_id: StringName

	func _init(p_node: Node3D, p_pool_id: StringName) -> void:
		node = p_node
		pool_id = p_pool_id


class PoolConfig:
	var scenes: Array[PackedScene]
	var max_count: int
	var fade_time: float
	var fade_duration: float
	var textures: Dictionary

	func _init(
		p_scenes: Array[PackedScene],
		p_max: int   = 50,
		p_fade: float = 10.0,
		p_fade_dur: float = 2.0,
		p_textures: Dictionary = {}
	) -> void:
		scenes = p_scenes
		max_count = p_max
		fade_time = p_fade
		fade_duration = p_fade_dur
		textures = p_textures

	func get_random_scene() -> PackedScene:
		return scenes[randi() % scenes.size()]
	func get_scenes_count() -> int:
		return scenes.size()
#endregion

#region Constants
const _BLOOD_POOL_ID: StringName  = &"blood"
const _BLOOD_PACKED: PackedScene = preload("res://objects/blood_pudle/blood_pudle.tscn")
const _BLOOD_TEXTURES: Dictionary = {
	&"blood_1": {
		&"albedo": preload("res://objects/blood_pudle/textures/blood_splat_1.png"),
		&"normal": preload("res://objects/blood_pudle/textures/blood_stylized_normal.png"),
	},
}

const _BULLET_HOLE_POOL_ID: StringName  = &"bullet_hole"
const _BULLET_HOLE_PACKED: PackedScene = preload("res://player/weapons/bullet_hole/bullet_hole.tscn")
#endregion

#region Exports
@export var min_impact_velocity: float = 3.0
#endregion

#region Variables
var _pools: Dictionary[StringName, PoolConfig] = {}
var _entries: Dictionary[StringName, Array] = {}
#endregion

#region Lifecycle
func _ready() -> void:
	register_pool(_BLOOD_POOL_ID, [_BLOOD_PACKED], 30, 10.0, 2.0, _BLOOD_TEXTURES)
	register_pool(_BULLET_HOLE_POOL_ID, [_BULLET_HOLE_PACKED], 30, 5.0, 2.0)
	register_pool(&"shell", [], 30, 5.0, 1.0)
	register_pool(&"muzzle_smoke", [], 10, 1.5, 1.0)
	
#endregion

#region Public methods — registration

## Register a pool with one or multiple scenes.
## If multiple scenes are provided, a random one is chosen each spawn().
func register_pool(
	pool_id: StringName,
	scenes: Array[PackedScene],
	max_count: int   = 50,
	fade_time: float = 10.0,
	fade_duration: float = 2.0,
	textures: Dictionary = {}
) -> void:
	_pools[pool_id]   = PoolConfig.new(scenes, max_count, fade_time, fade_duration, textures)
	_entries[pool_id] = []


## Check, if scene already in pool
func has_scene_in_pool(pool_id: StringName, scene: PackedScene) -> bool:
	if not _pools.has(pool_id):
		return false
	return _pools[pool_id].scenes.has(scene)

## return index of scene in pool, or -1, if not found
func get_scene_index(pool_id: StringName, scene: PackedScene) -> int:
	if not _pools.has(pool_id):
		return -1
	return _pools[pool_id].scenes.find(scene)

## Adds scene into pool, if scene doesn`t exist in it yet, and returns scene`s index
func add_scene_to_pool(pool_id: StringName, scene: PackedScene) -> int:
	if not _pools.has(pool_id):
		push_error("VFXManager: unknown pool '%s'" % pool_id)
		return -1
	if has_scene_in_pool(pool_id, scene):
		return get_scene_index(pool_id, scene)
	_pools[pool_id].scenes.append(scene)
	return _pools[pool_id].scenes.size() - 1
#endregion

#region Public methods — spawning

## Spawn a random scene from the pool as a child of parent.
## Returns a Node3D or null on error.
func spawn(
	pool_id: StringName,
	parent: Node,
	world_pos: Vector3,
	world_basis: Basis = Basis.IDENTITY
) -> Node3D:
	var instance: Node3D = _instantiate(pool_id)
	if not instance:
		return null

	parent.add_child(instance)
	instance.global_position = world_pos
	instance.global_basis    = world_basis

	_register_entry(pool_id, instance)
	return instance


## Spawn a specific scene from the pool by index (0..scenes.size()-1)
func spawn_by_index(
	pool_id: StringName, 
	index: int, 
	parent: Node, 
	world_pos: Vector3, 
	world_basis: Basis = Basis.IDENTITY
) -> Node3D:
	if not _pools.has(pool_id):
		push_error("VFXManager: unknown pool '%s'" % pool_id)
		return null
	var cfg: PoolConfig = _pools[pool_id]
	if index < 0 or index >= cfg.scenes.size():
		push_error("VFXManager: invalid index %d for pool '%s'" % [index, pool_id])
		return null
	var instance: Node3D = cfg.scenes[index].instantiate()
	if not instance:
		return null
	parent.add_child(instance)
	instance.global_position = world_pos
	instance.global_basis = world_basis
	_register_entry(pool_id, instance)
	return instance


## Spawn a blood decal (backward compatibility with BloodManager.place_decal).
func place_decal(
	collider: Node,
	normal: Vector3,
	pos: Vector3,
	intensity: float = min_impact_velocity
) -> void:
	place_pool_decal(_BLOOD_POOL_ID, collider, normal, pos, intensity)


## Spawn a decal from an arbitrary pool.
func place_pool_decal(
	pool_id: StringName,
	collider: Node,
	normal: Vector3,
	pos: Vector3,
	intensity: float = min_impact_velocity,
	args: Dictionary[StringName, Variant] = {},
) -> Node3D:
	if intensity < min_impact_velocity:
		return
	if not collider:
		return

	var instance: Node3D = _instantiate(pool_id)
	if not instance:
		return
	if &"collider" in instance:
		instance.collider = collider
	
	if args:
		for arg in args.keys():
			if arg in collider:
				collider.set(arg, args[arg])
	
	collider.add_child(instance)
	instance.global_position = pos

	_apply_decal_texture(instance, _pools[pool_id])
	_orient_decal(instance, normal)
	_apply_intensity_scale(instance, intensity)

	_register_entry(pool_id, instance)
	
	return instance


## Raycast — find a surface and place a decal at that position.
func place_decal_at_position(
	pool_id: StringName,
	world_pos: Vector3,
	direction: Vector3 = Vector3.DOWN,
	intensity: float   = 1.0,
	args: Dictionary[StringName, Variant] = {},
) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		world_pos, world_pos + direction * 2.0
	)
	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		place_pool_decal(pool_id, result.collider, result.normal, result.position, intensity, args)


## Place several decals around a point.
func place_splatter(
	pool_id: StringName,
	collider: Node,
	center: Vector3,
	normal: Vector3,
	intensity: float = min_impact_velocity,
	count: int   = 3,
	args: Dictionary[StringName, Variant] = {},
) -> void:
	place_pool_decal(pool_id, collider, normal, center, intensity)
	for _i: int in range(count - 1):
		var offset := Vector3(
			randf_range(-0.3, 0.3),
			randf_range(-0.1, 0.1),
			randf_range(-0.3, 0.3)
		)
		place_pool_decal(pool_id, collider, normal, center + offset, intensity * randf_range(0.4, 0.8), args)


## Backward compatibility with BloodManager.place_blood_splatter.
func place_blood_splatter(
	collider: Node,
	center: Vector3,
	normal: Vector3,
	intensity: float = min_impact_velocity,
	count: int   = 3,
	args: Dictionary[StringName, Variant] = {},
) -> void:
	place_splatter(_BLOOD_POOL_ID, collider, center, normal, intensity, count, args)


## Remove all alive objects in the pool.
func clear_pool(pool_id: StringName) -> void:
	if not _entries.has(pool_id):
		return
	for entry: VFXEntry in _entries[pool_id].duplicate():
		_remove_entry(entry)
	_entries[pool_id].clear()


## Remove all objects from all pools.
func clear_all() -> void:
	for pool_id: StringName in _entries.keys():
		clear_pool(pool_id)


## Number of alive objects in the pool.
func get_count(pool_id: StringName) -> int:
	return _entries[pool_id].size() if _entries.has(pool_id) else 0
#endregion

#region Private methods

func _instantiate(pool_id: StringName) -> Node3D:
	if not _pools.has(pool_id):
		push_error("VFXManager: unknown pool '%s'" % pool_id)
		return null
	if not _pools[pool_id].get_scenes_count() > 0:
		push_error("VFXManager: empty scene array, pool '%s'" % pool_id)
		return null
	return _pools[pool_id].get_random_scene().instantiate() as Node3D


func _register_entry(pool_id: StringName, instance: Node3D) -> void:
	var entry := VFXEntry.new(instance, pool_id)
	_entries[pool_id].append(entry)
	_enforce_limit(pool_id)
	_start_fade(entry)


func _enforce_limit(pool_id: StringName) -> void:
	var cfg: PoolConfig = _pools[pool_id]
	var arr: Array      = _entries[pool_id]
	while arr.size() > cfg.max_count:
		_remove_entry(arr.pop_front())


func _start_fade(entry: VFXEntry) -> void:
	var cfg: PoolConfig = _pools[entry.pool_id]
	await get_tree().create_timer(cfg.fade_time).timeout

	if not is_instance_valid(entry.node):
		return

	var tween: Tween = create_tween()
	var node: Node3D = entry.node

	if node is MeshInstance3D and node.get_surface_override_material_count() > 0:
		var mat: Material = node.get_surface_override_material(0)
		if mat is BaseMaterial3D:
			tween.tween_property(mat, "albedo_color:a", 0.0, cfg.fade_duration)
	elif "modulate" in node:
		tween.tween_property(node, "modulate:a", 0.0, cfg.fade_duration)

	tween.tween_callback(_remove_entry.bind(entry))


func _remove_entry(entry: VFXEntry) -> void:
	if is_instance_valid(entry.node):
		entry.node.free()
	if _entries.has(entry.pool_id):
		_entries[entry.pool_id].erase(entry)


func _apply_decal_texture(instance: Node3D, cfg: PoolConfig) -> void:
	if cfg.textures.is_empty():
		return
	var keys: Array     = cfg.textures.keys()
	var tex: Dictionary = cfg.textures[keys[randi() % keys.size()]]
	if tex.has(&"albedo") and "texture_albedo" in instance:
		instance.texture_albedo = tex[&"albedo"]
	if tex.has(&"normal") and "texture_normal" in instance:
		instance.texture_normal = tex[&"normal"]


func _orient_decal(instance: Node3D, normal: Vector3) -> void:
	if not normal.is_equal_approx(Vector3.UP) and not normal.is_equal_approx(Vector3.DOWN):
		instance.look_at(instance.global_transform.origin + normal, Vector3.UP)
		instance.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(90))
		instance.rotate_object_local(Vector3(0, 1, 0), randf_range(0.0, TAU))
	else:
		instance.rotate_y(randf_range(0.0, TAU))


func _apply_intensity_scale(instance: Node3D, intensity: float) -> void:
	instance.scale = Vector3.ONE * clampf(intensity / 10.0, 0.5, 1.5)
#endregion
