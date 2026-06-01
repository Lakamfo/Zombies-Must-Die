#"res://classes/map_gen/RoomGenerationConfig.gd"
extends Resource

class_name RoomGenerationConfig

@export_category("Generation Settings")
@export var rng_seed: int = -1

@export var count: int = 30
@export var buffer: int = 5
@export var generate_at_once: bool = false

@export_category("Room Types")
@export var include_rooms: bool = true
@export var include_hallways: bool = true
@export var include_shop: bool = true
@export var include_end: bool = true
