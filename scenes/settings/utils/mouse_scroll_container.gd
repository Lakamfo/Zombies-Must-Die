extends ScrollContainer

class_name ScrollContainerMouse

const stick_r_vhint := preload('uid://jayagp8ksxf5')

var is_dragging: bool = false
var last_drag_position: Vector2 = Vector2.ZERO
var gamepad_scroll_dir: float = 0.0
var gamepad_enabled: bool = false

var gpad_scroll_hint: TextureRect

func _gpad_hint(state: bool) -> void:
	gpad_scroll_hint.visible = state
	gamepad_enabled = state
	if not gamepad_enabled:
		gamepad_scroll_dir = 0.0

func _ready() -> void:
	gpad_scroll_hint = TextureRect.new()
	gpad_scroll_hint.texture = stick_r_vhint
	gpad_scroll_hint.visible = false
	gpad_scroll_hint.z_index = 100
	gpad_scroll_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	gpad_scroll_hint.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	gpad_scroll_hint.scale = Vector2(0.5, 0.5)
	gpad_scroll_hint.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	gpad_scroll_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	
	get_v_scroll_bar().add_child(gpad_scroll_hint)
	
	if Global.gamepad_connected:
		_gpad_hint(true)
	
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void:
		_gpad_hint(Global.gamepad_connected)
	)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and !_is_ui_under_mouse():
				is_dragging = true
				last_drag_position = get_global_mouse_position()
			else:
				is_dragging = false
		elif !event.pressed:
			is_dragging = false

	elif event is InputEventMouseMotion and is_dragging:
		var current_position: Vector2 = get_global_mouse_position()
		var drag_delta: Vector2 = last_drag_position - current_position
		scroll_vertical += int(drag_delta.y)
		last_drag_position = current_position
	elif event is InputEventJoypadMotion and gamepad_enabled:
		if event.axis == JoyAxis.JOY_AXIS_RIGHT_Y && _is_ui_under_focused():
			gamepad_scroll_dir = event.axis_value if abs(event.axis_value) > 0.2 else 0.0

func update_hint_position():
	var v_bar := get_v_scroll_bar()
	if not v_bar:
		return

	if v_bar.max_value <= v_bar.page:
		gpad_scroll_hint.hide()
		return

	gpad_scroll_hint.show()
	var thumb_visual_height = (v_bar.page / v_bar.max_value) * v_bar.size.y

	var range_val = v_bar.max_value - v_bar.page
	var thumb_top = (v_bar.value / range_val) * (v_bar.size.y - thumb_visual_height)

	var thumb_center = thumb_top + (thumb_visual_height / 2)
	gpad_scroll_hint.position.y = thumb_center - (gpad_scroll_hint.size.y / 4)
	gpad_scroll_hint.position.y = clamp(
		gpad_scroll_hint.position.y, 
		0, 
		v_bar.size.y - gpad_scroll_hint.size.y / 2
	)

func _process(_delta: float) -> void:
	if not gamepad_enabled:
		return
		
	scroll_vertical += int(gamepad_scroll_dir * 8.0)
	update_hint_position()

func _is_ui_under_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	
	return !(focus_owner == null or (focus_owner != self and not is_ancestor_of(focus_owner)))

func _is_ui_under_mouse() -> bool:
	var ui_element: Control = get_viewport().gui_get_hovered_control()

	if not ui_element:
		return false

	if ui_element.is_in_group(&"scroll_block"):
		return true

	if ui_element is Slider or ui_element is OptionButton:
		return true

	return false
