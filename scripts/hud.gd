extends CanvasLayer

const INK := Color("102731")
const PAPER := Color("f0f5ed")
const MUTED := Color("b5c7c6")
const ACCENT := Color("ffc572")

var tuning_open: bool = false
var _speed: Label
var _state: Label
var _assist: Label
var _jump: Label
var _bar: ProgressBar
var _tuning: PanelContainer
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _rows: Array = [
	["run_speed", "Run speed", 5.0, 14.0, 0.1, "m/s"],
	["acceleration", "Acceleration", 5.0, 22.0, 0.1, "m/s²"],
	["jump_speed", "Jump launch", 8.0, 18.0, 0.1, "m/s"],
	["gravity", "Gravity", 20.0, 55.0, 0.5, "m/s²"],
	["turn_speed", "Turn rate", 2.0, 12.0, 0.1, "rad/s"],
	["air_side_speed", "Air steering", 0.0, 6.0, 0.1, "m/s"]
]
@onready var _player: ShmovementPlayer = get_parent().get_node("Player")
@onready var _camera: Node3D = get_parent().get_node("CameraRig")


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", PAPER)
	root.theme = theme
	var title := _panel(root, Vector2(28, 26), Vector2(365, 113))
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 6)
	title.add_child(title_box)
	title_box.add_child(_label("S H M O V E M E N T", 27, PAPER))
	title_box.add_child(_label("01  /  THE MOVEMENT PLAYGROUND", 13, ACCENT))
	title_box.add_child(_label("Build momentum. Find your rhythm.", 14, MUTED))
	var stats := _panel(root, Vector2(-280, 26), Vector2(252, 252))
	stats.anchor_left = 1.0
	stats.anchor_right = 1.0
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 8)
	stats.add_child(stats_box)
	_state = _label("READY", 14, ACCENT)
	stats_box.add_child(_state)
	_speed = _label("0.0  m/s", 36, PAPER)
	stats_box.add_child(_speed)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 5
	_bar.max_value = 16.0
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", _style(Color("30474e"), 2, 0))
	_bar.add_theme_stylebox_override("fill", _style(ACCENT, 2, 0))
	stats_box.add_child(_bar)
	_jump = _label("", 15, MUTED)
	stats_box.add_child(_jump)
	_assist = _label("", 13, ACCENT)
	stats_box.add_child(_assist)
	var help := _panel(root, Vector2(28, -130), Vector2(710, 102))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	var help_box := VBoxContainer.new()
	help_box.add_theme_constant_override("separation", 7)
	help.add_child(help_box)
	help_box.add_child(_label("WASD / left stick   Move     •     SPACE / A   Jump     •     Mouse / right stick   Look", 15, PAPER))
	help_box.add_child(_label("SHIFT / LT + jump   Long jump     •     Jump on landing   Chain     •     Jump at a wall   Kick", 14, MUTED))
	help_box.add_child(_label("R   Reset     F   Recenter     F1   Assists     T   Tune     ESC   Release mouse", 14, ACCENT))
	_build_tuning(root)


func _process(_delta: float) -> void:
	var horizontal: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	_speed.text = "%04.1f  m/s" % horizontal
	_bar.value = horizontal
	_state.text = _player.state_label()
	var height: float = _player.current_jump_height if not _player.is_on_floor() else _player.last_jump_height
	_jump.text = "Peak height     %4.2f m\nLast distance   %4.2f m\nLast airtime    %4.2f s" % [height, _player.last_jump_distance, _player.last_air_time]
	_assist.text = "ASSISTS ON  ·  forgiving timing" if _player.assists_enabled else "ASSISTS OFF  ·  baseline timing"


func _build_tuning(root: Control) -> void:
	_tuning = _panel(root, Vector2(-220, -275), Vector2(440, 550))
	_tuning.set_anchors_preset(Control.PRESET_CENTER)
	_tuning.offset_left = -220.0
	_tuning.offset_right = 220.0
	_tuning.offset_top = -300.0
	_tuning.offset_bottom = 300.0
	_tuning.mouse_filter = Control.MOUSE_FILTER_STOP
	_tuning.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_tuning.add_child(box)
	box.add_child(_label("MAKE IT FEEL RIGHT", 24, PAPER))
	box.add_child(_label("Live adjustments • Reset restores the baseline", 14, MUTED))
	for row in _rows:
		var key: String = row[0]
		var heading := HBoxContainer.new()
		var name_label := _label(row[1], 15, PAPER)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(name_label)
		var value_label := _label("", 14, ACCENT)
		heading.add_child(value_label)
		box.add_child(heading)
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.value = float(_player.settings.get(key))
		slider.custom_minimum_size.y = 18
		slider.value_changed.connect(_change_setting.bind(key, str(row[5])))
		box.add_child(slider)
		_sliders[key] = slider
		_value_labels[key] = value_label
		_change_setting(slider.value, key, str(row[5]))
	var reset := Button.new()
	reset.text = "Restore baseline"
	reset.custom_minimum_size.y = 38
	reset.pressed.connect(_reset_tuning)
	box.add_child(reset)
	var close := Button.new()
	close.text = "Back to playground  [T]"
	close.custom_minimum_size.y = 38
	close.pressed.connect(toggle_tuning)
	box.add_child(close)


func toggle_tuning() -> void:
	tuning_open = not tuning_open
	_tuning.visible = tuning_open
	_player.input_enabled = not tuning_open
	_camera.look_enabled = not tuning_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if tuning_open else Input.MOUSE_MODE_CAPTURED


func _change_setting(value: float, key: String, unit: String) -> void:
	_player.settings.set(key, value)
	(_value_labels[key] as Label).text = "%.1f %s" % [value, unit]


func _reset_tuning() -> void:
	_player.restore_defaults()
	for key in _sliders:
		(_sliders[key] as HSlider).value = float(_player.settings.get(key))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel(parent: Control, offset: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = offset
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(INK, 0.93), 12, 18))
	parent.add_child(panel)
	return panel


func _style(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
