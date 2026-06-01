class_name NavigationRegion3DDynamic
extends NavigationRegion3D

func _ready() -> void:
	EventBus.update_navigation_mesh.connect(bake_nav_mesh)


func bake_nav_mesh() -> void:
	await get_tree().physics_frame

	var time_start = Time.get_ticks_msec()
	bake_finished.connect(
		func():
			DebugOutput.print_info("NavigationServer3D baking took: %s msec" % [str(Time.get_ticks_msec() - time_start)]),
		ConnectFlags.CONNECT_ONE_SHOT,
	)
	bake_navigation_mesh(true)
