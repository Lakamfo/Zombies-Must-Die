class_name MapGenDoor
extends StaticBody3D

@export var area_3d: Area3D
@export var animation_player: AnimationPlayer
@export var audio_stream_player: AudioStreamPlayer3D

@onready var battle_id: int = get_owner().get_meta("battle_id", -1)
@onready var room_id: int = get_owner().get_meta("id", 0)
@onready var can_be_opened: bool = room_id == 1

@onready var free_open: bool = get_owner().get_meta(&"free_open", false)
var is_opened: bool = false


func _ready() -> void:
	if battle_id == -1:
		can_be_opened = true
	
	EventBus.wave_started.connect(
		func(wave: int):
			if battle_id == wave:
				animation_player.play("open", -1.0, -2.0, true)
				self.set_collision_layer_value(1, true)
				is_opened = false
				can_be_opened = false
	)
	EventBus.wave_ended.connect(
		func(wave: int):
			if wave == battle_id:
				can_be_opened = true
	)
	area_3d.body_entered.connect(
		func(body: PhysicsBody3D):
			if is_opened:
				return
			if not can_be_opened and not free_open:
				return
			if Global.wave_logic.is_wave_in_progress:
				return

			if body is Player:
				animation_player.play("open", -1, 2.0)
				audio_stream_player.play()
				is_opened = true
				self.set_collision_layer_value(1, false)
	)
