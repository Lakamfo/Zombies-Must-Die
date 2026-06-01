extends AudioStreamPlayer3D
class_name FootStepsModule

@export var base_delay: float = 0.5
var delay: float = 0.5
@export var is_enabled: bool = true
@onready var ray_cast_3d: RayCast3D = $ray_cast_3d

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

@export var character_body: CharacterBody3D

var current_material: String:
	set(value):
		if value != current_material:
			current_material = value
			material_changed.emit(value)

var timer: float = 0.0
signal material_changed(material: String)


func _physics_process(delta: float) -> void:
	if !is_enabled:
		return

	timer += delta

	if character_body is Player:
		delay = base_delay / (character_body.current_speed / character_body.default_speed)

	if timer >= delay:
		if (character_body.is_on_floor() or ray_cast_3d.is_colliding()) && character_body.velocity.length() > 0.2:
			var collider: Node3D

			if ray_cast_3d.is_colliding():
				collider = ray_cast_3d.get_collider()

			var material = MaterialHelper.get_material(collider).strip_edges()

			if material != null:
				play_sound(material)

			timer = 0


func force_play():
	var collider: Node3D

	if ray_cast_3d.is_colliding():
		collider = ray_cast_3d.get_collider()

	var material = MaterialHelper.get_material(collider).strip_edges()
	current_material = material

	if material != null:
		play_sound(material)


func play_sound(material_name: String):
	if StreamBank.get(material_name):
		stream = StreamBank.get(material_name)
		if material_name in volume_list.keys():
			volume_db = linear_to_db(volume_list[material_name])
		play()
	current_material = material_name
