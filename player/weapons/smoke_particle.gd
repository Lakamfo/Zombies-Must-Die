extends Sprite3D

@onready var animation_player: AnimationPlayer = $animation_player
var _basis: Basis


func _ready() -> void:
	animation_player.play("smoke")


func _physics_process(delta: float) -> void:
	translate(Vector3(0.1, 0.1, 0.3) * delta * randi_range(-1, 1) * _basis)
