extends Node
class_name SceneTreeUtils

static func get_all_children(in_node, array: Array[Node] = []) -> Array[Node]:
	array.push_back(in_node)

	for child in in_node.get_children():
		array = get_all_children(child, array)

	return array
