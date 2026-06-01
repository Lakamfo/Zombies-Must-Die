extends Node

var scaling_factor: float = 0.75
var take_treshold: float = 2

var open_folder_event: StringName = "open_screenshots_folder"
var take_screenshot: StringName = "take_screenshot"

var root_folder_path: String = OS.get_user_data_dir()
var path: String
var overlay: PackedScene = preload("res://addons/sc-module/scenes/sc-overlay.tscn")
var folder_name: String = "screenshots"

var overlay_instance: CanvasLayer
var tx_a: AnimationPlayer
var tx_r: TextureRect
var asp: AudioStreamPlayer
var label: Label

var thread: Thread = Thread.new()
var timer: Timer = Timer.new()

var sc: Image
var tween: Tween


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if Input.is_action_just_pressed(take_screenshot):
			take_sc()
		elif Input.is_action_just_pressed(open_folder_event):
			OS.shell_open(path)


func _ready() -> void:
	path = root_folder_path + '/' + folder_name + '/'
	DirAccess.make_dir_absolute(path)
	_init_overlay()
	_init_nodes()
	set_label_key()

	process_mode = ProcessMode.PROCESS_MODE_ALWAYS

	EventBus.update_settings.connect(
		func():
			set_label_key()
	)
	tx_a.connect(
		"change_position",
		func():
			if tween:
				tween.kill()

			tween = create_tween()

			tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tween.tween_property(tx_r, "position:y", -(tx_r.size * tx_r.scale).y, 0.5)
	)
	tx_a.animation_finished.connect(
		func(_anim: String):
			tx_r.hide()
			label.hide()
	)


func _init_nodes():
	tx_r = overlay_instance.get_node("TextureRect")
	tx_a = overlay_instance.get_node("AnimationPlayer")
	asp = overlay_instance.get_node("AudioStreamPlayer")
	label = overlay_instance.get_node("Label")

	add_child(timer)
	timer.one_shot = true


func _init_overlay():
	overlay_instance = overlay.instantiate()
	add_child(overlay_instance)


func set_label_key():
	var events = InputMap.action_get_events(open_folder_event)

	if events.size() > 0:
		label.text = events[0].as_text().trim_suffix(" - Physical")
	else:
		label.text = ""


func take_sc() -> void:
	if not timer.is_stopped():
		return

	if thread.is_started():
		thread.wait_to_finish()

	await RenderingServer.frame_post_draw

	sc = get_viewport().get_texture().get_image()
	var sc_size: Vector2i = sc.get_size() * scaling_factor
	sc.resize(sc_size.x, sc_size.y, Image.INTERPOLATE_TRILINEAR)

	if not thread.is_started():
		thread.start(save_image, Thread.PRIORITY_NORMAL)
	if not thread.is_alive():
		thread.wait_to_finish()

	tx_r.show()

	tx_r.pivot_offset.x = tx_r.size.x / 2
	tx_r.texture = ImageTexture.create_from_image(sc)

	tx_a.stop()
	tx_a.play("show_and_hide")

	asp.pitch_scale = randf_range(0.9, 1.1)
	asp.play(0.1)

	label.show()
	timer.start(take_treshold)


func save_image():
	var timestamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-")
	sc.save_png(path + '/' + timestamp + ".png")
