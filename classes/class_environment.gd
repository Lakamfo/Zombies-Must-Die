extends WorldEnvironment

class_name WorldGameEnvironment
## WorldEnvironment with graphic settings

var volumetric_fog_can_be_enabled: bool
var fog_can_be_enabled: bool


func _ready() -> void:
	#var sdfgi_state = environment.sdfgi_enabled 
	volumetric_fog_can_be_enabled = environment.volumetric_fog_enabled
	fog_can_be_enabled = environment.fog_enabled

	#SDFGI reload
	environment.sdfgi_enabled = false
	await get_tree().process_frame
	environment.sdfgi_enabled = GraphicsSettings.sdfgi_enabled

	update_settings()
	EventBus.update_settings.connect(update_settings)


func update_settings():
	
	environment.sdfgi_enabled = GraphicsSettings.sdfgi_enabled

	if GraphicsSettings.render_on_sinlge_layer:
		environment.ssr_enabled = GraphicsSettings.ssr_enabled
	else:
		environment.ssr_enabled = false # Can't render transparent viewport with enabled SSR, FORCE DISABLE

	environment.ssil_enabled = GraphicsSettings.ssil_enabled
	environment.glow_enabled = GraphicsSettings.glow_enabled
	
	if volumetric_fog_can_be_enabled:
		environment.volumetric_fog_enabled = GraphicsSettings.volumetric_fog_enabled
	if fog_can_be_enabled:
		environment.fog_enabled = !GraphicsSettings.volumetric_fog_enabled

	if GraphicsSettings.ssao_setting > 0:
		RenderingServer.environment_set_ssao_quality(GraphicsSettings.ssao_setting, true, 0.5, 4, 50, 300)
	else:
		environment.ssao_enabled = false
