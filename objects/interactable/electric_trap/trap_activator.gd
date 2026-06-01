class_name ElectricTrapActivator
extends InteractableItems

@export var price: int = 1000
@export var electric_trap: ElectricTrap

var electricity_enabled: bool = false

@onready var trap_is_active_string = tr("KEY_OBJECT_ELECTRIC_TRAP") + ' ' + tr("KEY_OBJECT_ACTIVE")

signal started
signal ended


func _ready() -> void:
	EventBus.game_electricity_turn.connect(
		func(p_enabled : bool = true):
			electricity_enabled = p_enabled
			if electricity_enabled:
				interactable_text = get_formatted_description("KEY_OBJECT_BUY_HINT") % [tr("KEY_OBJECT_ELECTRIC_TRAP"), price]
			else:
				interactable_text = tr("KEY_OBJECT_ELECTRICITY_HINT")
	)
	interactable_text = tr("KEY_OBJECT_ELECTRICITY_HINT")

	if electric_trap:
		electric_trap.attack_ended.connect(
			func():
				ended.emit()
		)


func action():
	if electric_trap:
		if not electricity_enabled:
			return

		if not electric_trap.active:
			var player = Global.player

			if player.score >= price:
				EventBus.emit_signal("add_score", tr("KEY_OBJECT_BUYED_MESSAGE") % [tr("KEY_OBJECT_ELECTRIC_TRAP")], -price)
				electric_trap.activate()
				started.emit()
	else:
		DebugOutput.print_warning("No electric trap" + str(self))


func get_description() -> String:
	if electric_trap:
		if electric_trap.active:
			return trap_is_active_string
		else:
			return interactable_text
	else:
		return "NO TRAP, PLEASE REPORT"
