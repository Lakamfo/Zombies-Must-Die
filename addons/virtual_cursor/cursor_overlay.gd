extends Node

@onready var game_window : Window = get_window()
@onready var cursor_pivot: Control = $cursor_pivot
@onready var cursor_texture: TextureRect = $cursor_pivot/CursorTexture

const DISAPPEAR_TIME : float = 10.0
const CURSOR_FRICTION : float = 15.0

var cursor_speed : float = 800.0 #pixels per second
var timer : Timer = Timer.new()
var input_axis : Vector2 = Vector2.ZERO

var dead_zone : float = 0.09
var click_activation_treshold : float = 0.6

var triggers_clicked : Vector2i = Vector2i.ZERO
var mouse_locked : bool = false
var cursor_hiden : bool = false

var velocity : Vector2 = Vector2.ZERO

var screen_size : Vector2 = Vector2.ZERO

var tween : Tween

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	
	timer.one_shot = true
	timer.wait_time = DISAPPEAR_TIME / 2.0

func _ready() -> void:
	cursor_texture.modulate.a = 0.0
	
	screen_size = get_viewport().size
	timer.timeout.connect(hide_idle)
	
	cursor_pivot.global_position = screen_size / 2.0
	get_viewport().size_changed.connect(func update_screen_size():
		screen_size = get_viewport().size
		cursor_pivot.global_position = get_viewport().size / 2.0
		)

func _unhandled_input(event: InputEvent) -> void:
	_input(event)

func _input(event: InputEvent) -> void:
	if not cursor_pivot or cursor_hiden or mouse_locked:
		return
	
	if event is InputEventJoypadMotion:
		# Stick
		if event.axis == JOY_AXIS_LEFT_X:
			input_axis.x = 0.0
			if abs(event.axis_value) > dead_zone:
				input_axis.x = event.axis_value
				cursor_pivot.show()

		elif event.axis == JOY_AXIS_LEFT_Y:
			input_axis.y = 0.0
			if abs(event.axis_value) > dead_zone:
				input_axis.y = event.axis_value
				cursor_pivot.show()

		# Triggers
		elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
			if event.axis_value > click_activation_treshold and not triggers_clicked.y:
				var press_event := InputEventMouseButton.new()
				press_event.position = cursor_pivot.global_position * game_window.content_scale_factor
				press_event.button_index = MOUSE_BUTTON_RIGHT
				press_event.pressed = true
				press_event.device = -1
				get_viewport().push_input(press_event)
				#Input.parse_input_event(press_event)
				play_press()
	
			elif event.axis_value <= click_activation_treshold and triggers_clicked.y:
				var release_event := InputEventMouseButton.new()
				release_event.position = cursor_pivot.global_position * game_window.content_scale_factor
				release_event.button_index = MOUSE_BUTTON_RIGHT
				release_event.pressed = false
				release_event.device = -1
				get_viewport().push_input(release_event)
				#Input.parse_input_event(release_event)
				play_release()
			
			triggers_clicked.y = 1 if event.axis_value > click_activation_treshold else 0
		
		elif event.axis == JOY_AXIS_TRIGGER_LEFT:
			if event.axis_value > click_activation_treshold and not triggers_clicked.x:
				var press_event := InputEventMouseButton.new()
				press_event.position = cursor_pivot.global_position * game_window.content_scale_factor
				press_event.button_index = MOUSE_BUTTON_LEFT
				press_event.pressed = true
				press_event.device = -1
				get_viewport().push_input(press_event)
				
				#Input.parse_input_event(press_event)
				play_press()

			elif event.axis_value <= click_activation_treshold and triggers_clicked.x:
				var release_event := InputEventMouseButton.new()
				release_event.position = cursor_pivot.global_position * game_window.content_scale_factor
				release_event.button_index = MOUSE_BUTTON_LEFT
				release_event.pressed = false
				release_event.device = -1
				get_viewport().push_input(release_event)
				#Input.parse_input_event(release_event)
				play_release()

			triggers_clicked.x = 1 if event.axis_value > click_activation_treshold else 0
	else:
		if event is InputEventMouse:
			if event.device != -1:
				cursor_pivot.global_position = screen_size / 2.0
				cursor_pivot.hide()

func _process(delta: float) -> void:
	mouse_locked = Input.mouse_mode in [
		Input.MouseMode.MOUSE_MODE_CAPTURED,
		Input.MouseMode.MOUSE_MODE_HIDDEN,
		Input.MouseMode.MOUSE_MODE_CONFINED_HIDDEN
	]
	
	if mouse_locked:
		cursor_pivot.global_position = screen_size / 2.0
		cursor_pivot.hide()
	
	var old_velocity : Vector2 = velocity
	velocity = velocity.lerp((input_axis * cursor_speed / game_window.content_scale_factor) * delta, CURSOR_FRICTION * delta)
	
	cursor_pivot.global_position += velocity
	
	cursor_pivot.global_position.x = clamp(cursor_pivot.global_position.x, 0, screen_size.x / game_window.content_scale_factor)
	cursor_pivot.global_position.y = clamp(cursor_pivot.global_position.y, 0, screen_size.y / game_window.content_scale_factor)
	
	if not is_zero_approx((old_velocity - velocity).length_squared()):
		var mouse_event : InputEventMouseMotion = InputEventMouseMotion.new()
		mouse_event.position = cursor_pivot.global_position * game_window.content_scale_factor
		mouse_event.relative = old_velocity - velocity
		mouse_event.device = InputEvent.DEVICE_ID_EMULATION
		get_viewport().push_input(mouse_event)
	
	if not input_axis:
		if timer.is_stopped() and not cursor_hiden:
			timer.start()
		return
	else:
		timer.stop()
		show_moving()

func hide_idle():
	tween = create_tween()
	
	tween.tween_property(cursor_texture,'modulate',Color(1.0, 1.0, 1.0, 0.0), DISAPPEAR_TIME / 2.0)

func show_moving():
	if triggers_clicked.x or triggers_clicked.y:
		return
	if tween:
		tween.stop()
	
	cursor_texture.modulate = Color(1.0, 1.0, 1.0, 1.0)

func play_press():
	cursor_pivot.scale = Vector2.ONE
	tween = create_tween()
	
	tween.tween_property(cursor_pivot, "scale", Vector2(0.75, 0.75), 0.05)
	tween.parallel()
	tween.tween_property(cursor_texture, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.1)


func play_release():
	if triggers_clicked.x and triggers_clicked.y:
		return 
	
	cursor_pivot.scale = Vector2.ONE
	tween = create_tween()
	
	tween.tween_property(cursor_pivot, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel()
	tween.tween_property(cursor_texture, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
