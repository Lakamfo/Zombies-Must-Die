extends Area3D


@export var bonus_id: String = &"instant_kill"
@export var random: bool = true

@onready var animation_player: AnimationPlayer = $animation_player
@onready var mesh_instance_3d: MeshInstance3D = $mesh_instance_3d
@onready var omni_light_3d: OmniLight3D = $omni_light_3d

var audio_stream_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _process(delta: float) -> void:
	mesh_instance_3d.rotate_y(delta)
	mesh_instance_3d.rotate_z(delta)


func _ready() -> void:
	self.body_entered.connect(_on_body_entered)
	
	if random:
		var bonus = Global.bonus_registry.get_random_pickup_bonus()
		if bonus:
			bonus_id = bonus.id
	
	animation_player.play("animation")
	
	audio_stream_player.finished.connect(audio_stream_player.queue_free)
	audio_stream_player.set_bus(&"sfx")
	
	omni_light_3d.position.y -= 1
	
	_setup_visual_for_bonus()


func _setup_visual_for_bonus() -> void:
	var bonus = Global.bonus_registry.get_bonus(bonus_id)
	if bonus == null:
		queue_free()
		return
	
	if bonus.mesh:
		mesh_instance_3d.mesh = bonus.mesh
	
	match bonus_id:
		"instant_kill":
			omni_light_3d.position.y = 0
		_:
			pass
	
	var sound_path = "res://objects/interactable/pickup/sounds/%s.mp3" % bonus_id
	if ResourceLoader.exists(sound_path):
		audio_stream_player.stream = load(sound_path)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		Global.bonus_controller.activate_bonus(bonus_id)
		
		add_sibling(audio_stream_player)
		audio_stream_player.play()
		
		queue_free()
