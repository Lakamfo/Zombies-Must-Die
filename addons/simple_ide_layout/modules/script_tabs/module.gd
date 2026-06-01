## Module responsible for the multiline tab bar in the Script Editor.
## Replaces the default tab bar with a custom multiline version
## and manages split view, scripts popup, and tab cycling.
extends SIL_BaseModule
class_name SIL_ScriptTabsModule

const MULTILINE_TAB_BAR: PackedScene = preload("uid://vjuhunm2uboy")
const SPLIT_CODE_EDIT := preload("uid://boy48rhhyrph")

#region Setting path const
const SETTING_CATEGORY_PATH: String = SIMPLE_IDE_LAYOUT + "tabs/"
const SETTING_TABS_ENABLED: String = SETTING_CATEGORY_PATH + "enabled"
const SETTING_USE_DEFAULT_TABS: String = SETTING_CATEGORY_PATH + "use_default_tabs"
const SETTING_METHOD_LIST_VISIBLE: String = SETTING_CATEGORY_PATH + "method_list_visible"
const SETTING_VISIBLE: String = SETTING_CATEGORY_PATH + "visible"
const SETTING_POSITION_TOP: String = SETTING_CATEGORY_PATH + "position_top"
const SETTING_CLOSE_BUTTON_ALWAYS: String = SETTING_CATEGORY_PATH + "close_button_always"
const SETTING_SINGLELINE: String = SETTING_CATEGORY_PATH + "singleline"
#endregion


## Emitted when the active tab changes. Main plugin can connect
## to update outline and other dependant modules.
signal tab_changed(index: int)

var plugin: EditorPlugin
var editor: ScriptEditor

var defaults: Dictionary[StringName, Variant]

var _script_item_list_height: float = 500.0

#region Existing Engine controls

var old_scripts_tab_container: TabContainer
var old_scripts_tab_bar: TabBar
var script_filter_txt : LineEdit
var scripts_item_list : ItemList
var script_panel_split_container : Control
var top_vbox : VBoxContainer
#endregion

#region Own controls
var multiline_tab_bar  # MultilineTabBar (untyped to avoid global class pollution)
var scripts_popup: PopupPanel
var tab_splitter: HSplitContainer
#endregion

#region State
var _is_tabs_top: bool = true
#endregion

func _init(plugin: EditorPlugin, editor: ScriptEditor) -> void:
	self.plugin = plugin
	self.editor = editor


func enable() -> void:
	default_settings = {
		SETTING_TABS_ENABLED: true,
		SETTING_USE_DEFAULT_TABS: false,
		SETTING_METHOD_LIST_VISIBLE: true,
		SETTING_VISIBLE: true,
		SETTING_POSITION_TOP: true,
		SETTING_CLOSE_BUTTON_ALWAYS: false,
		SETTING_SINGLELINE: false,
	}
	_init_editor_settings(default_settings)
	
	EditorInterface.get_editor_settings().settings_changed.connect(_on_settings_changed)
	
	top_vbox = _get_top_vbox()
	
	var s : Dictionary = _get_settings(default_settings)
	if not s.get(SETTING_TABS_ENABLED, true):
		return
	
	var es := EditorInterface.get_editor_settings()
	if not es.settings_changed.is_connected(_sync_settings):
		es.settings_changed.connect(_sync_settings)
	
	# Grab existing UI references
	scripts_item_list = _find_child(editor, "ItemList")
	script_filter_txt = _find_child(scripts_item_list.get_parent(), "LineEdit")
	script_panel_split_container = scripts_item_list.get_parent().get_parent()
	
	old_scripts_tab_container = _find_child(editor, "TabContainer")
	old_scripts_tab_bar = old_scripts_tab_container.get_tab_bar()
	old_scripts_tab_bar.tab_changed.connect(_on_tab_changed)
	old_scripts_tab_container.child_order_changed.connect(_on_order_changed)
	
	scripts_item_list = _find_scripts_item_list(editor)
	
	var methods_list: ItemList = _find_methods_item_list(editor)
	var side_panel: Control = _get_side_panel()

	if methods_list != null and side_panel != null and s.get(SETTING_METHOD_LIST_VISIBLE, true):
		methods_list.reparent(side_panel)
		side_panel.move_child(methods_list, 1)
		
	if scripts_item_list != null and s.get(SETTING_USE_DEFAULT_TABS, false):
		defaults[&"parent"] = scripts_item_list.get_parent()
		defaults[&"size_flags_vertical"] = scripts_item_list.size_flags_vertical
		defaults[&"custom_minimum_size:y"] = scripts_item_list.custom_minimum_size.y
		defaults[&"auto_height"] = scripts_item_list.auto_height
		defaults[&"max_columns"] = 0
		
		scripts_item_list.reparent(top_vbox)
		scripts_item_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		scripts_item_list.custom_minimum_size.y = 48
		scripts_item_list.auto_height = not s.get(SETTING_SINGLELINE, false)
		scripts_item_list.max_columns = 32
		
		# Move to the top of container
		top_vbox.move_child(scripts_item_list, 1)
		
		if side_panel != null:
			script_filter_txt.reparent(side_panel)
			side_panel.move_child(script_filter_txt, 0)
		
		return
	
	# Wrap tab container in a splitter so split-view works
	var tab_parent: Control = old_scripts_tab_container.get_parent()
	
	tab_splitter = HSplitContainer.new()
	tab_splitter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_splitter.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	tab_parent.add_child(tab_splitter)
	tab_parent.move_child(tab_splitter, 0)
	old_scripts_tab_container.reparent(tab_splitter)
	
	# Create and insert our multiline tab bar
	multiline_tab_bar = MULTILINE_TAB_BAR.instantiate()
	multiline_tab_bar.set(&"plugin", plugin)
	multiline_tab_bar.scripts_item_list   = scripts_item_list
	multiline_tab_bar.script_filter_txt   = script_filter_txt
	multiline_tab_bar.scripts_tab_container = old_scripts_tab_container
	
	tab_parent.add_theme_constant_override(&"separation", 0)
	tab_parent.add_child(multiline_tab_bar)
	
	multiline_tab_bar.split_btn.toggled.connect(_toggle_split_view.unbind(1))
	
	# Apply settings
	_is_tabs_top = s.get("simple_ide/tabs/position_top", true)
	multiline_tab_bar.show_close_button_always = s.get(SETTING_CLOSE_BUTTON_ALWAYS, false)
	multiline_tab_bar.is_singleline_tabs = s.get(SETTING_SINGLELINE, false)
	multiline_tab_bar.visible = s.get(SETTING_VISIBLE, true)
	
	_update_tabs_position()
	_create_scripts_popup()


func disable() -> void:
	EditorInterface.get_editor_settings().settings_changed.disconnect(_on_settings_changed)
	
	var s := _get_settings(default_settings)
	
	if scripts_item_list != null and s.get(SETTING_USE_DEFAULT_TABS, false):
		if defaults[&"parent"]:
			scripts_item_list.reparent(defaults[&"parent"])
		
		for key in defaults.keys():
			if key == &"parent":
				continue
			
			scripts_item_list.set(key, defaults[key])
	
	if old_scripts_tab_bar != null:
		old_scripts_tab_bar.tab_changed.disconnect(_on_tab_changed)
	
	if old_scripts_tab_container != null:
		old_scripts_tab_container.child_order_changed.disconnect(_on_order_changed)
	
	if tab_splitter != null:
		var tab_parent: Control = tab_splitter.get_parent()
		old_scripts_tab_container.reparent(tab_parent)
		tab_parent.move_child(old_scripts_tab_container, 1)
		tab_parent.remove_theme_constant_override(&"separation")
		tab_parent.remove_child(multiline_tab_bar)
		tab_splitter.free()
		tab_splitter = null
	
	if multiline_tab_bar != null:
		multiline_tab_bar.free_tabs()
		multiline_tab_bar.free()
		multiline_tab_bar = null
	
	if scripts_popup != null:
		scripts_popup.free()
		scripts_popup = null


#region Public API (called by main plugin or other modules)

## Call after the active tab changes to sync the multiline bar.
func notify_tab_changed() -> void:
	if multiline_tab_bar != null:
		multiline_tab_bar.tab_changed()

## Call after a filesystem / save change to refresh all tab labels.
func update_tabs() -> void:
	if multiline_tab_bar != null:
		multiline_tab_bar.update_tabs()

## Sync the visual selection on the multiline bar after an external change.
func update_selected_tab() -> void:
	if multiline_tab_bar != null:
		multiline_tab_bar.update_selected_tab()

func open_scripts_popup() -> void:
	if multiline_tab_bar != null:
		multiline_tab_bar.show_popup()

func hide_scripts_popup() -> void:
	if scripts_popup != null and scripts_popup.visible:
		scripts_popup.hide.call_deferred()
#endregion

#region Private handlers
func _sync_settings() -> void:
	var changed := EditorInterface.get_editor_settings().get_changed_settings()
	if not changed.has(SETTING_SINGLELINE):
		return
	
	if scripts_item_list != null:
		var value: bool = _get_settings(default_settings).get(SETTING_SINGLELINE, true)
		scripts_item_list.auto_height = not value
#endregion

#region Private helpers

func _on_tab_changed(index: int) -> void:
	if not multiline_tab_bar:
		return
	
	var script_editor_base: ScriptEditorBase = editor.get_current_editor()
	
	if not multiline_tab_bar.is_split():
		var split_btn = multiline_tab_bar.get(&"split_btn")
		if split_btn != null:
			split_btn.disabled = script_editor_base == null

	tab_changed.emit(index)


func _on_order_changed() -> void:
	if multiline_tab_bar != null:
		multiline_tab_bar.script_order_changed()


func _toggle_split_view() -> void:
	var current_base: ScriptEditorBase = editor.get_current_editor()

	if not multiline_tab_bar.is_split():
		if current_base == null:
			return
		var base_editor: Control = current_base.get_base_editor()
		if not (base_editor is CodeEdit):
			return
		
		multiline_tab_bar.set_split(true)
		
		var split_edit: CodeEdit = SPLIT_CODE_EDIT.new_from(base_editor)
		var container := PanelContainer.new()
		container.custom_minimum_size.x = 200
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(split_edit)
		tab_splitter.add_child(container)
	else:
		multiline_tab_bar.set_split(false)
		tab_splitter.get_child(tab_splitter.get_child_count() - 1).free()
		
		if current_base == null:
			multiline_tab_bar.split_btn.disabled = true


func _update_tabs_position() -> void:
	var tab_parent: Control = multiline_tab_bar.get_parent()
	if _is_tabs_top:
		tab_parent.move_child(multiline_tab_bar, 0)
	else:
		tab_parent.move_child(multiline_tab_bar, tab_parent.get_child_count() - 1)


func _create_scripts_popup() -> void:
	scripts_popup = PopupPanel.new()
	scripts_popup.popup_hide.connect(_on_scripts_popup_hidden)
	editor.add_child(scripts_popup)
	multiline_tab_bar.set_popup(scripts_popup)


func _on_scripts_popup_hidden() -> void:
	script_filter_txt.text = &""
	# Restore the item list to its original place inside the panel split container
	scripts_item_list.get_parent().reparent(script_panel_split_container)
	script_panel_split_container.move_child(scripts_item_list.get_parent(), 0)


func _on_settings_changed() -> void:
	var changed := EditorInterface.get_editor_settings().get_changed_settings()
	for key: String in changed:
		match key:
			SETTING_VISIBLE:
				multiline_tab_bar.visible = EditorInterface.get_editor_settings().get_setting(key)
			SETTING_POSITION_TOP:
				_is_tabs_top = EditorInterface.get_editor_settings().get_setting(key)
				_update_tabs_position()
			SETTING_CLOSE_BUTTON_ALWAYS:
				multiline_tab_bar.show_close_button_always = EditorInterface.get_editor_settings().get_setting(key)
			SETTING_SINGLELINE:
				multiline_tab_bar.is_singleline_tabs = EditorInterface.get_editor_settings().get_setting(key)


func _get_side_panel() -> Control:
	var splits := editor.find_children("*", "HSplitContainer", true, false)
	if splits.is_empty():
		return null
	return splits[0].get_child(0)


func _get_top_vbox() -> VBoxContainer:
	var editor_root = EditorInterface.get_script_editor()
	return editor_root.get_child(0)


func _find_methods_item_list(root: Node) -> ItemList:
	var lists = root.find_children("*", "ItemList", true, false)
	
	if lists.is_empty():
		return null
	
	return lists[1]


func _find_scripts_item_list(root: Node) -> ItemList:
	var lists = root.find_children("*", "ItemList", true, false)
	
	if lists.is_empty():
		return null
	
	return lists[0]


static func _find_child(root: Node, type: String) -> Node:
	var found := root.find_children("*", type, true, false)
	if found.is_empty():
		push_error("SIL_ScriptTabsModule: could not find node of type '%s' in '%s'" % [type, root.name])
		return null
	return found[0]
#endregion
