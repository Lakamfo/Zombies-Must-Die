extends MeshInstance3D

@export var in_doors_camera_checker : CameraIndoorsChecker 

var disabled_by_settings : bool = false :
	set(value):
		disabled_by_settings = value
		if value:
			visible = false
		else:
			visible = true

func _ready() -> void:
	EventBus.update_settings.connect(_update_settings)
	_update_settings()
	if in_doors_camera_checker:
		in_doors_camera_checker.value_changed.connect(_value_changed)


func _value_changed(value : float) -> void:
	if disabled_by_settings:
		return
	
	if value < 0.99:
		visible = true
	else:
		visible = false
		return
	
	self.get_surface_override_material(0).set("shader_parameter/effect_strength", 1.0 - value)


func _update_settings() -> void:
	disabled_by_settings = not GraphicsSettings.water_puddles
