#"res://classes/map_gen/map_generator.gd"
@tool
extends Node

class_name MapGenerator

@export_tool_button("Generate")
var generate = generate_map

@export var config: RoomGenerationConfig
@export var room_templates: Array[RoomTemplate]
@export var gen_root: Node3D

enum types { start_room, room, hallway, shop, end }

var placed_rooms: Array = []
var room_id_counter: int = 0
var battle_room_counter: int = 0

var previous_room: Node3D
var previous_room_res: RoomTemplate
var current_room_res: RoomTemplate

var init_gen: bool = true

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var player_latest_entered_room_id: int = 0

signal s_generate_next_room


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	EventBus.player_entered_room.connect(
		func(id: int, battle: bool = false):
			if id == room_id_counter - 1:
				s_generate_next_room.emit()

			if id > player_latest_entered_room_id:
				player_latest_entered_room_id = id
				update_spawn_positions_for_room(id)

				EventBus.player_entered_new_room.emit(id)

				if not battle:
					return

				if not get_room_by_id(id).get_meta('type', 'room') in ["start_room", "hallway", "shop"]:
					EventBus.player_entered_new_battle_room.emit(id)
	)

	generate_map()
	update_nav_mesh()


func generate_map() -> void:
	clear_map()
	if config.rng_seed == -1:
		rng.randomize()
	else:
		rng.seed = config.rng_seed

	var start_room = get_random_room(types.start_room)
	if not start_room:
		push_error("No starting room!")
		return

	var start_instance = place_room(start_room)
	if not start_instance:
		return

	previous_room = start_instance
	placed_rooms.append(start_instance)

	for i in config.count:
		if not config.generate_at_once and not Engine.is_editor_hint():
			if placed_rooms.size() >= config.buffer:
				await s_generate_next_room
				placed_rooms[0].queue_free()
				placed_rooms.remove_at(0)

				update_nav_mesh()

		var new_room = generate_next_room(previous_room)

		if new_room:
			previous_room = new_room


func generate_next_room(_previous_room: Node3D) -> Node3D:
	previous_room_res = current_room_res

	var room_type: types = types.room
	var rand_float: float = rng.randf()

	if config.include_end and room_id_counter >= config.count:
		room_type = types.end
	elif config.include_shop and room_id_counter % 3 == 0:
		room_type = types.shop
	elif config.include_hallways and rand_float < 0.2:
		room_type = types.hallway

	var max_attempts = 50
	var new_room_res: RoomTemplate = null

	while max_attempts > 0:
		new_room_res = get_random_room(room_type)
		if new_room_res:
			break
		max_attempts -= 1

	if not new_room_res:
		return generate_next_room(previous_room)

	current_room_res = new_room_res

	for new_port in previous_room.find_children("exit"):
		var new_pos = new_port.global_position
		var new_room_instance = place_room(new_room_res)

		var new_entrance = new_room_instance.find_child("entrance")
		if not new_entrance:
			continue

		var offset = new_entrance.global_position - new_room_instance.global_position
		new_room_instance.global_position = new_pos - offset

		placed_rooms.append(new_room_instance)
		return new_room_instance

	return null


func get_random_room(room_type: types) -> RoomTemplate:
	var candidates = room_templates.filter(func(r): return r.type == room_type and r != previous_room_res)
	if candidates.is_empty():
		return null

	var total_weight = 0.0
	for room in candidates:
		total_weight += room.weight

	var rand_value = rng.randf() * total_weight
	var current_sum = 0.0

	for room in candidates:
		current_sum += room.weight
		if rand_value < current_sum:
			return room

	return null


func place_room(room_res: RoomTemplate) -> Node3D:
	var instance = room_res.scene.instantiate()

	if not instance:
		push_error("Failed to instantiate room!")
		return null

	instance.set_meta('type', room_res.get_type())
	instance.set_meta("id", room_id_counter)
	printt(instance.name, room_id_counter)
	if not room_res.get_type() in ["start_room", "hallway", "shop"]:
		instance.set_meta("battle_id", battle_room_counter)
		battle_room_counter += 1

	if previous_room_res:
		if previous_room_res.get_type() in ["start_room", "hallway", "shop"]:
			instance.set_meta("free_open", true)

	room_id_counter += 1

	if gen_root:
		gen_root.add_child(instance, true)
	instance.owner = self

	return instance


func clear_map() -> void:
	for room in placed_rooms:
		room.queue_free()

	placed_rooms.clear()
	room_id_counter = 0


func update_spawn_positions_for_room(room_id: int):
	for room in placed_rooms:
		if room.get_meta("id") == room_id:
			var spawn_points = room.find_children("spawn_position*")

			EventBus.delete_all_spawn_positions.emit()
			EventBus.add_spawn_positions.emit(spawn_points)
			break


func get_room_by_id(room_id: int) -> Node3D:
	var _room: Node3D

	for room in placed_rooms:
		if room.get_meta("id") == room_id:
			_room = room
			break

	return _room


func update_nav_mesh() -> void:
	# TODO: Add navmesh update logic here. Done
	EventBus.update_navigation_mesh.emit()
