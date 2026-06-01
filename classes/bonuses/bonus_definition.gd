class_name BonusDefinition
extends Resource

enum Source { PICKUP, MACHINE }

@export var id: StringName
@export var label: String
@export var source: Source = Source.PICKUP
@export var endless: bool = false
@export var duration: float = 15.0
@export var price: int = 0

@export var show_ui_message : bool = false

@export var color: Color = Color(0.996, 0.925, 0.004, 1.0)
@export var icon: Texture2D
@export var mesh: Mesh

@export var stackable: bool = false
@export var max_stacks: int = 1

func is_timed() -> bool:
	return not endless and duration > 0

func is_instant() -> bool:
	return endless
