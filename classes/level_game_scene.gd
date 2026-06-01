class_name LevelGameScene
extends Node3D

#region Signals
#endregion

#region Exports
@export var player: Player
@export var wave_logic: WaveLogic
@export var mystery_box: Node3D
@export var world_environment: WorldGameEnvironment
#endregion

#region Variables
#endregion

#region Onready variables
#endregion

#region Lifecycle methods
func _ready() -> void:
	GameState.current_location_root = self
	
	_print_active_modifiers()
	_setup_player_loadout()
	_setup_wave_logic()
	
	MaterialHelper.setup_scene_materials(SceneTreeUtils.get_all_children(self))
#endregion

#region Public methods
#endregion

#region Private methods
func _print_active_modifiers() -> void:
	var mod_active_names: Array[String] = []
	for modifier in ModifiersManager.active_modifiers.keys():
		mod_active_names.append(ModifiersManager.get_modifier_name(modifier))
	DebugOutput.print_info('Active Modifiers : ' + str(mod_active_names))


func _setup_player_loadout() -> void:
	if not player:
		return

	if not ModifiersManager.active_modifiers.has(ModifiersManager.Modifiers.LondonModifier):
		# FSP45 ID  - 1
		player.weapon_manager.add_weapon(1)
	else:
		if mystery_box:
			mystery_box.queue_free()


func _setup_wave_logic() -> void:
	if wave_logic:
		wave_logic.small_zombies_only = ModifiersManager.active_modifiers.has(
			ModifiersManager.Modifiers.SmallZombiesOnlyModifier
		)
		ServerRequests.start_run(GameState.current_location_name)
#endregion

#region Event handlers
#endregion
