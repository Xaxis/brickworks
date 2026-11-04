## What a set stands on when it is opened, by every way one is: the grid,
## Studio's floor, and never a baseplate nobody chose. The owner, 2026-11-04:
## "when user opens a prebuilt kit it loads it into the studio with a green
## baseplate underneath it.. that doesnt make since does it?" A file that
## said nothing of its floor got the floor new models get
## (ModelFloor.preferred), a 32 x 32 dark green baseplate, so every set from
## the library and every file made in another program opened on a lawn.
##
##   godot --headless --path . --script src/dev/set_floor_probe.gd
##
## In the real app, headless, with stand-ins for the library and the gallery
## (as empty_open_probe has them) given LDraw's own files from vendor/omr:
##
##   1. 8808-1, the F1 Racer, by the Library and a set's page's Open in the
##      app (?library=, Main._maybe_open_library), by a session's open_model
##      library=, by File, Open of its .mpd, given as a double-click gives it
##      (Main._open_given), and restored from the autosave: on the grid each
##      time, no plate laid.
##   2. Files made elsewhere, by File, Open and as given: a community .ldr
##      (LDraw's car, the first visit's example), a Studio .io, one with a
##      picture Brickworks reads into a part of its own, and an LDD .lxf.
##   3. A new model (File, New; a session's clear_model) stands on the floor
##      the person chose for new ones: the default, and one chosen.
##   4. A Brickworks file keeps its floor line, each kind; one saved before
##      models had floors (by Brickworks, no line) stands on the floor new
##      models get.
##   5. A set with a baseplate of its own (6689-1) stands on that, and no
##      second plate is laid under it.
##   6. View, Floor, Baseplate 32 x 32 under the set: laid, one step of the
##      history, undone to the grid and redone, saved with the person's copy
##      and opened again on it.
##   7. Build together: a set opened here is on the grid in what a joiner is
##      sent, and a joiner given that stands on the grid.
##   8. What pictures it: the scene a card draws has no ground part in it;
##      the booklet's steps and the parts list are the set's parts alone.
##   9. Whether it stands: the status bar's verdict and its balance on the
##      grid are what they are on a baseplate, for 6043-1, whose halberd's
##      turned box reaches under the ground, and for 8808-1.
extends SceneTree

const SET_ID := "omr-8808-1"
const SET_FILE := "res://vendor/omr/files/8808-1.mpd"
## Its parts, as the app lays them and the site packs them (api/_parts.js sceneOf).
const SET_PARTS := 92
const PLATED_ID := "omr-6689-1"
const PLATED_FILE := "res://vendor/omr/files/6689-1.mpd"
## The Dragon Defender: a figure's halberd, turned, whose box reaches 7.7 LDU
## under the ground the trebuchet stands on (Tested._exact_whole).
const HALBERD_FILE := "res://vendor/omr/files/6043-1.mpd"
## Made elsewhere: LDraw's example car (James Jessiman's), a Studio .io whose
## author line is empty, one carrying a picture Brickworks reads into a part
## whose author line is Brickworks (StudioDecor), and an LDD file.
const ELSEWHERE := ["res://models/car.ldr", "res://tests/fixtures/studio/bay_2025.io",
	"res://tests/fixtures/studio/decor_2025.io", "res://src/dev/fixtures/49311_test.lxf"]
const COPY := "Set Floor Probe 8808"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _bar: ModelBar
var _shell: Shell
var _floor: FloorLayer
var _socket: CommandSocket
var _books: FakeLibrary
var _next: int = 0
var _opened: int = 0


## The library, with LDraw's files of the sets asked for, as the store
## serves them, and no network.
class FakeLibrary extends ModelLibrary:
	var files: Dictionary = {}

	func find(id: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		if not files.has(id):
			trouble = "The library has no model %s." % id
			return {}
		# No set number: a session's answer would weigh the parts against
		# the box's, which is a fetch.
		var number: String = id.trim_prefix("omr-")
		return {"id": id, "set": "", "name": number, "theme": "", "year": 0, "parts": 0,
			"box": 0, "file": "library/omr/%s.mpd" % number, "cover": "", "author": "LDraw",
			"licence": "CCAL 2.0", "page": "https://library.ldraw.org/omr/sets/1", "alternate_of": ""}

	func model_text(entry: Dictionary, _job: Working.Job = null) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"text": FileAccess.get_file_as_string(str(files[entry["id"]])), "error": ""}

	func fetch_model(id: String, job: Working.Job = null) -> Dictionary:
		var entry: Dictionary = await find(id)
		if entry.is_empty():
			return {"entry": {}, "text": "", "error": trouble}
		var got: Dictionary = await model_text(entry, job)
		got["entry"] = entry
		return got


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_bar = _main.get("_bar")
	_shell = _main.get("_shell")
	_floor = _main.get("_floor")
	_store.keeps = true
	_books = FakeLibrary.new()
	_books.files = {SET_ID: SET_FILE, PLATED_ID: PLATED_FILE}
	root.add_child(_books)
	_main.set("_model_library", _books)
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_bar.opened.connect(func(_placed: int) -> void: _opened += 1)
	# The floor new models get, as a first run has it.
	ShellPrefs.put("new_floor", "")
	_forget(COPY)

	await _a_set_every_way()
	await _made_elsewhere()
	await _new_models()
	await _brickworks_files()
	await _its_own_plate()
	await _a_plate_chosen()
	await _together()
	await _pictured()
	await _stands()

	_forget(COPY)
	ShellPrefs.put("new_floor", "")
	print("")
	if _failures == 0:
		print("set_floor: a set, or a file made elsewhere, opens on the grid; a new model on the floor chosen for new ones")
	else:
		print("set_floor: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- 1. a set, every way one opens ------------------------------------------------


func _a_set_every_way() -> void:
	print("  8808-1, every way a set is opened")
	await _start_clear()
	_main.set("_from_library", SET_ID)
	await _main.call("_maybe_open_library")
	await _settled()
	_on_grid("from the Library, or its page's Open in the app (?library=)", SET_PARTS)

	await _start_clear()
	var said: String = await _say("open_model", {"library": SET_ID, "discard_changes": true})
	await _settled()
	_on_grid("by a session's open_model library= (%s)" % said.left(40), SET_PARTS)

	await _start_clear()
	await _file_open(SET_FILE)
	_on_grid("by File, Open of 8808-1.mpd", SET_PARTS)

	await _start_clear()
	await _given(SET_FILE)
	_on_grid("given as a double-click gives it", SET_PARTS)

	# Its autosave, as the next start brings it back.
	_store.touch()
	var kept: String = _store.write_now()
	var said_floor: ModelFloor = ModelFloor.read(FileAccess.get_file_as_string(kept))
	_check("its autosave written, saying %s" % (said_floor.to_meta() if said_floor != null
		else "nothing of its floor"), said_floor != null)
	await _start_clear()
	var back: int = await _store.restore_fetched()
	_main.call("_lay_baseplate")
	await _settled()
	_on_grid("restored from the autosave (%d parts)" % back, SET_PARTS)


# -- 2. files made elsewhere ------------------------------------------------------


func _made_elsewhere() -> void:
	print("  files made elsewhere")
	for path: String in ELSEWHERE:
		await _start_clear()
		await _file_open(path)
		_on_grid("%s by File, Open" % path.get_file(), 1)
		await _start_clear()
		await _given(path)
		_on_grid("%s given" % path.get_file(), 1)


# -- 3. new models ----------------------------------------------------------------


func _new_models() -> void:
	print("  a new model, on the floor chosen for new ones")
	await _start_clear()
	await _file_open(SET_FILE)
	await _bar.call("_start_new")
	await _frames(3)
	var default: ModelFloor = ModelFloor.make(ModelFloor.BASEPLATE)
	_check("File, New after a set: %s, %d plate laid" % [_store.model_floor.words(),
		_store.scenery.size()], _store.model_floor.same_as(default) and _store.scenery.size() == 1)
	await _file_open(SET_FILE)
	await _say("clear_model", {})
	await _frames(3)
	_check("a session's clear_model after a set: %s, %d plate laid" % [_store.model_floor.words(),
		_store.scenery.size()], _store.model_floor.same_as(default) and _store.scenery.size() == 1)
	var tan: ModelFloor = ModelFloor.make(ModelFloor.BASEPLATE, 48, 48, 19)
	ModelFloor.prefer(tan)
	await _bar.call("_start_new")
	await _frames(3)
	_check("chosen for new models, %s: File, New stands on it (%s)" % [tan.words(),
		_store.model_floor.words()], _store.model_floor.same_as(tan) and _store.scenery.size() == 1)
	await _start_clear()
	await _file_open(SET_FILE)
	_on_grid("...and a set still opens on the grid", SET_PARTS)
	ShellPrefs.put("new_floor", "")


# -- 4. Brickworks' own files ---------------------------------------------------


func _brickworks_files() -> void:
	print("  a Brickworks file keeps its line")
	await _start_clear()
	_builder.put_part("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	_builder.put_part("3003", 1, Transform3D(Basis.IDENTITY, Vector3(60, 24, 0)))
	for chosen: ModelFloor in [ModelFloor.make(ModelFloor.GRID), ModelFloor.make(ModelFloor.NONE),
			ModelFloor.make(ModelFloor.BASEPLATE, 16, 16, 72), ModelFloor.make(ModelFloor.BASEPLATE)]:
		_main.call("choose_floor", chosen)
		await _frames(2)
		var text: String = _store.to_text("Own Floors")
		var opened: Dictionary = await _store.open_text_fetched(text, "own floors")
		_main.call("_lay_baseplate")
		await _frames(2)
		_check("saved on %s and opened again on it (%s, %d parts)" % [chosen.words().to_lower(),
			_store.model_floor.words().to_lower(), int(opened["placed"])],
			_store.model_floor.same_as(chosen) and int(opened["placed"]) == 2
			and _store.scenery.is_empty() != chosen.is_plate())
	# Saved by Brickworks before models had floors (2026-10-12): its author
	# line and no floor line.
	var old: PackedStringArray = []
	for line: String in _store.to_text("Before Floors").split("\n"):
		if not line.begins_with(ModelFloor.META):
			old.append(line)
	var text_old: String = "\n".join(old)
	var tan: ModelFloor = ModelFloor.make(ModelFloor.BASEPLATE, 48, 48, 19)
	for preferred: ModelFloor in [ModelFloor.make(ModelFloor.BASEPLATE), tan]:
		ModelFloor.prefer(preferred)
		await _start_clear()
		await _store.open_text_fetched(text_old, "before floors")
		_main.call("_lay_baseplate")
		await _frames(2)
		_check("a Brickworks file from before floors (%s, no floor line) stands on the floor new models get, %s (%s)"
			% ["0 Author: Brickworks" if text_old.contains("\n0 Author: Brickworks\n") else "no author line",
			preferred.words().to_lower(), _store.model_floor.words().to_lower()],
			text_old.contains("\n0 Author: Brickworks\n") and _store.model_floor.same_as(preferred)
			and _store.scenery.size() == 1)
	ShellPrefs.put("new_floor", "")


# -- 5. a set with its own baseplate ----------------------------------------------


func _its_own_plate() -> void:
	print("  a set with a baseplate of its own")
	await _start_clear()
	_main.set("_from_library", PLATED_ID)
	await _main.call("_maybe_open_library")
	await _settled()
	var own: Array[int] = _floor.own_plates()
	var plates: PackedStringArray = []
	for brick_id: int in own:
		plates.append(_world.get_brick(brick_id).part_id)
	_check("6689-1 stands on its own %s, at the ground, and no plate is laid under it (%d scenery)"
		% [", ".join(plates), _store.scenery.size()],
		own.size() == 1 and _store.scenery.is_empty())
	_check("...the grid drawn under it, no wider than its plate: %s" % _store.model_floor.words(),
		_store.model_floor.kind == ModelFloor.GRID and _floor.area.is_equal_approx(
			_flat(_world.get_brick(own[0]))) if not own.is_empty() else false)


# -- 6. a baseplate chosen under a set --------------------------------------------


func _a_plate_chosen() -> void:
	print("  View, Floor, Baseplate 32 x 32 under the set")
	await _start_clear()
	_main.set("_from_library", SET_ID)
	await _main.call("_maybe_open_library")
	await _settled()
	_on_grid("opened", SET_PARTS)
	var places: Array = _model_places()
	var depth: int = _builder.history_depth()
	_check("View, Floor, Baseplate 32 × 32 runs", _shell.run("floor_32"))
	await _frames(3)
	var plate: ModelFloor = ModelFloor.make(ModelFloor.BASEPLATE, 32, 32, 288)
	_check("...one step of the history (%d -> %d), %s, %d plate laid" % [depth,
		_builder.history_depth(), _store.model_floor.words(), _store.scenery.size()],
		_builder.history_depth() == depth + 1 and _store.model_floor.same_as(plate)
		and _store.scenery.size() == 1)
	_check("...nothing of the set moved", _model_places() == places)
	_check("Edit, Undo: the grid again, no plate", _shell.run("undo"))
	await _frames(3)
	_check("...%s, %d scenery" % [_store.model_floor.words(), _store.scenery.size()],
		_store.model_floor.kind == ModelFloor.GRID and _store.scenery.is_empty())
	_check("Edit, Redo: the baseplate back", _shell.run("redo"))
	await _frames(3)
	_check("...%s, %d plate" % [_store.model_floor.words(), _store.scenery.size()],
		_store.model_floor.same_as(plate) and _store.scenery.size() == 1)
	_check("saved as the person's copy, %s" % COPY, _store.save_as(COPY))
	var saved: String = FileAccess.get_file_as_string(ModelStore.saved_path(COPY))
	_check("...its file says %s" % plate.to_meta(), saved.contains(plate.to_meta() + "\n"))
	await _start_clear()
	var placed: int = await _bar.open_with_progress(ModelStore.saved_path(COPY))
	_bar.opened.emit(placed)
	await _settled()
	_check("...and opened again, %d parts on %s, %d plate laid" % [placed,
		_store.model_floor.words(), _store.scenery.size()],
		placed == SET_PARTS and _store.model_floor.same_as(plate) and _store.scenery.size() == 1)


# -- 7. building together -------------------------------------------------------


func _together() -> void:
	print("  Build together, a set opened by one")
	await _start_clear()
	_main.set("_from_library", SET_ID)
	await _main.call("_maybe_open_library")
	await _settled()
	var together: Together = _main.get("_together")
	var meta: Dictionary = together.call("_meta_now")
	var text: String = together.model_text()
	_check("what a joiner is sent says the grid: ~floor %s, %s" % [meta.get("~floor", ""),
		ModelFloor.read(text).to_meta() if ModelFloor.read(text) != null else "no floor line"],
		str(meta.get("~floor", "")).begins_with("GRID") and ModelFloor.read(text) != null
		and ModelFloor.read(text).kind == ModelFloor.GRID)
	# The joiner: the session's text opened as Together opens it, and its
	# floor put as the snapshot's meta puts it (Together._lay_snapshot).
	await _start_clear()
	var opened: Dictionary = await _bar.open_text_with_progress(text, "8808-1")
	together.call("_put_meta", "~floor", str(meta.get("~floor", "")))
	_main.call("_lay_baseplate")
	await _settled()
	_on_grid("the joiner, %d parts" % int(opened["placed"]), SET_PARTS)


# -- 8. what pictures it ----------------------------------------------------------


func _pictured() -> void:
	print("  what pictures the set")
	await _start_clear()
	_main.set("_from_library", SET_ID)
	await _main.call("_maybe_open_library")
	await _settled()
	var scene: Dictionary = ModelScene.packed(_world, _library, _store.scenery)
	var parts: int = _world.brick_count() - _store.scenery.size()
	_check("the scene a card draws: %d bricks, %d of them ground" % [int(scene["count"]),
		int(scene["count"]) - parts], int(scene["count"]) == parts and parts == SET_PARTS)
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery, {}, true)
	var in_steps: int = 0
	var plates: int = 0
	for step: Instructions.Step in steps:
		for brick_id: int in step.brick_ids:
			in_steps += 1
			if _floor.is_ground_plate(_world.get_brick(brick_id)):
				plates += 1
	_check("the booklet's %d steps lay the set's %d parts and no baseplate (%d laid, %d plates)"
		% [steps.size(), parts, in_steps, plates], in_steps == parts and plates == 0)
	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	_check("the parts list counts the set alone: %d pieces" % stock.pieces, stock.pieces == parts)


# -- 9. whether it stands ----------------------------------------------------------


func _stands() -> void:
	print("  whether a set stands, on the grid as on a baseplate")
	for path: String in [HALBERD_FILE, SET_FILE]:
		await _start_clear()
		await _given(path)
		var grid: Array = await _weighed()
		_shell.run("floor_32")
		await _frames(3)
		var plate: Array = await _weighed()
		_check("%s on the grid: %s, margin %s; on a baseplate: %s, margin %s" % [path.get_file(),
			grid[0], grid[1], plate[0], plate[1]],
			grid == plate and str(grid[0]).begins_with("stands up"))


## The status bar's verdict on the model as it stands (Main.weigh_joints),
## and the margin of its balance, in studs.
func _weighed() -> Array:
	var report: Stability.Report = await _main.weigh_joints(true)
	if report == null:
		return ["not weighed", ""]
	var margin: String = "%.1f" % report.balance.margin if report.balance != null else "none"
	return [report.summary(), margin]


# -- helpers ----------------------------------------------------------------------


func _on_grid(how: String, least: int) -> void:
	var parts: int = _world.brick_count() - _store.scenery.size()
	_check("%s: %s, %d plate%s laid, %d parts" % [how, _store.model_floor.words().to_lower(),
		_store.scenery.size(), "" if _store.scenery.size() == 1 else "s", parts],
		_store.model_floor.kind == ModelFloor.GRID and _store.scenery.is_empty() and parts >= least)


## An empty model on the floor new models get, nothing to ask about: what
## each open starts from, so the floor it ends on is the open's.
func _start_clear() -> void:
	_main.call("clear_model")
	await _frames(2)


## File, Open of [param path], as the picker hands the app a file chosen.
func _file_open(path: String) -> void:
	_bar.call("_import")
	var picker: ModelFilePicker = _bar.get("_picker")
	var dialog: FileDialog = picker.get("_dialog")
	if dialog != null:
		dialog.hide()
	var was: int = _opened
	picker.take(FileAccess.get_file_as_bytes(path), path.get_file())
	for _n: int in 3000:
		if _opened > was:
			break
		await process_frame
	await _settled()


## [param path] as the system hands it to the app, which opens it then lays
## its floor (Main._ready).
func _given(path: String) -> void:
	var real: String = ProjectSettings.globalize_path(path)
	await _main.call("_open_given", real)
	_main.call("_lay_baseplate")
	await _settled()


func _settled() -> void:
	for _n: int in 3000:
		if not _store.laying and _store.awaited.is_empty():
			break
		await process_frame
	await _frames(3)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _model_places() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append([brick.part_id, brick.transform.origin.snapped(Vector3.ONE * 0.01)])
	out.sort()
	return out


## A brick's top, flattened, as FloorLayer reads a plate's.
func _flat(brick: BrickWorld.Brick) -> AABB:
	var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
	var box: AABB = (brick.transform * info.bounds).abs()
	return AABB(Vector3(box.position.x, 0.0, box.position.z), Vector3(box.size.x, 0.0, box.size.z))


func _forget(name: String) -> void:
	DirAccess.remove_absolute(ModelStore.saved_path(name))
	var folder: String = ModelVersions.folder(ModelStore._safe_name(name))
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


## A tool's answer as text, called as the connector calls it: a job's
## answer once it is done, when the call answered with a job.
func _say(tool: String, arguments: Dictionary) -> String:
	var result: Dictionary = await _rpc("tools/call", {"name": tool, "arguments": arguments})
	var job: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	if job == null:
		return _text(result)
	for _n: int in 120:
		var polled: String = _text(await _rpc("tools/call", {"name": "job",
			"arguments": {"id": int(job.get_string(1))}}))
		if not polled.contains(" is still going"):
			return polled
	return "job %s never ended" % job.get_string(1)


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text
