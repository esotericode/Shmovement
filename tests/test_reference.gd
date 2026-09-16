extends SceneTree
## Source-derived rule tests. This is not proof of reference-executable parity.
const A := MovementCore.Action
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ntsc_rules.json"))
	var core := MovementCore.new()
	var height: float = 0.0
	for i in fixture.standing_jump.motion_y.size():
		var motion: Vector3 = core.begin_tick({"pressed": i == 0, "held": true})
		height += motion.y
		_check(is_equal_approx(motion.y, float(fixture.standing_jump.motion_y[i])) and is_equal_approx(height, float(fixture.standing_jump.position_y[i])), "Held jump source trace, tick %d" % (i + 1))
		core.end_tick(false)
	core = MovementCore.new()
	core.begin_tick({"pressed": true, "held": false})
	core.end_tick(false)
	_check(is_equal_approx(core.vertical_velocity, 10.5), "Release divides ascent by four without also subtracting gravity")
	core = _running(32.0)
	for i in fixture.turn_from_32.speeds.size():
		core.begin_tick({"yaw": -32768, "magnitude": 32.0})
		core.end_tick(true)
		_check(absf(core.forward_velocity - float(fixture.turn_from_32.speeds[i])) < 0.00001 and core.action_name() == fixture.turn_from_32.actions[i], "Turnaround source trace, tick %d" % (i + 1))
	_check(core.facing == -32768, "Finish-turn entry sets intended facing")
	_check(core.side_flip_available(), "Finish-turn remains side-flip eligible")
	core.begin_tick({"yaw": -32768, "magnitude": 32.0, "pressed": true})
	_check(core.action == A.SIDE_FLIP and core.launch_vertical == 62.0 and core.launch_forward == 8.0, "Side flip launches at 62 up and 8 forward")
	core.end_tick(false)
	_check(core.vertical_velocity == 58.0, "Side flip has no jump-release height cut")
	core = _running(32.0)
	core.begin_tick({"yaw": -32768, "magnitude": 32.0, "pressed": true, "held": true})
	_check(core.action == A.JUMP, "Simultaneous reverse+A prioritizes a normal jump")
	core = _running(15.99)
	core.begin_tick({"yaw": -32768, "magnitude": 32.0})
	_check(core.action == A.WALKING, "Reversal below 16 does not enter turnaround")
	for yaw in [0x471C, 0x471D, -0x471C, -0x471D]:
		core = _running(16.0)
		core.begin_tick({"yaw": yaw, "magnitude": 32.0})
		_check((core.action == A.TURNING_AROUND) == (absi(yaw) > 0x471C), "Turn angle boundary %d" % yaw)
	core = _running(32.0)
	for i in 8:
		core.begin_tick({"yaw": -32768, "magnitude": 32.0})
		core.end_tick(true)
	while core.animation_frame < 17:
		core.begin_tick({"yaw": -32768, "magnitude": 32.0})
		core.end_tick(true)
	_check(core.action == A.FINISH_TURNING_AROUND, "Turn finish remains active through frame 17")
	core.begin_tick({"yaw": -32768, "magnitude": 32.0})
	_check(core.action == A.WALKING, "Turn completes at the source animation end condition")
	for delay in range(1, 10):
		core = _impact()
		for i in range(1, delay + 1):
			core.begin_tick({"pressed": i == delay, "held": true})
			core.end_tick(false)
		_check((core.action == A.WALL_KICK) == (delay <= 5), "Wall kick on post-impact tick %d" % delay)
	core = _impact()
	for i in 30:
		core.begin_tick({})
		core.end_tick(false, Vector3.BACK)
	core.begin_tick({"pressed": true, "held": true})
	_check(core.action != A.WALL_KICK and core.wall_window_remaining() == 0, "Continuous contact cannot renew the wall window")
	core = _impact()
	core.begin_tick({"held": true})
	core.end_tick(false)
	_check(core.action == A.SOFT_BONK and core.wall_kick_ticks == 5 and core.forward_velocity == -8.0, "Missed firsty enters soft bonk with one recovery timer")
	core.begin_tick({"pressed": true, "held": true})
	_check(core.action == A.WALL_KICK and core.launch_forward == 24.0 and core.launch_vertical == 62.0, "Recovery kick restores minimum launch speed")
	core = _impact(42.0)
	var impact_speed: float = core.forward_velocity
	core.begin_tick({"pressed": true, "held": true})
	_check(core.launch_forward == impact_speed and impact_speed > 38.0, "First-frame kick preserves speed above minimum")
	core = _impact(42.0)
	core.begin_tick({})
	_check(core.action == A.HARD_BONK and core.forward_velocity == -16.0, "Fast missed impact enters hard knockback")
	core = _impact(16.35)
	_check(core.action != A.AIR_HIT_WALL, "Speed exactly 16 after drag cannot enter impact")
	core = _impact(24.0, Vector3(1, 0, 1).normalized())
	_check(core.action != A.AIR_HIT_WALL, "135-degree glancing contact cannot enter impact")
	core = _running(32.0)
	core.begin_tick({"move": Vector2(0, -1), "crouch": true, "pressed": true})
	_check(core.action == A.JUMP, "Initial simultaneous crouch+A follows A priority")
	core = _running(32.0)
	core.begin_tick({"move": Vector2(0, -1), "crouch": true})
	core.end_tick(true)
	core.begin_tick({"move": Vector2(0, -1), "crouch": true, "pressed": true, "held": true})
	_check(core.action == A.LONG_JUMP and core.launch_vertical == 30.0 and is_equal_approx(core.launch_forward, 45.12), "Crouch then A uses source long-jump boost")
	core.end_tick(false)
	_check(core.vertical_velocity == 28.0, "Long-jump gravity is two units per tick")
	core = MovementCore.new()
	core.action = A.JUMP
	core.grounded = false
	core.forward_velocity = 80.0
	core.begin_tick({"move": Vector2(0, -1), "held": true})
	_check(is_equal_approx(core.forward_velocity, 80.15), "Air speed retains original uncapped acceleration")
	core = _running(32.0)
	core.begin_tick({"yaw": 0x4000, "magnitude": 32.0})
	_check(core.facing == 0x800, "Ground turning advances 0x800 units")
	print("RESULT: %d/%d reference rule checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func _running(speed: float) -> MovementCore:
	var core := MovementCore.new()
	core.action = A.WALKING
	core.forward_velocity = speed
	core.slide_velocity = Vector3(0, 0, -speed)
	core.motion = core.slide_velocity
	return core

func _impact(speed: float = 24.0, normal: Vector3 = Vector3.BACK) -> MovementCore:
	var core := MovementCore.new()
	core.action = A.JUMP
	core.grounded = false
	core.forward_velocity = speed
	core.vertical_velocity = 12.0
	core.begin_tick({"held": true})
	core.end_tick(false, normal)
	return core

func _check(passed: bool, description: String) -> void:
	checks += 1
	if passed:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
