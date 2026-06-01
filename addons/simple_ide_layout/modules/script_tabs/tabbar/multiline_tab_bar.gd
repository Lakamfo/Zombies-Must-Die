## Tab bar that displays tabs in multiple lines (wrapping) when horizontal
## space is insufficient.
@tool
extends PanelContainer

const CLOSE_BTN_SPACER: String = "    "
const CustomTab := preload("uid://bppomxp4mri2o")

#region Exported / public properties

var plugin: EditorPlugin

var show_close_button_always: bool = false:
	set(value):
		if show_close_button_always == value:
			return
		show_close_button_always = value
		_apply_close_button_visibility()

var is_singleline_tabs: bool = false:
	set(value):
		if is_singleline_tabs == value:
			return
		is_singleline_tabs = value
		_apply_singleline_mode()

# Existing Engine components — set from the plugin.
var script_filter_txt: LineEdit
var scripts_item_list: ItemList
var scripts_tab_container: TabContainer
#endregion

#region Private state

var _tab_group: ButtonGroup = ButtonGroup.new()
var _current_tab: CustomTab
var _popup: PopupPanel
var _split: bool
var _split_path: String
var _split_icon: Texture2D
var _last_drag_over_tab: CustomTab
var _drag_marker: ColorRect
var _suppress_theme_changed: bool
#endregion

#region Theme cache

var _style_hovered: StyleBoxFlat
var _style_focus: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _style_unselected: StyleBoxFlat
var _color_selected: Color
var _color_unselected: Color
var _color_hovered: Color
#endregion

#region Node references

@onready var _flow_container: HFlowContainer = %MultilineTabBar
@onready var split_btn: Button = %SplitBtn
@onready var _popup_btn: Button = %PopupBtn
#endregion

#region Lifecycle

func _init() -> void:
	_tab_group.pressed.connect(_on_tab_selected)


func _ready() -> void:
	_popup_btn.pressed.connect(show_popup)
	split_btn.gui_input.connect(_on_split_btn_input)
	_split_icon = split_btn.icon
	set_process(false)

	if plugin == null:
		return
	schedule_update()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_END, NOTIFICATION_MOUSE_EXIT:
			_clear_drag_marker()
		NOTIFICATION_THEME_CHANGED:
			_on_theme_changed()


func _process(_delta: float) -> void:
	_sync_tabs_with_item_list()
	if is_singleline_tabs:
		_shift_singleline_tabs_to(_current_tab)
	set_process(false)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var can_drop: bool = data.has("index") and data["index"] != get_tab_count() - 1
	if can_drop:
		_on_drag_over(_get_tab(get_tab_count() - 1))
	return can_drop


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		_on_drag_drop(data["index"], get_tab_count() - 1)
#endregion

#region Public API

func schedule_update() -> void:
	set_process(true)


func set_split(value: bool) -> void:
	_split = value
	if _split:
		var index: int = _current_tab.get_index()
		_split_path = scripts_item_list.get_item_tooltip(index)
		split_btn.text = scripts_item_list.get_item_text(index)
		split_btn.icon = scripts_item_list.get_item_icon(index)
		split_btn.tooltip_text = _split_path
	else:
		split_btn.icon = _split_icon
		split_btn.text = ""


func is_split() -> bool:
	return _split


func set_popup(new_popup: PopupPanel) -> void:
	_popup = new_popup


func show_popup() -> void:
	if _popup == null:
		return
	scripts_item_list.get_parent().reparent(_popup)
	scripts_item_list.get_parent().visible = true
	_popup.size = Vector2(250 * _get_editor_scale(), get_parent().size.y - size.y)
	_popup.position = _popup_btn.get_screen_position() - Vector2(_popup.size.x, 0)
	_popup.popup()
	script_filter_txt.grab_focus()


func update_tabs() -> void:
	_on_scripts_changed()
	for tab: CustomTab in _get_all_tabs():
		_update_tab(tab)


func update_selected_tab() -> void:
	_update_tab(_tab_group.get_pressed_button())


func tab_changed() -> void:
	_on_scripts_changed()
	_clear_script_filter()
	_update_tab(_get_tab(scripts_tab_container.current_tab))


func script_order_changed() -> void:
	schedule_update()


func free_tabs() -> void:
	if _drag_marker != null:
		_drag_marker.free()
	for tab: CustomTab in _get_all_tabs():
		_free_tab(tab)
#endregion

#region Tab queries

func get_tab_count() -> int:
	return _flow_container.get_child_count()
#endregion

#region Private — tab management

func _get_all_tabs() -> Array[Node]:
	return _flow_container.get_children()


func _get_tab(index: int) -> CustomTab:
	if index < 0 or index >= get_tab_count():
		return null
	return _flow_container.get_child(index)


func _add_tab() -> CustomTab:
	var tab := CustomTab.new()
	tab.button_group = _tab_group
	if show_close_button_always:
		tab.show_close_button()
	_apply_tab_theme(tab)
	tab.close_pressed.connect(_on_tab_close_pressed.bind(tab))
	tab.right_clicked.connect(_on_tab_right_clicked.bind(tab))
	tab.mouse_exited.connect(_clear_drag_marker)
	tab.dragged_over.connect(_on_drag_over.bind(tab))
	tab.dropped.connect(_on_drag_drop)
	_flow_container.add_child(tab)
	return tab


func _free_tab(tab: CustomTab) -> void:
	if tab.close_button != null:
		tab.close_button.free()
	tab.free()


func _update_tab(tab: CustomTab) -> void:
	if tab == null:
		return
	var index: int = tab.get_index()
	tab.text = scripts_item_list.get_item_text(index)
	tab.icon = scripts_item_list.get_item_icon(index)
	tab.tooltip_text = scripts_item_list.get_item_tooltip(index)
	_apply_tab_icon_color(tab, scripts_item_list.get_item_icon_modulate(index))

	if scripts_item_list.is_selected(index) or show_close_button_always:
		tab.text += CLOSE_BTN_SPACER


func _sync_tabs_with_item_list() -> void:
	# Remove excess tabs
	for index in range(get_tab_count() - 1, scripts_item_list.item_count - 1, -1):
		var tab: CustomTab = _get_tab(index)
		if tab == _current_tab:
			_current_tab = null
		_flow_container.remove_child(tab)
		_free_tab(tab)

	# Add missing tabs and refresh all
	for index in scripts_item_list.item_count:
		var tab: CustomTab = _get_tab(index)
		if tab == null:
			tab = _add_tab()
		_update_tab(tab)


func _on_scripts_changed() -> void:
	_clear_script_filter()
	_popup_btn.text = "(%d)" % scripts_item_list.item_count


func _clear_script_filter() -> void:
	if script_filter_txt.text != &"":
		script_filter_txt.text = ""
		script_filter_txt.text_changed.emit("")
#endregion

#region Private — theme


func _on_theme_changed() -> void:
	if _suppress_theme_changed:
		return
	_suppress_theme_changed = true
	add_theme_stylebox_override(
		&"panel",
		EditorInterface.get_editor_theme().get_stylebox(&"tabbar_background", &"TabContainer")
	)
	_suppress_theme_changed = false

	var et := EditorInterface.get_editor_theme()
	_style_hovered   = et.get_stylebox(&"tab_hovered",    &"TabContainer")
	_style_focus     = et.get_stylebox(&"tab_focus",      &"TabContainer")
	_style_selected  = et.get_stylebox(&"tab_selected",   &"TabContainer")
	_style_unselected = et.get_stylebox(&"tab_unselected", &"TabContainer")

	if _drag_marker == null:
		_drag_marker = ColorRect.new()
		_drag_marker.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
		_drag_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drag_marker.custom_minimum_size.x = 4.0 * EditorInterface.get_editor_scale()
	_drag_marker.color = et.get_color(&"drop_mark_color", &"TabContainer")

	_color_hovered   = et.get_color(&"font_hovered_color",    &"TabContainer")
	_color_selected  = et.get_color(&"font_selected_color",   &"TabContainer")
	_color_unselected = et.get_color(&"font_unselected_color", &"TabContainer")

	if _flow_container == null:
		return
	for tab: CustomTab in _get_all_tabs():
		_apply_tab_theme(tab)


func _apply_tab_theme(tab: CustomTab) -> void:
	tab.add_theme_stylebox_override(&"normal",        _style_unselected)
	tab.add_theme_stylebox_override(&"hover",         _style_hovered)
	tab.add_theme_stylebox_override(&"hover_pressed", _style_hovered)
	tab.add_theme_stylebox_override(&"focus",         _style_focus)
	tab.add_theme_stylebox_override(&"pressed",       _style_selected)
	tab.add_theme_color_override(&"font_color",         _color_unselected)
	tab.add_theme_color_override(&"font_hover_color",   _color_hovered)
	tab.add_theme_color_override(&"font_pressed_color", _color_selected)


func _apply_tab_icon_color(tab: CustomTab, color: Color) -> void:
	for prop: StringName in [
		&"icon_normal_color", &"icon_hover_color", &"icon_hover_pressed_color",
		&"icon_pressed_color", &"icon_focus_color",
	]:
		tab.add_theme_color_override(prop, color)
#endregion

#region Private — close button visibility

func _apply_close_button_visibility() -> void:
	if _flow_container == null:
		return
	for tab: CustomTab in _get_all_tabs():
		var index: int = tab.get_index()
		tab.text = scripts_item_list.get_item_text(index)
		if show_close_button_always:
			tab.text += CLOSE_BTN_SPACER
			if not tab.button_pressed:
				tab.show_close_button()
		else:
			if not tab.button_pressed:
				tab.hide_close_button()
			else:
				tab.text += CLOSE_BTN_SPACER
#endregion

#region Private — drag & drop

func _on_drag_over(tab: CustomTab) -> void:
	if _last_drag_over_tab == tab:
		return
	tab.add_child(_drag_marker)
	_last_drag_over_tab = tab


func _on_drag_drop(source_index: int, target_index: int) -> void:
	scripts_tab_container.move_child(
		scripts_tab_container.get_child(source_index),
		target_index
	)
	_get_tab(target_index).grab_focus()


func _clear_drag_marker() -> void:
	if _last_drag_over_tab == null:
		return
	if _drag_marker.get_parent() != null:
		_drag_marker.get_parent().remove_child(_drag_marker)
	_last_drag_over_tab = null
#endregion

#region Private — signal callbacks

func _on_tab_selected(tab: CustomTab) -> void:
	if not show_close_button_always:
		if _current_tab != null:
			_current_tab.hide_close_button()
		if tab != null:
			tab.show_close_button()

	_clear_script_filter()

	var index: int = tab.get_index()
	if scripts_item_list != null and not scripts_item_list.is_selected(index):
		scripts_item_list.select(index)
		scripts_item_list.item_selected.emit(index)
		scripts_item_list.ensure_current_is_visible()

	if not show_close_button_always and _current_tab != null:
		_update_tab(_current_tab)

	_current_tab = tab


func _on_tab_close_pressed(tab: CustomTab) -> void:
	scripts_item_list.item_clicked.emit(
		tab.get_index(),
		scripts_item_list.get_local_mouse_position(),
		MOUSE_BUTTON_MIDDLE
	)


func _on_tab_right_clicked(tab: CustomTab) -> void:
	scripts_item_list.item_clicked.emit(
		tab.get_index(),
		scripts_item_list.get_local_mouse_position(),
		MOUSE_BUTTON_RIGHT
	)


func _on_split_btn_input(event: InputEvent) -> void:
	if not split_btn.button_pressed:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.is_pressed() or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	split_btn.button_pressed = false
	if _split_path != null and ResourceLoader.exists(_split_path):
		EditorInterface.edit_resource(load(_split_path))
#endregion

#region Private — singleline mode

func _apply_singleline_mode() -> void:
	if is_singleline_tabs:
		item_rect_changed.connect(_on_singleline_rect_changed)
		_tab_group.pressed.connect(_ensure_current_tab_visible.unbind(1))
		if _flow_container != null:
			_shift_singleline_tabs_to(_current_tab)
	else:
		item_rect_changed.disconnect(_on_singleline_rect_changed)
		_tab_group.pressed.disconnect(_ensure_current_tab_visible)
		if _flow_container != null:
			for tab: CustomTab in _get_all_tabs():
				tab.visible = true


func _ensure_current_tab_visible() -> void:
	if _current_tab != null and not _current_tab.visible:
		_shift_singleline_tabs_to(_current_tab)


func _on_singleline_rect_changed() -> void:
	if _current_tab != null and not _current_tab.visible:
		_shift_singleline_tabs_to(_current_tab)
		return
	for tab: CustomTab in _get_all_tabs():
		if tab.visible:
			_shift_singleline_tabs_to(tab)
			break


func _shift_singleline_tabs_to(start_tab: CustomTab) -> void:
	var bar_width: float = _flow_container.size.x
	var accumulated: float = 0.0
	var started: bool = false

	for tab: CustomTab in _get_all_tabs():
		if start_tab == null or tab == start_tab:
			started = true
		if started:
			accumulated += tab.size.x
			tab.visible = accumulated <= bar_width
		else:
			tab.visible = false

	# If current tab was cut off, retry from it
	if _current_tab != null and not _current_tab.visible:
		if start_tab != _current_tab:
			_shift_singleline_tabs_to(_current_tab)
			return

	if start_tab == null:
		return

	# Fill space to the left of start_tab
	for index in range(start_tab.get_index() - 1, -1, -1):
		var tab: CustomTab = _get_all_tabs().get(index)
		accumulated += tab.size.x
		if accumulated > bar_width:
			return
		tab.visible = true
#endregion

#region Private — helpers

func _get_editor_scale() -> float:
	return EditorInterface.get_editor_scale()
#endregion
