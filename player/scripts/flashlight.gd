extends SpotLight3D

var audio_stream_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
var texture := preload("uid://dmww5pemy0xm5")

@export var audio: AudioStream = preload("res://sounds/sfx/flashlight/button_press.mp3")


func _ready() -> void:
	audio_stream_player.stream = audio
	audio_stream_player.max_polyphony = 5

	check_shadows()
	add_child(audio_stream_player)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("flashlight"):
		visible = not visible
		check_shadows()

		audio_stream_player.pitch_scale = randf_range(0.9, 1.1)
		audio_stream_player.play()


func check_shadows() -> void:
	if shadow_enabled and not light_projector:
		light_projector = texture
	elif not shadow_enabled:
		light_projector = null
