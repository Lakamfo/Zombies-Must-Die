class_name ElectricTrap
extends Area3D

@export var damage = 50
@export var attack_count: float = 10
@export var time_between_attacks: float = 1.5

var active: bool = false
var timer: float = 0
var available_attack_count = attack_count

const PARTICLES_SCENE = preload("res://objects/interactable/electric_trap/electricity_particles.tscn")
var particles: GPUParticles3D

signal attack
signal attack_ended


func _ready() -> void:
	set_collision_mask_value(3, true)

	particles = PARTICLES_SCENE.instantiate()
	add_child(particles)

	for child in get_children(true):
		if child is CollisionShape3D:
			particles.process_material.emission_shape_offset = child.position

			assert(child.shape is BoxShape3D, "The electric trap must have a box area")
			particles.process_material.emission_box_extents = child.shape.size
			particles.amount = 32 * child.shape.size.length()

			break


func activate():
	active = true
	timer = 0.0
	available_attack_count = attack_count


func _physics_process(delta: float) -> void:
	if active:
		timer += delta

		if available_attack_count > 0 and timer > time_between_attacks:
			available_attack_count -= 1
			timer = 0.0

			particles.emitting = true
			receive_damage()
			attack.emit()

		elif available_attack_count <= 0:
			attack_ended.emit()
			active = false


func receive_damage():
	for body in get_overlapping_bodies():
		if not body is Player and body.has_method("get_hit"):
			EventBus.weapon_hitted.emit(Color(0.489, 0.531, 0.965))
			body.get_hit(damage, Vector3.ZERO)
