class_name WaveLogic
extends Node

#region Signals
signal enemies_dead
#endregion

#region Exports
@export_category("Settings")
@export var spawn_positions: Array[NodePath]:
	set(value):
		spawn_positions = value
		_spawn_position_nodes = _update_spawn_positions(value)

@export var wave_enemies_list: Array[Array] = [["zombie", "zombie", "zombie"]]
@export var wave_peak_difficulty: int = 13
@export var difficulty_curve: Curve = preload("res://classes/wave_logic/difficulty_curve.tres")

@export_group("Rooms")
@export var generate_wave_for_rooms: bool = false

@export_group("Endless")
@export var endless: bool = false
@export var zombie_ai_per_player: int = 20
@export var max_alive_at_once: int = 24
@export var endless_enemy_array: Array[WaveLogicEnemy] = [
	preload("res://entities/enemy/zombie/zombie_resource.tres"),
]

@export_group("Timings")
@export var time_between_waves: float = 15
@export var time_between_spawns: float = 1.5
@export var min_spawn_delay: float = 0.3
#endregion

#region Variables
var small_zombies_only: bool = false
var wave: int = 0
var difficulty: float = 0.0
var alive_cap: int = 0
var zombies_pending_spawn: int = 0
var enemies_killed: int = 0
var lifetime: float = 0.0
var is_wave_in_progress: bool = false
var is_dead: bool = true
var player_entered_new_room: bool = false

var alive_zombies: int = 0:
	set(value):
		alive_zombies = value
		if value <= 0 and _timer_spawn.is_stopped() and zombies_pending_spawn <= 0:
			_enemies_already_dead = true
			enemies_dead.emit()
			EventBus.wave_ended.emit(get_wave())
			is_wave_in_progress = false
			is_dead = true
		else:
			is_dead = false

var _enemies_already_dead: bool = false
var _spawn_position_nodes: Array[Node] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _enemies_list: Dictionary = {
	"zombie": preload("res://entities/enemy/zombie/enemy_zombie.tscn"),
}
#endregion

#region Private variables
var _timer_wave: Timer = Timer.new()
var _timer_spawn: Timer = Timer.new()
var _audio_round_change: AudioStreamPlayer = AudioStreamPlayer.new()
var _audio_round_end: AudioStreamPlayer = AudioStreamPlayer.new()
#endregion

#region Lifecycle methods
func _ready() -> void:
	add_child(_timer_wave)
	add_child(_timer_spawn)

	_timer_spawn.one_shot = true
	_timer_wave.one_shot = true
	_timer_spawn.process_mode = Node.PROCESS_MODE_INHERIT
	_timer_wave.process_mode = Node.PROCESS_MODE_INHERIT

	_timer_wave.timeout.connect(_on_timer_wave_timeout)
	_timer_spawn.timeout.connect(_on_timer_spawn_timeout)

	Global.wave_logic = self

	_spawn_position_nodes = _update_spawn_positions(spawn_positions)

	_audio_round_change.stream = load("uid://dxn1u1dpvqmop")
	_audio_round_end.stream = load("uid://uwkwynjax5yv")
	_audio_round_change.set_bus(&"sfx")
	_audio_round_end.set_bus(&"sfx")
	add_child(_audio_round_change)
	add_child(_audio_round_end)

	_rng.randomize()

	EventBus.game_enemy_killed.connect(_on_enemy_killed)
	EventBus.delete_all_spawn_positions.connect(_on_clear_spawns)
	EventBus.add_spawn_positions.connect(_on_add_spawns)
	EventBus.player_entered_new_battle_room.connect(_on_player_entered_new_battle_room)

	_timer_wave.start(time_between_waves)

	if &"wave_logic" in owner:
		owner.wave_logic = self


func _physics_process(delta: float) -> void:
	lifetime += delta
#endregion

#region Public methods
func get_wave() -> int:
	return wave + 1


func get_lifetime() -> float:
	return lifetime


func get_enemies_kill_count() -> int:
	return enemies_killed


func get_alive_cap(current_wave: int, player_count: int = 1) -> int:
	var base_cap: int = max_alive_at_once + (player_count * zombie_ai_per_player)

	var early_multipliers: Dictionary = {0: 0.2, 1: 0.4, 2: 0.6, 3: 0.8}
	if current_wave in early_multipliers:
		return int(base_cap * early_multipliers[current_wave])

	return base_cap


func get_zombies_for_wave(current_wave: int, player_count: int = 1) -> int:
	var multiplier: float = float(current_wave) / 5.0
	if current_wave >= 10:
		multiplier *= current_wave * 0.15
	var base: int = 6
	var per_player: int = zombie_ai_per_player
	return int(base + (per_player * player_count * multiplier)) + 1


func add_spawns(spawns: Array[Node]) -> void:
	_spawn_position_nodes.append_array(spawns)


func clear_spawns() -> void:
	spawn_positions.clear()
	_spawn_position_nodes.clear()


func delete_spawns(spawns: Array[Node]) -> void:
	for spawn: Node in spawns:
		_spawn_position_nodes.erase(spawn)
#endregion

#region Private methods
func _calculate_difficulty(current_display_wave: int) -> float:
	var norm_wave: float = clampf(
		float(current_display_wave) / float(wave_peak_difficulty), 0.0, 1.0
	)
	var base_diff: float = difficulty_curve.sample(norm_wave)

	if current_display_wave <= wave_peak_difficulty:
		return base_diff

	var waves_over_peak: float = float(current_display_wave - wave_peak_difficulty)
	var tail: float = log(1.0 + waves_over_peak) * 0.85

	return base_diff + tail


func _update_spawn_positions(paths: Array[NodePath]) -> Array[Node]:
	var nodes: Array[Node] = []
	for path: NodePath in paths:
		var node: Node = get_node_or_null(path)
		if node:
			nodes.append(node)
	return nodes


func _spawn_enemy(enemy_name: String) -> void:
	if not _enemies_list.has(enemy_name):
		DebugOutput.print_warning("Enemy not found: " + enemy_name)
		return

	difficulty = _calculate_difficulty(get_wave())

	var instance: Node = _enemies_list[enemy_name].instantiate()
	instance.difficulty = difficulty

	var spawn: Node = _spawn_position_nodes.pick_random()
	if spawn:
		spawn.add_child(instance)
	else:
		DebugOutput.print_warning("No available spawn points!")

	alive_zombies += 1
	is_dead = false


func _spawn_endless_wave() -> void:
	_audio_round_change.play()
	EventBus.wave_started.emit(get_wave())
	is_wave_in_progress = true
	is_dead = false

	alive_cap = get_alive_cap(wave, Global.players.size())
	var total_zombies: int = get_zombies_for_wave(get_wave(), Global.players.size())
	zombies_pending_spawn = total_zombies

	difficulty = _calculate_difficulty(get_wave())

	for _i: int in total_zombies:
		while alive_zombies >= alive_cap:
			await get_tree().create_timer(0.5, false).timeout

		var picked: PackedScene = _pick_random_enemy(endless_enemy_array)
		if not picked:
			DebugOutput.print_warning("pick_random_enemy returned null, skipping spawn slot")
			zombies_pending_spawn -= 1
			continue

		var instance: Node = picked.instantiate()
		instance.spawned_by_wave_logic = true
		instance.difficulty = difficulty

		var spawn: Node = _spawn_position_nodes.pick_random()
		var rng_offset: Vector3 = Vector3(
			_rng.randf_range(-0.15, 0.15),
			0,
			_rng.randf_range(-0.15, 0.15)
		)

		if spawn:
			spawn.add_child(instance)
			instance.position += rng_offset
		else:
			DebugOutput.print_warning("No available spawn points!")

		alive_zombies += 1
		is_dead = false
		zombies_pending_spawn -= 1

		var norm_wave: float = clampf(float(get_wave()) / float(wave_peak_difficulty), 0.0, 1.0)
		var base_diff: float = difficulty_curve.sample(norm_wave)
		var spawn_curve_clamp: float = clampf(base_diff, 0.001, 5.0)
		var spawn_delay: float = maxf(min_spawn_delay, time_between_spawns / spawn_curve_clamp)
		await get_tree().create_timer(spawn_delay, false).timeout

	if alive_zombies <= 0 and _enemies_already_dead:
		_enemies_already_dead = false
		_end_wave()
		return

	if alive_zombies <= 0:
		DebugOutput.print_warning("No enemies were spawned this wave, ending wave manually")
		is_wave_in_progress = false
		is_dead = true
		_end_wave()
		return

	_enemies_already_dead = false
	await enemies_dead
	_end_wave()


func _pick_random_enemy(array_enemy: Array) -> PackedScene:
	var picked_enemy: PackedScene = null

	if small_zombies_only:
		var small_enemies: Array = []
		for enemy: WaveLogicEnemy in array_enemy:
			if enemy.is_small:
				small_enemies.append(enemy)

		if small_enemies.is_empty():
			return null

		var small_total_weight: float = 0.0
		for enemy: WaveLogicEnemy in small_enemies:
			small_total_weight += enemy.spawn_weight

		var small_random_value: float = randf() * small_total_weight
		var small_cumulative_weight: float = 0.0
		for enemy: WaveLogicEnemy in small_enemies:
			small_cumulative_weight += enemy.spawn_weight
			if small_random_value <= small_cumulative_weight:
				picked_enemy = enemy.scene
				break

		return picked_enemy

	var check_diff: float = clampf(float(wave) / float(wave_peak_difficulty), 0.0, 1.0)

	var eligible_enemies: Array = []
	for enemy: WaveLogicEnemy in array_enemy:
		if not enemy.enabled:
			continue
		if enemy.difficulty_min > check_diff or enemy.difficulty_max < check_diff:
			continue
		if (wave + 1) < enemy.wave_min or (wave + 1) > enemy.wave_max:
			continue
		if enemy.spawn_every_n_wave_enabled and wave % enemy.spawn_every_n_wave != 0:
			continue
		eligible_enemies.append(enemy)

	if eligible_enemies.is_empty():
		return null

	var total_weight: float = 0.0
	for enemy: WaveLogicEnemy in eligible_enemies:
		total_weight += enemy.spawn_weight

	var random_value: float = randf() * total_weight
	var cumulative_weight: float = 0.0
	for enemy: WaveLogicEnemy in eligible_enemies:
		cumulative_weight += enemy.spawn_weight
		if random_value <= cumulative_weight:
			picked_enemy = enemy.scene
			break

	return picked_enemy


func _end_wave() -> void:
	wave += 1
	_audio_round_end.play()
	_timer_wave.start(time_between_waves)
#endregion

#region Event handlers
func _on_enemy_killed() -> void:
	alive_zombies = max(0, alive_zombies - 1)
	enemies_killed += 1


func _on_player_entered_new_battle_room(_arg: Variant) -> void:
	player_entered_new_room = true


func _on_timer_wave_timeout() -> void:
	if generate_wave_for_rooms:
		if not player_entered_new_room:
			await EventBus.player_entered_new_battle_room
	player_entered_new_room = false

	EventBus.emit_signal("ui_update_wave", get_wave())

	if not endless:
		if wave < wave_enemies_list.size():
			for enemy_name: String in wave_enemies_list[wave]:
				_spawn_enemy(enemy_name)
				await get_tree().create_timer(time_between_spawns, false).timeout
			wave += 1
		if wave < wave_enemies_list.size():
			_timer_wave.start(time_between_waves)
	else:
		if is_wave_in_progress:
			return
		_spawn_endless_wave()


func _on_timer_spawn_timeout() -> void:
	pass


func _on_add_spawns(spawns: Array[Node]) -> void:
	add_spawns(spawns)


func _on_clear_spawns() -> void:
	clear_spawns()
#endregion
