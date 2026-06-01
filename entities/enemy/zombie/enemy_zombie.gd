extends EnemyBase

@export_group("Stats")
@export var health: float = 100.0
@export var damage: float = 20.0
@export var accel: float = 2.0
@export var speed: float = 5.0
var max_health

@export_group("Movement")
@export var can_wiggle: bool = false
@export var direction_movement_speed: float = 1.5
@export var direction_change_speed: float = 1.5

@export_group("Attack")
@export var attack_time: float = 0.5
@export var attack_threshold_time: float = 1.0
@export var barrier_attack_threshold_time: float = 2.0
@export var player_knockback_multiplier: float = 1.0
@export var is_explosive: bool = false
@export var attack_stuck_timeout: float = 3.0  # FIX: fallback если застрял в Attacking


@export_group("Surround Behavior")
@export var surround_radius: float = 1.2 
@export var surround_angle_speed: float = 0.3 
@export var surround_drift_strength: float = 0.4 

@export_group("Hesitation")
@export var hesitation_chance: float = 0.15  
@export var hesitation_duration_min: float = 0.4
@export var hesitation_duration_max: float = 1.2


@export_group("Other")
@export var score_kill: int = 50
@export var enemy_name: String = "Zombie"
@export var disappear_animation: String = "disappear"

enum states { Chasing = 0, Attacking = 1, Spawning = 2, Staggered = 3, Hesitating = 4 }

@export_group("Node Paths")
@export var explosive_area: Area3D
@export var explosive_area_collision_shape: CollisionShape3D
@export var explode_vfx: GPUParticles3D
@export var explode_sound: AudioStreamPlayer3D
@export var damage_area: Area3D
@export var footstep_system: AudioStreamPlayer3D
@export var animation_player: AnimationPlayer
@export var hitboxes: Array[StaticBody3D]
@export var head_explode_player: AudioStreamPlayer3D
@export var head_explode_particle: GPUParticles3D
@export var blood_trail: GPUParticles3D
@export var head_mesh: Node3D
@export var sound_impact: AudioStreamPlayer3D
@export var meshes: Array[MeshInstance3D]
@export var ray_ground_right: RayCast3D
@export var ray_ground_left: RayCast3D

@export_group("Stagger")
@export var stagger_damage_threshold: float = 30.0
@export var stagger_duration: float = 0.5         

@export_group("Rage")
## Percentage of health
@export var rage_health_threshold: float = 0.3      
@export var rage_speed_multiplier: float = 1.5      

var attack_timer: Timer = Timer.new()
var state: int = states.Chasing
var timer_player_in_area: float = 0.0
var attack_state_timer: float = 0.0

var barrier: InteractableItems
var barrier_damage: float = 0.0
var barrier_timer: float = 0.0

var scream_timer: float = 0.0
var scream_threshold: float = 10.0

var is_attacking_barrier: bool = false
var is_enraged: bool = false
var stagger_timer: float = 0.0

var player: Player = null
var wiggle_timer: float = 0.0

var surround_angle: float = 0.0 
var surround_target: Vector3 
var hesitation_timer: float = 0.0

@onready var hit_sounds: AudioStreamPlayer3D = $sfx/player_hit_sound
@onready var scream_sound: AudioStreamPlayer3D = $sfx/scream_sound

var damage_per_frame: float = 0.0


func _enter_tree() -> void:
	random_mat()


func _ready() -> void:
	super._ready()
	setup_enemy()
	setup_timers()
	setup_signals()
	play_spawn_anim()

	if explode_vfx: explode_vfx.hide()
	if blood_trail: blood_trail.hide()
	if head_explode_particle: head_explode_particle.hide()


func random_mat() -> void:
	var f_mat: BaseMaterial3D
	var variant: StringName = [&"zombie_1", &"zombie_2"].pick_random()

	if is_explosive:
		f_mat = MaterialsBank.get_material(&"zombie_explosive_1")
	else:
		f_mat = MaterialsBank.get_material(variant)

	for mesh in meshes:
		mesh.set_surface_override_material(0, f_mat)


func setup_enemy() -> void:
	health *= difficulty
	max_health = health
	state = states.Chasing
	scream_threshold = randf_range(5, 15)
	surround_angle = randf_range(0.0, TAU)  


func setup_timers() -> void:
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.wait_time = attack_time
	attack_timer.timeout.connect(receive_hit)

	wiggle_timer = randf_range(-30, 30)


func setup_signals() -> void:
	if damage_area:
		damage_area.body_exited.connect(body_exited)
		damage_area.body_entered.connect(body_entered)

	EventBus.bonus_nuke_all.connect(on_nuke_all)


func play_spawn_anim() -> void:
	await get_tree().process_frame
	if visible_on_screen_notifier.is_on_screen():
		if animation_tree:
			animation_tree[&"parameters/spawn_shot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


func _process(delta: float) -> void:
	is_on_screen(delta)


func _physics_process(delta: float) -> void:
	if animation_tree:
		var old_value: float = animation_tree.get(&"parameters/velocity_blend/blend_amount")
		animation_tree.set(&"parameters/velocity/scale", old_value)
		animation_tree.set(&"parameters/velocity_blend/blend_amount", lerpf(old_value, 1.0 - (get_real_velocity().length() / speed), 3 * delta))

	if not is_ready or is_dead:
		return

	count_tick()
	damage_per_frame = 0.0

	update_timers(delta)
	update_state(delta)
	handle_scream()
	check_rage()


func get_surround_target(delta: float) -> Vector3:
	if not player:
		return path

	surround_angle += sin(wiggle_timer * 0.5) * surround_drift_strength * delta

	var offset := Vector3(
		cos(surround_angle) * surround_radius,
		0.0,
		sin(surround_angle) * surround_radius
	)

	return player.global_position + offset


func try_hesitate() -> bool:
	if randf() < hesitation_chance:
		state = states.Hesitating
		hesitation_timer = randf_range(hesitation_duration_min, hesitation_duration_max)
		return true
	return false


func update_timers(delta: float) -> void:
	if not barrier:
		barrier_timer = 0.0

	wiggle_timer += delta * direction_change_speed
	scream_timer += delta

	if state == states.Attacking or (damage_area and damage_area.has_overlapping_bodies()):
		timer_player_in_area += delta
	else:
		timer_player_in_area = 0.0

	if state == states.Attacking:
		attack_state_timer += delta
	else:
		attack_state_timer = 0.0

	if state == states.Staggered:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			state = states.Chasing

	if state == states.Hesitating:
		hesitation_timer -= delta
		if hesitation_timer <= 0.0:
			state = states.Chasing


func update_state(delta: float) -> void:
	if state == states.Attacking and attack_state_timer > attack_stuck_timeout:
		state = states.Chasing
		attack_state_timer = 0.0

	var current_speed: float = speed * (rage_speed_multiplier if is_enraged else 1.0)
	
	surround_target = get_surround_target(delta)
	var dir: Vector3 = global_position.direction_to(surround_target)
	var new_velocity: Vector3 = velocity.lerp(dir * current_speed, accel * delta)

	match state:
		states.Chasing:
			update_rotation()
			_push_away_rigid_bodies()
			if not is_attacking_barrier:
				if can_wiggle and ray_ground_left and ray_ground_right:
					if ray_ground_left.is_colliding() and ray_ground_right.is_colliding():
						new_velocity += transform.basis * Vector3(sin(wiggle_timer) * direction_movement_speed, 0, 0)
				update_velocity(new_velocity)
				velocity = velocity.limit_length(current_speed)
				move_and_slide()

			check_area()
			check_barrier(delta)

		states.Attacking:
			pass

		states.Spawning:
			pass

		states.Staggered:
			velocity = velocity.lerp(Vector3.ZERO, accel * delta * 3.0)
			move_and_slide()

		states.Hesitating:
			velocity = velocity.lerp(Vector3.ZERO, accel * delta * 2.0)
			move_and_slide()
			update_rotation()


func check_area() -> void:
	if player and timer_player_in_area > attack_threshold_time:
		if not try_hesitate():
			start_attack()


func check_barrier(delta: float) -> void:
	if barrier:
		barrier_timer += delta

		if barrier_timer > barrier_attack_threshold_time and barrier.health > 0:
			perform_barrier_attack()
			is_attacking_barrier = true
		else:
			is_attacking_barrier = false


func perform_barrier_attack() -> void:
	if animation_tree:
		animation_tree[&"parameters/attack_shot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	barrier_timer = 0.0
	hit_sounds.play()
	barrier.get_hit(barrier_damage, Vector3.ZERO)


func start_attack() -> void:
	attack_timer.start()
	attack_state_timer = 0.0
	state = states.Attacking


func handle_scream() -> void:
	if scream_timer > scream_threshold:
		scream_sound.play()
		scream_timer = 0.0
		scream_threshold = randf_range(5, 15)


func check_rage() -> void:
	if not is_enraged and health / max_health <= rage_health_threshold:
		is_enraged = true
		scream_sound.play()


func receive_hit() -> void:
	if animation_tree:
		animation_tree[&"parameters/attack_shot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	if player:
		player.get_hit(damage * difficulty)
		player.direction += global_position.direction_to(get_closest_target().global_position) * (weight / player.weight) * player_knockback_multiplier
		hit_sounds.play()
	state = states.Chasing


func body_exited(body: Node3D) -> void:
	if body is Player:
		timer_player_in_area = 0.0
		player = null


func body_entered(body: Node3D) -> void:
	if body is Player:
		player = body


func get_hit(dmg: float, _position: Vector3 = Vector3.ZERO, body_part: int = 0) -> void:
	if is_dead:
		return

	if Global.bonus_controller.is_bonus_active(&"instant_kill"):
		health -= health + 1
	else:
		health -= dmg
	damage_per_frame += dmg

	play_hit_animation(body_part)

	if damage_per_frame >= stagger_damage_threshold and state != states.Staggered:
		trigger_stagger()

	if health <= 0:
		if body_part == Hitbox.Type.Head or Global.bonus_controller.is_bonus_active(&"instant_kill"):
			explode_head_if_lucky(damage_per_frame)
		on_death()
	elif sound_impact:
		sound_impact.play()


func trigger_stagger() -> void:
	state = states.Staggered
	stagger_timer = stagger_duration
	if animation_tree:
		animation_tree[&"parameters/body_hit/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


func play_hit_animation(body_part: int) -> void:
	if animation_tree:
		var animation_param: String = "head_hit" if body_part == Hitbox.Type.Head else "body_hit"
		animation_tree["parameters/%s/request" % animation_param] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


func _push_away_rigid_bodies() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var push_dir: Vector3 = -c.get_normal()
			var velocity_diff_in_push_dir: float = self.velocity.dot(push_dir) - c.get_collider().linear_velocity.dot(push_dir)
			velocity_diff_in_push_dir = max(0.0, velocity_diff_in_push_dir)
			var mass_ratio: float = min(1.0, weight / c.get_collider().mass)
			if mass_ratio < 0.25:
				continue
			push_dir.y = 0
			var push_force: float = mass_ratio * 5.0
			c.get_collider().apply_impulse(push_dir * velocity_diff_in_push_dir * push_force, c.get_position() - c.get_collider().global_position)


func on_death() -> void:
	if health <= 0:
		EventBus.emit_signal(&"add_score", tr(enemy_name) + " " + tr("KEY_ENEMY_KILLED"), score_kill * min(1.5, difficulty))
		spawn_pickup_if_lucky()
		die()


func explode_head_if_lucky(p_damage: float) -> void:
	if randf() <= min(p_damage / max_health, 0.9):
		explode_head()


func spawn_pickup_if_lucky() -> void:
	if randf() <= 0.09:
		var pickup_instance = pickup_scene.instantiate()
		add_sibling(pickup_instance)
		pickup_instance.global_position = global_position
		pickup_instance.position.y += 0.5


func die() -> void:
	if is_dead:
		return
	super.die()
	
	disable_hitboxes()

	if footstep_system:
		footstep_system.is_enabled = false

	if scream_sound:
		scream_sound.stop()

	_explode()

	if animation_player:
		animation_player.play(disappear_animation)


func disable_hitboxes() -> void:
	for hit_box in hitboxes:
		hit_box.set_collision_layer_value(CollisionsLayerName.CollisionName.WEAPON_INTERACTIVE, false)


func on_nuke_all() -> void:
	await get_tree().create_timer(0.5, false).timeout
	get_hit(health + 1)


func explode_head() -> void:
	if head_mesh:
		head_mesh.hide()
	if head_explode_player:
		head_explode_player.pitch_scale = randf_range(0.9, 1.1)
		head_explode_player.play()
	if head_explode_particle:
		head_explode_particle.show()
		head_explode_particle.restart()
	if blood_trail:
		blood_trail.show()
		blood_trail.restart()


func _explode() -> void:
	if not explosive_area or not is_explosive:
		return

	var rand_frame: int = randi_range(2, 5)
	for i in rand_frame:
		await get_tree().physics_frame

	if not is_instance_valid(self):
		return

	if explode_sound:
		explode_sound.play()
	if scream_sound:
		scream_sound.stop()
	if explode_vfx:
		explode_vfx.show()
		explode_vfx.restart()

	var damaged_bodies := {}
	var exclude_rids: Array[RID] = [get_rid()]
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var radius: float = explosive_area_collision_shape.shape.radius

	for body in explosive_area.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if damaged_bodies.has(body):
			continue 

		var current_exclude: Array[RID] = exclude_rids.duplicate()
		var query := PhysicsRayQueryParameters3D.create(explosive_area.global_position, body.global_position, 0xFFFFFFFF, current_exclude)
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
				var distance: float = explosive_area.global_position.distance_to(col.global_position)
				var fall_off: float = clamp(1.0 - (distance / radius), 0.0, 1.0)

				if col is RigidBody3D or col.has_method(&"apply_central_impulse"):
					var dir: Vector3 = explosive_area.global_position.direction_to(col.global_position)
					col.apply_central_impulse((dir * 5) * fall_off)
				if col.has_method(&"get_hit"):
					col.get_hit(150 * fall_off)

				damaged_bodies[body] = true
				hit_target = true
				break

			current_exclude = exclude_rids.duplicate()
			query = PhysicsRayQueryParameters3D.create(explosive_area.global_position, body.global_position, 0xFFFFFFFF, current_exclude)
			result = space_state.intersect_ray(query)
			tries -= 1
