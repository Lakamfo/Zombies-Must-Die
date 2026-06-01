extends Panel

@onready var label_dictionary: Dictionary = {
	"enemy_kills": $margin_container/v_box_container/enemy_kills_container/label_value,
	"games_played": $margin_container/v_box_container/games_played_container/label_value,
	"score": $margin_container/v_box_container/score_container/label_value,
}

signal await_signal


func _ready() -> void:
	ServerRequests.player_logged.connect(
		func(_x, _y):
			_emit_signal()
			update()
	)
	get_tree().create_timer(1).timeout.connect(_emit_signal)
	SceneManager.scene_changed.connect(_emit_signal)

	ServerRequests.player_stats_getted.connect(
		func show(dict: Dictionary):
			for x in dict.keys():
				if not x in label_dictionary.keys():
					continue

				label_dictionary[x].text = str(int(dict[x]))
	)

	await await_signal
	update()


func update():
	ServerRequests.get_stats()


func _emit_signal():
	await_signal.emit()
