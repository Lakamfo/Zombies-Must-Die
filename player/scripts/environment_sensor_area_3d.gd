extends Area3D

enum StressType { ZOMBIE, SHOT }

@export var stress_stenghold : float = 10.0
@export var stress_per_shot : float = 0.05
@export var stress_per_zombie : float = 0.5
@export var stress_attenuation : float = 1.3

var stress_meter : float = 0.0
var zombies_in_area : Array[Node3D] = []
var status_manager : StatusManager

func _ready() -> void:
	body_entered.connect(f_body_entered)
	body_exited.connect(f_body_exited)
	
	status_manager = (get_owner() as Player).status_manager
	
	EventBus.weapon_fired.connect(func (_weapon) -> void:
		add_stress(StressType.SHOT)
		)


func f_body_entered(body: Node3D):
	if is_instance_of(body, EnemyBase):
		zombies_in_area.append(body)


func f_body_exited(body: Node3D):
	if is_instance_of(body, EnemyBase):
		zombies_in_area.erase(body)

func add_stress(type : StressType):
	match type:
		StressType.SHOT:
			stress_meter += stress_per_shot


func _physics_process(delta):
	var zombie_count : int = zombies_in_area.size()
	var zombie_stress = sqrt(min(zombie_count, 20)) * stress_per_zombie
	
	stress_meter += zombie_stress * delta
	
	stress_meter -= stress_attenuation * delta
	stress_meter = max(stress_meter, 0.0)
	
	if stress_meter > stress_stenghold:
		status_manager.add_effect(StatusEffectPanic.new())
		
		stress_meter = 0.0
