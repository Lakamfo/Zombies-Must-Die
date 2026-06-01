extends SIL_BaseModule
class_name SIL_GITGutter

const GUTTER_NAME = &"git_gutter"
const SETTING_ENABLED = SIMPLE_IDE_LAYOUT + GUTTER_NAME + &"/" + &"enabled"
const SETTING_ADDED_COLOR = SIMPLE_IDE_LAYOUT + GUTTER_NAME + &"/" + &"added_color"
const SETTING_MODIFIED_COLOR = SIMPLE_IDE_LAYOUT + GUTTER_NAME + &"/" + &"modified_color"
const SETTING_DELETED_COLOR = SIMPLE_IDE_LAYOUT + GUTTER_NAME + &"/" + &"deleted_color"
const SETTING_GUTTER_WIDTH = SIMPLE_IDE_LAYOUT + GUTTER_NAME + &"/" + &"gutter_width"

var editor: ScriptEditor
var ce: CodeEdit

var last_result: Dictionary = {}
var current_script: Script


func enable() -> void:
	default_settings = {
		SETTING_ENABLED: true,
		SETTING_ADDED_COLOR: Color("#4CAF50"),
		SETTING_MODIFIED_COLOR: Color("#4FC3F7"),
		SETTING_DELETED_COLOR: Color("#F44336"),
		SETTING_GUTTER_WIDTH: 6
	}

	_init_editor_settings(default_settings)

	if not _get_settings(default_settings).get(SETTING_ENABLED, true):
		return

	editor = EditorInterface.get_script_editor()
	call_deferred("_connect_editor_signal")


func _connect_editor_signal() -> void:
	editor.editor_script_changed.connect(_on_script_changed)

func disable() -> void:
	if editor.editor_script_changed.is_connected(_on_script_changed):
		editor.editor_script_changed.disconnect(_on_script_changed)
	_remove_gutter()

func _on_script_changed(script: Script) -> void:
	if not _get_settings(default_settings).get(SETTING_ENABLED, true):
		disable()
		return

	last_result = {}
	_clear_markers()

	current_script = script
	if not script:
		return

	if script.is_built_in():
		return

	last_result = _get_git_changed_lines(script.resource_path)
	_ensure_gutter()
	_mark_changed_lines(last_result)

func refresh() -> void:
	if not current_script:
		return
	last_result = _get_git_changed_lines(current_script.resource_path)
	_clear_markers()
	_mark_changed_lines(last_result)

func _ensure_gutter() -> void:
	ce = _get_current_code_edit()
	if not ce:
		return
	for i in ce.get_gutter_count():
		if ce.get_gutter_name(i) == GUTTER_NAME:
			return


	ce.add_gutter(0)
	ce.set_gutter_name(0, GUTTER_NAME)
	ce.set_gutter_type(0, TextEdit.GUTTER_TYPE_STRING)
	ce.set_gutter_width(
		0,
		_get_settings(self.default_settings).get(SETTING_GUTTER_WIDTH)
	)
	ce.set_gutter_draw(0, true)

func _remove_gutter() -> void:
	ce = _get_current_code_edit()
	if not ce:
		return
	for i in ce.get_gutter_count():
		if ce.get_gutter_name(i) == GUTTER_NAME:
			ce.remove_gutter(i)
			return

func _get_gutter_index() -> int:
	if not ce:
		return -1
	for i in ce.get_gutter_count():
		if ce.get_gutter_name(i) == GUTTER_NAME:
			return i
	return -1

func _get_git_changed_lines(path: String) -> Dictionary:
	var os_path = ProjectSettings.globalize_path(path)
	var out := []
	var exit_code := OS.execute("git", ["diff", "--unified=0", os_path], out, true)

	if exit_code != 0:
		print("Git diff failed for: ", out[0].split('\n')[0].split('.')[0])
		return {}

	var added: Array = []
	var deleted: Array = []
	var modified: Array = []
	var current_new_line := 0

	for l in out:
		for raw in l.split("\n"):
			var line = raw.strip_edges(true, false)
			if line.begins_with("@@"):
				var plus_idx = line.find("+")
				var space_idx = line.find(" ", plus_idx)
				var comma_idx = line.find(",", plus_idx)
				if comma_idx != -1 and comma_idx < space_idx:
					current_new_line = int(line.substr(plus_idx + 1, comma_idx - plus_idx - 1))
				else:
					current_new_line = int(line.substr(plus_idx + 1, space_idx - plus_idx - 1))
			elif line.begins_with("+"):
				added.append(current_new_line - 1)
				current_new_line += 1
			elif line.begins_with("-"):
				deleted.append(current_new_line - 1)
			elif line.begins_with(" "):
				current_new_line += 1

	var deleted_map : Dictionary = {}

	for line in deleted:
		deleted_map[line] = true

	for line in added:
		if deleted_map.has(line):
			added.erase(line)
			deleted.erase(line)
			modified.append(line)

	return { "added": added, "deleted": deleted, "modified": modified}

func _mark_changed_lines(result: Dictionary) -> void:
	ce = _get_current_code_edit()
	if not ce:
		return
	_ensure_gutter()
	var gutter = _get_gutter_index()
	if gutter == -1:
		return

	for line in result.get("added", []):
		if line >= 0 and line < ce.get_line_count():
			ce.set_line_gutter_text(line, gutter, "|")
			ce.set_line_gutter_item_color(
				line,
				gutter,
				_get_settings(self.default_settings).get(SETTING_ADDED_COLOR)
			)
	for line in result.get("modified", []):
		if line >= 0 and line < ce.get_line_count():
			ce.set_line_gutter_text(line, gutter, "|")
			ce.set_line_gutter_item_color(
				line,
				gutter,
				_get_settings(self.default_settings).get(SETTING_MODIFIED_COLOR)
			)
	for line in result.get("deleted", []):
		if line >= 0 and line < ce.get_line_count():
			ce.set_line_gutter_text(line, gutter, "|")
			ce.set_line_gutter_item_color(
				line,
				gutter,
				_get_settings(self.default_settings).get(SETTING_DELETED_COLOR)
			)


func _clear_markers() -> void:
	ce = _get_current_code_edit()
	if not ce:
		return
	var gutter = _get_gutter_index()
	if gutter == -1:
		return
	for i in ce.get_line_count():
		ce.set_line_gutter_text(i, gutter, "")
		ce.set_line_gutter_item_color(i, gutter, Color(0, 0, 0, 0))

func _get_current_code_edit() -> CodeEdit:
	var current = editor.get_current_editor()
	if not current:
		return null
	var children = current.find_children("*", "CodeEdit", true, false)
	if children.is_empty():
		return null
	return children[0] as CodeEdit
