## Keeping a model: saving it, loading it, and not losing it.
##
## Everything is written as LDraw .ldr, the format every brick tool
## reads. A model saved here opens in LDView, LeoCAD, Studio and
## Mecabricks, and a model made in any of those opens here. That is worth
## more than a format of our own would be, and it costs nothing: the
## renderer already speaks it.
##
## Three places a model can live, and the difference matters:
##
## The working model is what is on screen. It is written to browser
## storage or the user directory on every change, debounced, so closing
## a tab or losing power costs the last few seconds rather than the last
## few hours. It is not a save — it is the thing a save is made from.
##
## Named saves are the user's. They persist until deleted.
##
## An export is a file leaving the application. On desktop that is a
## path; on the web it is a download, which needs a different mechanism
## entirely because a browser will not let a page write to disk.
class_name ModelStore
extends RefCounted

## Where saves live. user:// is the app's own directory on desktop and
## IndexedDB in the browser, which is the reason this works the same in
## both without a second implementation.
const SAVE_DIR := "user://models/"
## Models that ship with the app. Somewhere to start from: the Open menu
## said "nothing saved yet" to everybody the first time they opened it,
## which is a poor answer to "show me what this can do".
const EXAMPLE_DIR := "res://models/"
const AUTOSAVE := "user://autosave.ldr"

## How long after the last change to write the working model. Long
## enough that dropping a large model in does not write it repeatedly;
## short enough that nothing meaningful is lost.
const AUTOSAVE_DELAY_MS := 2500

## Whether this run keeps the person's working model. Off for a run
## driven from the command line: a design from tools/design.py writes its
## own --out, and writing the autosave as well replaced whatever the
## person had open in the app with a castle they never asked for — and
## two runs at once raced each other for the one file.
var keeps: bool = true


class Entry extends RefCounted:
	var name: String
	var path: String
	var bricks: int
	var modified: int       ## unix seconds
	## An example that ships with the app rather than something this
	## person saved. Read-only in practice: opening one and saving writes
	## a copy of their own.
	var example: bool = false

	func describe() -> String:
		if example:
			return "%s — %d bricks" % [name, bricks]
		var when: String = Time.get_datetime_string_from_unix_time(modified)
		return "%s — %d bricks, %s" % [name, bricks, when.replace("T", " ")]


var world: BrickWorld
var library: PartLibrary
var builder: Builder

## Bricks that are scenery rather than model — the baseplate. They are
## not saved, because a model that carries its own baseplate grows a
## second one every time it is reopened, and because a baseplate is a
## property of the workspace rather than of the thing built on it.
var scenery: Dictionary = {}

var _dirty_at: int = 0
var _pending: bool = false

signal saved(name: String)
signal loaded(name: String, bricks: int)

const UNTITLED := "Untitled"
## What the model on the baseplate is called: the name it was saved under,
## or the title inside the file it came from. The autosave carries it.
## It wrote "Working model" instead, so the app reopened a model the owner
## had saved and named, and called it Untitled.
var title: String = UNTITLED


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Call whenever the model changes. Writing is deferred and coalesced.
func touch() -> void:
	_dirty_at = Time.get_ticks_msec()
	_pending = true


## The model on screen is now what somebody meant it to be, whatever it
## was missing when it opened. Called when they place, remove or change
## a brick: after that the autosave is saving their work rather than
## overwriting their file with a worse copy of it.
func adopt() -> void:
	whole = true


## Call once a frame. Writes the working model when it has settled.
func tick() -> void:
	if not _pending or not keeps:
		return
	if Time.get_ticks_msec() - _dirty_at < AUTOSAVE_DELAY_MS:
		return
	_pending = false
	# Never over a model that did not open whole.
	#
	# On the web most geometry is fetched rather than shipped, so a
	# model can open missing the parts that had not arrived yet. Writing
	# that back over the file it came from turns a few seconds of
	# network into a permanent deletion — and the autosave fires a
	# second after the open, which is exactly when the fetches are still
	# in flight.
	if not whole:
		return
	_write(AUTOSAVE, title)


## Restore the working model from the last session, if there is one.
func restore() -> int:
	if not FileAccess.file_exists(AUTOSAVE):
		return 0
	return open(AUTOSAVE)


func save_as(name: String) -> bool:
	var clean: String = _safe_name(name)
	if clean.is_empty():
		return false
	if _write(SAVE_DIR + clean + ".ldr", name, true):
		title = name
		# Saved by them is theirs, whatever it opened short of.
		whole = true
		saved.emit(name)
		return true
	return false


## Whether starting a new model would lose anything: bricks that are not
## in a saved model under this name, exactly as they stand.
func has_unsaved_work() -> bool:
	var now: PackedStringArray = _brick_lines(to_text(UNTITLED))
	if now.is_empty():
		return false
	if title == UNTITLED:
		return true
	var kept: String = SAVE_DIR + _safe_name(title) + ".ldr"
	if not FileAccess.file_exists(kept):
		return true
	return _brick_lines(FileAccess.get_file_as_string(kept)) != now


static func _brick_lines(text: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with("1 "):
			lines.append(line.strip_edges())
	lines.sort()
	return lines


func list_saved() -> Array[Entry]:
	var found: Array[Entry] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".ldr"):
			continue
		var entry := Entry.new()
		entry.path = SAVE_DIR + file_name
		entry.name = file_name.substr(0, file_name.length() - 4)
		entry.modified = FileAccess.get_modified_time(entry.path)
		entry.bricks = _count_bricks(entry.path)
		found.append(entry)
	found.sort_custom(func(a: Entry, b: Entry) -> bool:
		return a.modified > b.modified)
	return found


## The models that ship with the app, prettied up for a menu.
func list_examples() -> Array[Entry]:
	var found: Array[Entry] = []
	var dir: DirAccess = DirAccess.open(EXAMPLE_DIR)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		# The exported build strips nothing from names, but the editor
		# leaves an .import beside anything it has looked at.
		if not file_name.ends_with(".ldr"):
			continue
		var entry := Entry.new()
		entry.path = EXAMPLE_DIR + file_name
		entry.name = file_name.substr(0, file_name.length() - 4).capitalize()
		entry.bricks = _count_bricks(entry.path)
		entry.example = true
		found.append(entry)
	found.sort_custom(func(a: Entry, b: Entry) -> bool:
		return a.name < b.name)
	return found


func delete(path: String) -> bool:
	return DirAccess.remove_absolute(path) == OK


## Replace what is on screen with a model from disk. Returns how many
## bricks landed.
## Open a saved model from a path.
##
## The same code as [method open_text], because the difference between
## them was doing real harm. This one placed whatever it could and said
## nothing about the rest — and on the web most geometry is fetched
## rather than shipped, so reopening your own model dropped every part
## outside the packed set, reported the truncated count as a success,
## and then the autosave wrote the truncated model back over the file.
## Which is to say: it quietly deleted parts of somebody's model and
## then made that permanent.
func open(path: String) -> int:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return 0
	var result: Dictionary = open_text(text, path.get_file())
	return int(result["placed"])


## What a file calls its model: its first line, as LDraw has it, unless
## that is a placeholder, and then its file name. The autosave written
## before it kept the name said "Working model", which is no name.
static func _title_of(model: LdrModel, file_name: String) -> String:
	var said: String = model.main.title if model.main != null else ""
	if not said.is_empty() and not said in ["Working model", "Model", "model"]:
		return said
	var stem: String = file_name.get_basename()
	if stem.is_empty() or stem == AUTOSAVE.get_file().get_basename():
		return UNTITLED
	return stem.capitalize()


## Open a model from text rather than from a path.
##
## Which is what opening somebody's own file means in a browser, where
## there is no path to open — and, since it is the same code either
## way, what opening one means on the desktop too.
##
## Parts the catalogue does not have are counted and reported rather
## than skipped in silence: an .ldr from elsewhere will use parts this
## does not carry, and "opened, 340 of 500 parts" is a true answer where
## "opened" is not.
func open_text(text: String, name: String = "model") -> Dictionary:
	var model: LdrModel = LdrModel.parse(text, name)
	if model == null:
		return {"placed": 0, "missing": 0, "error": "that is not an LDraw file"}
	# Parts the file brought with it, made here or somewhere else, join
	# the library before anything asks whether the library has them.
	var carried: Dictionary = CustomParts.take_from(library, model)
	for problem: String in carried["problems"]:
		push_warning("could not build a part the file carries: " + problem)

	var flattened: Array = model.flatten(library.parts)
	if flattened.is_empty():
		return {"placed": 0, "missing": 0, "waiting": 0,
			"error": "there are no parts in that file"}

	# Everything decided before anything is destroyed.
	#
	# Tearing the world down and then discovering that not one part
	# could be placed leaves the person with an empty baseplate where
	# their model was, and — because the count was never checked — a
	# message saying it opened.
	var known: Array = []
	var missing: Dictionary = {}
	var waiting: Dictionary = {}
	for item: Variant in flattened:
		var placement: LdrModel.Placement = item
		if not library.parts.has(placement.part_id):
			missing[placement.part_id] = true
		elif not library.is_resident(placement.part_id):
			# In the catalogue but not yet fetched, which on the web is
			# most of it. Counted apart from missing, because asking for
			# it and trying again is an answer and "this part does not
			# exist" is not.
			waiting[placement.part_id] = true
			known.append(placement)
		else:
			known.append(placement)

	if known.is_empty():
		return {"placed": 0, "missing": missing.size(), "waiting": 0,
			"error": "none of the %d parts in that file are in the library"
				% missing.size()}

	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	scenery.clear()

	var placed: int = 0
	for item: Variant in known:
		var placement: LdrModel.Placement = item
		var brick_id: int = world.add_brick(
			placement.part_id, placement.color_code, placement.transform)
		if brick_id != 0:
			world.get_brick(brick_id).group = placement.group
			builder.register(brick_id, placement.part_id, placement.transform)
			placed += 1
	_stand_it_on_the_ground()

	# Ask for the ones that were not to hand, so a second attempt lands
	# them rather than losing them for good.
	for part_id: String in waiting:
		library.request_mesh(part_id, true)

	whole = missing.is_empty() and waiting.is_empty()
	title = _title_of(model, name)
	loaded.emit(title, placed)
	return {"placed": placed, "missing": missing.size(),
		"waiting": waiting.size(), "error": ""}


## Lift a model that opens below the ground.
##
## The ground here is zero and nothing is meant to go under it. Other
## people's files do not know that: the LDraw demonstration car, which
## is what this app opens the very first time anybody runs it, is built
## around an origin one brick lower — so it arrived buried to the
## axles in the baseplate, which is the first thing a new visitor saw.
##
## Lifting the model rather than dropping the plate, because the plate
## is where everything else is measured from, and because this then
## works for any file somebody imports rather than for one known car.
func _stand_it_on_the_ground() -> void:
	var lowest: int = 0x7FFFFFFF
	for brick: BrickWorld.Brick in world.bricks():
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		for cell: Vector3i in builder._cells_for(part, brick.transform):
			lowest = mini(lowest, cell.y)
	if lowest == 0x7FFFFFFF or lowest >= 0:
		return

	var up: Vector3 = BrickLattice.to_ldu(Vector3i(0, -lowest, 0))
	for brick: BrickWorld.Brick in world.bricks():
		var to := Transform3D(brick.transform.basis, brick.transform.origin + up)
		builder.lattice.release(brick.id)
		world.move_brick(brick.id, to)
		builder.register(brick.id, brick.part_id, to)


## Whether the model on screen is the whole of what was opened.
##
## False when parts were missing or still arriving. The autosave checks
## it: writing a model that is missing bricks over the file those bricks
## came from is how a temporary failure to fetch becomes a permanent
## loss.
var whole: bool = true


## The model as LDraw text, for export or for handing to something else.
## The model as an .ldr file.
##
## [param with_steps] works out the build order and writes it as the
## "0 STEP" lines every LDraw reader understands, so the order survives
## leaving this app. Off by default because the autosave calls this: the
## order costs 96 ms at 400 bricks, 552 at a thousand and 2.2 seconds at
## two thousand — it compares every brick with every other — and the
## autosave fires a second after each change. A saved or exported file
## is worth that wait; a keystroke is not.
func to_text(title: String = "Model", with_steps: bool = false) -> String:
	## brick id -> which step it belongs to.
	var step_of: Dictionary = {}
	if with_steps and world.library != null:
		var steps: Array[Instructions.Step] = Instructions.plan(
			world, world.library, scenery)
		for index: int in steps.size():
			for brick_id: int in steps[index].brick_ids:
				step_of[brick_id] = index

	var placements: Array = []
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		if scenery.has(brick.id):
			continue
		var placement := LdrModel.Placement.new(
			brick.part_id, brick.color_code, brick.transform,
			int(step_of.get(brick.id, 0)))
		placement.group = brick.group
		placements.append(placement)
	# In build order where there is one, and bottom to top otherwise, so
	# the file reads the way it would be built. Sorting by height alone
	# put a pin above the beam it goes into, because a pin sits at the
	# middle of a hole and the beam starts lower.
	#
	# And the same file every time for the same model: parts at one
	# height went out in whatever order the world held them, which a
	# reopen changes, so saving a model twice wrote two files. Two
	# figures standing on one plate swapped places in it.
	placements.sort_custom(func(a: LdrModel.Placement, b: LdrModel.Placement) -> bool:
		if a.step != b.step:
			return a.step < b.step
		if not is_equal_approx(a.transform.origin.y, b.transform.origin.y):
			return a.transform.origin.y < b.transform.origin.y
		if a.group != b.group:
			return a.group < b.group
		if a.part_id != b.part_id:
			return a.part_id < b.part_id
		if not is_equal_approx(a.transform.origin.x, b.transform.origin.x):
			return a.transform.origin.x < b.transform.origin.x
		if not is_equal_approx(a.transform.origin.z, b.transform.origin.z):
			return a.transform.origin.z < b.transform.origin.z
		return a.color_code < b.color_code)
	# A made part goes out inside the file, or the file means nothing
	# anywhere the part was not made.
	var used: Dictionary = {}
	for item: Variant in placements:
		used[(item as LdrModel.Placement).part_id] = true
	return LdrModel.write_ldr(placements, title, "Brickworks", figure_frames(),
		CustomParts.sources_for(library, used.keys()))


## Each minifigure in the model, by its group, and the frame it stands
## in: so a figure goes out as a sub-model of its own, standing at its
## origin and placed where it stands, the way real sets' files keep them.
func figure_frames() -> Dictionary:
	var members: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if brick.group.is_empty() or scenery.has(brick.id):
			continue
		if not members.has(brick.group):
			members[brick.group] = []
		(members[brick.group] as Array).append(brick)
	var frames: Dictionary = {}
	for group: String in members:
		if Minifig.is_figure(members[group]):
			var frame: Variant = Minifig.frame_of(members[group])
			if frame != null:
				frames[group] = frame
	return frames


## Send the model to the person as a file.
##
## On desktop this is a write. In a browser a page cannot write to disk,
## so the bytes are handed to the browser as a download instead — the
## same model either way, by two entirely different mechanisms.
func export_to(path: String, title: String = "Model") -> bool:
	var text: String = to_text(title, true)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(
			text.to_utf8_buffer(), path.get_file(), "text/plain")
		return true
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


func _write(path: String, title: String, with_steps: bool = false) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(to_text(title, with_steps))
	file.close()
	return true


static func _count_bricks(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var count: int = 0
	# Not the lines inside a part the file carries: a made 2 x 7 brick is
	# twenty-odd references to studs and tubes, and one brick. A section
	# is counted when it ends, once its header has said what it is.
	var section: int = 0
	var head := PackedStringArray()
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.begins_with("0 FILE ") or line.begins_with("0 NOFILE"):
			if not LdrModel.declares_part(head):
				count += section
			section = 0
			head = PackedStringArray()
			continue
		if head.size() < 16:
			head.append(line)
		if line.begins_with("1 "):
			section += 1
	file.close()
	if not LdrModel.declares_part(head):
		count += section
	return count


## Keep a name to something that can be a filename on every platform.
static func _safe_name(name: String) -> String:
	var out: String = ""
	for character: String in name.strip_edges():
		if character.is_valid_identifier() or character in " -_":
			out += character
		elif character.to_lower() != character.to_upper() or character.is_valid_int():
			out += character
	out = out.strip_edges().replace("  ", " ")
	return out.substr(0, 60)
