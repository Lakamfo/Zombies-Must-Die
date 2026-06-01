extends Panel

@onready var text_edit: TextEdit = $text_edit


func _ready() -> void:
	var file = FileAccess.open("res://THIRDPARTYLICENSE.txt", FileAccess.READ)

	if file:
		text_edit.text = file.get_as_text()
