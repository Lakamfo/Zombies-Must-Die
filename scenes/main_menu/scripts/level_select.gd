extends Panel

var locations: Array[LocationData] = []
@onready var flex_container: FlowContainer = $v_box_container/margin_container/scroll_container/flex_container
@onready var label_max_score: Label = $v_box_container/label_max_score
@onready var modifiers_flex_container: FlowContainer = $v_box_container/modifers_scroll_container/modifiers_flex_container
@onready var bt_play: Button = $v_box_container/bt_play

const MODIFIER_BUTTON = preload("res://scenes/main_menu/scenes/modifier_button.tscn")
const LEVEL_BUTTON = preload("res://scenes/main_menu/scenes/level_button.tscn")


var buttons: Array = []
var selected_bt: Button


var _double_click_max_time : int = 500
var _last_clicked_button : Button
var _last_button_clicked_time : int = 0


func _ready() -> void:
	var button_group: ButtonGroup = ButtonGroup.new()
	label_max_score.text = tr("KEY_MAX_SCORE") % [0]

	var files: PackedStringArray = DirAccess.get_files_at("res://map/data/")
	for file in files:
		if file.get_extension() == 'tres':
			locations.append(load("res://map/data/" + file))
		elif file.get_extension() == 'remap':
			var config: ConfigFile = ConfigFile.new()
			config.load("res://map/data/" + file)

			locations.append(load(config.get_value('remap', 'path')))

	for loc in locations:
		if loc == null:
			continue

		if not OS.has_feature("editor"):
			if loc.debug_only:
				continue

		var button: Button = LEVEL_BUTTON.instantiate()
		button.button_group = button_group
		flex_container.add_child(button)
		buttons.append(button)

		button.find_child("texture_rect").texture = loc.icon
		button.find_child("label").text = loc.name.strip_edges()
		button.set_meta("path", loc.scene_path)
		button.set_meta("name", loc.name)
		
		
		button.set_meta("modifiers", loc.location_modifiers)
		#button.tooltip_text = loc.name.strip_edges()

		button.toggled.connect(button_toggled.bind(button))


func button_toggled(toggled: bool, bt: Button):
	var record : int = 0

	if toggled:
		selected_bt = bt
		
		if _last_clicked_button == bt:
			if (Time.get_ticks_msec() - _last_button_clicked_time) < _double_click_max_time:
					_start_load()
		
		_last_button_clicked_time = Time.get_ticks_msec()
		
		if _last_clicked_button == bt: #don`t update if previous button was exactly same
			return
		
		_last_clicked_button = bt
	
	
	label_max_score.text = tr("KEY_MAX_SCORE") % [tr("KEY_LOADING")]
	
	bt_play.disabled = not bt.button_pressed
	var location : String = _formate_location_name(bt.get_meta(&"name") ) 
	
	
	if toggled:
		var modifiers: Dictionary[ModifiersManager.Modifiers, bool] = bt.get_meta('modifiers')

		for child in modifiers_flex_container.get_children():
			child.queue_free()

		var first_mod = null
		for mod in modifiers:
			if not modifiers[mod]:
				continue
			
			var mod_bt := MODIFIER_BUTTON.instantiate()
			mod_bt.set_meta("modifier", mod)
			
			var label: Label = mod_bt.find_child("label")
			label.text = ModifiersManager.get_modifier_name(mod)
			modifiers_flex_container.add_child(mod_bt)
			
			if not first_mod: first_mod = mod_bt
			
		if first_mod:
			first_mod.grab_focus()
		else:
			bt_play.grab_focus()
		
		ServerRequests.get_record(ServerRequests.local_player_id, location)

		ServerRequests.getted_record.connect(
			func x(result: Dictionary, _location: String):
				if result and location == _location:
					if result.response:
						record = result.response[3]
					label_max_score.text = tr("KEY_MAX_SCORE") % [record]
		)


func _on_bt_play_pressed() -> void:
	_start_load()

func _start_load() -> void:
	if selected_bt:
		ModifiersManager.clear_active_modifiers()

		for child: Button in modifiers_flex_container.get_children():
			if child.button_pressed:
				var modifier: ModifiersManager.Modifiers = child.get_meta("modifier")

				var mod_instance := ModifiersManager.create_modifier(modifier)

				if mod_instance:
					ModifiersManager.add_active_modifier(modifier, mod_instance)
		
		GameState.current_location_name = _formate_location_name(selected_bt.get_meta(&"name") ) 
		SceneManager.change_scene_to_file(selected_bt.get_meta("path"))


## Remove spaces and edges
func _formate_location_name(_name : String) -> String:
	var result : String = ""
	
	for part in _name.strip_edges().split(" "):
		result += part
	
	return result
