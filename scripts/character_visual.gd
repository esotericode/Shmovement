extends Node3D
## Mesh animation is cosmetic; the collision capsule stays upright and constant.

var _phase: float = 0.0
@onready var _player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var _left: Node3D = $LeftFoot
@onready var _right: Node3D = $RightFoot
@onready var _body: Node3D = $Body


func _process(delta: float) -> void:
	rotation.y = float(_player.get("facing_yaw"))
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	_phase += speed * delta * 2.8
	var stride: float = minf(speed / 9.6, 1.0) if _player.is_on_floor() else 0.0
	_left.position.y = 0.15 + maxf(0.0, sin(_phase)) * 0.20 * stride
	_right.position.y = 0.15 + maxf(0.0, sin(_phase + PI)) * 0.20 * stride
	_left.position.z = -0.12 + cos(_phase) * 0.23 * stride
	_right.position.z = -0.12 + cos(_phase + PI) * 0.23 * stride
	_body.rotation.x = lerpf(_body.rotation.x, -0.10 * stride, 1.0 - exp(-12.0 * delta))
	if not _player.is_on_floor():
		_left.position.z = -0.22
		_right.position.z = 0.10
