extends Control

#region Signals
signal cache_loaded(loaded: bool)
#endregion


#region Variables
var preload_weapons: bool = true
var preload_resources: bool = true
var loaded : bool = false

var preloaded_scenes: Dictionary[String, PackedScene] = {}
var weapon_icons: Dictionary[String, CompressedTexture2D] = {}
var weapon_stats: Dictionary[String, WeaponStats] = {}

var _message_label: PackedScene = preload("res://ui/score_label/score_label.tscn")

const _PATH = "user://settings.ini"
#endregion

#region Onready variables
@onready var v_box_container: VBoxContainer = $v_box_container
#endregion

#region Lifecycle methods
func _ready() -> void:
	if not OS.is_debug_build():
		v_box_container.hide()
	
	var config = ConfigFile.new()
	
	if config.load(_PATH) in [ERR_FILE_CANT_OPEN, ERR_FILE_NOT_FOUND]:
		config.set_value("core", "preload_weapons_scenes", preload_weapons)
		config.set_value("core", "preload_weapons_resource", preload_resources)
		config.set_value("core", "preload_weapons_comment", "Increase RAM usage (preload_weapons_scenes), but minimize freeze with weapon instantiate")
		config.save(_PATH)
	else:
		preload_weapons = config.get_value("core", "preload_weapons_scenes", preload_weapons)
		preload_resources = config.get_value("core", "preload_weapons_resource", preload_resources)

	if config.get_value('core', 'preload_weapons_scenes', false):
		var paths: Array[String] = []
		for id in WeaponManager.WEAPON_REGISTRY:
			paths.append(WeaponManager.WEAPON_REGISTRY[id][1])
		
		_preload_all_threaded(paths)
	else:
		cache_loaded.emit(false)
#endregion

#region Private methods
func _preload_all_threaded(weapon_paths: Array[String]) -> void:
	var before: int = OS.get_static_memory_usage()

	for path in weapon_paths:
		await _preload_by_one_threaded(path)
		await get_tree().process_frame
	
	cache_loaded.emit(true)
	loaded = true
	
	if OS.is_debug_build():
		var after = OS.get_static_memory_usage()
		var label: MessageLabel = _create_label()
		label.text = "Approx memory used: %1.1f mb" % [(after - before) / pow(2, 20)]
		v_box_container.add_child(label)


func _preload_by_one_threaded(path: String) -> void:
	var label: MessageLabel = _create_label()
	label.text = "Weapon caching : %s..." % path.split('/')[-1]
	v_box_container.add_child(label)

	if weapon_icons.has(path):
		label.text = "Weapon caching : %s... Skipped" % path
		return

	var error := ResourceLoader.load_threaded_request(path)
	if error != OK:
		label.text = "Weapon caching : %s... Failed to request" % path
		return

	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		label.text = "Weapon caching : %s... Load Failed" % path.split('/')[-1]
		return

	var resource := ResourceLoader.load_threaded_get(path) as PackedScene
	if not resource:
		label.text = "Weapon caching : %s... Not a scene" % path.split('/')[-1]
		return

	var weapon_instance := resource.instantiate() as Weapon
	if weapon_instance and weapon_instance.weapon_stats:
		weapon_icons[path] = weapon_instance.weapon_stats.icon.duplicate()
		weapon_stats[path] = weapon_instance.weapon_stats.duplicate()

	if preload_weapons:
		preloaded_scenes[path] = resource

	if not preload_weapons and weapon_instance:
		weapon_instance.queue_free()
	
	DebugOutput.print_debug_unique("Weapon Cached : %s" % path)
	label.text = "Weapon caching : %s... Done" % path.split('/')[-1]


func _create_label() -> MessageLabel:
	var label: MessageLabel = _message_label.instantiate()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mid_color = Color(1, 1, 1, 0.5)
	return label
#endregion
