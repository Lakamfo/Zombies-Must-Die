class_name BonusUIController
extends Node

const BONUS_SLOT = preload("uid://dfcjvnew7vpdj")

@export var ui_container_pickup  : HBoxContainer
@export var ui_container_machine : HBoxContainer

var _active_slots: Dictionary = {}


func _ready() -> void:
	EventBus.bonus_activated.connect(_on_bonus_activated)
	EventBus.bonus_refreshed.connect(_on_bonus_refreshed)
	EventBus.bonus_deactivated.connect(_on_bonus_deactivated)
	EventBus.bonus_time_updated.connect(_on_bonus_time_updated)


func _on_bonus_activated(bonus_id: String, stacks: int) -> void:
	var bonus = Global.bonus_registry.get_bonus(bonus_id)
	if bonus == null:
		return
	
	if _active_slots.has(bonus_id):
		var slot = _active_slots[bonus_id]
		slot.set_stacks(stacks)
		return
	
	var ui = BONUS_SLOT.instantiate()
	ui.label_text = bonus.label
	if bonus.is_timed():
		ui.set_total_time(bonus.duration)
	
	ui.bonus_id = bonus_id
	ui.icon = bonus.icon
	ui.color = bonus.color
	
	match bonus.source:
		BonusDefinition.Source.PICKUP:
			ui_container_pickup.add_child(ui)
		BonusDefinition.Source.MACHINE:
			ui_container_machine.add_child(ui)
	
	_active_slots[bonus_id] = ui
	
	if bonus.show_ui_message:
		EventBus.ui_message.emit(bonus.label + " " + tr("KEY_BONUS_COLLECTED"))


func _on_bonus_refreshed(bonus_id: String) -> void:
	var bonus = Global.bonus_registry.get_bonus(bonus_id)
	if bonus == null or not _active_slots.has(bonus_id):
		return
	
	var slot = _active_slots[bonus_id]
	if bonus.is_timed():
		slot.set_total_time(bonus.duration)


func _on_bonus_deactivated(bonus_id: String) -> void:
	if _active_slots.has(bonus_id):
		# Hide/outro/exit animation and queue_free() inside slot logic
		_active_slots.erase(bonus_id)


func _on_bonus_time_updated(bonus_id: String, time_left: float) -> void:
	if _active_slots.has(bonus_id):
		var slot = _active_slots[bonus_id]
		slot.update_time(time_left)
