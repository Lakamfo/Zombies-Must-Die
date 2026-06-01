extends InteractableItems

@export var disable_chance : float = 0.05
@export var audio_stream_player : AudioStreamPlayer3D
var is_activated: bool = false :
	set(value):
		EventBus.game_electricity_turn.emit(value)
		is_activated = value


func _ready() -> void:
	interactable_text = get_formatted_description("KEY_OBJECT_POWER_SWITCH_DISABLED")
	EventBus.wave_ended.connect(
		func disable_electricity_with_chance(_wave : int) -> void:
			if not is_activated:
				return
			
			if randf() <= disable_chance:
				EventBus.ui_message.emit(tr("KEY_EVENTS_ELECTRICITY_DISABLED"))
				reset()
	)

func reset() -> void:
	interactable_text = tr("KEY_OBJECT_POWER_SWITCH_DISABLED")
	is_activated = false
	
	EventBus.update_navigation_mesh.emit()

func action():
	if not is_activated:
		is_activated = true
		EventBus.game_electricity_turn.emit(is_activated)
		
		interactable_text = tr("KEY_OBJECT_POWER_SWITCH_ENABLED")
		EventBus.update_navigation_mesh.emit()
		
		if audio_stream_player:
			audio_stream_player.play()
