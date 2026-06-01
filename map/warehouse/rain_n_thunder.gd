extends Node3D


@export_category("Thunder Sound Reach (Sound Speed imitation)")
@export_range(0, 5, 0.5) var min_thunder_reach : float = 1.0
@export_range(0, 5, 0.5) var max_thunder_reach : float = 5.0

@export_category("Thunder delays (How fast it can be played again)")
@export_range(1, 100, 0.5) var min_thunder_delay : float = 10.0
@export_range(1, 100, 0.5) var max_thunder_delay : float = 48.0

@export_category("Thunder frames (How many frames of thunder is visible)")
@export_range(5, 30, 1) var min_thunder_flash_frames : int = 5
@export_range(5, 30, 1) var max_thunder_flash_frames : int = 10

@export_category("Nodes")
@export var omni_light : OmniLight3D
@export var thunder_player_sound : AudioStreamPlayer

var positions : Array[Marker3D]
var _timer : Timer = Timer.new()

var rng : RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	
	var childrens : Array[Node] = get_children()
	
	for child in childrens:
		if is_instance_of(child, Marker3D):
			positions.append(child)
	
	
	_timer.one_shot = false
	_timer.wait_time = rng.randf_range(min_thunder_delay, max_thunder_delay)
	
	_timer.timeout.connect(_timer_timeout)
	
	add_child(_timer)
	
	_timer.start()


func _timer_timeout() -> void:
	var tree : SceneTree = get_tree()
	var random_frames_count : int = rng.randi_range(min_thunder_flash_frames, max_thunder_flash_frames)
	var delay_time_before_sound : float = rng.randf_range(min_thunder_reach, max_thunder_reach)
	
	_timer.wait_time = rng.randf_range(min_thunder_delay, max_thunder_delay)
	
	if not omni_light and not thunder_player_sound:
		return
	
	omni_light.global_position = positions.pick_random().global_position
	
	omni_light.show()
	
	for i : int in random_frames_count:
		await tree.physics_frame
	
	omni_light.hide()
	
	await tree.create_timer(delay_time_before_sound, false).timeout
	
	thunder_player_sound.play()
