extends InteractableItems

var is_playing: bool = false
var is_break: bool = false

@onready var video_stream_player: VideoStreamPlayer = $"../sub_viewport/canvas_layer/video_stream_player"
@onready var mesh: MeshInstance3D = $"../tv_game_ready/Cube_002"
@onready var sub_viewport: SubViewport = $"../sub_viewport"
@onready var spot_light_3d: SpotLight3D = $"../spot_light_3d"
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $"../audio_stream_player_3d"
@onready var animation_player: AnimationPlayer = $"../spot_light_3d/animation_player"


func _ready() -> void:
	var _mat: StandardMaterial3D = StandardMaterial3D.new()

	_mat.albedo_texture = sub_viewport.get_texture()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.set_surface_override_material(0, _mat)

	animation_player.play("change_colors")


func action():
	if is_break:
		return

	is_playing = !is_playing
	#spot_light_3d.visible = is_playing

	if is_playing:
		video_stream_player.play()
		audio_stream_player_3d.play()
		interactable_text = get_formatted_description("Turn off TV")
	else:
		video_stream_player.stop()
		audio_stream_player_3d.stop()
		interactable_text = get_formatted_description("Turn on TV")


func get_hit(_dmg: float = 0.0, _point: Vector3 = Vector3.ZERO):
	if is_break:
		return
	
	video_stream_player.stop()
	is_break = true

	video_stream_player.stop()
	audio_stream_player_3d.stop()
	spot_light_3d.hide()

	var _mat: StandardMaterial3D = StandardMaterial3D.new()

	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mesh.set_surface_override_material(0, _mat)

	interactable_text = ""
