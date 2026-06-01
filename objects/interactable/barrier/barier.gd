extends InteractableItems

class_name GameBarier

@export var max_health: float = 100.0
@export var treshold_between_repairs: float = 0.5

@export_node_path("Area3D") var _area
@export_node_path("Node3D") var _visuals_meshs_parent

@onready var timer = Timer.new()
@onready var reapir_sounds = $repair_sound
@onready var full_repair_sound: AudioStreamPlayer3D = $full_repair_sound

@onready var breaking_sound: AudioStreamPlayer3D = $breaking_sound
@onready var full_broken_sound: AudioStreamPlayer3D = $full_broken_sound

var bodys: Array[EnemyBase]

var step: float = health
var area: Area3D
var meshs
var action_pressed: bool = false

@onready var health: float = max_health:
	set(value):
		health = value

		if is_zero_approx(health):
			collision_layer = 24 #pow(2, 5-1) + pow(2, 4-1)
		else:
			collision_layer = 28 #pow(2, 3-1) + pow(2, 4-1) + pow(2, 5-1)

		if meshs != []:
			for x in meshs:
				x.hide()

			for xy in roundi(health / step):
				meshs[clampi(xy, 0, meshs.size() - 1)].show()


func _ready() -> void:
	if _area:
		area = get_node_or_null(_area) as Area3D

	if area:
		#area.process_mode = Node.PROCESS_MODE_ALWAYS

		area.body_entered.connect(body_entered)
		area.body_exited.connect(body_exited)

	if get_node_or_null(_visuals_meshs_parent):
		meshs = get_node(_visuals_meshs_parent).get_children()
		step = max_health / meshs.size()

	add_child(timer)

	
	EventBus.bonus_activated.connect(func barier_bonus_check(bonus_id : StringName, _stack : int) -> void:
		if bonus_id == &"full_repair":
			health = max_health
	)

	timer.one_shot = true
	timer.wait_time = treshold_between_repairs


func _physics_process(_delta: float) -> void:
	if !is_focused:
		return

	if Input.is_action_pressed(interact_key) && timer.is_stopped() && bodys.size() < 1:
		var local_repair_step = max_health / 4

		if health < max_health && timer.is_stopped():
			health += local_repair_step
			health = clampf(health, 0.0, max_health)

			EventBus.emit_signal("add_score", tr("KEY_BARIER_REPAIR_MESSAGE"), local_repair_step)
			timer.start()

			if is_equal_approx(health, max_health):
				full_repair_sound.play()
			else:
				reapir_sounds.play()
	else:
		action_pressed = false


func body_entered(body):
	if body is EnemyBase:
		bodys.push_back(body)

		body.barrier = self
		body.barrier_damage = max_health / 4


func body_exited(body):
	if body is EnemyBase:
		bodys.erase(body)

		body.barrier = null


func get_hit(dmg: float = 0.0, _point: Vector3 = Vector3.ZERO):
	if health >= 0:
		health -= dmg
		health = clampf(health, 0.0, max_health)
		breaking_sound.play()
	if is_zero_approx(health):
		full_broken_sound.play()


func action():
	action_pressed = true


func get_description() -> String:
	if is_equal_approx(health, max_health) or bodys.size() > 0:
		return ""
	else:
		return get_formatted_description(interactable_text)
