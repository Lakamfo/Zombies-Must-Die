extends ScrollContainerMouse

@export var default_cfg: Dictionary = {
	'audio': {
		'master_volume': 1.0,
		'weapon_volume': 1.0,
		'sfx_volume': 1.0,
		'music_volume': 1.0,
	},
}
@export var config_file_handler: ConfigFileHandler

enum AUDIO_BUS { MASTER, WEAPON, MUSIC, SFX }

@onready var master_label: Label = %master_label
@onready var master_volume_slider: HSlider = %master_volume_slider

@onready var weapon_label: Label = %weapon_label
@onready var weapon_volume_slider: HSlider = %weapon_volume_slider

@onready var music_label: Label = %music_label
@onready var music_volume_slider: HSlider = %music_volume_slider

@onready var sfx_label: Label = %sfx_label
@onready var sfx_volume_slider: HSlider = %sfx_volume_slider


func _ready() -> void:
	await owner.locale_loaded

	_init_signals()
	_load_from_settings()


func _init_signals() -> void:
	master_volume_slider.connect(
		&'value_changed',
		func(value: float):
			update_volume_and_text(value, master_label, tr('KEY_SETTING_MASTER_VOLUME') % [value * 100], AUDIO_BUS.MASTER)
	)
	weapon_volume_slider.connect(
		&'value_changed',
		func(value: float):
			update_volume_and_text(value, weapon_label, tr('KEY_SETTING_WEAPON_VOLUME') % [value * 100], AUDIO_BUS.WEAPON)
	)
	music_volume_slider.connect(
		&'value_changed',
		func(value: float):
			update_volume_and_text(value, music_label, tr('KEY_SETTING_MUSIC_VOLUME') % [value * 100], AUDIO_BUS.MUSIC)
	)
	sfx_volume_slider.connect(
		&'value_changed',
		func(value: float):
			update_volume_and_text(value, sfx_label, tr('KEY_SETTING_SFX_VOLUME') % [value * 100], AUDIO_BUS.SFX)
	)


func _load_from_settings() -> void:
	var data: Dictionary = config_file_handler.config_load_filtered(
		{
			'audio': { 'master_volume': 1.0, 'weapon_volume': 1.0, 'sfx_volume': 1.0, 'music_volume': 1.0 },
		},
	)

	master_volume_slider.value = data['audio']['master_volume']
	weapon_volume_slider.value = data['audio']['weapon_volume']
	sfx_volume_slider.value = data['audio']['sfx_volume']
	music_volume_slider.value = data['audio']['music_volume']

	master_volume_slider.emit_signal(&'value_changed', master_volume_slider.value)
	weapon_volume_slider.emit_signal(&'value_changed', weapon_volume_slider.value)
	sfx_volume_slider.emit_signal(&'value_changed', sfx_volume_slider.value)
	music_volume_slider.emit_signal(&'value_changed', music_volume_slider.value)


func update_volume_and_text(volume: float, label: Label, text: String, bus: AUDIO_BUS):
	AudioServer.set_bus_volume_linear(bus, volume)
	label.text = text

	match bus:
		AUDIO_BUS.MASTER:
			default_cfg['audio']['master_volume'] = volume
		AUDIO_BUS.WEAPON:
			default_cfg['audio']['weapon_volume'] = volume
		AUDIO_BUS.SFX:
			default_cfg['audio']['sfx_volume'] = volume
		AUDIO_BUS.MUSIC:
			default_cfg['audio']['music_volume'] = volume

	config_file_handler.config_save(default_cfg)
