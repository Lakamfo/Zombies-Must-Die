extends CanvasLayer

#region Preloads
const ITEM_SLOT = preload("uid://b7yafw4j81hb5")
const SCORE_LABEL = preload("uid://clubhxsfwyga2")
const TIME_BONUS_SLOT = preload("uid://dfcjvnew7vpdj")
#endregion

#region Exports
## Calculate by dividing width by height OR just 16:9 or other aspect ratios
@export var maximum_aspect_ratio: float = 1.814

@export_group("Crosshair")
@export var crosshair_snappines: float = 15
#endregion

#region Onready variables
@onready var aspect_ratio_container: AspectRatioContainer = $aspect_ratio_container

@onready var weapons_ui: Array = []
@onready var weapons_container: VBoxContainer = $aspect_ratio_container/margin/inventory_vbox
@onready var score_stats: VBoxContainer = $aspect_ratio_container/margin/score_stats

@onready var crosshair: ColorRect = $aspect_ratio_container/margin/crosshair
@onready var hit_marker_animation: AnimationPlayer = $aspect_ratio_container/margin/hit_marker/animation_player
@onready var hit_marker: TextureRect = $aspect_ratio_container/margin/hit_marker

@onready var blood_texture: TextureRect = $blood_texture
@onready var blood_animation_player: AnimationPlayer = $blood_texture/animation_player
@onready var blood_audio_stream_player: AudioStreamPlayer = $blood_texture/audio_stream_player

@onready var hp_label: Label = %health_label
@onready var hp_progress_bar: ProgressBar = %health_progress_bar
@onready var score_label: Label = %score_label

@onready var fire_mode_label: Label = %fire_mode_label
@onready var fire_mode_animation_player: AnimationPlayer = $aspect_ratio_container/margin/fire_mode_label/fire_mode_animation_player

@onready var interactable_panel: Panel = $aspect_ratio_container/margin/interactable_text/interactable_panel
@onready var interact_text: RichTextLabel = $aspect_ratio_container/margin/interactable_text

@onready var wave_label: Label = %wave_label
@onready var wave_container: HBoxContainer = %wave_container

@onready var pause_menu: Panel = $aspect_ratio_container/margin/pause_menu

@onready var label_dead: Label = $aspect_ratio_container/margin/pause_menu/label_dead
@onready var menu_buttons: VBoxContainer = $aspect_ratio_container/margin/pause_menu/buttons

@onready var time_bonus_vbox: HBoxContainer = $aspect_ratio_container/margin/time_bonus_vbox
@onready var active_bonus_hbox: HBoxContainer = %active_bonus_hbox

@onready var nuke_animation_player: AnimationPlayer = $nuke_overlay/nuke_animation_player

@onready var settings: SettingsMain = $aspect_ratio_container/margin/pause_menu/SettingsMain

@onready var touch_screen: Control = %touch_screen

@onready var bt_cont: Button = %bt_cont
@onready var bt_restart: Button = %bt_restart
@onready var bt_settings: Button = %bt_settings
@onready var bt_exit: Button = %bt_exit
@onready var bt_exit_descktop: Button = %bt_exit_descktop

@onready var death_screen: CanvasLayer = $death_screen
#endregion

#region Variables
var weapon_manager = Global.weapon_manager
var player_speed: float = 0
var player_alive: bool = true
var _message_cache: Dictionary[String, MessageLabel] = {}
#endregion

func _gpad_hint(state: bool) -> void:
	var hints := [
		%gamepad_hints,
		%gamepad_hints_gun,
		%gamepad_hints,
		%gamepad_hints2,
	]

	for hint in hints:
		hint.visible = state

#region Lifecycle methods
func _ready() -> void:
	# if gpad dissconnected, return to pause
	
	_gpad_hint(Global.gamepad_connected)
	
	Input.joy_connection_changed.connect(func(device: int, connected: bool) -> void:
		_gpad_hint(Global.gamepad_connected)
		if Global.gamepad_connected:
			if get_tree().paused:
				%gpad_broke.hide()
				bt_cont.grab_focus()
			return
		
		if not get_tree().paused:
			button_handler(0)
			%gpad_broke.show()
	)
	
	if Global.first_hint_counter:
		Global.first_hint_counter = false
	else:
		%gamepad_hints2.hide()
	
	aspect_ratio_container.modulate.a = 0

	update_interface_ratio()
	get_viewport().size_changed.connect(update_interface_ratio)

	touch_screen.visible = SystemInfo.has_touch_screen

	bt_cont.pressed.connect(button_handler.bind(0))
	bt_restart.pressed.connect(button_handler.bind(1))
	bt_settings.pressed.connect(button_handler.bind(2))
	bt_exit.pressed.connect(button_handler.bind(3))
	bt_exit_descktop.pressed.connect(button_handler.bind(4))

	settings.close_requested.connect(_on_close_request)

	EventBus.weapon_fire_mode_changed.connect(_on_weapon_fire_mode_changed)
	EventBus.weapon_add_ui.connect(_on_weapon_add_ui)
	EventBus.weapon_remove_ui.connect(_on_weapon_remove_ui)
	EventBus.weapon_active.connect(_on_weapon_active)
	EventBus.ui_update_crosshair.connect(_on_ui_update_crosshair)
	EventBus.ui_update_interactable.connect(_on_ui_update_interactable)
	EventBus.weapon_hitted.connect(_on_weapon_hitted)
	EventBus.weapon_add_ammo.connect(_on_weapon_add_ammo)
	EventBus.add_score.connect(_on_add_score)
	EventBus.ui_message.connect(_on_ui_message)
	EventBus.ui_update_score.connect(_on_ui_update_score)
	EventBus.player_changed_health.connect(_on_player_changed_health)
	EventBus.player_die.connect(_on_player_die)
	EventBus.ui_update_wave.connect(_on_ui_update_wave)
	EventBus.ui_add_time_bonus.connect(_on_ui_add_time_bonus)
	EventBus.bonus_nuke_all.connect(_on_bonus_nuke_all)
	EventBus.player_revived.connect(_on_player_revived)
	EventBus.scene_loaded.connect(_play_ui_reveal_animation)

	blood_animation_player.play("puls")

	# Fallback if scene was direct loaded from editor
	get_tree().create_timer(5.0, false).timeout.connect(_play_ui_reveal_animation)


func _process(_delta: float) -> void:
	if Global.player:
		_update_crosshair_spread()

	if is_instance_valid(Global.weapon_manager):
		_update_crosshair_position()

func _unhandled_input(event: InputEvent) -> void:
	if 	(event.is_action_pressed(&"pause") and player_alive) or \
		(event.is_action_pressed(&"ui_cancel") and get_tree().paused):
		%gamepad_hints2.hide()
		get_tree().paused = !get_tree().paused
		pause_menu.visible = get_tree().paused
		if get_tree().paused:
			pause_menu.get_node('buttons/bt_cont').grab_focus()
		else:
			%gpad_broke.hide()
			
		_on_close_request()

		if pause_menu.visible:
			MouseManager.lock(&"pause_menu")
		else:
			MouseManager.unlock(&"pause_menu")


func _exit_tree() -> void:
	MouseManager.unlock(&"pause_menu")
	MouseManager.unlock(&"dead_screen")
#endregion

#region Public methods
func update_interface_ratio() -> void:
	aspect_ratio_container.ratio = minf(
		float(aspect_ratio_container.size.x) / float(aspect_ratio_container.size.y),
		maximum_aspect_ratio
	)


func button_handler(id: int = -1) -> void:
	match id:
		0:
			get_tree().paused = !get_tree().paused
			if not get_tree().paused:
				%gpad_broke.hide()
				
			pause_menu.visible = get_tree().paused
			MouseManager.unlock(&"pause_menu")
			%gamepad_hints2.hide()
		1:
			get_tree().paused = !get_tree().paused
			SceneManager.reload_current_scene()
		2:
			settings.process_mode = Node.PROCESS_MODE_ALWAYS
			settings.show()
			menu_buttons.hide()
			label_dead.hide()
		3:
			if not label_dead.visible:
				GameState.save_record()
			SceneManager.change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
			MouseManager.lock(&"main_menu")
		4:
			if not label_dead.visible:
				GameState.save_record()
			get_tree().quit(0)
#endregion

#region Private methods
func _play_ui_reveal_animation() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(aspect_ratio_container, "modulate:a", 1, 1)


func _update_crosshair_spread() -> void:
	player_speed = lerp(player_speed, Global.player.velocity.length(), 0.1)
	var spread_value: float = Global.weapon_manager.recoil_system.get_spread_factor() + player_speed
	crosshair.material.set("shader_parameter/dynamic_spread", spread_value)


func _update_crosshair_position() -> void:
	var unprojected_position: Vector2

	if not Global.weapon_manager.weapon_ray_cast_3d.is_colliding():
		unprojected_position = Global.player.camera_3d.unproject_position(
			Global.weapon_manager.get_ray_end_point()
		)
	else:
		unprojected_position = Global.player.camera_3d.unproject_position(
			Global.weapon_manager.weapon_ray_cast_3d.get_collision_point()
		)

	crosshair.global_position = lerp(
		crosshair.global_position,
		unprojected_position - crosshair.size / 2,
		SystemInfo.fixed_delta_procces * crosshair_snappines
	)
#endregion

#region Event handlers
func _on_close_request() -> void:
	settings.hide()
	settings.process_mode = Node.PROCESS_MODE_DISABLED
	menu_buttons.show()


func _on_weapon_fire_mode_changed(fire_mode: int) -> void:
	fire_mode_label.text = ["Semi", "Auto", "Burst"][fire_mode]
	fire_mode_animation_player.stop()
	fire_mode_animation_player.play("update")


func _on_weapon_add_ui(icon: CompressedTexture2D) -> void:
	var slot: Node = ITEM_SLOT.instantiate()
	slot.icon = icon
	weapons_ui.append(slot)
	slot.slot_number = weapons_ui.size()
	slot.active = false
	weapons_container.add_child(slot)
	EventBus.weapon_added_ui.emit(slot.slot_number - 1, slot)


func _on_weapon_remove_ui(id: int) -> void:
	weapons_ui[id].queue_free()
	weapons_ui.remove_at(id)

	for i: int in weapons_ui.size():
		weapons_ui[i].set_number(i + 1)


func _on_weapon_active(id: int) -> void:
	for ui in weapons_ui:
		ui.set_active(false)
	weapons_ui[id].set_active(true)


func _on_ui_update_crosshair(is_aiming: bool) -> void:
	crosshair.visible = !is_aiming


func _on_ui_update_interactable(text: String) -> void:
	interact_text.visible = text != ""
	interact_text.text = text


func _on_weapon_hitted(hit_color: Color) -> void:
	hit_marker.modulate = hit_color
	hit_marker.rotation_degrees = randf_range(-15, 15)
	hit_marker_animation.stop(false)
	hit_marker_animation.play("fade")


func _on_weapon_add_ammo(ammo_count: int = 0) -> void:
	var label: Node = SCORE_LABEL.instantiate()
	label.text = "Ammunition refilled by %d bullets" % ammo_count
	score_stats.add_child(label)


func _on_add_score(line: String = "SCORE", score: int = 50) -> void:
	var final_score: int = score
	if Global.bonus_controller.is_bonus_active("double_points") and score > 0:
		final_score *= 2

	var cache_key: String = "%s|%d" % [line, final_score]
	if _message_cache.has(cache_key):
		var existing_label: MessageLabel = _message_cache[cache_key]
		if is_instance_valid(existing_label):
			existing_label.increment()
			return

	var label: MessageLabel = SCORE_LABEL.instantiate()
	label.mode = MessageLabel.LabelMode.SCORE
	label.score_line = line
	label.score_value = final_score
	label.set_display_text()
	score_stats.add_child(label)

	_message_cache[cache_key] = label


func _on_ui_message(line: String = "SCORE", lifetime: float = 2.0, parametres: Array = []) -> void:
	var label: Node = SCORE_LABEL.instantiate()
	label.mode = MessageLabel.LabelMode.GENERIC
	label.base_text = line
	label.set_lifetime(lifetime)
	label.set_display_text()
	score_stats.add_child(label)
	label.text = line % parametres


func _on_ui_update_score(score: int) -> void:
	score_label.text = str(score)


func _on_player_changed_health(health: float = 0, _previous_health: float = 0) -> void:
	var health_ratio: float = clampf(1.0 - (health / Global.player.max_health), 0.0, 1.0)
	blood_audio_stream_player.volume_db = linear_to_db(health_ratio)
	blood_texture.modulate.a = health_ratio
	hp_progress_bar.max_value = Global.player.max_health
	hp_progress_bar.value = health
	hp_label.text = "%d" % health


func _on_player_die() -> void:
	death_screen.show()
	MouseManager.lock(&"dead_screen")
	death_screen.play()

	for child: Node in get_children():
		if not child is CanvasLayer:
			if &"visible" in child:
				child.hide()

	player_alive = false
	MouseManager.unlock(&"pause_menu")
	
	get_tree().paused = true


func _on_ui_update_wave(wave: int = 0) -> void:
	wave_container.visible = true
	wave_label.text = tr("KEY_WAVE") % wave


func _on_ui_add_time_bonus(text: String, time: int) -> void:
	var instance: Node = TIME_BONUS_SLOT.instantiate()
	instance.wait_time = time
	instance.label_text = text
	time_bonus_vbox.add_child(instance)


func _on_bonus_nuke_all() -> void:
	nuke_animation_player.play("nuke_animation")


func _on_player_revived() -> void:
	if InputSettings.is_multiplayer:
		return

	for child: Node in active_bonus_hbox.get_children():
		if child.bonus_id == &"quick_revive":
			child.queue_free()
			break
#endregion
