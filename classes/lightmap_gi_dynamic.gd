extends LightmapGI

class_name LightmapGIDynamic

var p_light_data: LightmapGIData
var disabled: bool = false:
	set(value):
		if value:
			light_data = null

		disabled = value


func _ready() -> void:
	p_light_data = light_data

	EventBus.update_settings.connect(func upd(): call_deferred(&"update"))


func update():
	if disabled:
		return

	if GraphicsSettings.sdfgi_enabled:
		light_data = null
	else:
		light_data = p_light_data
