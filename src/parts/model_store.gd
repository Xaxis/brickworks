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

## Whether this run may write a model anywhere at all. False only for a
## model shared by link and opened to look at (/app?view=<id>): somebody
## else's model, in a browser that may hold the visitor's own. The
## autosave, Save and Save as all go through _write, which refuses.
var read_only: bool = false

## The link this model is shared at (api/share.js), or empty. Carried in
## the working model and its saves as a meta line LDraw readers ignore,
## so publishing it again updates the same link. Never in what is
## published or exported: that is to_text, which leaves it out.
var share_id: String = ""
const SHARE_META := "0 !BRICKWORKS SHARE "


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
## A new model, called this: see [method begin].
signal begun(name: String)

const UNTITLED := "Untitled"
## What the model on the baseplate is called: the name it was saved under,
## or the title inside the file it came from. The autosave carries it.
## It wrote "Working model" instead, so the app reopened a model the owner
## had saved and named, and called it Untitled.
var title: String = UNTITLED
## The model on the baseplate is one that ships with the app, opened from
## there and not saved since. Its name is not the person's: Clear takes it
## away with the bricks (Main).
var example: bool = false


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
		example = false
		saved.emit(name)
		return true
	return false


## The model on the baseplate is a new one, nothing of it saved, called
## [param name] for what is going down on it.
##
## When the example car of a first visit made room for a design, it went
## and its name stayed: the tower built in its place was "Example Car for
## Demonstration of LDRAW Library" in the bar, and Save saved it as that.
## A name a saved model has already gets a number after it, so Save never
## writes over somebody's model with new work.
func begin(name: String) -> void:
	var wanted: String = name.strip_edges()
	title = UNTITLED if wanted.is_empty() or wanted == UNTITLED else _free_name(wanted)
	# Nothing in it is missing, so the autosave may keep it.
	whole = true
	example = false
	# New work is not the model that was shared: publishing it must not
	# replace that one at its link.
	share_id = ""
	begun.emit(title)


## [param name], or it with a number after it when a saved model has it.
static func _free_name(name: String) -> String:
	var tried: String = name
	for n: int in range(2, 100):
		if not FileAccess.file_exists(SAVE_DIR + _safe_name(tried) + ".ldr"):
			break
		tried = "%s %d" % [name.left(50), n]
	return tried


## What to call the model a brief asks for: the thing, without the asking
## or what is said about it. "Build the Tower of Orthanc from Lord of the
## Rings, about 40 cm tall" is the Tower of Orthanc.
static func name_for(brief: String) -> String:
	var text: String = brief.strip_edges()
	for stop: String in [".", ",", ";", ":", "!", "?", "\n", "(", " - ", " — ", " – "]:
		var at: int = text.find(stop)
		if at > 0:
			text = text.left(at)
	var words: PackedStringArray = text.split(" ", false)
	const ASKING := ["please", "can", "could", "would", "will", "you", "i", "i'd",
		"id", "i'm", "want", "like", "love", "to", "see", "build", "make", "design",
		"create", "do", "me", "us", "a", "an", "the", "some", "my", "lego", "brick",
		"model", "version", "of", "let's", "lets", "how", "about"]
	while not words.is_empty() and words[0].to_lower() in ASKING:
		words.remove_at(0)
	# Up to where the brief goes on to say what it should be like.
	const SAYING := ["with", "that", "which", "from", "for", "in", "on", "at",
		"about", "using", "made", "where", "who", "like", "inspired", "based",
		"built", "around", "roughly", "approximately"]
	var kept := PackedStringArray()
	for word: String in words:
		if not kept.is_empty() and word.to_lower() in SAYING:
			break
		kept.append(word)
		if kept.size() == 6:
			break
	var named: String = " ".join(kept).lstrip("\"'“‘").rstrip("\"'”’")
	if named.is_empty():
		return UNTITLED
	# Not capitalize(), which makes a double decker bus A Double Decker Bus.
	return named.left(1).to_upper() + named.substr(1)


## Whether starting a new model would lose anything: bricks that are not
## in a saved model under this name, exactly as they stand.
func has_unsaved_work() -> bool:
	# An example as it shipped is nobody's work: New on the first visit's
	# car, untouched, asked whether to save it. Nothing has been done to
	# it while there is nothing to undo (an Open forgets the history).
	if example and builder != null and builder.history_depth() == 0:
		return false
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
	# Nor take anything away, for a model shared by link and looked at.
	if read_only:
		return false
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
	if int(result["placed"]) > 0:
		example = path.begins_with(EXAMPLE_DIR)
	return int(result["placed"])


## What a file calls its model: its first line, as LDraw has it, unless
## that is a placeholder, and then its file name. The autosave written
## before it kept the name said "Working model", which is no name; Studio
## starts every model "Untitled Model", whatever it is called.
static func _title_of(model: LdrModel, file_name: String) -> String:
	var said: String = model.main.title if model.main != null else ""
	if not said.is_empty() and not said in ["Working model", "Model", "model", "Untitled Model"]:
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
	# A mirrored copy's parts: each put where its reflection is, in its
	# other hand where it has one.
	for item: Variant in flattened:
		var placement: LdrModel.Placement = item
		placement.part_id = studio_part(placement.part_id)
		if placement.mirrored:
			Assemblies.unmirror(placement, library)
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
			missing[placement.part_id] = int(missing.get(placement.part_id, 0)) + 1
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
			"missing_ids": missing,
			"error": "none of the %d parts in that file are in the library (%s)"
				% [missing.size(), named_counts(missing)]}

	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	scenery.clear()
	awaited.clear()

	# Stood on the ground before anything is placed, from every part in it.
	var up: Vector3 = lift_for(known)
	var placed: int = 0
	for item: Variant in known:
		var placement: LdrModel.Placement = item
		placement.transform.origin += up
		# Asked for first: on the desktop the geometry is read from disk
		# when it is asked for, and only a part that still has none is
		# waited for.
		var brick_id: int = world.add_brick(
			placement.part_id, placement.color_code, placement.transform)
		if brick_id == 0:
			awaited.append(placement)
			continue
		world.get_brick(brick_id).group = placement.group
		world.get_brick(brick_id).unit = placement.unit
		builder.register(brick_id, placement.part_id, placement.transform)
		placed += 1
	_awaited_in = world.generation()

	# Ask for the ones that were not to hand, and put each down as it
	# arrives (place_awaited).
	var asked: Dictionary = {}
	for placement: LdrModel.Placement in awaited:
		if not asked.has(placement.part_id):
			asked[placement.part_id] = true
			library.request_mesh(placement.part_id, true)

	_missing_at_open = missing.size()
	whole = missing.is_empty() and awaited.is_empty()
	title = _title_of(model, name)
	share_id = share_in(text)
	example = false
	loaded.emit(title, placed)
	return {"placed": placed, "missing": missing.size(),
		"waiting": waiting.size(), "missing_ids": missing, "error": ""}


## Part numbers and how many of each, as a person reads them: "3626cpr9
## ×2, 973pb999", the first [param most], then "…".
static func named_counts(counts: Dictionary, most: int = 6) -> String:
	var named := PackedStringArray()
	for id: String in counts:
		named.append(id if int(counts[id]) == 1 else "%s ×%d" % [id, int(counts[id])])
	return ", ".join(named.slice(0, most)) + (", …" if named.size() > most else "")


## The LDraw part a Studio model means by [param part_id].
##
## Studio draws parts its copy of LDraw had not got yet itself, and names
## them by BrickLink's number with "bl_" before it: a Studio set from 2025
## used bl_5095, a curved slope LDraw has since drawn as 5095. Where the
## library has that number it is that part; where it has not (a print only
## BrickLink knows, bl_3068pb2483), the name is kept, and the part is left
## out and named like any other the library has not got.
func studio_part(part_id: String) -> String:
	if part_id.begins_with("bl_") and not library.parts.has(part_id) \
			and library.parts.has(part_id.substr(3)):
		return part_id.substr(3)
	return part_id


## Placements whose geometry is on its way, put down as each part arrives.
##
## There were two ways to open a model. The app's own, for the sample on a
## first visit, waited for parts that were not yet fetched and put them
## down later, and did not stand the model on the ground; this one stood it
## on the ground and dropped the parts that had not arrived. So on the web
## a first visit saved the car buried to its axles, a reload lifted it a
## brick, and New said the model had changed. Main opens through here now.
var awaited: Array[LdrModel.Placement] = []
var _awaited_in: int = -1
var _missing_at_open: int = 0


## Put down what was waiting for [param part_id]. Returns how many landed;
## none once the world has been cleared since the model opened.
func place_awaited(part_id: String) -> int:
	if awaited.is_empty():
		return 0
	if world.generation() != _awaited_in:
		awaited.clear()
		return 0
	var still: Array[LdrModel.Placement] = []
	var landed: int = 0
	for placement: LdrModel.Placement in awaited:
		if placement.part_id != part_id:
			still.append(placement)
			continue
		var brick_id: int = world.add_brick(
			placement.part_id, placement.color_code, placement.transform)
		if brick_id != 0:
			world.get_brick(brick_id).group = placement.group
			world.get_brick(brick_id).unit = placement.unit
			builder.register(brick_id, placement.part_id, placement.transform)
			landed += 1
	awaited = still
	whole = awaited.is_empty() and _missing_at_open == 0
	return landed


## How far [param placements] must come up to stand on the ground: zero
## when nothing is below it.
##
## The ground here is zero and nothing is meant to go under it. Other
## people's files do not know that: the LDraw demonstration car, which is
## what this app opens the very first time anybody runs it, is built
## around an origin one brick lower, and arrived buried to the axles in
## the baseplate. The model comes up rather than the plate going down,
## because the plate is where everything else is measured from.
##
## From the catalogue's bounds of every part, so the answer is the same
## whatever geometry has arrived yet. It was measured on the bricks
## already placed, and on the web which those are depends on the network.
func lift_for(placements: Array) -> Vector3:
	var lowest: float = INF
	for item: Variant in placements:
		var placement: LdrModel.Placement = item
		var info: PartLibrary.PartInfo = library.parts.get(placement.part_id)
		if info == null:
			continue
		lowest = minf(lowest, (placement.transform * info.bounds).position.y)
	if lowest == INF or lowest >= -0.001:
		return Vector3.ZERO
	return Vector3(0.0, ceilf(-lowest / BrickLattice.CELL - 0.001) * BrickLattice.CELL, 0.0)


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
		placement.unit = Assemblies.path_of(brick)
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
	var embedded: Dictionary = CustomParts.sources_for(library, used.keys())
	# Sub-assemblies, nested or copied, go out as a tree of sub-models: each
	# definition once, every copy a reference to it (LdrModel.write_tree).
	var tree := Assemblies.new()
	tree.world = world
	tree.builder = builder
	tree.library = library
	tree.scenery = scenery
	var instances: Dictionary = tree.file_frames(figure_frames())
	if not instances.is_empty():
		return LdrModel.write_tree(placements, title, "Brickworks", instances, embedded)
	return LdrModel.write_ldr(placements, title, "Brickworks", figure_frames(), embedded)


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
		if Minifig.is_figure(members[group], library):
			var frame: Variant = Minifig.frame_of(members[group], library)
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
	if read_only:
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	var text: String = with_share(to_text(title, with_steps), share_id)
	file.store_string(text)
	file.close()
	_tell_page_wrote(path, text.to_utf8_buffer().size())
	return true


## [param text] with the link it is shared at, on the line after its
## first (inside the model itself, for an .mpd); as it is for none.
static func with_share(text: String, id: String) -> String:
	if id.is_empty():
		return text
	var cut: int = text.find("\n")
	if cut < 0:
		return text + "\n" + SHARE_META + id + "\n"
	return text.substr(0, cut + 1) + SHARE_META + id + "\n" + text.substr(cut + 1)


## The link a model's text says it is shared at, or empty.
static func share_in(text: String) -> String:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS SHARE ([A-Za-z0-9]{10})\\s*$").search(text)
	return found.get_string(1) if found != null else ""


## [param name], or the first of "name (copy)", "name (copy 2)"… that no
## saved model has yet: so a copy never writes over one of the person's own.
func unused_name(name: String) -> String:
	var tried: String = name
	var n: int = 1
	while FileAccess.file_exists(SAVE_DIR + _safe_name(tried) + ".ldr"):
		tried = "%s (copy)" % name if n == 1 else "%s (copy %d)" % [name, n]
		n += 1
	return tried


## On the web, tell the page a file was written, so it can watch for it
## to reach the browser's storage (the shell's brickworksWrote).
##
## user:// there is IndexedDB, written by the engine on its own schedule:
## a save reached it 25 to 52 s after Save on a loaded machine, and a tab
## closed before then lost the save. The page knows when it has really
## landed; the app says "saved" only then (stored), and the page warns
## before a tab with a write still on its way is closed.
static func _tell_page_wrote(path: String, size: int) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.brickworksWrote && window.brickworksWrote(%s, %d)"
		% [JSON.stringify(ProjectSettings.globalize_path(path)), size], true)


## Whether a file written here has reached the browser's storage. Always
## true off the web, where a written file is on disk.
static func stored(path: String) -> bool:
	if not OS.has_feature("web"):
		return true
	var answer: Variant = JavaScriptBridge.eval(
		"window.brickworksStored ? window.brickworksStored(%s) : true"
		% JSON.stringify(ProjectSettings.globalize_path(path)), true)
	return answer == null or bool(answer)


static func _count_bricks(path: String) -> int:
	return count_in(FileAccess.get_file_as_string(path))


## How many bricks a model's text opens as, counted the way the app counts
## the model on the baseplate: each copy of a sub-model as the parts in
## it. The Open list counted a sub-model's reference as a brick and its
## parts once however many copies there were, and said "My House — 14
## bricks" of a house the app called 13 (brickworks.diy, 2026-10-12).
## Not the lines inside a part the file carries: a made 2 x 7 brick is
## twenty-odd references to studs and tubes, and one brick.
static func count_in(text: String) -> int:
	# Each section by its name: the files its lines refer to, and whether
	# it declares a part. The first with any lines is the model.
	var refs: Dictionary = {}
	var is_part: Dictionary = {}
	var order: Array[String] = []
	var name: String = ""
	var lines := PackedStringArray()
	var head := PackedStringArray()
	for raw: String in (text + "\n0 NOFILE").split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 FILE ") or line.begins_with("0 NOFILE"):
			if not lines.is_empty() and not refs.has(name):
				refs[name] = lines
				is_part[name] = LdrModel.declares_part(head)
				order.append(name)
			name = LdrModel._key(line.substr(7)) if line.begins_with("0 FILE ") else ""
			lines = PackedStringArray()
			head = PackedStringArray()
			continue
		if head.size() < 16:
			head.append(line)
		if line.begins_with("1 "):
			var fields: PackedStringArray = line.split(" ", false)
			if fields.size() >= 15:
				lines.append(LdrModel._key(" ".join(fields.slice(14))))
	if order.is_empty():
		return 0
	return _bricks_in(order[0], refs, is_part, 0)


static func _bricks_in(section: String, refs: Dictionary, is_part: Dictionary,
		depth: int) -> int:
	var count: int = 0
	for named: String in refs[section]:
		if depth < 32 and refs.has(named) and named != section and not bool(is_part[named]):
			count += _bricks_in(named, refs, is_part, depth + 1)
		else:
			count += 1
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
