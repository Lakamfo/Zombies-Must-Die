class_name StatusManager
extends Node

var player : Player = owner
var effects: Dictionary[StatusEffect.StatusType, StatusEffect]

func _ready() -> void:
	#add_effect(StatusEffectPanic.new())
	pass

func _physics_process(delta: float) -> void:
	update(delta)

func add_effect(effect: StatusEffect) -> void:
	if effect.type in effects:
		effects[effect.type].intensity += 1.0
		effects[effect.type].duration += effect.duration
	else:
		effects[effect.type] = effect
		EventBus.player_added_status_effect.emit(effect.type)
	
	effect.apply(player)

func update(delta : float) -> void:
	for effect : StatusEffect.StatusType in effects:
		effects[effect].update(player, delta)
		effects[effect].duration -= delta
		
		if effects[effect].duration <= 0:
			
			effects[effect].remove(player)
			EventBus.player_removed_status_effect.emit(effect)
			effects.erase(effect)


func get_modifier(stat : StringName) -> float:
	var value : float = 1.0
	
	for effect : StatusEffect in effects.values():
		if not is_instance_valid(effect):
			continue
		
		var mods : Dictionary[StringName, float] = effect.get_modifiers()
		
		if mods.has(stat):
			value *= mods[stat]
	
	return value
