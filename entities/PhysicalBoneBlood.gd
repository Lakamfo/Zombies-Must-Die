extends PhysicalBone3D

@export var impact_power_threshold : float = 0.5

var previous_impulse : float = 0.0
var last_place_time : int = 0

var audio_steam_player : AudioStreamPlayer3D = AudioStreamPlayer3D.new()
var audio_stream : AudioStream = preload("res://entities/sounds/gib_sound.tres")


func _ready() -> void:
	PhysicsServer3D.body_set_max_contacts_reported(get_rid(), 4)

	audio_steam_player.stream = audio_stream
	add_child(audio_steam_player)


func _integrate_forces(state):
	var current_time : int = Time.get_ticks_msec()

	for i in range(state.get_contact_count()):
		var collider: Node = state.get_contact_collider_object(i)

		if is_instance_of(collider, Player):
			continue

		var pos: Vector3 = state.get_contact_local_position(i)
		var normal: Vector3 = state.get_contact_local_normal(i)
		var impulse: Vector3 = state.get_contact_impulse(i)
		var impulse_length: float = impulse.length()

		var rounded_impulse : float = round(impulse_length * 10) / 10
		if abs((rounded_impulse - previous_impulse)) > impact_power_threshold:
			if (current_time - last_place_time) > 1000:
				last_place_time = current_time

				audio_steam_player.play()
				VFXManager.place_decal(collider, normal, pos)

		previous_impulse = rounded_impulse
