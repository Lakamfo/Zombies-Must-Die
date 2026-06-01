# lantern_light.gd
extends SpotLight3D

@export var delay_before_on: float = 2.5 
@export var turn_on_duration: float = 0.8   
@export var energy_min: float = 0.85
@export var energy_max: float = 1.15
@export var flicker_speed: float = 0.9

var base_energy: float = 1.0
var noise: FastNoiseLite = FastNoiseLite.new()
var noise_offset: float = 0.0

func _ready() -> void:
	base_energy = light_energy 
	light_energy = 0.0

	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.8

	noise_offset = randf_range(0.0, 100.0)

	_start_sequence()


func _start_sequence() -> void:
	await get_tree().create_timer(delay_before_on, true).timeout

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "light_energy", base_energy, turn_on_duration)


func _process(delta: float) -> void:
	if light_energy <= 0.01:
		return 

	noise_offset += delta * flicker_speed
	var n: float = noise.get_noise_1d(noise_offset)
	var target: float = remap(n, -1.0, 1.0, energy_min, energy_max)
	light_energy = lerpf(light_energy, base_energy * target, delta * 4.0)
