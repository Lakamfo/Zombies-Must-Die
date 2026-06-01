extends InteractableItems

@export var light: Light3D
@export var mesh: MeshInstance3D
@export var gi: VisualInstance3D


func get_hit(_dmg: float = 0, _point: Vector3 = Vector3.ZERO):
	if light and is_instance_valid(light):
		light.queue_free()
	if mesh and is_instance_valid(mesh):
		mesh.queue_free()

	if not (gi is VoxelGI or gi is LightmapGI or gi is LightmapGIDynamic):
		DebugOutput.print_warning('%s, gi should be voxelgi or lightmap gi' % self)
		return

	if gi and is_instance_valid(gi):
		if gi is LightmapGI:
			gi.light_data = null

			if 'disabled' in gi:
				gi.disabled = true
		else:
			gi.data = null
