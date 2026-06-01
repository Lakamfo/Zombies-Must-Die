extends Camera3D

func _ready() -> void:
	fov = get_owner().weapon_fov
