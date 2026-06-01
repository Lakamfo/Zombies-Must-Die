extends InteractableItems

var wave_logic_node: WaveLogic
var spawns: Array = []

@onready var _r_collision_layer : int = collision_layer

func _ready():
	interactable_text = tr("KEY_OBJECT_ELECTRICITY_HINT")

	EventBus.game_electricity_turn.connect(
		func handler(p_enabled : bool):
			if p_enabled:
				collision_layer = 0
				hide()
			else:
				collision_layer = _r_collision_layer
				show()
	)
