extends Node3D
## CC0 rig and original state poses. Animation never moves the collision body.
const MODEL := preload("res://assets/character/scout.fbx")
const SKIN := preload("res://assets/character/scout.png")
const CLIPS: Dictionary = {
	"idle": preload("res://assets/character/idle.fbx"),
	"run": preload("res://assets/character/run.fbx"),
	"jump": preload("res://assets/character/jump.fbx")
}
var pose_name: String = "idle"
var _pivot: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _animator: AnimationPlayer
var _idle_positions: Array[Vector3] = []
var _idle_rotations: Array[Quaternion] = []
var _clip_time: float = 0.0
var _last_tick: int = -1
var _player: ShmovementPlayer

func _ready() -> void:
	_player = get_parent() as ShmovementPlayer
	_pivot = Node3D.new()
	_pivot.position.y = 0.9
	add_child(_pivot)
	_model = MODEL.instantiate()
	_model.position.y = -0.9
	_model.scale = Vector3(0.54, 0.478, 0.54)
	_model.rotation.y = PI # Kenney faces +Z; the movement core faces -Z.
	_pivot.add_child(_model)
	_skeleton = _model.get_node("Root/Skeleton3D")
	var material := StandardMaterial3D.new()
	material.albedo_texture = SKIN
	material.roughness = 0.85
	(_skeleton.get_node("characterMedium") as MeshInstance3D).material_override = material
	_animator = AnimationPlayer.new()
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_model.add_child(_animator)
	var library := AnimationLibrary.new()
	for clip in CLIPS:
		var source: Node = (CLIPS[clip] as PackedScene).instantiate()
		var source_player: AnimationPlayer = source.get_node("AnimationPlayer")
		for name in source_player.get_animation_list():
			if name.ends_with("|" + String(clip).capitalize()):
				var animation: Animation = source_player.get_animation(name).duplicate(true)
				animation.loop_mode = Animation.LOOP_LINEAR if clip != "jump" else Animation.LOOP_NONE
				library.add_animation(clip, animation)
		source.free()
	_animator.add_animation_library("", library)
	_sample("idle", 0.0)
	for bone in _skeleton.get_bone_count():
		_idle_positions.append(_skeleton.get_bone_pose_position(bone))
		_idle_rotations.append(_skeleton.get_bone_pose_rotation(bone))
	_skeleton.set_bone_pose_scale(_skeleton.find_bone("Head"), Vector3.ONE * 1.15)

func _process(delta: float) -> void:
	if _player == null:
		return
	var state: MovementCore = _player.core
	rotation.y = _player.facing_yaw
	_pivot.rotation = Vector3.ZERO
	_pivot.position.y = 0.9
	_clip_time += delta
	pose_name = String(state.animation)
	if state.tick != _last_tick and state.launched:
		_clip_time = 0.0
	_last_tick = state.tick
	var frame: float = float(state.action_ticks) + Engine.get_physics_interpolation_fraction()
	match state.action:
		MovementCore.Action.WALKING, MovementCore.Action.DECELERATING:
			_sample("run", fmod(_clip_time * clampf(absf(_player.forward_speed) / 6.0, 0.35, 1.8), 2.0 / 3.0))
		MovementCore.Action.IDLE, MovementCore.Action.LAND_STOP, MovementCore.Action.ROLLOUT_LAND:
			_sample("idle", fmod(_clip_time, 32.0 / 30.0))
		MovementCore.Action.TURNING_AROUND, MovementCore.Action.FINISH_TURNING_AROUND, MovementCore.Action.BRAKING:
			_base_pose()
			_bend("Spine", Vector3.RIGHT, 22)
			_bend("LeftUpLeg", Vector3.RIGHT, 42)
			_bend("RightUpLeg", Vector3.RIGHT, 10)
			_bend("LeftLeg", Vector3.RIGHT, -35)
			_bend("RightLeg", Vector3.RIGHT, -25)
			_bend("LeftArm", Vector3.RIGHT, -45)
			_bend("RightArm", Vector3.RIGHT, 38)
			_pivot.position.y -= 0.08
			if state.action == MovementCore.Action.FINISH_TURNING_AROUND:
				var progress: float = clampf(float(state.animation_frame) / 17.0, 0, 1)
				_pivot.rotation.y = PI * (1.0 - smoothstep(0.0, 1.0, progress))
		MovementCore.Action.LONG_JUMP:
			_base_pose()
			_bend("Spine", Vector3.RIGHT, -22)
			_bend("LeftUpLeg", Vector3.RIGHT, 72)
			_bend("RightUpLeg", Vector3.RIGHT, 58)
			_bend("LeftLeg", Vector3.RIGHT, -20)
			_bend("RightLeg", Vector3.RIGHT, -12)
			_bend("LeftArm", Vector3.RIGHT, -65)
			_bend("RightArm", Vector3.RIGHT, -65)
		MovementCore.Action.SIDE_FLIP, MovementCore.Action.TRIPLE_JUMP, MovementCore.Action.BACKFLIP:
			_base_pose()
			_bend("LeftUpLeg", Vector3.RIGHT, 70)
			_bend("RightUpLeg", Vector3.RIGHT, 70)
			_bend("LeftLeg", Vector3.RIGHT, -95)
			_bend("RightLeg", Vector3.RIGHT, -95)
			_bend("LeftArm", Vector3.RIGHT, 55)
			_bend("RightArm", Vector3.RIGHT, 55)
			var spin: float = TAU * smoothstep(0.0, 23.0, frame)
			if state.action == MovementCore.Action.SIDE_FLIP:
				_pivot.rotation.z = spin
			else:
				_pivot.rotation.x = spin * (-1.0 if state.action == MovementCore.Action.TRIPLE_JUMP else 1.0)
		MovementCore.Action.WALL_KICK:
			_base_pose()
			_bend("LeftUpLeg", Vector3.RIGHT, 65)
			_bend("LeftLeg", Vector3.RIGHT, -85)
			_bend("RightUpLeg", Vector3.RIGHT, -35)
			_bend("LeftArm", Vector3.RIGHT, -70)
			_bend("RightArm", Vector3.RIGHT, 75)
			_pivot.rotation.x = -0.15
		MovementCore.Action.DIVE, MovementCore.Action.DIVE_SLIDE, MovementCore.Action.STOMACH_SLIDE_STOP:
			_base_pose()
			var recovery: float = smoothstep(4.0, 37.0, float(state.animation_frame)) if state.action == MovementCore.Action.STOMACH_SLIDE_STOP else 0.0
			var extension: float = 1.0 - recovery
			_bend("LeftArm", Vector3.RIGHT, 155 * extension)
			_bend("RightArm", Vector3.RIGHT, 155 * extension)
			_bend("LeftForeArm", Vector3.RIGHT, 12)
			_bend("RightForeArm", Vector3.RIGHT, 12)
			_bend("LeftLeg", Vector3.RIGHT, -18 * extension)
			_bend("RightLeg", Vector3.RIGHT, -25 * extension)
			_pivot.rotation.x = -PI / 2.0 * extension
			if state.action == MovementCore.Action.DIVE:
				_pivot.rotation.x += float(state.dive_pitch) * TAU / 65536.0
			else:
				_pivot.position.y = lerpf(0.4, 0.9, recovery)
		MovementCore.Action.FORWARD_ROLLOUT, MovementCore.Action.BACKWARD_ROLLOUT:
			_base_pose()
			_bend("LeftUpLeg", Vector3.RIGHT, 100)
			_bend("RightUpLeg", Vector3.RIGHT, 100)
			_bend("LeftLeg", Vector3.RIGHT, -120)
			_bend("RightLeg", Vector3.RIGHT, -120)
			_bend("LeftArm", Vector3.RIGHT, 65)
			_bend("RightArm", Vector3.RIGHT, 65)
			_pivot.rotation.x = TAU * smoothstep(0, 10, frame) * (-1.0 if state.action == MovementCore.Action.FORWARD_ROLLOUT else 1.0)
		MovementCore.Action.JUMP_KICK, MovementCore.Action.PUNCH:
			_base_pose()
			_bend("RightArm", Vector3.RIGHT, 85)
			_bend("LeftArm", Vector3.RIGHT, 40)
			if state.action == MovementCore.Action.JUMP_KICK:
				_bend("RightUpLeg", Vector3.RIGHT, 85)
				_bend("LeftUpLeg", Vector3.RIGHT, 30)
				_bend("LeftLeg", Vector3.RIGHT, -65)
		MovementCore.Action.AIR_HIT_WALL, MovementCore.Action.SOFT_BONK, MovementCore.Action.HARD_BONK, MovementCore.Action.GROUND_BONK:
			_base_pose()
			_bend("LeftArm", Vector3.RIGHT, 90)
			_bend("RightArm", Vector3.RIGHT, 90)
			_bend("LeftUpLeg", Vector3.RIGHT, 50)
			_bend("RightUpLeg", Vector3.RIGHT, 50)
			_bend("LeftLeg", Vector3.RIGHT, -75)
			_bend("RightLeg", Vector3.RIGHT, -75)
		MovementCore.Action.CROUCHING, MovementCore.Action.CROUCH_SLIDE, MovementCore.Action.LANDING:
			_base_pose()
			_bend("LeftUpLeg", Vector3.RIGHT, 65)
			_bend("RightUpLeg", Vector3.RIGHT, 65)
			_bend("LeftLeg", Vector3.RIGHT, -95)
			_bend("RightLeg", Vector3.RIGHT, -95)
			_bend("Spine", Vector3.RIGHT, -20)
			_pivot.position.y -= 0.25
		_:
			_sample("jump", 0.12 if state.vertical_velocity > 0 else 0.35)

func _sample(clip: StringName, time: float) -> void:
	_animator.play(clip)
	_animator.seek(time, true)
	_animator.advance(0)

func _base_pose() -> void:
	for bone in _skeleton.get_bone_count():
		_skeleton.set_bone_pose_position(bone, _idle_positions[bone])
		_skeleton.set_bone_pose_rotation(bone, _idle_rotations[bone])

func _bend(name: String, axis: Vector3, degrees: float) -> void:
	var bone: int = _skeleton.find_bone(name)
	var parent: int = _skeleton.get_bone_parent(bone)
	var basis: Basis = _skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var local_axis: Vector3 = (basis.inverse() * axis).normalized()
	var delta_rotation := Quaternion(local_axis, deg_to_rad(-degrees))
	_skeleton.set_bone_pose_rotation(bone, delta_rotation * _skeleton.get_bone_pose_rotation(bone))
