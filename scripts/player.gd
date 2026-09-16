class_name ShmovementPlayer
extends CharacterBody3D
## Original controller informed by documented movement relationships.
## This is a 60 Hz approximation with Godot collision response, not an SM64 port.

signal simulation_stepped
signal landed(height: float, distance: float, duration: float)

enum JumpKind { NONE, SINGLE, DOUBLE, TRIPLE, LONG, WALL }

@export var profile: MovementProfile
@export var camera_path: NodePath
@export var assists_enabled: bool = false

var settings: MovementProfile
var facing_yaw: float = 0.0
var forward_speed: float = 0.0
var jump_kind: JumpKind = JumpKind.NONE
var braking: bool = false
var input_enabled: bool = true
## Optional world-relative input for deterministic tests and future replay tools.
var input_override: Dictionary = {}
var last_jump_height: float = 0.0
var last_jump_distance: float = 0.0
var last_air_time: float = 0.0
var current_jump_height: float = 0.0

var _camera: Node3D
var _spawn: Vector3
var _buffer: float = 0.0
var _coyote: float = 0.0
var _chain: float = 0.0
var _previous_jump: JumpKind = JumpKind.NONE
var _wall_time: float = 0.0
var _wall_lock: float = 0.0
var _wall_normal: Vector3 = Vector3.ZERO
var _release_used: bool = false
var _recording: bool = false
var _jump_origin: Vector3
var _air_time: float = 0.0


func _ready() -> void:
	settings = profile.duplicate(true) if profile != null else MovementProfile.new()
	_camera = get_node_or_null(camera_path) as Node3D
	_spawn = global_position
	floor_snap_length = 0.22
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	floor_stop_on_slope = true
	wall_min_slide_angle = 0.0


func _physics_process(delta: float) -> void:
	var controls: Dictionary = _read_controls()
	var stick: Vector2 = controls["move"]
	var strength: float = pow(minf(stick.length(), 1.0), settings.stick_exponent)
	var wish: Vector3 = Vector3(stick.x, 0.0, stick.y).normalized() * strength
	if input_override.is_empty() and _camera != null:
		wish = wish.rotated(Vector3.UP, _camera.rotation.y)
	var grounded: bool = is_on_floor()
	_chain = maxf(0.0, _chain - delta)
	_wall_time = maxf(0.0, _wall_time - delta)
	_wall_lock = maxf(0.0, _wall_lock - delta)
	if grounded:
		_coyote = settings.coyote_time if assists_enabled else 0.0
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if controls["pressed"]:
		_buffer = settings.jump_buffer if assists_enabled else delta

	if grounded:
		_ground_motion(wish, delta)
		velocity.y = 0.0
	else:
		_air_motion(wish, delta)

	if _buffer > 0.0:
		if grounded or _coyote > 0.0:
			_launch_ground_jump(bool(controls["crouch"]), grounded)
		elif _wall_time > 0.0 and _wall_lock <= 0.0:
			_launch_wall_jump()
	_buffer = maxf(0.0, _buffer - delta)

	move_and_slide()
	if is_on_ceiling():
		velocity.y = minf(velocity.y, 0.0)
	if is_on_wall():
		# Consume actual collision response so blocked speed cannot accumulate.
		forward_speed = Vector3(velocity.x, 0.0, velocity.z).dot(_forward())
		if not is_on_floor():
			_wall_normal = get_wall_normal()
			_wall_time = settings.assisted_wall_window if assists_enabled else settings.wall_contact_window

	if _recording:
		_air_time += delta
		current_jump_height = maxf(current_jump_height, global_position.y - _jump_origin.y)
	if is_on_floor():
		if not grounded and _recording:
			_finish_jump()
		jump_kind = JumpKind.NONE
	else:
		# Reference ordering: displacement, then gravity for the next simulation tick.
		var shortenable: bool = jump_kind == JumpKind.SINGLE or jump_kind == JumpKind.DOUBLE
		if shortenable and not controls["held"] and not _release_used and velocity.y > settings.release_threshold:
			velocity.y *= settings.release_retention
			_release_used = true
		else:
			var weight: float = settings.long_jump_gravity_scale if jump_kind == JumpKind.LONG else 1.0
			velocity.y = maxf(velocity.y - settings.gravity * weight * delta, -settings.terminal_speed)
	if global_position.y < -12.0:
		respawn()
	simulation_stepped.emit()


func _ground_motion(wish: Vector3, delta: float) -> void:
	braking = false
	if wish.length_squared() > 0.0001:
		var target_yaw: float = atan2(-wish.x, -wish.z)
		var difference: float = wrapf(target_yaw - facing_yaw, -PI, PI)
		if absf(difference) > deg_to_rad(settings.reversal_angle) and forward_speed > 0.6:
			braking = true
			forward_speed = move_toward(forward_speed, 0.0, settings.reverse_braking * delta)
		else:
			if absf(forward_speed) < 0.6:
				facing_yaw = target_yaw
				forward_speed = maxf(forward_speed, minf(settings.start_speed, settings.run_speed * wish.length()))
			else:
				facing_yaw = rotate_toward(facing_yaw, target_yaw, settings.turn_speed * delta)
			var target_speed: float = settings.run_speed * wish.length()
			if forward_speed < target_speed:
				var acceleration: float = maxf(0.0, settings.acceleration - settings.speed_drag * forward_speed)
				forward_speed = minf(target_speed, forward_speed + acceleration * delta)
			else:
				forward_speed = move_toward(forward_speed, target_speed, settings.overspeed_braking * delta)
		if get_floor_normal().y < 0.995:
			var downhill: Vector3 = Vector3.DOWN.slide(get_floor_normal())
			forward_speed += downhill.dot(_forward()) * settings.slope_acceleration * delta
	else:
		braking = absf(forward_speed) > 0.5
		forward_speed = move_toward(forward_speed, 0.0, settings.braking * delta)
	forward_speed = clampf(forward_speed, -settings.run_speed, settings.air_speed_limit)
	_set_horizontal(_forward() * forward_speed)


func _air_motion(wish: Vector3, delta: float) -> void:
	braking = false
	var forward: Vector3 = _forward()
	var right: Vector3 = forward.cross(Vector3.UP)
	forward_speed = move_toward(forward_speed, 0.0, settings.air_drag * delta)
	forward_speed += wish.dot(forward) * settings.air_acceleration * delta
	var soft_limit: float = settings.long_jump_max_speed if jump_kind == JumpKind.LONG else settings.run_speed
	if forward_speed > soft_limit:
		forward_speed = maxf(soft_limit, forward_speed - settings.air_overspeed_drag * delta)
	if forward_speed < -settings.run_speed * 0.5:
		forward_speed = minf(-settings.run_speed * 0.5, forward_speed + settings.air_overspeed_drag * 2.0 * delta)
	forward_speed = clampf(forward_speed, -settings.air_speed_limit, settings.air_speed_limit)
	_set_horizontal(forward * forward_speed + right * wish.dot(right) * settings.air_side_speed)


func _launch_ground_jump(crouch: bool, grounded: bool) -> void:
	var launch: float = settings.jump_speed + maxf(0.0, forward_speed) * settings.running_jump_bonus
	jump_kind = JumpKind.SINGLE
	if crouch and forward_speed >= settings.long_jump_min_speed:
		jump_kind = JumpKind.LONG
		launch = settings.long_jump_speed
		forward_speed = minf(forward_speed * settings.long_jump_boost, settings.long_jump_max_speed)
	else:
		if grounded and _chain > 0.0:
			if _previous_jump == JumpKind.SINGLE:
				jump_kind = JumpKind.DOUBLE
				launch = settings.double_jump_speed + maxf(0.0, forward_speed) * settings.running_jump_bonus
			elif _previous_jump == JumpKind.DOUBLE and forward_speed > settings.triple_jump_min_speed:
				jump_kind = JumpKind.TRIPLE
				launch = settings.triple_jump_speed
		forward_speed *= settings.takeoff_retention
	_set_horizontal(_forward() * forward_speed)
	velocity.y = launch
	_begin_jump()


func _launch_wall_jump() -> void:
	var away: Vector3 = Vector3(_wall_normal.x, 0.0, _wall_normal.z).normalized()
	if away.is_zero_approx():
		return
	facing_yaw = atan2(-away.x, -away.z)
	forward_speed = settings.wall_push_speed
	_set_horizontal(away * forward_speed)
	velocity.y = settings.wall_jump_speed
	jump_kind = JumpKind.WALL
	_wall_lock = 0.18
	_wall_time = 0.0
	_begin_jump()


func _begin_jump() -> void:
	_buffer = 0.0
	_coyote = 0.0
	_chain = 0.0
	_release_used = false
	_recording = true
	_jump_origin = global_position
	_air_time = 0.0
	current_jump_height = 0.0


func _finish_jump() -> void:
	last_jump_height = current_jump_height
	last_jump_distance = Vector2(global_position.x - _jump_origin.x, global_position.z - _jump_origin.z).length()
	last_air_time = _air_time
	_previous_jump = jump_kind
	_chain = settings.chain_window
	_recording = false
	landed.emit(last_jump_height, last_jump_distance, last_air_time)


func _forward() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


func _set_horizontal(horizontal: Vector3) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _read_controls() -> Dictionary:
	if not input_override.is_empty():
		var controls: Dictionary = input_override.duplicate()
		input_override["pressed"] = false
		return controls
	if not input_enabled:
		return {"move": Vector2.ZERO, "pressed": false, "held": false, "crouch": false}
	return {
		"move": Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
		"pressed": Input.is_action_just_pressed("jump"),
		"held": Input.is_action_pressed("jump"),
		"crouch": Input.is_action_pressed("crouch")
	}


func respawn(at: Vector3 = Vector3.INF) -> void:
	global_position = _spawn if at == Vector3.INF else at
	velocity = Vector3.ZERO
	forward_speed = 0.0
	facing_yaw = 0.0
	jump_kind = JumpKind.NONE
	_previous_jump = JumpKind.NONE
	_buffer = 0.0
	_coyote = 0.0
	_chain = 0.0
	_wall_time = 0.0
	_wall_lock = 0.0
	_recording = false
	current_jump_height = 0.0
	reset_physics_interpolation()


func restore_defaults() -> void:
	settings = profile.duplicate(true) if profile != null else MovementProfile.new()


func state_label() -> String:
	if is_on_floor():
		return "BRAKING" if braking else ("RUNNING" if absf(forward_speed) > 0.2 else "READY")
	var names: Array[String] = ["FALLING", "JUMP", "DOUBLE JUMP", "TRIPLE JUMP", "LONG JUMP", "WALL JUMP"]
	return names[jump_kind]
