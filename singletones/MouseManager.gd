# MouseManager.gd (autoload)
extends Node

var _locks: Array[StringName] = []

func lock(id: StringName) -> void:
	if not _locks.has(id):
		_locks.append(id)
	_apply()


func unlock(id: StringName) -> void:
	_locks.erase(id)
	_apply()


func _apply() -> void:
	if _locks.is_empty():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
