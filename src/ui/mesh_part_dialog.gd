## A part from a 3D file: choose an STL or an OBJ, see it at LDraw's size
## beside a 1 x 1 brick, size it, turn it upright, put connectors on it with
## a click each, name it and add it to the parts (see [MeshPart]).
##
## From Make a part… ("From a 3D file…") it goes in the parts bin under
## Custom and into the hand. From the minifigure builder's Hair ("Your
## own…") it starts as hair: seated on the head, which shows instead of the
## brick, and "Wear it" puts it on the figure.
##
## The view: drag to turn it, the wheel or a pinch to come closer, and a
## click (a tap) on the part puts the connector chosen on the left there.
## On a phone the view is on top and the controls scroll under it.
class_name MeshPartDialog
extends PanelContainer

## A part was made and is in the library: its id, and whether it is hair.
signal made(part_id: String, hair: bool)
signal closed()

var library: PartLibrary
var colour_code: int = 71
## Opened for a minifigure's hair: it starts as hair and is worn.
var for_hair: bool = false

var part: MeshPart = null

var _picker: MeshFilePicker
var _title: Label
var _status: Label
var _size: SpinBox
var _unit: OptionButton
var _size_words: Label
var _hair: Button
var _tools: Dictionary = {}           ## kind -> its Button
var _tool: String = ""
var _counts: Label
var _name: LineEdit
var _add: Button
var _choose: Button
var _controls: VBoxContainer
var _scroll: ScrollContainer
var _body: BoxContainer

var _frame: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _shape: MeshInstance3D
var _material: StandardMaterial3D
var _beside: MeshInstance3D
var _beside_material: StandardMaterial3D
var _marks: Node3D
var _turn: float = 0.7
var _tilt: float = 0.4
var _reach: float = 160.0
var _centre := Vector3.ZERO
var _pressed_at := Vector2(-1, -1)
var _dragged: bool = false
var _reading: int = -1
var _read: MeshPart = null
## While a change to the part is made on a worker (_work): nothing reads it.
var _busy: bool = false
var _turns: Array[Button] = []
var _filling: bool = false
var _waiting_for: String = ""

## What one click puts, by the words on its button.
const TOOLS: Array[String] = ["stud", "anti-stud", "bar", "bar hole", "pin hole", "hair socket",
	"take off"]
const TOOL_WORDS: Dictionary = {
	"stud": "Stud", "anti-stud": "Anti-stud", "bar": "Bar", "bar hole": "Bar hole",
	"pin hole": "Pin hole", "hair socket": "Hair socket", "take off": "Take off"}
const TOOL_TIPS: Dictionary = {
	"stud": "A stud where you click, facing out of the surface",
	"anti-stud": "A place a stud fits into, where you click: under the part, for it to sit on a stud",
	"bar": "A bar a hand or a clip holds: on a thin stem it runs along the stem, elsewhere it stands out",
	"bar hole": "A hole a bar fits into, going into the part where you click",
	"pin hole": "A Technic pin hole where you click, facing out of the surface",
	"hair socket": "Under the crown of a hair piece: where the head's stud goes in",
	"take off": "Click a connector to take it off"}
const MARK_COLOURS: Dictionary = {
	"stud": Color(1.0, 0.85, 0.2), "tube": Color(0.4, 0.8, 1.0), "shaft": Color(0.5, 1.0, 0.5),
	"bore": Color(1.0, 0.55, 0.3), "pin_hole": Color(0.75, 0.55, 1.0)}


func _ready() -> void:
	visible = false
	_build()
	if library != null:
		library.fetched.connect(_on_fetched)
	get_viewport().size_changed.connect(_arrange)
	if Phone.on():
		_for_a_finger.call_deferred()


## In the layout for a finger, its words in points and every button a
## fingertip each way, as the panels over the model are (TouchSizing): at
## a phone's scale they were 11 units, a tap's target 18 tall.
func _for_a_finger() -> void:
	var touch: Node = get_tree().get_first_node_in_group(TouchSizing.SELF)
	if touch is TouchSizing:
		(touch as TouchSizing).size_panel(self)


## Shown, and the file asked for at once: call straight from the press that
## wanted it, as a browser hands its file chooser only to a click.
func choose_file(hair: bool) -> void:
	for_hair = hair
	HudFront.show_panel(self)
	_arrange()
	if part == null:
		_title.text = "Your own hair from a 3D file" if hair else "A part from a 3D file"
		_status.text = "Choose an STL or an OBJ file."
		_enable(false)
	_picker.ask()


## Shown, with the file at [param path] read, no chooser asked: the
## documentation's pictures open a file this way.
func open_file(path: String, hair: bool) -> void:
	for_hair = hair
	HudFront.show_panel(self)
	_arrange()
	take(FileAccess.get_file_as_bytes(path), path.get_file())


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## A file's bytes, as the picker hands them (and a check does).
func take(bytes: PackedByteArray, file_name: String, extras: Dictionary = {}) -> void:
	_status.text = "Reading %s…" % file_name.get_file()
	_enable(false)
	_read = null
	# Simplifying a file of tens of thousands of triangles takes seconds: on
	# a worker, so the page keeps drawing.
	var hair: bool = for_hair
	_reading = WorkerThreadPool.add_task(func() -> void:
		var read: MeshPart = MeshPart.read(bytes, file_name, extras)
		# Seated on the head here too: 70 to 190 ms, a held window's frames.
		if hair and read != null and read.problem.is_empty():
			read.make_hair()
		_read = read)
	set_process(true)


func _process(_delta: float) -> void:
	if _reading < 0:
		set_process(false)
		return
	if not WorkerThreadPool.is_task_completed(_reading):
		return
	WorkerThreadPool.wait_for_task_completion(_reading)
	_reading = -1
	set_process(false)
	_took(_read)


## Whether a file is being read, or the part changed or made.
func reading() -> bool:
	return _reading >= 0 or _busy


## [param change] made to the part on a worker where there are threads,
## the panel's controls off meanwhile, then shown: seating hair on the head
## is 70 to 190 ms, a held window's frames. A coroutine.
func _work(change: Callable, frame: bool = false) -> void:
	_busy = true
	_enable(false)
	await WorkerTasks.awaited(change, "change a part from a 3D file")
	_busy = false
	_enable(true)
	_refresh()
	if frame:
		_frame_it()


func _took(read: MeshPart) -> void:
	if read == null or not read.problem.is_empty():
		_status.text = read.problem if read != null else "That file could not be read."
		_enable(part != null)
		return
	part = read
	if for_hair:
		colour_code = 6 if colour_code == 71 else colour_code
	_name.text = part.name
	_title.text = "Your own hair: %s" % part.file if for_hair else "A part from %s" % part.file
	_tool = ""
	for kind: String in _tools:
		(_tools[kind] as Button).set_pressed_no_signal(false)
	_enable(true)
	_refresh()
	_frame_it()


func _on_fetched(part_id: String) -> void:
	if part_id == _waiting_for:
		_waiting_for = ""
		_refresh()


# -- building the panel ---------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.99)
	backing.border_color = Color(1, 1, 1, 0.16)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	for side: String in ["left", "right", "top", "bottom"]:
		backing.set("content_margin_" + side, 14)
	add_theme_stylebox_override("panel", backing)
	_picker = MeshFilePicker.new()
	_picker.accept = ".stl,.obj"
	_picker.title = "A part from a 3D file"
	_picker.filter = PackedStringArray(["*.stl, *.obj", "3D files (STL, OBJ)"])
	_picker.native = SaveTo.native
	_picker.picked.connect(take)
	_picker.failed.connect(func(why: String) -> void:
		if why != "no model chosen":
			_status.text = why[0].to_upper() + why.substr(1) + ".")
	add_child(_picker)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.clip_text = true
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_choose = _button(header, "Choose file…", func() -> void: _picker.ask(),
		"Bring in another STL or OBJ file")
	_button(header, "Close", close, "Back without making a part (Escape)")

	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.custom_minimum_size = Vector2(250, 0)
	_body.add_child(_scroll)
	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 8)
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_controls)
	_status = _words(_controls, "", 12)
	_status.modulate = Color(1.0, 0.86, 0.6)

	_words(_controls, "Size: the longest side", 11).modulate = Color(1, 1, 1, 0.7)
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	_controls.add_child(size_row)
	_size = SpinBox.new()
	_size.accessibility_name = "The longest side"
	_size.min_value = 0.1
	_size.max_value = 2000.0
	_size.step = 0.1
	_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size.value_changed.connect(func(value: float) -> void:
		if _filling or part == null or _busy:
			return
		var unit: String = _unit_chosen()
		if part.hair:
			_work(func() -> void: part.set_longest(value, unit))
			return
		part.set_longest(value, unit)
		_refresh())
	size_row.add_child(_size)
	_unit = OptionButton.new()
	_unit.accessibility_name = "Size in"
	for unit: String in MeshPart.UNITS:
		_unit.add_item(unit)
	_unit.item_selected.connect(func(_index: int) -> void:
		if part != null:
			part.unit = _unit_chosen()
			_refresh())
	size_row.add_child(_unit)
	_size_words = _words(_controls, "", 11)
	_size_words.modulate = Color(1, 1, 1, 0.62)

	var turn_row := HFlowContainer.new()
	turn_row.add_theme_constant_override("h_separation", 6)
	_controls.add_child(turn_row)
	_turns = [_button(turn_row, "Turn", func() -> void: _quarter(Vector3.UP),
			"A quarter turn about the upright, to face it the other way"),
		_button(turn_row, "Tip forward", func() -> void: _quarter(Vector3.RIGHT),
			"A quarter turn forward, if it came in lying down"),
		_button(turn_row, "Tip sideways", func() -> void: _quarter(Vector3.BACK),
			"A quarter turn sideways")]
	_hair = _button(_controls, "This is hair", _make_hair,
		"Seat it on a minifigure's head: the inside of its crown on the head's stud, sized "
		+ "like a hair piece if it is not one already")
	_hair.toggle_mode = true

	_words(_controls, "Put on it, one click each", 11).modulate = Color(1, 1, 1, 0.7)
	var tools := GridContainer.new()
	tools.columns = 2
	tools.add_theme_constant_override("h_separation", 6)
	tools.add_theme_constant_override("v_separation", 6)
	_controls.add_child(tools)
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for kind: String in TOOLS:
		var button: Button = _button(tools, TOOL_WORDS[kind], _choose_tool.bind(kind), TOOL_TIPS[kind])
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tools[kind] = button
	_counts = _words(_controls, "", 11)
	_counts.modulate = Color(1, 1, 1, 0.62)

	_words(_controls, "Name", 11).modulate = Color(1, 1, 1, 0.7)
	_name = LineEdit.new()
	_name.accessibility_name = "Name"
	_name.placeholder_text = "My shape"
	_controls.add_child(_name)
	_add = _button(_controls, "Add to parts", _make,
		"Make the part, keep it with your parts, and carry it in every model that uses it")
	_add.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))

	_frame = SubViewportContainer.new()
	_frame.accessibility_name = "The part, and a 1 x 1 brick for its size"
	_frame.stretch = true
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.custom_minimum_size = Vector2(300, 260)
	_frame.gui_input.connect(_on_view_input)
	_body.add_child(_frame)
	_build_view()
	_enable(false)


func _words(row: Container, text: String, font: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font)
	row.add_child(label)
	return label


func _button(row: Container, text: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	row.add_child(button)
	return button


func _build_view() -> void:
	_viewport = SubViewport.new()
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var world := World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.17, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.86, 0.9)
	environment.ambient_light_energy = BrickWorld.light_energy(0.55)
	world.environment = environment
	_viewport.world_3d = world
	_frame.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_camera.near = 1.0
	_camera.far = 6000.0
	_viewport.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	key.light_energy = BrickWorld.light_energy(1.0)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
	fill.light_energy = BrickWorld.light_energy(0.45)
	_viewport.add_child(fill)
	_material = StandardMaterial3D.new()
	_material.roughness = 0.35
	_shape = MeshInstance3D.new()
	_shape.material_override = _material
	_viewport.add_child(_shape)
	_beside_material = StandardMaterial3D.new()
	_beside_material.roughness = 0.4
	_beside = MeshInstance3D.new()
	_beside.material_override = _beside_material
	_viewport.add_child(_beside)
	_marks = Node3D.new()
	_viewport.add_child(_marks)


# -- what it shows --------------------------------------------------------------------


func _enable(on: bool) -> void:
	for control: Control in [_size, _unit, _hair, _name, _add] + _turns:
		if control is BaseButton:
			(control as BaseButton).disabled = not on
		elif control is LineEdit:
			(control as LineEdit).editable = on
		elif control is SpinBox:
			(control as SpinBox).editable = on
	for kind: String in _tools:
		(_tools[kind] as Button).disabled = not on
	_add.text = "Wear it" if for_hair else "Add to parts"


func _unit_chosen() -> String:
	return _unit.get_item_text(maxi(_unit.selected, 0))


func _refresh() -> void:
	if part == null or _busy:
		return
	_filling = true
	var at: int = MeshPart.UNITS.keys().find(part.unit)
	_unit.select(maxi(at, 0))
	_size.step = 0.01 if part.unit == "studs" else 0.1
	_size.value = snappedf(part.longest(part.unit), _size.step)
	_filling = false
	_hair.set_pressed_no_signal(part.hair)
	_tools["hair socket"].visible = part.hair or for_hair
	_size_words.text = part.size_words()
	var said := PackedStringArray()
	if not part.note.is_empty():
		said.append(part.note)
	if part.hair:
		said.append("Seated on a minifigure's head." if part.head_inside <= 0.02 else
			"The head goes into it in places (%d%%): make it a little larger, or put the hair socket by hand."
			% roundi(part.head_inside * 100.0))
	_status.text = " ".join(said)
	var made: Dictionary = part.placed()
	var count: int = (made["connectors"] as Array).size() + (made["studs"] as Array).size() \
		+ (made["bars"] as Array).size()
	_counts.text = "%s · %s" % [Counted.of(part.triangles.size() / 3, "triangle"),
		"no connectors yet" if count == 0 else Counted.of(count, "connector")]
	_show()


func _show() -> void:
	var points: PackedVector3Array = part.fitted()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var corners := PackedVector3Array()
	var facing := PackedVector3Array()
	# Flat faces, as the part is drawn: each triangle its own three corners,
	# wound as the engine winds them (LDraw's a, b, c is its a, c, b).
	for t: int in part.triangles.size() / 3:
		var a: Vector3 = points[part.triangles[t * 3]]
		var b: Vector3 = points[part.triangles[t * 3 + 1]]
		var c: Vector3 = points[part.triangles[t * 3 + 2]]
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		corners.append_array([a, c, b])
		facing.append_array([normal, normal, normal])
	arrays[Mesh.ARRAY_VERTEX] = corners
	arrays[Mesh.ARRAY_NORMAL] = facing
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_shape.mesh = mesh
	_material.albedo_color = Color(library.color(colour_code).rgb, 1.0) if library != null \
		else Color(0.6, 0.6, 0.62)
	# Beside it for its size: a 1 x 1 brick standing where it stands, or the
	# head it is worn on.
	var beside: String = "3626c" if part.hair else "3005"
	var mesh_beside: Lbm.PartMesh = library.mesh_for(beside) if library != null else null
	if mesh_beside == null and library != null and library.request_mesh(beside, true):
		_waiting_for = beside
	_beside.visible = mesh_beside != null and not mesh_beside.surfaces.is_empty()
	if _beside.visible:
		_beside.mesh = mesh_beside.surfaces[0]
		var box: AABB = part.box()
		if part.hair:
			_beside.position = Vector3.ZERO
			_beside_material.albedo_color = Color(library.color(14).rgb, 1.0)
		else:
			_beside.position = Vector3(box.end.x + 20.0, box.position.y + 24.0, 0.0)
			_beside_material.albedo_color = Color(library.color(4).rgb, 1.0)
	_mark(made_marks())


## The connectors as the part file will state them, in the app's axes:
## [kind, at, way, radius, length].
func made_marks() -> Array:
	var out: Array = []
	var made: Dictionary = part.placed()
	for c: Array in made["connectors"]:
		out.append([c[0], Vector3(c[2], -c[3], -c[4]), Vector3(c[5], -c[6], -c[7]),
			float(c[9]) if float(c[9]) > 0.0 else 6.0, float(c[8])])
	for stud: Array in made["studs"]:
		var at: Vector3 = stud[0]
		var way: Vector3 = stud[1]
		out.append(["stud", Vector3(at.x, -at.y, -at.z), Vector3(way.x, -way.y, -way.z), 6.0, 4.0])
	for bar: Array in made["bars"]:
		var at: Vector3 = bar[0]
		var way: Vector3 = bar[1]
		out.append(["shaft", Vector3(at.x, -at.y, -at.z), Vector3(way.x, -way.y, -way.z), 4.0,
			float(bar[2])])
	return out


func _mark(marks: Array) -> void:
	for child: Node in _marks.get_children():
		child.queue_free()
	for mark: Array in marks:
		var kind: String = mark[0]
		var at: Vector3 = mark[1]
		var way: Vector3 = (mark[2] as Vector3).normalized()
		var radius: float = mark[3]
		var long: float = maxf(float(mark[4]), 1.2)
		var shown := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
		cylinder.height = long
		cylinder.radial_segments = 24
		shown.mesh = cylinder
		var ink := StandardMaterial3D.new()
		ink.albedo_color = Color(MARK_COLOURS.get(kind, Color.WHITE), 0.8)
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.no_depth_test = true
		shown.material_override = ink
		# The cylinder's Y along the connector's way, from where it starts.
		var y: Vector3 = way
		var x: Vector3 = (Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).cross(y).normalized()
		var basis := Basis(x, y, x.cross(y))
		var start: Vector3 = at
		if kind in ["stud", "tube", "pin_hole"]:
			# A stud stands out of the surface; a hole is marked in it.
			start = at if kind == "stud" else at - way * 0.6
		shown.transform = Transform3D(basis, start + way * long * 0.5)
		_marks.add_child(shown)


func _frame_it() -> void:
	var box: AABB = part.box()
	if part.hair:
		box = box.merge(AABB(Vector3(-13, -24, -13), Vector3(26, 28, 26)))
	elif _beside.visible:
		box = box.merge(AABB(Vector3(box.end.x + 10.0, box.position.y, -10.0), Vector3(20, 28, 20)))
	_centre = box.get_center()
	_reach = maxf(box.size.length() * 2.0, 60.0)
	_aim()


func _aim() -> void:
	_camera.position = _centre + Vector3(sin(_turn) * cos(_tilt), sin(_tilt),
		cos(_turn) * cos(_tilt)) * _reach
	_camera.look_at(_centre, Vector3.UP)


## Laid out for the room: side by side, or the view over the controls on a
## narrow screen.
func _arrange() -> void:
	if _body == null or not is_inside_tree():
		return
	var narrow: bool = get_viewport().get_visible_rect().size.x < 760.0
	var stacked: bool = _body is VBoxContainer
	if narrow == stacked:
		return
	var replacement: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	replacement.add_theme_constant_override("separation", 12)
	replacement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var parent: Node = _body.get_parent()
	parent.add_child(replacement)
	parent.move_child(replacement, _body.get_index())
	for child: Control in [_frame, _scroll] if narrow else [_scroll, _frame]:
		child.reparent(replacement, false)
	_body.queue_free()
	_body = replacement
	_frame.custom_minimum_size = Vector2(0, 240) if narrow else Vector2(300, 260)
	_scroll.custom_minimum_size = Vector2(0, 0) if narrow else Vector2(250, 0)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL


# -- acting ------------------------------------------------------------------------


func _quarter(axis: Vector3) -> void:
	if part == null or _busy:
		return
	if part.hair:
		_work(func() -> void: part.quarter_turn(axis), true)
		return
	part.quarter_turn(axis)
	_refresh()
	_frame_it()


func _make_hair() -> void:
	if part == null or _busy:
		return
	if _hair.button_pressed:
		_work(func() -> void: part.make_hair(), true)
		return
	part.hair = false
	part.guess_fit()
	_refresh()
	_frame_it()


func _choose_tool(kind: String) -> void:
	var button: Button = _tools[kind]
	_tool = kind if button.button_pressed else ""
	if _tool == "hair socket":
		_status.text = "Click the inside of the hair, under its crown, from below: the head's stud goes in there."
	elif not _tool.is_empty():
		_status.text = TOOL_TIPS[kind] + "."


## A click on the part with a connector chosen: the connector there.
func put_at(at: Vector2) -> String:
	if part == null or _tool.is_empty():
		return "Choose what to put on it first."
	var ray: Array = _ray(at)
	var hit: Dictionary = part.pick(ray[0], ray[1])
	if _tool == "take off":
		if hit.is_empty() or not part.take_off(hit["at"]):
			return "There is no connector there to take off."
		_refresh()
		return ""
	if hit.is_empty():
		return "That is beside the part: click on it."
	var why: String = part.put(_tool, hit)
	if why.is_empty():
		_refresh()
		if _tool == "hair socket":
			_frame_it()
	return why


func _make() -> void:
	if part == null or _busy:
		return
	_busy = true
	_enable(false)
	# Another file chosen while this one is made would be what the made
	# part was said to be (its hair or not).
	_choose.disabled = true
	_status.text = "Making the part…"
	var result: Dictionary = await part.make_built(library, _name.text)
	_busy = false
	_enable(true)
	_choose.disabled = false
	if not str(result["problem"]).is_empty():
		_status.text = "It could not be made: %s." % result["problem"]
		return
	made.emit(str(result["id"]), part.hair)
	close()


# -- the view ----------------------------------------------------------------------


func _ray(at: Vector2) -> Array:
	var scale: Vector2 = Vector2(_viewport.size) / _frame.size
	var inside: Vector2 = at * scale
	return [_camera.project_ray_origin(inside), _camera.project_ray_normal(inside)]


func _on_view_input(event: InputEvent) -> void:
	if part == null or _busy:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_reach = maxf(20.0, _reach / 1.12)
			_aim()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_reach = minf(3000.0, _reach * 1.12)
			_aim()
		elif button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				_pressed_at = button.position
				_dragged = false
			else:
				# A press let go where it began is a click: the connector.
				if not _dragged and button.button_index == MOUSE_BUTTON_LEFT and not _tool.is_empty():
					var why: String = put_at(button.position)
					if not why.is_empty():
						_status.text = why
				_pressed_at = Vector2(-1, -1)
		accept_event()
	elif event is InputEventMagnifyGesture:
		_reach = clampf(_reach / (event as InputEventMagnifyGesture).factor, 20.0, 3000.0)
		_aim()
		accept_event()
	elif event is InputEventMouseMotion and _pressed_at.x >= 0.0:
		var motion: InputEventMouseMotion = event
		if motion.position.distance_to(_pressed_at) > 6.0:
			_dragged = true
		if _dragged:
			_turn -= motion.relative.x * 0.01
			_tilt = clampf(_tilt + motion.relative.y * 0.01, -1.4, 1.4)
			_aim()
		accept_event()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# -- for checks ----------------------------------------------------------------------


func view() -> SubViewportContainer:
	return _frame


func picker() -> MeshFilePicker:
	return _picker


## Where a point of the part's space is in the view, in the view's own
## pixels: what a check clicks.
func on_view(point: Vector3) -> Vector2:
	var scale: Vector2 = _frame.size / Vector2(_viewport.size)
	return _camera.unproject_position(point) * scale


func turn_to(turn: float, tilt: float, reach: float = -1.0) -> void:
	_turn = turn
	_tilt = tilt
	if reach > 0.0:
		_reach = reach
	_aim()


func choose_tool(kind: String) -> void:
	(_tools[kind] as Button).button_pressed = true


func controls_by_name() -> Dictionary:
	var named: Dictionary = {"own_part_size": _size, "own_part_unit": _unit, "own_part_hair": _hair,
		"own_part_name": _name, "own_part_add": _add, "own_part_choose": _choose}
	for kind: String in _tools:
		named["own_part_" + kind.replace(" ", "_").replace("-", "_")] = _tools[kind]
	return named
