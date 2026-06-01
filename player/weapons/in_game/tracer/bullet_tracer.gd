extends Node3D

@export var life_time: int = 5
@export var SPEED: float = 75
@export var direction: Vector3 = Vector3.MODEL_FRONT

@onready var mesh_instance_3d: MeshInstance3D = $mesh_instance_3d

var prevpos: Vector3
var timer: float = 0.0

var update_n_tick: int = 5
var current_tick: int = 0

signal tracer_collision(_global_position: Vector3)


func _ready() -> void:
	prevpos = global_position


func _physics_process(delta: float) -> void:
	current_tick += 1
	timer += delta

	if timer > life_time:
		queue_free()

	translate(direction * SPEED * delta)

	if current_tick >= update_n_tick:
		current_tick = 0
		var query = PhysicsRayQueryParameters3D.create(prevpos, global_position)

		var result = get_world_3d().direct_space_state.intersect_ray(query)

		if not result.is_empty():
			tracer_collision.emit(result.position)
			await get_tree().physics_frame

			queue_free()
		prevpos = global_position
