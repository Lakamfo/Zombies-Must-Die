class_name MysteryBox
extends InteractableItems

#region Signals
#endregion

#region Exports
@export var positions: Array[Marker3D]
@export var price_per_roll: int = 500

@export var can_take_weapon: bool = false:
	set(value):
		can_take_weapon = value
		force_update_ui = true

@export var is_animation_active: bool = false
@export var teddy_bear_chance: float = 0.15
#endregion

#region Variables
var rand_weapon_id: int = 1
var teddy_bear_sequence_active: bool = false
var current_pos: int = -1

var _icons_list: Array[CompressedTexture2D] = []
var _current_weapon_name: String = ''

#endregion

#region Onready variables
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var teddy_bear_model: Node3D = $teddy_bear_model
@onready var teddy_bear_laugh: AudioStreamPlayer = $teddy_bear_laugh
@onready var mesh_instance_3d: MeshInstance3D = $mesh_instance_3d
#endregion

#region Lifecycle methods
func _ready() -> void:
	interactable_text = get_formatted_description("KEY_OBJECT_MYSTERY_BOX_USE") % [price_per_roll]
	animation_player.animation_finished.connect(_on_animation_finished)
	
	await owner.ready
	_init_icons()
	mesh_instance_3d.material_override = mesh_instance_3d.material_override.duplicate()
#endregion

#region Public methods
func action() -> void:
	if can_take_weapon:
		_give_weapon(rand_weapon_id)
		animation_player.play("close")
		can_take_weapon = false
		return
		
	if teddy_bear_sequence_active or is_animation_active:
		return
		
	if Global.player.score >= price_per_roll:
		animation_player.play("open")
		is_animation_active = true
		EventBus.emit_signal("add_score", tr("KEY_OBJECT_MYSTERY_BOX_MESSAGE"), -price_per_roll)


func randomize_weapon() -> void:
	rand_weapon_id = Global.weapon_manager.get_random_weapon_id()
	var new_random_id: int = Global.weapon_manager.get_random_weapon_id()

	while rand_weapon_id == new_random_id:
		new_random_id = Global.weapon_manager.get_random_weapon_id()
		if rand_weapon_id != new_random_id:
			rand_weapon_id = new_random_id
			break

	mesh_instance_3d.material_override.set_shader_parameter("icon", _icons_list[rand_weapon_id])
	_current_weapon_name = Global.weapon_manager.get_weapon_name_from_id(rand_weapon_id)


func teddy_bear_sequence() -> void:
	if randf() > teddy_bear_chance or positions.size() <= 1:
		return
		
	teddy_bear_sequence_active = true
	can_take_weapon = false

	mesh_instance_3d.hide()
	teddy_bear_laugh.play()
	teddy_bear_model.show()

	await teddy_bear_laugh.finished

	current_pos = _get_new_position_index(current_pos, positions.size())
	global_transform = positions[current_pos].global_transform

	teddy_bear_model.hide()
	teddy_bear_sequence_active = false


func get_description() -> String:
	if not can_take_weapon and is_animation_active:
		return ""
	if teddy_bear_sequence_active:
		return ""
	if can_take_weapon:
		return get_formatted_description("KEY_OBJECT_MYSTERY_BOX_TAKE") % [_current_weapon_name.to_upper()]

	return get_formatted_description("KEY_OBJECT_MYSTERY_BOX_USE") % [price_per_roll]


func get_hit(_dmg: float = 0.0, _point: Vector3 = Vector3.ZERO) -> void:
	pass
#endregion

#region Private methods
func _init_icons() -> void:
	if WeaponCache.loaded:
		for id in WeaponManager.WEAPON_REGISTRY:
			var path: String = WeaponManager.WEAPON_REGISTRY[id][1]
			_icons_list.push_back(WeaponCache.weapon_icons[path])
	else:
		for id in WeaponManager.WEAPON_REGISTRY:
			var path: String = WeaponManager.WEAPON_REGISTRY[id][1]
			var instance: Weapon = load(path).instantiate() as Weapon
			_icons_list.push_back(instance.weapon_stats.icon.duplicate())
			instance.queue_free() 


func _get_new_position_index(exclude_index: int, size: int) -> int:
	var attempts = 0
	var new_index = randi_range(0, size - 1)
	while new_index == exclude_index and attempts < 8:
		new_index = randi_range(0, size - 1)
		attempts += 1
	return new_index


func _give_weapon(id: int = 0) -> void:
	Global.weapon_manager.add_weapon(id)
#endregion

#region Event handlers
func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "close":
		is_animation_active = false
#endregion
