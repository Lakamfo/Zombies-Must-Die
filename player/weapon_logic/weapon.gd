class_name Weapon
extends Node3D

signal reload
signal reloaded
signal fire_mode_changed
signal shot

#region Exports
@export_category("Basic")
@export var weapon_name: String = "fsp45"
@export var weapon_stats: WeaponStats:
	set(res):
		weapon_stats = res.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		weapon_lvl = res.upgrade_level
		set_upgrade_level(weapon_lvl)
		weapon_stats = res
		clip = res.clip_size
		magazine = res.magazine_size
		if ui_element:
			ui_element.set_icon(res.icon)
			ui_element.set_weapon_name(
				(weapon_stats.weapon_upgrade_name 
				if weapon_stats.weapon_upgrade_name != ""
				else weapon_name).to_upper()
			)

@export_group("Nodes")
## Weapon's animation node
@export_node_path("AnimationPlayer") var animation_player
## Weapon's shot sound
@export_node_path("AudioStreamPlayer3D") var audio_stream_player
## Weapon's fire-mode click sound
@export_node_path("AudioStreamPlayer3D") var audio_fire_mode_switch_stream_player
## Weapon's muzzle flash light
@export_node_path("OmniLight3D") var omni_light
## Shell spawn position
@export_node_path("Marker3D") var shell_position
## Sparkles and smoke particles
@export_node_path("GPUParticles3D") var gpu_particles

@export var muzzle_fire: Node3D
@export var camera_animation: Node3D
@export var bullet_pos: Marker3D
#endregion

const FIRE_MODE_LABELS: Array[String] = ["SEMI", "AUTO", "BURST"]

#region Variables

var weapon_lvl: int = 0
var current_fov: float:
	set(value):
		current_fov = value
		_update_fov()

# --- State ---
var fire_mode: int
var is_aiming: bool = false
var is_reloading: bool = false:
	set(value):
		is_reloading = value
		EventBus.weapon_reload.emit(is_reloading)
		reload.emit(is_reloading)
var is_take_out: bool = false
var is_haste: bool = false
var is_tactical_reload: bool = false

# --- Ammo ---
var clip: int:
	set(value):
		clip = value
		EventBus.weapon_clip_changed.emit(value)
var magazine: int:
	set(value):
		magazine = value
		_update_ui()

# --- Internal ---
var _previous_aim_state: bool  = false
var _non_stop: float = 1.0
var _auto_fire_accumulator: float = 0.0
var _bullet_shotted: int = 0

var _upgrade_shader_material: ShaderMaterial


# --- References ---
var player
var ui_element: Control
var scene_root: Node
var weapon_ray_cast_3d: RayCast3D
var model_materials: Array[BaseMaterial3D]
var all_animations: PackedStringArray

# --- Timers ---
var _timer: Timer = Timer.new()
var _non_stop_timer: Timer = Timer.new()
var _trigger_delay_timer: Timer = Timer.new()

# --- Preloaded scenes (effects that are not decals) ---
var _shell_9mm: PackedScene = preload("res://player/weapons/shells/models/9mm/9_mm_shell.tscn")
var _shell_5mm: PackedScene = preload("res://player/weapons/shells/models/5_56mm/5_56_shell.tscn")
var _bullet_tracer: PackedScene = preload("uid://cobqy6vhvqbqc")
var _smoke_particle: PackedScene = preload("res://player/weapons/smoke_particle.tscn")

# --- Cached node references (resolved from NodePaths) ---
var _animation_player: AnimationPlayer
var _audio_stream_player: AudioStreamPlayer3D
var _audio_fire_mode_switch_stream_player: AudioStreamPlayer3D
var _omni_light: OmniLight3D
var _gpu_particles: GPUParticles3D
var _shell_position: Marker3D
#endregion

#region Animation packs
var _anim_fire:               AnimationsPack = AnimationsPack.new()
var _anim_aim_fire:           AnimationsPack = AnimationsPack.new()
var _anim_last_fire:          AnimationsPack = AnimationsPack.new()
var _anim_last_aim_fire:      AnimationsPack = AnimationsPack.new()
var _anim_idle:               AnimationsPack = AnimationsPack.new()
var _anim_aim_idle:           AnimationsPack = AnimationsPack.new()
var _anim_take_out:           AnimationsPack = AnimationsPack.new()
var _anim_reload:             AnimationsPack = AnimationsPack.new()
var _anim_tactical_reload:    AnimationsPack = AnimationsPack.new()
var _anim_inspect_ammo:       AnimationsPack = AnimationsPack.new()
var _anim_inspect_no_ammo:    AnimationsPack = AnimationsPack.new()

class AnimationsPack:
	var _pack:      PackedStringArray
	var _pack_size: int = -1

	func parse(data: String, splitter: String = ",") -> void:
		_pack      = data.split(splitter, false)
		_pack_size = _pack.size() - 1

	func get_size() -> int:
		return _pack_size

	func get_pack() -> PackedStringArray:
		return _pack

	func get_rand_animation() -> String:
		return _pack[randi_range(0, _pack_size)] if _pack_size > -1 else "null"
#endregion

#region Lifecycle

func _ready() -> void:
	_setup_timers()
	_resolve_node_paths()
	
	weapon_stats = weapon_stats.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	
	scene_root = get_tree().root
	fire_mode = weapon_stats.fire_mode
	current_fov = GraphicsSettings.weapon_camera_fov
	magazine = weapon_stats.magazine_size
	clip = weapon_stats.clip_size
	_non_stop = weapon_stats.min_non_stop_mult

	if camera_animation:
		camera_animation.rotation = Vector3.ZERO
	if _animation_player:
		_animation_player.animation_finished.connect(_on_animation_finished)
	if _audio_stream_player:
		_audio_stream_player.process_mode = Node.PROCESS_MODE_ALWAYS

	_change_shooting_mode(true)
	_update_ui()
	_init_weapon_transform()
	_init_all_animations()

	model_materials = _init_materials()
	_clean_up_mats()
	_update_mats()

	EventBus.update_settings.connect(_on_settings_updated)


func _process(delta: float) -> void:
	_handle_input(delta)
	_procedural_animation(delta)


func _physics_process(_delta: float) -> void:
	if not visible:
		return
	if Input.is_action_just_pressed("change_fire_mode"):
		_change_shooting_mode(false)
	if Input.is_action_just_pressed("reload"):
		_reload()
#endregion

#region Public methods

func change_visible(visible_weapon: bool = false) -> void:
	if visible_weapon == visible:
		return

	visible      = visible_weapon
	is_reloading = false

	if visible_weapon and _anim_take_out.get_size() > -1:
		_animation_player.stop()
		_play_animation(_anim_take_out.get_rand_animation())
		is_take_out = true

	EventBus.weapon_fire_mode_changed.emit(fire_mode)


func set_ui_element(value: Control) -> void:
	ui_element = value
	var display_name: String = weapon_name if not weapon_stats.weapon_upgrade_name \
							   else weapon_stats.weapon_upgrade_name
	ui_element.weapon_name.text = display_name.to_upper()


func get_raycast_end_point() -> Vector3:
	return Global.weapon_manager.get_ray_end_point()


func get_random_recoil(min_kick: Vector3 = Vector3.ZERO,
					   max_kick: Vector3 = Vector3.ZERO) -> Vector3:
	return Vector3(
		randf_range(min_kick.x, max_kick.x),
		randf_range(-min_kick.y, max_kick.y),
		randf_range(-min_kick.z, max_kick.z)
	) * _non_stop


func call_fire_anim() -> void:
	if not _animation_player or weapon_stats.fire_animation == "":
		return

	_animation_player.stop()

	if weapon_stats.aim_fire_animation != "" and is_aiming:
		var anim := _anim_last_aim_fire.get_rand_animation() \
				if clip <= 0 and _anim_last_aim_fire.get_size() > -1 \
				else _anim_aim_fire.get_rand_animation()
		_play_animation(anim)
	else:
		var anim := _anim_last_fire.get_rand_animation() \
				if clip <= 0 and _anim_last_fire.get_size() > -1 \
				else _anim_fire.get_rand_animation()
		_play_animation(anim)


# Called from AnimationPlayer track
func end_reloading() -> void:
	is_reloading = false

func end_take_out() -> void:
	is_take_out = false

func break_reloading() -> void:
	pass  # reserved

func reload_by_one() -> void:
	if not visible:
		return

	if magazine > 0:
		var is_last := clip + 1 >= weapon_stats.clip_size or magazine - 1 <= 0
		clip     += 1
		magazine -= 1

		if not is_last:
			_play_animation(_anim_reload.get_pack()[1])
		else:
			var anim := _anim_tactical_reload.get_pack()[2] if is_tactical_reload \
						else _anim_reload.get_pack()[2]
			_play_animation(anim)
			is_reloading = false
	elif is_reloading:
		is_reloading = false
		_play_animation(_anim_tactical_reload.get_pack()[2])
#endregion

#region Private methods

func _setup_timers() -> void:
	for t in [_timer, _non_stop_timer, _trigger_delay_timer]:
		add_child(t)
		t.one_shot = true
		t.autostart  = false


func _resolve_node_paths() -> void:
	if animation_player:                    _animation_player                    = get_node_or_null(animation_player)
	if audio_stream_player:                 _audio_stream_player                 = get_node_or_null(audio_stream_player)
	if audio_fire_mode_switch_stream_player:_audio_fire_mode_switch_stream_player = get_node_or_null(audio_fire_mode_switch_stream_player)
	if omni_light:                          _omni_light                          = get_node_or_null(omni_light)
	if gpu_particles:                       _gpu_particles                       = get_node_or_null(gpu_particles)
	if shell_position:                      _shell_position                      = get_node_or_null(shell_position)


func _handle_input(_delta: float) -> void:
	if not Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return
	if not visible:
		return

	is_aiming = Input.is_action_pressed("mouse_2")

	_handle_inspect_input()
	_sync_camera_animation()

	if _non_stop_timer.is_stopped():
		_non_stop = weapon_stats.min_non_stop_mult

	var busy := is_take_out or (is_reloading and not weapon_stats.single_loading)
	if busy:
		return

	if Input.is_action_just_pressed("mouse_1") and clip == 0:
		_reload()
		return

	_handle_fire_input(_delta)


func _handle_inspect_input() -> void:
	if not Input.is_action_just_pressed("inspect"):
		return

	var in_blocking_anim: bool = _animation_player.current_animation in (
		_anim_fire.get_pack() + _anim_reload.get_pack() +
		_anim_tactical_reload.get_pack() + _anim_take_out.get_pack()
	)
	if in_blocking_anim:
		return

	if clip > 0 and _anim_inspect_ammo.get_size() > -1:
		_play_animation(_anim_inspect_ammo.get_rand_animation())
	elif _anim_inspect_no_ammo.get_size() > -1:
		_play_animation(_anim_inspect_no_ammo.get_rand_animation())


func _handle_fire_input(delta: float) -> void:
	var fire_interval: float = 60.0 / weapon_stats.fire_rate

	match fire_mode:
		0: # Semi
			if Input.is_action_just_pressed("mouse_1") and _timer.is_stopped():
				_fire()
				_timer.start(fire_interval) 
		1: # Auto
			if Input.is_action_pressed("mouse_1"):
				if Input.is_action_just_pressed("mouse_1") and _timer.is_stopped():
					if clip > 0:
						_fire()
						_timer.start(fire_interval)
					_auto_fire_accumulator = 0.0
					return
				
				_auto_fire_accumulator += delta
				while _auto_fire_accumulator >= fire_interval and clip > 0:
					_auto_fire_accumulator -= fire_interval
					_fire()
					_timer.start(fire_interval) 
			else:
				_auto_fire_accumulator = 0.0
		2: # Burst
			if Input.is_action_just_pressed("mouse_1") and _timer.is_stopped():
				_fire_burst()


func _fire_burst() -> void:
	var burst_interval: float = 60.0 / weapon_stats.burst_fire_rate
	_timer.start((burst_interval * weapon_stats.burst_size) + 0.1) 
	_play_muzzle_vfx()
	
	for _i in weapon_stats.burst_size:
		if weapon_stats.trigger_delay_enabled and not _trigger_delay_timer.is_stopped():
			await _trigger_delay_timer.timeout
		
		_fire_burst_shot()
		_play_bullet_vfx(get_raycast_end_point())
		
		await get_tree().create_timer(burst_interval, false).timeout


func _fire_burst_shot() -> void:
	if clip <= 0:
		return

	is_reloading = false
	_play_fire_audio()

	if weapon_stats.trigger_delay_enabled:
		if not _trigger_delay_timer.is_stopped():
			return
		_trigger_delay_timer.start(weapon_stats.trigger_delay)
		call_fire_anim()
		await _trigger_delay_timer.timeout

	clip -= 1

	if not weapon_stats.trigger_delay_enabled:
		call_fire_anim()

	if not weapon_stats.manual_shell_eject:
		_eject_shell()

	if weapon_stats.buckshot_size > 0:
		_fire_buckshot()
	else:
		_hit_reg()
	

	EventBus.weapon_fired.emit(self)
	_update_ui()
	_apply_recoil()
	_apply_controller_vibration()

	_non_stop_timer.start(weapon_stats.non_stop_reset_threshold)
	_non_stop = clamp(
		_non_stop + weapon_stats.non_stop_increase,
		weapon_stats.min_non_stop_mult,
		weapon_stats.max_non_stop_mult
	)


func _fire() -> void:
	if clip <= 0:
		return

	is_reloading = false
	_play_fire_audio()

	if weapon_stats.trigger_delay_enabled:
		if not _trigger_delay_timer.is_stopped():
			return
		_trigger_delay_timer.start(weapon_stats.trigger_delay)
		call_fire_anim()
		await _trigger_delay_timer.timeout

	clip -= 1

	if not weapon_stats.trigger_delay_enabled:
		call_fire_anim()

	if not weapon_stats.manual_shell_eject:
		_eject_shell()

	if weapon_stats.buckshot_size > 0:
		_fire_buckshot()
	else:
		_hit_reg()
		_play_muzzle_vfx()
		_play_bullet_vfx(get_raycast_end_point())

	EventBus.weapon_fired.emit(self)
	_update_ui()
	_apply_recoil()
	_apply_controller_vibration()

	_non_stop_timer.start(weapon_stats.non_stop_reset_threshold)
	_non_stop = clamp(
		_non_stop + weapon_stats.non_stop_increase,
		weapon_stats.min_non_stop_mult,
		weapon_stats.max_non_stop_mult
	)


func _play_fire_audio() -> void:
	if _audio_stream_player and _trigger_delay_timer.is_stopped():
		_audio_stream_player.pitch_scale = randf_range(
			weapon_stats.pitch_min, weapon_stats.pitch_max
		)
		_audio_stream_player.play()


func _fire_buckshot() -> void:
	var rot := _manual_spread()
	_play_muzzle_vfx()
	
	
	for _i in weapon_stats.buckshot_size:
		weapon_ray_cast_3d.rotation_degrees = rot
		weapon_ray_cast_3d.force_raycast_update()
		rot = _manual_spread()
		_hit_reg()
		_play_bullet_vfx(get_raycast_end_point())
	weapon_ray_cast_3d.rotation_degrees = Vector3.ZERO


func _hit_reg() -> void:
	if not weapon_ray_cast_3d:
		return

	_bullet_shotted += 1
	G_PenetrationSystem.weapon_stats = weapon_stats

	var direction: Vector3 = PenetrationSystem.get_raycast_global_direction(weapon_ray_cast_3d)
	var results: Array[HitResult] = G_PenetrationSystem.fire_bullet(
		weapon_ray_cast_3d.global_position, direction,
		weapon_stats.max_penetration_count,
		G_PenetrationSystem.penetration_data
	)

	var flew_through_flesh: bool = false
	for hit in results as Array[HitResult]:
		VFXManager.place_pool_decal(&"bullet_hole", hit.collider, hit.normal, hit.position, 10.0)
		
		if flew_through_flesh:
			VFXManager.place_decal(hit.collider, hit.normal, hit.position)
			flew_through_flesh = false
		if hit.material == &"FLESH":
			flew_through_flesh = true


func _reload() -> void:
	var in_blocking_anim: bool = (
		_animation_player.current_animation in _anim_fire.get_pack() or
		_animation_player.current_animation in _anim_reload.get_pack()
	)
	if in_blocking_anim or is_reloading or is_take_out:
		return
	if weapon_stats.single_loading:
		if magazine > 0 and clip != weapon_stats.clip_size:
			_play_animation(_anim_reload.get_pack()[0])
			is_tactical_reload = clip < 1
			is_reloading = true
		return

	var max_clip: int = weapon_stats.clip_size + int(weapon_stats.bullet_in_chamber and clip > 0)
	var wasted: int = max_clip - clip

	if wasted <= 0 or magazine <= 0:
		return
	if clip > 0 and _anim_tactical_reload.get_size() > -1:
		_play_animation(_anim_tactical_reload.get_rand_animation())
		is_tactical_reload = true
	elif _anim_reload.get_size() > -1:
		_play_animation(_anim_reload.get_rand_animation())
		is_tactical_reload = false
	is_reloading = true
	await reload
	if not visible:
		return

	var actual_max_clip: int = weapon_stats.clip_size + int(weapon_stats.bullet_in_chamber and clip > 0)
	var actual_wasted: int = actual_max_clip - clip

	if actual_wasted <= 0:
		return

	if weapon_stats.reload_penalty:
		var to_add: int = min(actual_wasted, magazine)
		var actually_added: int = min(to_add, actual_max_clip - clip)
		clip += actually_added
		magazine -= actual_wasted
	else:
		var to_add: int = min(actual_wasted, magazine)
		var actually_added: int = min(to_add, actual_max_clip - clip)
		clip += actually_added
		magazine -= actually_added
	_update_ui()


func _apply_recoil() -> void:
	if weapon_stats.layered_recoil_enabled:
		_play_recoil_sequence()
		return

	var camera_kick: Vector3 = get_random_recoil(
		weapon_stats.min_aim_camera_kick if is_aiming else weapon_stats.min_hip_camera_kick,
		weapon_stats.max_aim_camera_kick if is_aiming else weapon_stats.max_hip_camera_kick
	)
	EventBus.emit_signal("weapon_recoil", camera_kick,
		weapon_stats.snappinnes, weapon_stats.return_speed)


func _apply_controller_vibration() -> void:
	if not InputSettings.joy_vibration:
		return
	var score: float = WeaponCalculator.calculate_recoil_score(weapon_stats)
	Input.start_joy_vibration(
		0,
		score * 0.005,
		score * 0.01,
		minf(60.0 / weapon_stats.fire_rate * 1.5, 0.5)
	)


func _play_recoil_sequence() -> void:
	var data: RecoilData = weapon_stats.layered_recoil
	if not data:
		return

	var prefix: StringName = &"aim_" if is_aiming else &"hip_"

	var _emit_recoil := func(is_body: bool,
							  mins: Array[Vector3], maxs: Array[Vector3],
							  snaps: Array[Vector3], returns: Array[Vector3],
							  delays: Array[float]) -> void:
		for i in maxs.size():
			if delays.size() > 0 and i < delays.size() and delays[i] > 0.0:
				await get_tree().create_timer(delays[i], false).timeout
			var kick: Vector3 = get_random_recoil(mins[i], maxs[i])
			var snap:   Vector3 = snaps[mini(i, snaps.size() - 1)]
			var ret:    Vector3 = returns[mini(i, returns.size() - 1)]
			if is_body:
				EventBus.weapon_recoil_body_vector.emit(kick, snap, ret)
			else:
				EventBus.weapon_recoil_camera_vector.emit(kick, snap, ret)

	_emit_recoil.call(false,
		data.get(prefix + &"camera_min_recoil_data"),
		data.get(prefix + &"camera_max_recoil_data"),
		data.get(prefix + &"camera_recoil_snappines"),
		data.get(prefix + &"camera_recoil_return_speed"),
		data.get(prefix + &"camera_recoil_delay")
	)
	_emit_recoil.call(true,
		data.get(prefix + &"body_min_recoil_data"),
		data.get(prefix + &"body_max_recoil_data"),
		data.get(prefix + &"body_recoil_snappines"),
		data.get(prefix + &"body_recoil_return_speed"),
		data.get(prefix + &"body_recoil_delay")
	)


func _change_shooting_mode(ready_update: bool = false) -> void:
	var mask: int = weapon_stats.available_shooting_modes
	if mask == 0:
		DebugOutput.print_warning("No shooting mode selected: " + str(self))
		return

	var available: Array[int] = []
	var bit := 1; var mode := 0
	while bit <= mask:
		if mask & bit: available.append(mode)
		bit <<= 1; mode += 1

	if ready_update:
		if not available.has(fire_mode): fire_mode = available[0]
		return

	var idx: int = available.find(fire_mode)
	fire_mode = available[(idx + 1) % available.size()] if idx != -1 else available[0]

	if _audio_fire_mode_switch_stream_player:
		_audio_fire_mode_switch_stream_player.pitch_scale = randf_range(0.9, 1.1)
		_audio_fire_mode_switch_stream_player.play()

	EventBus.weapon_fire_mode_changed.emit(fire_mode)
	_update_ui()


func _procedural_animation(_delta: float) -> void:
	if not weapon_stats.procedural_animation_enabled:
		return
	if is_aiming == _previous_aim_state:
		return

	_previous_aim_state = is_aiming
	var tween := get_tree().create_tween()

	if is_aiming:
		EventBus.weapon_aim.emit(weapon_stats.aim_camera_zoom, weapon_stats.aim_weapon_camera_zoom,
			weapon_stats.aim_speed, true,
			weapon_stats.transition_type, weapon_stats.ease_in)
		EventBus.weapon_scope_state_changed.emit(true)
		tween.tween_property(self, "position",         weapon_stats.aim_position, weapon_stats.aim_speed)\
			.set_trans(weapon_stats.transition_type).set_ease(weapon_stats.ease_in)
		tween.parallel()
		tween.tween_property(self, "rotation_degrees", weapon_stats.aim_rotation, weapon_stats.aim_speed)\
			.set_trans(weapon_stats.transition_type).set_ease(weapon_stats.ease_out)
	else:
		EventBus.weapon_aim.emit(1.0, 1.0, weapon_stats.aim_speed, false,
			weapon_stats.transition_type, weapon_stats.ease_out)
		EventBus.weapon_scope_state_changed.emit(false)
		tween.tween_property(self, "position",         weapon_stats.standart_position, weapon_stats.aim_speed)\
			.set_trans(weapon_stats.transition_type).set_ease(weapon_stats.ease_out)
		tween.parallel()
		tween.tween_property(self, "rotation_degrees", weapon_stats.standart_rotation, weapon_stats.aim_speed)\
			.set_trans(weapon_stats.transition_type).set_ease(weapon_stats.ease_out)

	tween.play()


func _sync_camera_animation() -> void:
	if not Global.player.camera_weapon_animation or not camera_animation:
		return
	var current_rot: Vector3 = Global.player.camera_weapon_animation.rotation_degrees
	var target: Vector3 = Vector3(
		-camera_animation.rotation_degrees.x,
		 camera_animation.rotation_degrees.y,
		 camera_animation.rotation_degrees.z
	)
	_translate_head(target, current_rot, 26.0, 6.0)


func _translate_head(target: Vector3, current: Vector3,
					  snappiness: float, return_speed: float) -> void:
	var dt: float = SystemInfo.fixed_delta_procces
	target  = target.lerp(Vector3.ZERO, return_speed * dt)
	current = current.lerp(target, snappiness * dt)
	Global.player.camera_weapon_animation.rotation_degrees = current


func _manual_spread() -> Vector3:
	var angle: float = weapon_stats.buckshot_spread_max_angle
	return Vector3(
		randf_range(-angle, angle),
		randf_range(-angle, angle),
		0.0
	) * _non_stop


func _play_bullet_vfx(end_point: Vector3) -> void:
	if not GraphicsSettings.decals_enabled or not bullet_pos:
		return

	var tracer: Node
	if weapon_stats.use_custom_tracer:
		assert(weapon_stats.custom_tracer_scene != null,
			"Custom Tracer Scene is missing: %s" % name)
		tracer = weapon_stats.custom_tracer_scene.instantiate()
	else:
		tracer = _bullet_tracer.instantiate()

	scene_root.add_child(tracer)
	tracer.global_position = bullet_pos.global_position
	tracer.top_level = true
	tracer.look_at(end_point, Vector3.UP, true)

func _play_muzzle_vfx() -> void:
	if not bullet_pos or not GraphicsSettings.decals_enabled:
		return

	var smoke_scene: PackedScene = _smoke_particle
	if not smoke_scene:
		return

	var pool_id = &"muzzle_smoke"
	var scene_index: int = VFXManager.add_scene_to_pool(pool_id, smoke_scene)
	if scene_index == -1:
		return

	VFXManager.spawn_by_index(pool_id, scene_index, scene_root, bullet_pos.global_position, global_basis)

	if _gpu_particles: _gpu_particles.emitting = true
	if _omni_light:    _omni_light.visible      = true
	if muzzle_fire:
		muzzle_fire.visible             = true
		muzzle_fire.rotation_degrees.z  = randf_range(-180.0, 180.0)

	for _i in 3:
		await get_tree().process_frame

	if _gpu_particles: _gpu_particles.emitting = false
	if _omni_light:    _omni_light.visible      = false
	if muzzle_fire:    muzzle_fire.visible       = false


func _eject_shell() -> void:
	if not GraphicsSettings.decals_enabled or not _shell_position:
		return

	var shell_scene: PackedScene
	if weapon_stats.custom_model:
		shell_scene = weapon_stats.custom_model
	else:
		match weapon_stats.shell_type:
			0: shell_scene = _shell_9mm
			1, 2: shell_scene = _shell_5mm
			_: return

	if not shell_scene:
		return

	var pool_id = &"shell"
	var scene_index: int = VFXManager.add_scene_to_pool(pool_id, shell_scene)
	if scene_index == -1:
		return 

	var instance: RigidBody3D = VFXManager.spawn_by_index(pool_id, scene_index, scene_root, _shell_position.global_position, global_basis)
	if not instance:
		return

	instance.top_level = true
	instance.apply_central_impulse(global_transform.basis * _get_random_impulse())
	instance.apply_torque_impulse(_get_random_impulse())


func _get_random_impulse() -> Vector3:
	return Vector3(
		randf_range(weapon_stats.min_impulse.x, weapon_stats.max_impulse.x),
		randf_range(weapon_stats.min_impulse.y, weapon_stats.max_impulse.y),
		randf_range(weapon_stats.min_impulse.z, weapon_stats.max_impulse.z)
	)


func _play_animation(anim_name: String) -> void:
	if not _animation_player:
		return
	var is_reload_anim: bool = anim_name in (
		_anim_reload.get_pack() + _anim_tactical_reload.get_pack()
	)
	_animation_player.speed_scale = 2.0 if is_haste and is_reload_anim else 1.0
	_animation_player.play(anim_name)


func _update_ui() -> void:
	if not ui_element:
		return
	ui_element.ammos.text     = ui_element.ammo_template % [clip, magazine]
	ui_element.fire_mode.text = FIRE_MODE_LABELS[fire_mode]


func _update_fov() -> void:
	if not GraphicsSettings.render_on_sinlge_layer:
		return
	for mat in model_materials:
		mat.fov_override = current_fov
		_sync_next_pass_params(mat)


func _sync_next_pass_params(mat: BaseMaterial3D) -> void:
	if not mat.next_pass is ShaderMaterial:
		return
	var sm := mat.next_pass as ShaderMaterial
	var single := GraphicsSettings.render_on_sinlge_layer
	sm.set_shader_parameter("use_z_clip_scale", single)
	sm.set_shader_parameter("z_clip_scale", 0.1)
	sm.set_shader_parameter("use_fov_override", single)
	sm.set_shader_parameter("fov_override", current_fov)


func _clean_up_mats() -> void:
	for mat in model_materials:
		if mat.next_pass:
			mat.next_pass = null


func _update_mats() -> void:
	for mat in model_materials:
		if GraphicsSettings.render_on_sinlge_layer:
			mat.use_fov_override = true
			mat.use_z_clip_scale = true
			mat.z_clip_scale = 0.1
			mat.fov_override = current_fov
		else:
			mat.use_fov_override = false
			mat.use_z_clip_scale = false
		
		_sync_next_pass_params(mat)


func _init_weapon_transform() -> void:
	position = weapon_stats.standart_position
	rotation_degrees = weapon_stats.standart_rotation


func _init_all_animations() -> void:
	_anim_last_fire.parse(weapon_stats.last_fire_animation)
	_anim_last_aim_fire.parse(weapon_stats.last_aim_fire_animation)
	_anim_fire.parse(weapon_stats.fire_animation)
	_anim_aim_fire.parse(weapon_stats.aim_fire_animation)
	_anim_idle.parse(weapon_stats.idle_animation)
	_anim_aim_idle.parse(weapon_stats.aim_idle_animation)
	_anim_reload.parse(weapon_stats.reload_animation)
	_anim_tactical_reload.parse(weapon_stats.tactical_reload_animation)
	_anim_take_out.parse(weapon_stats.take_out_animation)
	_anim_inspect_ammo.parse(weapon_stats.inspect_with_ammo)
	_anim_inspect_no_ammo.parse(weapon_stats.inspect_without_ammo)

	all_animations = (
		_anim_take_out.get_pack()        + _anim_fire.get_pack()         +
		_anim_aim_fire.get_pack()        + _anim_last_fire.get_pack()    +
		_anim_last_aim_fire.get_pack()   + _anim_reload.get_pack()       +
		_anim_tactical_reload.get_pack() + _anim_aim_idle.get_pack()     +
		_anim_idle.get_pack()            + _anim_inspect_ammo.get_pack() +
		_anim_inspect_no_ammo.get_pack()
	)


func _init_materials() -> Array[BaseMaterial3D]:
	var materials: Array[BaseMaterial3D] = []
	for child in SceneTreeUtils.get_all_children(self):
		if not child is MeshInstance3D:
			continue
		child.extra_cull_margin = 5.0
		
		if child.mesh is ArrayMesh:
			for i in child.mesh.get_surface_count():
				var mat = child.get_active_material(i)
				if mat is BaseMaterial3D: materials.append(mat)
		elif child.mesh is PrimitiveMesh:
			var mat = child.mesh.material
			if mat is BaseMaterial3D: materials.append(mat)

	return materials


func _apply_upgrade_shader(enabled: bool) -> void:
	if not _upgrade_shader_material:
		_upgrade_shader_material = ShaderMaterial.new()
		_upgrade_shader_material.set_shader(weapon_stats.upgrade_shader)
	
	for mat in model_materials:
		if mat.resource_name == "fps_hands":
			continue
		
		if enabled:
			if mat.next_pass == null or not mat.next_pass is ShaderMaterial:
				_upgrade_shader_material.shader = weapon_stats.upgrade_shader
				_upgrade_shader_material.render_priority = 1
				mat.next_pass = _upgrade_shader_material
		else:
			mat.next_pass = null


func set_upgrade_level(level: int) -> void:
	weapon_lvl = level
	var has_upgrade := level > 0
	_apply_upgrade_shader(has_upgrade)
	_update_mats()
	
	if has_upgrade and _upgrade_shader_material:
		var colors := [
			Color(0.2, 0.8, 1.0),  
			Color(0.8, 0.3, 1.0),  
			Color(1.0, 0.6, 0.1),
		]
		var idx := clampi(level - 1, 0, colors.size() - 1)
		
		ui_element.texture_rect.modulate = colors[idx]
		
		
		_upgrade_shader_material.set_shader_parameter("scratch_color", colors[idx])
		_upgrade_shader_material.set_shader_parameter("intensity", 0.3 + level * 0.15)
#endregion

#region Event handlers

func _on_settings_updated() -> void:
	current_fov = GraphicsSettings.weapon_camera_fov
	_update_mats()


func _on_animation_finished(anim_name: String) -> void:
	var known: PackedStringArray = all_animations
	if anim_name not in known:
		return

	if anim_name in _anim_reload.get_pack() + _anim_tactical_reload.get_pack():
		is_reloading = false
	if anim_name in _anim_take_out.get_pack():
		is_take_out = false

	var next_idle: String
	if not is_aiming or _anim_aim_idle.get_size() < 0:
		next_idle = _anim_idle.get_rand_animation()
	else:
		next_idle = _anim_aim_idle.get_rand_animation()

	_play_animation(next_idle)


func _animation_handler(anim_name : String) -> void: # Legacy, compability thing
	_on_animation_finished(anim_name)
	pass
#endregion
