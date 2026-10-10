## Making a part: pick a family, give it its dimensions, see it, name it.
##
## What a LEGO element designer is asked for, in the terms they are asked
## in: a 2 x 7 brick, a 1 x 5 plate, a 33 degree slope three studs deep. Or
## a part that exists, at another size — start from 3001 and make it a
## 2 x 7. The preview is the part itself, built by [PartForge] from the
## LDraw file the maker wrote, so what turns on screen is what gets placed,
## saved and opened elsewhere.
##
## Nothing here knows how a brick is drawn; [ElementMaker] does. This is
## the controls, the preview, and the sentence that says what the part is
## in millimetres and studs, which is what a designer checks before asking
## for a mould.
class_name ElementDialog
extends PanelContainer

## LDraw units to millimetres.
const MM := 0.4
## Quiet before a change is rebuilt, so dragging a spin box is one build.
const SETTLE_MS := 140

var library: PartLibrary
## The colour the preview is drawn in: the one in hand.
var color_code: int = 4

var _spec := ElementMaker.Spec.new()
var _family: OptionButton
var _from: LineEdit
var _across: SpinBox
var _deep: SpinBox
var _plates: SpinBox
var _run: SpinBox
var _diameter: SpinBox
var _studs: CheckBox
var _angles: HBoxContainer
var _name: LineEdit
var _about: Label
var _add: Button
var _rows: Dictionary = {}          ## what -> its row, shown by family
var _view: SubViewport
var _turntable: Node3D
var _camera: Camera3D
var _material: ShaderMaterial
var _built: PartForge.Result = null
var _dirty_at: int = -1
var _filling: bool = false
var _dragging: bool = false

## A part was made and is in the library, under Custom.
signal made(part_id: String)
signal cancelled

const FAMILIES: Array = [
	["brick", "Brick, plate or tile"],
	["slope", "Slope"],
	["inverted", "Inverted slope"],
	["round", "Round brick, plate or tile"],
]


func _ready() -> void:
	visible = false
	_build()
	set_process(true)


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	backing.content_margin_top = 15
	backing.content_margin_bottom = 15
	add_theme_stylebox_override("panel", backing)

	# The preview and what the part is stay in view, and so does the
	# button: only the controls scroll, when the window is short. The
	# first version scrolled the whole panel and put "Add to parts" below
	# the bottom of a 900-pixel window.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 9)
	add_child(outer)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	outer.add_child(column)

	var title := Label.new()
	title.text = "Make a part"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)
	var lead := Label.new()
	lead.text = ("A new element at any size, drawn as an LDraw part: it goes "
		+ "in the parts bin under Custom, clutches like the real thing, and "
		+ "travels inside any model you save with it.")
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.add_theme_font_size_override("font_size", 11)
	lead.modulate = Color(1, 1, 1, 0.62)
	column.add_child(lead)

	# The preview: the part itself, turning, in the colour in hand.
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(380, 190)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_preview_input)
	column.add_child(frame)
	_view = SubViewport.new()
	_view.transparent_bg = false
	_view.msaa_3d = Viewport.MSAA_4X
	var world := World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.17, 0.20)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.88, 0.94)
	environment.ambient_light_energy = 1.3
	world.environment = environment
	_view.world_3d = world
	frame.add_child(_view)
	_camera = Camera3D.new()
	_camera.near = 1.0
	_camera.far = 20000.0
	_camera.fov = 32.0
	_view.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	key.light_energy = 1.9
	_view.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14.0, 132.0, 0.0)
	fill.light_energy = 0.7
	_view.add_child(fill)
	_turntable = Node3D.new()
	_view.add_child(_turntable)
	_material = ShaderMaterial.new()
	_material.shader = BrickWorld.SHADERS["opaque"]
	_material.set_shader_parameter("linearise", BrickWorld._linearise_colors())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 8)
	scroll.add_child(controls)
	column = controls

	# Start from a part that exists: the resize path.
	var from_row := _row(column, "Resize a part")
	_from = LineEdit.new()
	_from.placeholder_text = "a part number, e.g. 3001"
	_from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_from.text_submitted.connect(func(_t: String) -> void: _start_from(_from.text))
	from_row.add_child(_from)
	var use := Button.new()
	use.text = "Start from it"
	use.pressed.connect(func() -> void: _start_from(_from.text))
	from_row.add_child(use)

	var family_row := _row(column, "Family")
	_family = OptionButton.new()
	for entry: Array in FAMILIES:
		_family.add_item(entry[1])
	_family.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_family.item_selected.connect(func(index: int) -> void:
		if FAMILIES[index][0] != _spec.family:
			# A 3001 made into a slope is not 3001 resized.
			_spec.derived_from = ""
			_from.text = ""
		_spec.family = FAMILIES[index][0]
		if _spec.family == "slope" or _spec.family == "inverted":
			if _spec.deep < 2:
				_spec.deep = 2
			if _spec.plates < 2:
				ElementMaker.use_angle(_spec, 45)
		_show_spec())
	family_row.add_child(_family)

	# Two to a row: five spin boxes stacked one per line were most of
	# the panel's height.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	_across = _number(grid, "across", "Length, studs", 1, ElementMaker.MOST_STUDS)
	_deep = _number(grid, "deep", "Width, studs", 1, ElementMaker.MOST_STUDS)
	_diameter = _number(grid, "diameter", "Diameter, studs", 1, 16)
	_run = _number(grid, "run", "Slope falls over, rows", 1, ElementMaker.MOST_STUDS - 1)
	_plates = _number(grid, "plates", "Height, plates (3 = a brick)", 1,
		ElementMaker.MOST_PLATES)

	var angle_row := _row(column, "LEGO's angles")
	_rows["angles"] = angle_row.get_parent()
	_angles = angle_row
	for angle: int in [33, 45, 65, 75]:
		var button := Button.new()
		button.text = "%d°" % angle
		button.tooltip_text = ("The proportions LEGO's %d degree slope is drawn "
			+ "with in the library") % angle
		button.pressed.connect(func() -> void:
			ElementMaker.use_angle(_spec, angle)
			_show_spec())
		_angles.add_child(button)

	_studs = CheckBox.new()
	_studs.text = "Studs on top (off for a tile)"
	_studs.button_pressed = true
	_studs.toggled.connect(func(on: bool) -> void:
		if not _filling:
			_spec.studs = on
			_changed())
	column.add_child(_studs)

	var name_row := _row(column, "Name")
	_name = LineEdit.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_changed.connect(func(text: String) -> void:
		if not _filling:
			_spec.title = text.strip_edges()
			_changed())
	name_row.add_child(_name)

	_about = Label.new()
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.add_theme_font_size_override("font_size", 12)
	_about.custom_minimum_size = Vector2(0, 52)
	outer.add_child(_about)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void:
		visible = false
		cancelled.emit())
	buttons.add_child(cancel)
	_add = Button.new()
	_add.text = "Add to parts"
	_add.pressed.connect(_make)
	buttons.add_child(_add)


func _row(column: Container, label: String) -> HBoxContainer:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 3)
	column.add_child(holder)
	var words := Label.new()
	words.text = label
	words.add_theme_font_size_override("font_size", 11)
	words.modulate = Color(1, 1, 1, 0.7)
	holder.add_child(words)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	holder.add_child(row)
	return row


func _number(column: Container, field: String, label: String, low: int,
		high: int) -> SpinBox:
	var row := _row(column, label)
	_rows[field] = row.get_parent()
	var box := SpinBox.new()
	box.min_value = low
	box.max_value = high
	box.step = 1
	box.rounded = true
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.value_changed.connect(func(value: float) -> void:
		if _filling:
			return
		_spec.set(field, int(value))
		_changed())
	row.add_child(box)
	return box


## Open, starting from [param part_id] when it is a plain part that can be
## resized, and from a 2 x 4 brick otherwise.
func open(part_id: String = "") -> void:
	visible = true
	if not part_id.is_empty() and _start_from(part_id, true):
		return
	if _built == null:
		_spec = ElementMaker.Spec.new()
		_show_spec()


## Take a library part's family and size, to resize it. Returns whether the
## part is one the maker can make.
func _start_from(part_id: String, quietly: bool = false) -> bool:
	var id: String = part_id.strip_edges().to_lower().trim_suffix(".dat")
	var info: PartLibrary.PartInfo = library.parts.get(id) if library != null else null
	if info == null:
		if not quietly:
			_say("There is no part %s in the library." % id, true)
		return false
	var spec: ElementMaker.Spec = ElementMaker.parse_spec(library.custom_source(id)) \
		if info.custom else ElementMaker.from_part(id, info.name)
	if spec == null:
		if not quietly:
			_say("%s (%s) is not a plain brick, plate, tile, slope or round part, "
				% [id, Inventory._tidy(info.name)]
				+ "so it cannot be resized here. Start from the family instead.", true)
		return false
	if info.custom:
		spec.derived_from = ""
		spec.title = ""
	_spec = spec
	_from.text = id
	_show_spec()
	return true


## Put the spec into the controls, then rebuild.
func _show_spec() -> void:
	_filling = true
	for index: int in FAMILIES.size():
		if FAMILIES[index][0] == _spec.family:
			_family.select(index)
	_across.value = _spec.across
	_deep.value = _spec.deep
	_plates.value = _spec.plates
	_run.value = _spec.run
	_diameter.value = _spec.diameter
	_studs.button_pressed = _spec.studs
	_name.text = _spec.title
	var is_round: bool = _spec.family == "round"
	var sloped: bool = _spec.family == "slope" or _spec.family == "inverted"
	_rows["across"].visible = not is_round
	_rows["deep"].visible = not is_round
	_rows["diameter"].visible = is_round
	_rows["run"].visible = sloped
	_rows["angles"].visible = sloped
	# A brick is named "2 x 7", short side first, and its long side runs
	# along X as the library's do; a slope is as wide as its face and as
	# deep as its back is from its foot.
	(_rows["across"].get_child(0) as Label).text = \
		"Width, studs (along the face)" if sloped else "Length, studs"
	(_rows["deep"].get_child(0) as Label).text = \
		"Depth, studs (back to foot)" if sloped else "Width, studs"
	_filling = false
	_changed()


func _changed() -> void:
	_dirty_at = Time.get_ticks_msec()


func _process(delta: float) -> void:
	if not visible:
		return
	if _dirty_at >= 0 and Time.get_ticks_msec() - _dirty_at >= SETTLE_MS:
		_dirty_at = -1
		_rebuild_shown()
	if not _dragging and _turntable != null:
		_turntable.rotate_y(delta * 0.45)


## Say it is being built, let that be drawn, then build: a large plate is
## a second or more of work on the one thread, and a dialog that goes still
## without a word reads as one that has hung.
func _rebuild_shown() -> void:
	var studs: int = _spec.diameter * _spec.diameter if _spec.family == "round" \
		else _spec.across * _spec.deep
	if studs > 48:
		_say("Building the part…", false)
		_add.disabled = true
		await get_tree().process_frame
		await get_tree().process_frame
	_rebuild()


## Build what the controls say and show it.
func _rebuild() -> void:
	_name.placeholder_text = ElementMaker.title_for(_without_title())
	var problem: String = ElementMaker.problem(_spec)
	if not problem.is_empty():
		_built = null
		_show_mesh(null)
		_say("Not yet: " + problem + ".", true)
		return
	var id: String = ElementMaker.id_for(_spec)
	_built = PartForge.build(ElementMaker.dat(_spec, id), id, {}, true)
	if not _built.problem.is_empty():
		_say("It did not build: " + _built.problem, true)
		_show_mesh(null)
		return
	_show_mesh(_built.mesh)
	_say(describe(_spec, _built), false)


func _without_title() -> ElementMaker.Spec:
	var bare: ElementMaker.Spec = _spec.duplicate()
	bare.title = ""
	return bare


## What the part is, in the units it will be checked in.
static func describe(spec: ElementMaker.Spec, built: PartForge.Result) -> String:
	var size: Vector3 = Vector3(built.bounds_max[0] - built.bounds_min[0],
		built.bounds_max[1] - built.bounds_min[1],
		built.bounds_max[2] - built.bounds_min[2])
	var body: float = spec.plates * ElementMaker.PLATE
	var studs: int = int(built.connector_counts.get("stud", 0))
	var under: int = int(built.connector_counts.get("tube", 0))
	var words: String = "%s — %.1f x %.1f mm, %.1f mm tall without studs. " % [
		Inventory._tidy(ElementMaker.title_for(spec)), size.x * MM, size.z * MM,
		body * MM]
	words += "%d stud%s on top, %d place%s a stud goes in underneath" % [
		studs, "" if studs == 1 else "s", built.sockets.size(),
		"" if built.sockets.size() == 1 else "s"]
	if under > 0:
		words += ", %d tube%s or pin%s" % [under, "" if under == 1 else "s",
			"" if under == 1 else "s"]
	words += "."
	if spec.family == "slope" or spec.family == "inverted":
		var named: int = ElementMaker.named_angle(spec)
		words += " The face is at %.1f°" % ElementMaker.true_angle(spec)
		words += (" — what LEGO calls a %d." % named) if named > 0 else "."
	return words


func _say(text: String, wrong: bool) -> void:
	_about.text = text
	_about.modulate = Color(1.0, 0.62, 0.55) if wrong else Color(1, 1, 1, 0.85)
	_add.disabled = wrong


func _show_mesh(mesh: Lbm.PartMesh) -> void:
	for child: Node in _turntable.get_children():
		child.queue_free()
	if mesh == null:
		return
	var color: PartLibrary.BrickColor = library.color(color_code) if library != null \
		else null
	for n: int in mesh.surfaces.size():
		var holder := MeshInstance3D.new()
		holder.mesh = mesh.surfaces[n]
		var surface: ShaderMaterial = _material.duplicate()
		if color != null:
			surface.set_shader_parameter("tint_override", color.shown)
			surface.set_shader_parameter("finish_override", color.instance_custom)
		holder.material_override = surface
		# Turned about its own middle, not its origin on the top face.
		holder.position = -mesh.bounds.get_center()
		_turntable.add_child(holder)
	var radius: float = maxf(mesh.bounds.size.length() * 0.5, 10.0)
	var direction := Vector3(0.0, 0.55, 1.0).normalized()
	_camera.position = direction * radius * 3.3
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _dragging:
		_turntable.rotate_y((event as InputEventMouseMotion).relative.x * 0.01)


## Make it: into the library, kept, and announced.
func _make() -> void:
	if library == null or not ElementMaker.problem(_spec).is_empty():
		return
	var result: Dictionary = CustomParts.make(library, _spec)
	if not str(result["problem"]).is_empty():
		_say("It was not made: " + str(result["problem"]), true)
		return
	visible = false
	made.emit(str(result["id"]))


## Where a browser test finds the controls (main._tell_page publishes
## them), by the names tools/web/element_flow.mjs clicks.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {
		"element length": _across.get_line_edit(),
		"element width": _deep.get_line_edit(),
		"element height": _plates.get_line_edit(),
		"element add": _add,
	}


## For a probe: the spec on screen and the part it built.
func spec() -> ElementMaker.Spec:
	return _spec


func built() -> PartForge.Result:
	return _built


## Set the controls as a person would, then build at once rather than
## after the pause.
func set_field(field: String, value: Variant) -> void:
	match field:
		"family":
			for index: int in FAMILIES.size():
				if FAMILIES[index][0] == str(value):
					_family.select(index)
					_family.item_selected.emit(index)
		"studs":
			_studs.button_pressed = bool(value)
		"name":
			_name.text = str(value)
			_name.text_changed.emit(str(value))
		_:
			var box: SpinBox = {"across": _across, "deep": _deep, "plates": _plates,
				"run": _run, "diameter": _diameter}.get(field)
			if box != null:
				box.value = float(value)
	settle()


func settle() -> void:
	if _dirty_at >= 0:
		_dirty_at = -1
		_rebuild()


## Press "Add to parts", as a person would.
func press_add() -> void:
	if not _add.disabled:
		_add.pressed.emit()


func press_angle(angle: int) -> void:
	for button: Button in _angles.get_children():
		if button.text == "%d°" % angle:
			button.pressed.emit()
	settle()


func start_from(part_id: String) -> bool:
	_from.text = part_id
	var ok: bool = _start_from(part_id)
	settle()
	return ok
