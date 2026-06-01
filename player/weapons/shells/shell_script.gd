extends RigidBody3D

@onready var audio_stream_player_3d: AudioStreamPlayer3D = $audio_stream_player_3d
@export var max_life_time: float = 5.0
@onready var animation: AnimationPlayer = $animation

var sound_played = false
var life_timer: float


func _physics_process(delta: float) -> void:
	life_timer += delta

	if (life_timer > max_life_time) and !audio_stream_player_3d.playing:
		animation.play("fade")
		await animation.animation_finished
		queue_free()

	if get_contact_count() > 0 and !sound_played and get_colliding_bodies() != []:
		if !(get_colliding_bodies().pick_random() is Player):
			sound_played = true
			audio_stream_player_3d.pitch_scale = randf_range(0.8, 1.2)
			audio_stream_player_3d.play()
