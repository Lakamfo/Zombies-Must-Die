extends Control


@export var label_text: String = "2x"

@onready var label: Label = $label

@onready var texture_rect_bg: TextureRect = $texture_rect_bg
@onready var texture_rect_glow: TextureRect = $texture_rect_glow
@onready var texture_rect_fg: TextureRect = $texture_rect_fg
@onready var texture_rect_icon: TextureRect = $texture_rect_icon

var icon : Texture2D
var color : Color = Color(1.0, 1.0, 1.0, 0.5)
var bonus_id : StringName

var _total_time: float = 0.0
var _time_left: float = 0.0
var _stacks: int = 1

var _pulse_tween: Tween
var _intro_tween: Tween
var _exit_tween: Tween

func _ready() -> void:
	label.text = label_text

	modulate.a = 0.0
	texture_rect_glow.modulate = Color(
		color.r,
		color.g,
		color.b,
		0.5
	)
	texture_rect_fg.modulate = color
	
	
	scale = Vector2(0.85, 0.85)
	texture_rect_icon.texture = icon
	
	_play_intro()
	
	EventBus.bonus_time_updated.connect(func _update_time(_bonus_id : StringName, time : float) -> void:
		if _bonus_id == bonus_id:
			update_time(time)
		)
	EventBus.bonus_deactivated.connect(func _deactivate(_bonus_id : StringName) -> void:
		if _bonus_id == bonus_id:
			_play_exit()
		)


func set_total_time(time: float) -> void:
	_total_time = time
	_time_left = time


func set_stacks(count: int) -> void:
	_stacks = count
	_update_label()


func update_time(time_left: float) -> void:
	_time_left = time_left
	_update_label()
	_update_visual_state()


func _update_label() -> void:
	if _stacks > 1:
		label.text = "%s x%d" % [label_text, _stacks]
	else:
		label.text = label_text


func _update_visual_state() -> void:
	if _total_time <= 0:
		return

	var ratio := _time_left / _total_time

	if ratio < 0.3:
		_start_pulse()
	else:
		_stop_pulse()



func _play_intro() -> void:
	if _intro_tween:
		_intro_tween.kill()

	_intro_tween = create_tween()
	_intro_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_intro_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.2)


func _play_exit() -> void:
	if _exit_tween:
		_exit_tween.kill()

	set_process(false)

	_exit_tween = create_tween()
	_exit_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_exit_tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.25)
	_exit_tween.tween_callback(queue_free)


func _start_pulse() -> void:
	if _pulse_tween:
		return

	_pulse_tween = create_tween()
	_pulse_tween.set_loops()

	_pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.25)
	_pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null

	scale = Vector2.ONE


func is_active() -> bool:
	return _time_left > 0
