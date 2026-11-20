## Edit › Finish the surfaces…: a set designer's finishing pass, for a person
## (finishpass, APP_UX10 #9). The surface pass (SurfacePass) is how a real
## set's finish is laid: tiles where a top should be smooth, slopes where a
## top steps, curved slopes where a body's top edge is hard, a skin on a plain
## flank. The person's Claude reached it (review_model {"surface": true},
## settle_surface); the window did not, and on the MCP walk's g3 (a house
## with a stepped roof, then a finishing pass) the AI got there and a person
## never could.
##
## The bar shows first what the pass will lay, before anything changes: a
## count per kind, each kind's parts drawn as a ghost on the model, and a
## tick per kind to leave it out. Lay puts the ticked kinds down as one undo
## step, and Undo puts the file back byte for byte. The pass itself is
## SurfacePass's, read as the AI's is (find_paced: the same findings, its
## frames given back); this bar only shows, leaves out and lays.
##
## The rules a designer keeps, kept here as each finding is laid:
## - a part that holds a stud something sits on is never taken off for a
##   tile or a slope unless what sat on it is still held after (_holds);
## - nothing laid overlaps or floats: each part is tried where it goes, as
##   the model then stands, with the finding's other parts (SurfacePass
##   ._fits), and a finding that does not fit whole is left as it is;
## - with a selection, only what is on the selected parts is finished.
## A finger reaches all of it: the layout for a finger sizes every target 44
## points or more (TouchSizing.place_panel).
class_name FinishBar
extends PanelContainer

## The kinds a person reads, in the order the bar lists them; each finding
## is one of them (kind_of).
const KINDS: Array[String] = ["tiles", "slopes", "rounds", "sides", "ground"]
## Left out until ticked. The ground a design leaves for its figures is
## offered, not laid, by the pass. Smooth sides swap a side's own bricks for
## others, which changes what the model is made of, not only its finish: the
## person chooses it (self_attack, Defaults).
const OFF_AT_FIRST: Array[String] = ["sides", "ground"]
## A finger's size, in points, on a phone (TouchSizing's).
const FINGER := 44.0

## main.gd: what the bar works on.
var app: Node
## Says a line on the status bar.
var say: Callable = func(_line: String) -> void: pass

## What the pass found, kind -> Array of SurfacePass.Finding, each laid in
## the order the pass gave them; and which kinds are ticked.
var found: Dictionary = {}
var ticked: Dictionary = {}
## Why the pass left some studs as they are, and how many it found past
## what it lays at once (SurfacePass.left_alone, .more).
var left_alone: PackedStringArray = PackedStringArray()
var more: int = 0
## Reading the model or laying: nothing is pressed meanwhile.
var busy: bool = false
## The world's revision the findings were read at: a change since, and they
## are read again before anything is laid.
var read_at: int = -1
## What the last Lay did: {"laid": findings laid, "parts": parts put down,
## "taken": parts taken off, "left": [why each finding was left]}.
var last_laid: Dictionary = {}

var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _scenery: Dictionary = {}
## The assistant the pass reads the model through: one of the bar's own,
## never in the tree, so the person's Claude's own pass (its findings, the
## zones it was told to keep) is left as it is.
var _reader: Assistant = null
var _pass: SurfacePass = null
## Each kind's parts as a ghost on the model.
var _ghosts: Dictionary = {}
var _title: Label
var _status: Label
var _rows: VBoxContainer
var _ticks: Dictionary = {}
var _note: Label
var _lay: Button
var _close: Button
var _reading: int = 0


func _ready() -> void:
	visible = false
	if app != null:
		_world = app.get("_world")
		_builder = app.get("_builder")
		_library = app.get("_library")
		var store: ModelStore = app.get("_store")
		_scenery = store.scenery if store != null else {}
	_build()


# -- for the window and a probe -------------------------------------------------


## Shown, and the model read for what the pass would lay: the selection's
## parts only when there is a selection. Awaited: done when the bar shows it.
func open() -> void:
	visible = true
	await refresh()


func close() -> void:
	_reading += 1
	visible = false
	_ghosts_off()
	busy = false


## What a reading is doing now, for a probe timing its frames: "" when
## nothing, else warm, read, fetch, ghosts.
var phase: String = ""


## Read the model again and show what the pass would lay now. Awaited.
func refresh() -> void:
	if _world == null:
		return
	_reading += 1
	var mine: int = _reading
	busy = true
	found = {}
	left_alone = PackedStringArray()
	more = 0
	_ghosts_off()
	_show()
	var picked: Dictionary = {}
	for id: Variant in _builder.selection:
		if _world.get_brick(int(id)) != null and not _scenery.has(int(id)):
			picked[int(id)] = true
	var revision: int = _world.revision
	var job: Working.Job = Working.begin(tr("Reading the model's studs, steps and edges…"))
	await job.shown()
	_make_pass()
	phase = "warm"
	await _warm(mine)
	phase = "read"
	# The pass's own reading, the AI's, spread over frames (Fiber): on
	# Orthanc it is seconds of work, and the window goes on meanwhile.
	var reading: SurfacePass = _pass
	var fiber_said: Variant = await Fiber.run(func() -> Variant: return reading.find(), _library,
		_fetch, job)
	var findings: Array = fiber_said if fiber_said is Array else []
	phase = "ghosts"
	job.end()
	if mine != _reading or not visible:
		return
	if _world.revision != revision:
		# Changed while it was read: read again, as it stands now.
		busy = false
		await refresh()
		return
	read_at = revision
	left_alone = _pass.left_alone
	more = _pass.more
	for one: SurfacePass.Finding in findings:
		if not picked.is_empty() and not _on_picked(one, picked):
			continue
		var kind: String = kind_of(one)
		if not found.has(kind):
			found[kind] = []
		(found[kind] as Array).append(one)
	for kind: String in KINDS:
		if not ticked.has(kind):
			ticked[kind] = not OFF_AT_FIRST.has(kind)
	# Read only when every kind's ghost is down: a Lay pressed between
	# would lay what was not yet shown on the model.
	await _show_ghosts(mine)
	if mine != _reading:
		return
	busy = false
	phase = ""
	_show()


## Leave a kind out, or put it back.
func set_kind(kind: String, on: bool) -> void:
	ticked[kind] = on
	if _ticks.has(kind):
		(_ticks[kind] as CheckBox).set_pressed_no_signal(on)
	if _ghosts.has(kind):
		(_ghosts[kind] as Node3D).visible = on and visible
	_show_counts()


## How many places and parts each kind would lay: kind -> [places, parts].
func counts() -> Dictionary:
	var out: Dictionary = {}
	for kind: String in found:
		var parts: int = 0
		for one: SurfacePass.Finding in found[kind]:
			parts += one.add.size()
		out[kind] = [(found[kind] as Array).size(), parts]
	return out


## Lay the ticked kinds, as Lay does: one undo step. last_laid says what it
## did; {} when there was nothing to lay. Awaited.
func lay_now() -> Dictionary:
	last_laid = {}
	if busy or _pass == null:
		return {}
	if _builder.is_carrying():
		# What is in hand stays in hand: laid round, it would land in a
		# finish read without it.
		say.call(tr("put down what you are carrying first: nothing was laid"))
		return {}
	if _world.revision != read_at:
		# The model changed since this was shown: shown again, nothing laid.
		say.call(tr("the model changed since the finish was shown: it is shown again"))
		await refresh()
		return {}
	var chosen: Array = []
	for kind: String in KINDS:
		if bool(ticked.get(kind, false)) and found.has(kind):
			chosen.append_array(found[kind])
	if chosen.is_empty():
		say.call(tr("nothing ticked to lay"))
		return {}
	busy = true
	_show()
	var job: Working.Job = Working.begin(tr("Laying the finish…"), chosen.size())
	await job.shown()
	var depth: int = _builder.history_depth()
	var laid: int = 0
	var parts: int = 0
	var taken: int = 0
	var left := PackedStringArray()
	var pace := FramePace.new()
	var done: int = 0
	# Each place's steps, newest first, kept as one step at the end: an edit
	# of the person's made while this goes on is a step of its own, never
	# folded into the finish.
	var places: Array = []
	var seen: int = _world.revision
	for one: SurfacePass.Finding in chosen:
		done += 1
		job.count(done)
		if pace.due():
			await pace.next()
			if _world.revision != seen:
				left.append(tr("the model was changed while it was laid: the rest is left"))
				break
		var why: String = _why_not_laid(one)
		if not why.is_empty():
			left.append(why)
			continue
		var steps: Array = _builder.swap_bricks(PackedInt64Array(one.remove), _adds_of(one))
		seen = _world.revision
		if steps.is_empty():
			continue
		places.push_front({"undo": "group", "steps": steps, "words": "finish"})
		laid += 1
		parts += one.add.size()
		taken += one.remove.size()
	job.end()
	if not places.is_empty():
		_builder.record(places, tr("finished the surfaces: %d parts") % parts)
		if app != null and app.has_method("_on_model_edited"):
			app.call("_on_model_edited")
	last_laid = {"laid": laid, "parts": parts, "taken": taken, "left": Array(left),
		"undone": _builder.history_depth() <= depth}
	busy = false
	if laid > 0 and _builder.history_depth() > depth:
		say.call(Keymap.filled(tr("finished the surfaces: %d parts in %d places — {undo|takes it back}"))
			% [parts, laid])
		close()
	else:
		say.call(tr("nothing laid: %s") % ("; ".join(left) if not left.is_empty()
			else tr("none of it fits as the model stands")))
		await refresh()
	return last_laid


## A finding's kind as the bar lists it.
static func kind_of(one: SurfacePass.Finding) -> String:
	if one.offered:
		return "ground"
	match one.kind:
		"staircase":
			return "slopes"
		"edge":
			return "rounds"
		"flank", "wall":
			return "sides"
	return "tiles"


# -- reading --------------------------------------------------------------------


func _make_pass() -> void:
	if _reader == null:
		_reader = Later.make(&"Assistant")
	_reader.library = _library
	_reader.world = _world
	_reader.builder = _builder
	_reader.scenery = _scenery
	# What the model is called says whether it is a building (straight
	# slopes first, its roof's edges kept) or a body (rounded): the pass
	# reads it off the design's name, and a person's model is its name.
	var bar: Node = app.get("_bar") if app != null else null
	_reader._named_as = str(bar.call("model_name")) if bar != null and bar.has_method("model_name") \
		else ""
	_pass = SurfacePass.new(_reader)


## Whether a finding touches the selected parts only: each part it takes
## off is selected, and each of the model's parts holding one it lays.
func _on_picked(one: SurfacePass.Finding, picked: Dictionary) -> bool:
	var skip: Dictionary = {}
	for id: int in one.remove:
		if not picked.has(id):
			return false
		skip[id] = true
	var held: bool = false
	for raw: Variant in one.add:
		var trial: Dictionary = _pass._read.test(Assistant.Placement.from_dict(raw), skip)
		for by: Variant in trial["held_by"]:
			if int(by) <= 0:
				continue
			if not picked.has(int(by)) and not skip.has(int(by)):
				return false
			held = true
	return held or not skip.is_empty()


## The parts the pass lays, loaded before it reads: read on a fiber, a part
## not loaded reads as none, and the reading is done again once it is.
func _warm(mine: int) -> void:
	var pace := FramePace.new()
	for id: String in _laid_parts():
		if pace.due():
			await pace.next()
			if mine != _reading:
				return
		_library.mesh_for(id)


static func _laid_parts() -> PackedStringArray:
	var out := PackedStringArray()
	for list: Array in [SurfacePass.TILES, SurfacePass.ACCENTS, SurfacePass.STRAIGHT,
			SurfacePass.CURVED, SurfacePass.ROW_PLATES, SurfacePass.FILL_BRICKS,
			SurfacePass.PLATES, SurfacePass.SIDE_STUDS.values(), SurfacePass.FLANK_ONE_WIDE.keys(),
			SurfacePass.FLANK_TWO_WIDE.keys(), SurfacePass.ONE_WIDE_BRICK.values(),
			SurfacePass.SKIN_TILES.values()]:
		for id: Variant in list:
			if not out.has(str(id)):
				out.append(str(id))
	return out


## Parts a reading missed, fetched as a session's design fetches them.
func _fetch(ids: PackedStringArray) -> void:
	phase = "fetch"
	var wanted := Assistant.Model.new()
	for id: String in ids:
		wanted.placements.append(Assistant.Placement.from_dict({"part": id}))
	await _reader._ensure_parts(wanted)
	phase = "read"


# -- laying ---------------------------------------------------------------------


## Why [param one] is not laid as the model now stands, "" when it may be:
## every part it lays fits there with the rest of the finding, the parts it
## takes off are all still there, and whatever sat on a stud of one of them
## is still held after.
func _why_not_laid(one: SurfacePass.Finding) -> String:
	for id: int in one.remove:
		if _world.get_brick(id) == null or _builder.is_locked(id):
			return tr("%s: a part it lays again is gone or locked") % _where(one)
	var skip: Dictionary = {}
	for id: int in one.remove:
		skip[id] = true
	for n: int in one.add.size():
		var others: Array = one.add.slice(0, n) + one.add.slice(n + 1)
		if not _pass._fits(one.add[n], skip, others):
			return tr("%s: no room for it as the model now stands") % _where(one)
	if not _holds(one, skip):
		return tr("%s: what stands on it would be left loose") % _where(one)
	return ""


## Whatever sits on a stud of a part [param one] takes off is still held
## once it is laid: a part holding studs others sit on is never tiled.
func _holds(one: SurfacePass.Finding, skip: Dictionary) -> bool:
	if one.remove.is_empty():
		return true
	var on: Dictionary = {}
	for raw: Variant in _pass._read.points_of(one.remove):
		var point: OpenPoints.Point = raw
		if point.kind == "stud" and point.by > 0 and not skip.has(point.by):
			on[point.by] = true
	for id: Variant in on:
		var placement: Assistant.Placement = _pass._read.by_id.get(int(id))
		if placement == null:
			return false
		var alone: Dictionary = skip.duplicate()
		alone[int(id)] = true
		if not _pass._fits(SurfacePass._as_dict(placement), alone, one.add):
			return false
	return true


## The finding's parts as Builder.swap_bricks puts them down: each where the
## pass placed it, in the sub-model and step a part put down by hand goes in,
## or, where it stands in the place of a part it takes off, that part's.
func _adds_of(one: SurfacePass.Finding) -> Array:
	var out: Array = []
	var gone: Array = []          ## [brick, its box]
	for id: int in one.remove:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id) if brick != null else null
		if mesh != null:
			gone.append([brick, (brick.transform * mesh.bounds).abs()])
	var path: String = _builder.place_group
	var step: int = int(_builder.place_step.call(path)) if _builder.place_step.is_valid() else -1
	for raw: Variant in one.add:
		var placed: Dictionary = raw
		var at: Transform3D = _at(placed)
		var item: Dictionary = {"part": str(placed["part"]), "color": int(placed["color"]),
			"at": at, "path": path, "step": step}
		var mesh: Lbm.PartMesh = _library.mesh_for(str(placed["part"]))
		var middle: Vector3 = (at * mesh.bounds).abs().get_center() if mesh != null else at.origin
		for n: int in gone.size():
			if (gone[n][1] as AABB).grow(0.5).has_point(middle):
				var was: BrickWorld.Brick = gone[n][0]
				item["path"] = Assemblies.path_of(was)
				item["step"] = was.step
				gone.remove_at(n)
				break
		out.append(item)
	return out


## Where a placement of the pass's goes, in the world.
func _at(placed: Dictionary) -> Transform3D:
	var placement := Assistant.Placement.from_dict(placed)
	var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
	var section: Assistant.Section = _pass._read.model.sections.get(placement.section) \
		if not placement.section.is_empty() else null
	return _reader._transform(placement, mesh, section)


func _where(one: SurfacePass.Finding) -> String:
	return "%s %s" % [_kind_words(kind_of(one), 1), SurfacePass._where_said(one.box)]


# -- what it shows ----------------------------------------------------------------


func _show() -> void:
	_lay.disabled = busy or found.is_empty()
	_status.visible = busy or found.is_empty()
	if busy:
		_status.text = tr("Reading the model's studs, steps and edges…")
	elif found.is_empty():
		_status.text = tr("Nothing to finish here: no open stud field, no stud staircase, no hard top edge and no plain flank.") \
			if _builder.selection.is_empty() else tr("Nothing to finish on the selected parts.")
	for kind: String in KINDS:
		(_ticks[kind] as CheckBox).visible = found.has(kind)
		(_ticks[kind] as CheckBox).set_pressed_no_signal(bool(ticked.get(kind, true)))
	_show_counts()
	var notes := PackedStringArray()
	if not _builder.selection.is_empty() and not found.is_empty():
		notes.append(tr("Only what is on the selected parts."))
	if more > 0:
		notes.append(tr("%d more found past what is laid at once: Finish again lays them.") % more)
	if not left_alone.is_empty() and not busy:
		notes.append(tr("Left as studs: %s.") % "; ".join(left_alone.slice(0, 3)))
	_note.text = "\n".join(notes)
	_note.visible = not notes.is_empty()
	_fit_height.call_deferred()


## As tall as what it shows now: a panel grows with its words but never
## shrinks by itself, and the first reading's long words left it over the
## model, its lower half empty. A phone's panel is TouchSizing's.
func _fit_height() -> void:
	if is_inside_tree() and not Phone.on():
		size = Vector2(size.x, 0.0)


func _show_counts() -> void:
	var counted: Dictionary = counts()
	var parts: int = 0
	for kind: String in KINDS:
		var box: CheckBox = _ticks[kind]
		if not counted.has(kind):
			continue
		var places: int = int(counted[kind][0])
		var many: int = int(counted[kind][1])
		box.text = "%s — %s" % [_kind_words(kind, places), _parts_words(many, places)]
		if bool(ticked.get(kind, false)):
			parts += many
	_lay.text = tr("Lay %d parts") % parts if parts > 0 else tr("Lay")
	_lay.disabled = busy or parts == 0


func _kind_words(kind: String, places: int) -> String:
	match kind:
		"tiles":
			return tr("Tiles") if places != 1 else tr("Tile")
		"slopes":
			return tr("Slopes")
		"rounds":
			return tr("Rounded edges")
		"sides":
			return tr("Smooth sides")
	return tr("The ground")


func _parts_words(parts: int, places: int) -> String:
	if places == 1:
		return tr("%d parts in 1 place") % parts if parts != 1 else tr("1 part in 1 place")
	return tr("%d parts in %d places") % [parts, places]


func _ghosts_off() -> void:
	for kind: Variant in _ghosts:
		var ghost: Node3D = _ghosts[kind]
		if is_instance_valid(ghost):
			ghost.queue_free()
	_ghosts = {}


## How many parts one piece of a kind's ghost is made of: a piece is made
## in one go, so on a big model a kind is several, a frame given back
## between them.
const GHOST_PIECE := 12


## Each kind's parts, as one ghost, drawn where they would go: a node per
## kind, its pieces under it, a frame given back between parts on a big
## model.
func _show_ghosts(mine: int) -> void:
	# Begun in a frame of its own: the reading's last turn was this one's.
	await get_tree().process_frame
	if mine != _reading:
		return
	var pace := FramePace.new()
	var strengthen: GDScript = Later.script(&"Strengthen")
	for kind: String in KINDS:
		if not found.has(kind):
			continue
		var holder := Node3D.new()
		holder.visible = bool(ticked.get(kind, true))
		_builder.add_child(holder)
		_ghosts[kind] = holder
		var parts: Array = []
		for one: SurfacePass.Finding in found[kind]:
			for raw: Variant in one.add:
				if pace.due():
					await pace.next()
					if mine != _reading:
						return
				parts.append({"part": str(raw["part"]), "color": int(raw["color"]), "at": _at(raw)})
				if parts.size() >= GHOST_PIECE:
					if pace.due():
						await pace.next()
						if mine != _reading:
							return
					_ghost_piece(holder, strengthen.ghost_mesh(parts, _library))
					parts = []
		if not parts.is_empty():
			if pace.due():
				await pace.next()
				if mine != _reading:
					return
			_ghost_piece(holder, strengthen.ghost_mesh(parts, _library))


static func _ghost_piece(holder: Node3D, mesh: ArrayMesh) -> void:
	var piece := MeshInstance3D.new()
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.mesh = mesh
	holder.add_child(piece)


# -- made once ----------------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.96)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 10
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var finger: bool = Phone.on()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.text = tr("Finish the surfaces")
	_title.add_theme_font_size_override("font_size", 14)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = _button(header, tr("Close"), close, tr("Put the bar away"))
	var lead := Label.new()
	lead.text = tr("What a set designer would finish, drawn on the model. Untick a kind to leave it out.")
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.add_theme_font_size_override("font_size", 12)
	lead.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	column.add_child(lead)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	column.add_child(_status)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	column.add_child(_rows)
	for kind: String in KINDS:
		var box := CheckBox.new()
		box.name = "finish_" + kind
		box.add_theme_font_size_override("font_size", 12)
		box.tooltip_text = _kind_tip(kind)
		box.accessibility_name = _kind_words(kind, 2)
		if finger:
			box.custom_minimum_size = Vector2(0, FINGER)
		box.toggled.connect(func(on: bool) -> void: set_kind(kind, on))
		box.visible = false
		_rows.add_child(box)
		_ticks[kind] = box
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 12)
	_note.add_theme_color_override("font_color", Color(0.62, 0.8, 1.0))
	_note.visible = false
	column.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	_lay = _button(buttons, tr("Lay"), func() -> void: await lay_now(),
		tr("Put down every ticked kind, as one undo step"))
	_lay.name = "finish_lay"
	if finger:
		_lay.custom_minimum_size = Vector2(FINGER * 2.0, FINGER)
		_close.custom_minimum_size = Vector2(FINGER, FINGER)
	custom_minimum_size = Vector2(340, 0)


func _kind_tip(kind: String) -> String:
	match kind:
		"tiles":
			return tr("Tiles on open studs where a top should be smooth, in the part's own colour")
		"slopes":
			return tr("Slopes on studs that step up, as a roof or a bonnet steps")
		"rounds":
			return tr("Curved slopes along a body's hard top edge")
		"sides":
			return tr("A plain side skinned smooth, or a long wall given texture: its own bricks are swapped for others, so it starts unticked")
	return tr("The open ground, kept for figures to stand on unless ticked")


func _button(into: Control, text: String, run: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(run)
	into.add_child(button)
	return button


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if visible and key != null and key.pressed and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_ghosts_off()
	if _reader != null and not _reader.is_inside_tree():
		_reader.free()
		_reader = null
