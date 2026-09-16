extends Node3D

@onready var _player: ShmovementPlayer = $Player
@onready var _camera: Node3D = $CameraRig
@onready var _hud: CanvasLayer = $HUD
const COURSE := preload("res://scripts/practice_course.gd")
var station: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		visit_station(station)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
		visit_station(event.physical_keycode - KEY_1)
	if event.is_action_pressed("toggle_assists"):
		_player.assists_enabled = not _player.assists_enabled
	if event.is_action_pressed("tuning"):
		_hud.toggle_tuning()
	if event.is_action_pressed("ui_cancel"):
		if _hud.tuning_open:
			_hud.toggle_tuning()
		else:
			var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED
			_player.input_enabled = not captured
			_camera.look_enabled = not captured
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _hud.tuning_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_player.input_enabled = true
			_camera.look_enabled = true

func visit_station(index: int) -> void:
	station = clampi(index, 0, COURSE.STATIONS.size() - 1)
	_player.respawn(COURSE.STATIONS[station])
	_camera.rotation.y = 0.0
	_camera.snap_to_target()
	_player.core.last_event = COURSE.STATION_NAMES[station]
