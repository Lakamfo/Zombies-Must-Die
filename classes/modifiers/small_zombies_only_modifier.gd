#"res://classes/modifiers/small_zombies_only_modifier.gd"
extends BaseModifier
class_name SmallZombiesOnlyModifier

#!!!Active logic in LevelGameScene!!!

func _init() -> void:
	modifier_name = &"Small Zombies Only"


#func apply_to_wave_logic(wave_logic: WaveLogic) -> void:
#wave_logic.small_zombies_only = true
