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
## points or more (TouchSizing.size_panel), and on a phone it is a sheet
## under the model, the ghost in sight above it (Main._finish_surfaces).
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
## The assistant the shown findings were read through, and their pass: one
## of the bar's own per reading, never in the tree, so the person's
## Claude's own pass (its findings, the zones it was told to keep) is left
## as it is. One per reading: a reading stopped part way had filled a
## shared one's caches from a model since closed, and the next model's read
## through it found none of its 22 (fpreview M1).
var _reader: Assistant = null
var _pass: SurfacePass = null
## The world as the findings shown, or being read, were read from: its
## generation (another model opened) and revision (any edit, an Undo, a
## Together peer's). Either moving while the bar is open, what is shown is
## taken down and read again (fpreview M2).
var _seen_generation: int = -1
var _seen_revision: int = -1
## And the model's name it was read under: the pass reads a building or a
## body off it, and a model opened is named after its parts are in. Read
## under the last one's name, the house showed 30 places, not its 22.
var _seen_name: String = ""
## Laying: its own edits are not a change to read again for.
var _laying: bool = false
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
	set_process(false)
	visibility_changed.connect(func() -> void: set_process(visible))
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
	# A reading still going ends at its next stopping place: opened again,
	# the next one waits for it, never runs whole in one frame (H1).
	Fiber.stop(self)
	visible = false
	_ghosts_off()
	busy = false
	phase = ""


## What a reading is doing now, for a probe timing its frames: "" when
## nothing, else warm, read, fetch, ghosts.
var phase: String = ""


## Read the model again and show what the pass would lay now. Awaited.
## A reading still going is stopped and waited for (Fiber.run), never
## read whole beside it; this one reads through an assistant of its own.
func refresh() -> void:
	if _world == null:
		return
	_reading += 1
	var mine: int = _reading
	Fiber.stop(self)
	busy = true
	found = {}
	left_alone = PackedStringArray()
	more = 0
	read_at = -1
	_ghosts_off()
	_show()
	var picked: Dictionary = {}
	for id: Variant in _builder.selection:
		if _world.get_brick(int(id)) != null and not _scenery.has(int(id)):
			picked[int(id)] = true
	var revision: int = _world.revision
	_seen_generation = _world.generation()
	_seen_revision = revision
	_seen_name = _model_name()
	var job: Working.Job = Working.begin(tr("Reading the model's studs, steps and edges…"))
	await job.shown()
	# What reads and what draws the ghost compiled on a worker the first
	# time, the frames going on: compiled where first used, the ghost's
	# script held Orthanc's first ghost frame 122-209 ms (fpfix).
	phase = "scripts"
	await Later.script_in_background(&"Assistant", job)
	await Later.script_in_background(&"Strengthen", job)
	var reader: Assistant = _make_reader()
	var reading := SurfacePass.new(reader)
	phase = "warm"
	await _warm(mine)
	phase = "read"
	# The pass's own reading, the AI's, spread over frames (Fiber): on
	# Orthanc it is seconds of work, and the window goes on meanwhile.
	var fiber_said: Variant = null
	if mine == _reading:
		fiber_said = await Fiber.run(func() -> Variant: return reading.find(), _library,
			_fetch.bind(reader), job, self)
	job.end()
	if fiber_said != null and mine == _reading:
		# The reading's last turn and its thread's end had the frame it ended
		# in: what the bar makes of it begins in the next.
		phase = "read: done"
		await get_tree().process_frame
	if mine != _reading or not visible or fiber_said == null:
		# Stopped, closed or read again since: its reader goes with it.
		_drop(reader)
		if mine == _reading:
			busy = false
			phase = ""
			_show()
		return
	if _world.revision != revision or _world.generation() != _seen_generation \
			or _model_name() != reader._named_as:
		# Changed while it was read: read again, as it stands now.
		_drop(reader)
		await refresh()
		return
	phase = "ghosts: begin"
	_keep_reader(reader, reading)
	var findings: Array = fiber_said if fiber_said is Array else []
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
	_ghost_in_sight()


## What is shown first must be seen: a ghost out of the model's room has the
## view framed on the model and it. On a phone held upright the room is the
## strip above the bar's sheet, and the house's two pieces stood right of a
## 390-wide screen, at x 791 and 802 of its 720 units (fpfix).
func _ghost_in_sight() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or not camera.has_method("frame") or app == null \
			or not app.has_method("_model_rect"):
		return
	var room: Rect2 = app.call("_model_rect")
	var box := AABB()
	var any: bool = false
	var out: bool = false
	for kind: Variant in _ghosts:
		var holder: Node3D = _ghosts[kind]
		if not is_instance_valid(holder) or not holder.visible:
			continue
		for piece: Node in holder.get_children():
			var shape: AABB = (piece as MeshInstance3D).global_transform \
				* (piece as MeshInstance3D).get_aabb()
			box = shape if not any else box.merge(shape)
			any = true
			var middle: Vector3 = shape.get_center()
			if camera.is_position_behind(middle) \
					or not room.has_point(camera.unproject_position(middle)):
				out = true
	if not any or not out:
		return
	var model: AABB = _world.model_bounds()
	camera.call("frame", box.merge(model) if model.size.length_squared() > 0.0 else box)


## The world changed under what the bar shows or reads (another model
## opened, an edit, an Undo, a Together peer's part): the ghost of what
## the pass would have laid on the model as it was is taken down at once,
## and the model read again as it stands now. A reading going on is
## stopped first (refresh).
func _process(_delta: float) -> void:
	if not visible or _laying or _world == null:
		return
	if _world.generation() == _seen_generation and _world.revision == _seen_revision \
			and _model_name() == _seen_name:
		return
	_seen_generation = _world.generation()
	_seen_revision = _world.revision
	_ghosts_off()
	refresh()


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
##
## Paced by the part: each part a finding lays is tried where it goes, and
## the frame given back whenever its slice is spent, the status bar
## counting the parts. Tried a finding at a time, Orthanc's 32-part round
## held one frame 96 ms on its own, and the frame it ended in 182-205 ms
## (fpreview M5).
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
	var total: int = 0
	for kind: String in KINDS:
		if bool(ticked.get(kind, false)) and found.has(kind):
			chosen.append_array(found[kind])
	for one: SurfacePass.Finding in chosen:
		total += one.add.size()
	if chosen.is_empty():
		say.call(tr("nothing ticked to lay"))
		return {}
	busy = true
	_laying = true
	_show()
	var job: Working.Job = Working.begin(tr("Laying the finish…"), total)
	await job.shown()
	var depth: int = _builder.history_depth()
	var laid: int = 0
	var parts: int = 0
	var taken: int = 0
	var left := PackedStringArray()
	var pace := FramePace.new()
	# Each place's steps, newest first, kept as one step at the end: an edit
	# of the person's made while this goes on is a step of its own, never
	# folded into the finish.
	var places: Array = []
	var going: Dictionary = {"seen": _world.revision, "done": 0, "changed": false}
	for one: SurfacePass.Finding in chosen:
		phase = "lay: check"
		var why: String = await _why_not_laid(one, pace, job, going)
		if bool(going["changed"]):
			left.append(tr("the model was changed while it was laid: the rest is left"))
			break
		if not why.is_empty():
			left.append(why)
			continue
		# The swap begins a frame of its own, and the frame after it, where
		# the world works out what changed, is left to the world: a slice of
		# the Lay's beside either held Orthanc's frames 119-147 ms (fpfix).
		await pace.next()
		if _world.revision != int(going["seen"]):
			left.append(tr("the model was changed while it was laid: the rest is left"))
			break
		var steps: Array = await _swap_paced(one, pace, going)
		await get_tree().process_frame
		phase = "lay: after swap"
		await pace.next()
		if steps.is_empty():
			continue
		places.push_front({"undo": "group", "steps": steps, "words": "finish"})
		laid += 1
		parts += one.add.size()
		taken += one.remove.size()
	job.end()
	# What the app works out after an edit, in a frame of its own.
	if not places.is_empty():
		await pace.next()
	if not places.is_empty():
		phase = "lay: record"
		_builder.record(places, tr("finished the surfaces: %d parts") % parts)
		if app != null and app.has_method("_on_model_edited"):
			# What the app works out after an edit (56 ms on Orthanc), in a
			# frame apart from the record and from the bar's close.
			await get_tree().process_frame
			phase = "lay: edited"
			app.call("_on_model_edited")
			await get_tree().process_frame
			phase = "lay: after edited"
	last_laid = {"laid": laid, "parts": parts, "taken": taken, "left": Array(left),
		"undone": _builder.history_depth() <= depth}
	busy = false
	_laying = false
	phase = ""
	_seen_generation = _world.generation()
	_seen_revision = _world.revision
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


## An assistant of the bar's own for one reading, reading the model as it
## stands. What the model is called says whether it is a building (straight
## slopes first, its roof's edges kept) or a body (rounded): the pass reads
## it off the design's name, and a person's model is its name.
func _make_reader() -> Assistant:
	var reader: Assistant = Later.make(&"Assistant")
	reader.library = _library
	reader.world = _world
	reader.builder = _builder
	reader.scenery = _scenery
	reader._named_as = _seen_name
	return reader


func _model_name() -> String:
	var bar: Node = app.get("_bar") if app != null else null
	return str(bar.call("model_name")) if bar != null and bar.has_method("model_name") else ""


## The reading [param reader] made is the one shown: the last shown's goes.
func _keep_reader(reader: Assistant, reading: SurfacePass) -> void:
	var old: Assistant = _reader
	_reader = reader
	_pass = reading
	if old != null and old != reader:
		# Freed in the next frame, not beside the reading's end: Orthanc's
		# reading is a hundred thousand points to let go of.
		get_tree().process_frame.connect(_drop.bind(old), CONNECT_ONE_SHOT)


func _drop(reader: Assistant) -> void:
	if reader == null or not is_instance_valid(reader) or reader == _reader:
		return
	if not reader.is_inside_tree():
		reader.free()


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


## Parts a reading missed, fetched as a session's design fetches them,
## through the reading's own [param reader].
func _fetch(ids: PackedStringArray, reader: Assistant) -> void:
	phase = "fetch"
	var wanted := Assistant.Model.new()
	for id: String in ids:
		wanted.placements.append(Assistant.Placement.from_dict({"part": id}))
	await reader._ensure_parts(wanted)
	phase = "read"


# -- laying ---------------------------------------------------------------------


## Why [param one] is not laid as the model now stands, "" when it may be:
## every part it lays fits there with the rest of the finding, the parts it
## takes off are all still there, and whatever sat on a stud of one of them
## is still held after. Each part tried, [param pace]'s frame given back
## when its slice is spent and [param job] counting the parts; an edit of
## the person's meanwhile sets [param going]'s changed, and the rest waits.
func _why_not_laid(one: SurfacePass.Finding, pace: FramePace, job: Working.Job,
		going: Dictionary) -> String:
	for id: int in one.remove:
		if _world.get_brick(id) == null or _builder.is_locked(id):
			return tr("%s: a part it lays again is gone or locked") % _where(one)
	var skip: Dictionary = {}
	for id: int in one.remove:
		skip[id] = true
	var fits: bool = true
	for n: int in one.add.size():
		if await _breathe(pace, going):
			return ""
		going["done"] = int(going["done"]) + 1
		job.count(int(going["done"]))
		var others: Array = one.add.slice(0, n) + one.add.slice(n + 1)
		if fits and not _pass._fits(one.add[n], skip, others):
			# Counted on to the finding's end, so the count stays the parts.
			fits = false
	if not fits:
		return tr("%s: no room for it as the model now stands") % _where(one)
	if not await _holds(one, skip, pace, going):
		return "" if bool(going["changed"]) else tr("%s: what stands on it would be left loose") % _where(one)
	return ""


## The frame given back if [param pace]'s slice is spent: true when the
## model was changed meanwhile by anyone but the Lay (going's changed).
func _breathe(pace: FramePace, going: Dictionary) -> bool:
	if pace.due():
		await pace.next()
		if _world.revision != int(going["seen"]):
			going["changed"] = true
	return bool(going["changed"])


## Whatever sits on a stud of a part [param one] takes off is still held
## once it is laid: a part holding studs others sit on is never tiled.
func _holds(one: SurfacePass.Finding, skip: Dictionary, pace: FramePace,
		going: Dictionary) -> bool:
	if one.remove.is_empty():
		return true
	var on: Dictionary = {}
	for raw: Variant in _pass._read.points_of(one.remove):
		var point: OpenPoints.Point = raw
		if point.kind == "stud" and point.by > 0 and not skip.has(point.by):
			on[point.by] = true
	for id: Variant in on:
		if await _breathe(pace, going):
			return false
		var placement: Assistant.Placement = _pass._read.by_id.get(int(id))
		if placement == null:
			return false
		var alone: Dictionary = skip.duplicate()
		alone[int(id)] = true
		if not _pass._fits(SurfacePass._as_dict(placement), alone, one.add):
			return false
	return true


## [param one]'s swap, a part at a time: the parts it takes off in one go,
## then each it lays, whenever [param pace]'s slice is spent a frame left
## to the world and the next slice begun after it. Made in one call, Orthanc's biggest swap held a frame 143 ms
## (fpfix). Its undo steps as Builder.swap_bricks gives them, the new parts
## off first, then the old ones back. Begun, it is finished: a change of
## someone else's meanwhile is said in [param going] (changed), and no
## finding after it is laid.
func _swap_paced(one: SurfacePass.Finding, pace: FramePace, going: Dictionary) -> Array:
	var adds: Array = _adds_of(one)
	phase = "lay: take off"
	var taken: Array = _builder.swap_bricks(PackedInt64Array(one.remove), [])
	going["seen"] = _world.revision
	var put: Array = []
	# A slice's parts are drawn after it, in frames of the world's own,
	# never in a frame with a slice of parts: the world draws a change in the
	# frame it is made (a deferred rebuild), a slice at a time, and each
	# slice, the Lay's and the drawing's, grows to half a slow frame
	# (FramePace), so a frame that held both was 113-222 ms on Orthanc
	# (fpfix) and still 101-132 ms with one frame left between (greenreds).
	_world.hold_drawing()
	for item: Dictionary in adds:
		if pace.due():
			phase = "lay: the world"
			await get_tree().process_frame
			_world.release_drawing()
			await _drawn()
			await pace.next()
			_world.hold_drawing()
			if _world.revision != int(going["seen"]):
				going["changed"] = true
		phase = "lay: put down"
		put.append_array(_builder.swap_bricks(PackedInt64Array(), [item]))
		going["seen"] = _world.revision
	_world.release_drawing()
	return put + taken


## Frames until the world has drawn every change, at most a second's worth
## of them: a drawing someone else holds meanwhile is not waited out.
func _drawn() -> void:
	for _n: int in 60:
		if not _world.has_undrawn():
			return
		await get_tree().process_frame


## The finding's parts as Builder.swap_bricks puts them down: each where the
## pass placed it. Where the finding takes parts off, every part it lays is
## laid in the place of one of them, and takes that part's sub-model and
## step: the one whose box it stands in, or else the nearest (a skin's
## tiles stand on the face of the brick they replace). Matched one for one,
## the castle's curtain walls lost the rest of a swap's parts to the main
## model, 40 parts to 38 (fpreview M3). Where it takes none off (tiles on
## open studs), the sub-model and step a part put down by hand goes in.
func _adds_of(one: SurfacePass.Finding) -> Array:
	var out: Array = []
	var gone: Array = []          ## [brick, its box]
	for id: int in one.remove:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id) if brick != null else null
		if mesh != null:
			gone.append([brick, (brick.transform * mesh.bounds).abs()])
		elif brick != null:
			gone.append([brick, AABB(brick.transform.origin, Vector3.ZERO)])
	var path: String = _builder.place_group
	var step: int = int(_builder.place_step.call(path)) if _builder.place_step.is_valid() else -1
	var middles: Array = []
	for raw: Variant in one.add:
		var placed: Dictionary = raw
		var at: Transform3D = _at(placed)
		var item: Dictionary = {"part": str(placed["part"]), "color": int(placed["color"]),
			"at": at, "path": path, "step": step}
		var mesh: Lbm.PartMesh = _library.mesh_for(str(placed["part"]))
		var middle: Vector3 = (at * mesh.bounds).abs().get_center() if mesh != null else at.origin
		var was: BrickWorld.Brick = _in_place_of(gone, middle)
		if was != null:
			item["path"] = Assemblies.path_of(was)
			item["step"] = was.step
		out.append(item)
		middles.append(middle)
	_none_emptied(out, gone, middles, _kept_by_group(gone))
	_on_their_lines(out, gone, middles)
	return out


## Each part taken off that was read from a line of someone else's file
## hands that line to the nearest part laid in its sub-model and step, as a
## part swapped in by Replace part keeps it (Builder._swap): saved, the part
## laid is written on that line, in the step and the run of its copy the
## file had it in. Laid as new parts, the castle's back curtain wall was
## written in three runs fewer, its copy's parts put at the ends of steps
## (fpfix). One line to a part.
static func _on_their_lines(out: Array, gone: Array, middles: Array) -> void:
	for pair: Array in gone:
		var brick: BrickWorld.Brick = pair[0]
		if brick.origin.is_empty():
			continue
		var key: String = "%s#%d" % [Assemblies.path_of(brick), brick.step]
		var box: AABB = pair[1]
		var pick: int = -1
		var pick_d: float = INF
		for n: int in out.size():
			var item: Dictionary = out[n]
			if item.has("origin") or "%s#%d" % [item["path"], int(item["step"])] != key:
				continue
			var middle: Vector3 = middles[n]
			var d: float = middle.distance_to(_nearest_in(box, middle))
			if d < pick_d:
				pick = n
				pick_d = d
		if pick >= 0:
			out[pick]["origin"] = brick.origin


## How many parts each sub-model and step keeps that [param gone] does not
## take off, read only where a step loses a part and is given none of those
## laid: a step two findings empty between them is empty though each left it
## a part (the castle's back curtain wall, fpfix).
func _kept_by_group(gone: Array) -> Dictionary:
	var off: Dictionary = {}
	for pair: Array in gone:
		off[(pair[0] as BrickWorld.Brick).id] = true
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not off.has(brick.id):
			var key: String = "%s#%d" % [Assemblies.path_of(brick), brick.step]
			out[key] = int(out.get(key, 0)) + 1
	return out


## Every sub-model and step a part is taken off from keeps a part: one it
## still has ([param kept], parts left in each), or one of those laid in
## their place, from a step that keeps something without it: the nearest.
## Matched by box alone, a step of the castle's back curtain wall whose
## parts were all taken off got none of the tiles laid over them, and its
## line in the file went with it (fpfix).
static func _none_emptied(out: Array, gone: Array, middles: Array,
		kept: Dictionary = {}) -> void:
	var given: Dictionary = {}
	for item: Dictionary in out:
		var key: String = "%s#%d" % [item["path"], int(item["step"])]
		given[key] = int(given.get(key, 0)) + 1
	for pair: Array in gone:
		var brick: BrickWorld.Brick = pair[0]
		var key: String = "%s#%d" % [Assemblies.path_of(brick), brick.step]
		if given.has(key) or int(kept.get(key, 0)) > 0:
			continue
		var box: AABB = pair[1]
		var pick: int = -1
		var pick_d: float = INF
		for n: int in out.size():
			var from: String = "%s#%d" % [out[n]["path"], int(out[n]["step"])]
			if from == key or int(given.get(from, 0)) < 2 and int(kept.get(from, 0)) == 0:
				continue
			var middle: Vector3 = middles[n]
			var d: float = middle.distance_to(_nearest_in(box, middle))
			if d < pick_d:
				pick = n
				pick_d = d
		if pick < 0:
			continue
		var was: String = "%s#%d" % [out[pick]["path"], int(out[pick]["step"])]
		given[was] = int(given[was]) - 1
		out[pick]["path"] = Assemblies.path_of(brick)
		out[pick]["step"] = brick.step
		given[key] = 1


## Which of [param gone] (each [brick, its box]) a part whose middle is at
## [param middle] stands in the place of: the one whose box holds it, the
## nearest such; else the nearest box. Null when nothing is taken off.
static func _in_place_of(gone: Array, middle: Vector3) -> BrickWorld.Brick:
	var best: BrickWorld.Brick = null
	var best_d: float = INF
	var inside: bool = false
	for pair: Array in gone:
		var box: AABB = pair[1]
		var holds: bool = box.grow(0.5).has_point(middle)
		var d: float = middle.distance_to(_nearest_in(box, middle))
		if holds:
			d = middle.distance_to(box.get_center())
		if holds and not inside or holds == inside and d < best_d:
			best = pair[0]
			best_d = d
			inside = inside or holds
	return best


static func _nearest_in(box: AABB, point: Vector3) -> Vector3:
	return point.clamp(box.position, box.end)


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
## model, its lower half empty. In the tools' column (a finger's layout)
## the column lays it out.
func _fit_height() -> void:
	if is_inside_tree() and not get_parent() is Container:
		size = Vector2(size.x, 0.0)


## The least the tools' sheet under the model is on a phone held upright
## (Main._size_tool_sheet): all it holds, Lay with it, the model and its
## ghost above.
func least_tall() -> float:
	return get_combined_minimum_size().y


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


## How many parts one piece of a kind's ghost is made of, at most, and how
## many corners: a piece is made in one go, so on a big model a kind is
## several, a frame given back between them. Twelve parts alone could be
## twelve 6x6 plates' worth.
const GHOST_PIECE := 12
const GHOST_CORNERS := 6000


## Each kind's ghost put up, a piece at a time.
func _show_ghosts(mine: int) -> void:
	# Begun in a frame of its own: the reading's last turn was this one's.
	await get_tree().process_frame
	if mine != _reading:
		return
	phase = "ghosts: parts"
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
		var corners: int = 0
		for one: SurfacePass.Finding in found[kind]:
			for raw: Variant in one.add:
				if pace.due():
					await pace.next()
					if mine != _reading:
						return
				var part: String = str(raw["part"])
				var size: int = _corners_of(part)
				if not parts.is_empty() and (parts.size() >= GHOST_PIECE
						or corners + size > GHOST_CORNERS):
					if not await _ghost_piece_paced(holder, strengthen, parts, pace, mine):
						return
					parts = []
					corners = 0
				parts.append({"part": part, "color": int(raw["color"]), "at": _at(raw)})
				corners += size
		if not parts.is_empty():
			if not await _ghost_piece_paced(holder, strengthen, parts, pace, mine):
				return


## A piece of a ghost made of [param parts], in a slice of its own: false
## when the reading was stopped meanwhile.
func _ghost_piece_paced(holder: Node3D, strengthen: GDScript, parts: Array, pace: FramePace,
		mine: int) -> bool:
	if pace.due():
		phase = "ghosts: piece"
		await pace.next()
		if mine != _reading:
			return false
	_ghost_piece(holder, strengthen.ghost_mesh(parts, _library))
	return true


## How many corners a part's mesh has, as a ghost is made of it.
func _corners_of(part: String) -> int:
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	if mesh == null:
		return 0
	var out: int = 0
	for s: int in mesh.surface_count():
		out += mesh.surfaces[s].surface_get_array_len(0)
	return out


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
	Fiber.stop(self)
	if _reader != null and not _reader.is_inside_tree():
		_reader.free()
		_reader = null
