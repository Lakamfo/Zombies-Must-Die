extends Resource

class_name GraphicsPreset

@export var preset_string = 'KEY_SETTINGS_ULTRA_LOW'
@export var graphics_preset: int = 0
@export var scaling_method: int = 0
@export var render_resolution: float = 100.0
@export var fsr_sharpness: float = 0.0
@export var ssao_preset: int = 0
@export var msaa_preset: int = 0
@export var main_camera_fov: float = 75.0
@export var weapon_camera_fov: float = 75.0
@export var shadow_quality: int = 0
@export var shaders_quality: int = 0
@export var shadows: bool = true
@export var fxaa: bool = true
@export var taa: bool = false
@export var glow: bool = true
@export var sdfgi: bool = false
@export var ssil: bool = false
@export var volumetric_fog: bool = true
@export var ssr: bool = false
@export var vfx: bool = true
@export var vegetation : bool = true
@export var water_puddles : bool = true
@export var single_layer_render: = true

@export var ignore_settings: Array[StringName] = [&'scaling_method', &'main_camera_fov', &'weapon_camera_fov']


func serialize() -> Dictionary:
	return {
		'graphics': {
			'graphics_preset': graphics_preset,
			'scaling_method': scaling_method,
			'render_resolution': render_resolution,
			'fsr_sharpness': fsr_sharpness,
			'ssao_preset': ssao_preset,
			'msaa_preset': msaa_preset,
			'main_camera_fov': 75.0,
			'weapon_camera_fov': 75.0,
			'shadow_quality': shadow_quality,
			'shaders_quality': shaders_quality,
			'shadows': shadows,
			'fxaa': fxaa,
			'taa': taa,
			'glow': glow,
			'sdfgi': sdfgi,
			'ssil': ssil,
			'volumetric_fog': volumetric_fog,
			'ssr': ssr,
			'vfx': vfx,
			'vegetation': vegetation,
			'water_puddles' : water_puddles,
			'single_layer_render': single_layer_render,
		},
	}


func matches(settings: Dictionary) -> bool:
	var preset_settings = serialize().get('graphics', { })

	for key in settings.keys():
		var key_sn = StringName(key)
		if key_sn in ignore_settings:
			continue

		if not preset_settings.has(key) or preset_settings[key] != settings[key]:
			return false

	return true
