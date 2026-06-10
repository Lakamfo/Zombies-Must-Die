extends ScrollContainerMouse

@export var config_file_handler: ConfigFileHandler
@export var locale_string_to_full_string: Dictionary[String, String] = {
	'en': 'English',
	'ru': 'Русский',
}

@onready var language_option_button: OptionButton = %language_option_button
@onready var preload_weapon_button: CheckButton = %preload_weapon_button


func _ready() -> void:
	super()
	
	preload_weapon_button.toggled.connect(preload_weapon)
	language_option_button.item_selected.connect(language_option_button_item_selected)

	init_languages()
	restore_from_config()

	owner.locale_loaded.emit()


func init_languages() -> void:
	for locale in TranslationServer.get_loaded_locales():
		var locale_name: String = ''

		if locale in locale_string_to_full_string.keys():
			locale_name = locale_string_to_full_string[locale]
		else:
			locale_name = TranslationServer.get_locale_name(locale)

		language_option_button.add_item(locale_name)


func restore_from_config() -> void:
	var data: Dictionary = config_file_handler.config_load_filtered(
		{
			'core': { 'preload_weapons_scenes': true },
			'other': { 'language': TranslationServer.get_locale() },
		},
	)

	preload_weapon_button.button_pressed = data['core']['preload_weapons_scenes']

	var language_index: int = TranslationServer.get_loaded_locales().find(data['other']['language'])

	language_option_button.select(language_index)
	language_option_button_item_selected(language_index)


func preload_weapon(enabled: bool):
	config_file_handler.config_save({ 'core': { 'preload_weapons_scenes': enabled } })


func language_option_button_item_selected(index: int) -> void:
	var locale: String = TranslationServer.get_loaded_locales()[index]
	TranslationServer.set_locale(locale)

	var data: Dictionary = config_file_handler.config_load_filtered(
		{
			'other': { 'language': TranslationServer.get_locale() },
		},
	)

	if data['other']['language'] != locale:
		SettingsMain.alert(tr("KEY_SETTINGS_RELOAD_TO_APPLY_TITLE"), tr('KEY_SETTINGS_RELOAD_TO_APPLY'))

	config_file_handler.config_save({ 'other': { 'language': locale } })
