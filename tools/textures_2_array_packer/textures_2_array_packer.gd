extends Node

var textures : Array[String]

@onready var open_file_dialog: FileDialog = %open_file_dialog
@onready var save_file_dialog: FileDialog = %save_file_dialog

@onready var open_preset_dialog: FileDialog = %open_preset_dialog
@onready var save_preset_dialog: FileDialog = $panel/save_preset_dialog

@onready var v_box_container: VBoxContainer = %v_box_container

@onready var button_save_preset: Button = %button_save_preset
@onready var button_open_preset: Button = %button_open_preset

@onready var button_open: Button = %button_open
@onready var button_save: Button = %button_save

const TEXTURE_SCENE := preload("uid://d1rwe5lbt0y0x")

func _ready() -> void:
	button_open.pressed.connect(open_file_dialog.show)
	button_save.pressed.connect(save_file_dialog.show)
	
	button_save_preset.pressed.connect(save_preset_dialog.show)
	button_open_preset.pressed.connect(open_preset_dialog.show)
	
	open_file_dialog.file_selected.connect(_open_file_path_texture)
	open_file_dialog.files_selected.connect(func (files : PackedStringArray):
		for path in files:
			_open_file_path_texture(path)
		)
	save_file_dialog.file_selected.connect(_save_file_path_selected)
	
	open_preset_dialog.file_selected.connect(_load_preset)
	save_preset_dialog.file_selected.connect(_save_preset)


func create_texture_array(paths : Array[String], save_2_path : String) -> void:
	var images: Array[Image] = []
	
	for path in paths:
		var img: Image = load(path).get_image()
		if img.is_compressed():
			img.decompress()
		
		img.convert(Image.FORMAT_RGBA8)
		images.append(img)
	
	
	var tex_array := Texture2DArray.new()
	tex_array.create_from_images(images)
	
	
	ResourceSaver.save(tex_array, save_2_path, ResourceSaver.FLAG_COMPRESS)


func _open_file_path_texture(filepath : String) -> void:
	var scene := TEXTURE_SCENE.instantiate()
	
	var img : TextureRect = scene.get_node("%texture_rect")
	var label : Label = scene.get_node("%label")
	var btn : Button = scene.get_node("%button")
	
	var img_texture : CompressedTexture2D = load(filepath)
	img.texture = img_texture
	label.text = "Path: %s \nSize: %s x %s" %[filepath, img_texture.get_width(),img_texture.get_height()]
	
	btn.pressed.connect(_delete_texture.bind(filepath, scene))
	textures.append(filepath)
	
	v_box_container.add_child(scene)


func _save_file_path_selected(filepath : String) -> void:
	create_texture_array(textures, filepath)


func _delete_texture(path : String, scene : Node) -> void:
	textures.erase(path)
	scene.queue_free()


func _save_preset(path : String) -> void:
	if path:
		var res: = T2AP_Preset.new()
		res.textures = textures
		
		ResourceSaver.save(res, path)


func _load_preset(path : String) -> void:
	if path:
		var res := load(path) as T2AP_Preset
		
		for _path in res.textures:
			_open_file_path_texture(_path)
