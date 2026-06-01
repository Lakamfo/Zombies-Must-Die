class_name StatusEffectPanic
extends StatusEffect

func _init() -> void:
	duration = 5.0

func get_modifiers() -> Dictionary[StringName, float]:
	return {
		&"speed_mult": 1.1,
		&"recoil_mult": 1.1,
		&"camera_shake_modifier":1.02 * (intensity)
	}
