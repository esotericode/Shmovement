extends Node3D
## Original practice geometry. Surface metadata is consumed by the collision adapter.
const STATIONS: Array[Vector3] = [
	Vector3(0, 0.04, 13), Vector3(-36, 0.14, 48), Vector3(31.5, 0.04, -26),
	Vector3(26, 0.04, 45), Vector3(-7, 0.04, -24)
]
const STATION_NAMES: Array[String] = ["BASICS", "100 m RUN / DIVE", "24 m WALL TOWER", "JUMP COURSE", "SLOPE LAB"]
const TEAL := Color("388d91")
const ORANGE := Color("eb8750")
const CREAM := Color("e9dfa9")
const BLUE := Color("779bc1")

func _ready() -> void:
	_resize_box("Floor", Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_resize_box("NorthWall", Vector3(120, 7, 0.7), Vector3(0, 3.5, -60))
	_resize_box("WestWall", Vector3(0.7, 7, 120), Vector3(-60, 3.5, 0))
	_resize_box("EastWall", Vector3(0.7, 7, 120), Vector3(60, 3.5, 0))
	_resize_box("SouthRail", Vector3(120, 1.3, 0.7), Vector3(0, 0.65, 60))
	for child in get_children():
		if child.name.begins_with("NorthBeam") or child.name.ends_with("Trim"):
			child.hide()
	_runways()
	_tower()
	_jumps()
	_slopes()
	for i in STATIONS.size():
		_label("Station%d" % (i + 1), "%d / %s" % [i + 1, STATION_NAMES[i]], STATIONS[i] + Vector3(0, 4.0, -5), CREAM, 0.013)

func _runways() -> void:
	for lane in 3:
		var x: float = -45.0 + lane * 9.0
		var colors: Array[Color] = [TEAL, ORANGE, BLUE]
		var names: Array[String] = ["DEFAULT", "SLIPPERY", "VERY SLIPPERY"]
		var body := _box("Runway%d" % lane, Vector3(x, 0.025, 0), Vector3(7, 0.05, 100), colors[lane])
		body.set_meta("floor_class", lane) # Core: default=0, slippery=1, very slippery=2.
		for mark in range(-50, 51, 10):
			_paint(Vector3(x, 0.057, mark), Vector3(7, 0.012, 0.12), CREAM)
			_label("Distance%d_%d" % [lane, mark], "%d m" % (50 - mark), Vector3(x - 3.3, 0.08, mark), CREAM, 0.012, true)
		_label("Surface%d" % lane, names[lane] + "\nRUN + E / X → DIVE\nSPACE / A → ROLL OUT", Vector3(x, 2.8, -51), CREAM, 0.017)

func _tower() -> void:
	_box("TowerLeft", Vector3(29, 12, -36), Vector3(0.6, 24, 16), TEAL)
	_box("TowerRight", Vector3(34, 12, -36), Vector3(0.6, 24, 16), TEAL)
	for height in range(3, 25, 3):
		for x in [29.0, 34.0]:
			_paint(Vector3(x, height, -27.96), Vector3(0.65, 0.16, 0.1), CREAM)
		_label("Height%d" % height, "%d m" % height, Vector3(31.5, height, -44.2), CREAM, 0.018)
	for level in range(1, 5):
		_box("TowerRest%d" % level, Vector3(38, level * 6 - 0.25, -42), Vector3(7, 0.5, 4), ORANGE)
	_box("TowerSummit", Vector3(31.5, 23.75, -46), Vector3(13, 0.5, 4), ORANGE)
	_label("TowerHint", "ALTERNATE WALL KICKS\nJump within the impact window", Vector3(31.5, 4, -26), CREAM, 0.018)

func _jumps() -> void:
	# Two switchbacks: heights increase by 0.8 m; gaps widen along each row.
	for i in 10:
		var row: int = i / 5
		var column: int = i % 5 if row == 0 else 4 - i % 5
		var top: float = 1.0 + i * 0.8
		var center := Vector3(26 + row * 10, top - 0.3, 38 - column * 7)
		_box("JumpPlatform%02d" % i, center, Vector3(4, 0.6, 4), ORANGE if i % 2 == 0 else TEAL)
		_label("JumpNumber%d" % i, "%02d / %.1f m" % [i + 1, top], center + Vector3(0, 1.0, 0), CREAM, 0.012)
	_box("CourseFinish", Vector3(46, 8.6, 38), Vector3(7, 0.6, 7), ORANGE)
	_label("FinishSign", "FINISH / 8.9 m", Vector3(46, 11, 38), CREAM, 0.02)
	_label("CourseHint", "ASCENDING SWITCHBACKS\nJump · double jump · dive recovery", Vector3(26, 4.5, 45), CREAM, 0.018)

func _slopes() -> void:
	for lane in 3:
		var degrees: float = [12.0, 22.0, 35.0][lane]
		var angle: float = deg_to_rad(degrees)
		var x: float = -16 + lane * 9
		var ramp := _box("SlideRamp%d" % lane, Vector3(x, sin(angle) * 9 - 0.12, -40), Vector3(6, 0.5, 18), BLUE if lane == 0 else TEAL)
		ramp.rotation.x = angle
		ramp.set_meta("floor_class", 1 if lane == 0 else 0)
		_label("SlopeSign%d" % lane, "%d° / %s" % [int(degrees), "SLIPPERY" if lane == 0 else "DEFAULT"], Vector3(x, 2.5, -28), CREAM, 0.016)

func _resize_box(path: String, size: Vector3, at: Vector3) -> void:
	var body: Node3D = get_node(path)
	body.position = at
	(body.get_node("Mesh").mesh as BoxMesh).size = size
	(body.get_node("Collision").shape as BoxShape3D).size = size

func _box(title: String, at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = title
	body.position = at
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_mesh(body, size, color)
	return body

func _paint(at: Vector3, size: Vector3, color: Color) -> void:
	var node := Node3D.new()
	node.position = at
	add_child(node)
	_mesh(node, size, color)

func _mesh(parent: Node3D, size: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)

func _label(title: String, text: String, at: Vector3, color: Color, pixel: float, flat: bool = false) -> void:
	var label := Label3D.new()
	label.name = title
	label.text = text
	label.position = at
	label.font_size = 40
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 4
	label.no_depth_test = false
	if flat:
		label.rotation.x = -PI / 2.0
	else:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
