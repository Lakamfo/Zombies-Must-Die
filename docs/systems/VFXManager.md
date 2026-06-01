# VFXManager Usage

`VFXManager` is a global singleton in the project that manages pooled visual effects and decals.
It provides simple APIs for spawning effects, placing bullet holes/blood decals, and clearing active entries.

## Overview

Common methods:

* `register_pool(pool_id, scenes, max_count, fade_time, fade_duration, textures)`
* `spawn(pool_id, parent, world_pos, world_basis)`
* `spawn_by_index(pool_id, index, parent, world_pos, world_basis)`
* `place_decal(collider, normal, pos)`
* `place_pool_decal(pool_id, collider, normal, pos, intensity, args)`
* `place_decal_at_position(pool_id, world_pos, direction, intensity, args)`
* `place_splatter(pool_id, collider, center, normal, intensity, count, args)`
* `clear_pool(pool_id)`
* `clear_all()`


## Example: Creating a new pool

Before using any pool, you must register it, if not registered yet. This is typically done in `VFXManager._ready()` or at game initialization.

```gdscript
# Register a blood decal pool with custom textures, max 30 instances, fade after 10s, fade duration 2s.
VFXManager.register_pool(
	&"blood",                     # unique pool identifier
	[preload("res://blood_decal.tscn")],  # array of scenes (randomly chosen when spawning)
	30,                           # max concurrent instances
	10.0,                         # time (seconds) before fade starts
	2.0,                          # fade out duration
	{                             # optional per‑instance textures
		&"blood_1": {
			&"albedo": preload("res://textures/blood_albedo.png"),
			&"normal": preload("res://textures/blood_normal.png")
		}
	}
)

# Register a simple shell casing pool (no textures, random scene selection)
VFXManager.register_pool(
	&"shell",
	[
		preload("res://shells/9mm_shell.tscn"),
		preload("res://shells/556_shell.tscn")
	],
	50,
	8.0,
	1.5
)
```

## Example: Place a bullet hole decal

This example is used in `player/weapon_logic/weapon.gd`.

```gdscript
var hit = ... # Hit result from raycast
VFXManager.place_pool_decal(
	&"bullet_hole",
	hit.collider,
	hit.normal,
	hit.position,
	10.0
)
```

## Example: Place a blood decal

This example is used in `entities/PhysicalBoneBlood.gd`.

```gdscript
VFXManager.place_decal(
	collider,
	normal,
	pos
)
```

`place_decal()` is a convenience wrapper for the built-in blood pool.

## Example: Spawn a specific scene from a pool

This example is used for shell ejection in `player/weapon_logic/weapon.gd`.

```gdscript
var pool_id: StringName = &"shell"
var scene_index: int = VFXManager.add_scene_to_pool(pool_id, shell_scene)
if scene_index == -1:
	return

var instance: RigidBody3D = VFXManager.spawn_by_index(
	pool_id,
	scene_index,
	scene_root,
	_shell_position.global_position,
	global_basis
)
```

## Example: Adding a custom scene to an existing pool and spawning by index

Sometimes you need to add a new scene (e.g., a custom shell casing) to an already registered pool at runtime. The pool will manage its lifetime (fade time, max count) just like any other scene.  
This example shows how to safely add a scene to a pool (avoiding duplicates) and then spawn exactly that scene using its index.

```gdscript
# Determine which shell scene to use
var shell_scene: PackedScene
if weapon_stats.custom_model:
	shell_scene = weapon_stats.custom_model
else:
	match weapon_stats.shell_type:
		0: shell_scene = preload("res://shells/9mm_shell.tscn")
		1, 2: shell_scene = preload("res://shells/556_shell.tscn")

# Add the scene to the pool (if not already present) and get its index
var pool_id = &"shell"
var scene_index: int = VFXManager.add_scene_to_pool(pool_id, shell_scene)
if scene_index == -1:
	return   # pool doesn't exist or error

# Spawn the exact scene by index
var instance: RigidBody3D = VFXManager.spawn_by_index(
    pool_id,
    scene_index,
    get_tree().root,        # parent node
    global_position,        # world position
    Basis.IDENTITY          # world basis
)

# Apply custom physics (e.g., impulses for a shell)
if instance:
    instance.apply_central_impulse(Vector3(2, 5, 1))
    instance.apply_torque_impulse(Vector3(1, 1, 0))
```

### Why use this pattern?

- **Control over the exact scene** – you decide which variant appears.
- **Single pool for multiple variants** – no need to create separate pools (`shell_9mm`, `shell_556`).
- **Automatic lifetime management** – the added scene inherits the pool's `max_count`, `fade_time`, etc.
- **No duplicates** – `add_scene_to_pool` checks if the scene already exists and returns its index.

## Example: Place multiple decals around a point

```gdscript
VFXManager.place_splatter(
	&"blood",
	collider,
	center,
	normal,
	12.0,
	5
)
```

## Example: Clear decals

```gdscript
VFXManager.clear_pool(&"bullet_hole")

# Clear all active pooled effects
VFXManager.clear_all()
```

## Notes

* `place_pool_decal()` respects `min_impact_velocity`; lower intensity values will be ignored.
* Decal instances are automatically faded out and removed after their configured life time.
* `register_pool()` should be called before using a pool.
* `add_scene_to_pool()` is a helper that prevents duplicate entries; it returns the index of the scene (existing or newly added).
