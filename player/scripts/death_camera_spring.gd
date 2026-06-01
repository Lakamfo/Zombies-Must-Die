extends SpringArm3D

class_name DeathCameraSpring

@export var enabled: bool = true
@export var rotation_speed: float = 10.0

@onready var camera_3d: Camera3D = $camera_3d


func _ready() -> void:
	set_process(false)
	EventBus.player_die.connect(
		func():
			if not enabled:
				return
			visible = true
			set_process(true)
			camera_3d.make_current()
			process_mode = Node.PROCESS_MODE_ALWAYS
	)


func _process(delta: float) -> void:
	rotation_degrees.y += delta * rotation_speed
