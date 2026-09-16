class_name MovementCore
extends RefCounted
## Original action implementation. Native units/tick, 30 Hz; 100 units = 1 metre.
## Godot collision is an adapter, not the reference surface solver.

enum Action {
	IDLE, WALKING, DECELERATING, BRAKING, TURNING_AROUND, FINISH_TURNING_AROUND,
	CROUCH_SLIDE, CROUCHING, JUMP, DOUBLE_JUMP, TRIPLE_JUMP, LONG_JUMP, SIDE_FLIP,
	WALL_KICK, BACKFLIP, FREEFALL, AIR_HIT_WALL, SOFT_BONK, HARD_BONK, LANDING, LAND_STOP
}

const HZ: int = 30
const METRES_PER_UNIT: float = 0.01
const SPEED_SCALE: float = 0.3
const TURN_END_FRAME: int = 17 # anim_BD.loopEnd (18) - 1; no source keyframes used.

var settings: MovementProfile = MovementProfile.new()
var action: Action = Action.IDLE
var previous_action: Action = Action.IDLE
var action_ticks: int = 0
var tick: int = 0
var facing: int = 0
var intended_yaw: int = 0
var intended_magnitude: float = 0.0
var forward_velocity: float = 0.0
var vertical_velocity: float = 0.0
var motion: Vector3 = Vector3.ZERO
var grounded: bool = true
var floor_normal: Vector3 = Vector3.UP
var wall_kick_ticks: int = 0
var double_jump_ticks: int = 0
var landing_jump: Action = Action.FREEFALL
var animation: StringName = &"idle"
var animation_frame: int = 0
var launched: bool = false
var launch_vertical: float = 0.0
var launch_forward: float = 0.0
var last_event: String = "READY"
var event_tick: int = 0
var assists: bool = false
var _pressed: bool = false
var _held: bool = false
var _crouch: bool = false
var _crouch_pressed: bool = false
var _was_crouched: bool = false
var _air_step: bool = false
var _landing_timer: int = 0
var _slide_timer: int = 0

func begin_tick(controls: Dictionary) -> Vector3:
	tick += 1
	action_ticks += 1
	launched = false
	wall_kick_ticks = maxi(0, wall_kick_ticks - 1)
	double_jump_ticks = maxi(0, double_jump_ticks - 1)
	_pressed = controls.get("pressed", false)
	_held = controls.get("held", false)
	_crouch = controls.get("crouch", false)
	_crouch_pressed = _crouch and not _was_crouched
	_was_crouched = _crouch
	var stick: Vector2 = controls.get("move", Vector2.ZERO)
	intended_magnitude = pow(minf(stick.length(), 1.0), settings.stick_exponent) * 32.0
	intended_yaw = angle_from_vector(Vector3(stick.x, 0, stick.y)) if intended_magnitude > 0.0 else facing
	if controls.has("yaw"):
		intended_yaw = signed_angle(int(controls["yaw"]))
		intended_magnitude = float(controls.get("magnitude", 32.0))
	if not grounded and not is_airborne():
		_change(Action.FREEFALL)
	# Cancelling an action runs its successor in this same tick.
	for transition in range(12):
		if not _dispatch():
			break
	_air_step = is_airborne()
	motion.y = vertical_velocity if _air_step else 0.0
	return motion

func end_tick(on_floor: bool, wall_normal: Vector3 = Vector3.ZERO, ceiling: bool = false) -> void:
	# Position first, gravity second, action result last.
	if _air_step:
		if ceiling:
			vertical_velocity = minf(vertical_velocity, 0.0)
		_apply_gravity()
		if on_floor:
			landing_jump = action
			_landing_timer = 0
			_change(Action.LANDING)
			_event("LANDED")
		elif not wall_normal.is_zero_approx():
			_resolve_wall(wall_normal)
	elif not on_floor:
		_change(Action.FREEFALL)
	grounded = on_floor
	animation_frame += 1
	if animation == &"turn_finish":
		animation_frame = mini(animation_frame, TURN_END_FRAME)

func _dispatch() -> bool:
	match action:
		Action.IDLE, Action.LAND_STOP:
			if _pressed:
				_launch(_chain_jump() if action == Action.LAND_STOP else Action.JUMP)
				return true
			if intended_magnitude > 0.0:
				facing = intended_yaw
				_walk()
				return true
			if _crouch:
				_change(Action.CROUCHING)
				return true
			forward_velocity = 0.0
			_ground_motion()
			_set_animation(&"idle")
		Action.WALKING, Action.DECELERATING, Action.BRAKING:
			# A precedes reversal and Z: same-tick reverse+A is an ordinary jump.
			if _pressed:
				_launch(_chain_jump())
				return true
			if intended_magnitude == 0.0:
				if action == Action.WALKING:
					_change(Action.BRAKING if forward_velocity >= 16.0 else Action.DECELERATING)
				var decel: float = 4.0 if action == Action.BRAKING else 1.0
				forward_velocity = move_toward(forward_velocity, 0.0, decel)
				if is_zero_approx(forward_velocity):
					_change(Action.IDLE)
					return true
				_slope_acceleration()
				_ground_motion()
				_set_animation(&"skid" if action == Action.BRAKING else &"run")
			elif action != Action.WALKING:
				_walk()
				return true
			elif _held_back() and forward_velocity >= 16.0:
				_change(Action.TURNING_AROUND)
				_event("TURNAROUND · SIDE FLIP READY")
				return true
			elif _crouch_pressed:
				_slide_timer = 0
				_change(Action.CROUCH_SLIDE)
				return true
			else:
				_update_walking()
				_set_animation(&"run")
		Action.TURNING_AROUND:
			if _pressed:
				_launch(Action.SIDE_FLIP)
				return true
			if intended_magnitude == 0.0:
				_change(Action.BRAKING)
				return true
			if not _held_back():
				_walk()
				return true
			forward_velocity = move_toward(forward_velocity, 0.0, settings.reverse_braking / 9.0)
			var stopped: bool = is_zero_approx(forward_velocity)
			_slope_acceleration()
			if stopped:
				facing = intended_yaw
				forward_velocity = 8.0
				_change(Action.FINISH_TURNING_AROUND)
				return true
			_ground_motion()
			_set_animation(&"turn_start" if forward_velocity >= 18.0 else &"turn_finish")
			if animation == &"turn_finish" and animation_frame == TURN_END_FRAME:
				facing = intended_yaw
				forward_velocity = -forward_velocity if forward_velocity > 0.0 else 8.0
				_walk()
		Action.FINISH_TURNING_AROUND:
			if _pressed:
				_launch(Action.SIDE_FLIP)
				return true
			_update_walking()
			_set_animation(&"turn_finish")
			if animation_frame == TURN_END_FRAME:
				_walk()
		Action.CROUCH_SLIDE:
			if _slide_timer < 30:
				_slide_timer += 1
				if _pressed and forward_velocity > 10.0:
					_launch(Action.LONG_JUMP)
					return true
			if _pressed:
				_launch(Action.JUMP)
				return true
			# Flat-ground friction only. Full vector/slope sliding remains pending.
			if _slide_timer != 5:
				_slide_timer += 1
			var along: float = _cos(intended_yaw - facing)
			if along < 0.0 and forward_velocity >= 0.0:
				along *= 0.5 + 0.5 * forward_velocity / 100.0
			forward_velocity *= 0.92 + intended_magnitude / 32.0 * along * 0.02
			_ground_motion()
			_set_animation(&"crouch")
			if absf(forward_velocity) < 4.0:
				forward_velocity = 0.0
				_change(Action.CROUCHING)
		Action.CROUCHING:
			if _pressed:
				_launch(Action.BACKFLIP)
				return true
			if not _crouch:
				_change(Action.IDLE)
				return true
			forward_velocity = 0.0
			_ground_motion()
			_set_animation(&"crouch")
		Action.AIR_HIT_WALL:
			if _pressed:
				facing = signed_angle(facing + 0x8000)
				_launch(Action.WALL_KICK)
				_event("WALL KICK · FIRST FRAME")
				return true
			# NTSC's missing return re-enters this action in one frame.
			# Encode the observed behavior explicitly, without undefined C behavior.
			wall_kick_ticks = 5 + (3 if assists else 0)
			vertical_velocity = minf(vertical_velocity, 0.0)
			if forward_velocity >= 38.0:
				_change(Action.HARD_BONK)
			else:
				if forward_velocity > 8.0:
					forward_velocity = -8.0
				_change(Action.SOFT_BONK)
			_event("BONK · RECOVERY WINDOW")
			return true
		Action.SOFT_BONK, Action.HARD_BONK:
			if _pressed and wall_kick_ticks > 0 and previous_action == Action.AIR_HIT_WALL:
				facing = signed_angle(facing + 0x8000)
				_launch(Action.WALL_KICK)
				_event("WALL KICK · RECOVERY")
				return true
			if _pressed:
				_event("WALL KICK MISSED · WINDOW CLOSED")
			if action == Action.HARD_BONK:
				forward_velocity = -16.0
			_set_horizontal(_forward() * forward_velocity)
			_set_animation(&"bonk")
		Action.LANDING:
			var frames: int = 6 if landing_jump == Action.LONG_JUMP else 4
			double_jump_ticks = 0 if landing_jump in [Action.TRIPLE_JUMP, Action.BACKFLIP] else 5
			_landing_timer += 1
			if _landing_timer >= frames:
				_change(Action.LAND_STOP)
				return true
			if _pressed:
				_launch(_chain_jump())
				return true
			if intended_magnitude > 0.0:
				_slope_acceleration()
				_ground_motion()
				# Landing friction changes forward speed after this tick's motion is set.
				if floor_normal.y > 0.9659258:
					forward_velocity *= 0.98
			elif forward_velocity >= 16.0:
				forward_velocity = move_toward(forward_velocity, 0.0, 4.0)
				_slope_acceleration()
				_ground_motion()
			else:
				vertical_velocity = 0.0
			_set_animation(&"land")
		_:
			_update_air()
			_set_animation(action_name().to_lower())
	return false

func _walk() -> void:
	_change(Action.WALKING)
	if forward_velocity >= 0.0:
		forward_velocity = maxf(forward_velocity, minf(intended_magnitude, settings.start_speed / SPEED_SCALE))

func _update_walking() -> void:
	var target: float = minf(intended_magnitude, settings.run_speed / SPEED_SCALE)
	var acceleration: float = settings.acceleration / 9.0
	if forward_velocity <= 0.0:
		forward_velocity += acceleration
	elif forward_velocity <= target:
		forward_velocity += acceleration - forward_velocity / 43.0
	elif floor_normal.y >= 0.95:
		forward_velocity -= 1.0
	forward_velocity = minf(forward_velocity, 48.0)
	var difference: int = signed_angle(intended_yaw - facing)
	var max_turn: int = roundi(settings.turn_speed * 65536.0 / (TAU * HZ))
	facing = signed_angle(intended_yaw - int(move_toward(difference, 0, max_turn)))
	_slope_acceleration()
	_ground_motion()

func _update_air() -> void:
	forward_velocity = move_toward(forward_velocity, 0.0, 0.35)
	var difference: int = signed_angle(intended_yaw - facing)
	var strength: float = intended_magnitude / 32.0
	forward_velocity += strength * _cos(difference) * 1.5
	var sideways: float = strength * _sin(difference) * (settings.air_side_speed / SPEED_SCALE)
	var threshold: float = 48.0 if action == Action.LONG_JUMP else 32.0
	if forward_velocity > threshold:
		forward_velocity -= 1.0
	if forward_velocity < -16.0:
		forward_velocity += 2.0
	# No hard cap: positive acceleration above the drag threshold is original behavior.
	_set_horizontal(_forward() * forward_velocity + _direction(facing + 0x4000) * sideways)

func _launch(kind: Action) -> void:
	_change(kind)
	match kind:
		Action.JUMP, Action.DOUBLE_JUMP:
			var base: float = settings.jump_speed if kind == Action.JUMP else settings.double_jump_speed
			vertical_velocity = base / SPEED_SCALE + forward_velocity * 0.25
			forward_velocity *= 0.8
		Action.TRIPLE_JUMP:
			vertical_velocity = 69.0
			forward_velocity *= 0.8
		Action.LONG_JUMP:
			vertical_velocity = 30.0
			forward_velocity = minf(forward_velocity * 1.5, 48.0)
		Action.SIDE_FLIP:
			vertical_velocity = 62.0
			forward_velocity = 8.0
			facing = intended_yaw
		Action.WALL_KICK:
			vertical_velocity = 62.0
			forward_velocity = maxf(forward_velocity, 24.0)
		Action.BACKFLIP:
			vertical_velocity = 62.0
			forward_velocity = -16.0
	wall_kick_ticks = 0
	double_jump_ticks = 0
	grounded = false
	launched = true
	launch_vertical = vertical_velocity
	launch_forward = forward_velocity
	_event(action_name().replace("_", " "))

func _chain_jump() -> Action:
	if action == Action.LANDING or double_jump_ticks > 0:
		if landing_jump in [Action.JUMP, Action.WALL_KICK, Action.FREEFALL, Action.SIDE_FLIP, Action.SOFT_BONK]:
			return Action.DOUBLE_JUMP
		if landing_jump == Action.DOUBLE_JUMP and forward_velocity > 20.0:
			return Action.TRIPLE_JUMP
		if landing_jump == Action.LONG_JUMP and _crouch:
			return Action.LONG_JUMP
	return Action.JUMP

func _apply_gravity() -> void:
	if action in [Action.JUMP, Action.DOUBLE_JUMP, Action.WALL_KICK] and not _held and vertical_velocity > 20.0:
		vertical_velocity *= 0.25
	else:
		var gravity: float = settings.gravity / 9.0
		if action == Action.LONG_JUMP:
			gravity *= 0.5
		vertical_velocity = maxf(vertical_velocity - gravity, -75.0)

func _resolve_wall(normal: Vector3) -> void:
	var wall_yaw: int = angle_from_vector(normal)
	if absi(signed_angle(wall_yaw - facing)) <= 0x6000:
		return
	if action in [Action.SOFT_BONK, Action.HARD_BONK]:
		facing = signed_angle(2 * wall_yaw - facing + 0x8000)
		forward_velocity = -forward_velocity
		vertical_velocity = minf(vertical_velocity, 0.0)
	elif forward_velocity > 16.0:
		facing = signed_angle(2 * wall_yaw - facing)
		_change(Action.AIR_HIT_WALL)
		_set_animation(&"wall_contact")
		_event("WALL IMPACT · PRESS JUMP")
	else:
		forward_velocity = 0.0

func _slope_acceleration() -> void:
	if floor_normal.y <= 0.9659258:
		var downhill := Vector3(floor_normal.x, 0, floor_normal.z)
		var sign_value: float = 1.0 if downhill.dot(_forward()) > 0.0 else -1.0
		forward_velocity += sign_value * 1.7 * downhill.length()

func _ground_motion() -> void:
	vertical_velocity = 0.0
	_set_horizontal(_forward() * forward_velocity)

func _set_horizontal(value: Vector3) -> void:
	motion.x = value.x
	motion.z = value.z

func _held_back() -> bool:
	return absi(signed_angle(intended_yaw - facing)) > 0x471C

func is_airborne() -> bool:
	return action in [Action.JUMP, Action.DOUBLE_JUMP, Action.TRIPLE_JUMP, Action.LONG_JUMP,
		Action.SIDE_FLIP, Action.WALL_KICK, Action.BACKFLIP, Action.FREEFALL,
		Action.AIR_HIT_WALL, Action.SOFT_BONK, Action.HARD_BONK]

func side_flip_available() -> bool:
	return grounded and action in [Action.TURNING_AROUND, Action.FINISH_TURNING_AROUND]

func wall_window_remaining() -> int:
	if action == Action.AIR_HIT_WALL:
		return 5 + (3 if assists else 0)
	if action in [Action.SOFT_BONK, Action.HARD_BONK] and previous_action == Action.AIR_HIT_WALL:
		return maxi(0, wall_kick_ticks - 1)
	return 0

func action_name() -> String:
	return Action.keys()[action]

func _change(next: Action) -> void:
	previous_action = action
	action = next
	action_ticks = 0

func _event(message: String) -> void:
	last_event = message
	event_tick = tick

func _set_animation(name: StringName) -> void:
	if animation != name:
		animation = name
		animation_frame = 0 if name == &"turn_finish" else -1

func _forward() -> Vector3:
	return _direction(facing)

static func _direction(angle: int) -> Vector3:
	return Vector3(-_sin(angle), 0, -_cos(angle))

static func signed_angle(value: int) -> int:
	return ((value + 0x8000) & 0xFFFF) - 0x8000

static func angle_from_vector(vector: Vector3) -> int:
	return signed_angle(roundi(atan2(-vector.x, -vector.z) * 65536.0 / TAU))

static func _sin(angle: int) -> float:
	return sin(float((angle & 0xFFFF) >> 4) * TAU / 4096.0)

static func _cos(angle: int) -> float:
	return _sin(angle + 0x4000)
