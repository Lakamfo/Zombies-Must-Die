extends HSlider

func _ready() -> void:
	value_changed.connect(_value_changed)


func _value_changed(_value: float):
	accept_event()
