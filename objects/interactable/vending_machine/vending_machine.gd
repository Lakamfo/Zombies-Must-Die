@tool
extends InteractableItems

@export var price: int = 500
## &"double_tap", &"juggernog", &"quick_revive", &"speed_cola"
@export var bonus_id: StringName = &"quick_revive":
	set(value):
		bonus_id = value
		set_model()
@export var random: bool = false
@onready var mesh_root: Node3D = $mesh_root
@onready var collision_shape_3d: CollisionShape3D = $collision_shape_3d
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $audio_stream_player_3d

var is_buyed: bool = false
var electricity_enabled: bool = false


func set_model() -> void:
	if mesh_root:
		if mesh_root.get_child_count() > 0:
			mesh_root.get_children()[0].queue_free()

		var mesh = load("res://objects/interactable/vending_machine/models/%s_unique.tscn" % bonus_id)
		var mesh_instance 
		
		if mesh:
			mesh_instance = mesh.instantiate()
		else:
			return
		
		if collision_shape_3d:
			collision_shape_3d.set_deferred("disabled", true)
			await get_tree().process_frame

			collision_shape_3d.shape = null
			collision_shape_3d.rotation_degrees.y = -90 if bonus_id == &"quick_revive" else 0

			var shape_path = "res://objects/interactable/vending_machine/collisions/%s.tres" % bonus_id
			var shape := load(shape_path)
			
			if shape:
				collision_shape_3d.shape = shape

			collision_shape_3d.set_deferred("disabled", false)

		mesh_root.add_child(mesh_instance)
		mesh_instance.owner = self


func _ready() -> void:
	if Engine.is_editor_hint():
		set_model()
		return

	if random:
		var bonus = Global.bonus_registry.get_random_pickup_bonus()
		if bonus:
			bonus_id = bonus.id
	
	set_model()
	
	EventBus.game_electricity_turn.connect(func(turn_on: bool) -> void:
		electricity_enabled = turn_on
		update_interactable_text()
	)
	
	update_interactable_text()


func update_interactable_text() -> void:
	var bonus = Global.bonus_registry.get_bonus(bonus_id)
	if bonus == null:
		return
	
	if not electricity_enabled and bonus_id != &"quick_revive":
		interactable_text = tr(&"KEY_OBJECT_ELECTRICITY_HINT")
		return
	
	if is_buyed:
		interactable_text = tr(&"KEY_OBJECT_ALREADY_BUYED") % ["(%s)" % tr(bonus.label)]
		return
	
	interactable_text = get_formatted_description(&"KEY_OBJECT_BUY_HINT") % [tr(bonus.label), price]
	
	if bonus_id == &"quick_revive" and InputSettings.is_multiplayer == false:
		EventBus.player_revived.connect(func():
			is_buyed = false
			update_interactable_text()
		)


func reset_buy() -> void:
	is_buyed = false


func action() -> void:
	if not enabled or is_buyed:
		return
	
	var player = Global.player
	var bonus = Global.bonus_registry.get_bonus(bonus_id)
	
	if bonus == null:
		return
	
	if not electricity_enabled and bonus_id != &"quick_revive":
		return
	
	if player.score < price:
		return
	
	if Global.bonus_controller.activate_bonus(bonus_id):
		EventBus.emit_signal("add_score", tr("KEY_OBJECT_BUYED_MESSAGE") % [tr(bonus.label)], -price)
		audio_stream_player_3d.play()
		is_buyed = true
		update_interactable_text()
