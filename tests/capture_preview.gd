extends SceneTree
## Optional rendered review images. Run with a display, not --headless.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute("res://test-results/screenshots")
	var world: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(world)
	var player: ShmovementPlayer = world.get_node("Player")
	for i in 20:
		await player.simulation_stepped
	await _capture("playground")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = player.position + Vector3(2.7, 2.1, -4)
	camera.look_at(player.position + Vector3(0, 0.9, 0))
	camera.current = true
	player.set_physics_process(false)
	world.get_node("HUD").hide()
	for state in [MovementCore.Action.IDLE, MovementCore.Action.TURNING_AROUND, MovementCore.Action.LONG_JUMP, MovementCore.Action.SIDE_FLIP, MovementCore.Action.WALL_KICK]:
		player.core.action = state
		player.core.action_ticks = 8
		for i in 3:
			await process_frame
		await _capture(player.core.action_name().to_lower())
	quit()

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://test-results/screenshots/%s.png" % name)
	if error != OK:
		push_error("Screenshot failed: " + name)
		quit(1)
