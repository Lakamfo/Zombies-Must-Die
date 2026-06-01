@tool
extends Node

class_name PlacerEditor

@export var place: bool = false:
	set(value):
		if Engine.is_editor_hint():
			place_scenes()
@export var apply_rotation: bool = true
@export var raycast: RayCast3D
@export var scene: PackedScene
@export var radius: float = 100
@export var count: int = 20
@export var add_to_node: Node3D
@export var avoidance_radius: float = 20


func place_scenes():
	if add_to_node == null:
		print("add_to_node is not set. Instances will not be added.")
		return

	var placed_positions = []

	for i in range(count):
		var attempts = 0
		var hit_position = Vector3()
		var hit_normal = Vector3()
		var valid_position = false

		while attempts < 1000:
			var random_position = Vector3(randf_range(-radius, radius), abs(raycast.target_position.y), randf_range(-radius, radius))
			raycast.global_position = random_position
			raycast.force_raycast_update()

			if raycast.is_colliding():
				hit_position = raycast.get_collision_point()
				hit_normal = raycast.get_collision_normal()

				valid_position = true
				for pos in placed_positions:
					if hit_position.distance_to(pos) < avoidance_radius:
						valid_position = false
						break

				if valid_position:
					break

			attempts += 1

		if not valid_position or attempts >= 1000:
			print("It was not possible to find a suitable place for the instance after 1000 attempts.")
			continue

		var instance = scene.instantiate()
		add_to_node.add_child(instance)

		instance.global_position = hit_position

		if apply_rotation:
			var look_target = hit_position + hit_normal
			if not hit_normal.dot(Vector3.UP) > 0.8:
				#look_target += Vector3(0.1, 0, 0)  
				instance.look_at(look_target, Vector3.UP)

		instance.owner = owner

		placed_positions.append(hit_position)

		await get_tree().create_timer(0.1).timeout
