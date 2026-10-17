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
## Where the working model is kept: this tab's own (TabSession). It was one
## file for every tab and window, so two tabs reopened the same model,
## under the name of whichever had written it last.
static func autosave() -> String:
	return TabSession.autosave()

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
## The link this model was copied from with Open in Brickworks, or empty.
## Kept the same way as [member share_id], and sent when it is published,
## so its page can say what it was remixed from (api/share.js).
var remixed_from: String = ""
const REMIX_META := "0 !BRICKWORKS REMIX "
## The real set this model was opened from ("10182"), or empty: a file of
## the LDraw model repository says so in its header, and a model saved
## from one carries it on as a meta line. HiddenColours asks before it
## recolours a set's parts.
var from_set: String = ""
const SET_META := "0 !BRICKWORKS FROM_SET "
## The hidden parts' colours chosen for this model (HiddenColours.Plan
## .scheme), for the booklet to show; empty when none were.
var hidden_scheme: Dictionary = {}


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

## What the model stands on: a baseplate of a size and colour, a grid
## floor, or nothing (ModelFloor). Saved with it as a meta line and read
## back; a file that says nothing gets the person's choice for new models.
## Laid by FloorLayer, which is the only thing that changes it.
var model_floor: ModelFloor = ModelFloor.preferred()

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
	# Parts on the baseplate again: whatever empties it next has to be the
	# person's doing for an empty model to be written over a file.
	if world != null and not _is_empty():
		emptied = false


## The model on screen is now what somebody meant it to be, whatever it
## was missing when it opened. Called when they place, remove or change
## a brick: after that the autosave is saving their work rather than
## overwriting their file with a worse copy of it.
func adopt() -> void:
	whole = true
	# Their own edit took the last part off.
	if world != null and _is_empty():
		emptied = true


## The baseplate is empty because the person emptied it: Clear, New, or an
## edit of theirs taking the last part off. Only then is a model of no parts
## written over a file that has parts in it ([method _write]). Anything else
## that leaves it empty (a model that opened with none of its parts, the
## catalogue not arriving, the app clearing it for its own work) is not the
## person deleting their model, and the file keeps what it had.
var emptied: bool = false


## The person cleared the baseplate (File, Clear the baseplate).
func cleared_by_person() -> void:
	emptied = true


func _is_empty() -> bool:
	return world.brick_count() - scenery.size() <= 0


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
	# A small model in one go, as before; a big one over frames.
	if world.brick_count() - scenery.size() < PACED_FROM:
		_write(autosave(), title)
		return
	_autosave_paced()


## The working model's text made a slice at a time, then written in a frame
## of its own: made and written in one, it was a frame of 512 ms in a browser
## after Brick Art laid 1,327 parts (progress_check, 2026-10-15). Not written
## when the model changed again meanwhile: the autosave after that writes it.
func _autosave_paced() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		_write(autosave(), title)
		return
	_autosaves += 1
	var mine: int = _autosaves
	_autosaving = true
	var made_at: int = _dirty_at
	var revision: int = world.revision
	var made: Array = []
	await _text_into(made, title, false, {}, FramePace.new())
	await tree.process_frame
	if mine != _autosaves:
		return
	_autosaving = false
	# The model changed while its text was made: written again, as it is now,
	# once it settles.
	if _dirty_at != made_at or world.revision != revision:
		_dirty_at = maxi(_dirty_at, Time.get_ticks_msec())
		_pending = true
		return
	_write(autosave(), title, false, str(made[0]))


## Autosaves begun, the latest the only one that may still write; and
## whether it is being made now, not yet written ([method write_now]).
var _autosaves: int = 0
var _autosaving: bool = false


## Write the working model now rather than when it settles, as a reload
## is about to take the page away (UpdateOffer). The file to wait on until
## it is stored (ModelStore.stored), or "" when there is nothing to keep.
func write_now() -> String:
	if not keeps or read_only:
		return ""
	# One being made a slice at a time is not written yet: written now, and
	# the one going let go.
	if (_pending or _autosaving) and whole:
		_pending = false
		_autosaving = false
		_autosaves += 1
		_write(autosave(), title)
	return autosave() if FileAccess.file_exists(autosave()) else ""


## Restore the working model from the last session, if there is one. How
## many of its parts come back: put down now, or on their way (on the web,
## parts not fetched yet go down as they arrive, and nothing may be opened
## over them meanwhile). 0 when there is none, or none of it can be had.
##
## Main opens the sample car when this is 0, and the car's autosave wrote
## over the working model a few seconds later: one none of whose parts were
## in this build's catalogue went for good, and nothing said so. So a model
## with parts that cannot be opened is kept first, as it was, among the
## person's models ([method _keep_unopened]).
func restore() -> int:
	unrestored = ""
	var path: String = autosave()
	if not FileAccess.file_exists(path):
		return 0
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return 0
	var result: Dictionary = open_text(text, path.get_file())
	# What is awaited is this model's only when it opened: one that did not
	# leaves the last model's there.
	var opened: bool = str(result["error"]).is_empty()
	var back: int = int(result["placed"]) + (awaited.size() if opened else 0)
	if back == 0 and count_in(text) > 0:
		_keep_unopened(text, str(result["error"]))
	return back


## What the person is told when the working model could not be opened at
## start-up and was kept ([method restore]), or "".
var unrestored: String = ""
## The working model could not be opened at start-up, and was kept: Main
## says so above the model, in [param words].
signal not_restored(words: String)


## Keep [param text], the working model that could not be opened, where the
## person finds their models (File › Open, and Download my models on the
## web), under its name and "- could not open"; or nowhere new when it is
## saved as it is already. A later build that has its parts opens it. When it
## cannot be written anywhere, this tab keeps no working model, so the file
## is not written over either.
func _keep_unopened(text: String, why: String) -> void:
	var name: String = title_in(text, "")
	if name.is_empty():
		name = "Working model"
	var kept: String = name
	var same: String = saved_path(name)
	if not FileAccess.file_exists(same) \
			or _brick_lines(FileAccess.get_file_as_string(same)) != _brick_lines(text):
		kept = unused_name("%s - could not open" % name)
		if not NewerBuild.may_write(saved_path(kept)) or not _store(saved_path(kept), text):
			keeps = false
			unrestored = ("Your last model, “%s”, could not be opened: %s. It could not be "
				+ "copied anywhere, so it is left as it was and this %s keeps nothing "
				+ "until it is reloaded.") % [name, why, "tab" if OS.has_feature("web") else "window"]
			push_warning("could not keep the working model that did not open: " + why)
			not_restored.emit(unrestored)
			return
	# As File › Open lists it: by its file's name.
	unrestored = ("Your last model, “%s”, could not be opened: %s. It is kept as it was, "
		+ "as “%s” in File › Open.") % [name, why, saved_path(kept).get_file().get_basename()]
	push_warning("the working model did not open (%s); kept as %s" % [why, saved_path(kept)])
	not_restored.emit(unrestored)


func save_as(name: String) -> bool:
	var clean: String = _safe_name(name)
	if clean.is_empty():
		return false
	if _saved_over_elsewhere(SAVE_DIR + clean + ".ldr", name):
		return false
	if _write(SAVE_DIR + clean + ".ldr", name, true):
		title = name
		# Saved by them is theirs, whatever it opened short of.
		whole = true
		example = false
		saved.emit(name)
		return true
	return false


## Write the model on the baseplate to [param path] in the person's models
## as Save writes them (kept as a version, never empty over a model with
## parts, the page told), with its build steps, and without making it the
## model's name: save_model over MCP, which names a file of its own.
func save_file(path: String, file_title: String = "Model") -> bool:
	var was: Array = [_known_path, _known_time, _known_lines]
	var ok: bool = _write(path, file_title, true)
	# Still watching the model's own file for saves from elsewhere.
	if path != saved_path(title):
		_known_path = was[0]
		_known_time = was[1]
		_known_lines = was[2]
	return ok


## The saved file the model on the baseplate is, as this tab or window last
## read or wrote it, so a save of it from another one is noticed: offered
## as a reload ([method saved_elsewhere]), and never saved over unasked.
## Saved models are the person's, shared by every tab and window on
## purpose; until 2026-10-13 one tab's Save went over another's in silence,
## and on the web the other tab's next autosave deleted it outright (the
## page's user:// sync, src/boot/shell.html).
var _known_path: String = ""
var _known_time: int = 0
var _known_lines: PackedStringArray = PackedStringArray()
## Why the last save was not made, in words, or "".
var refused: String = ""
## A save was not made because another tab or window saved this model since
## this one read it: the person is asked which to keep (Main's ReloadOffer).
signal saved_by_another(name: String)


## The file a model called [param name] is saved in.
static func saved_path(name: String) -> String:
	return SAVE_DIR + _safe_name(name) + ".ldr"


## This tab now takes [param path] to hold what is on disk: after it opened
## or wrote it, or when the person chose to keep their own over a save made
## elsewhere.
func know(path: String) -> void:
	_known_path = path
	_known_time = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0
	_known_lines = _brick_lines(FileAccess.get_file_as_string(path)) \
		if _known_time > 0 else PackedStringArray()


## Whether another tab or window saved the model on the baseplate since this
## one last read or wrote it: the file of its name now holds other bricks.
## Asked every couple of seconds (Main), which offers to reload it; true
## until the person has chosen.
func saved_elsewhere() -> bool:
	if title == UNTITLED or example or read_only:
		return false
	var path: String = saved_path(title)
	if path != _known_path:
		know(path)
		return false
	return _changed_since_known(path)


func _changed_since_known(path: String) -> bool:
	if path != _known_path or not FileAccess.file_exists(path):
		return false
	var time: int = FileAccess.get_modified_time(path)
	if time == _known_time:
		return false
	if _brick_lines(FileAccess.get_file_as_string(path)) == _known_lines:
		# Written again as it was: nothing to ask about.
		_known_time = time
		return false
	return true


## Refuses, saying why, a save over a model another tab or window saved
## since this one read it. The person is asked which to keep instead.
func _saved_over_elsewhere(path: String, name: String) -> bool:
	refused = ""
	if not _changed_since_known(path):
		return false
	refused = ("“%s” was saved in %s since this one opened it — "
		+ "reload it, or keep yours and save again") % [name, TabSession.elsewhere()]
	saved_by_another.emit(name)
	return true


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
	# Nothing in it is missing, so the autosave may keep it — empty too.
	whole = true
	emptied = true
	example = false
	# New work is not the model that was shared: publishing it must not
	# replace that one at its link, nor say it was copied from one.
	share_id = ""
	remixed_from = ""
	from_set = ""
	hidden_scheme = {}
	# Nobody's file: written whole, where it stands.
	_source = null
	_opened_in = -1
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
	if world.brick_count() - scenery.size() <= 0:
		return false
	# The model written out and compared only when there is a saved one to
	# compare it with: on Orthanc that is a third of a second, and New asks
	# this before it can ask anything else.
	if title == UNTITLED:
		return true
	var kept: String = SAVE_DIR + _safe_name(title) + ".ldr"
	if not FileAccess.file_exists(kept):
		return true
	return _brick_lines(FileAccess.get_file_as_string(kept)) != _brick_lines(to_text(UNTITLED))


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


## Whether any model is saved here: without reading each, as list_saved does.
static func any_saved() -> bool:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return false
	for file_name: String in DirAccess.get_files_at(SAVE_DIR):
		if file_name.ends_with(".ldr"):
			return true
	return false


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
		var text: String = FileAccess.get_file_as_string(entry.path)
		entry.name = title_in(text, file_name)
		entry.bricks = count_in(text)
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
		if path.begins_with(SAVE_DIR):
			know(path)
	return int(result["placed"])


## The saves of the model on the baseplate kept as versions, newest first:
## none for a model never saved (ModelVersions).
func versions() -> Array[ModelVersions.Version]:
	if title == UNTITLED or example:
		return [] as Array[ModelVersions.Version]
	return ModelVersions.of(_safe_name(title))


## Open the version at [param path] on the baseplate, as the model it is a
## version of: under its name, [param called] or the model on the
## baseplate's, so Save makes it the newest save again. How many parts
## landed; 0 when it could not be read, and nothing is changed.
func open_version(path: String, called: String = "") -> int:
	var text: String = ModelVersions.read(path)
	if text.is_empty():
		return 0
	var name: String = called if not called.is_empty() else title
	var result: Dictionary = open_text(text, name)
	if int(result["placed"]) <= 0 and awaited.is_empty():
		return 0
	# The name it is saved under, whatever its first line says.
	if title != name:
		title = name
		loaded.emit(title, int(result["placed"]))
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
	if stem.is_empty() or stem == autosave().get_file().get_basename():
		return UNTITLED
	return stem.capitalize()


## What a file's first line calls its model, read without parsing the
## rest: the examples list showed orthanc.ldr as "Orthanc" while the file,
## and so the bar, the share link and the booklet, called it Wizard's
## Tower. An MPD names its first section, then the title.
static func title_in(text: String, file_name: String) -> String:
	var named: String = title_meta_in(text.left(4096))
	if not named.is_empty():
		return named
	for line: String in text.left(4096).split("\n", false):
		var said: String = line.strip_edges()
		if said.is_empty():
			continue
		if not said.begins_with("0 ") or said.begins_with("0 FILE "):
			if said.begins_with("0 FILE "):
				continue
			break
		said = said.substr(2).strip_edges()
		if said.is_empty() or said.begins_with("!") or said.begins_with("Name:") \
				or said.begins_with("Author:") or said in ["Working model", "Model", "model",
				"Untitled Model"]:
			break
		return said
	return file_name.get_basename().capitalize()


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
	open_phases = {}
	_phase_at = Time.get_ticks_usec()
	var model: LdrModel = LdrModel.parse(text, name)
	_phase("parse")
	if model == null:
		return {"placed": 0, "missing": 0, "error": "that is not an LDraw file"}
	# Parts the file brought with it, made here or somewhere else, join
	# the library before anything asks whether the library has them.
	var carried: Dictionary = CustomParts.take_from(library, model)
	for problem: String in carried["problems"]:
		push_warning("could not build a part the file carries: " + problem)
	_phase("carried")

	var flattened: Array = model.flatten(library.parts)
	_phase("flatten")
	# The author's steps go on to every part; steps Brickworks worked out
	# and wrote are no one's, and are worked out again (LdrModel).
	var authored: bool = model.steps_are_authored()
	# A mirrored copy's parts: each put where its reflection is, in its
	# other hand where it has one.
	var mirrored_lines: Dictionary = {}
	for item: Variant in flattened:
		var placement: LdrModel.Placement = item
		if not authored:
			placement.step = -1
		placement.part_id = studio_part(placement.part_id)
		if placement.mirrored:
			mirrored_lines["%d|%s" % [placement.line, placement.unit]] = true
			Assemblies.unmirror(placement, library)
		# A retired number as the part it became, where its stub puts it
		# (PartLibrary.moved_by), before the lift is worked out from it and
		# before it waits for geometry by the right name.
		var real: String = library.resolve(placement.part_id)
		if real != placement.part_id:
			placement.transform = placement.transform * library.moved_by(placement.part_id)
			placement.part_id = real
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

	_phase("known")
	if known.is_empty():
		return {"placed": 0, "missing": missing.size(), "waiting": 0,
			"missing_ids": missing,
			"error": "none of the %d parts in that file are in the library (%s)"
				% [missing.size(), named_counts(missing)]}

	# Someone else's file is kept, so a save writes back what nobody changed
	# as it was (SourceFile); the app's own are written whole, as always.
	# Made before the model is stood on the ground: the file's coordinates.
	var source: SourceFile = SourceFile.make(text, model, known, mirrored_lines, authored,
		flattened.filter(func(p: LdrModel.Placement) -> bool:
			return not library.parts.has(p.part_id))) \
		if model.author.strip_edges() != "Brickworks" else null
	_phase("source")

	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	scenery.clear()
	awaited.clear()
	_phase("clear")
	_source = source
	_opened_in = world.generation()
	# What the file holds that is not on the baseplate: kept in it, and said.
	unshown = missing.duplicate()
	if source != null and not missing.is_empty():
		unshown = source.unshown(flattened.filter(func(p: LdrModel.Placement) -> bool:
			return not library.parts.has(p.part_id)))

	# Each sub-model copy's step in the one that places it, by its path.
	if authored:
		world.unit_steps = model.unit_steps.duplicate()
	# Stood on the ground before anything is placed, from every part in it;
	# and brought down onto it, when another tool drew it up in the air.
	var up: Vector3 = lift_for(known, model.author.strip_edges() != "Brickworks")
	_phase("lift")
	# A turned part's cover is the slow half of putting it down, and depends
	# on nothing but the part and its turn: all of them set going at once,
	# first, and worked out while the parts are drawn.
	builder.prepare_covers(known)
	_phase("covers")
	var placed: int = 0
	var down: Array[int] = []
	for item: Variant in known:
		var placement: LdrModel.Placement = item
		placement.transform.origin += up
		# Asked for first: on the desktop the geometry is read from disk
		# when it is asked for, and only a part that still has none is
		# waited for.
		var brick_id: int = world.add_brick(
			placement.part_id, placement.color_code, placement.transform)
		down.append(brick_id)
		if brick_id == 0:
			awaited.append(placement)
			continue
		world.get_brick(brick_id).group = placement.group
		world.get_brick(brick_id).unit = placement.unit
		world.get_brick(brick_id).step = placement.step
		placed += 1
	_phase("draw")
	# Then the lattice told of each, in the same order, once the covers are in.
	builder.finish_covers()
	_phase("covered")
	for n: int in known.size():
		if down[n] != 0:
			var placement: LdrModel.Placement = known[n]
			builder.register(down[n], placement.part_id, placement.transform)
	_awaited_in = world.generation()
	_phase("place")

	# Ask for the ones that were not to hand, and put each down as it
	# arrives (place_awaited).
	var asked: Dictionary = {}
	for placement: LdrModel.Placement in awaited:
		if not asked.has(placement.part_id):
			asked[placement.part_id] = true
			library.request_mesh(placement.part_id, true)

	_missing_at_open = missing.size()
	whole = missing.is_empty() and awaited.is_empty()
	# A model from a file: nobody emptied the baseplate.
	emptied = false
	title = _title_of(model, name)
	if source != null:
		source.own_title = title
		var named: String = title_meta_in(text)
		if not named.is_empty():
			title = named
	share_id = share_in(text)
	remixed_from = remix_in(text)
	var said: ModelFloor = ModelFloor.read(text)
	model_floor = said if said != null else ModelFloor.preferred()
	from_set = set_in(text)
	hidden_scheme = HiddenColours.read(text)
	example = false
	_phase("meta")
	loaded.emit(title, placed)
	_phase("loaded")
	return {"placed": placed, "missing": missing.size(),
		"waiting": waiting.size(), "missing_ids": missing, "error": "",
		"unshown": unshown, "kept": source != null}


## What the last [method open_text] spent, phase by phase, in ms, in order:
## parse, carried, flatten, known, source, clear, lift, covers (set going),
## draw (the world), covered (waiting for the covers), place (the lattice),
## meta and the store's own [signal loaded] handlers (bigmodel_probe --open
## says it).
var open_phases: Dictionary = {}
var _phase_at: int = 0


func _phase(name: String) -> void:
	var now: int = Time.get_ticks_usec()
	open_phases[name] = (now - _phase_at) / 1000.0
	_phase_at = now


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


## The file the model on the baseplate was opened from, when it is someone
## else's (SourceFile): a save writes it back with only what changed. Null
## for a model made here or saved by Brickworks, which is written whole.
## Only while the world is the one it was opened into ([member _opened_in]).
var _source: SourceFile = null
var _opened_in: int = -1
## Parts the file holds that are not on the baseplate, by number, how many
## of each: not in the library, or a flexible part's skin. Kept in the file
## when it is someone else's, and said when it opens.
var unshown: Dictionary = {}
const TITLE_META := "0 !BRICKWORKS TITLE "


## The source the model on the baseplate is still the model of, or null.
func _live_source() -> SourceFile:
	if _source == null or world == null or world.generation() != _opened_in:
		return null
	return _source


## How far the model on the baseplate was moved to stand on the ground when
## it opened: taken off again when it is written, so the file keeps its
## coordinates. Zero for a model made here.
func _lift_now() -> Vector3:
	if world == null or world.generation() != _opened_in:
		return Vector3.ZERO
	return Vector3(0.0, _lifted_by, 0.0)


## The source file with the model on the baseplate written into it, or null
## when there is none or the change cannot be written into it as it is.
func _source_text(title_now: String) -> Variant:
	var source: SourceFile = _live_source()
	if source == null:
		return null
	var bricks: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		# A section broken out is written where it was pulled from: its
		# parts as they stand there (BrickWorld.home_of).
		if not world.broken_out.is_empty():
			var home := BrickWorld.Brick.new(brick.id, brick.part_id, brick.color_code,
				world.home_of(brick))
			home.group = brick.group
			home.unit = brick.unit
			home.step = brick.step
			home.hidden = brick.hidden
			bricks.append(home)
			continue
		bricks.append(brick)
	var waiting: Dictionary = {}
	if world.generation() == _awaited_in:
		for placement: LdrModel.Placement in awaited:
			waiting["%d|%s" % [placement.line, placement.unit]] = true
	var written: Variant = source.write(bricks, _lift_now(), waiting, library,
		world.unit_steps if source.authored else {})
	if written == null:
		return null
	var text: String = _without_app_lines(str(written))
	if title_now != source.own_title and not title_now.is_empty():
		text = _after_first_line(text, TITLE_META + title_now)
	return text


## [param text] without the lines this app writes again on every save.
static func _without_app_lines(text: String) -> String:
	if not text.contains("0 !BRICKWORKS "):
		return text
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with(SHARE_META) or line.begins_with(REMIX_META) \
				or line.begins_with(TITLE_META):
			continue
		kept.append(line)
	return "\n".join(kept)


static func _after_first_line(text: String, line: String) -> String:
	var cut: int = text.find("\n")
	if cut < 0:
		return text + "\n" + line + "\n"
	return text.substr(0, cut + 1) + line + "\n" + text.substr(cut + 1)


## The name a save of someone else's file gave its model, or "".
static func title_meta_in(text: String) -> String:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS TITLE (.+?)\\s*$").search(text)
	return found.get_string(1) if found != null else ""


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
			world.get_brick(brick_id).step = placement.step
			builder.register(brick_id, placement.part_id, placement.transform)
			landed += 1
	awaited = still
	if awaited.is_empty():
		_settle()
	whole = awaited.is_empty() and _missing_at_open == 0
	return landed


## How far the model was lifted when it opened, and whether that was worked
## out without the geometry of a turned part that could be the lowest: on
## the web, where a part outside the pack is fetched after the model opens.
var _lifted_by: float = 0.0
var _lift_unsure: bool = false
var _lowers: bool = false


## Once every part has arrived, the model down to where it stands by its
## parts' shapes, if the lift it opened with stood it on a turned part's box
## instead. The same height as a desktop, which has every part's geometry,
## stands it at; done before the model is whole, so it is the height saved.
func _settle() -> void:
	if not _lift_unsure:
		return
	_lift_unsure = false
	# The model's, not the baseplate laid under it.
	var standing: Array = []
	var model: Array[BrickWorld.Brick] = []
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			standing.append([brick.part_id, brick.transform])
			model.append(brick)
	var now: float = lowest_of(standing)
	if now == INF or _lift_unsure:
		_lift_unsure = false
		return
	var by: float = _lift_from(now - _lifted_by, _lowers) - _lifted_by
	if absf(by) < 0.001:
		return
	_lifted_by += by
	for brick: BrickWorld.Brick in model:
		var to: Transform3D = brick.transform.translated(Vector3(0.0, by, 0.0))
		builder.lattice.release(brick.id)
		world.move_brick(brick.id, to)
		builder.register(brick.id, brick.part_id, to)


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
## Except a part turned off the grid, whose box hangs below it wherever it
## does not fill the box (Lbm.PartMesh.lowest_at): a model on its wheels,
## drawn spun on their axles, stood on their boxes 12 LDU up. That is
## measured by the part's geometry, and where that has not arrived yet the
## box stands in until it has (_settle).
##
## With [param lower] a model drawn up in the air comes down onto the ground
## as well: a file another tool wrote, whose origin is that tool's. One this
## app saved keeps the height it was saved at, as it always has.
func lift_for(placements: Array, lower: bool = false) -> Vector3:
	var pairs: Array = []
	for item: Variant in placements:
		var placement: LdrModel.Placement = item
		pairs.append([placement.part_id, placement.transform])
	_lift_unsure = false
	_lowers = lower
	_lifted_by = _lift_from(lowest_of(pairs), lower)
	return Vector3(0.0, _lifted_by, 0.0)


## How far up a model whose lowest point is [param lowest] comes: to the
## next whole cell, so what stood on the lattice still does. And with
## [param lower], down by whole cells when it is drawn up in the air: a file
## from another tool has its origin wherever that tool put it, and 30285's
## dinosaur, drawn 21 LDU above the ground and stood there held by nothing,
## was called floating in every part. Within a cell of the ground it stays.
static func _lift_from(lowest: float, lower: bool = false) -> float:
	if lowest == INF:
		return 0.0
	if lowest < -0.001:
		return ceilf(-lowest / BrickLattice.CELL - 0.001) * BrickLattice.CELL
	if lower and lowest >= BrickLattice.CELL - 0.001:
		return -floorf((lowest + 0.001) / BrickLattice.CELL) * BrickLattice.CELL
	return 0.0


## The lowest point of these parts, [part id, Transform3D] each, in LDU. By
## the catalogue's boxes, lowest first, and by its geometry for a turned
## part whose box reaches lower than anything found so far: a box is never
## above the part in it, so a part whose box does not reach that low cannot
## be lower, and only the few parts at the bottom are measured. A turned
## part whose geometry is not to hand is taken at its box, and the lift is
## then unsure ([member _lift_unsure]).
func lowest_of(pairs: Array) -> float:
	var rows: Array = []   ## [how low the box reaches, part id, transform, exact]
	for pair: Array in pairs:
		var info: PartLibrary.PartInfo = library.parts.get(str(pair[0]))
		if info == null:
			continue
		var at: Transform3D = pair[1]
		var box: AABB = at * info.bounds
		# A baseplate stands with its top on the ground, as the one laid
		# under every model does, not its underside: a model saved with its
		# own plate came back four LDU higher than it went, every part on
		# the plate off the lattice the ground is laid on.
		if info.category == "Baseplate" and FloorLayer.is_upright(at):
			rows.append([box.end.y - FloorLayer.STUD_HIGH, "", at, true])
		else:
			rows.append([box.position.y, str(pair[0]), at,
				BrickLattice.is_square_to_grid(at.basis.orthonormalized())])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var lowest: float = INF
	for row: Array in rows:
		if float(row[0]) >= lowest:
			break
		if bool(row[3]):
			lowest = float(row[0])
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(str(row[1]))
		if mesh == null:
			_lift_unsure = true
			lowest = float(row[0])
			continue
		lowest = minf(lowest, mesh.lowest_at(row[2]))
	return lowest


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
##
## A model with the author's steps (AuthorSteps) always writes them, the
## autosave too, since they are the model's and cost nothing to write;
## and says so in the file, so they are kept when it is opened again.
func to_text(title: String = "Model", with_steps: bool = false,
		worked: Dictionary = {}) -> String:
	var made: Array = []
	_text_into(made, title, with_steps, worked, null)
	return str(made[0])


## [method to_text] into [param made]; a slice at a time with a
## [param pace] (the autosave's).
func _text_into(made: Array, title: String, with_steps: bool, worked: Dictionary,
		pace: FramePace) -> void:
	## brick id -> which step it belongs to, and each sub-assembly copy's
	## path -> the step it goes on in.
	var step_of: Dictionary = {}
	var unit_steps: Dictionary = {}
	# Someone else's file: written back as it was, with what changed.
	var from_source: Variant = _source_text(title)
	if from_source != null:
		var kept: String = str(from_source)
		kept = model_floor.written_into(kept) if model_floor != null else kept
		kept = HiddenColours.written_into(kept, hidden_scheme)
		made.append(kept if set_in(kept) == from_set else with_set(kept, from_set))
		return
	# A section broken out is written where it was pulled from: the whole
	# file, frames and steps, from the model as built (BrickWorld.home_of).
	var model: BrickWorld = world if world.broken_out.is_empty() else world.copy_at_home()
	var authored: bool = AuthorSteps.any(model, scenery)
	if not worked.is_empty() and not authored:
		step_of = worked["bricks"]
		unit_steps = worked["units"]
	elif authored or (with_steps and world.library != null):
		var numbers: Dictionary = AuthorSteps.numbers_for_file(model, world.library,
			scenery, with_steps) if authored \
			else AuthorSteps.numbers_from_plan(model, world.library, scenery)
		step_of = numbers["bricks"]
		unit_steps = numbers["units"]

	# In the file's coordinates, not where the model was stood for the view.
	var back := Transform3D(Basis.IDENTITY, -_lift_now())
	var placements: Array = []
	for item: Variant in model.bricks():
		if pace != null and pace.due():
			await pace.next()
		var brick: BrickWorld.Brick = item
		if model.get_brick(brick.id) != brick or scenery.has(brick.id):
			continue
		var placement := LdrModel.Placement.new(
			brick.part_id, brick.color_code, back * brick.transform,
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
	#
	# Sorted by a key each, compared by the engine: the same order as a
	# comparison written out here, which took a quarter of a second of
	# Orthanc's every save, export and autosave.
	if pace != null:
		await pace.next()
	placements = _in_file_order(placements)
	if pace != null and pace.due():
		await pace.next()
	# A made part goes out inside the file, or the file means nothing
	# anywhere the part was not made.
	var used: Dictionary = {}
	for item: Variant in placements:
		used[(item as LdrModel.Placement).part_id] = true
	var embedded: Dictionary = CustomParts.sources_for(library, used.keys())
	# Sub-assemblies, nested or copied, go out as a tree of sub-models: each
	# definition once, every copy a reference to it (LdrModel.write_tree).
	var tree := Assemblies.new()
	tree.world = model
	tree.builder = builder
	tree.library = library
	tree.scenery = scenery
	var figures: Dictionary = figure_frames(model)
	var instances: Dictionary = tree.file_frames(figures)
	if pace != null and pace.due():
		await pace.next()
	# Every frame moved with the parts, so each part is where it was in it.
	for path: Variant in instances:
		var entry: Dictionary = instances[path]
		entry["frame"] = back * (entry["frame"] as Transform3D)
	for group: Variant in figures:
		figures[group] = back * (figures[group] as Transform3D)
	var known: Dictionary = library.parts if library != null else {}
	var text: String = LdrModel.write_tree(placements, title, "Brickworks", instances, embedded,
		unit_steps, known) if not instances.is_empty() \
		else LdrModel.write_ldr(placements, title, "Brickworks", figures, embedded, known)
	if authored:
		text = with_authored_steps(text)
	# Someone else's model written whole: still theirs, under their terms,
	# its steps still no one's when Brickworks worked them out.
	if _live_source() != null:
		text = _with_header(text, _live_source().header(), authored)
		# And what it holds that is not on the baseplate, kept.
		var waiting: Array = []
		if world.generation() == _awaited_in:
			for placement: LdrModel.Placement in awaited:
				var held := LdrModel.Placement.new(placement.part_id, placement.color_code,
					Transform3D(Basis.IDENTITY, -_lift_now()) * placement.transform,
					placement.step)
				held.unit = placement.unit
				held.line = placement.line
				waiting.append(held)
		text = _live_source().carried_into(text, waiting)
	# What it stands on goes with it, everywhere it goes: the autosave, a
	# save, an export, a shared link. Another program reads past the line.
	text = model_floor.written_into(text) if model_floor != null else text
	text = HiddenColours.written_into(text, hidden_scheme)
	if model != world:
		model.free()
	made.append(with_set(text, from_set))


## [param text], written whole, under [param header] (SourceFile.header)
## in place of its own author line.
static func _with_header(text: String, header: PackedStringArray, authored: bool) -> String:
	if header.is_empty():
		return text
	var at: int = text.find("\n0 Author: Brickworks\n")
	if at < 0:
		return text
	var lines: PackedStringArray = header.duplicate()
	if not authored:
		lines.append(LdrModel.WORKED_META)
	var rest: String = text.substr(at + "\n0 Author: Brickworks\n".length())
	# Each sub-model under the author's name too: the model is still theirs.
	for line: String in header:
		if line.begins_with("0 Author:"):
			rest = rest.replace("\n0 Author: Brickworks\n", "\n" + line + "\n")
			break
	return text.substr(0, at + 1) + "\n".join(lines) + "\n" + rest


## [param text] with the set it came from on a line after its first.
static func with_set(text: String, number: String) -> String:
	if number.is_empty() or text.contains(SET_META):
		return text
	var cut: int = text.find("\n")
	if cut < 0:
		return text + "\n" + SET_META + number + "\n"
	return text.substr(0, cut + 1) + SET_META + number + "\n" + text.substr(cut + 1)


## The real set a model's text is, or empty: its own line, else the
## LDraw model repository's header ("0 !LDRAW_ORG Model", "0 Name: 10182 -
## Main Model.ldr"), read from the head of the file only.
static func set_in(text: String) -> String:
	var kept: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS FROM_SET ([0-9A-Za-z-]{1,20})\\s*$").search(text)
	if kept != null:
		return kept.get_string(1)
	var head: String = text.left(4000)
	if not RegEx.create_from_string("(?m)^0 !LDRAW_ORG (Unofficial_)?Model\\b").search(head):
		return ""
	var named: RegExMatch = RegEx.create_from_string(
		"(?m)^0 Name:\\s*([0-9]{3,7}(-[0-9]+)?)").search(head)
	return named.get_string(1) if named != null else "set"


## [method to_text] with the build order, for a save or an export: on a big
## model the order is worked out a slice at a time (Instructions.plan_paced)
## with [param job] counting it, and the page goes on drawing.
##
## Worked out in one go, it held a browser for seconds on Orthanc: "when I
## clicked 'Save and then new' it seemingly froze the app" (the owner,
## 2026-10-13). "" when the job was cancelled.
func to_text_paced(title: String, job: Working.Job) -> String:
	if not paces():
		return to_text(title, true)
	var steps: Array[Instructions.Step] = await Instructions.plan_paced(
		world, world.library, scenery, {}, job)
	if job.cancelled or steps.is_empty():
		return ""
	job.say("Writing %s parts…" % Working.comma(world.brick_count() - scenery.size()))
	job.count(0, 0)
	await job.next()
	return to_text(title, true, AuthorSteps.numbers_of(world, steps, scenery))


## A model this big has its build order worked out a slice at a time when
## it is saved or exported; a smaller one in one go, as before.
const PACED_FROM := 300


## Whether this model's build order is worked out a slice at a time.
func paces() -> bool:
	return not AuthorSteps.any(world, scenery) and world.library != null \
		and world.brick_count() - scenery.size() >= PACED_FROM \
		and _source_text(title) == null


## The model's text with its build order, for an export or a share: on a
## big model worked out a slice at a time, the status bar saying
## [param doing] and counting, with Cancel ([method to_text_paced]). ""
## when it was cancelled.
func text_for_file(title: String, doing: String) -> String:
	if not paces():
		return to_text(title, true)
	var job: Working.Job = Working.begin(doing, 0, true)
	await job.shown()
	var text: String = await to_text_paced(title, job)
	job.end()
	return "" if job.cancelled else text


## [method save_as], its build order worked out a slice at a time
## ([method to_text_paced]). False when it was not saved, cancelled too.
func save_as_paced(name: String, job: Working.Job) -> bool:
	var clean: String = _safe_name(name)
	if clean.is_empty():
		return false
	if _saved_over_elsewhere(SAVE_DIR + clean + ".ldr", name):
		return false
	var text: String = await to_text_paced(name, job)
	if text.is_empty() or job.cancelled:
		return false
	if _write(SAVE_DIR + clean + ".ldr", name, true, text):
		title = name
		whole = true
		example = false
		saved.emit(name)
		return true
	return false


## [param placements] in the order a file lists them: by step, then height,
## group, part, across, along and colour. Heights a hair apart are one
## height: rounded to a thousandth of an LDU, finer than any part sits.
static func _in_file_order(placements: Array) -> Array:
	var keys: Array = []
	keys.resize(placements.size())
	for n: int in placements.size():
		var placement: LdrModel.Placement = placements[n]
		var at: Vector3 = placement.transform.origin
		keys[n] = [placement.step, roundi(at.y * 1000.0), placement.group,
			placement.part_id, roundi(at.x * 1000.0), roundi(at.z * 1000.0),
			placement.color_code, n]
	keys.sort()
	var ordered: Array = []
	ordered.resize(keys.size())
	for n: int in keys.size():
		ordered[n] = placements[int((keys[n] as Array)[7])]
	return ordered


## [param text] saying its steps are its author's, under the model's own
## header (after its Author line), where LdrModel looks for it.
static func with_authored_steps(text: String) -> String:
	var at: int = text.find("\n0 Author: ")
	var cut: int = text.find("\n", at + 1) if at >= 0 else text.find("\n")
	if cut < 0:
		return text + "\n" + LdrModel.AUTHORED_META + "\n"
	return text.substr(0, cut + 1) + LdrModel.AUTHORED_META + "\n" + text.substr(cut + 1)


## Each minifigure in the model, by its group, and the frame it stands
## in: so a figure goes out as a sub-model of its own, standing at its
## origin and placed where it stands, the way real sets' files keep them.
func figure_frames(from: BrickWorld = null) -> Dictionary:
	var members: Dictionary = {}
	for brick: BrickWorld.Brick in (from if from != null else world).bricks():
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
	return _export_text(path, to_text(title, true))


## [method export_to] from a person's press: a big model's build order
## worked out a slice at a time, said and counted ([method text_for_file]).
## False when it was cancelled or not written.
func export_paced(path: String, title: String = "Model") -> bool:
	var text: String = await text_for_file(title, "Exporting %s…" % path.get_file())
	return not text.is_empty() and _export_text(path, text)


func _export_text(path: String, text: String) -> bool:
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


func _write(path: String, title: String, with_steps: bool = false,
		written: String = "") -> bool:
	if read_only:
		return false
	# A newer build is live: this tab stores nothing outside its own session
	# until it reloads (NewerBuild), so a save there is refused, saying why.
	if not NewerBuild.may_write(path):
		refused = NewerBuild.REFUSAL
		return false
	var text: String = with_share(written if not written.is_empty()
		else to_text(title, with_steps), share_id, remixed_from)
	# Never a model of no parts over a file that has some, unless the person
	# emptied the baseplate ([member emptied]). The autosave fires on its
	# own a few seconds after any change, so whatever left the baseplate
	# bare, it wrote that over the model it had.
	if not emptied and not _has_parts(text) and FileAccess.file_exists(path) \
			and _count_bricks(path) > 0:
		refused = ("Not saved: there are no parts on the baseplate, and “%s” has %d. "
			% [title, _count_bricks(path)]
			+ "Clear the baseplate first if it is meant to be empty.")
		push_warning("kept %s: refused to write a model of no parts over it" % path)
		return false
	return _store(path, text)


## [param text] written to [param path] as it is, the page told; in the
## person's models, kept as a version too.
func _store(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	_tell_page_wrote(path, text.to_utf8_buffer().size())
	if path.begins_with(SAVE_DIR):
		know(path)
		# Each save kept as a version too, the last 20 (File, Versions…).
		var kept: String = ModelVersions.keep(path.get_file().get_basename(), text)
		if not kept.is_empty():
			_tell_page_wrote(kept, FileAccess.get_file_as_bytes(kept).size())
		# A browser asked to keep the person's models, now that there are some.
		StorageKeep.ask()
	return true


## Whether LDraw [param text] places anything: a line of type 1 anywhere.
## Read without parsing it, since the autosave asks on every write.
static func _has_parts(text: String) -> bool:
	return text.begins_with("1 ") or text.find("\n1 ") >= 0


## [param text] with the link it is shared at and the link it was copied
## from, each on a line after its first (inside the model itself, for an
## .mpd); as it is for neither.
static func with_share(text: String, id: String, remix: String = "") -> String:
	var lines: String = (SHARE_META + id + "\n" if not id.is_empty() else "") \
		+ (REMIX_META + remix + "\n" if not remix.is_empty() else "")
	if lines.is_empty():
		return text
	var cut: int = text.find("\n")
	if cut < 0:
		return text + "\n" + lines
	return text.substr(0, cut + 1) + lines + text.substr(cut + 1)


## The link a model's text says it is shared at, or empty.
static func share_in(text: String) -> String:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS SHARE ([A-Za-z0-9]{10})\\s*$").search(text)
	return found.get_string(1) if found != null else ""


## The link a model's text says it was copied from, or empty.
static func remix_in(text: String) -> String:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS REMIX ([A-Za-z0-9]{10})\\s*$").search(text)
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
