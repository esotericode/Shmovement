class_name ShmovementPlayer
extends CharacterBody3D
## Godot input/collision adapter. See MovementCore and docs/MOVEMENT_REFERENCE.md.

signal simulation_stepped
signal landed(height: float, distance: float, duration: float)
enum JumpKind { NONE, SINGLE, DOUBLE, TRIPLE, LONG, WALL, SIDE, BACK }

@export var profile: MovementProfile
@export var camera_path: NodePath
@export var assists_enabled: bool = false
var core: MovementCore = MovementCore.new()
var settings: MovementProfile
var facing_yaw: float:
	get: return float(core.facing) * TAU / 65536.0
	set(value): core.facing = MovementCore.signed_angle(roundi(value * 65536.0 / TAU))
var forward_speed: float:
	get: return core.forward_velocity * MovementCore.SPEED_SCALE
	set(value): core.forward_velocity = value / MovementCore.SPEED_SCALE
var braking: bool:
	get: return core.action in [MovementCore.Action.BRAKING, MovementCore.Action.TURNING_AROUND]
var jump_kind: JumpKind = JumpKind.NONE
var input_enabled: bool = true
var input_override: Dictionary = {}
var last_jump_height: float = 0.0
var last_jump_distance: float = 0.0
var last_air_time: float = 0.0
var current_jump_height: float = 0.0
var last_jump_name: String = "NONE"
var _camera: Node3D
var _spawn: Vector3
var _buffer_ticks: int = 0
var _coyote_ticks: int = 0
var _recording: bool = false
var _jump_origin: Vector3
var _air_ticks: int = 0
var _jump_edge: bool = false
var _attack_edge: bool = false
var _respawn_pending: bool = false

func _ready() -> void:
	restore_defaults()
	_camera = get_node_or_null(camera_path) as Node3D
	_spawn = global_position
	core.grounded = false
	floor_snap_length = 0.22
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	floor_stop_on_slope = true
	wall_min_slide_angle = 0.0
	assert(Engine.physics_ticks_per_second == MovementCore.HZ, "Reference actions require 30 physics ticks/s")

func _input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed("jump") and not event.is_echo():
		_jump_edge = true
	if input_enabled and event.is_action_pressed("attack") and not event.is_echo():
		_attack_edge = true

func _physics_process(_delta: float) -> void:
	var controls: Dictionary = _read_controls()
	var stick: Vector2 = controls["move"]
	if input_override.is_empty() and _camera != null:
		var world := Vector3(stick.x, 0, stick.y).rotated(Vector3.UP, _camera.rotation.y)
		controls["move"] = Vector2(world.x, world.z)
	var was_grounded: bool = is_on_floor() and not _respawn_pending and core.vertical_velocity <= 0.0
	_respawn_pending = false
	core.grounded = was_grounded
	core.floor_normal = get_floor_normal() if was_grounded else Vector3.UP
	core.floor_class = _floor_class() if was_grounded else 0
	core.assists = assists_enabled
	_apply_assists(controls, was_grounded)
	var frame_motion: Vector3 = core.begin_tick(controls)
	if core.launched:
		_begin_jump()
	velocity = frame_motion * MovementCore.SPEED_SCALE
	if not core.is_airborne():
		velocity.y = -0.3 # Godot floor-contact probe, not reference gravity.
	move_and_slide()
	var contact: Vector3 = get_wall_normal() if is_on_wall() else Vector3.ZERO
	# Godot recovery can leave a floor flag on a rising takeoff tick.
	var on_floor: bool = is_on_floor() and (not core.is_airborne() or frame_motion.y <= 0.0)
	core.end_tick(on_floor, contact, is_on_ceiling())
	velocity.y = core.vertical_velocity * MovementCore.SPEED_SCALE
	if _recording:
		_air_ticks += 1
		current_jump_height = maxf(current_jump_height, global_position.y - _jump_origin.y)
	if on_floor:
		if not was_grounded and _recording:
			_finish_jump()
		jump_kind = JumpKind.NONE
	if global_position.y < -12.0:
		respawn()
	simulation_stepped.emit()

func _apply_assists(controls: Dictionary, on_floor: bool) -> void:
	if not assists_enabled:
		_buffer_ticks = 0
		_coyote_ticks = 0
		return
	_coyote_ticks = ceili(settings.coyote_time * 30) if on_floor else maxi(0, _coyote_ticks - 1)
	_buffer_ticks = ceili(settings.jump_buffer * 30) if controls["pressed"] else maxi(0, _buffer_ticks - 1)
	if _buffer_ticks > 0 and (on_floor or (_coyote_ticks > 0 and core.action == MovementCore.Action.FREEFALL)):
		controls["pressed"] = true
		if not on_floor:
			core.grounded = true
			core.action = MovementCore.Action.IDLE
		_buffer_ticks = 0
		_coyote_ticks = 0

func _begin_jump() -> void:
	var kinds: Dictionary = {
		MovementCore.Action.JUMP: JumpKind.SINGLE, MovementCore.Action.DOUBLE_JUMP: JumpKind.DOUBLE,
		MovementCore.Action.TRIPLE_JUMP: JumpKind.TRIPLE, MovementCore.Action.LONG_JUMP: JumpKind.LONG,
		MovementCore.Action.WALL_KICK: JumpKind.WALL, MovementCore.Action.SIDE_FLIP: JumpKind.SIDE,
		MovementCore.Action.BACKFLIP: JumpKind.BACK
	}
	jump_kind = kinds.get(core.action, JumpKind.NONE)
	last_jump_name = core.action_name().replace("_", " ")
	_recording = true
	_jump_origin = global_position
	_air_ticks = 0
	current_jump_height = 0.0

func _finish_jump() -> void:
	last_jump_height = current_jump_height
	last_jump_distance = Vector2(global_position.x - _jump_origin.x, global_position.z - _jump_origin.z).length()
	last_air_time = float(_air_ticks) / MovementCore.HZ
	_recording = false
	landed.emit(last_jump_height, last_jump_distance, last_air_time)

func _read_controls() -> Dictionary:
	if not input_override.is_empty():
		var controls: Dictionary = input_override.duplicate()
		input_override["pressed"] = false
		input_override["attack"] = false
		_jump_edge = false
		_attack_edge = false
		return controls
	if not input_enabled:
		_jump_edge = false
		_attack_edge = false
		return {"move": Vector2.ZERO, "pressed": false, "held": false, "crouch": false}
	var pressed: bool = _jump_edge or Input.is_action_just_pressed("jump")
	var attack: bool = _attack_edge or Input.is_action_just_pressed("attack")
	_jump_edge = false
	_attack_edge = false
	return {
		"move": Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
		"pressed": pressed, "held": Input.is_action_pressed("jump"), "attack": attack,
		"crouch": Input.is_action_pressed("crouch")
	}

func respawn(at: Vector3 = Vector3.INF) -> void:
	global_position = _spawn if at == Vector3.INF else at
	velocity = Vector3.ZERO
	core = MovementCore.new()
	core.settings = settings
	core.grounded = false
	jump_kind = JumpKind.NONE
	_buffer_ticks = 0
	_coyote_ticks = 0
	_recording = false
	_jump_edge = false
	_attack_edge = false
	_respawn_pending = true
	current_jump_height = 0.0
	reset_physics_interpolation()

func _floor_class() -> int:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
			var collider: Object = collision.get_collider()
			if collider != null:
				return clampi(int(collider.get_meta("floor_class", 0)), 0, 3)
	return 0

func restore_defaults() -> void:
	settings = profile.duplicate(true) if profile != null else MovementProfile.new()
	core.settings = settings

func is_reference_profile() -> bool:
	var baseline := MovementProfile.new()
	for property in baseline.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			if not is_equal_approx(float(settings.get(property.name)), float(baseline.get(property.name))):
				return false
	return not assists_enabled

func state_label() -> String:
	return core.action_name().replace("_", " ")
