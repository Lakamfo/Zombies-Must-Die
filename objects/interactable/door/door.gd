extends InteractableItems

@export var open_price: int = 1050
@export var new_spawns: Array[NodePath]
@export_node_path("WaveLogic") var _wave_logic_path

@onready var animation_player: AnimationPlayer = $animation_player
#@onready var navigation_obstacle : NavigationObstacle3D = $navigation_obstacle_3d

var is_opened: bool = false
var wave_logic_node: WaveLogic
var spawns: Array[Node] = []

@onready var audio_stream_player_3d: AudioStreamPlayer3D = $audio_stream_player_3d


func _ready():
	interactable_text = get_formatted_description("KEY_OBJECT_GATE") % [open_price]
	animation_player.play("RESET")

	if _wave_logic_path:
		wave_logic_node = get_node_or_null(_wave_logic_path)

	EventBus.ui_update_score.connect(
		func(score: int = 0):
			if is_opened:
				return
			if score >= open_price:
				animation_player.play("idle_money")
			elif score < open_price:
				animation_player.play("RESET")
	)

	for spawn in new_spawns:
		spawns.push_back(get_node_or_null(spawn))


func action():
	if enabled:
		var player = Global.player

		if player.score >= open_price:
			EventBus.emit_signal("add_score", tr("KEY_OBJECT_GATE_MESSAGE"), -open_price)
			if wave_logic_node: wave_logic_node.add_spawns(spawns)
			is_opened = true
			audio_stream_player_3d.play()
			#navigation_obstacle.avoidance_enabled = false

			collision_layer = 0
			animation_player.play("open")

			await get_tree().physics_frame

			EventBus.update_navigation_mesh.emit()
