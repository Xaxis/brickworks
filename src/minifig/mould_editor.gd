## Making a mould: sculpting a hair piece, a helmet or something to hold
## into a shape of one's own, its connection to the figure left exactly as
## it was (see [Mould]).
##
## The part in the middle, big: drag on it to sculpt, drag off it (or with
## the right button) to turn it, the wheel to come closer. Brushes down
## the left — pull, push, grow, shrink, smooth, pinch, flatten, grab — with
## a size in LDU and a strength; symmetry, on from the start, makes every
## stroke on both sides; the lattice puts 27 handles round the part to bend
## all of it at once; "Finer" gives the surface more corners where it is
## coarse. What is locked is tinted blue — the inside that rests on the
## head, a socket, a bar — and no brush moves it. "Check walls" marks in red
## where the part is thinner than a millimetre.
##
## By finger (figmould): on a phone the part is over the brushes, which are
## a row of their own, and the rest under them. One finger sculpts on the
## part and turns the view off it; two fingers turn it and pinch to come
## closer. A second finger that comes down while the first is sculpting
## takes the stroke it had begun back: a pinch never dents the part.
##
## Every stroke is one step of Undo, and so are Finer, a lattice handle's
## drag and starting again from another part: Undo past a fresh start goes
## back into the mould begun before it. Up to figmould, Start, Dome and Club
## threw the sculpting away, and Undo after Finer put back fewer corners
## than its triangles named.
##
## Nothing made is lost by closing it, a reload, or the tab going: the mould
## as it is is kept for this tab after every stroke ([member drafts]), and
## Make a mould… in the same slot opens on it again until it is saved.
##
## Start from the part in the slot, any part by number, or a dome (to wear)
## or a club (to hold). "Save mould" makes the part, keeps it, and puts it
## on the figure.
class_name MouldEditor
extends PanelContainer

signal made(ids: Array, slot: String)
signal closed()

## Where the moulds being made are kept, one a slot, or "" for this tab's
## own folder (TabSession): a reload keeps the tab's, and another tab has
## its own. A probe points it at a folder of its own.
static var drafts: String = ""

## How long after a word typed in the name the draft is written.
const DRAFT_AFTER_MS := 400
## Said when the mould as it is could not be kept: the draft before stays.
const NOT_KEPT := "Your mould could not be kept: there is no room on the disk."
## Narrower than this, in the interface's units, the part is over the
## brushes rather than beside them (a phone has 720).
const NARROW := 760.0

var library: PartLibrary
var slot: String = ""
var colour_code: int = 70

var mould: Mould

var _title: Label
var _name: LineEdit
var _from: LineEdit
var _status: Label
var _counts: Label
var _hint: Label
var _tools: Dictionary = {}
var _tool: String = "pull"
var _size: HSlider
var _strength: HSlider
var _symmetry: CheckBox
var _lattice: CheckBox
var _walls: CheckBox
var _save: Button
var _waiting_for: String = ""

# The pieces laid out for a desk or a finger ([method _arrange]).
var _column: VBoxContainer
var _header: HBoxContainer
var _body: HBoxContainer
var _tools_column: VBoxContainer
var _from_words: Label
var _start: Button
var _dome: Button
var _club: Button
var _called: Label
var _close: Button
var _size_words: Label
var _strength_words: Label
var _finer: Button
var _undo_row: HBoxContainer
var _undo_button: Button
var _redo_button: Button
var _separator: HSeparator
var _finger_scroll: ScrollContainer
var _finger: VBoxContainer
var _name_row: HBoxContainer
var _tool_strip: ScrollContainer
var _tool_row: HBoxContainer
var _rows: Array[HBoxContainer] = []
var _narrow: int = -1

var _viewport: SubViewport
var _frame: SubViewportContainer
var _camera: Camera3D
var _body_mesh: MeshInstance3D
var _head: MeshInstance3D
var _ring: MeshInstance3D
var _handles: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _turn: float = 0.6
var _tilt: float = 0.35
var _reach: float = 110.0
var _centre := Vector3.ZERO

var _sculpting: bool = false
var _turning: bool = false
var _handle: int = -1
var _grab_at := Vector3.ZERO
var _grab_plane := Plane()
var _last_dab := Vector3(INF, INF, INF)
var _as_made: Dictionary = {}         ## part id -> its share under 1 mm

## Fingers on the view (touch index -> where), and whether two of them are
## turning it: the first one's own clicks, which the engine makes of it,
## then sculpt nothing until every finger is up.
var _fingers: Dictionary = {}
var _gesture: bool = false
var _gesture_from: Array = []          ## [spread, middle, reach, turn, tilt]

## Moulds begun again from (Start, Dome, Club), the last newest, and those
## undone back out of: Undo past a fresh start goes into the one before it.
var _earlier: Array[Mould] = []
var _later: Array[Mould] = []
## Opened on what was kept: worth keeping before any stroke of this visit.
var _restored: bool = false
var _draft_at: int = 0


func _ready() -> void:
	visible = false
	_build()
	if library != null:
		library.fetched.connect(_on_fetched)
	get_viewport().size_changed.connect(_arrange)
	_arrange()
	if Phone.on():
		_for_a_finger.call_deferred()


## In the layout for a finger, its words in points and every button a
## fingertip each way, as the panels over the model are (TouchSizing).
func _for_a_finger() -> void:
	var touch: Node = get_tree().get_first_node_in_group(TouchSizing.SELF)
	if touch is TouchSizing:
		(touch as TouchSizing).size_panel(self)


## Open on a part: what the slot holds, or the part to start from. A mould
## of the slot's begun before and not saved opens instead, as it was left.
func open(part_id: String, for_slot: String, colour: int) -> void:
	slot = for_slot
	colour_code = colour
	HudFront.show_panel(self)
	_arrange()
	_name.text = ""
	_earlier.clear()
	_later.clear()
	_restored = false
	# What this opening makes starts here: the mould of an opening before
	# (saved, or let go) is no step of this one's Undo, nor kept with it.
	mould = null
	_body_mesh.mesh = null
	var kept: Dictionary = _kept()
	if kept.has("lost"):
		_start_from(part_id)
		if mould != null and _status.text.is_empty():
			_status.text = "Your mould from before could not be read back, so this begins again from %s." \
				% _from.text
		return
	if not kept.is_empty():
		_set_mould(kept["mould"])
		_frame_it()
		_restored = true
		_name.text = str(kept.get("title", ""))
		_from.text = PartPrints.mould_of(library, part_id) if library.parts.has(part_id) \
			and not Mould.sculpts_on(library, part_id) else part_id
		_title.text = "Make a mould from %s" % mould.name
		_status.text = ("Your mould from before, as you left it. Start begins again from %s; "
			+ "Undo goes back to it.") % _from.text
		_show()
		return
	_start_from(part_id)


## Back to the figure. What is being made is kept for next time.
func close() -> void:
	if not visible:
		return
	_keep_draft()
	visible = false
	closed.emit()


func _start_from(part_id: String) -> void:
	var wanted: String = part_id.strip_edges()
	match wanted.to_lower():
		"dome":
			_take(Mould.dome())
			return
		"club":
			_take(Mould.club())
			return
	if not library.parts.has(wanted):
		_status.text = "There is no part %s." % wanted
		return
	if _too_big(wanted):
		return
	# A mould or a 3D file's hair made before is sculpted on further, as it
	# is; saved, it is a new part, and the one before stays as it was.
	if Mould.sculpts_on(library, wanted):
		var own: String = PartPrints.made_title(library.parts[wanted].name)
		_take(Mould.of_made(library, wanted, slot))
		if mould != null and mould.base != wanted:
			_from.text = wanted
			_title.text = "Make a mould from your %s" % own
			_status.text = "Your %s, to shape further. Saved, it is a new part; the one before stays." \
				% own
		return
	wanted = PartPrints.mould_of(library, wanted)
	_from.text = wanted
	if _too_big(wanted):
		return
	if library.mesh_for(wanted) == null and library.request_mesh(wanted, true):
		_status.text = "Fetching %s's geometry…" % wanted
		_waiting_for = wanted
		return
	_take(Mould.of_part(library, wanted, slot))


func _on_fetched(part_id: String) -> void:
	if part_id == _waiting_for:
		_waiting_for = ""
		if not _too_big(part_id):
			_take(Mould.of_part(library, part_id, slot))


## Whether [param part_id] has more triangles than the maker shapes, said
## if it has: it is not opened (Mould.MOST_OPENED). The mould shown stays.
func _too_big(part_id: String) -> bool:
	var faces: int = Mould.triangles_in(library, part_id)
	if faces <= Mould.MOST_OPENED:
		return false
	_status.text = "%s has %s triangles, and the maker shapes parts of up to %s." % [part_id,
		_grouped(faces), _grouped(Mould.MOST_OPENED)]
	return true


## A count with its thousands set apart: 143,996.
static func _grouped(n: int) -> String:
	var digits: String = str(n)
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return digits + out


## A mould begun: the one before it is kept, for Undo to go back into.
func _take(made: Mould) -> void:
	if made == null:
		_status.text = "That part has no geometry to sculpt."
		return
	# Corners enough for a brush to shape, where it is free to.
	made.refine(Mould.FINEST * 2.0)
	made._undo.clear()
	if mould != null:
		_earlier.append(mould)
		_later.clear()
	_set_mould(made)
	_title.text = "Make a mould from %s" % mould.name
	_from.text = mould.base if not mould.name.ends_with("Dome") and not mould.name.ends_with("Club") \
		else mould.name.get_slice(" ", mould.name.get_slice_count(" ") - 1).to_lower()
	_walls.button_pressed = false
	_status.text = ""
	_frame_it()
	_show()
	_keep_draft()


## [param other] in the view in place of the mould shown, its lattice put
## away first.
func _set_mould(other: Mould) -> void:
	_lattice.button_pressed = false
	mould = other
	_head.visible = mould.on_head
	_walls.set_pressed_no_signal(false)
	mould.thickness = PackedFloat32Array()


func _frame_it() -> void:
	var box := AABB(mould.positions[0], Vector3.ZERO)
	for p: Vector3 in mould.positions:
		box = box.expand(p)
	_centre = box.get_center()
	_reach = maxf(box.size.length() * 2.2, 60.0)
	_aim()


# -- kept while it is made -----------------------------------------------------------


func _draft_path() -> String:
	var folder: String = drafts if not drafts.is_empty() else TabSession.path("moulds/")
	return folder.path_join((slot if not slot.is_empty() else "part") + ".draft")


## Whether there is anything of the person's to keep: a stroke, a start
## from another part, words in its name, or a mould opened as it was kept.
func _worth_keeping() -> bool:
	return mould != null and (_restored or mould.can_undo() or not _earlier.is_empty()
		or not _name.text.strip_edges().is_empty())


## The mould as it is, kept for this tab; or nothing kept, when there is
## nothing of the person's in it (a mould opened and closed untouched is not
## brought back over the next part they choose).
func _keep_draft() -> void:
	_draft_at = 0
	if mould == null:
		return
	var path: String = _draft_path()
	if not _worth_keeping():
		_drop_draft()
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	TabSession.writing(path)
	# Written beside it, read back whole, and only then put in its place: a tab
	# closed or a power cut mid-write, or a full disk that takes only part of
	# it, leaves the draft before. Up to figfix a write the disk cut short was
	# moved over the good draft unasked, and the next open let it go
	# (figreview: all the unsaved work lost).
	var bytes: PackedByteArray = var_to_bytes({"mould": mould.to_draft(), "title": _name.text,
		"slot": slot})
	var beside: String = path + ".new"
	var file: FileAccess = FileAccess.open(beside, FileAccess.WRITE)
	var written: bool = file != null and file.store_buffer(bytes)
	if file != null:
		file.close()
	written = written and FileAccess.get_file_as_bytes(beside).size() == bytes.size() \
		and DirAccess.rename_absolute(beside, path) == OK
	if not written:
		if FileAccess.file_exists(beside):
			DirAccess.remove_absolute(beside)
		_status.text = NOT_KEPT
	elif _status.text == NOT_KEPT:
		_status.text = ""


func _keep_draft_soon() -> void:
	_draft_at = Time.get_ticks_msec()


func _drop_draft() -> void:
	var path: String = _draft_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## What was kept for this slot: {mould, title}, or {} when nothing was, or
## {lost: true} when what was is not a whole mould (damaged on the disk, or
## from another build), which is said and set aside as .unread beside it,
## never deleted: a newer build's draft is one this build cannot read.
func _kept() -> Dictionary:
	var path: String = _draft_path()
	if not FileAccess.file_exists(path):
		return {}
	var kept: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path))
	var made: Mould = Mould.from_draft((kept as Dictionary).get("mould")) \
		if kept is Dictionary else null
	if made == null:
		if FileAccess.file_exists(path + ".unread"):
			DirAccess.remove_absolute(path + ".unread")
		if DirAccess.rename_absolute(path, path + ".unread") != OK:
			_drop_draft()
		return {"lost": true}
	return {"mould": made, "title": str((kept as Dictionary).get("title", ""))}


func _process(_delta: float) -> void:
	if _draft_at > 0 and Time.get_ticks_msec() - _draft_at >= DRAFT_AFTER_MS:
		_keep_draft()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED,
			NOTIFICATION_APPLICATION_FOCUS_OUT] and visible:
		_keep_draft()


# -- building the panel --------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.99)
	backing.border_color = Color(1, 1, 1, 0.16)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	for side: String in ["left", "right", "top", "bottom"]:
		backing.set("content_margin_" + side, 14)
	add_theme_stylebox_override("panel", backing)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 8)
	add_child(_column)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 8)
	_column.add_child(_header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.clip_text = true
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title)
	_from_words = Label.new()
	_from_words.text = "Start from"
	_from_words.add_theme_font_size_override("font_size", 12)
	_from_words.modulate = Color(1, 1, 1, 0.7)
	_header.add_child(_from_words)
	_from = LineEdit.new()
	_from.custom_minimum_size = Vector2(110, 0)
	_from.placeholder_text = "3901, dome, club"
	_from.tooltip_text = "A part number, or dome (to wear) or club (to hold)"
	_from.text_submitted.connect(func(text: String) -> void: _start_from(text))
	_header.add_child(_from)
	_start = _button(_header, "Start", func() -> void: _start_from(_from.text),
		"Start again from this part (Undo goes back)")
	_dome = _button(_header, "Dome", func() -> void: _start_from("dome"),
		"A plain cap to wear, with a hair piece's socket")
	_club = _button(_header, "Club", func() -> void: _start_from("club"),
		"A plain bar to hold with a ball on the end, held where a sword is")
	_called = Label.new()
	_called.text = "Name"
	_called.add_theme_font_size_override("font_size", 12)
	_called.modulate = Color(1, 1, 1, 0.7)
	_header.add_child(_called)
	_name = LineEdit.new()
	_name.placeholder_text = "Quiff"
	_name.custom_minimum_size = Vector2(140, 0)
	_name.text_changed.connect(func(_text: String) -> void: _keep_draft_soon())
	_header.add_child(_name)
	_save = _button(_header, "Save mould", _save_mould,
		"Make the part, keep it, and put it on the figure")
	_save.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_close = _button(_header, "Close", close,
		"Back to the figure; the mould is kept as it is for next time (Escape)")

	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_body)
	_tools_column = _build_tools()
	_body.add_child(_tools_column)
	_frame = SubViewportContainer.new()
	_frame.accessibility_name = "The part being shaped"
	_frame.stretch = true
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.custom_minimum_size = Vector2(480, 380)
	_frame.gui_input.connect(_on_view_input)
	_body.add_child(_frame)
	_build_view()
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1.0, 0.86, 0.6)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_status)

	# What only the layout for a finger has, filled by _arrange.
	_name_row = HBoxContainer.new()
	_name_row.add_theme_constant_override("separation", 8)
	_finger_scroll = ScrollContainer.new()
	_finger_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_finger_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_finger = VBoxContainer.new()
	_finger.add_theme_constant_override("separation", 8)
	_finger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finger_scroll.add_child(_finger)
	_tool_strip = ScrollContainer.new()
	_tool_strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tool_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_row = HBoxContainer.new()
	_tool_row.add_theme_constant_override("separation", 4)
	_tool_strip.add_child(_tool_row)
	_finger.add_child(_tool_strip)
	for n: int in 5:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_finger.add_child(row)
		_rows.append(row)
	for spare: Node in [_name_row, _finger_scroll]:
		add_child(spare)
		(spare as Control).visible = false


const NAMES: Dictionary = {"pull": "Pull", "push": "Push", "inflate": "Grow", "shrink": "Shrink",
	"smooth": "Smooth", "pinch": "Pinch", "flatten": "Flatten", "grab": "Grab"}
const TIPS: Dictionary = {
	"pull": "Draw the surface out towards you",
	"push": "Press the surface in",
	"inflate": "Grow it: swell where the brush is, each point straight out",
	"shrink": "Shrink it: slim where the brush is, each point straight in",
	"smooth": "Even out bumps and ridges",
	"pinch": "Draw the surface together into a crease or a ridge",
	"flatten": "Flatten it to the plane under the brush",
	"grab": "Take hold of it and drag it about",
}
const DESK_HINT := ("Drag on the part to sculpt, off it to turn it; wheel to come closer. "
	+ "Blue is its connection, which stays as it is.")
const FINGER_HINT := ("Drag on the part to sculpt, off it to turn it; two fingers turn it, "
	+ "and pinch to come closer. Blue is its connection, which stays as it is.")


func _build_tools() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(170, 0)
	column.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for tool: String in Mould.TOOLS:
		var button := Button.new()
		button.text = NAMES[tool]
		button.tooltip_text = TIPS[tool]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_choose_tool.bind(tool))
		column.add_child(button)
		_tools[tool] = button
	(_tools["pull"] as Button).set_pressed_no_signal(true)
	_separator = HSeparator.new()
	column.add_child(_separator)
	_size_words = _words("Size (LDU)")
	column.add_child(_size_words)
	_size = HSlider.new()
	_size.min_value = 2
	_size.max_value = 24
	_size.value = 7
	_size.focus_mode = Control.FOCUS_NONE
	_size.tooltip_text = "How far the brush reaches, in LDU (2.5 to a millimetre)"
	_size.accessibility_name = "Brush size"
	column.add_child(_size)
	_strength_words = _words("Strength")
	column.add_child(_strength_words)
	_strength = HSlider.new()
	_strength.min_value = 0.05
	_strength.max_value = 1.0
	_strength.step = 0.05
	_strength.value = 0.5
	_strength.focus_mode = Control.FOCUS_NONE
	_strength.accessibility_name = "Brush strength"
	column.add_child(_strength)
	_symmetry = CheckBox.new()
	_symmetry.text = "Symmetry"
	_symmetry.button_pressed = true
	_symmetry.focus_mode = Control.FOCUS_NONE
	_symmetry.tooltip_text = "Every stroke on both sides of the part's middle"
	column.add_child(_symmetry)
	_lattice = CheckBox.new()
	_lattice.text = "Lattice"
	_lattice.focus_mode = Control.FOCUS_NONE
	_lattice.tooltip_text = "27 handles round the part: drag one to bend the whole part"
	_lattice.toggled.connect(_on_lattice)
	column.add_child(_lattice)
	_walls = CheckBox.new()
	_walls.text = "Check walls"
	_walls.focus_mode = Control.FOCUS_NONE
	_walls.tooltip_text = "Mark in red where the part is thinner than 1 mm"
	_walls.toggled.connect(func(on: bool) -> void:
		if mould == null:
			return
		if on:
			var found: Dictionary = mould.walls()
			_status.text = "Thinnest wall %.1f mm; %.0f%% of the surface under 1 mm (red)." % [
				float(found["thinnest"]) * Lbm.LDU_MM, float(found["thin"]) * 100.0]
			# Beside what LEGO made: hair is moulded thin, and 3901 as it
			# comes is mostly under a millimetre itself.
			var as_made: float = _as_made_thin()
			if as_made >= 0.0:
				_status.text += " %s as the LEGO Group made it: %.0f%%." % [mould.base, as_made * 100.0]
		else:
			mould.thickness = PackedFloat32Array()
		_show())
	column.add_child(_walls)
	_finer = _button(column, "Finer", _make_finer,
		"More corners where the surface is coarse, for finer detail (Undo takes it back)")
	_undo_row = HBoxContainer.new()
	column.add_child(_undo_row)
	_undo_button = _button(_undo_row, "Undo", _undo, "")
	Keymap.tell(_undo_button, "Take the last stroke back ({undo})")
	_redo_button = _button(_undo_row, "Redo", _redo, "")
	Keymap.tell(_redo_button, "Put it back ({redo})")
	_counts = Label.new()
	_counts.add_theme_font_size_override("font_size", 11)
	_counts.modulate = Color(1, 1, 1, 0.6)
	_counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_counts)
	_hint = Label.new()
	_hint.text = DESK_HINT
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.modulate = Color(1, 1, 1, 0.55)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	return column


# -- laid out for the room ---------------------------------------------------------------


## Beside each other at a desk; on a phone the part over the brushes, which
## are a row a finger scrolls, and the rest under them. The same controls
## moved, never made again, so each works as it does at a desk.
func _arrange() -> void:
	if _column == null or not is_inside_tree():
		return
	var room: Vector2 = get_viewport().get_visible_rect().size
	var narrow: bool = room.x < NARROW
	if _narrow == int(narrow):
		if narrow:
			_frame.custom_minimum_size = Vector2(0, maxf(220.0, room.y * 0.38))
		return
	_narrow = int(narrow)
	if narrow:
		_put(_title, _header, 0)
		_put(_close, _header, 1)
		_put(_called, _name_row, 0)
		_put(_name, _name_row, 1)
		_put(_save, _name_row, 2)
		_put(_name_row, _column, 1)
		_put(_frame, _column, 2)
		_put(_finger_scroll, _column, 3)
		_column.move_child(_status, -1)
		for tool: String in Mould.TOOLS:
			_put(_tools[tool], _tool_row, _tool_row.get_child_count())
		var rows: Array = [
			[_undo_button, _redo_button, _symmetry, _finer],
			[_size_words, _size],
			[_strength_words, _strength],
			[_lattice, _walls],
			[_from_words, _from, _start, _dome, _club],
		]
		for n: int in rows.size():
			for k: int in (rows[n] as Array).size():
				_put(rows[n][k], _rows[n], k)
		_put(_counts, _finger, _finger.get_child_count())
		_put(_hint, _finger, _finger.get_child_count())
		_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_strength.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_size.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_strength.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_name.custom_minimum_size.x = 0.0
		_from.custom_minimum_size.x = 0.0
		_frame.custom_minimum_size = Vector2(0, maxf(220.0, room.y * 0.38))
		_frame.size_flags_vertical = Control.SIZE_FILL
		_hint.text = FINGER_HINT
		for side: Side in [SIDE_LEFT, SIDE_TOP]:
			set_offset(side, 4)
		for side: Side in [SIDE_RIGHT, SIDE_BOTTOM]:
			set_offset(side, -4)
	else:
		var order: Array = [_title, _from_words, _from, _start, _dome, _club, _called, _name, _save,
			_close]
		for n: int in order.size():
			_put(order[n], _header, n)
		_put(_body, _column, 1)
		_put(_frame, _body, 1)
		var column: Array = []
		for tool: String in Mould.TOOLS:
			column.append(_tools[tool])
		column.append_array([_separator, _size_words, _size, _strength_words, _strength, _symmetry,
			_lattice, _walls, _finer, _undo_row, _counts, _hint])
		for n: int in column.size():
			_put(column[n], _tools_column, n)
		_put(_undo_button, _undo_row, 0)
		_put(_redo_button, _undo_row, 1)
		_column.move_child(_status, -1)
		for flexible: Control in [_name, _from, _size, _strength]:
			flexible.size_flags_horizontal = Control.SIZE_FILL
			flexible.size_flags_vertical = Control.SIZE_FILL
		_name.custom_minimum_size.x = 140.0
		_from.custom_minimum_size.x = 110.0
		_frame.custom_minimum_size = Vector2(480, 380)
		_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_hint.text = DESK_HINT
	_body.visible = not narrow
	_name_row.visible = narrow
	_finger_scroll.visible = narrow
	_separator.visible = not narrow


static func _put(node: Node, parent: Node, index: int) -> void:
	if node.get_parent() != parent:
		node.reparent(parent, false)
	parent.move_child(node, mini(index, parent.get_child_count() - 1))


func _as_made_thin() -> float:
	if mould == null or not library.parts.has(mould.base) or mould.name.ends_with("Dome") \
			or mould.name.ends_with("Club"):
		return -1.0
	if not _as_made.has(mould.base):
		var plain: Mould = Mould.of_part(library, mould.base, slot)
		_as_made[mould.base] = float(plain.walls()["thin"]) if plain != null else -1.0
	return float(_as_made[mould.base])


func _words(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
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
	_camera.far = 3000.0
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
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.35
	_body_mesh = MeshInstance3D.new()
	_body_mesh.material_override = _material
	_viewport.add_child(_body_mesh)
	# The head it is worn on, faint, so the fit can be seen.
	_head = MeshInstance3D.new()
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(0.95, 0.8, 0.2, 0.35)
	head_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_head.material_override = head_material
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 12.6
	head_mesh.bottom_radius = 13.0
	head_mesh.height = 24.0
	_head.mesh = head_mesh
	_head.position = Vector3(0, -12.0, 0)
	_head.visible = false
	_viewport.add_child(_head)
	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.92
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 32
	_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.92, 0.55)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.no_depth_test = true
	_ring.material_override = ring_material
	_ring.visible = false
	_viewport.add_child(_ring)


# -- showing it ---------------------------------------------------------------------


func _show() -> void:
	if mould == null:
		return
	_body_mesh.mesh = mould.mesh()
	var colour: PartLibrary.BrickColor = library.color(colour_code)
	_material.albedo_color = Color(colour.rgb, 1.0)
	_counts.text = "%d triangles · about %d kB in a file" % [mould.triangle_count(),
		mould.triangle_count() * 70 / 1000]
	_place_handles()


func _aim() -> void:
	_camera.position = _centre + Vector3(sin(_turn) * cos(_tilt), sin(_tilt),
		cos(_turn) * cos(_tilt)) * _reach
	_camera.look_at(_centre, Vector3.UP)


func _choose_tool(tool: String) -> void:
	_tool = tool
	(_tools[tool] as Button).set_pressed_no_signal(true)


## A step of the person's begun on the mould shown: what was undone out of,
## past a fresh start, is let go, as a stroke after Undo lets go of Redo.
func _begin_step(whole: bool = false) -> void:
	mould.begin(whole)
	_later.clear()


func _make_finer() -> void:
	if mould == null:
		return
	# Its own step, the corners and triangles as they were (Mould.refine).
	_later.clear()
	var before: int = mould.triangle_count()
	mould.refine(Mould.FINEST)
	if mould.triangle_count() == before:
		# Nothing to split: no step of its own.
		mould._undo.pop_back()
	_show()
	_keep_draft()


func _undo() -> void:
	if mould == null:
		return
	if not mould.undo():
		if _earlier.is_empty():
			return
		_later.append(mould)
		_set_mould(_earlier.pop_back())
		_from.text = mould.base
		_title.text = "Make a mould from %s" % mould.name
	_show()
	_keep_draft()


func _redo() -> void:
	if mould == null:
		return
	if not mould.redo():
		if _later.is_empty():
			return
		_earlier.append(mould)
		_set_mould(_later.pop_back())
		_from.text = mould.base
		_title.text = "Make a mould from %s" % mould.name
	_show()
	_keep_draft()


func _on_lattice(on: bool) -> void:
	for handle: MeshInstance3D in _handles:
		handle.queue_free()
	_handles.clear()
	if mould == null:
		return
	if on:
		mould.lattice_begin()
		var ball := SphereMesh.new()
		ball.radius = 1.4
		ball.height = 2.8
		var ink := StandardMaterial3D.new()
		ink.albedo_color = Color(1.0, 0.6, 0.15)
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.no_depth_test = true
		for n: int in 27:
			var handle := MeshInstance3D.new()
			handle.mesh = ball
			handle.material_override = ink
			_viewport.add_child(handle)
			_handles.append(handle)
		_place_handles()
	else:
		mould.lattice_end()


func _place_handles() -> void:
	if _handles.is_empty() or mould == null:
		return
	var at: PackedVector3Array = mould.lattice_handles()
	for n: int in mini(at.size(), _handles.size()):
		_handles[n].position = at[n]


# -- sculpting by mouse and finger -------------------------------------------------------


## The ray under a point of the view.
func _ray(at: Vector2) -> Array:
	var scale: Vector2 = Vector2(_viewport.size) / _frame.size
	var inside: Vector2 = at * scale
	return [_camera.project_ray_origin(inside), _camera.project_ray_normal(inside)]


func _on_view_input(event: InputEvent) -> void:
	if mould == null:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_fingers[touch.index] = touch.position
		else:
			_fingers.erase(touch.index)
		if _fingers.size() >= 2 and not _gesture:
			_begin_gesture()
		elif _fingers.is_empty():
			_gesture = false
		accept_event()
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if _fingers.has(drag.index):
			_fingers[drag.index] = drag.position
		if _gesture and _fingers.size() >= 2:
			_two_fingers()
		accept_event()
		return
	if event is InputEventMagnifyGesture:
		_reach = clampf(_reach / maxf(0.05, (event as InputEventMagnifyGesture).factor), 20.0, 800.0)
		_aim()
		accept_event()
		return
	if event is InputEventPanGesture:
		var pan: InputEventPanGesture = event
		_turn -= pan.delta.x * 0.05
		_tilt = clampf(_tilt + pan.delta.y * 0.05, -1.4, 1.4)
		_aim()
		accept_event()
		return
	# The first finger's own clicks, while two turn the view.
	if _gesture:
		if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
			_sculpting = false
			_turning = false
			_handle = -1
		accept_event()
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_reach = maxf(20.0, _reach / 1.12)
			_aim()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_reach = minf(800.0, _reach * 1.12)
			_aim()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_turning = button.pressed
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_press(button.position)
			else:
				_release()
		accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _turning:
			_turn -= motion.relative.x * 0.01
			_tilt = clampf(_tilt + motion.relative.y * 0.01, -1.4, 1.4)
			_aim()
		elif _sculpting or _handle >= 0:
			_move(motion.position)
		else:
			_hover(motion.position)
		accept_event()


## A second finger down: what the first had begun is taken back, and the two
## turn the view from here.
func _begin_gesture() -> void:
	if _sculpting or _handle >= 0:
		mould.cancel_stroke()
		_show()
	_sculpting = false
	_turning = false
	_handle = -1
	_ring.visible = false
	_gesture = true
	var two: Array = _fingers.values().slice(0, 2)
	_gesture_from = [maxf(1.0, (two[0] as Vector2).distance_to(two[1])),
		((two[0] as Vector2) + (two[1] as Vector2)) * 0.5, _reach, _turn, _tilt]


## Two fingers: apart or together comes closer or goes back, both moved
## together turn it.
func _two_fingers() -> void:
	var two: Array = _fingers.values().slice(0, 2)
	var spread: float = maxf(1.0, (two[0] as Vector2).distance_to(two[1]))
	var middle: Vector2 = ((two[0] as Vector2) + (two[1] as Vector2)) * 0.5
	var moved: Vector2 = middle - (_gesture_from[1] as Vector2)
	_reach = clampf(float(_gesture_from[2]) * float(_gesture_from[0]) / spread, 20.0, 800.0)
	_turn = float(_gesture_from[3]) - moved.x * 0.01
	_tilt = clampf(float(_gesture_from[4]) + moved.y * 0.01, -1.4, 1.4)
	_aim()


func _press(at: Vector2) -> void:
	var ray: Array = _ray(at)
	if _lattice.button_pressed:
		_handle = _handle_under(at)
		if _handle >= 0:
			_begin_step()
			_grab_plane = Plane(-_camera.global_transform.basis.z,
				mould.lattice_handles()[_handle])
			return
	var hit: Dictionary = mould.pick(ray[0], ray[1])
	if hit.is_empty():
		_turning = true
		return
	_sculpting = true
	if _tool == "grab":
		_grab_at = hit["at"]
		_grab_plane = Plane(-_camera.global_transform.basis.z, _grab_at)
		mould.grab(_grab_at, _size.value, _symmetry.button_pressed)
		_later.clear()
		return
	_begin_step()
	_last_dab = Vector3(INF, INF, INF)
	_dab(hit)


func _move(at: Vector2) -> void:
	var ray: Array = _ray(at)
	if _handle >= 0:
		var to: Variant = _grab_plane.intersects_ray(ray[0], ray[1])
		if to != null:
			mould.lattice_move(_handle, to, _symmetry.button_pressed)
			_show()
		return
	if _tool == "grab":
		var to: Variant = _grab_plane.intersects_ray(ray[0], ray[1])
		if to != null:
			mould.drag((to as Vector3) - _grab_at)
			_show()
		return
	var hit: Dictionary = mould.pick(ray[0], ray[1])
	if not hit.is_empty():
		_dab(hit)
	_hover(at)


## A dab where the brush is, once it has moved a quarter of its size.
func _dab(hit: Dictionary) -> void:
	var at: Vector3 = hit["at"]
	if at.distance_to(_last_dab) < _size.value * 0.25:
		return
	_last_dab = at
	mould.dab(_tool, at, hit["normal"], _size.value, _strength.value, _symmetry.button_pressed)
	_show()


func _release() -> void:
	var stroke: bool = _sculpting or _handle >= 0
	_sculpting = false
	_turning = false
	_handle = -1
	mould.let_go()
	if _walls.button_pressed:
		mould.walls()
		_show()
	if stroke:
		_keep_draft()


func _hover(at: Vector2) -> void:
	var ray: Array = _ray(at)
	var hit: Dictionary = mould.pick(ray[0], ray[1])
	_ring.visible = not hit.is_empty() and not _lattice.button_pressed
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(normal, up).rotated(Basis.looking_at(normal, up).x, PI * 0.5)
	_ring.transform = Transform3D(basis.scaled(Vector3.ONE * _size.value), hit["at"])


func _handle_under(at: Vector2) -> int:
	var scale: Vector2 = Vector2(_viewport.size) / _frame.size
	var best: int = -1
	var nearest: float = 16.0
	var handles: PackedVector3Array = mould.lattice_handles()
	for n: int in handles.size():
		var seen: Vector2 = _camera.unproject_position(handles[n]) / scale
		if seen.distance_to(at) < nearest:
			nearest = seen.distance_to(at)
			best = n
	return best


# -- saving --------------------------------------------------------------------------


func _save_mould() -> void:
	if mould == null:
		return
	_lattice.button_pressed = false
	var title: String = _name.text.strip_edges()
	if title.is_empty():
		title = "My Mould"
	_status.text = "Building the mould…"
	_save.disabled = true
	# Said before the build starts, which in a browser takes a few seconds.
	await get_tree().process_frame
	await get_tree().process_frame
	var result: Dictionary = mould.make(library, title)
	_save.disabled = false
	if not str(result["problem"]).is_empty():
		_status.text = "Not saved: %s." % result["problem"]
		_keep_draft()
		return
	_status.text = "Saved as %s." % result["id"]
	# Made: what was kept while it was made is let go, and nothing of it is
	# brought back next time.
	_drop_draft()
	_restored = false
	_earlier.clear()
	_later.clear()
	mould._undo.clear()
	mould._redo.clear()
	_name.text = ""
	_draft_at = 0
	made.emit([result["id"]], slot)
	close()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed:
		return
	if key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif Keymap.action_of(Keymap.accel_of(key)) in ["undo", "redo"] \
			and not (get_viewport().gui_get_focus_owner() is LineEdit):
		if Keymap.action_of(Keymap.accel_of(key)) == "redo":
			_redo()
		else:
			_undo()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


# -- for a check to use as a person would ------------------------------------------------


func view() -> SubViewportContainer:
	return _frame


## Where on the view a point of the part is seen.
func on_view(point: Vector3) -> Vector2:
	var scale: Vector2 = Vector2(_viewport.size) / _frame.size
	return _camera.unproject_position(point) / scale


func turn_to(turn: float, tilt: float, reach: float = -1.0) -> void:
	_turn = turn
	_tilt = tilt
	if reach > 0.0:
		_reach = reach
	_aim()


func reach() -> float:
	return _reach


func choose_tool(tool: String) -> void:
	_choose_tool(tool)


func set_brush(size: float, strength: float) -> void:
	_size.value = size
	_strength.value = strength


## Whether it is laid out for a finger, the part over the brushes.
func laid_narrow() -> bool:
	return _narrow == 1


func controls_by_name() -> Dictionary:
	var named: Dictionary = {"mould_view": _frame, "mould_name": _name, "mould_save": _save,
		"mould_from": _from, "mould_symmetry": _symmetry, "mould_lattice": _lattice,
		"mould_walls": _walls, "mould_close": _close, "mould_dome": _dome, "mould_club": _club,
		"mould_finer": _finer, "mould_start": _start, "mould_undo": _undo_button,
		"mould_redo": _redo_button}
	for tool: String in _tools:
		named["mould_tool_" + tool] = _tools[tool]
	return named
