extends Control

@onready var settings_panel: Control = $Control/panels/SettingsMain
@onready var level_selection: Panel = $Control/panels/level_selection
@onready var auth_screen: Panel = $Control/panels/auth_screen
@onready var credits: Panel = $Control/panels/credits

@onready var audio_stream_player: AudioStreamPlayer = $audio_stream_player

@onready var game_update_control = $game_update_available
@onready var game_update_label = $game_update_available/game_update_bg/game_update_label
@onready var checking_for_updates_label = %checking_for_updates_label
@onready var panels: Control = $Control/panels

@onready var leadearboard_screen = $Control/panels/leadearboard_screen

@onready var buttons_container: VBoxContainer = $Control/buttons/buttons2

@onready var first_activate_button: Button = $Control/buttons/buttons2/bt_play

var game_version = ProjectSettings.get("application/config/version").split(" ")[1].strip_edges()


const GAME_DOWNLOAD_LINK: String = "https://lakamfo.itch.io/zombies-must-die"
const URL_DONATE: String = "https://www.donationalerts.com/r/lakamfo"
const URL_TELEGRAM: String = "https://t.me/lakamfo_news"
const URL_ITCH_IO: String = "https://lakamfo.itch.io/zombies-must-die"


var get_update_try: int = 0
var get_update_max_try: int = 3

var swindow_scaling: float = 100
var is_kg_mode := false

#func _unhandled_input(event):
#if event is InputEventKey and event.pressed and event.keycode == KEY_BACK:
#pass

func _gpad_hint(state: bool) -> void:
	var gh := $Control/gamepad_hints
	gh.visible = state
	

func _ready() -> void:
	await get_tree().process_frame
	audio_stream_player.play()
	
	_gpad_hint(Global.gamepad_connected)
	Input.joy_connection_changed.connect(func(d, c): 
		_gpad_hint(c)
		if c: first_activate_button.grab_focus()
	)
	
	if not OS.has_feature("editor"):
		check_game_updates()
	else:
		DebugOutput.print_info("Well, update check is disabled due to debugging")
		checking_for_updates_label.text = tr("KEY_UPDATE_UPTODATE") % game_version

	init_buttons(get_children(true))
	init_buttons(buttons_container.get_children(true))
	init_buttons($game_update_available/game_update_bg.get_children(true))
	init_buttons($Control/h_box_container.get_children())
	init_buttons($Control/v_box_container.get_children())
	
	MouseManager.lock(&"main_menu")
	settings_panel.close_requested.connect(
		func(): settings_panel.hide();  if is_kg_mode: first_activate_button.grab_focus()
	)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton and !is_kg_mode:
		is_kg_mode = true
		first_activate_button.grab_focus()
		
	if event is InputEventMouseMotion:
		is_kg_mode = false

func init_buttons(buttons_array: Array) -> void:
	var bt: Array[Button]
	var bt_group := ButtonGroup.new()
	for _node in buttons_array:
		if _node is Button:
			_node.button_group = bt_group
			_node.pressed.connect(_on_bt_pressed.bind(_node.name))
			bt.append(_node)

	DebugOutput.print_debug_unique("[color=lightblue][MAIN MENU][/color] Connected Buttons : " + str(bt))


func _on_bt_pressed(button_name: String) -> void:
	match button_name:
		"bt_play":
			level_selection.visible = not level_selection.visible

			leadearboard_screen.hide()
			credits.hide()
			auth_screen.hide()
			settings_panel.hide()
		"bt_leadearboard":
			leadearboard_screen.visible = not leadearboard_screen.visible

			credits.hide()
			auth_screen.hide()
			level_selection.hide()
			settings_panel.hide()
		"bt_login":
			auth_screen.visible = not auth_screen.visible

			leadearboard_screen.hide()
			credits.hide()
			level_selection.hide()
			settings_panel.hide()
		"bt_settings":
			settings_panel.visible = not settings_panel.visible

			leadearboard_screen.hide()
			credits.hide()
			auth_screen.hide()
			level_selection.hide()
		"bt_exit":
			get_tree().quit()
		"bt_download":
			OS.shell_open(GAME_DOWNLOAD_LINK)
		"bt_close_update":
			game_update_control.hide()
		"bt_credits":
			leadearboard_screen.hide()
			auth_screen.hide()
			settings_panel.hide()
			level_selection.hide()

			credits.visible = not credits.visible
		"bt_donate":
			OS.shell_open(URL_DONATE)
		"bt_telegram":
			OS.shell_open(URL_TELEGRAM)
		"bt_itch_io":
			OS.shell_open(URL_ITCH_IO)


func check_game_updates():
	ServerRequests.getted_game_version.connect(
		func(version: String):
			if version == "":
				if get_update_try < get_update_max_try:
					get_update_try += 1
					check_game_updates()
				else:
					checking_for_updates_label.text = tr("KEY_UPDATE_TEXT_ERROR")
				return

			var is_last_version = game_version == version
			GameState.is_latest_game_version = is_last_version

			if not is_last_version:
				game_update_control.show()
				checking_for_updates_label.text = tr("KEY_UPDATE_IS_AVAILABLE") + game_version + ' — ' + version
				game_update_label.text = tr("KEY_UPDATE_TEXT") % [game_version, version]
			else:
				checking_for_updates_label.text = tr("KEY_UPDATE_UPTODATE") % game_version
	)
	ServerRequests.get_version()


func _exit_tree() -> void:
	MouseManager.unlock(&"main_menu")
