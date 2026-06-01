class_name BonusEffectsManager
extends Node

static var _instance: BonusEffectsManager


func _ready() -> void:
	if _instance == null:
		_instance = self


static func apply_bonus_effect(bonus_id: String) -> void:
	match bonus_id:
		"double_points":
			EventBus.bonus_double_points.emit()
		
		"instant_kill":
			EventBus.bonus_instant_kill.emit()
		
		"nuke":
			EventBus.bonus_nuke_all.emit()
		
		"max_ammo":
			EventBus.bonus_full_ammo.emit()
		
		"full_repair":
			EventBus.bonus_full_repair.emit()
		
		"quick_revive":
			EventBus.bonus_quick_revive.emit()
		
		"juggernog":
			EventBus.bonus_juggernog.emit()
		
		"speed_cola":
			EventBus.bonus_speed_cola.emit()
		
		"double_tap":
			EventBus.bonus_double_tap.emit()


static func remove_bonus_effect(bonus_id: String) -> void:
	match bonus_id:
		"double_points":
			EventBus.bonus_double_points_expired.emit()
		
		"instant_kill":
			EventBus.bonus_instant_kill_expired.emit()
		
		_:
			pass
