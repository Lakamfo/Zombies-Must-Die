extends Resource

class_name RecoilData

@export_group("HIP")
@export_subgroup('CAMERA')
@export var hip_camera_max_recoil_data: Array[Vector3]
@export var hip_camera_min_recoil_data: Array[Vector3]
@export var hip_camera_recoil_snappines: Array[Vector3]
@export var hip_camera_recoil_return_speed: Array[Vector3]
@export var hip_camera_recoil_delay: Array[float]
@export_subgroup('BODY')
@export var hip_body_max_recoil_data: Array[Vector3]
@export var hip_body_min_recoil_data: Array[Vector3]
@export var hip_body_recoil_snappines: Array[Vector3]
@export var hip_body_recoil_return_speed: Array[Vector3]
@export var hip_body_recoil_delay: Array[float]

@export_group("AIM")
@export_subgroup('CAMERA')
@export var aim_camera_max_recoil_data: Array[Vector3]
@export var aim_camera_min_recoil_data: Array[Vector3]
@export var aim_camera_recoil_snappines: Array[Vector3]
@export var aim_camera_recoil_return_speed: Array[Vector3]
@export var aim_camera_recoil_delay: Array[float]
@export_subgroup('BODY')
@export var aim_body_max_recoil_data: Array[Vector3]
@export var aim_body_min_recoil_data: Array[Vector3]
@export var aim_body_recoil_snappines: Array[Vector3]
@export var aim_body_recoil_return_speed: Array[Vector3]
@export var aim_body_recoil_delay: Array[float]
