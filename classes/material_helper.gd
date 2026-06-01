# "res://classes/MaterialHelper.gd"
extends Node

class_name MaterialHelper

static func setup_scene_materials(objects: Array[Node]):
	for child in objects:
		if child is CSGShape3D or child is PhysicsBody3D:
			var mat: StringName = get_material(child)

			child.set_meta(&"material", mat)


static func get_material(collider: Node3D):
	var material = "CONCRETE"

	if not collider:
		return material

	if collider.has_meta("material"):
		return collider.get_meta("material", "CONCRETE").strip_edges()

	if collider.get_parent() is CSGCombiner3D:
		var par: CSGCombiner3D = collider.get_parent()

		if par.material_overlay:
			return par.material_overlay.resource_name.strip_edges()
		elif par.material_override:
			return par.material_override.resource_name.strip_edges()

	if collider is MeshInstance3D and collider.mesh != null:
		var _material: Material = collider.get_active_material(0)
		if _material != null:
			return _material.resource_name.strip_edges()

	if "material" in collider:
		if collider.material != null:
			return collider.material.resource_name.strip_edges()

	elif collider.has_method("get_material_override"):
		if collider.material_override != null:
			return collider.material_override.resource_name.strip_edges()

	return material
