extends SceneTree

var player: ShmovementPlayer
var failures: int = 0
var count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var world: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	var rig: Node3D = world.get_node("CameraRig")
	var arm: SpringArm3D = rig.get_node("SpringArm3D")
	var hud: CanvasLayer = world.get_node("HUD")
	await _ticks(10)
	_check(player.is_on_floor(), "Room spawn is grounded")
	_check(player.is_reference_profile(), "HUD initialization preserves exact reference defaults")
	var visual: Node3D = player.get_node("Visual")
	var skeleton: Skeleton3D = visual.get("_skeleton")
	_check(skeleton.get_bone_count() > 20, "Detailed character loads a real humanoid rig")
	_check(arm.get_hit_length() > 4.0, "Camera excludes the player's capsule")
	var spawn: Vector3 = player.position
	Input.action_press("move_forward")
	await _ticks(30)
	Input.action_release("move_forward")
	_check(player.position.z < spawn.z - 3.0, "Mapped forward input moves into the room")
	player.respawn()
	rig.rotation.y = PI / 2.0
	await _ticks(6)
	Input.action_press("move_forward")
	await _ticks(23)
	Input.action_release("move_forward")
	_check(player.position.x < spawn.x - 2.0, "Movement follows camera orientation")

	hud.toggle_tuning()
	_check(hud.tuning_open and not player.input_enabled and not rig.look_enabled, "Tuning frees the cursor and suspends character input")
	var tuning: Control = hud.get("_tuning")
	var bounds: Rect2 = tuning.get_global_rect()
	_check(bounds.position.x >= 0.0 and bounds.position.y >= 0.0 and bounds.end.x <= 1280 and bounds.end.y <= 800, "Tuning panel is fully visible")
	var sliders: Dictionary = hud.get("_sliders")
	(sliders["run_speed"] as Range).value = 11.2
	_check(is_equal_approx(player.settings.run_speed, 11.2) and is_equal_approx(player.profile.run_speed, 9.6), "Live tuning changes movement without altering the baseline asset")
	hud.call("_reset_tuning")
	_check(is_equal_approx(player.settings.run_speed, 9.6), "Restore baseline resets live tuning")
	hud.toggle_tuning()
	_check(not hud.tuning_open and player.input_enabled and rig.look_enabled, "Closing tuning restores control")

	player.respawn(Vector3(-13, 0.04, -7.8))
	player.input_override = {"move": Vector2.ZERO, "pressed": false, "held": false, "crouch": false}
	await _ticks(6)
	player.input_override["move"] = Vector2(0, -1)
	await _ticks(30)
	_check(player.is_on_floor() and player.position.y > 1.0, "Character climbs the actual room ramp")
	var slope: float = rad_to_deg(acos(clampf(player.get_floor_normal().y, -1.0, 1.0)))
	_check(slope > 20.0 and slope < 24.0, "Ramp is detected as a 22 degree floor")

	player.respawn(Vector3(20.8, 0.04, 0))
	player.input_override["move"] = Vector2.ZERO
	rig.snap_to_target()
	rig.rotation.y = PI / 2.0
	await _ticks(20)
	_check(arm.get_hit_length() < 2.0, "Camera retracts against the room wall")
	_check(arm.get_node("Camera3D").global_position.x < 21.8, "Camera stays inside the wall")

	player.respawn(Vector3(13, 1.04, 12))
	await _ticks(6)
	player.input_override["move"] = Vector2(0, -1)
	await _ticks(25)
	player.input_override["crouch"] = true
	await _ticks(1)
	player.input_override["pressed"] = true
	player.input_override["held"] = true
	player.input_override["crouch"] = true
	await _ticks(1)
	_check(player.jump_kind == ShmovementPlayer.JumpKind.LONG, "Runway allows a long jump")
	print("Gap takeoff: ", player.position, " speed: ", player.forward_speed)
	for index in range(180):
		await _ticks(1)
		if player.is_on_floor():
			break
	print("Gap landing: ", player.position)
	_check(player.is_on_floor() and player.position.y > 0.95 and player.position.z < -2.5, "Long jump clears the seven metre gap onto the landing island")
	print("RESULT: %d/%d playground checks passed" % [count - failures, count])
	quit(1 if failures > 0 else 0)


func _ticks(amount: int) -> void:
	for index in range(amount):
		await player.simulation_stepped


func _check(passed: bool, description: String) -> void:
	count += 1
	if passed:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
