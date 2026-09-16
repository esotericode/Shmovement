class_name MovementProfile
extends Resource
## SI units throughout: metres, seconds, radians. See docs/MOVEMENT_REFERENCE.md.

@export_group("Ground")
@export var run_speed: float = 9.6
@export var start_speed: float = 2.4
@export var acceleration: float = 9.9
@export var speed_drag: float = 0.697674
@export var braking: float = 18.0
@export var reverse_braking: float = 27.0
@export var overspeed_braking: float = 9.0
@export var turn_speed: float = 5.890486
@export var reversal_angle: float = 100.0
@export var slope_acceleration: float = 12.0
@export var stick_exponent: float = 2.0

@export_group("Jump")
@export var jump_speed: float = 12.6
@export var running_jump_bonus: float = 0.25
@export var takeoff_retention: float = 0.8
@export var gravity: float = 36.0
@export var terminal_speed: float = 22.5
@export var release_threshold: float = 6.0
@export var release_retention: float = 0.25
@export var double_jump_speed: float = 15.6
@export var triple_jump_speed: float = 20.7
@export var triple_jump_min_speed: float = 6.0
@export var chain_window: float = 0.20

@export_group("Long jump")
@export var long_jump_speed: float = 9.0
@export var long_jump_boost: float = 1.5
@export var long_jump_max_speed: float = 14.4
@export var long_jump_min_speed: float = 3.0
@export var long_jump_gravity_scale: float = 0.5

@export_group("Air")
@export var air_acceleration: float = 13.5
@export var air_drag: float = 3.15
@export var air_side_speed: float = 3.0
@export var air_overspeed_drag: float = 9.0
@export var air_speed_limit: float = 16.0
@export var wall_jump_speed: float = 18.6
@export var wall_push_speed: float = 7.2
@export var wall_contact_window: float = 0.067

@export_group("Optional assists")
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12
@export var assisted_wall_window: float = 0.12
