@tool
extends Button


@export var is_primary: bool = false:
	set(v):
		is_primary = v
		if is_node_ready(): _apply_primary_style()
@export var title: String = "ИГРАТЬ":
	set(v): title = v; _update()
@export var subtitle: String = "Быстрый старт":
	set(v): subtitle = v; _update()
@export var icon_texture: Texture2D:
	set(v): icon_texture = v; _update()

@onready var label_title    := %title
@onready var label_subtitle := %subtitle
@onready var icon_rect      := %texture_rect
@onready var panel          := %panel

var tween: Tween
var style: StyleBoxFlat

func _ready() -> void:
	style = panel.get_theme_stylebox("panel").duplicate()
	panel.add_theme_stylebox_override("panel", style)
	
	_update()
	
	toggled.connect(_on_toggled)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	focus_entered.connect(_on_hover)
	focus_exited.connect(_on_unhover)
	
	add_theme_stylebox_override("normal",   StyleBoxEmpty.new())
	add_theme_stylebox_override("hover",    StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed",  StyleBoxEmpty.new())
	add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	
	
	label_title.add_theme_font_size_override("font_size", 22)
	label_title.add_theme_color_override("font_color", Color.WHITE)

	label_subtitle.add_theme_font_size_override("font_size", 13)
	label_subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _update() -> void:
	if not is_node_ready(): return
	if label_title:    label_title.text    = title
	if label_subtitle: label_subtitle.text = subtitle
	if icon_rect:      icon_rect.texture   = icon_texture
	if is_primary: _apply_primary_style()


func _on_hover() -> void:
	if tween: tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "self_modulate", Color(1.15, 0.15, 0.15, 1.0), 0.18)
	tween.parallel()
	tween.tween_property(style, "border_color", Color(0.8, 0.133, 0.133, 1.0), 0.18)


func _on_unhover() -> void:
	if button_pressed:
		return
	
	if tween: tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "self_modulate", Color(1, 1, 1, 1), 0.25)
	tween.parallel()
	tween.tween_property(style, "border_color", Color(0.8, 0.133, 0.133, 0.0), 0.25)


func _on_toggled(value : bool) -> void:
	if value:
		_on_hover()
	else:
		_on_unhover()


func _apply_primary_style() -> void:
	style = panel.get_theme_stylebox("panel").duplicate()
	style.bg_color     = Color("#4d0000")
	style.shadow_size  = 16
	panel.add_theme_stylebox_override("panel", style)
