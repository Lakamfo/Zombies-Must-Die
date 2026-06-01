extends FPSAnimation

@export var throw_power : float = 5.5
@export var projectile_scene : PackedScene 
@export var projectile_spawn_point : Marker3D

var player : Player 
var root : Node

func _ready() -> void:
	player = get_owner()
	root = get_tree().root
	
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("granade"):
		_throw() 


func _throw() -> void:
	var scene : RigidBody3D = projectile_scene.instantiate()
	var rotated_vector = -player.neck.global_transform.basis.z
	
	root.add_child(scene)
	
	
	scene.global_position = projectile_spawn_point.global_position
	scene.apply_central_impulse((rotated_vector * throw_power) + player.velocity)
