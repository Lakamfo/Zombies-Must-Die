extends Node3D
class_name ExplodeComponent

@export var area : Area3D
@export var area_collision_shape : CollisionShape3D
@export var audio_stream_player : AudioStreamPlayer3D
@export var vfx : GPUParticles3D

func _explode(damage : float) -> void:
	if not area:
		return
	
	var rand_frame: int = randi_range(2, 10)
	
	for i in rand_frame:
		await get_tree().physics_frame

	if audio_stream_player:
		audio_stream_player.play()
	
	
	if vfx:
		vfx.show()
		vfx.restart()
	
	var exclude_rids: Array[RID] = [owner.get_rid()]
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var radius: float = area_collision_shape.shape.radius
	
	for body in area.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
	
		var current_exclude = exclude_rids.duplicate()
		var query := PhysicsRayQueryParameters3D.create(area_collision_shape.global_position, body.global_position, 0xFFFFFFFF, current_exclude)
		var result: Dictionary = space_state.intersect_ray(query)

		var tries: int = 3
		var hit_target: bool = false

		while tries > 0 and not hit_target:
			if result.is_empty():
				break

			var col: Object = result.get(&"collider")
			if not is_instance_valid(col):
				break

			exclude_rids.append(result[&"rid"])

			if col == body:
				var distance = area.global_position.distance_to(col.global_position)
				var fall_off = clamp(1.0 - (distance / radius), 0.0, 1.0)

				if col is RigidBody3D or col.has_method(&"apply_central_impulse"):
					var dir: Vector3 = area.global_position.direction_to(col.global_position)
					col.apply_central_impulse((dir * 5) * fall_off)
				if col.has_method(&"get_hit"):
					col.get_hit(damage * fall_off)

				hit_target = true
				break

			current_exclude = exclude_rids.duplicate()
			query = PhysicsRayQueryParameters3D.create(area.global_position, body.global_position, 0xFFFFFFFF, current_exclude)
			result = space_state.intersect_ray(query)
			tries -= 1
	
	await vfx.finished
