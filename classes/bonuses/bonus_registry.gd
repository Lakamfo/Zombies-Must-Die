class_name BonusRegistry
extends Node

var _bonuses: Dictionary = {}  
var _bonuses_by_source: Dictionary = {
	BonusDefinition.Source.PICKUP: [],
	BonusDefinition.Source.MACHINE: [],
}


func _ready() -> void:
	_load_bonuses()



func _load_bonuses() -> void:
	register_bonus(preload("res://objects/interactable/vending_machine/resources/quick_revive.tres"))
	register_bonus(preload("res://objects/interactable/vending_machine/resources/juggernog.tres"))
	register_bonus(preload("res://objects/interactable/vending_machine/resources/double_tap.tres"))
	register_bonus(preload("res://objects/interactable/vending_machine/resources/speed_cola.tres"))
	
	
	register_bonus(preload("res://objects/interactable/pickup/resources/double_points.tres"))
	register_bonus(preload("res://objects/interactable/pickup/resources/full_repair.tres"))
	register_bonus(preload("res://objects/interactable/pickup/resources/instant_kill.tres"))
	register_bonus(preload("res://objects/interactable/pickup/resources/max_ammo.tres"))
	register_bonus(preload("res://objects/interactable/pickup/resources/nuke.tres"))


func register_bonus(bonus: BonusDefinition) -> void:
	if _bonuses.has(bonus.id):
		push_error("Bonus %s already registered!" % bonus.id)
		return
	
	_bonuses[bonus.id] = bonus
	_bonuses_by_source[bonus.source].append(bonus.id)


func get_bonus(id: String) -> BonusDefinition:
	if not _bonuses.has(id):
		push_error("Bonus %s not found!" % id)
		return null
	return _bonuses[id]


func get_bonuses_by_source(source: BonusDefinition.Source) -> Array[BonusDefinition]:
	var result: Array[BonusDefinition] = []
	for bonus_id in _bonuses_by_source[source]:
		result.append(_bonuses[bonus_id])
	return result


func get_random_pickup_bonus() -> BonusDefinition:
	var pickups = get_bonuses_by_source(BonusDefinition.Source.PICKUP)
	if pickups.is_empty():
		return null
	return pickups[randi() % pickups.size()]


func is_registered(id: String) -> bool:
	return _bonuses.has(id)
