extends AnimationPlayer

@onready var control: Control = $control


func _ready() -> void:
	control.pivot_offset = control.size / 2
	control.resized.connect(
		func():
			control.pivot_offset = control.size / 2
	)
	animation_finished.connect(_splash_ended)

	control.visible = true
	
	if SystemInfo.game_launch_state:
		if randf() > 0.05:
			self.play('fade_splash')
		else:
			self.play('fade_splash_video')
	else:
		control.visible = false

func _splash_ended(_name : String) -> void:
	control.visible = false
