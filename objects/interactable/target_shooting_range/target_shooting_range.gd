extends AnimatableBody3D

@export var distance : float = 5

func get_hit(dmg, _position, _type : Hitbox.Type) -> void:
	#var _type_string : String = Hitbox.Type.keys()[type]
	
	EventBus.add_score.emit("%dm DMG: %.1f" %[distance, dmg], 0) 
	#EventBus.ui_message.emit("DMG: %.1f" %[dmg]) 
