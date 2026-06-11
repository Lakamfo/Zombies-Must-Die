class_name GPadHintTexture
extends Texture2D

const INVALID_TEXTURE := preload('uid://drdctaxlparxe')

@export var action: StringName = "":
	set(value):
		action = value
		
		if not InputMap.has_action(value):
			_texture = INVALID_TEXTURE
			return
			
		var actions := InputMap.action_get_events(value)
		for act in actions:
			_texture = _load_texture_from_event(act)
			if _texture != INVALID_TEXTURE:
				return

var _texture : Texture2D = INVALID_TEXTURE

func _init() -> void:
	# trigger changed icons
	Input.joy_connection_changed.connect(func(_device, _changed): action = action)

static func _load_texture_from_event(event: InputEvent) -> Texture2D:
	# var id : int = -1
	var ret: Texture2D = INVALID_TEXTURE
	
	ret = InputDisplayHelper.get_event_icon(event)
	if ret == null:
		ret = INVALID_TEXTURE
	
	return ret

func _draw(
	to_canvas_item: RID, 
	pos: Vector2, 
	modulate: Color, 
	transpose: bool
) -> void:
	
	if not _texture:
		return
		
	_texture.draw(to_canvas_item, pos, modulate, transpose)


func _draw_rect(
	to_canvas_item: RID, 
	rect: Rect2, 
	tile: bool, 
	modulate: Color, 
	transpose: bool
):
	if not _texture:
		return
		
	_texture.draw_rect(to_canvas_item, rect, tile, modulate, transpose)


func _draw_rect_region(
	to_canvas_item: RID, 
	rect: Rect2, 
	src_rect: Rect2, 
	modulate: Color, 
	transpose: bool, 
	clip_uv: bool
) -> void:
	if not _texture:
		return
	
	_texture._draw_rect_region(to_canvas_item, rect, src_rect, modulate, transpose, clip_uv)


func _get_height() -> int: return _texture.get_height()
func _get_width() -> int : return _texture.get_width()
func _has_alpha() -> bool: return _texture.has_alpha()
func _is_pixel_opaque(_x: int, _y: int): return false
