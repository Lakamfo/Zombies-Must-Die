class_name BonusController
extends Node

var _active_bonuses: Dictionary = {} 
var _registry: BonusRegistry


func _ready() -> void:
	_registry = Global.bonus_registry
	
	if _registry == null:
		push_error("BonusRegistry not initialized!")
	
	EventBus.scene_changed.connect(func _clear_bonuses() -> void:
		_active_bonuses.clear()
	)


func activate_bonus(bonus_id: String) -> bool:
	if _registry == null or not _registry.is_registered(bonus_id):
		push_error("Bonus not registered: %s" % bonus_id)
		return false
	
	var bonus = _registry.get_bonus(bonus_id)
	if bonus == null:
		return false
	
	if _active_bonuses.has(bonus_id):
		if bonus.stackable and _active_bonuses[bonus_id][&"stacks"] < bonus.max_stacks:
			_active_bonuses[bonus_id][&"stacks"] += 1
			EventBus.bonus_activated.emit(bonus_id, _active_bonuses[bonus_id][&"stacks"])
			return true
		elif not bonus.stackable:
			_active_bonuses[bonus_id][&"time_left"] = bonus.duration
			EventBus.bonus_refreshed.emit(bonus_id)
			return true
		else:
			return false
	
	_active_bonuses[bonus_id] = {
		&"definition": bonus,
		&"stacks": 1,
		&"time_left": bonus.duration,
	}
	
	EventBus.bonus_activated.emit(bonus_id, 1)
	
	if not bonus.endless:
		BonusEffectsManager.apply_bonus_effect(bonus_id)
	
	return true


func deactivate_bonus(bonus_id: String) -> bool:
	if not _active_bonuses.has(bonus_id):
		return false
	
	_active_bonuses.erase(bonus_id)
	
	EventBus.bonus_deactivated.emit(bonus_id)
	BonusEffectsManager.remove_bonus_effect(bonus_id)
	
	return true


func try_purchase_bonus(bonus_id: StringName, player_score: int) -> bool:
	var bonus = _registry.get_bonus(bonus_id)
	if bonus == null or bonus.source != BonusDefinition.Source.MACHINE:
		return false
	
	if player_score < bonus.price:
		return false
	
	EventBus.bonus_purchased.emit(bonus_id, bonus.price)
	return activate_bonus(bonus_id)


func is_bonus_active(bonus_id: StringName) -> bool:
	return _active_bonuses.has(bonus_id)


func get_active_bonuses() -> Array[StringName]:
	return _active_bonuses.keys()


func get_bonus_data(bonus_id: StringName) -> Dictionary:
	if _active_bonuses.has(bonus_id):
		return _active_bonuses[bonus_id]
	return {}


func _process(delta: float) -> void:
	if _registry == null:
		return
		
	for bonus_id in _active_bonuses.keys():
		var bonus_data = _active_bonuses[bonus_id]
		var bonus = bonus_data[&"definition"]
		
		if bonus.is_timed():
			bonus_data[&"time_left"] -= delta
			EventBus.bonus_time_updated.emit(bonus_id, bonus_data[&"time_left"])
			
			if bonus_data[&"time_left"] <= 0:
				deactivate_bonus(bonus_id)
