extends CanvasLayer

var loading_status: int
var progress: Array[float]

var path: String
var is_loading: bool = false

@onready var loading_screen: PackedScene = preload("res://scenes/loading_screen.tscn")
var progress_bar: ProgressBar
var label: Label
var label_resource: Label
var animation_player: AnimationPlayer

var dependencies: PackedStringArray
var loading_screen_instance: Control
var audio_effect: AudioEffectFilter = AudioEffectFilter.new()

signal scene_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3

	init_loading_screen()
	init_effects()


func reload_current_scene():
	EventBus.scene_changed.emit()
	get_tree().call_deferred(&'reload_current_scene')
	
	for frame in 3:
		await get_tree().process_frame # Waiting, until scene fully loaded
	EventBus.scene_loaded.emit()


func init_loading_screen() -> void:
	loading_screen_instance = loading_screen.instantiate()
	add_child(loading_screen_instance)

	progress_bar = loading_screen_instance.get_node("progress_bar")
	label = loading_screen_instance.find_child("label")
	label_resource = loading_screen_instance.find_child("label_resource")

	animation_player = loading_screen_instance.get_node("animation_player")


func change_scene_to_file(path_v: String) -> void:
	is_loading = true

	handle_sound_effects(true)

	path = path_v
	progress_bar.value = 0
	animation_player.play("fade_in")

	ResourceLoader.load_threaded_request(path_v)
	dependencies = ResourceLoader.get_dependencies(path)


func _physics_process(_delta: float) -> void:
	if is_loading:
		update_loading_status()


func update_loading_status() -> void:
	loading_status = ResourceLoader.load_threaded_get_status(path, progress)
	match loading_status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			update_loading_progress()
		ResourceLoader.THREAD_LOAD_LOADED:
			finish_loading()
		ResourceLoader.THREAD_LOAD_FAILED:
			handle_loading_error()


func update_loading_progress() -> void:
	var current_resource: String = dependencies[remap(progress[0], 0.0, 1.0, 0, dependencies.size() - 1)].get_slice("::", 2)

	label_resource.visible = true

	label.text = tr(&"KEY_SCENE_MANAGER_LOADING") % path
	label_resource.text = tr(&"KEY_SCENE_MANAGER_LOADING") % current_resource
	progress_bar.value = lerp(progress_bar.value, progress[0] * 100, 0.1)


func finish_loading() -> void:
	get_tree().call_deferred(&"set", &"paused", false)
	get_tree().call_deferred(&"change_scene_to_packed", ResourceLoader.load_threaded_get(path))

	is_loading = false

	label_resource.visible = false
	label.text = tr(&"KEY_SCENE_MANAGER_LOADING_DONE")
	scene_changed.emit()
	EventBus.scene_changed.emit()

	wait_for_scene_load()


func wait_for_scene_load() -> void:
	var time_start: int = Time.get_ticks_msec()

	for frame in 3:
		await get_tree().process_frame # Waiting, until scene fully loaded
	EventBus.scene_loaded.emit()
	DebugOutput.print_debug_unique("Scene freeze took %s ms" % (Time.get_ticks_msec() - time_start))

	var tween: Tween = create_tween()
	tween.tween_property(progress_bar, "value", 100, 1).set_trans(Tween.TRANS_EXPO)

	handle_sound_effects(false)
	animation_player.play("fade_out")


func handle_loading_error() -> void:
	var current_resource: String = dependencies[remap(progress[0], 0.0, 1.0, 0, dependencies.size() - 1)].get_slice("::", 2)

	DebugOutput.print_error("Error. Could not load Resource %s" % current_resource)
	label.text = tr(&"KEY_SCENE_MANAGER_LOADING_ERROR") % path
	is_loading = false
	animation_player.play("fade_out")

	handle_sound_effects(false)


func init_effects():
	audio_effect.cutoff_hz = 2000
	AudioServer.add_bus_effect(0, audio_effect)
	AudioServer.set_bus_effect_enabled(0, 0, false)


func handle_sound_effects(enable: bool = false):
	if enable:
		audio_effect.cutoff_hz = 2000
		AudioServer.set_bus_effect_enabled(0, 0, true)
		get_tree().create_tween().tween_property(audio_effect, "cutoff_hz", 200, 1.0)
	else:
		get_tree().create_tween().tween_property(audio_effect, "cutoff_hz", 2000, 1.5).finished.connect(
			func x():
				AudioServer.set_bus_effect_enabled(0, 0, false)
		)
