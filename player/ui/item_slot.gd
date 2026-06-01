extends Control


@export_multiline() var ammo_template = \
"""[font_size=32][color=#ffffff]%s[/color][/font_size][color=red]│[/color][font_size=18][color=#8a8a8a]%s[/color][/font_size]
"""

var icon: CompressedTexture2D = preload("res://default_resources/icon.svg"):
	set(value):
		icon = value
		set_icon(value)
var slot_number: int = 1
var active: bool = false

@onready var animation_player: AnimationPlayer = $animation_player
@onready var texture_rect: TextureRect = %texture_rect
@onready var number: Label = %weapon_index_label
@onready var ammos: RichTextLabel = %ammunition_label
@onready var fire_mode: Label = %fire_mode
@onready var weapon_name: Label = %weapon_name


func _ready() -> void:
	set_icon(icon)
	set_number(slot_number)
	set_active(active)


func set_active(_active: bool):
	if _active:
		active = true
		animation_player.play("fade_in")
	else:
		active = false
		animation_player.play("fade_out")


func set_number(p_number: int = 1):
	if number: number.text = str(p_number)


func set_icon(p_icon : CompressedTexture2D) -> void:
	if texture_rect: texture_rect.texture = p_icon


func set_weapon_name(p_name : String) -> void:
	if weapon_name: weapon_name.text = p_name
