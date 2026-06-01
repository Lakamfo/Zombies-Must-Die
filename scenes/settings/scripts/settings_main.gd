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


func _ready() -> void:
	init_tabs_tittles()
	runs_count += 1

	tab_container.tab_selected.connect(handle_tab_select)
	
	await get_tree().create_timer(2.5).timeout
	locale_loaded.emit()


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


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible and tab_container:
				tab_container.current_tab = 1
