@tool
extends EditorScript

class_name CSGCombinerUnpacker

static func unpack_csg_combiner(csg_combiner: CSGCombiner3D, parent: Node3D) -> void:
	if not csg_combiner or not parent:
		push_error("Invalid CSGCombiner or parent node")
		return

	var all_csg_children = _get_all_csg_children_recursive(csg_combiner)

	if all_csg_children.size() == 0:
		push_warning("CSGCombiner has no CSG children to unpack")
		return

	print("Unpacking %d CSG nodes from '%s'" % [all_csg_children.size(), csg_combiner.name])

	for csg_node in all_csg_children:
		var copied_node = _copy_csg_node(csg_node)
		copied_node.material = csg_combiner.material_overlay
		copied_node.use_collision = csg_combiner.use_collision
		parent.add_child(copied_node)
		copied_node.owner = parent.owner if parent.owner else parent

		copied_node.transform = csg_combiner.transform * csg_node.transform

		print("Unpacked: %s (type: %s)" % [copied_node.name, copied_node.get_class()])

	csg_combiner.queue_free()


static func _get_all_csg_children_recursive(parent: Node) -> Array:
	var csg_children = []

	for child in parent.get_children():
		if child is CSGPrimitive3D or child is CSGCombiner3D:
			if child is CSGCombiner3D:
				csg_children.append_array(_get_all_csg_children_recursive(child))
			else:
				csg_children.append(child)

	return csg_children

static func _copy_csg_node(original: Node) -> Node:
	var copy = null

	if original is CSGBox3D:
		copy = CSGBox3D.new()
		var original_box: CSGBox3D = original
		copy.size = original_box.size

	elif original is CSGSphere3D:
		copy = CSGSphere3D.new()
		var original_sphere: CSGSphere3D = original
		copy.radius = original_sphere.radius
		copy.radial_segments = original_sphere.radial_segments
		copy.rings = original_sphere.rings

	elif original is CSGCylinder3D:
		copy = CSGCylinder3D.new()
		var original_cylinder: CSGCylinder3D = original
		copy.radius = original_cylinder.radius
		copy.height = original_cylinder.height
		copy.sides = original_cylinder.sides

	elif original is CSGTorus3D:
		copy = CSGTorus3D.new()
		var original_torus: CSGTorus3D = original
		copy.inner_radius = original_torus.inner_radius
		copy.outer_radius = original_torus.outer_radius
		copy.sides = original_torus.sides
		copy.ring_sides = original_torus.ring_sides

	elif original is CSGMesh3D:
		copy = CSGMesh3D.new()
		var original_mesh: CSGMesh3D = original
		copy.mesh = original_mesh.mesh

	elif original is CSGCombiner3D:
		copy = CSGCombiner3D.new()
		var original_combiner: CSGCombiner3D = original
		copy.operation = original_combiner.operation

	else:
		copy = CSGBox3D.new()
		copy.name = original.name + "_copy"

	if copy is CSGShape3D and original is CSGShape3D:
		var original_shape: CSGShape3D = original
		var copy_shape: CSGShape3D = copy

		copy_shape.operation = original_shape.operation
		copy_shape.use_collision = original_shape.use_collision
		copy_shape.snap = original_shape.snap
		copy_shape.calculate_tangents = original_shape.calculate_tangents
		copy_shape.collision_layer = original_shape.collision_layer
		copy_shape.collision_mask = original_shape.collision_mask

		if original_shape.material_override:
			copy_shape.material_override = original_shape.material_override

	copy.name = original.name
	return copy


func _run() -> void:
	var selection = EditorInterface.get_selection()
	var selected_nodes = selection.get_selected_nodes()

	if selected_nodes.size() == 0:
		print("Please select a CSGCombiner3D node")
		return

	var selected_node = selected_nodes[0]

	if not selected_node is CSGCombiner3D:
		print("Selected node is not a CSGCombiner3D")
		return

	var parent = selected_node.get_parent()
	if not parent:
		print("Selected node has no parent")
		return

	unpack_csg_combiner(selected_node, parent)
	print("CSGCombiner completely unpacked!")


static func unpack_all_csg_combiners_in_scene(root: Node) -> void:
	var combiners = _find_all_csg_combiners(root)

	for combiner in combiners:
		var parent = combiner.get_parent()
		if parent:
			print("Unpacking: ", combiner.name)
			unpack_csg_combiner(combiner, parent)

	print("All CSGCombiners unpacked!")


static func _find_all_csg_combiners(root: Node) -> Array:
	var combiners = []

	if root is CSGCombiner3D:
		combiners.append(root)

	for child in root.get_children():
		combiners.append_array(_find_all_csg_combiners(child))

	return combiners
