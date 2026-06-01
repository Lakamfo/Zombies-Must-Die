extends Node

## Singleton for managing graphics settings
## Responsible for all visual parameters and effects

#region Graphics Quality Settings
var ssao_setting: int = 0
var fxaa_enabled: bool = false
var sdfgi_enabled: bool = false
var ssr_enabled: bool = false
var decals_enabled: bool = false
var glow_enabled: bool = false
var ssil_enabled: bool = false
var volumetric_fog_enabled: bool = false
var dynamic_shadows_enabled: bool = false

var vegetation : bool = true
var water_puddles : bool = true

var disable_textures: bool = false
var render_on_sinlge_layer: bool = false
#endregion

#region Shader Quality
var shaders_quality: GraphicsUtils.ShadersQuality = GraphicsUtils.ShadersQuality.HIGH:
	set(value):
		var _tree = SceneTreeUtils.get_all_children(get_tree().root)
		shaders_quality = value

		for node in _tree:
			if node is DirectionalLight3D:
				GraphicsUtils.change_shadows_mode(node, value as GraphicsUtils.ShadowsQuality)
		var v_rid: RID = get_viewport().get_viewport_rid()
		match value:
			GraphicsUtils.ShadersQuality.LOW:
				GraphicsUtils.remove_pbr_textures_array(_tree, false, value)
				RenderingServer.viewport_set_debug_draw(v_rid, RenderingServer.VIEWPORT_DEBUG_DRAW_UNSHADED)
			GraphicsUtils.ShadersQuality.MEDIUM:
				GraphicsUtils.remove_pbr_textures_array(_tree, false, value)
				RenderingServer.viewport_set_debug_draw(v_rid, RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED)
			GraphicsUtils.ShadersQuality.HIGH:
				RenderingServer.viewport_set_debug_draw(v_rid, RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED)

var shadows_quality: GraphicsUtils.ShadowsQuality = GraphicsUtils.ShadowsQuality.PARALLEL_2_SPLITS:
	set(value):
		shadows_quality = value
		GraphicsUtils.update_lighting(SceneTreeUtils.get_all_children(get_tree().root), dynamic_shadows_enabled, shadows_quality)
#endregion

#region Camera Settings
var camera_fov: int = 90
var weapon_camera_fov: int = 90
#endregion

#region Scaling
var scaling_mode: int = 0
#endregion

var window: Window = get_window()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Listen to graphics settings updates
	EventBus.update_settings.connect(
		func():
			GraphicsUtils.update_lighting(SceneTreeUtils.get_all_children(get_tree().root), dynamic_shadows_enabled, shadows_quality)
	)

	# Apply graphics settings to newly added nodes
	get_tree().node_added.connect(
		func(node: Node):
			await node.ready

			if shaders_quality > -1 and shaders_quality < 2:
				if is_instance_valid(node):
					if node is GeometryInstance3D:
						GraphicsUtils.remove_pbr_textures(node)
						return
					elif node is Light3D:
						GraphicsUtils.update_lighting([node], dynamic_shadows_enabled, shadows_quality)
						return
	)
