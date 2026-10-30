## The properties of what is selected, in the left-hand column beside
## the model (PanelStack), under the parts bin and the model tree.
##
## One part: what it is, by LDraw's number and BrickLink's; its colour, by
## LDraw's name and LEGO's and the shops' numbers; where it stands and
## which way it faces, as numbers that can be typed over to move or turn
## it; what it is joined to, which sub-model it is in, and which step of
## the instructions puts it there. Several: how many of what, in which
## colours, how big, and where — moved as one when the numbers change.
##
## Studio and Mecabricks both have this panel, and it is where a part is
## put exactly where it should be: a click and a drag land within a stud,
## and a number lands on it.
class_name Inspector
extends PanelContainer

const WIDE := 252.0

var shell: Shell

var _open: bool = true
var _header: Button
var _arrow: Arrow
var _count: Label
var _body: VBoxContainer
## The body scrolls when the column gives it less room than it needs.
var _scroll: ScrollContainer
var _title: Label
var _ids: Label
var _colour_row: HBoxContainer
var _swatch: ColorRect
var _colour: Label
var _place: GridContainer
var _x: SpinBox
var _y: SpinBox
var _z: SpinBox
var _yaw: SpinBox
## How far it is tipped off the square: its front lifted, its right side
## lifted. Turn alone faced a panel round a dome and could not tip it back
## to the curve.
var _tilt: SpinBox
var _roll: SpinBox
## How far the selection stands turned about the joint it hangs from, off
## square: shown only when it hangs from one (Builder.hinge_angle). Studio's
## hinge tool turns a part about its connection by an angle typed; here J
## turned it 15 degrees at a press, and 8841-1's pan hangs at 66.4.
var _hinge: SpinBox
var _hinge_name: Label
var _hinged: float = 0.0
## Two parts selected: Meet swings the hinges between them so they meet
## (HingeAlign), in the joint row beside Hinge.
var _meet: Button
var _meet_name: Label
var _facts: Label
var _actions: HBoxContainer
## What the model stands on, shown with nothing selected.
var floor_picker: FloorPicker
var _credit: VBoxContainer
var _credit_words: Label
var _credit_link: LinkButton
var _credit_page: String = ""
var _joined_button: Button
var _lock_button: Button
var _hide_button: Button
## Edit, Printed versions…, for one part the LEGO Group printed or put a
## sticker on: under its name, with how many there are.
var _versions_button: Button

## What was last shown, so nothing is redrawn while nothing changes.
var _shown: String = ""
var _looked_at: int = 0
## Where the numbers say the selection is, to work out how far a typed
## number moves it.
var _at: Vector3 = Vector3.ZERO
var _facing: float = 0.0
var _tilted := Vector2.ZERO
## The instructions' steps, worked out once per model state and only when
## asked for: brick id -> step number, and how many steps there are.
var _steps_for: String = ""
var _step_of: Dictionary = {}
var _step_count: int = 0

signal toggled(open: bool)
## Nothing selected, or something again: folded to its header while there
## is nothing to show, its room going to the parts grid (PanelStack).
signal idled(idle: bool)
var _idle: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PanelStack.section_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	column.add_child(head)
	_header = Button.new()
	_header.flat = true
	_header.text = "Properties"
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.focus_mode = Control.FOCUS_NONE
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_theme_font_size_override("font_size", 13)
	_header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_header.tooltip_text = "Fold the properties away, or open them"
	_header.pressed.connect(func() -> void: set_open(not _open))
	head.add_child(_header)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 12)
	_count.modulate = Color(1, 1, 1, 0.6)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_count)
	_arrow = Arrow.new()
	_arrow.custom_minimum_size = Vector2(14, 14)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_arrow)

	# Nothing selected: the model's own properties, which is what it
	# stands on (FloorPicker). Two rows under the header, not the panel's
	# room: an empty Properties gives that to the parts grid (is_idle).
	floor_picker = FloorPicker.new()
	floor_picker.visible = false
	column.add_child(floor_picker)
	var floor_layer: FloorLayer = shell.app.get("_floor")
	floor_picker.picked.connect(func(chosen: ModelFloor) -> void:
		shell.app.call("choose_floor", chosen))
	floor_picker.part_toggled.connect(func(on: bool) -> void:
		shell.app.call("floor_part_of_model", on))
	if floor_layer != null:
		floor_layer.changed.connect(_show_floor)
	# And whose it is, when it is someone else's: who made it, its licence
	# and its page (ModelStore.credit), as the library or the gallery said.
	_credit = VBoxContainer.new()
	_credit.visible = false
	_credit.add_theme_constant_override("separation", 0)
	column.add_child(_credit)
	_credit_words = Label.new()
	_credit_words.add_theme_font_size_override("font_size", 12)
	_credit_words.modulate = Color(1, 1, 1, 0.75)
	_credit_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credit.add_child(_credit_words)
	_credit_link = Look.link("Its page", 12)
	_credit_link.pressed.connect(func() -> void:
		if not _credit_page.is_empty():
			OS.shell_open(_credit_page))
	_credit.add_child(_credit_link)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	_title = _text(14, 0.95)
	_ids = _text(12, 0.7)
	_versions_button = Button.new()
	_versions_button.flat = true
	_versions_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_versions_button.focus_mode = Control.FOCUS_NONE
	_versions_button.add_theme_font_size_override("font_size", 12)
	_versions_button.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	_versions_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_versions_button.tooltip_text = ("Swap it for one of the prints or stickered versions the LEGO "
		+ "Group made of it")
	_versions_button.visible = false
	_versions_button.pressed.connect(func() -> void: shell.run("printed_versions"))
	_body.add_child(_versions_button)
	_colour_row = HBoxContainer.new()
	_colour_row.add_theme_constant_override("separation", 8)
	_body.add_child(_colour_row)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(16, 16)
	_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_colour_row.add_child(_swatch)
	_colour = Label.new()
	_colour.add_theme_font_size_override("font_size", 12)
	_colour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_colour.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_colour.custom_minimum_size = Vector2(WIDE - 46.0, 0)
	_colour_row.add_child(_colour)

	_place = GridContainer.new()
	_place.columns = 4
	_place.add_theme_constant_override("h_separation", 6)
	_place.add_theme_constant_override("v_separation", 4)
	_body.add_child(_place)
	_x = _number("X", "Across, in LDU (a stud is 20)")
	_y = _number("Y", "Up from the baseplate, in LDU (a plate is 8)")
	_z = _number("Z", "Front to back, in LDU (a stud is 20)")
	_yaw = _number("Turn", "Which way it faces, in degrees about the vertical")
	_tilt = _number("Tilt", "How far its front is lifted, in degrees, about a level line "
		+ "across it through its middle")
	_roll = _number("Roll", "How far its right side is lifted, in degrees, about a level "
		+ "line front to back through its middle")
	for spin: SpinBox in [_x, _y, _z]:
		spin.value_changed.connect(func(_value: float) -> void: _moved())
	_yaw.value_changed.connect(func(_value: float) -> void: _turned())
	for spin: SpinBox in [_tilt, _roll]:
		spin.value_changed.connect(func(_value: float) -> void: _tipped())
	_hinge = _number("Hinge", "How far it is turned about the hinge, pin, axle or clip it "
		+ "hangs from, in degrees off square: type an angle to swing it there")
	_hinge_name = _place.get_child(_place.get_child_count() - 2)
	_hinge.value_changed.connect(func(_value: float) -> void: _swung())
	_show_hinge(null)
	_meet_name = Label.new()
	_meet_name.text = "Hinges"
	_meet_name.add_theme_font_size_override("font_size", 12)
	_meet_name.modulate = Color(1, 1, 1, 0.7)
	_meet_name.mouse_filter = Control.MOUSE_FILTER_PASS
	_place.add_child(_meet_name)
	_meet = _button("Meet", "Swing the hinges, clips and turntables between the two selected "
		+ "parts so they meet: a ring closes, a wing meets its strut. One step to undo",
		_met)
	_meet.accessibility_name = "Meet"
	_place.add_child(_meet)
	_show_meet(false)

	_facts = _text(12, 0.78)

	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 4)
	_body.add_child(_actions)
	_joined_button = _action("Joined", "Select it and everything joined to it",
		func() -> void: _act(0))
	_lock_button = _action("Lock", "Keep it from being picked out, moved, painted or taken off",
		func() -> void: _act(1))
	_hide_button = _action("Hide", "Hide it, to reach what is behind it   "
		+ shell.key_words("hide"), func() -> void: _act(2))

	shell.builder.selection_changed.connect(func(_n: int) -> void: _refresh(true))
	shell.world.rebuilt.connect(func(_b: int, _c: int, _t: int) -> void: _refresh(true))
	_refresh(true)


func _text(font_size: int, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1, alpha))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDE - 20.0, 0)
	_body.add_child(label)
	return label


func _number(words: String, says: String) -> SpinBox:
	var name := Label.new()
	name.text = words
	name.add_theme_font_size_override("font_size", 12)
	name.modulate = Color(1, 1, 1, 0.7)
	name.tooltip_text = says
	name.mouse_filter = Control.MOUSE_FILTER_PASS
	_place.add_child(name)
	var spin := SpinBox.new()
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.min_value = -100000
	spin.max_value = 100000
	spin.custom_minimum_size = Vector2(76, 0)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.tooltip_text = says
	spin.accessibility_name = words
	spin.accessibility_description = says
	spin.select_all_on_focus = true
	spin.add_theme_font_size_override("font_size", 12)
	spin.get_line_edit().add_theme_font_size_override("font_size", 12)
	_place.add_child(spin)
	return spin


func _action(words: String, says: String, does: Callable) -> Button:
	var button: Button = _button(words, says, does)
	_actions.add_child(button)
	return button


func _button(words: String, says: String, does: Callable) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = says
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(1, 1, 1, {"normal": 0.07, "hover": 0.15, "pressed": 0.22}[state])
		face.border_color = Color(1, 1, 1, 0.14)
		face.set_border_width_all(1)
		face.set_corner_radius_all(5)
		face.content_margin_left = 6
		face.content_margin_right = 6
		face.content_margin_top = 2
		face.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, face)
	button.pressed.connect(does)
	return button


## What the three buttons do: for parts, Joined, Lock and Hide; for a
## sub-assembly, Edit inside, Ungroup and Make unique.
var _for_assembly: bool = false


## The panel's buttons are the commands of the same names, timed and said
## on the status bar first when slow, as from the menus (Shell.attend).
func _act(which: int) -> void:
	var verbs: EditVerbs = shell.verbs
	if _for_assembly:
		match which:
			0: shell.attend("enter_assembly", verbs.enter_assembly)
			1: shell.attend("leave_submodel", verbs.leave_submodel)
			2: shell.attend("make_unique", verbs.make_unique)
		return
	match which:
		0: shell.attend("select_connected", verbs.select_connected)
		1: shell.attend("lock", verbs.lock.bind(true))
		2: shell.attend("hide", verbs.hide_selection)


func _buttons_for(assembly: bool) -> void:
	_for_assembly = assembly
	var faces: Array = [["Edit inside", "Work on its parts one by one   Enter, or double-click"],
		["Ungroup", "Take it apart one level   " + shell.key_words("leave_submodel")],
		["Make unique", "Cut this copy loose, so editing it changes no other"]] if assembly \
		else [["Joined", "Select it and everything joined to it"],
		["Lock", "Keep it from being picked out, moved, painted or taken off"],
		["Hide", "Hide it, to reach what is behind it   " + shell.key_words("hide")]]
	for n: int in 3:
		var button: Button = [_joined_button, _lock_button, _hide_button][n]
		button.text = faces[n][0]
		button.tooltip_text = faces[n][1]
		button.disabled = false


func is_open() -> bool:
	return _open


## Open, with nothing selected to show: as tall as its header. An empty
## Properties took 200 px of the column at 1440 x 900, and the parts grid
## had room for two rows (brickworks.diy, 2026-10-12).
func is_idle() -> bool:
	return _open and _idle


func set_open(open: bool) -> void:
	_open = open
	if _body != null:
		_scroll.visible = open and not _idle
		floor_picker.visible = open and _idle
		_arrow.down = open
		_arrow.queue_redraw()
	ShellPrefs.put("inspector_open", open)
	toggled.emit(open)
	_refresh(true)


## A few times a second while open, and at once when the selection or the
## model changes: only redrawn when what it would show differs.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _looked_at < 250:
		return
	_looked_at = now
	_refresh(false)


func _refresh(_now: bool) -> void:
	if shell == null or _body == null:
		return
	var ids: Array = shell.builder.selection.keys()
	var bricks: Array[BrickWorld.Brick] = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = shell.world.get_brick(brick_id)
		if brick != null:
			bricks.append(brick)
	_count.text = "nothing selected" if bricks.is_empty() else (
		"1 part" if bricks.size() == 1 else "%d parts" % bricks.size())
	if bricks.is_empty() != _idle:
		_idle = bricks.is_empty()
		_scroll.visible = _open and not _idle
		floor_picker.visible = _open and _idle
		if _idle:
			_show_floor()
		idled.emit(_idle)
	_show_credit()
	if not _open:
		return
	var state: String = _state_of(bricks)
	if state == _shown:
		return
	_shown = state
	var assembly: String = shell.assemblies.selected_assembly() \
		if shell.assemblies != null and not bricks.is_empty() else ""
	_buttons_for(not assembly.is_empty())
	if bricks.is_empty():
		_show_nothing()
	elif not assembly.is_empty():
		_show_many(bricks)
		_show_assembly(assembly, bricks.size())
	elif bricks.size() == 1:
		_show_one(bricks[0])
	else:
		_show_many(bricks)


func _state_of(bricks: Array[BrickWorld.Brick]) -> String:
	if bricks.size() > 60:
		return "%d|%d" % [bricks.size(), shell.builder.history_depth()]
	var parts := PackedStringArray()
	for brick: BrickWorld.Brick in bricks:
		parts.append("%d %s %d %s %s %s" % [brick.id, brick.part_id, brick.color_code,
			brick.transform, brick.group, shell.builder.is_locked(brick.id)])
	parts.append("%s %s" % [shell.verbs.snap, shell.verbs.turn_step])
	if shell.assemblies != null:
		parts.append(shell.assemblies.selected_assembly())
		parts.append(shell.assemblies.entered)
	return "|".join(parts)


## Whose the model is, with nothing selected: "LDraw model by Roland Dahl,
## CCAL 2.0" and a link to its page, for a model from the library or the
## gallery; nothing for the person's own.
func _show_credit() -> void:
	var credit: Dictionary = shell.store.credit if shell.store != null else {}
	var words: String = ModelBar.credit_words(credit)
	var shown: bool = _open and _idle and not words.is_empty()
	if _credit.visible != shown:
		_credit.visible = shown
	if _credit_words.text != words:
		_credit_words.text = words
		_credit_page = str(credit.get("page", ""))
		_credit_link.visible = not _credit_page.is_empty()
		_credit_link.text = "Its LDraw page" if str(credit.get("from", "")) == ModelLibrary.FROM \
			else "Its page"
		_credit_link.tooltip_text = _credit_page


## The model's floor, in the picker.
func _show_floor() -> void:
	var floor_layer: FloorLayer = shell.app.get("_floor")
	if floor_picker == null or floor_layer == null:
		return
	floor_picker.show_floor(shell.store.model_floor, floor_layer.has_own_plate())


## Nothing selected: the header and what the model stands on (is_idle),
## and the rest of its room the parts grid's. How to select is the Select
## tool's hint.
func _show_nothing() -> void:
	_title.text = ""
	_ids.text = ""
	for control: Control in [_title, _ids, _colour_row, _place, _facts, _actions, _versions_button]:
		control.visible = false
	_show_meet(false)


## How many joined parts the properties count before saying "or more".
const JOINED_MOST := 500


func _show_one(brick: BrickWorld.Brick) -> void:
	var library: PartLibrary = shell.library
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
	_title.visible = true
	_ids.visible = true
	_title.text = Inventory._tidy(info.name) if info != null else brick.part_id
	var custom: bool = library.custom.has(brick.part_id)
	_ids.text = ("Made here · %s" % brick.part_id) if custom else (
		"LDraw %s · BrickLink %s" % [brick.part_id, brick.part_id.trim_suffix(".dat")])
	# A flexible part's skin was drawn by LDCad and came in the file.
	if custom and CustomParts.is_skin_text(library.custom_source(brick.part_id)):
		_ids.text = "Flexible part from the file, as LDCad drew it · %s" % brick.part_id
	var studio: PrintStudio = shell.app.get("_studio") if shell.app != null else null
	var versions: int = studio.versions_of(brick.part_id).size() if studio != null else 0
	_versions_button.visible = versions > 0 and not Stickers.sticks(library, brick.part_id)
	_versions_button.text = "Printed versions… (%d)" % versions
	_show_colours([brick.color_code])
	_place.visible = true
	_actions.visible = true
	_colour_row.visible = true
	_set_place(brick.transform.origin, _yaw_of(brick.transform.basis),
		_tilt_of(brick.transform.basis))
	_show_hinge(shell.builder.hinge_angle())
	_show_meet(false)
	# Counted up to a point: on a big model all of it is joined to all of it.
	var joined: int = SelectBy.connected(shell.world, shell.builder.lattice,
		[brick.id], shell.store.scenery, JOINED_MOST + 1).size() - 1
	var lines := PackedStringArray()
	lines.append("Joined to %s" % ("nothing" if joined <= 0 else (
		"1 other part" if joined == 1 else ("%s other parts, directly or through others"
			% ("%d" % joined if joined < JOINED_MOST else "%d or more" % JOINED_MOST)))))
	lines.append("Faces: studs %s" % _face_of(brick.transform.basis))
	if not brick.group.is_empty():
		lines.append("In %s" % _chain(Assemblies.path_of(brick)))
	var step: String = _step_words(brick.id)
	if not step.is_empty():
		lines.append(step)
	if shell.builder.is_locked(brick.id):
		lines.append("Locked — Shift-L unlocks everything")
	_facts.text = "\n".join(lines)
	_facts.visible = true
	_lock_button.disabled = shell.builder.is_locked(brick.id)


func _show_many(bricks: Array[BrickWorld.Brick]) -> void:
	var library: PartLibrary = shell.library
	_title.visible = true
	_ids.visible = true
	_title.text = "%d parts selected" % bricks.size()
	_versions_button.visible = false
	var kinds: Dictionary = {}
	var colours: Array[int] = []
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in bricks:
		kinds[brick.part_id] = int(kinds.get(brick.part_id, 0)) + 1
		if not colours.has(brick.color_code):
			colours.append(brick.color_code)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh != null:
			var here: AABB = (brick.transform * mesh.bounds).abs()
			box = here if first else box.merge(here)
			first = false
	var most: Array = kinds.keys()
	most.sort_custom(func(a: String, b: String) -> bool: return int(kinds[a]) > int(kinds[b]))
	var lines := PackedStringArray()
	for part_id: String in most.slice(0, 4):
		var info: PartLibrary.PartInfo = library.parts.get(part_id)
		lines.append("%d × %s" % [int(kinds[part_id]),
			Inventory._tidy(info.name) if info != null else part_id])
	if most.size() > 4:
		lines.append("and %d other kinds" % (most.size() - 4))
	_ids.text = "\n".join(lines)
	_show_colours(colours)
	_colour_row.visible = true
	_place.visible = true
	_actions.visible = true
	# The corner the group is measured from: its lowest, leftmost,
	# nearest, so typing a number moves the whole group by the difference.
	_set_place(Vector3(box.position.x, box.position.y, box.position.z), 0.0)
	_show_hinge(shell.builder.hinge_angle())
	_show_meet(bricks.size() == 2)
	_yaw.editable = true
	var facts := PackedStringArray()
	facts.append("%s × %s studs, %s tall" % [_studs(box.size.x), _studs(box.size.z),
		_plates(box.size.y)])
	# The sub-assembly they are all in, when they are; a sub-assembly
	# selected whole says so itself (_show_assembly).
	var shared: String = _shared_path(bricks)
	if not shared.is_empty() and (shell.assemblies == null
			or shell.assemblies.selected_assembly() != shared):
		facts.append("In %s" % _chain(shared))
	facts.append("Turn: by the turn step, %d° a time" % roundi(shell.verbs.turn_step))
	_facts.text = "\n".join(facts)
	_facts.visible = true
	_lock_button.disabled = false


## "Wing (copy 2), in Plane": a place in the tree, innermost first.
static func _chain(path: String) -> String:
	var words := PackedStringArray()
	var at: String = path
	while not at.is_empty():
		words.append(Assemblies.label(at))
		at = Assemblies.parent_of(at)
	return ", in ".join(words)


## The innermost sub-assembly every one of the bricks is in: "" if none.
static func _shared_path(bricks: Array) -> String:
	if bricks.is_empty():
		return ""
	var shared: PackedStringArray = Assemblies.segments(Assemblies.path_of(bricks[0]))
	for brick: BrickWorld.Brick in bricks:
		var own: PackedStringArray = Assemblies.segments(Assemblies.path_of(brick))
		var same: int = 0
		while same < mini(shared.size(), own.size()) and shared[same] == own[same]:
			same += 1
		shared = shared.slice(0, same)
	return "/".join(shared)


## A sub-assembly selected whole: its name, its copies, what is in it.
func _show_assembly(path: String, count: int) -> void:
	var tree: Assemblies = shell.assemblies
	_title.text = Assemblies.label(path)
	var copies: int = tree.copies_of(path).size()
	var inside: int = 0
	for other: String in tree.paths():
		if Assemblies.parent_of(other) == path:
			inside += 1
	var lines := PackedStringArray(["Sub-assembly of %d parts%s" % [count,
		"" if inside == 0 else ", %d inside it" % inside]])
	if copies > 0:
		lines.append("%d other cop%s of %s follow%s it" % [copies, "y" if copies == 1 else "ies",
			Assemblies.definition(Assemblies.leaf(path)), "s" if copies == 1 else ""])
	if not Assemblies.parent_of(path).is_empty():
		lines.append("In %s" % Assemblies.label(Assemblies.parent_of(path)))
	_ids.text = "\n".join(lines) + "\n" + _ids.text
	_hide_button.disabled = copies == 0
	_show_meet(false)


func _show_colours(codes: Array[int]) -> void:
	var library: PartLibrary = shell.library
	var first: PartLibrary.BrickColor = library.color(codes[0])
	_swatch.color = first.rgb
	if codes.size() > 1:
		var names := PackedStringArray()
		for code: int in codes.slice(0, 4):
			names.append(library.color(code).name.replace("_", " "))
		_colour.text = "%d colours: %s%s" % [codes.size(), ", ".join(names),
			"…" if codes.size() > 4 else ""]
		return
	var words: String = "%s (%d)" % [first.name.replace("_", " "), first.code]
	var plain: int = library.plain_code(first.code)
	var lego: String = ""
	if not first.lego_name.is_empty():
		lego = "LEGO® %s%s" % [first.lego_name.replace("_", " "),
			(" %d" % first.lego_ids[0]) if not first.lego_ids.is_empty() else ""]
	var shops := PackedStringArray()
	if library.bricklink_colour(plain) >= 0:
		shops.append("BrickLink %d" % library.bricklink_colour(plain))
	if first.rebrickable_id >= 0:
		shops.append("Rebrickable %d" % first.rebrickable_id)
	_colour.text = words + ("\n" + lego if not lego.is_empty() else "") \
		+ ("\n" + " · ".join(shops) if not shops.is_empty() else "")


func _set_place(at: Vector3, facing: float, tilted := Vector2.ZERO) -> void:
	_at = at
	_facing = facing
	_tilted = tilted
	var across: float = float(EditVerbs.SNAPS[shell.verbs.snap][0])
	var up: float = float(EditVerbs.SNAPS[shell.verbs.snap][1])
	# A step, not none: with no step a box shows every digit the float
	# carries, and a part at 1 read "0.999999818". A hundredth of an LDU
	# shows what is there without snapping a typed number to the studs.
	for pair: Array in [[_x, at.x, across], [_y, at.y, up], [_z, at.z, across]]:
		var spin: SpinBox = pair[0]
		spin.step = 0.01
		spin.custom_arrow_step = float(pair[2])
		spin.set_value_no_signal(snappedf(float(pair[1]), 0.01))
	_yaw.step = 0.1
	_yaw.custom_arrow_step = shell.verbs.turn_step
	_yaw.set_value_no_signal(snappedf(facing, 0.1))
	for pair: Array in [[_tilt, tilted.x], [_roll, tilted.y]]:
		var spin: SpinBox = pair[0]
		spin.step = 0.1
		spin.custom_arrow_step = shell.verbs.turn_step
		spin.set_value_no_signal(snappedf(float(pair[1]), 0.1))


## A number typed or stepped: the selection moved by the difference, to
## the hundredth of an LDU (Builder.move_selection_by), or put back as it
## was and said why. It moved by whole cells only, so a part a set has off
## the 2 LDU lattice could not be typed to where the set has it.
func _moved() -> void:
	var by := Vector3(_x.value, _y.value, _z.value) - _at
	# A box shows its place to the hundredth: what is past that on the axes
	# not typed is the showing's, not a move.
	for n: int in 3:
		if absf(by[n]) <= 0.0051:
			by[n] = 0.0
	if by.length() < 0.005:
		_set_place(_at, _facing, _tilted)
		return
	if shell.builder.move_selection_by(by) > 0:
		shell.verbs.edited.call()
		shell.bar.say("moved to %s, %s, %s" % [_num(_x.value), _num(_y.value), _num(_z.value)])
	else:
		shell.bar.say("no room there")
	_shown = ""
	_refresh(true)


static func _num(value: float) -> String:
	return String.num(snappedf(value, 0.01), 2)


## The Hinge shown, or hidden where the selection hangs from no joint.
func _show_hinge(angle: Variant) -> void:
	_hinge.visible = angle != null
	_hinge_name.visible = angle != null
	_hinged = float(angle) if angle != null else 0.0
	_hinge.step = 0.01
	_hinge.custom_arrow_step = shell.verbs.turn_step if shell != null else 15.0
	_hinge.set_value_no_signal(snappedf(_hinged, 0.01))


## Meet, offered for two parts.
func _show_meet(shown: bool) -> void:
	_meet.visible = shown
	_meet_name.visible = shown


## Meet pressed: the joints between the two selected parts swung so they
## meet, as one step (HingeAlign), or nothing moved and said why. The
## model's bodies as the grab last read them, when that is still the model.
func _met() -> void:
	var ids: Array = shell.builder.selection.keys()
	if ids.size() != 2:
		shell.bar.say("select the two parts that should meet")
		return
	var align := HingeAlign.new()
	align.world = shell.world
	align.builder = shell.builder
	align.library = shell.library
	var drag: Variant = shell.app.get("_grab_drag") if shell.app != null else null
	var bodies: Bodies = (drag as GrabDrag).read_bodies() if drag is GrabDrag else null
	if bodies == null or bodies.revision != shell.world.revision:
		bodies = Bodies.read(shell.world, shell.library, shell.builder.lattice,
			shell.store.scenery if shell.store != null else {}, shell.builder.locked)
	align.bodies = bodies
	if align.solve(int(ids[0]), int(ids[1])) and align.commit() > 0:
		shell.verbs.edited.call()
		shell.bar.say(align.said)
	else:
		shell.bar.say(align.why if not align.why.is_empty() else "they meet where they stand already")
	_shown = ""
	_refresh(true)


## An angle typed in Hinge: the selection swung about its joint by the
## difference, as J swings it (Builder.swing_selection), or put back and
## said why.
func _swung() -> void:
	var by: float = _hinge.value - _hinged
	if absf(by) < 0.005:
		return
	if shell.builder.swing_selection(by) > 0:
		shell.verbs.edited.call()
		shell.bar.say("swung to %s° on its joint" % _num(_hinge.value))
	else:
		shell.bar.say("no room to swing it there, or it hangs from no joint")
	_shown = ""
	_refresh(true)


func _turned() -> void:
	var by: float = _yaw.value - _facing
	if is_zero_approx(by):
		return
	if shell.builder.turn_selection_by(by) > 0:
		shell.verbs.edited.call()
		shell.bar.say("turned %+d°" % roundi(by))
	else:
		shell.bar.say("no room to turn it there")
	_shown = ""
	_refresh(true)


## A tilt or a roll typed or stepped: the selection tipped by the
## difference about its middle, as one step, or put back and said why. The
## same turn a section's pitch and roll make, so a part tipped here reads
## back as one tipped there.
func _tipped() -> void:
	var to := Vector2(_tilt.value, _roll.value)
	if to.is_equal_approx(_tilted):
		return
	var facing: float = _yaw_of_turn()
	var turn: Basis = Assistant.Section.turned(facing, to.x, to.y) \
		* Assistant.Section.turned(facing, _tilted.x, _tilted.y).inverse()
	if shell.builder.turn_selection_basis(turn, "tipped %+d°, rolled %+d°"
			% [roundi(to.x - _tilted.x), roundi(to.y - _tilted.y)]) > 0:
		shell.verbs.edited.call()
		shell.bar.say("tilted %d°, rolled %d°" % [roundi(to.x), roundi(to.y)])
	else:
		shell.bar.say("no room to tip it there")
	_shown = ""
	_refresh(true)


## The yaw the tilt is measured in: the one part's own, off the square, or
## none for a group.
func _yaw_of_turn() -> float:
	var ids: Array = shell.builder.selection.keys()
	if ids.size() != 1:
		return 0.0
	var brick: BrickWorld.Brick = shell.world.get_brick(int(ids[0]))
	if brick == null:
		return 0.0
	var basis: Basis = brick.transform.basis.orthonormalized()
	return Assistant.Section.angles_of(basis * BrickLattice.snap_basis(basis).inverse()).x


## How far a part is tipped off the square, as [tilt, roll] in degrees: its
## turn less the nearest square one, read as a section's pitch and roll.
static func _tilt_of(basis: Basis) -> Vector2:
	var b: Basis = basis.orthonormalized()
	var off: Vector3 = Assistant.Section.angles_of(b * BrickLattice.snap_basis(b).inverse())
	return Vector2(off.y, off.z)


## Which way a part faces about the vertical, in degrees, 0 to 360.
static func _yaw_of(basis: Basis) -> float:
	var x: Vector3 = basis.x
	return fposmod(rad_to_deg(atan2(-x.z, x.x)), 360.0)


## Which way its studs point.
static func _face_of(basis: Basis) -> String:
	var up: Vector3 = basis.y
	if up.y > 0.7:
		return "up"
	if up.y < -0.7:
		return "down"
	return "to the side"


static func _studs(ldu: float) -> String:
	var studs: float = ldu / BrickLattice.STUD
	return str(roundi(studs)) if is_equal_approx(studs, roundf(studs)) else "%.1f" % studs


static func _plates(ldu: float) -> String:
	# A part's box takes in the studs on its top, four LDU proud of it, and
	# nobody counts those in how tall a wall is.
	var body: float = ldu - 4.0 if is_equal_approx(fposmod(ldu, 8.0), 4.0) else ldu
	var plates: float = body / 8.0
	if is_equal_approx(fposmod(plates, 3.0), 0.0) and plates >= 3.0:
		var bricks: int = roundi(plates / 3.0)
		return "1 brick" if bricks == 1 else "%d bricks" % bricks
	return "%s plate%s" % [str(roundi(plates)) if is_equal_approx(plates, roundf(plates))
		else "%.1f" % plates, "" if is_equal_approx(plates, 1.0) else "s"]


## Which step of the instructions puts a brick in, worked out once for the
## model as it stands — and not for a model so big that working it out
## would hold the screen up.
func _step_words(brick_id: int) -> String:
	var count: int = shell.world.brick_count()
	if count > 600:
		return ""
	var key: String = "%d|%d" % [count, shell.builder.history_depth()]
	if key != _steps_for:
		_steps_for = key
		_step_of.clear()
		# The author's steps when there are any, numbered as the booklet is.
		var steps: Array = Instructions.plan(shell.world, shell.library, shell.store.scenery,
			{}, true)
		_step_count = (steps.back() as Instructions.Step).number if not steps.is_empty() else 0
		for n: int in steps.size():
			var step: Instructions.Step = steps[n]
			for id: int in step.brick_ids:
				_step_of[id] = step.number
	if not _step_of.has(brick_id):
		return ""
	return "Step %d of %d in the instructions" % [int(_step_of[brick_id]), _step_count]


func controls_by_name() -> Dictionary:
	if not is_visible_in_tree():
		return {}
	var out: Dictionary = {"properties": _header}
	if _credit.visible and _credit_link.visible:
		out["prop_credit_page"] = _credit_link
	if _open and _versions_button.is_visible_in_tree():
		out["prop_versions"] = _versions_button
	if _open and _place.visible:
		out["prop_x"] = _x
		out["prop_y"] = _y
		out["prop_z"] = _z
		out["prop_turn"] = _yaw
		out["prop_tilt"] = _tilt
		out["prop_roll"] = _roll
		if _hinge.visible:
			out["prop_hinge"] = _hinge
		if _meet.visible:
			out["prop_meet"] = _meet
	return out


## A small triangle, drawn rather than typeset: the font has no arrows.
class Arrow extends Control:
	var down: bool = true

	func _draw() -> void:
		var s: Vector2 = size
		var points: PackedVector2Array
		if down:
			points = PackedVector2Array([Vector2(s.x * 0.2, s.y * 0.35),
				Vector2(s.x * 0.8, s.y * 0.35), Vector2(s.x * 0.5, s.y * 0.72)])
		else:
			points = PackedVector2Array([Vector2(s.x * 0.35, s.y * 0.2),
				Vector2(s.x * 0.72, s.y * 0.5), Vector2(s.x * 0.35, s.y * 0.8)])
		draw_colored_polygon(points, Color(1, 1, 1, 0.7))
