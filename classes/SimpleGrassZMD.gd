@icon("res://addons/simplegrasstextured/sgt_icon.svg")
@tool
extends "res://addons/simplegrasstextured/grass.gd"
class_name GrassZMD

func _ready():
	super()
	
	if not Engine.is_editor_hint():
		EventBus.update_settings.connect(_update_settings)
		
		_update_settings()


func _update_settings() -> void:
	visible = GraphicsSettings.vegetation
	set_process(visible)
