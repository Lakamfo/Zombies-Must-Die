#"res://classes/modifiers/fast_zombies_modifier.gd"
extends BaseModifier
class_name FastZombiesModifier


func _init() -> void:
	modifier_name = &"Fast Zombies"


func apply(event_name: StringName, data: Dictionary) -> void:
	if event_name == &"enemy_spawned":
		var enemy = data.enemy
		if &"speed" in enemy:
			enemy.speed *= 2
		if &"attack_threshold_time" in enemy:
			enemy.attack_threshold_time /= 1.2
