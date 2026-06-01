extends Node

## Singleton for managing game state
## Responsible for score, version tracking and record saving

var current_location_name: String = ""
var current_location_root: Node

#region Score Tracking
var previous_score: int = 0
var earned_score: int = 0
var record_saved: bool = false
#endregion

#region Game Version
var is_latest_game_version: bool = false
var settings_launch_updated: bool = false
#endregion


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Track score updates
	EventBus.ui_update_score.connect(
		func(score: int = 0):
			if score > previous_score:
				earned_score += abs(score - previous_score)
				previous_score = score

			previous_score = score
	)

	# Reset score on scene change
	EventBus.scene_changed.connect(
		func():
			earned_score = 0
			previous_score = 0
	)

	# Reset save flag on scene change
	SceneManager.scene_changed.connect(
		func():
			record_saved = false
	)


func save_record() -> void:
	if record_saved == true:
		return
	#if OS.has_feature("editor"):
		#DebugOutput.print_info("Well, saving points is disabled due to debugging")
		#return
	if Global.wave_logic and is_latest_game_version:
		if Global.wave_logic.get_lifetime() > 30:
			var location_name: String = GameState.current_location_name
			@warning_ignore("narrowing_conversion")
			ServerRequests.finish_run(Global.wave_logic.get_wave(), earned_score, Global.wave_logic.get_lifetime(), location_name.to_upper())
			record_saved = true
			#@warning_ignore("narrowing_conversion")
			#ServerRequests.save_record(ServerRequests.local_player_id, Global.wave_logic.get_wave(), earned_score, Global.wave_logic.get_lifetime(), location_name.to_upper())
			#record_saved = true
