extends Node
class_name GraphicsUtils

enum ShadersQuality {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
}

enum ShadowsQuality {
	ORTHOGONAL = 0,
	PARALLEL_2_SPLITS = 1,
	PARALLEL_4_SPLITS = 2,
}


static func remove_pbr_textures_array(
	nodes: Array,
	disable_texture: bool = false,
	shaders_quality: ShadersQuality = ShadersQuality.LOW
) -> void:
	var time_start: int = Time.get_ticks_usec()

	for node in nodes:
		remove_pbr_textures(node, disable_texture, shaders_quality)

	var elapsed: int = Time.get_ticks_usec() - time_start
	DebugOutput.print_debug_unique(
		"%d nodes : Removing PBR textures took %d usecs" % [nodes.size(), elapsed]
	)


static func remove_pbr_textures(
	node: Node,
	disable_texture: bool = false,
	shaders_quality: ShadersQuality = ShadersQuality.LOW
) -> void:
	if not node is GeometryInstance3D:
		return
	
	# Material slot (e.g. CSGShape3D)
	if "material" in node:
		node.material = _clean_mat(node.material, disable_texture, shaders_quality)

	# material_override takes priority over mesh materials; skip ShaderMaterial
	if node.material_override:
		if not node.material_override is ShaderMaterial:
			node.material_override = _clean_mat(
				node.material_override, disable_texture, shaders_quality
			)
		return

	# Per-surface materials on ArrayMesh
	if "mesh" in node and node.mesh is ArrayMesh:
		_clean_array_mesh(node.mesh, disable_texture, shaders_quality)
		return

	# Fallback - mesh-level material (primitives, etc.)
	if (
		node is MeshInstance3D and
		node.mesh and node.mesh.material
		and node.mesh.material is not ShaderMaterial
	):
		node.mesh.material = _clean_mat(node.mesh.material, disable_texture, shaders_quality)



static func update_lighting(
	nodes: Array,
	dynamic_shadows_enabled: bool = false,
	shadows_quality: ShadowsQuality = ShadowsQuality.ORTHOGONAL
) -> void:
	for node in nodes:
		if node is Light3D:
			node.shadow_enabled = dynamic_shadows_enabled
		if node is DirectionalLight3D:
			node.directional_shadow_mode = shadows_quality


static func change_shadows_mode(
	light: DirectionalLight3D,
	quality: ShadowsQuality = ShadowsQuality.PARALLEL_2_SPLITS
) -> void:
	if light == null:
		return

	match quality:
		ShadowsQuality.ORTHOGONAL:
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		ShadowsQuality.PARALLEL_2_SPLITS:
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		ShadowsQuality.PARALLEL_4_SPLITS:
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


static func get_average_color(texture: Texture2D) -> Color:
	if texture == null:
		return Color.WHITE

	var image: Image = texture.get_image()
	if image == null:
		return Color.WHITE

	if image.is_compressed():
		image.decompress()

	var total_color := Color(0.0, 0.0, 0.0, 0.0)
	var pixel_count: int = 0

	# Sample every other pixel for performance
	for x in range(0, image.get_width(), 2):
		for y in range(0, image.get_height(), 2):
			total_color += image.get_pixel(x, y)
			pixel_count += 1

	return total_color / pixel_count if pixel_count > 0 else Color.WHITE


static func is_opengl() -> bool:
	return RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_OTHER


static func _clean_array_mesh(
	mesh: ArrayMesh,
	disable_texture: bool,
	shaders_quality: ShadersQuality
) -> void:
	for i in mesh.get_surface_count():
		var mat = mesh.surface_get_material(i)
		if mat is StandardMaterial3D:
			mesh.surface_set_material(i, _clean_mat(mat, disable_texture, shaders_quality))


static func _clean_mat(
	material: BaseMaterial3D,
	disable_texture: bool,
	shaders_quality: ShadersQuality
) -> BaseMaterial3D:
	if material == null:
		return null

	# High quality - leave material untouched
	if shaders_quality == ShadersQuality.HIGH:
		return material

	# ORM material - only strip the ORM texture
	if material is ORMMaterial3D:
		material.orm_texture = null
		return material

	_apply_quality_settings(material, shaders_quality)
	_strip_unused_maps(material, disable_texture)

	return material


static func _apply_quality_settings(
	material: BaseMaterial3D,
	shaders_quality: ShadersQuality
) -> void:
	if shaders_quality == ShadersQuality.LOW:
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# ALPHA_HASH is cheaper than ALPHA and does not require draw order sorting
	if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH


static func _strip_unused_maps(material: BaseMaterial3D, disable_texture: bool) -> void:
	material.normal_enabled     = false
	material.refraction_enabled = false
	material.heightmap_enabled  = false
	material.roughness_texture  = null
	material.metallic_texture   = null

	if disable_texture:
		material.albedo_color   = get_average_color(material.albedo_texture)
		material.albedo_texture = null
