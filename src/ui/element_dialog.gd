## Making a part: pick a family, give it its dimensions, see it, name it.
##
## What a LEGO element designer is asked for, in the terms they are asked
## in: a 2 x 7 brick, a 1 x 5 plate, a 33 degree slope three studs deep. Or
## a part that exists, at another size — start from 3001 and make it a
## 2 x 7 — or changed: start from any part at all and make it longer,
## wider or taller, or take its studs off or put them on, from its own
## geometry ([PartEditor]), so whatever is not changed is as LEGO made it. The preview is the part itself, built by [PartForge] from the
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
var _family_buttons: Dictionary = {}   ## family -> its Button
## "family", making a part of one of the maker's families; or "modify",
## changing a part that exists from its own geometry ([PartEditor]).
var _mode: String = "family"
var _edit: PartEditor.Edit = null
## The size of the part being changed, in studs, plates and studs.
var _source_size := Vector3i.ONE
var _modify_note: Label
var _studs_top: Dictionary = {}        ## "keep", "none", "fill" -> its Button
var _start: Button
## The part whose geometry is on its way, to change once it is here.
var _waiting_for: String = ""
var _from: LineEdit
var _across: SpinBox
var _deep: SpinBox
var _plates: SpinBox
var _run: SpinBox
var _diameter: SpinBox
var _studs: CheckBox
var _sides: Dictionary = {}          ## letter -> its CheckBox
var _rise: SpinBox
var _way: OptionButton
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

## [family, the button's word, what it makes].
const FAMILIES: Array = [
	["brick", "Brick", "A brick, plate or tile; studs on its sides if you want them"],
	["slope", "Slope", "A slope at LEGO's angles or any other"],
	["curved", "Curved", "A curved slope, with flat rows behind the curve if you want them"],
	["inverted", "Inverted", "An inverted slope"],
	["round", "Round", "A round brick, plate or tile"],
	["bracket", "Bracket", "A plate with an upright whose studs face forward"],
	["technic", "Technic", "A Technic brick, one stud wide, with a hole between every two studs"],
]

## The sides a brick's studs can go on, as the checkboxes name them.
const SIDE_LABELS: Array = [["f", "Front"], ["b", "Back"], ["l", "Left"], ["r", "Right"]]


func _ready() -> void:
	visible = false
	_build()
	set_process(true)
	if library != null:
		library.fetched.connect(_on_fetched)
		library.fetch_failed.connect(func(part_id: String, reason: String) -> void:
			if part_id == _waiting_for:
				_waiting_for = ""
				_say("%s's geometry did not arrive: %s" % [part_id, reason], true))


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

	# Start from a part that exists: one of the families, resized; any
	# other, changed from its own geometry.
	var from_row := _row(column, "Start from a part")
	_from = LineEdit.new()
	_from.placeholder_text = "a part number: 3001, 3700, 3062b…"
	_from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_from.text_submitted.connect(func(_t: String) -> void: _start_from(_from.text))
	from_row.add_child(_from)
	_start = Button.new()
	_start.text = "Start from it"
	_start.pressed.connect(func() -> void: _start_from(_from.text))
	from_row.add_child(_start)
	_modify_note = Label.new()
	_modify_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modify_note.add_theme_font_size_override("font_size", 11)
	_modify_note.modulate = Color(1, 0.86, 0.6, 0.9)
	_modify_note.visible = false
	column.add_child(_modify_note)

	# Every family on show, one press each: a menu hid six of the seven.
	var family_holder := VBoxContainer.new()
	family_holder.add_theme_constant_override("separation", 3)
	column.add_child(family_holder)
	var family_words := Label.new()
	family_words.text = "Family"
	family_words.add_theme_font_size_override("font_size", 11)
	family_words.modulate = Color(1, 1, 1, 0.7)
	family_holder.add_child(family_words)
	var family_grid := GridContainer.new()
	family_grid.columns = 4
	family_grid.add_theme_constant_override("h_separation", 4)
	family_grid.add_theme_constant_override("v_separation", 4)
	family_holder.add_child(family_grid)
	var family_group := ButtonGroup.new()
	for index: int in FAMILIES.size():
		var entry: Array = FAMILIES[index]
		var choice := Button.new()
		choice.text = entry[1]
		choice.tooltip_text = entry[2]
		choice.toggle_mode = true
		choice.button_group = family_group
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.pressed.connect(func() -> void: _choose_family(index))
		family_grid.add_child(choice)
		_family_buttons[entry[0]] = choice
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
	_run = _number(grid, "run", "Slope falls over, rows", 1, ElementMaker.MOST_STUDS)
	_plates = _number(grid, "plates", "Height, plates (3 = a brick)", 1,
		ElementMaker.MOST_PLATES)
	_rise = _number(grid, "rise", "Upright, studs", 1, ElementMaker.MOST_RISE)
	var way_row := _row(grid, "The upright")
	_rows["way"] = way_row.get_parent()
	_way = OptionButton.new()
	_way.add_item("hangs down from the plate")
	_way.add_item("stands up from the plate")
	_way.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_way.item_selected.connect(func(index: int) -> void:
		if not _filling:
			_spec.way = "down" if index == 0 else "up"
			_changed())
	way_row.add_child(_way)

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

	# A part being changed keeps its studs, or has them taken off, or put
	# on wherever its top is flat.
	var studs_row := _row(column, "Studs on its top")
	_rows["studs_top"] = studs_row.get_parent()
	var studs_group := ButtonGroup.new()
	for entry: Array in [["keep", "As they are"], ["none", "Take them off"],
			["fill", "Put them on"]]:
		var choice := Button.new()
		choice.text = entry[1]
		choice.toggle_mode = true
		choice.button_group = studs_group
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var way: String = entry[0]
		choice.pressed.connect(func() -> void:
			if _edit != null:
				_edit.studs = way
				_changed())
		studs_row.add_child(choice)
		_studs_top[way] = choice

	# Studs-not-on-top: a brick with studs on its faces, for building a
	# face sideways.
	var sides_row := _row(column, "Studs on its sides")
	_rows["sides"] = sides_row.get_parent()
	for entry: Array in SIDE_LABELS:
		var box := CheckBox.new()
		box.text = entry[1]
		box.tooltip_text = "Studs on the %s face, 10 LDU under the top and every stud down" \
			% str(entry[1]).to_lower()
		box.toggled.connect(func(_on: bool) -> void:
			if not _filling:
				_spec.sides = _sides_ticked()
				_changed())
		sides_row.add_child(box)
		_sides[entry[0]] = box

	var name_row := _row(column, "Name")
	_name = LineEdit.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_changed.connect(func(text: String) -> void:
		if not _filling:
			if _mode == "modify":
				_edit.title = text.strip_edges()
			else:
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
		if _mode == "modify":
			_edit_size(field, int(value))
		else:
			_spec.set(field, int(value))
		_changed())
	row.add_child(box)
	return box


## Open, starting from [param part_id] when it is a plain part that can be
## resized, and from a 2 x 4 brick otherwise. Any other part in hand is
## offered — its number in "Start from a part" — but not started on: a
## 32 x 32 baseplate in hand should not begin rebuilding itself because a
## button was pressed.
func open(part_id: String = "") -> void:
	visible = true
	if not part_id.is_empty() and _start_from(part_id, true):
		return
	if not part_id.is_empty() and library != null and library.parts.has(part_id):
		_from.text = part_id
	if _built == null:
		_mode = "family"
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
		if info.custom else ElementMaker.from_part(id, info.name, info.size.y)
	if spec == null:
		# Not one of the families: changed from its own geometry instead.
		if quietly:
			return false
		_start_modify(id)
		return true
	if info.custom:
		spec.derived_from = ""
		spec.title = ""
	_mode = "family"
	_spec = spec
	_from.text = id
	_show_spec()
	return true


## Change [param part_id] itself. Its geometry may have to be fetched first
## (a browser has only some parts' to hand); the controls wait for it.
func _start_modify(part_id: String) -> void:
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	_from.text = part_id
	if mesh == null:
		if library.request_mesh(part_id, true):
			_waiting_for = part_id
			_say("Fetching %s's geometry…" % part_id, false)
			_add.disabled = true
		else:
			_say("There is no geometry for %s here to change." % part_id, true)
		return
	_mode = "modify"
	_edit = PartEditor.Edit.new()
	_edit.from = part_id
	_source_size = PartEditor.size_of(mesh)
	_show_spec()


func _on_fetched(part_id: String) -> void:
	if part_id == _waiting_for:
		_waiting_for = ""
		_start_modify(part_id)


## A size control changed while changing a part: the part's own size is
## no change at all.
func _edit_size(field: String, value: int) -> void:
	match field:
		"across":
			_edit.length = 0 if value == _source_size.x else value
		"deep":
			_edit.width = 0 if value == _source_size.z else value
		"plates":
			_edit.plates = 0 if value == _source_size.y else value


## Put the spec into the controls, then rebuild.
func _show_spec() -> void:
	if _mode == "modify":
		_show_edit()
		return
	_modify_note.visible = false
	_rows["studs_top"].visible = false
	_studs.visible = true
	_rows["plates"].get_child(0).text = "Height, plates (3 = a brick)"
	_filling = true
	var shown: Button = _family_buttons.get(_spec.family)
	if shown != null:
		shown.set_pressed_no_signal(true)
	_across.value = _spec.across
	_deep.value = _spec.deep
	_plates.value = _spec.plates
	_run.value = _spec.run
	_diameter.value = _spec.diameter
	_rise.value = _spec.rise
	_way.select(0 if _spec.way == "down" else 1)
	_studs.button_pressed = _spec.studs
	for letter: String in _sides:
		(_sides[letter] as CheckBox).button_pressed = _spec.sides.contains(letter)
	_name.text = _spec.title
	var family: String = _spec.family
	var is_round: bool = family == "round"
	var sloped: bool = family == "slope" or family == "inverted" or family == "curved"
	_rows["across"].visible = not is_round
	_rows["deep"].visible = not is_round and family != "technic"
	_rows["diameter"].visible = is_round
	_rows["run"].visible = sloped
	_rows["angles"].visible = family == "slope" or family == "inverted"
	_rows["plates"].visible = family != "bracket" and family != "technic"
	_rows["rise"].visible = family == "bracket"
	_rows["way"].visible = family == "bracket"
	_rows["sides"].visible = family == "brick"
	# A brick is named "2 x 7", short side first, and its long side runs
	# along X as the library's do; a slope is as wide as its face and as
	# deep as its back is from its foot; a bracket's plate as wide as its
	# upright.
	(_rows["across"].get_child(0) as Label).text = \
		"Width, studs (along the face)" if sloped \
		else ("Width, studs (along the upright)" if family == "bracket" else "Length, studs")
	(_rows["deep"].get_child(0) as Label).text = \
		"Depth, studs (back to foot)" if sloped \
		else ("Plate depth, studs" if family == "bracket" else "Width, studs")
	(_rows["run"].get_child(0) as Label).text = \
		"Curve falls over, rows" if family == "curved" else "Slope falls over, rows"
	_filling = false
	_changed()


## The controls for changing a part: its size in studs and plates, what to
## do with its studs, a name; and what it is, said above them.
func _show_edit() -> void:
	_filling = true
	for family: String in _family_buttons:
		(_family_buttons[family] as Button).set_pressed_no_signal(false)
	_across.value = _edit.length if _edit.length > 0 else _source_size.x
	_deep.value = _edit.width if _edit.width > 0 else _source_size.z
	_plates.value = _edit.plates if _edit.plates > 0 else _source_size.y
	(_studs_top[_edit.studs] as Button).set_pressed_no_signal(true)
	_name.text = _edit.title
	for row: String in _rows:
		_rows[row].visible = row in ["across", "deep", "plates", "studs_top"]
	_studs.visible = false
	(_rows["across"].get_child(0) as Label).text = "Length, studs"
	(_rows["deep"].get_child(0) as Label).text = "Width, studs"
	(_rows["plates"].get_child(0) as Label).text = "Height, plates"
	var info: PartLibrary.PartInfo = library.parts.get(_edit.from)
	_modify_note.text = ("Changing %s, %s, from its own geometry: whatever you do not "
		+ "change stays as LEGO made it. Longer, wider and taller repeat a slice of it; "
		+ "or press a family to make a new part instead.") % [_edit.from,
		Inventory._tidy(info.name) if info != null else ""]
	_modify_note.visible = true
	_filling = false
	_changed()


## A family's button pressed: the spec becomes one of that family, keeping
## what sizes it can.
func _choose_family(index: int) -> void:
	_mode = "family"
	_waiting_for = ""
	if FAMILIES[index][0] != _spec.family:
		# A 3001 made into a slope is not 3001 resized.
		_spec.derived_from = ""
		_from.text = ""
	_spec.family = FAMILIES[index][0]
	_fit_family(_spec)
	_show_spec()


## What a family needs of a spec carried over from another: a slope two
## rows deep, a bracket's plate one plate tall, a Technic brick one stud
## wide and one brick tall, studs on the sides only on a brick that is one.
static func _fit_family(spec: ElementMaker.Spec) -> void:
	match spec.family:
		"slope", "inverted":
			if spec.deep < 2:
				spec.deep = 2
			if spec.plates < 2:
				ElementMaker.use_angle(spec, 45)
			spec.run = mini(spec.run, spec.deep - 1)
		"curved":
			if spec.plates < 2:
				spec.plates = 2
			spec.run = clampi(spec.run, 1, spec.deep)
		"bracket":
			spec.plates = 1
		"technic":
			spec.deep = 1
			spec.plates = 3
	if spec.family != "brick":
		spec.sides = ""
	elif not spec.sides.is_empty() and spec.plates < 3:
		spec.plates = 3


func _sides_ticked() -> String:
	var ticked: String = ""
	for entry: Array in SIDE_LABELS:
		if (_sides[entry[0]] as CheckBox).button_pressed:
			ticked += str(entry[0])
	return ticked


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
	if _mode == "modify":
		studs = int(_across.value) * int(_deep.value)
	if studs > 48:
		_say("Building the part…", false)
		_add.disabled = true
		await get_tree().process_frame
		await get_tree().process_frame
	_rebuild()


## Build what the controls say and show it.
func _rebuild() -> void:
	if _mode == "modify":
		_rebuild_edit()
		return
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


func _rebuild_edit() -> void:
	var info: PartLibrary.PartInfo = library.parts.get(_edit.from)
	var mesh: Lbm.PartMesh = library.mesh_for(_edit.from)
	if info == null or mesh == null:
		_built = null
		_show_mesh(null)
		_say("Not yet: there is no geometry for %s here." % _edit.from, true)
		return
	var bare: PartEditor.Edit = _edit.duplicate()
	bare.title = ""
	_name.placeholder_text = PartEditor.title_for(bare, info.name, _source_size)
	var made: Dictionary = CustomParts.modified_text(library, _edit)
	if not str(made["problem"]).is_empty():
		_built = null
		_show_mesh(null)
		_say("Not yet: " + str(made["problem"]) + ".", true)
		return
	_built = PartForge.build(made["text"], made["id"], {}, true)
	if not _built.problem.is_empty():
		_say("It did not build: " + _built.problem, true)
		_show_mesh(null)
		return
	_show_mesh(_built.mesh)
	_say(describe_modified(_edit, _built), false)


## What a changed part is, and what it kept.
static func describe_modified(edit: PartEditor.Edit, built: PartForge.Result) -> String:
	var size := Vector3(built.bounds_max[0] - built.bounds_min[0],
		built.bounds_max[1] - built.bounds_min[1], built.bounds_max[2] - built.bounds_min[2])
	var counts: Dictionary = {}
	var on_top: int = 0
	for c: Array in built.connectors:
		counts[c[0]] = int(counts.get(c[0], 0)) + 1
		if c[0] == "stud" and float(c[6]) > 0.99:
			on_top += 1
	var aside: int = int(counts.get("stud", 0)) - on_top
	var words: String = "%s — %.1f x %.1f mm, %.1f mm tall with its studs. " % [
		Inventory._tidy(built.name), size.x * MM, size.z * MM, size.y * MM]
	words += "%d stud%s on top" % [on_top, "" if on_top == 1 else "s"]
	if aside > 0:
		words += ", %d on its sides" % aside
	var holes: int = int(counts.get("pin_hole", 0)) + int(counts.get("axle_hole", 0))
	if holes > 0:
		words += ", %d Technic hole%s" % [holes, "" if holes == 1 else "s"]
	var under: int = int(counts.get("tube", 0))
	if under > 0:
		words += ", %d tube%s or pin%s underneath" % [under, "" if under == 1 else "s",
			"" if under == 1 else "s"]
	# Said plainly: a count of connectors "where they were" counted new holes
	# that landed where old ones had been once the part was put back on its
	# middle, and meant nothing.
	words += ". Everything else about it is %s's own" % edit.from
	return words + "."


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
	var on_top: int = 0
	var aside: int = 0
	for c: Array in built.connectors:
		if c[0] != "stud":
			continue
		# In the app's axes, +Y up: a stud pointing up is on the top.
		if float(c[6]) > 0.99:
			on_top += 1
		else:
			aside += 1
	var under: int = int(built.connector_counts.get("tube", 0))
	var holes: int = int(built.connector_counts.get("pin_hole", 0))
	var words: String = "%s — %.1f x %.1f mm, %.1f mm tall without studs. " % [
		Inventory._tidy(ElementMaker.title_for(spec)), size.x * MM, size.z * MM,
		body * MM]
	words += "%d stud%s on top" % [on_top, "" if on_top == 1 else "s"]
	if aside > 0:
		words += ", %d on %s" % [aside, "the upright" if spec.family == "bracket"
			else "its sides"]
	words += ", %d place%s a stud goes in underneath" % [built.sockets.size(),
		"" if built.sockets.size() == 1 else "s"]
	if under > 0:
		words += ", %d tube%s or pin%s" % [under, "" if under == 1 else "s",
			"" if under == 1 else "s"]
	if holes > 0:
		words += ", %d Technic hole%s a pin goes through" % [holes, "" if holes == 1 else "s"]
	words += "."
	if spec.family == "slope" or spec.family == "inverted":
		var named: int = ElementMaker.named_angle(spec)
		words += " The face is at %.1f°" % ElementMaker.true_angle(spec)
		words += (" — what LEGO calls a %d." % named) if named > 0 else "."
	elif spec.family == "curved":
		words += " The curve leaves the top level and meets its foot at %.1f°." \
			% ElementMaker.true_angle(spec)
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
	if library == null:
		return
	var result: Dictionary = {}
	if _mode == "modify":
		result = CustomParts.make_modified(library, _edit)
	elif not ElementMaker.problem(_spec).is_empty():
		return
	else:
		result = CustomParts.make(library, _spec)
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
	var named: Dictionary = {
		"element length": _across.get_line_edit(),
		"element width": _deep.get_line_edit(),
		"element height": _plates.get_line_edit(),
		"element add": _add,
	}
	for family: String in _family_buttons:
		named["element family " + family] = _family_buttons[family]
	named["element from"] = _from
	named["element start"] = _start
	for way: String in _studs_top:
		if _mode == "modify":
			named["element studs " + way] = _studs_top[way]
	return named


## For a probe: the spec on screen and the part it built.
func spec() -> ElementMaker.Spec:
	return _spec


## What is being changed, when a part is ("modify" mode), else null.
func edit() -> PartEditor.Edit:
	return _edit if _mode == "modify" else null


func built() -> PartForge.Result:
	return _built


## Set the controls as a person would, then build at once rather than
## after the pause.
func set_field(field: String, value: Variant) -> void:
	match field:
		"family":
			for index: int in FAMILIES.size():
				if FAMILIES[index][0] == str(value):
					(_family_buttons[FAMILIES[index][0]] as Button).set_pressed_no_signal(true)
					_choose_family(index)
		"studs":
			_studs.button_pressed = bool(value)
		"sides":
			var wanted: String = ElementMaker.canonical_sides(str(value))
			for letter: String in _sides:
				(_sides[letter] as CheckBox).button_pressed = wanted.contains(letter)
		"way":
			_way.select(0 if str(value) == "down" else 1)
			_way.item_selected.emit(_way.selected)
		"studs_top":
			var choice: Button = _studs_top.get(str(value))
			if choice != null:
				choice.button_pressed = true
				choice.pressed.emit()
		"name":
			_name.text = str(value)
			_name.text_changed.emit(str(value))
		_:
			var box: SpinBox = {"across": _across, "deep": _deep, "plates": _plates,
				"run": _run, "diameter": _diameter, "rise": _rise}.get(field)
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
