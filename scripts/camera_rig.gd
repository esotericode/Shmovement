extends Node3D

@export var target_path: NodePath
@export var mouse_sensitivity: float = 0.0025
@export var stick_sensitivity: float = 2.5
@export var follow_speed: float = 14.0

var look_enabled: bool = true
var _target: Node3D
var _pitch: float = -0.30
@onready var _arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	_target = get_node(target_path) as Node3D
	_arm.add_excluded_object((_target as CollisionObject3D).get_rid())
	snap_to_target()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and look_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.10, 0.35)
	if event.is_action_pressed("recenter") and look_enabled:
		rotation.y = float(_target.get("facing_yaw"))
		_pitch = -0.30


func _physics_process(delta: float) -> void:
	if look_enabled:
		var look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
		rotation.y -= look.x * stick_sensitivity * delta
		_pitch = clampf(_pitch - look.y * stick_sensitivity * delta, -1.10, 0.35)
	global_position = global_position.lerp(_target.global_position + Vector3.UP * 1.15, 1.0 - exp(-follow_speed * delta))
	_arm.rotation.x = _pitch


func snap_to_target() -> void:
	global_position = _target.global_position + Vector3.UP * 1.15
	rotation.y = float(_target.get("facing_yaw"))
	_arm.rotation.x = _pitch
	reset_physics_interpolation()
