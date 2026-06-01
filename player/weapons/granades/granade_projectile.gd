extends RigidBody3D

@export var damage : float = 100.0
@export var decay : float = 3.0
@export var impact : bool = false

@export var explode_component : ExplodeComponent
@export var mesh : Node3D

var timer : Timer
var is_exploded : bool = false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not impact:
		return
	
	if state.get_contact_count() > 0:
		play_explode_sequence()


func _ready() -> void:
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer) 
	timer.timeout.connect(_timer_timeout)
	
	timer.start(decay)


func _timer_timeout() -> void:
	play_explode_sequence()


func play_explode_sequence() -> void:
	if is_exploded:
		return
	
	if explode_component:
		mesh.hide()
		is_exploded = true
		
		await explode_component._explode(damage)
		
		queue_free()
