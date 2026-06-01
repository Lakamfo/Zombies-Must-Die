class_name WaveLogicEnemy
extends Resource

@export var enabled: bool = true
@export_range(0, 10) var spawn_weight: float = 1.0
@export var scene: PackedScene
@export_subgroup("Spawn Parametres")
@export_range(0, 1) var difficulty_min: float = 0
@export_range(0, 1) var difficulty_max: float = 1
@export var wave_min: int = 0
@export var wave_max: int = 9999
@export var is_small: bool = false
@export_subgroup("Every N Wave")
@export var spawn_every_n_wave_enabled: bool = false
@export var spawn_every_n_wave: int = 10
