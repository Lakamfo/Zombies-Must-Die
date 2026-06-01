extends Node3D

@export var explode_power: float = 25.0
@export var radius: float = 40.0
@export var area: Area3D
@export var collision_shape_3d: CollisionShape3D


func _ready() -> void:
	var parent: Node = get_parent()
	assert(parent.has_signal(&"tracer_collision"), "No 'tracer_collision' signal in parent")
	assert(area != null, "No Area in ExplodeOnContact")

	collision_shape_3d.shape.radius = radius
	parent.tracer_collision.connect(logica)


func logica(explosion_pos: Vector3) -> void:
	area.global_position = explosion_pos
	var bodies := area.get_overlapping_bodies()

	for body in bodies:
		if not body is Node3D:
			continue

		var dir := (body.global_position - explosion_pos).normalized()
		var dist := explosion_pos.distance_to(body.global_position)

		var strength: float = max(0.0, explode_power - dist)
		if strength == 0.0:
			continue

		if is_instance_of(body, CharacterBody3D):
			body.velocity += dir * strength
		elif is_instance_of(body, RigidBody3D):
			body.apply_central_impulse(dir * strength * body.mass)
