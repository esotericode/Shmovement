extends SceneTree
## Candidate side of the differential test. Expected results never enter Godot.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scenarios: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var output: Array = []
	for scenario in scenarios:
		var initial: Dictionary = scenario.initial
		var core := MovementCore.new()
		core.action = MovementCore.Action[initial.action]
		core.forward_velocity = core.f32(initial.speed)
		core.vertical_velocity = core.f32(initial.up)
		core.facing = initial.facing
		core.slide_yaw = initial.slide_yaw
		core.slide_velocity = Vector3(initial.slide[0], 0, initial.slide[1])
		core.motion = Vector3(core.slide_velocity.x, core.vertical_velocity, core.slide_velocity.z)
		core.dive_pitch = initial.get("pitch", 0)
		if initial.has("launch"):
			core._launch(MovementCore.Action[initial.launch])
		core.grounded = not core.is_airborne()
		if core.action == MovementCore.Action.DIVE_SLIDE:
			core.animation = &"dive"
			core.animation_frame = 19
		var trace: Array = []
		for frame in scenario.frames:
			core.floor_class = frame.surface
			core.floor_normal = Vector3(frame.normal[0], frame.normal[1], frame.normal[2])
			var controls: Dictionary = frame.input
			var travel := Vector3.ZERO
			if scenario.mode == 0:
				travel = core.begin_tick(controls)
				var airborne: bool = core.is_airborne()
				core.end_tick(frame.contact == 1 if airborne else frame.contact != 3,
					Vector3(frame.wall[0], frame.wall[1], frame.wall[2]) if frame.contact == 2 else Vector3.ZERO)
			else:
				core.intended_yaw = controls.yaw
				core.intended_magnitude = controls.magnitude
				core._held = controls.get("held", false)
				core._attack = controls.get("attack", false)
				if scenario.mode == 1:
					core._update_sliding(frame.stop)
					travel = Vector3(core.motion.x, 0, core.motion.z)
				elif scenario.mode == 2:
					core._update_air()
					travel = Vector3(core.motion.x, core.vertical_velocity, core.motion.z)
					core._apply_gravity()
				else:
					if core.action == MovementCore.Action.WALKING:
						if core._attack:
							core._ground_attack()
					else:
						core._air_attack()
			trace.append([core.action_name(), core.forward_velocity, core.vertical_velocity, core.facing,
				core.slide_yaw, core.slide_velocity.x, core.slide_velocity.z, core.dive_pitch,
				core.motion.x, core.motion.z, travel.x, travel.y, travel.z, core.action_state])
		output.append({"name": scenario.name, "trace": trace})
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	file.close()
	quit()
