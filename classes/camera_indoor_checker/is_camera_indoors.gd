extends Node3D
class_name CameraIndoorsChecker

@export var min_distance : float = 1.0
@onready var ray_cast_3d: RayCast3D = $ray_cast_3d

var min_cutoff := 1500.0
var max_cutoff := 20000.0

var bus_effect : AudioEffectLowPassFilter
var bus_index : int 
var value : float = 0.0 :
	set(new_value):
		if value != new_value:
			value_changed.emit(new_value)
		
		value = new_value

var camera : Camera3D
var effect_enabled : bool = true
var min_distance_sq : float

signal value_changed(value : float)

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	
	bus_index = AudioServer.get_bus_index("sfx_outside")
	bus_effect = AudioServer.get_bus_effect(bus_index, 0)
	
	min_distance_sq = min_distance * min_distance

func _physics_process(delta: float) -> void:
	if not bus_effect:
		return
	
	var temp_value : float = value
	
	camera = get_viewport().get_camera_3d()
	
	global_position = camera.global_position
	
	if ray_cast_3d.is_colliding():
		var distance := ray_cast_3d.get_collision_point().distance_squared_to(global_position)
		temp_value += (delta if distance > min_distance_sq else -delta)
	else:
		temp_value -= delta
	
	value = clamp(temp_value, 0.0, 1.0)
	
	if value <= 0.0:
		if effect_enabled:
			AudioServer.set_bus_effect_enabled(bus_index, 0, false)
			effect_enabled = false
		return
	else:
		if not effect_enabled:
			AudioServer.set_bus_effect_enabled(bus_index, 0, true)
			effect_enabled = true

	var cutoff : float = lerp(min_cutoff, max_cutoff, 1.0 - value)
	bus_effect.cutoff_hz = cutoff
