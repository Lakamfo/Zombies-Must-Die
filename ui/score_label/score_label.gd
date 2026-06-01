extends Control

class_name MessageLabel
enum LabelMode { GENERIC, SCORE }
var text: String:
	set(value):
		if not label:
			await ready
		text = value
		base_text = text

		set_display_text()
@onready var label: RichTextLabel = $text_label
@onready var timer: Timer = $timer
@export var mode: LabelMode = LabelMode.GENERIC
@export var play_shake: bool = true
@export var shake_color: Color = Color(1.0, 0.2, 0.2, 1)
@export var start_color: Color = Color(1, 1, 1, 0)
@export var mid_color: Color = Color(1, 1, 1, 1)
@export var end_color: Color = Color(1, 1, 1, 0)
@export var horizontal_alignment: HorizontalAlignment:
	set(value):
		if not label:
			await ready
		label.horizontal_alignment = value
		horizontal_alignment = value
@export var vertical_alignment: VerticalAlignment:
	set(value):
		if not label:
			await ready
		label.vertical_alignment = value
		vertical_alignment = value
@export_group("Animation")
@export var animation_show_duration: float = 0.1
@export var animation_hide_duration: float = 1.5
@export var lifetime: float = 2.0
var count: int = 1
var score_line: String = ""
var score_value: int = 0
var base_text: String = ""
var _is_disappearing: bool = false
var _disappear_tween: Tween = null

var _shake_tween: Tween

signal remove_cached_message(instance: MessageLabel)

func _ready() -> void:
	modulate = start_color
	timer.start(lifetime)

	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", mid_color, animation_show_duration)
	tween.play()

	custom_minimum_size = label.size


func _on_timer_timeout() -> void:
	if _is_disappearing:
		return
	_is_disappearing = true

	_disappear_tween = get_tree().create_tween()
	_disappear_tween.parallel()
	_disappear_tween.tween_property(self, "modulate", end_color, animation_hide_duration)
	_disappear_tween.play()
	await _disappear_tween.finished

	remove_cached_message.emit(self)

	queue_free()


func set_display_text():
	if not label:
		await ready

	if mode == LabelMode.SCORE:
		var _sign = "+" if score_value >= 0 else ""
		label.text = "%s%s 🪙 · %s" % [_sign, str(score_value), str(score_line)]
		if count > 1:
			label.text += " x%d" % count
	elif mode == LabelMode.GENERIC:
		label.text = base_text
		if count > 1:
			label.text += " x%d" % count

	custom_minimum_size = label.size


func set_lifetime(time : float) -> void:
	lifetime = time
	#timer.start(lifetime)


func increment():
	count += 1
	set_display_text()

	# Reset disappearance process
	if _is_disappearing:
		_is_disappearing = false
		if _disappear_tween and _disappear_tween.is_valid():
			_disappear_tween.kill()
		modulate = mid_color

	if not play_shake or not is_instance_valid(label) or is_queued_for_deletion():
		timer.start(lifetime)
		return

	animate_shake()
	timer.start(lifetime)


func animate_shake():
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	label.position = Vector2.ZERO
	label.scale = Vector2.ONE

	_shake_tween = get_tree().create_tween()
	var original_pos = Vector2.ZERO 
	var shake_count = 4
	var strength = min(20.0, 5.0 * count)
	var shake_duration = 0.03

	for i in shake_count:
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * strength
		_shake_tween.tween_property(label, "position", original_pos + offset, shake_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		strength *= 0.6
		_shake_tween.tween_property(label, "position", original_pos, shake_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	label.modulate = shake_color
	_shake_tween.parallel()
	_shake_tween.tween_property(label, "modulate", mid_color, 0.3).set_trans(Tween.TRANS_CUBIC)
	_shake_tween.parallel()
	_shake_tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.05)
	_shake_tween.tween_property(label, "scale", Vector2(1, 1), 0.15)
