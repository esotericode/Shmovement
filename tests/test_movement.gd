extends SceneTree
## Engine integration checks: real CharacterBody3D contacts and input sequences.

var player: ShmovementPlayer
var failures: int = 0
var checks: int = 0
var measurements: Dictionary = {}
var arena: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	_solid(Vector3(0, -0.5, 0), Vector3(400, 1, 400))
	_solid(Vector3(50, 2.5, 0), Vector3(8, 0.5, 8))
	_solid(Vector3(120, 3, -10), Vector3(3, 1, 3))
	player = load("res://scenes/player.tscn").instantiate() as ShmovementPlayer
	player.position = Vector3(0, 0.04, 0)
	arena.add_child(player)
	_controls()
	await _ticks(6)
	_check(player.is_on_floor(), "Capsule settles onto floor")
	_check(absf(player.position.y) < 0.03, "Feet align with the floor")

	_controls(Vector2(0, -1))
	await _ticks(120)
	_check(absf(player.forward_speed - 9.6) < 0.2, "Running reaches the configured speed")
	var stopping_start: Vector3 = player.position
	_controls()
	await _ticks(60)
	_check(absf(player.forward_speed) < 0.01, "Releasing input stops the character")
	measurements["stopping_distance_m"] = player.position.distance_to(stopping_start)
	_check(float(measurements["stopping_distance_m"]) < 3.0, "Stopping distance stays bounded")

	await _reset()
	_controls(Vector2(0, -0.5))
	await _ticks(120)
	_check(absf(player.forward_speed - 2.4) < 0.15, "Half stick produces a controlled walk")
	await _reset()
	_controls(Vector2(0, -1))
	await _ticks(90)
	_controls(Vector2(0, 1))
	await _ticks(1)
	_check(player.braking, "Opposite input starts a skid")
	await _ticks(90)
	_check(player.velocity.z > 5.0, "Reversal completes in the requested direction")

	await _reset()
	_controls(Vector2.ZERO, true, true)
	await _ticks(1)
	_check(not player.is_on_floor(), "Jump leaves the floor")
	await _flight()
	var held_peak: float = player.last_jump_height
	measurements["standing_jump_peak_m"] = held_peak
	_check(held_peak > 2.0 and held_peak < 2.7, "Held standing jump has the intended height")
	await _reset()
	_controls(Vector2.ZERO, true, true)
	await _ticks(2)
	_controls()
	await _flight()
	measurements["tap_jump_peak_m"] = player.last_jump_height
	_check(player.last_jump_height < held_peak * 0.55, "Releasing jump early shortens the arc")

	await _reset()
	_controls(Vector2(0, -1))
	await _ticks(120)
	_controls(Vector2(0, -1), true, true)
	await _ticks(1)
	_check(player.forward_speed < 8.0, "Normal takeoff reduces forward momentum")
	await _flight()
	var running_range: float = player.last_jump_distance
	measurements["running_jump_peak_m"] = player.last_jump_height
	measurements["running_jump_range_m"] = running_range
	_check(player.last_jump_height > held_peak + 0.4, "Running increases ordinary jump height")
	_controls(Vector2(0, -1), true, true)
	await _ticks(1)
	_check(player.jump_kind == ShmovementPlayer.JumpKind.DOUBLE, "Timely second jump chains to a double")
	await _flight()
	_controls(Vector2(0, -1), true, true)
	await _ticks(1)
	_check(player.jump_kind == ShmovementPlayer.JumpKind.TRIPLE, "Fast third jump chains to a triple")
	await _flight()
	measurements["triple_jump_peak_m"] = player.last_jump_height

	await _reset()
	_controls(Vector2(0, -1))
	await _ticks(120)
	_controls(Vector2(0, -1), true, true, true)
	await _ticks(1)
	_check(player.jump_kind == ShmovementPlayer.JumpKind.LONG, "Crouch plus running jump launches a long jump")
	await _flight()
	measurements["long_jump_peak_m"] = player.last_jump_height
	measurements["long_jump_range_m"] = player.last_jump_distance
	_check(player.last_jump_distance > running_range + 3.0, "Long jump travels substantially farther")
	_check(player.last_jump_height < held_peak + 0.3, "Long jump stays comparatively low")

	await _reset(Vector3(50, 0.04, 0))
	_controls(Vector2.ZERO, true, true)
	await _ticks(1)
	await _flight()
	_check(player.last_jump_height < 0.6, "Low ceiling cancels upward travel")
	_check(player.is_on_floor(), "Ceiling contact returns safely to the floor")

	var wall: StaticBody3D = _solid(Vector3(0, 3, -4), Vector3(12, 6, 0.5))
	await _reset()
	_controls(Vector2(0, -1))
	await _ticks(15)
	_controls(Vector2(0, -1), true, true)
	await _ticks(1)
	var contact: bool = false
	for index in range(90):
		await _ticks(1)
		if player.is_on_wall() and not player.is_on_floor():
			contact = true
			break
	_check(contact, "Airborne capsule detects a wall")
	_controls(Vector2.ZERO, true, true)
	await _ticks(1)
	_check(player.jump_kind == ShmovementPlayer.JumpKind.WALL and player.velocity.z > 1.0, "Wall jump launches away from the surface")
	wall.queue_free()
	await _ticks(2)

	for assisted in [false, true]:
		await _reset(Vector3(120, 3.54, -10))
		player.assists_enabled = assisted
		_controls(Vector2(1, 0))
		for index in range(90):
			await _ticks(1)
			if not player.is_on_floor():
				break
		await _ticks(2)
		_controls(Vector2(1, 0), true, true)
		await _ticks(1)
		_check((player.velocity.y > 0.0) == assisted, "Ledge grace follows assist setting: %s" % assisted)

	for assisted in [false, true]:
		await _reset()
		player.assists_enabled = assisted
		player.respawn(Vector3(0, 1.0, 0))
		_controls()
		await _ticks(2)
		for index in range(90):
			await _ticks(1)
			if not player.is_on_floor() and player.position.y < 0.18:
				break
		_controls(Vector2.ZERO, true, true)
		await _ticks(7)
		_check((player.velocity.y > 0.0) == assisted, "Prelanding jump buffer follows assist setting: %s" % assisted)

	player.assists_enabled = false
	player.respawn(Vector3(0, -13.0, 0))
	_controls()
	await _ticks(2)
	_check(player.position.y > -1.0, "Out-of-bounds fall respawns safely")
	_check(player.position.is_finite() and player.velocity.is_finite(), "State remains finite")

	print("MEASUREMENTS ", JSON.stringify(measurements))
	print("RESULT: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)


func _ticks(count: int) -> void:
	for index in range(count):
		await player.simulation_stepped


func _reset(at: Vector3 = Vector3(0, 0.04, 0)) -> void:
	player.assists_enabled = false
	player.restore_defaults()
	player.respawn(at)
	_controls()
	await _ticks(6)


func _controls(stick: Vector2 = Vector2.ZERO, pressed: bool = false, held: bool = false, crouch: bool = false) -> void:
	player.input_override = {"move": stick, "pressed": pressed, "held": held, "crouch": crouch}


func _flight() -> void:
	for index in range(240):
		await _ticks(1)
		if player.is_on_floor():
			return
	_check(false, "Flight terminates within four seconds")


func _solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	arena.add_child(body)
	body.position = at
	return body


func _check(passed: bool, description: String) -> void:
	checks += 1
	if passed:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
