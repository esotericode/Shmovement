extends SceneTree
## Optional rendered review images. Run with a display, not --headless.
var _sheet: Image = Image.create(768, 720, false, Image.FORMAT_RGB8)
var _capture_index: int = 0
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
	camera.position = player.position + Vector3(1.8, 1.65, -3)
	camera.look_at(player.position + Vector3(0, 0.9, 0))
	camera.current = true
	player.set_physics_process(false)
	world.get_node("HUD").hide()
	var overlay := CanvasLayer.new()
	world.add_child(overlay)
	var caption := Label.new()
	caption.position = Vector2(28, 24)
	caption.add_theme_font_size_override("font_size", 28)
	overlay.add_child(caption)
	for state in [MovementCore.Action.IDLE, MovementCore.Action.TURNING_AROUND, MovementCore.Action.LONG_JUMP, MovementCore.Action.SIDE_FLIP, MovementCore.Action.WALL_KICK]:
		player.core.action = state
		caption.text = player.core.action_name().replace("_", " ")
		player.core.action_ticks = 8
		for i in 3:
			await process_frame
		await _capture(player.core.action_name().to_lower())
	_sheet.save_png("res://test-results/screenshots/contact_sheet.png")
	if OS.get_cmdline_user_args().has("--emit-review-images"):
		print("RENDER_REVIEW|", Marshalls.raw_to_base64(_sheet.save_png_to_buffer()))
	quit()

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var error: Error = frame.save_png("res://test-results/screenshots/%s.png" % name)
	frame.resize(384, 240, Image.INTERPOLATE_LANCZOS)
	frame.convert(Image.FORMAT_RGB8)
	_sheet.blit_rect(frame, Rect2i(0, 0, 384, 240), Vector2i((_capture_index % 2) * 384, int(_capture_index / 2) * 240))
	_capture_index += 1
	if error != OK:
		push_error("Screenshot failed: " + name)
		quit(1)
