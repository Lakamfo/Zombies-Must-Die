extends Decal

@onready var audio_stream_player_3d: AudioStreamPlayer3D = $audio_stream_player_3d
@onready var gpu_particles_3d: GPUParticles3D = $gpu_particles_3d
@onready var collider

@export var area: Area3D

@export var volume_list: Dictionary = {
	"CARPET": 1.0,
	"CONCRETE": 1.0,
	"DIRT": 1.0,
	"GLASS": 1.0,
	"GRASS": 0.3,
	"GRAVEL": 1.0,
	"LADDER": 1.0,
	"METAL_CHAINLINK": 1.0,
	"METAL_GRATE": 1.0,
	"METAL_SOLID": 1.0,
	"MUD": 1.0,
	"RUBBER": 1.0,
	"SAND": 1.0,
	"SNOW": 1.0,
	'TILE': 1.0,
	"WOOD": 1.0,
}

var materials_particles: Dictionary = {
	"METAL": [preload("res://player/weapons/bullet_hole/metal/sparkles.tres"), preload("res://player/weapons/bullet_hole/metal/sparkles_draw.tres")],
	"CONCRETE": [preload("res://player/weapons/bullet_hole/concrete/concrete.tres"), preload("res://player/weapons/bullet_hole/concrete/concrete_draw.tres")],
	"SAND": [preload("res://player/weapons/bullet_hole/sand/sand.tres"), preload("res://player/weapons/bullet_hole/sand/sand_draw.tres")],
	"FLESH": [preload("res://player/weapons/bullet_hole/flesh/flesh.tres"), preload("res://player/weapons/bullet_hole/flesh/flesh_draw.tres")],
}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	await get_tree().physics_frame
	gpu_particles_3d.emitting = true
	gpu_particles_3d.finished.connect(gpu_particles_3d.queue_free)
	
	if collider:
		var mat: String = MaterialHelper.get_material(collider)
		if materials_particles.has(mat):
			gpu_particles_3d.process_material = materials_particles[mat][0]
			gpu_particles_3d.draw_pass_1 = materials_particles[mat][1]
		
		play_sound(mat)


func play_sound(_material_name: String):
	var material_name = _material_name + "_HIT"

	audio_stream_player_3d.pitch_scale = randf_range(0.9, 1.1)

	if StreamBank.get(material_name):
		audio_stream_player_3d.stream = StreamBank.get(material_name)

		if volume_list.has(material_name):
			audio_stream_player_3d.volume_db = linear_to_db(volume_list[material_name])

		audio_stream_player_3d.play()
