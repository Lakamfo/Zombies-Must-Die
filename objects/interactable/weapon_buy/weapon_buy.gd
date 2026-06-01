@tool
class_name WallBuy
extends InteractableItems

#region Signals
#endregion

#region Exports
@export var random: bool = false
@export var weapon_for_sell: int = 0
@export var cost: int = 500

@export var weapon_id_list: Dictionary:
	set(value):
		if _change_list_from_code:
			weapon_id_list = value
#endregion

#region Variables
var weapon_manager: WeaponManager
var player: Player
var ammo_string: String

var _change_list_from_code: bool = true
#endregion

#region Onready variables
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $audio_stream_player_3d
@onready var mesh_instance_3d: MeshInstance3D = $mesh_instance_3d
#endregion

#region Lifecycle methods
func _ready() -> void:
	if Engine.is_editor_hint():
		var id_map: Dictionary = {}
		for id in WeaponManager.WEAPON_REGISTRY:
			id_map[WeaponManager.WEAPON_REGISTRY[id][0].to_upper()] = id
		
		weapon_id_list = id_map
		_change_list_from_code = false
		return

	await get_owner().ready

	weapon_manager = Global.weapon_manager
	player = Global.player

	if random:
		weapon_for_sell = WeaponManager.WEAPON_REGISTRY.keys().pick_random()

	var new_material := (mesh_instance_3d.material_override as ShaderMaterial).duplicate()
	mesh_instance_3d.material_override = new_material

	if weapon_for_sell > -1 and WeaponManager.WEAPON_REGISTRY.has(weapon_for_sell):
		var weapon_resource_path: String = WeaponManager.WEAPON_REGISTRY[weapon_for_sell][1]
		var weapon_icon: CompressedTexture2D
		
		if WeaponCache.preloaded_scenes:
			weapon_icon = WeaponCache.weapon_icons[weapon_resource_path]
		else:
			var packed_weapon_scene: PackedScene = load(weapon_resource_path)
			var weapon_instance: Weapon = packed_weapon_scene.instantiate()
			weapon_icon = weapon_instance.weapon_stats.icon.duplicate()
			weapon_instance.queue_free() # Исправлена утечка памяти

		mesh_instance_3d.material_override.set_shader_parameter(&'icon', weapon_icon)

	var weapon_name_upper: String = weapon_manager.get_weapon_name_from_id(weapon_for_sell).to_upper()
	
	ammo_string = get_formatted_description("KEY_OBJECT_WEAPON_BUY_AMMO_USE") % [weapon_name_upper, cost]
	interactable_text = get_formatted_description("KEY_OBJECT_WEAPON_BUY_USE") % [weapon_name_upper, cost]


func _physics_process(_delta: float) -> void:
	pass
#endregion

#region Public methods
func action() -> void:
	if player.score >= cost:
		var weapon_name_upper: String = weapon_manager.get_weapon_name_from_id(weapon_for_sell).to_upper()
		var message_string: String
		
		if weapon_manager.weapon_in_inventory(weapon_for_sell):
			message_string = tr("KEY_OBJECT_WEAPON_BUY_AMMO_MESSAGE") % weapon_name_upper
		else:
			message_string = tr("KEY_OBJECT_WEAPON_BUY_MESSAGE") % weapon_name_upper

		EventBus.emit_signal("add_score", message_string, -cost)
		audio_stream_player_3d.play()
		_give_weapon(weapon_for_sell)


func get_description() -> String:
	if weapon_manager.weapon_in_inventory(weapon_for_sell):
		return ammo_string
	return interactable_text
#endregion

#region Private methods
func _give_weapon(id: int = 0) -> void:
	weapon_manager.add_weapon(id)
#endregion

#region Event handlers
#endregion
