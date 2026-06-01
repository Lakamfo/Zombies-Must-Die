extends Node

var materials : Dictionary[StringName, String] = {
	&"zombie_explosive_1":"res://entities/enemy/zombie/explosive_zombie_mat_1.tres",
	&"zombie_1":"res://entities/enemy/zombie/zombie_mat_1.tres",
	&"zombie_2":"res://entities/enemy/zombie/zombie_mat_2.tres",
}

var cached_materials : Dictionary[StringName, BaseMaterial3D] = { }


func _ready() -> void:
	EventBus.scene_changed.connect(_clear_cache)


func get_material(
	mat_name : StringName
	) -> BaseMaterial3D:
	
	var mat : BaseMaterial3D = null
	
	if mat_name in cached_materials.keys():
		return cached_materials[mat_name]
	
	if mat_name in materials.keys():
		mat = load(materials[mat_name]) 
		cached_materials[mat_name] = mat
		
		return mat
	
	return null


func _clear_cache() -> void:
	cached_materials.clear()
