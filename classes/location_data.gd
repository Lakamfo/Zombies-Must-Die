extends Resource

class_name LocationData

@export var name: String = "Location"
@export var icon: CompressedTexture2D = preload("uid://wr8b3s5af8xp")
@export_file("*.tscn", "*.scn") var scene_path: String
@export var debug_only: bool = false

@export var location_modifiers: Dictionary[ModifiersManager.Modifiers, bool] = {
	ModifiersManager.Modifiers.FastZombiesModifier: false,
	ModifiersManager.Modifiers.SmallZombiesOnlyModifier: false,
	ModifiersManager.Modifiers.LondonModifier: false
}
