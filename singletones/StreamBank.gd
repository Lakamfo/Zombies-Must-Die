extends Node

#region Material sounds

const CARPET   = preload("res://sounds/carpet.tres")
const CONCRETE = preload("res://sounds/concrete.tres")
const DIRT     = preload("res://sounds/dirt.tres")
const GLASS    = preload("res://sounds/glass.tres")
const GRASS    = preload("res://sounds/grass.tres")
const GRAVEL   = preload("res://sounds/gravel.tres")
const LADDER   = preload("res://sounds/ladder.tres")
const MUD      = preload("res://sounds/mud.tres")
const RUBBER   = preload("res://sounds/rubber.tres")
const SAND     = preload("res://sounds/sand.tres")
const SNOW     = preload("res://sounds/snow.tres")
const TILE     = preload("res://sounds/tile.tres")
const WOOD     = preload("res://sounds/wood.tres")

const ICE : = TILE

#const METAL_CHAINLINK = preload("res://sounds/metal_chainlink.tres")
#const METAL_GRATE     = preload("res://sounds/metal_grate.tres")
#const METAL_SOLID     = preload("res://sounds/metal_solid.tres")

const METAL_HIT : = preload("res://sounds/metal_impact.tres")
const WOOD_HIT : = preload("res://sounds/wood_impact.tres")
const CONCRETE_HIT : = preload("res://sounds/bullet_hit_sounds/concrete_hit.wav")
const GRASS_HIT : = preload("res://sounds/bullet_hit_sounds/dirt_hit.wav")
const SAND_HIT : = preload("res://sounds/sand_impact.tres")
const DIRT_HIT : = GRASS_HIT
const MUD_HIT : = DIRT_HIT
const ICE_HIT : = GLASS

#endregion

#region bullet hit sounds (OLD)
@onready var concrete_hit : Array[AudioStream] = [
	preload("res://sounds/bullet_hit_sounds/concrete_hit.wav")
]
@onready var grass_hit : Array[AudioStream] = [
	preload("res://sounds/bullet_hit_sounds/dirt_hit.wav")
]
#endregion 
