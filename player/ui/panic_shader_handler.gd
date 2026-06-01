extends ColorRect

@export var animation_duration : float = 2.0
var is_panic_active : bool = false

var _tween : Tween

func _ready() -> void:
	EventBus.player_added_status_effect.connect(
		added_status_effect_handler
	)
	EventBus.player_removed_status_effect.connect(
		removed_status_effect_handler
	)


func added_status_effect_handler(
	p_status_type : StatusEffect.StatusType
	) -> void:
	
	if p_status_type == StatusEffect.StatusType.PANIC:
		is_panic_active = true
		_play_animation(true)
		
		return


func removed_status_effect_handler(
	p_status_type : StatusEffect.StatusType
	) -> void:
	
	if p_status_type == StatusEffect.StatusType.PANIC:
		is_panic_active = false
		_play_animation(false)
		return

func _play_animation(enabled : bool = false) -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	
	if enabled:
		visible = true
		_tween.tween_property(self, "material:shader_parameter/alpha", 1.0, animation_duration)
	else:
		_tween.tween_property(self, "material:shader_parameter/alpha", 0.0, animation_duration)
		_tween.finished.connect(hide)
