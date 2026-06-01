@tool
extends SIL_BaseModule
class_name SIL_FilesystemPanelModule

#region Constants
const SETTING_ENABLED: String = SIMPLE_IDE_LAYOUT + "filesystem/enabled"
#endregion

#region State
var editor: ScriptEditor
var plugin: EditorPlugin
var side_panel: Control
var filesystem_data: SIL_FileSystemDataDTO

var _temporal_parent: Control
var _enabled: bool = false
#endregion

#region Lifecycle
func _init(
	plugin: EditorPlugin,
	editor: ScriptEditor,
	filesystem: FileSystemDock
) -> void:
	self.plugin = plugin
	self.editor = editor
	self.filesystem_data = _get_filesystem_data(filesystem)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var es := EditorInterface.get_editor_settings()
		if es.settings_changed.is_connected(_sync_settings):
			es.settings_changed.disconnect(_sync_settings)


## Enable FileSystem render in the ScriptEditor's side panel
func enable() -> void:
	default_settings[SETTING_ENABLED] = true
	_init_editor_settings(default_settings)
	
	if _enabled:
		return
	
	if not _get_settings(default_settings).get(SETTING_ENABLED, true):
		return
	
	side_panel = _get_side_panel()
	if not side_panel:
		return push_error("SIL_FilesystemPanelModule: side panel not found")
	
	_temporal_parent = _init_temporal_parent()
	
	for child in side_panel.get_children():
		child.reparent(_temporal_parent)
	
	plugin.main_screen_changed.connect(_on_main_screen_changed)
	
	var es := EditorInterface.get_editor_settings()
	if not es.settings_changed.is_connected(_sync_settings):
		es.settings_changed.connect(_sync_settings)
	
	_enabled = true


## Move FileSystem to its previous position and revert all changes
func disable() -> void:
	if not _enabled:
		return
	
	if not _temporal_parent:
		return push_warning("SIL_FilesystemPanelModule: temporal parent not found, disabling silently")
	
	plugin.main_screen_changed.disconnect(_on_main_screen_changed)
	
	_reset_filesystem_position()
	
	for child in _temporal_parent.get_children():
		child.reparent(side_panel)
	
	_temporal_parent.queue_free()
	_temporal_parent = null
	_enabled = false
#endregion

#region Filesystem positioning
## Move FileSystem inside the ScriptEditor side panel
func _move_filesystem_to_editor() -> void:
	if not filesystem_data:
		return
	
	_temporal_parent.visible = false
	
	var filesystem := filesystem_data.filesystem
	filesystem.reparent(side_panel)
	side_panel.move_child(filesystem, 2)


## Revert FileSystem back to its original position
func _reset_filesystem_position() -> void:
	
	if not filesystem_data:
		return
	
	_temporal_parent.visible = true
	
	var filesystem := filesystem_data.filesystem
	filesystem.reparent(filesystem_data.original_parent)
	filesystem_data.original_parent.move_child(filesystem, filesystem_data.original_index)
#endregion

#region Helpers
func _get_filesystem_data(filesystem: FileSystemDock) -> SIL_FileSystemDataDTO:
	return SIL_FileSystemDataDTO.new(
		filesystem,
		filesystem.get_parent(),
		filesystem.get_index()
	)


func _get_side_panel() -> Control:
	var splits := editor.find_children("*", "HSplitContainer", true, false)
	if splits.is_empty():
		return null
	return splits[0].get_child(0)


## Creates an invisible container to hold the original side panel contents.
## Needed because hiding individual children is more reliable than
## toggling visibility on the panel itself.
func _init_temporal_parent() -> Control:
	var invisible_parent := Control.new()
	invisible_parent.name = "SIL_InvisibleParent"
	invisible_parent.visible = false
	side_panel.get_parent().add_child(invisible_parent)
	return invisible_parent
#endregion

#region Signal callbacks
func _sync_settings() -> void:
	var changed := EditorInterface.get_editor_settings().get_changed_settings()
	if not changed.has(SETTING_ENABLED):
		return
	
	if _get_settings(default_settings).get(SETTING_ENABLED, true):
		enable()
	else:
		disable()


func _on_main_screen_changed(screen_name: String) -> void:
	if screen_name == "Script":
		_move_filesystem_to_editor()
	else:
		_reset_filesystem_position()
#endregion
