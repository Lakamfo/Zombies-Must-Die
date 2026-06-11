extends Control

class_name SettingsMain

@onready var tab_container: TabContainer = $TabContainer

static var first_run: bool = true
static var runs_count: int = 0:
	set(value):
		runs_count = value
		first_run = false

signal locale_loaded
signal close_requested

func _gpad_hint(state: bool) -> void:
	var gh := %gamepad_hints_tab
	gh.visible = state

func _ready() -> void:
	_gpad_hint(Global.gamepad_connected)
	
	Input.joy_connection_changed.connect(func(d, c): 
		_gpad_hint(c)
		if c: handle_tab_select(tab_container.current_tab)
	)
	
	init_tabs_tittles()
	runs_count += 1

	tab_container.tab_selected.connect(handle_tab_select)
	
	await get_tree().create_timer(2.5).timeout
	locale_loaded.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed('swap_weapon_left'):
		if tab_container.current_tab != 1:
			tab_container.current_tab -= 1
	elif event.is_action_pressed('swap_weapon_right'):
		if tab_container.current_tab < (tab_container.get_tab_count() - 1):
			tab_container.current_tab += 1
	elif event.is_action_pressed('ui_cancel'):
		close_requested.emit()

func init_tabs_tittles() -> void:
	tab_container.set_tab_title(1, "KEY_SETTINGS_DISPLAY")
	tab_container.set_tab_title(2, "KEY_SETTINGS_GRAPHICS")
	tab_container.set_tab_title(3, "KEY_SETTINGS_SOUNDS")
	tab_container.set_tab_title(4, "KEY_SETTINGS_INPUT")
	tab_container.set_tab_title(5, "KEY_SETTINGS_OTHER")


static func alert(title: String, text: String):
	OS.alert(text, title)


func handle_tab_select(_idx: int) -> void:
	match _idx:
		0:
			close_requested.emit()
		1:
			%display_mode_option_button.grab_focus.call_deferred()
		2:
			%graphic_preset_option.grab_focus.call_deferred()
		3:
			%master_volume_slider.grab_focus.call_deferred()
		4:
			%mouse_sensitivity_slider.grab_focus.call_deferred()
		5:
			%language_option_button.grab_focus.call_deferred()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible and tab_container:
				tab_container.current_tab = 1
				%display_mode_option_button.grab_focus()
