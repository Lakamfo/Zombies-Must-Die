extends Control

#region Signals
signal close_requested
#endregion

#region Exports
@export var label_settings: LabelSettings
#endregion

#region Variables
var weapon_manager: WeaponManager = Global.weapon_manager
var player: Player = Global.player

var _current_active_bt: Button
var _cache_is_loaded: bool = false
var _filter_text: String = ""
var _bold_font := load("uid://q6ulhkx8ln0a")

const FIRE_MODE_NAMES: Array[String] = ["Semi", "Auto", "Burst"]

var SYNTHETIC_STATS: Dictionary[String, Callable] = {
	"_recoil_score": WeaponCalculator.calculate_recoil_score,
	"_dps": WeaponCalculator.calculate_dps,
} 

const WEAPON_LAYOUT: Array[Dictionary] = [
	{
		"group": &"KEY_STAT_GROUP_MAIN",
		"stats": ["fire_rate", "burst_fire_rate", "fire_mode", "available_shooting_modes", "fire_distance"]
	},
	{
		"group": &"KEY_STAT_GROUP_DAMAGE",
		"stats": ["damage", "_dps", "head_mult", "torso_mult", "limbs_mult", "bullet_impact_power", "max_penetration_count"]
	},
	{
		"group": &"KEY_STAT_GROUP_BULLETS",
		"stats": ["clip_size", "magazine_size", "bullet_in_chamber", "reload_penalty", "burst_size", "buckshot_size"]
	},
	{
		"group": &"KEY_STAT_GROUP_RECOIL",
		"stats": [
			"_recoil_score",
			"non_stop_mult_enabled", "max_non_stop_mult",
			"non_stop_increase",
		]
	},
	{
		"group": &"KEY_STAT_GROUP_AIM",
		"stats": ["aim_speed", "aim_camera_zoom", "aim_weapon_camera_zoom"]
	},
	{
		"group": &"KEY_STAT_GROUP_TRIGGER",
		"stats": ["trigger_delay_enabled", "trigger_delay"]
	},
]

const DISPLAY_NAMES: Dictionary[String, String] = {
	"fire_rate":               "KEY_STAT_FIRE_RATE",
	"burst_fire_rate":         "KEY_STAT_BURST_FIRE_RATE",
	"available_shooting_modes":"KEY_STAT_AVAILABLE_SHOOTING_MODES",
	"fire_distance":           "KEY_STAT_FIRE_DISTANCE",
	"damage":                  "KEY_STAT_DAMAGE",
	"_dps":                    "KEY_STAT_DPS",
	"clip_size":               "KEY_STAT_CLIP_SIZE",
	"magazine_size":           "KEY_STAT_MAGAZINE_SIZE",
	"reload_penalty":          "KEY_STAT_RELOAD_PENALTY",
	"bullet_in_chamber":       "KEY_STAT_BULLET_IN_CHAMBER",
	"head_mult":               "KEY_STAT_HEAD_MULT",
	"torso_mult":              "KEY_STAT_TORSO_MULT",
	"limbs_mult":              "KEY_STAT_LIMBS_MULT",
	"bullet_impact_power":     "KEY_STAT_BULLET_IMPACT_POWER",
	"max_penetration_count":   "KEY_STAT_MAX_PENETRATION_COUNT",
	"burst_size":              "KEY_STAT_BURST_SIZE",
	"buckshot_size":           "KEY_STAT_BUCKSHOT_SIZE",
	"aim_speed":               "KEY_STAT_AIM_SPEED",
	"aim_camera_zoom":         "KEY_STAT_AIM_CAMERA_ZOOM",
	"aim_weapon_camera_zoom":  "KEY_STAT_AIM_WEAPON_CAMERA_ZOOM",
	"max_hip_camera_kick":     "KEY_STAT_MAX_HIP_CAMERA_KICK",
	"min_hip_camera_kick":     "KEY_STAT_MIN_HIP_CAMERA_KICK",
	"max_aim_camera_kick":     "KEY_STAT_MAX_AIM_CAMERA_KICK",
	"min_aim_camera_kick":     "KEY_STAT_MIN_AIM_CAMERA_KICK",
	"snappinnes":              "KEY_STAT_SNAPPINNES",
	"return_speed":            "KEY_STAT_RETURN_SPEED",
	"non_stop_mult_enabled":   "KEY_STAT_NON_STOP_MULT_ENABLED",
	"max_non_stop_mult":       "KEY_STAT_MAX_NON_STOP_MULT",
	"non_stop_increase":       "KEY_STAT_NON_STOP_INCREASE",
	"_recoil_score":           "KEY_STAT_RECOIL_SCORE",
	"non_stop_reset_threshold":"KEY_STAT_NON_STOP_RESET_THRESHOLD",
	"trigger_delay_enabled":   "KEY_STAT_TRIGGER_DELAY_ENABLED",
	"trigger_delay":           "KEY_STAT_TRIGGER_DELAY",
}

const LOWER_IS_BETTER: Dictionary[String, bool] = {
	"reload_penalty": true,
	"trigger_delay": true,
	"non_stop_reset_threshold": true,
	"_recoil_score": true,
	"aim_speed": true
}

#endregion

#region Onready variables
@onready var stats_list: HFlowContainer = %stats_list
@onready var weapon_list: VBoxContainer = %weapon_list
@onready var slot_prefab: Button = %slot_prefab
@onready var filter_input: LineEdit = %filter_input

@onready var bt_give_weapon: Button = %bt_give_weapon
@onready var bt_upgrade_weapon: Button = %bt_upgrade_weapon
@onready var bt_close: Button = %button_close

@onready var ui_sounds: UISounds = %ui_sounds
#endregion

var first_weapon_button: Button


#region Lifecycle methods
func _ready() -> void:
	Input.joy_connection_changed.connect(func(_d, c):
		if c: first_weapon_button.grab_focus()
	)
	
	bt_close.pressed.connect(close_requested.emit)
	
	if owner:
		await owner.ready
	
	if WeaponCache.weapon_stats.is_empty():
		_cache_is_loaded = await WeaponCache.cache_loaded
	else:
		_cache_is_loaded = true
	
	if not Global.weapon_manager:
		weapon_manager = load("res://player/weapon_logic/weapon_manager.gd").new()
	else:
		weapon_manager = Global.weapon_manager

	player = Global.player

	filter_input.text_changed.connect(_on_filter_changed)
	bt_upgrade_weapon.pressed.connect(_upgrade_selected_weapon)
	bt_give_weapon.pressed.connect(_give_selected_weapon)

	_build_weapon_list()	

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if 	event.is_action_pressed("pause") or \
		event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		accept_event()
#endregion

#region Public methods
func get_stat_value(p_name: String, data: WeaponStats) -> Variant:
	if SYNTHETIC_STATS.has(p_name):
		return SYNTHETIC_STATS[p_name].call(data)
	return data.get(p_name)


func format_value(p_name: String, value: Variant) -> String:
	if p_name == "fire_mode":
		return FIRE_MODE_NAMES[value] if value < FIRE_MODE_NAMES.size() else str(value)
	if p_name == "available_shooting_modes":
		return _decode_available_modes(value)
	if p_name == "_recoil_score":
		return "%.0f / 100" % [value]

	match typeof(value):
		TYPE_FLOAT:   return "%.2f" % value
		TYPE_INT:     return str(value)
		TYPE_BOOL:    return tr(&"KEY_YES") if value else tr(&"KEY_NO")
		TYPE_VECTOR3: return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
		TYPE_COLOR:   return ""
		TYPE_OBJECT:  return "null" if value == null else value.get_class()
		_:            return str(value)
#endregion

#region Private methods
func _build_weapon_list() -> void:
	var buttons: Array[Node] = []
	var bt_group := ButtonGroup.new()

	for weapon_id: int in WeaponManager.WEAPON_REGISTRY:
		var weapon_info: Array = WeaponManager.WEAPON_REGISTRY[weapon_id]
		var weapon_resource_path: String = weapon_info[1]
		var weapon_icon: CompressedTexture2D
		var weapon_name: String

		if WeaponCache.preloaded_scenes:
			weapon_icon = WeaponCache.weapon_icons[weapon_resource_path]
			weapon_name = weapon_manager.get_weapon_name_from_id(weapon_id).to_upper()
		else:
			var packed_weapon_scene: PackedScene = load(weapon_resource_path)
			var weapon_instance: Weapon = packed_weapon_scene.instantiate()
			weapon_icon = weapon_instance.weapon_stats.icon
			weapon_name = weapon_instance.weapon_name
			weapon_instance.queue_free()

		var bt := slot_prefab.duplicate(DuplicateFlags.DUPLICATE_USE_INSTANTIATION) as Button
		var texture_rect := bt.get_child(0) as TextureRect
		var label := bt.get_child(1) as Label
		
		first_weapon_button = bt

		bt.button_group = bt_group
		texture_rect.texture = weapon_icon
		label.text = weapon_name
		bt.visible = true
		bt.toggled.connect(_on_button_toggled.bind(bt))
		bt.set_meta(&"weapon_id", weapon_id)
		weapon_list.add_child(bt)
		buttons.append(bt)

	ui_sounds.connect_nodes(buttons)


func _decode_available_modes(mask: int) -> String:
	var result: Array[String] = []
	var bit := 1
	var mode := 0
	while bit <= mask:
		if mask & bit:
			result.append(FIRE_MODE_NAMES[mode])
		bit <<= 1
		mode += 1
	return " / ".join(result)


func _matches_filter(p_name: String, display_name: String) -> bool:
	if _filter_text == "":
		return true
	return display_name.to_lower().contains(_filter_text) \
		or p_name.to_lower().contains(_filter_text)


func _collect_upgrade_chain(base: WeaponStats) -> Array[WeaponStats]:
	var chain: Array[WeaponStats] = []
	var current := base.weapon_stats_upgrade
	while current != null:
		chain.append(current)
		current = current.weapon_stats_upgrade
	return chain


func _update_stats(weapon_id: int) -> void:
	for child in stats_list.get_children():
		child.queue_free()

	if not _cache_is_loaded:
		return

	var weapon_resource_path: String = WeaponManager.WEAPON_REGISTRY[weapon_id][1]
	var weapon_data: WeaponStats = WeaponCache.weapon_stats[weapon_resource_path]
	var upgrades := _collect_upgrade_chain(weapon_data)

	stats_list.add_theme_constant_override("separation", 8)

	for group in WEAPON_LAYOUT:
		var group_name: String = group["group"]
		var stat_keys: Array = group["stats"]

		var section := _create_section(tr(group_name))
		var container := VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_FILL
		section.add_child(container)
		var section_used := false

		for p_name in stat_keys:
			var display_name: String = DISPLAY_NAMES.get(p_name, p_name.capitalize())

			if not _matches_filter(p_name, display_name):
				continue

			var value: Variant = get_stat_value(p_name, weapon_data)
			container.add_child(_create_stat_row(p_name, display_name, value, upgrades))
			section_used = true

		if section_used:
			stats_list.add_child(section)


func _create_section(title: String, min_width: float = 300.0) -> FoldableContainer:
	var section := FoldableContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.custom_minimum_size.x = min_width
	section.title = title
	section.add_theme_font_size_override("font_size", 18)
	section.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	section.add_theme_font_override("font", _bold_font)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_sounds.connect_nodes([section])
	return section


func _create_stat_row(p_name: String, display_name: String, value: Variant, upgrades: Array[WeaponStats] = []) -> Control:
	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = tr(display_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var value_control: Control

	match typeof(value):
		TYPE_COLOR:
			var color_rect := ColorRect.new()
			color_rect.color = value
			color_rect.custom_minimum_size = Vector2(20, 20)
			value_control = color_rect
		_:
			var value_label := Label.new()
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

			if upgrades.is_empty():
				value_label.text = format_value(p_name, value)
				if typeof(value) == TYPE_BOOL:
					value_label.modulate = Color(0.3, 1, 0.3) if value else Color(1, 0.3, 0.3)
			else:
				var parts: Array[String] = [format_value(p_name, value)]
				for upgrade in upgrades:
					parts.append(format_value(p_name, get_stat_value(p_name, upgrade)))
				if typeof(value) == TYPE_BOOL:
					value_label.modulate = Color(0.3, 1, 0.3) if value else Color(1, 0.3, 0.3)

				var last_value: Variant = get_stat_value(p_name, upgrades.back())
				var all_same: bool = upgrades.all(func(u): return get_stat_value(p_name, u) == value)

				value_label.text = format_value(p_name, value) if all_same else " → ".join(parts)

				if not all_same and last_value != null:
					if typeof(value) in [TYPE_FLOAT, TYPE_INT]:
						var better: bool = last_value > value
						if LOWER_IS_BETTER.has(p_name):
							better = not better
						value_label.modulate = Color(0.3, 1, 0.3) if better else Color(1, 0.3, 0.3)
					elif typeof(value) in [TYPE_VECTOR3, TYPE_VECTOR2]:
						var better: bool = (last_value as Vector3).length() < (value as Vector3).length()
						value_label.modulate = Color(0.3, 1, 0.3) if better else Color(1, 0.3, 0.3)

			value_control = value_label

	if p_name in ["damage", "fire_rate"]:
		name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))

	hbox.add_child(name_label)
	hbox.add_child(value_control)
	panel.add_child(hbox)
	return panel


func _give_selected_weapon() -> void:
	if _current_active_bt and player:
		var weapon_id: int = _current_active_bt.get_meta(&"weapon_id", -1)
		player.weapon_manager.add_weapon(weapon_id)


func _upgrade_selected_weapon() -> void:
	var current_weapon: Weapon = weapon_manager.get_current_weapon()
	if current_weapon and current_weapon.weapon_stats.weapon_stats_upgrade:
		current_weapon.weapon_stats = current_weapon.weapon_stats.weapon_stats_upgrade
#endregion

#region Event handlers
func _on_filter_changed(text: String) -> void:
	_filter_text = text.to_lower().strip_edges()
	if _current_active_bt:
		_update_stats(_current_active_bt.get_meta(&"weapon_id", 0))


func _on_button_toggled(_toggled_on: bool, button: Button) -> void:
	_current_active_bt = button
	_update_stats(button.get_meta(&"weapon_id", 0))
	$margin_container/panel_container/margin_container/h_box_container/v_box_container/h_box_container/bt_give_weapon.grab_focus()
	
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible: first_weapon_button.grab_focus()
#endregion
