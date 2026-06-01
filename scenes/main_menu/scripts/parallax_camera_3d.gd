extends Camera3D

@export var min_rot: Vector3 = Vector3.ZERO
@export var max_rot: Vector3 = Vector3.ZERO
@export var input_noise: bool = true
@onready var default_rot: Vector3 = rotation_degrees
const MOUSE_SENS: float = 0.002
var rot: Vector2
var lerp_rot: Vector2

var init : bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rot += event.relative * MOUSE_SENS

func _ready() -> void:
	default_rot = rotation_degrees
	init = true


func _process(_delta: float) -> void:
	if not init:
		return
	
	if input_noise:
		rot += Vector2(randf_range(-10, 10), randf_range(-10, 10)) * MOUSE_SENS
	rotation_degrees = lerp(rotation_degrees, default_rot + Vector3(rot.y, rot.x, -rot.x), 5.0 * SystemInfo.fixed_delta_procces)

	rotation_degrees.y = clamp(rotation_degrees.y, min_rot.y, max_rot.y)
	rotation_degrees.x = clamp(rotation_degrees.x, min_rot.x, 0)

	lerp_rot = lerp(lerp_rot, rot, 1.0 * SystemInfo.fixed_delta_procces)
	rot = lerp(rot, Vector2.ZERO, 1.0 * SystemInfo.fixed_delta_procces)
