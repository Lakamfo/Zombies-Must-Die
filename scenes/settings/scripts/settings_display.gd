extends ScrollContainerMouse

@export var config_file_handler: ConfigFileHandler
@export var delayed_saver_manager: DelayedSaverManager

enum DisplayMode { FULLSCREEN, EXCLUSIVE_FULLSCREEN, WINDOWED }

@export var default_config: Dictionary = {
	'display': {
		'display_mode': 0,
		'display_monitor': DisplayServer.get_primary_screen(),
		'custom_framecap': 0,
		'interface_scaling': 1.0, #Overrides in _ready
		'vsync': true,
	},
}

@onready var ui_elements: Dictionary[StringName, Dictionary] = {
	&'display_mode': {
		&'label': %display_mode as Label,
		&'option_button': %display_mode_option_button as OptionButton,
		&'container': %display_mode_container as HBoxContainer,
	},
	&'display_monitor': {
		&'label': %display_monitor_label as Label,
		&'option_button': %display_monitor_option as OptionButton,
		&'container': %display_monitor_container as HBoxContainer,
	},
	&'frame_cap': {
		&'label': %frame_cap_label as Label,
		&'slider': %framecap_slider as HSlider,
		&'container': %custom_framecap_container as HBoxContainer,
	},
	&'interface_scaling': {
		&'label': %interface_scale_label as Label,
		&'slider': %interface_scale_slider as HSlider,
		&'container': %interface_scale_factor_container as HBoxContainer,
	},
	&'vsync': {
		&'label': %vsync_label as Label,
		&'check_button': %vsync_button as CheckButton,
		&'container': %vsync_container as HBoxContainer,
	},
}


func _ready() -> void:
	await owner.locale_loaded

	#Interface scaling based on device DPI
	var scaling_value: float = 1.0

	if SettingsUtils.is_mobile_device():
		scaling_value = float(DisplayServer.screen_get_dpi()) / 216.0
	else:
		scaling_value = float(DisplayServer.screen_get_dpi()) / (SettingsUtils.get_screen_size_inches() * 2)
		scaling_value = min(3.0, scaling_value)

	default_config['display']['interface_scaling'] = scaling_value

	init_signals()
	init_option_buttons()
	restore_settings_from_config()


func init_signals() -> void:
	#region Display Mode
	(ui_elements[&'display_mode'][&'option_button'] as OptionButton).item_selected \
	.connect(
		func(index: int):
			config_file_handler.config_save({ 'display': { 'display_mode': index } })

			match index:
				DisplayMode.FULLSCREEN:
					InputSettings.default_fullscreen_window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				DisplayMode.EXCLUSIVE_FULLSCREEN:
					InputSettings.default_fullscreen_window_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				DisplayMode.WINDOWED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	#endregion

	#region Display monitor
	(ui_elements[&'display_monitor'][&'option_button'] as OptionButton).item_selected \
	.connect(
		func change_monitor(index: int):
			config_file_handler.config_save({ 'display': { 'display_monitor': index } })
			DisplayServer.window_set_current_screen(index)
	)
	#endregion

	#region Frame Cap
	(ui_elements[&'frame_cap'][&'slider'] as HSlider).value_changed \
	.connect(
		func update_label(value: float):
			(ui_elements[&'frame_cap'][&'label'] as Label).text = tr("KEY_SETTING_FRAMECAP") % [value]

			delayed_saver_manager.trigger_delayed_call(
				"framecap_save",
				1.0,
				func():
					var v := int(value)
					config_file_handler.config_save({ 'display': { 'custom_framecap': v } })
					Engine.max_fps = int(value)
			)
	)
	#endregion

	#region Interface Scaling

	(ui_elements[&'interface_scaling'][&'slider'] as HSlider).value_changed \
	.connect(
		func scale_interface(value: float):
			delayed_saver_manager.trigger_delayed_call(
				"interface_scaling",
				1.0 if SettingsMain.first_run else 0.0,
				func():
					var v: float = value
					get_window().content_scale_factor = v
					config_file_handler.config_save({ 'display': { 'interface_scaling': v } })
			)
			(ui_elements[&'interface_scaling'][&'label'] as Label).text = \
			tr('KEY_SETTING_INTERFACE_SCALE') % [value]
	)
	#endregion

	#region VSYNC
	(ui_elements[&'vsync'][&'check_button'] as CheckButton).toggled \
	.connect(
		func toggle_vsync(value: bool):
			DisplayServer.window_set_vsync_mode(int(value) as DisplayServer.VSyncMode)

			config_file_handler.config_save({ 'display': { 'vsync': value } })
	)
	#endregion


func init_option_buttons() -> void:
	for number in DisplayServer.get_screen_count():
		(ui_elements[&'display_monitor'][&'option_button'] as OptionButton) \
		.add_item(str(number))


func restore_settings_from_config() -> void:
	var loaded_config: Dictionary = config_file_handler.config_load_filtered(default_config)

	### DISPLAY MODE 
	if SettingsMain.first_run:
		(ui_elements[&'display_mode'][&'option_button'] as OptionButton) \
		.select(loaded_config['display']['display_mode'])
		(ui_elements[&'display_mode'][&'option_button'] as OptionButton) \
		.item_selected.emit(loaded_config['display']['display_mode'])

	### DISPLAY MONITOR
	(ui_elements[&'display_monitor'][&'option_button'] as OptionButton) \
	.select(loaded_config['display']['display_monitor'])
	(ui_elements[&'display_monitor'][&'option_button'] as OptionButton) \
	.item_selected.emit(loaded_config['display']['display_monitor'])

	###FRAME CAP
	(ui_elements[&'frame_cap'][&'slider'] as HSlider) \
	.set_value(loaded_config['display']['custom_framecap'])
	(ui_elements[&'frame_cap'][&'slider'] as HSlider).value_changed.emit(
		\
		loaded_config['display']['custom_framecap'],
	)

	###INTERFACE SCALING
	(ui_elements[&'interface_scaling'][&'slider'] as HSlider) \
	.set_value(loaded_config['display']['interface_scaling'])
	(ui_elements[&'interface_scaling'][&'slider'] as HSlider).value_changed.emit(
		\
		loaded_config['display']['interface_scaling'],
	)

	###VSYNC
	(ui_elements[&'vsync'][&'check_button'] as CheckButton) \
	.button_pressed = loaded_config['display']['vsync']
	(ui_elements[&'vsync'][&'check_button'] as CheckButton).toggled.emit(
		\
		loaded_config['display']['vsync'],
	)
