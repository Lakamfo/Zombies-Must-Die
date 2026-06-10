extends Node

## Singleton for managing core game resources
## Stores references to critical game objects
## For other settings use specialized singletons:
## - GraphicsSettings: graphics configuration
## - GameState: game state (score)
## - InputSettings: input configuration
## - SystemInfo: system information

#region Essential Game Resources
var player: Player
var wave_logic: WaveLogic
var weapon_manager: WeaponManager

var players: Array = []
#endregion

#region Bonus System
var bonus_registry: BonusRegistry
var bonus_controller: BonusController
var bonus_effects_manager: BonusEffectsManager
#endregion

#region GamePad visitor

var gamepad_connected: bool = false

# jo
func _on_joy_state_changed(device: int, connected: bool) -> void:
	gamepad_connected = Input.get_connected_joypads().size() != 0

#endregion

func _ready() -> void:
	_initialize_bonus_system()

	Input.joy_connection_changed.connect(_on_joy_state_changed)

func _initialize_bonus_system() -> void:
	bonus_registry = BonusRegistry.new()
	add_child(bonus_registry)
	
	bonus_controller = BonusController.new()
	add_child(bonus_controller)
	bonus_controller.process_mode = Node.PROCESS_MODE_INHERIT
	
	bonus_effects_manager = BonusEffectsManager.new()
	add_child(bonus_effects_manager)
