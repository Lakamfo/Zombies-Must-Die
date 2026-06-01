@tool
extends CanvasLayer

@export_tool_button('Play Sequence') var play_action = play

@onready var bg_color_rect: ColorRect = $bg_color_rect
@onready var static_shader: ColorRect = %static_shader

@onready var sway_pivot: Control = %sway_pivot
@onready var elements_control: Control = $elements_control

@onready var scull_texture_rect: TextureRect = %scull_texture_rect
@onready var blood_texture_rect: TextureRect = %blood_texture_rect

@onready var audio_stream_player: AudioStreamPlayer = %audio_stream_player
@onready var lspslash_guilding_lights: AudioStreamPlayer = %lspslash_guilding_lights

@onready var scull_pivot: Control = %scull_pivot

@onready var scull_init: Control = %scull_init
@onready var scull_center: Control = %scull_center
@onready var scull_upper: Control = %scull_upper

@onready var label_stats: Label = %label_stats
@onready var panel: Panel = %panel

var _time: float = 0.0
var label_stats_pos: Vector2 = Vector2.ZERO
var start_bg_color: Color


func _exit_tree():
	kill_tweens()


func kill_tweens():
	for t in get_tree().get_processed_tweens():
		t.kill()


func _ready() -> void:
	label_stats_pos = label_stats.position
	start_bg_color = bg_color_rect.material.get("shader_parameter/color_over")

	if Engine.is_editor_hint():
		return

	%exit_menu.pressed.connect(
		func():
			SceneManager.change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	)
	%exit_desktop.pressed.connect(
		func():
			get_tree().quit()
	)
	%restart.pressed.connect(
		func():
			get_tree().paused = !get_tree().paused
			SceneManager.reload_current_scene()
	)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if visible:
		_time += delta
		var x = sin(_time * 1.3) * 30 + sin(_time * 0.7) * 20
		var y = cos(_time * 1.1) * 30 + cos(_time * 0.5) * 20

		sway_pivot.position = Vector2(x, y)

		elements_control.position = (Vector2(x, y) / 3.0) * -1.0
		label_stats.position += ((Vector2(x, y) / 2.7)) * delta


func play() -> void:
	sway_pivot.position = Vector2.ZERO

	label_stats.modulate.a = 0.0
	label_stats.position = label_stats_pos

	panel.modulate.a = 0.0

	var location_name: String = ''

	if not Engine.is_editor_hint():
		location_name = GameState.current_location_name

		if Global.wave_logic:
			var lifetime_formated: String = seconds_to_hms_string(int(Global.wave_logic.get_lifetime()))
			var kills: int = Global.wave_logic.get_enemies_kill_count()
			var wave: int = Global.wave_logic.get_wave()

			label_stats.text = ''
			label_stats.text = "LOCATION : %s | SCORE : %s | LIFETIME : %s | KILLS : %s | WAVE : %s" % [location_name, GameState.earned_score, lifetime_formated, kills, wave]

	scull_texture_rect.modulate.a = 0.0
	scull_texture_rect.pivot_offset = scull_texture_rect.size / 2.0
	scull_pivot.global_position = scull_init.global_position

	await get_tree().create_timer(0.1).timeout

	# ANIM SEQUENCE
	lspslash_guilding_lights.play()
	audio_stream_player.play()

	var tween = create_tween()

	animate_shake()

	tween.tween_property(bg_color_rect.material, "shader_parameter/color_over", start_bg_color, 0.5).from(Color(1.0, 0.161, 0.0))
	tween.parallel().tween_property(scull_texture_rect, "modulate:a", 1.0, 1.0).from(0.0)
	tween.parallel().tween_property(bg_color_rect.material, "shader_parameter/color_over", start_bg_color, 0.5).from(Color(1.0, 0.161, 0.0)).set_delay(0.5)

	tween.parallel().tween_property(scull_pivot, "position", scull_center.position, 0.5) \
	.set_trans(Tween.TRANS_SINE).from(scull_init.position)

	tween.parallel().tween_property(static_shader.material, "shader_parameter/BORDER_SIZE", 0.0, 1.0).from(0.3) \
	.set_trans(Tween.TRANS_EXPO)

	# Blood shader
	tween.set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(blood_texture_rect.material, "shader_parameter/visibility", -1.0, 0.7).from(1.0)

	tween.tween_interval(0.2)

	tween.tween_property(panel, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_property(label_stats, "modulate:a", 1.0, 0.5).from(0.0)

func animate_shake():
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	scull_texture_rect.pivot_offset = scull_texture_rect.size * 0.5

	var tween = create_tween()

	var original_pos = scull_texture_rect.position
	var shake_count = rng.randi_range(2, 2)
	var strength = 60.0
	var shake_duration = 0.02

	tween.parallel().tween_property(scull_texture_rect, "scale", Vector2(2, 2), 0.05)

	for i in shake_count:
		var _offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * rng.randf_range(10, strength)
		var duration = rng.randf_range(shake_duration, shake_duration * 2.0)

		tween.tween_property(scull_texture_rect, "position", original_pos + _offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(scull_texture_rect, "rotation_degrees", rng.randf_range(-10, 10), duration).set_trans(Tween.TRANS_SINE)
		tween.tween_property(scull_texture_rect, "position", original_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(scull_texture_rect, "rotation_degrees", 0.0, duration).set_trans(Tween.TRANS_SINE)

	tween.tween_property(scull_texture_rect, "scale", Vector2(1, 1), 0.15)


func seconds_to_hms_string(seconds: int) -> String:
	var hours: int = floor(seconds) / 3600.0
	var minutes: int = floor(seconds % 3600) / 60
	var secs = seconds % 60

	return str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2) + ":" + str(secs).pad_zeros(2)
