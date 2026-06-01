extends InteractableItems

@export var menu : Control

@export var animation_player : AnimationPlayer
@export var animation_name : StringName = &"litle_open"

@onready var weapons: Node3D = $weapons

var is_opened : bool = false

func _ready() -> void:
	focus_changed.connect(_focus_changed)
	
	if menu:
		menu.close_requested.connect(_close_requested)
		


func action():
	if menu: 
		menu.show()
		EventBus.ui_player_state.emit(true)
		MouseManager.lock(&"weapon_buy_menu")


func get_description() -> String:
	return get_formatted_description(&"KEY_OBJECT_WEAPON_SAFE")


func _focus_changed(value : bool) -> void:
	if not (animation_player and animation_name):
		return
	
	if value:
		is_opened = true
		
		animation_player.play(animation_name)
		weapons.show()
	else:
		is_opened = false
		
		animation_player.play_backwards(animation_name)
		
		await animation_player.animation_finished
		if not is_opened:
			weapons.hide()


func _close_requested() -> void:
	if menu:
		menu.hide()
		EventBus.ui_player_state.emit(false)
		MouseManager.unlock(&"weapon_buy_menu")
