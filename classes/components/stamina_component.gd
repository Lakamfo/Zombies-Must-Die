extends Node
class_name StaminaComponent

@export var enabled : bool = true
@export var current : float = 10.0 :
	set(value):
		current = value
		
		stamina_change_remaped.emit(current / maximum)
		stamina_changed.emit(value)

@export var maximum : float = 5.0
@export var regen_rate : float = 1.5
@export var drain_rate : float = 1.0
@export var regen_treshold : float = 3.0

var timer : Timer = Timer.new()

signal stamina_changed(value : float)
signal stamina_change_remaped(value : float)

func _ready() -> void:
	timer.one_shot = true
	add_child(timer)


func _physics_process(delta: float) -> void:
	if current != maximum and timer.is_stopped():
		current += delta * regen_rate
		
		current = min(current, maximum)
	else:
		if not is_stamina_zero():
			current = 0.0


func try_use(drain : float) -> bool:
	if not is_enough_stamina(drain):
		return false
	
	current -= drain * drain_rate
	
	timer.start(regen_treshold)
	return true

func is_enough_stamina(value : float) -> bool:
	return not current < (value * drain_rate)

func is_stamina_zero() -> bool:
	return not current < 0.05
