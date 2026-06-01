extends Panel

@export var hide_threshold : float = 1.0
@export var animation_duration : float = 0.5

var mat : ShaderMaterial
var tween : Tween
var timer : Timer = Timer.new()

func _ready() -> void:
	EventBus.player_stamina_changed_remaped.connect(_stamina_value_changed)
	mat = material
	
	timer.one_shot = true
	timer.timeout.connect(_hide)
	
	add_child(timer)

func _stamina_value_changed(value : float):
	mat.set_shader_parameter(&"progress", value)
	
	if not visible or tween:
		_show()
	
	if value >= 1.0:
		timer.start(hide_threshold)

func _show() -> void:
	if tween:
		tween.kill()
	show()
	
	tween = create_tween()
	
	tween.tween_property(self, "modulate:a", 1.0, animation_duration)\
	.set_ease(Tween.EASE_IN_OUT)

func _hide() -> void:
	if tween:
		tween.kill()
	
	tween = create_tween()
	
	tween.tween_property(self, "modulate:a", 0.0, animation_duration)\
	.set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(hide)
