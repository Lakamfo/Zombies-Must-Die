extends ScrollContainerMouse

@export var delayed_saver_manager: DelayedSaverManager
@export var config_file_handler: ConfigFileHandler
@export var graphics_presets: Array[GraphicsPreset]

var ignore_graphics_option_timer: Timer = Timer.new()
var first_run: bool = true

@onready var ui_elements: Dictionary[StringName, Dictionary] = {
	&'graphics_preset': {
		&'label': %graphics_preset_label,
		&'option_button': %graphic_preset_option,
		&'container': %graphics_preset_container,
	},
	&'scaling_method': {
		&'label': %scaling_label,
		&'option_button': %option_scaling_method,
		&'container': %scaling_method_container,
	},
	&'render_resolution': {
		&'label': %render_resolution_label,
		&'slider': %render_resolution_slider,
		&'container': %render_resolution_container,
	},
	&'fsr_sharpness': {
		&'label': %fsr_sharpness_label,
		&'slider': %fsr_sharpness_slider,
		&'container': %fsr_sharpness_container,
	},
	&'ssao_preset': {
		&'label': %ssao_preset_label,
		&'option_button': %ssao_preset_option,
		&'container': %ssao_preset_container,
	},
	&'msaa_preset': {
		&'label': %msaa_label,
		&'option_button': %msaa_option,
		&'container': %msaa_preset_container,
	},
	&'shadow_quality': {
		&'label': %shadow_qual_label,
		&'option_button': %shadows_option,
		&'container': %shadow_quality_container,
	},
	&'shaders_quality': {
		&'label': %shaders_qual_label,
		&'option_button': %shaders_option,
		&'container': %shaders_quality_container,
	},
	&'main_camera_fov': {
		&'label': %camera_fov_label,
		&'slider': %camera_fov_slider,
		&'container': %main_camera_fov_container,
	},
	&'weapon_camera_fov': {
		&'label': %weapon_camera_fov_label,
		&'slider': %weapon_camera_fov_slider,
		&'container': %weapon_camera_fov_container,
	},
	&'shadows': {
		&'label': %shadows_label,
		&'check_button': %shadows_button,
		&'container': %shadows_container,
	},
	&'fxaa': {
		&'label': %fxaa_label,
		&'check_button': %fxaa_button,
		&'container': %fxaa_container,
	},
	&'taa': {
		&'label': %taa_label,
		&'check_button': %taa_button,
		&'container': %taa_container,
	},
	&'glow': {
		&'label': %glow_label,
		&'check_button': %glow_button,
		&'container': %glow_container,
	},
	&'sdfgi': {
		&'label': %sdfgi_label,
		&'check_button': %sdfgi_button,
		&'container': %sdfgi_container,
	},
	&'ssil': {
		&'label': %ssil_label,
		&'check_button': %ssil_button,
		&'container': %ssil_container,
	},
	&'volumetric_fog': {
		&'label': %volumetric_fog_label,
		&'check_button': %volumetric_fog_button,
		&'container': %volumetric_fog_container,
	},
	&'ssr': {
		&'label': %ssr_label,
		&'check_button': %ssr_button,
		&'container': %ssr_container,
	},
	&'vegetation': {
		&'label': %veg_label,
		&'check_button': %veg_button,
		&'container': %vegetation_container,
	},
	&'water_puddles': {
		&'label': %water_label,
		&'check_button': %water_button,
		&'container': %water_container,
	},
	&'vfx': {
		&'label': %vfx_label,
		&'check_button': %vfx_button,
		&'container': %vfx_container,
	},
	&'single_layer_render': {
		&'label': %single_layer_render_label,
		&'check_button': %single_layer_render_button,
		&'container': %single_layer_render_container,
	},
}

@export var default_config: GraphicsPreset

var ignore_preset_selection_signal: bool = false


func _ready() -> void:
	super()
	
	await owner.locale_loaded

	ignore_graphics_option_timer.one_shot = true
	ignore_graphics_option_timer.wait_time = 0.5
	add_child(ignore_graphics_option_timer)

	init_option_buttons()
	init_signals()

	var loaded_graphics = config_file_handler.config_load_filtered(default_config.serialize())
	apply_and_select_preset(loaded_graphics['graphics'])

	first_run = false


func restore_settings_from_config(preset: Dictionary, called_from_option: bool = false, graphics_preset_res: GraphicsPreset = default_config) -> void:
	var graphics_dict: Dictionary = preset
	var ignore_settings_array: Array[StringName] = graphics_preset_res.ignore_settings

	ignore_preset_selection_signal = true

	for key in graphics_dict.keys():
		var value = graphics_dict[key]
		var key_sn := StringName(key)

		if not ui_elements.has(key_sn):
			continue
		var element := ui_elements[key_sn]

		if key_sn in ignore_settings_array and (called_from_option or not first_run):
			continue

		if element.has("option_button"):
			element["option_button"].select(value)
			element["option_button"].item_selected.emit(value)
		elif element.has("slider"):
			element["slider"].value = value
			element["slider"].value_changed.emit(value)
		elif element.has("check_button"):
			element["check_button"].button_pressed = value
			element["check_button"].toggled.emit(value)

	ignore_preset_selection_signal = false


func init_option_buttons() -> void:
	var graphics_option: OptionButton = ui_elements[&'graphics_preset'][&'option_button']
	var preset_index: int = 0
	graphics_option.clear()

	for preset: GraphicsPreset in graphics_presets:
		graphics_option.add_item(preset.preset_string)
		preset.graphics_preset = preset_index

		preset_index += 1
	graphics_option.add_item('KEY_SETTINGS_CUSTOM')


func on_setting_changed():
	if ignore_preset_selection_signal:
		return

	var current_settings = get_current_settings()
	var preset_index = find_matching_preset(current_settings)
	var graphics_option = ui_elements[&'graphics_preset'][&'option_button'] as OptionButton

	if graphics_option.selected != preset_index:
		graphics_option.select(preset_index)

	EventBus.update_settings.emit()


func init_signals() -> void:
	#region Graphics Preset
	(ui_elements[&'graphics_preset'][&'option_button'] as OptionButton).item_selected.connect(
		func(index: int):
			if index >= 0 and index < graphics_presets.size() and ignore_graphics_option_timer.is_stopped():
				var preset := graphics_presets[index]
				ignore_graphics_option_timer.start()
				restore_settings_from_config(preset.serialize()['graphics'], first_run)
			config_file_handler.config_save({ 'graphics': { 'graphics_preset': index } })
	)
	#endregion

	#region Scaling Method

	(ui_elements[&'scaling_method'][&'option_button'] as OptionButton).item_selected.connect(
		func(index: int):
			config_file_handler.config_save({ 'graphics': { 'scaling_method': index } })
			on_setting_changed()
	)
	#endregion

	#region Render Resolution
	get_viewport().size_changed.connect(
		func update_res_label():
			var value: int = int((ui_elements[&'render_resolution'][&'slider'] as HSlider).value)
			@warning_ignore("integer_division")
			(ui_elements[&'render_resolution'][&'label'] as Label).text = \
			tr("KEY_SETTING_RENDER_RESOLUTION") % [
				value,
				get_viewport().size.x * (value / 100),
				get_viewport().size.y * (value / 100),
			]
	)

	(ui_elements[&'render_resolution'][&'slider'] as HSlider).value_changed.connect(
		func(value: float):
			var text: String = (tr("KEY_SETTING_RENDER_RESOLUTION") % [value, get_viewport().size.x * (value / 100.0), get_viewport().size.y * (value / 100.0)])
			(ui_elements[&'render_resolution'][&'label'] as Label).text = text
			get_viewport().scaling_3d_scale = value / 100.0

			delayed_saver_manager.trigger_delayed_call(
				"render_resolution_save",
				1.0,
				func():
					config_file_handler.config_save({ 'graphics': { 'render_resolution': value } })
			)
			on_setting_changed()
	)
	#endregion

	#region FSR Sharpness
	(ui_elements[&'fsr_sharpness'][&'slider'] as HSlider).value_changed.connect(
		func(value: float):
			(ui_elements[&'fsr_sharpness'][&'label'] as Label).text = \
			tr("KEY_SETTING_FSR_SHARPNESS") % [value]

			delayed_saver_manager.trigger_delayed_call(
				"fsr_sharpness_save",
				1.0,
				func():
					config_file_handler.config_save({ 'graphics': { 'fsr_sharpness': value } })
			)
			on_setting_changed()
	)
	#endregion

	#region SSAO Preset
	(ui_elements[&'ssao_preset'][&'option_button'] as OptionButton).item_selected.connect(
		func(index: int):
			config_file_handler.config_save({ 'graphics': { 'ssao_preset': index } })
			GraphicsSettings.ssao_setting = index
			on_setting_changed()
	)
	#endregion

	#region MSAA Preset
	(ui_elements[&'msaa_preset'][&'option_button'] as OptionButton).item_selected.connect(
		func(index: int):
			config_file_handler.config_save({ 'graphics': { 'msaa_preset': index } })
			get_viewport().msaa_3d = index as Viewport.MSAA
			on_setting_changed()
	)
	#endregion

	#region Shadow Quality
	(ui_elements[&'shadow_quality'][&'option_button'] as OptionButton).item_selected.connect(
		func(index: int):
			config_file_handler.config_save({ 'graphics': { 'shadow_quality': index } })
			GraphicsSettings.shadows_quality = index as GraphicsUtils.ShadowsQuality
			on_setting_changed()
	)
	#endregion

	#region Shaders Quality
	(ui_elements[&'shaders_quality'][&'option_button'] as OptionButton).item_selected.connect(
		func(index: int):
			config_file_handler.config_save({ 'graphics': { 'shaders_quality': index } })
			GraphicsSettings.shaders_quality = index as GraphicsUtils.ShadersQuality
			on_setting_changed()
	)
	#endregion

	#region Camera FOVs
	(ui_elements[&'main_camera_fov'][&'slider'] as HSlider).value_changed.connect(
		func(value: float):
			config_file_handler.config_save({ 'graphics': { 'main_camera_fov': value } })
			(ui_elements[&'main_camera_fov'][&'label'] as Label).text = \
			tr("KEY_SETTING_CAMERA_FOV") % [value]
			GraphicsSettings.camera_fov = int(value)
			on_setting_changed()
	)

	(ui_elements[&'weapon_camera_fov'][&'slider'] as HSlider).value_changed.connect(
		func(value: float):
			config_file_handler.config_save({ 'graphics': { 'weapon_camera_fov': value } })
			(ui_elements[&'weapon_camera_fov'][&'label'] as Label).text = \
			tr("KEY_SETTING_WEAPON_CAMERA_FOV") % [value]
			GraphicsSettings.weapon_camera_fov = int(value)
			on_setting_changed()
	)
	#endregion

	#region Toggles
	var toggles: Array = [
		&'shadows',
		&'fxaa',
		&'taa',
		&'glow',
		&'sdfgi',
		&'ssil',
		&'volumetric_fog',
		&'ssr',
		&'vfx',
		&"vegetation",
		&"water_puddles",
		&'single_layer_render',
	]

	for toggle_key in toggles:
		(ui_elements[toggle_key][&'check_button'] as CheckButton).toggled.connect(
			func(value: bool, key: StringName = toggle_key):
				config_file_handler.config_save({ 'graphics': { key: value } })
				var key_2_var: Dictionary[StringName, StringName] = {
					&'shadows': &'dynamic_shadows_enabled',
					&'fxaa': &'fxaa_enabled',
					&'sdfgi': &'sdfgi_enabled',
					&'ssil': &'ssil_enabled',
					&'volumetric_fog': &'volumetric_fog_enabled',
					&'ssr': &'ssr_enabled',
					&'vfx': &'decals_enabled',
					&"water_puddles": &"water_puddles",
					&"vegetation": &"vegetation",
					&'single_layer_render': &'render_on_sinlge_layer',
				}

				match key:
					&'fxaa':
						if value:
							get_viewport().set_screen_space_aa(Viewport.SCREEN_SPACE_AA_FXAA)
						else:
							get_viewport().set_screen_space_aa(Viewport.SCREEN_SPACE_AA_DISABLED)

				if key in key_2_var:
					if key_2_var[key] in GraphicsSettings:
						GraphicsSettings.set(key_2_var[key], value)

				on_setting_changed()
		)
	#endregion


func get_current_settings() -> Dictionary:
	var result := { }
	for key_sn in ui_elements.keys():
		var element = ui_elements[key_sn]
		if element.has("option_button"):
			result[key_sn] = element["option_button"].get_selected_id()
		elif element.has("slider"):
			result[key_sn] = element["slider"].value
		elif element.has("check_button"):
			result[key_sn] = element["check_button"].button_pressed
	return result


func find_matching_preset(settings: Dictionary) -> int:
	for i in range(graphics_presets.size()):
		if graphics_presets[i].matches(settings):
			return i
	return graphics_presets.size() #custom preset index


func apply_and_select_preset(settings: Dictionary) -> void:
	restore_settings_from_config(settings, false, default_config)

	var preset_index = find_matching_preset(settings)
	var graphics_option = ui_elements[&'graphics_preset'][&'option_button'] as OptionButton
	graphics_option.select(preset_index)
