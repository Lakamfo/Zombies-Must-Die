extends Window

@export var weapons_buy_menu: Control 


func _ready() -> void:
	close_requested.connect(_close_requested)
	weapons_buy_menu.close_requested.connect(close_requested.emit)


func open() -> void:
	show()
	EventBus.ui_player_state.emit(true)


func _close_requested() -> void:
	hide()
	
	EventBus.ui_player_state.emit(false)
