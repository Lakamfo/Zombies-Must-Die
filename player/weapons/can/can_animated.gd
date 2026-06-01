extends FPSAnimation

@onready var cube: MeshInstance3D = $Bones/Skeleton3D/Cube
var mat: Material


func _ready() -> void:
	super._ready()
	mat = cube.mesh.surface_get_material(0)

	EventBus.bonus_activated.connect(
		func(bonus_id: StringName, _stacks: int):
			match bonus_id:
				&"quick_revive":
					mat.albedo_color = Color(0.51, 0.655, 0.702)
				&"juggernog":
					mat.albedo_color = Color(0.337, 0.196, 0.176)
				&"double_tap":
					mat.albedo_color = Color(0.447, 0.357, 0.169)
				&"speed_cola":
					mat.albedo_color = Color(0.2, 0.243, 0.173)
	)
