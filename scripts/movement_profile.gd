class_name MovementProfile
extends Resource
## SI experiment settings; action thresholds and windows belong to MovementCore.
@export_group("Ground")
@export var run_speed: float = 9.6
@export var start_speed: float = 2.4
@export var acceleration: float = 9.9
@export var reverse_braking: float = 36.0
@export var turn_speed: float = 5.89048622548086
@export var stick_exponent: float = 2.0
@export_group("Jump")
@export var jump_speed: float = 12.6
@export var double_jump_speed: float = 15.6
@export var gravity: float = 36.0
@export var air_side_speed: float = 3.0
@export_group("Optional experiments")
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12
