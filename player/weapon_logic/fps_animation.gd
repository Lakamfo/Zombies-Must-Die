class_name FPSAnimation
extends Node3D

@export var animations_strings: String

@export var animate_camera: bool = true
@export var camera_animate_node: Node3D
@export var animation_player: AnimationPlayer
@export var audio_stream_player: AudioStreamPlayer3D

var animations = AnimationsPack.new()

var model_materials: Array[BaseMaterial3D] = _init_materials()

var current_fov: float = GraphicsSettings.weapon_camera_fov:
	set(value):
		_update_mats()

signal animation_ended


class AnimationsPack:
	var _animations_pack: PackedStringArray
	var _pack_size: int = -1


	func parse(data: String, splitter: String = ",") -> void:
		_animations_pack = data.split(splitter, false)

		_pack_size = _animations_pack.size() - 1


	func get_size() -> int:
		return _pack_size


	func get_pack() -> PackedStringArray:
		return _animations_pack


	func get_rand_animation() -> String:
		if _pack_size > -1:
			return _animations_pack[randi_range(0, _pack_size)]
		else:
			return "null"


func _ready() -> void:
	animations.parse(animations_strings)

	if animation_player:
		animation_player.animation_finished.connect(
			func(_animation: String):
				visible = false
				Global.player.camera_weapon_animation.rotation_degrees = Vector3.ZERO
				animation_ended.emit()
		)

	EventBus.update_settings.connect(
		func():
			current_fov = GraphicsSettings.weapon_camera_fov
	)


func _init_materials() -> Array[BaseMaterial3D]:
	var materials: Array[BaseMaterial3D] = []

	for children in SceneTreeUtils.get_all_children(self):
		if children is MeshInstance3D:
			if children.mesh is ArrayMesh:
				var s_m: ArrayMesh = children.mesh
				var surface_count: int = s_m.get_surface_count()

				for i in surface_count:
					var _mat: = s_m.surface_get_material(i)
					if _mat is BaseMaterial3D:
						materials.append(_mat)

			if children.mesh is PrimitiveMesh:
				materials.append(children.mesh.material)

	return materials


func _update_mats() -> void:
	for mat in model_materials:
		if GraphicsSettings.render_on_sinlge_layer:
			mat.use_fov_override = true
			mat.use_z_clip_scale = true
			mat.z_clip_scale = 0.1
			
			mat.fov_override = current_fov
		else:
			mat.use_fov_override = false
			mat.use_z_clip_scale = false


func _process(_delta: float) -> void:
	if visible and camera_animate_node and animate_camera:
		Global.player.camera_weapon_animation.rotation_degrees = camera_animate_node.rotation_degrees


func play() -> void:
	if not visible:
		visible = true

	if animation_player and animations.get_size() > -1:
		animation_player.stop(false)
		animation_player.play(animations.get_rand_animation())

	if audio_stream_player:
		audio_stream_player.play()
		audio_stream_player.pitch_scale = randf_range(0.9, 1.1)
