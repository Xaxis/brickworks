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
## And which version of that link it was copied from (api/share.js), or 0
## when it is not a copy or was copied before links had versions: its page
## says "remixed from X, version 2". On a line of its own, so a build from
## before it still reads the link.
var remixed_from_version: int = 0
const REMIX_VERSION_META := "0 !BRICKWORKS REMIX_VERSION "
## The real set this model was opened from ("10182"), or empty: a file of
## the LDraw model repository says so in its header, and a model saved
## from one carries it on as a meta line. HiddenColours asks before it
## recolours a set's parts.
var from_set: String = ""
const SET_META := "0 !BRICKWORKS FROM_SET "
## Who made this model and on what terms, when it came from someone else:
## {by, licence, page, from}, as the library (ModelLibrary.credit_of) or the
## gallery (Main._maybe_copy) said it; empty for the person's own. Kept the
## same way as [member share_id], and shown in Properties with nothing
## selected (Inspector).
var credit: Dictionary = {}
const CREDIT_META := "0 !BRICKWORKS CREDIT "
## The hidden parts' colours chosen for this model (HiddenColours.Plan
## .scheme), for the booklet to show; empty when none were.
var hidden_scheme: Dictionary = {}
## Comments pinned to its parts (PinnedComments), kept in its file.
var pins: PinnedComments = PinnedComments.new()
## The sets whose parts the bin is built from for this model (SetBin), or
## none. Kept with its saves and the autosave as the app's other lines are
## (SetBin.META), never in what is published or exported; a model opened
## says it again, and a new one keeps the bin it was begun with.
var bin_sets: PackedStringArray = PackedStringArray()
## The picture to build over (Make, Reference picture…), as ReferenceImage
## keeps it: {on, at, width, opacity, locked, name, picture}, or empty for
## none. Kept with its saves and the autosave as the app's other lines are
## (ReferenceImage.META), never in what is published or exported: it is the
## person's to trace, not part of the model.
var reference: Dictionary = {}
## Who laid its parts, as far as this app knows (2026-10-24): "hand" for a
## model begun empty here with every part laid by a person, "assistant"
## once Claude laid any (the panel's designer, a session's tools), and
## "brickify" once Brickify did and Claude never; empty for a model that
## came from a file or a link saying nothing, which nobody here can vouch
## for. Sent when it is published, so its card says Hand-built or With the
## assistant from the app and not from its tags (docs/SOCIAL.md D7, U16).
## Kept the same way as [member share_id], and once said it stays said: a
## part taken off again was still laid.
var made_with: String = "hand"
const MADE_META := "0 !BRICKWORKS MADE "
## The ways [member made_with] says, the strongest last: the assistant over
## Brickify over a person's hands.
const MADE_WAYS: Array[String] = ["hand", "brickify", "assistant"]


class Entry extends RefCounted:
	var name: String
	var path: String
	var bricks: int
	var modified: int       ## unix seconds
	## An example that ships with the app rather than something this
	## person saved. Read-only in practice: opening one and saving writes
	## a copy of their own.
	var example: bool = false

	## "Harbour Tug — 253 bricks, today at 07:48:46": saved when this
	## computer's clock says, as File, Versions… says it. It said the time in
	## UTC, 15:48:46 for a save at 07:48 in Alaska (walk180, D4).
	func describe() -> String:
		if example:
			return "%s — %d bricks" % [name, bricks]
		return "%s — %d bricks, %s" % [name, bricks, ModelVersions.when_saved(modified)]


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
## The autosave holds the model as it stands: written since the last change.
var _autosave_is_model: bool = false

signal saved(name: String)
## A file of the person's models was written, by Save or a session's
## save_model: the account is sent it too (CloudModels).
signal kept_save(path: String)
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
	_autosave_is_model = false
	# Told of every change up to now: the watch ([method _hear]) takes up
	# from here, and does not hear the same change again a frame later. It
	# did, and each time pushed the write back, so an autosave that was due
	# was not written then: a restore right after opened the one before,
	# under its name, not this model's (project_probe on m99, 2026-10-20).
	if not _heard.is_empty() and world != null:
		_heard = _model_now()
	# Parts on the baseplate again: whatever empties it next has to be the
	# person's doing for an empty model to be written over a file.
	if world != null and not _is_empty():
		emptied = false


## The model on screen is now what somebody meant it to be. Called when
## they place, remove or change a brick: their own edit taking the last
## part off is them emptying it ([member emptied]).
func adopt() -> void:
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
	# Nothing is left of whoever laid what was there.
	made_with = "hand"


## [param way], "assistant" or "brickify", laid parts in this model: the
## assistant's says so for good, Brickify's unless the assistant's had, and
## a model nobody could vouch for is now at least that.
func laid_by(way: String) -> void:
	if way != "hand" and MADE_WAYS.find(way) > MADE_WAYS.find(made_with):
		made_with = way


func _is_empty() -> bool:
	return world.brick_count() - scenery.size() <= 0


## From now on, every change to the model is kept, whoever made it: Main
## calls this once the model the window opens with is down, which is written
## only where Main says (a restore is not written back as it was read).
##
## Every change, and not only the ones somebody remembered to tell the store
## about (touch). A minifigure stood up by a Claude session, and one stood
## up by the in-app assistant, went down past the builder's signals
## (Builder.put_figure), so nothing told the store, and a reload took them
## away (tabwalk, 2026-10-19). Whatever changes the model moves the world's
## revision (a part put down, taken off, moved, painted) or the builder's
## history (a part's sub-model or step, an undo of either), so those are
## what [method tick] watches.
func listen() -> void:
	_heard = _model_now()


## [method _model_now] as [method tick] last heard it; empty before
## [method listen].
var _heard: Array = []


## What says the model changed: the world's revision, the history's depth,
## and its newest step (the same dictionary until another is kept, undone or
## redone).
func _model_now() -> Array:
	var newest: Variant = null
	if builder != null and builder.history_depth() > 0:
		newest = builder.last_step()
	return [world.revision, builder.history_depth() if builder != null else 0, newest]


## A change nobody told the store of ([method touch]), told now: what
## moved the world's revision or the history since it last heard.
func _hear() -> void:
	if _heard.is_empty() or world == null:
		return
	var now: Array = _model_now()
	if now[0] != _heard[0] or now[1] != _heard[1] or not is_same(now[2], _heard[2]):
		touch()


## Call once a frame. Writes the working model when it has settled.
func tick() -> void:
	# Heard once it is whole: what is down of a model being laid is not it.
	if laying:
		return
	_hear()
	if not _pending or not keeps:
		return
	if Time.get_ticks_msec() - _dirty_at < AUTOSAVE_DELAY_MS:
		return
	_pending = false
	# A model short of parts is written too, and loses none of them: what
	# has not arrived, could not be fetched or is not in the catalogue goes
	# out where the file had it (_text_into). On the web most geometry is
	# fetched rather than shipped, and the autosave fires a second after the
	# open, while the fetches are in flight. Writing the model without them
	# turned a few seconds of network into a permanent deletion, so until
	# 2026-10-20 a model short of a part was not written at all: one part
	# that never came, and nothing done after was kept.
	# A small model in one go, as before; a big one over frames, and any
	# model while others build in it (Together sets [member paced_always]):
	# their changes keep coming, and each written in one frame held both
	# sides' windows for that frame after every change.
	if world.brick_count() - scenery.size() < PACED_FROM and not paced_always:
		var began: int = Time.get_ticks_usec()
		_autosave_is_model = _write(autosave(), title)
		last_write_ms = (Time.get_ticks_usec() - began) / 1000.0
		return
	_autosave_paced()


## Write the autosave over frames whatever the model's size (Together, while
## a session is live). And how long the last autosave held its frame, in ms.
var paced_always: bool = false
var last_write_ms: float = 0.0


## The working model's text made a slice at a time, then written in a frame
## of its own: made and written in one, it was a frame of 512 ms in a browser
## after Brick Art laid 1,327 parts (progress_check, 2026-10-15). Not written
## when the model changed again meanwhile: the autosave after that writes it.
func _autosave_paced() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		_autosave_is_model = _write(autosave(), title)
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
	_autosave_is_model = _write(autosave(), title, false, str(made[0]))


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
	# Half a model being laid is not written over the working model.
	if laying:
		return autosave() if FileAccess.file_exists(autosave()) else ""
	# A change made this frame, before the watch has had its turn.
	_hear()
	# One being made a slice at a time is not written yet: written now, and
	# the one going let go.
	if _pending or _autosaving:
		_pending = false
		_autosaving = false
		_autosaves += 1
		_autosave_is_model = _write(autosave(), title)
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
	var text: String = _autosaved()
	return _restored(text, open_text(text, autosave().get_file())) if not text.is_empty() else 0


## [method restore], once what the parts the model carries are drawn from has
## been fetched, where this build has not got it (on the web: [method
## open_text_fetched]). What the app does at start-up.
func restore_fetched() -> int:
	var text: String = _autosaved()
	if text.is_empty():
		return 0
	return _restored(text, await open_text_fetched(text, autosave().get_file()))


## The working model's text from the last session, or "". "" too for one
## with no parts, which is begun again as it was left, under its name
## ([member left_empty]).
func _autosaved() -> String:
	unrestored = ""
	left_empty = false
	var path: String = autosave()
	var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if text.is_empty() or _has_parts(text):
		return text
	var name: String = title_in(text, "")
	# A picture laid to build over comes back with it: the first thing a
	# person tracing a plan does, before any part.
	_begin_as(name if not name.is_empty() else UNTITLED, ReferenceImage.read(text))
	left_empty = true
	return ""


## The working model came back with no parts because it had none: the
## person left the baseplate empty (New, Clear, the last part taken off), or
## the tab was opened by New tab. Main shows it so, not the sample car a
## first visit is shown, which is what a reload after New brought back.
var left_empty: bool = false


## How many parts of [param text], opened as [param result], came back, the
## model kept first when none could be ([method restore]).
func _restored(text: String, result: Dictionary) -> int:
	# What is awaited is this model's only when it opened: one that did not
	# leaves the last model's there.
	var opened: bool = str(result["error"]).is_empty()
	# Nowhere else but the autosave, perhaps never saved.
	if opened:
		_opened_whole = -1
		_autosave_is_model = true
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
		if ok:
			_saved_as = path
	return ok


## The last file [method save_file] wrote that is not the title's own: the
## model as it stands there is saved work ([method has_unsaved_work]).
var _saved_as: String = ""


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
	_begin_as(UNTITLED if wanted.is_empty() or wanted == UNTITLED else _free_name(wanted))


## [method begin] under [param named] as it is, with the picture to build
## over [param picture] keeps (ReferenceImage.read), or none.
func _begin_as(named: String, picture: Dictionary = {}) -> void:
	title = named
	# Begun empty by the person: the autosave may keep it so.
	emptied = true
	example = false
	# New work is not the model that was shared: publishing it must not
	# replace that one at its link, nor say it was copied from one.
	share_id = ""
	remixed_from = ""
	remixed_from_version = 0
	credit = {}
	from_set = ""
	hidden_scheme = {}
	pins = PinnedComments.new()
	bin_sets = PackedStringArray()
	reference = picture
	# Begun empty here, who lays each part from now on is known. Named as a
	# design stands, its parts are still whoever laid them.
	if world == null or _is_empty():
		made_with = "hand"
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


## The world's generation a model was opened in, as it came, from somewhere
## that still has it as it is: a file of the person's, an example, the
## library, a save. Until it is changed, putting it away loses nothing
## ([method has_unsaved_work]). Not the working model restored at start-up,
## a version opened under its model's name, or a model Undo put back: those
## are nowhere else as they stand. -1 for none.
var _opened_whole: int = -1
## And how many parts it had, those on their way counted: a part put down or
## taken off past the history changes it.
var _opened_parts: int = 0


## The model's parts, those still on their way counted: the same as each
## arrives.
func _parts_with_awaited() -> int:
	return world.brick_count() - scenery.size() + awaited.size()


## Whether starting a new model would lose anything: bricks that are not
## in a saved model under this name, exactly as they stand.
func has_unsaved_work() -> bool:
	# An example as it shipped is nobody's work: New on the first visit's
	# car, untouched, asked whether to save it. Nothing has been done to
	# it while there is nothing to undo (an Open forgets the history).
	if example and builder != null and builder.history_depth() == 0:
		return false
	# Nor a model as it was opened, from somewhere that still has it: a file
	# of the person's opened twice over asked whether to save the first.
	if _opened_whole == world.generation() and builder != null \
			and builder.history_depth() == 0 and builder._redo.is_empty() \
			and _parts_with_awaited() == _opened_parts:
		return false
	# Nor an empty baseplate, unless a picture to build over is laid on it.
	if world.brick_count() - scenery.size() <= 0 and reference.is_empty():
		return false
	# The model written out and compared only when there is a saved one to
	# compare it with: on Orthanc that is a third of a second, and New asks
	# this before it can ask anything else.
	# Saved under another name is saved too: a session's save_model
	# "small-observatory.ldr" of Small Observatory, and its open_model a
	# moment later said the model had changes that were not saved.
	var now := PackedStringArray()
	for kept: String in [saved_path(title) if title != UNTITLED else "", _saved_as]:
		if kept.is_empty() or not FileAccess.file_exists(kept):
			continue
		if now.is_empty():
			now = _brick_lines(to_text(UNTITLED))
		# The picture to build over too (ReferenceImage): changed alone, it is
		# not what was saved.
		var text: String = FileAccess.get_file_as_string(kept)
		if _brick_lines(text) == now and ReferenceImage.same(ReferenceImage.read(text), reference):
			return false
	return true


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


## A saved model the person deleted, renamed or put back (File, Open, Rename
## or delete saved models…; SavedModelsDialog): the account is told too
## (CloudModels).
signal removed_save(name: String)
signal renamed_save(from: String, to: String)
signal put_back_save(name: String)

## Where a deleted model is kept for Undo: in this tab's own folder, the
## newest [constant OPENS_KEPT].
const DELETED := "deleted/"


## Delete the saved model called [param name] (its file's name, as Open
## lists it): the copy kept for Undo ([method put_back]), or "" when
## nothing was deleted. Its versions stay (File, Versions…).
func delete_saved(name: String) -> String:
	var path: String = SAVE_DIR + name + ".ldr"
	if read_only or not FileAccess.file_exists(path) or not NewerBuild.may_write(path):
		return ""
	DirAccess.make_dir_recursive_absolute(TabSession.path(DELETED))
	var kept: String = TabSession.path(DELETED + "%d-%s.ldr" % [
		int(Time.get_unix_time_from_system() * 1000.0), name])
	# Written, not moved: on the web a written file is what makes the
	# browser store user:// again, the delete with it (src/boot/shell.html).
	var text: String = FileAccess.get_file_as_string(path)
	var file: FileAccess = FileAccess.open(kept, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(text)
	file.close()
	if DirAccess.remove_absolute(path) != OK:
		DirAccess.remove_absolute(kept)
		return ""
	_tell_page_wrote(kept, text.to_utf8_buffer().size())
	var held: PackedStringArray = DirAccess.get_files_at(TabSession.path(DELETED))
	held.sort()
	for n: int in maxi(held.size() - OPENS_KEPT, 0):
		DirAccess.remove_absolute(TabSession.path(DELETED + held[n]))
	removed_save.emit(name)
	return kept


## The model [method delete_saved] kept at [param kept] saved again, under
## its own name or, when a model has that now, the next free one: the name
## it has, or "" when it could not be.
func put_back(kept: String) -> String:
	var text: String = FileAccess.get_file_as_string(kept) if FileAccess.file_exists(kept) else ""
	if text.is_empty() or read_only:
		return ""
	var stem: String = kept.get_file().get_basename()
	var was: String = stem.substr(stem.find("-") + 1)
	var name: String = _free_name(was)
	var path: String = SAVE_DIR + name + ".ldr"
	if not NewerBuild.may_write(path) \
			or not _write_saved(path, text if name == was else retitled(text, name)):
		return ""
	DirAccess.remove_absolute(kept)
	put_back_save.emit(name)
	return name


## The saved model called [param from] called [param to] now, the name in
## its file and its versions (File, Versions…) going with it: "" when it is,
## or why not, in words.
func rename_saved(from: String, to: String) -> String:
	var wanted: String = to.strip_edges()
	var path: String = SAVE_DIR + from + ".ldr"
	if read_only or not FileAccess.file_exists(path):
		return "“%s” is not saved here any more." % from
	if wanted.is_empty() or wanted == UNTITLED or _safe_name(wanted) != wanted:
		return "A name is letters, numbers, spaces, - and _, at most 60."
	if wanted == from:
		return ""
	var target: String = SAVE_DIR + wanted + ".ldr"
	# By the folder's own list: a name that differs only in case is the
	# same file on Windows and macOS, and another model on Linux.
	if DirAccess.get_files_at(SAVE_DIR).has(wanted + ".ldr"):
		return "“%s” is a saved model already. Choose another name." % wanted
	if not NewerBuild.may_write(target):
		return NewerBuild.REFUSAL
	if not _write_saved(target, retitled(FileAccess.get_file_as_string(path), wanted)):
		return "“%s” could not be written." % wanted
	var listed: PackedStringArray = DirAccess.get_files_at(SAVE_DIR)
	if listed.has(from + ".ldr") and listed.has(wanted + ".ldr"):
		DirAccess.remove_absolute(path)
	var versions: String = ModelVersions.folder(from)
	if DirAccess.dir_exists_absolute(versions) and not DirAccess.dir_exists_absolute(ModelVersions.folder(wanted)):
		DirAccess.rename_absolute(versions, ModelVersions.folder(wanted))
	# The model on the baseplate takes the name when it is this one (Main).
	renamed_save.emit(from, wanted)
	return ""


## [param text] written as the saved model at [param path], the page told:
## not a save of the model on the baseplate ([method _store]), so this tab
## goes on knowing its own file as it did.
static func _write_saved(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	_tell_page_wrote(path, text.to_utf8_buffer().size())
	return true


## [param text] with its model called [param name]: the first line that
## names it, or the line a save of someone else's file names it with
## ([constant TITLE_META]), or that line put in. A saved model opens under
## the name in its file, so a file renamed alone opened, and saved, under
## its old one: over the model that has it.
static func retitled(text: String, name: String) -> String:
	if not title_meta_in(text).is_empty():
		var lines: PackedStringArray = text.split("\n")
		for n: int in lines.size():
			if lines[n].begins_with(TITLE_META):
				lines[n] = TITLE_META + name
		return "\n".join(lines)
	var was: String = title_in(text, "")
	var cut: int = text.find("\n")
	var first: String = (text if cut < 0 else text.left(cut)).strip_edges()
	if not was.is_empty() and first == "0 " + was:
		return "0 " + name + (text.substr(cut) if cut >= 0 else "\n")
	return _after_first_line(text, TITLE_META + name)


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
	var text: String = _file_text(path)
	if text.is_empty():
		return 0
	return _opened_from(path, open_text(text, path.get_file()))


## [method open], once what the parts the file carries are drawn from has
## been fetched, where this build has not got it ([method open_text_fetched]).
func open_fetched(path: String, job: Working.Job = null) -> int:
	var text: String = _file_text(path)
	if text.is_empty():
		return 0
	return _opened_from(path, await open_text_fetched(text, path.get_file(), null, job))


## Why the last open left the model on the baseplate as it was, in words
## ("it is empty", "there are no parts in that file"), or "" when it opened.
## A model of no parts opens too: its parts placed are 0 either way, and a
## caller that took 0 for "not opened" said "Opened … 0 parts" of a model it
## had not opened, with the last one still there to be saved under its name
## (desktop060, 2026-10-23).
var not_opened: String = ""


## The text of the file at [param path]; "" with [member not_opened] saying
## why when there is none to open.
func _file_text(path: String) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	if not text.is_empty():
		return text
	not_opened = ("there is no such file" if not FileAccess.file_exists(path)
		else "it could not be read" if FileAccess.get_open_error() != OK
		else "it is empty")
	return ""


func _opened_from(path: String, result: Dictionary) -> int:
	if str(result["error"]).is_empty():
		example = path.begins_with(EXAMPLE_DIR)
		if path.begins_with(SAVE_DIR):
			know(path)
	return int(result["placed"])


## What the opens in this tab took off the baseplate, so each can be undone:
## {path, name, example}, a copy of the model as it stood, what it was
## called and whether it was an example, the newest last (Edit, Undo with nothing else to undo, and History). An open
## replaced a model of 254 parts not saved with no question, Undo greyed and
## History empty, and those parts were in no file (walk180, D6 and A11,
## 2026-10-23). Opens ask first now (ModelBar.ask_to_replace); this is what
## makes a slip cost nothing, whoever opened, a Claude session too.
var opened_over: Array[Dictionary] = []
## And what an undone open took off in turn, for Redo, the newest last.
var undone_over: Array[Dictionary] = []
## How many of each are kept: the oldest goes.
const OPENS_KEPT := 10
## Where the copies are, in this tab's own folder (TabSession).
const SET_ASIDE := "opened_over/"
## The world's generation the latest open laid its model in. Once anything
## else empties the world (New, Clear), those opens are not undone: an Undo
## after New does not put back a model opened before it.
var _opens_in: int = -1
## The open going is Undo's ("undo") or Redo's ("redo") of one, or neither.
var _reopening: String = ""
var _asides: int = 0


## Keep the model on the baseplate, before an open takes it off, for Undo
## ([member opened_over]); or, while Undo is reopening one, for Redo. Nothing
## for nothing there: an empty baseplate, half a model still being laid, a
## run that keeps nothing. The autosave copied when it holds the model as it
## stands, as it does once the model has been still a moment: made again,
## Orthanc's held a frame half as long again as the open's longest. Otherwise
## made, a big one over frames when [param paced], as the autosave makes it.
func _set_aside(paced: bool) -> void:
	if world.generation() != _opens_in:
		_forget_opens()
	# An empty baseplate with a picture laid to build over is kept too.
	if not keeps or read_only or laying or (_is_empty() and reference.is_empty()):
		return
	DirAccess.make_dir_recursive_absolute(TabSession.path(SET_ASIDE))
	_asides += 1
	var path: String = TabSession.path(SET_ASIDE + "%d-%d.ldr" % [
		int(Time.get_unix_time_from_system() * 1000.0), _asides])
	_hear()
	var kept: bool = _autosave_is_model and not _pending and not _autosaving \
		and DirAccess.copy_absolute(autosave(), path) == OK
	if not kept:
		var text: String = await _model_text(paced)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_warning("could not keep the model an open replaced (%d)" % FileAccess.get_open_error())
			return
		file.store_string(text)
		file.close()
	var into: Array[Dictionary] = undone_over if _reopening == "undo" else opened_over
	if _reopening.is_empty():
		_drop(undone_over, 0)
	# An example stays one: put back as it shipped, it is nobody's work to save.
	into.append({"path": path, "name": title, "example": example})
	_drop(into, OPENS_KEPT)


## The model on the baseplate as the autosave writes it, a big one over
## frames when [param paced].
func _model_text(paced: bool) -> String:
	if paced and world.brick_count() - scenery.size() >= PACED_FROM:
		var revision: int = world.revision
		var made: Array = []
		await _text_into(made, title, false, {}, FramePace.new())
		# Changed meanwhile: made again, as it is now.
		if world.revision == revision:
			return ReferenceImage.written_into(SetBin.written_into(with_share(str(made[0]),
				share_id, remixed_from, remixed_from_version, credit, made_with), bin_sets),
				reference)
	return ReferenceImage.written_into(SetBin.written_into(with_share(to_text(title), share_id,
		remixed_from, remixed_from_version, credit, made_with), bin_sets), reference)


## The copies of [param kept] past the newest [param leaving], deleted.
static func _drop(kept: Array[Dictionary], leaving: int) -> void:
	while kept.size() > leaving:
		DirAccess.remove_absolute(str(kept.pop_front()["path"]))


## No open to undo or redo any more, and their copies gone: those of a run
## before this one too.
func _forget_opens() -> void:
	opened_over.clear()
	undone_over.clear()
	var folder: String = TabSession.path(SET_ASIDE)
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)


## Whether Undo (or with [param again], Redo) can reopen what an open took
## off: nothing has emptied the world since, and for Redo nothing has been
## done since the Undo.
func can_reopen(again: bool = false) -> bool:
	if world == null or laying or world.generation() != _opens_in:
		return false
	if not again:
		return not opened_over.is_empty()
	return not undone_over.is_empty() and builder != null and builder.history_depth() == 0 \
		and builder._redo.is_empty()


## The open Undo (or Redo, [param again]) would take back (or do again), in
## words, as the history says a step: "opened “Car” in place of “Harbour
## Tug”", or "opened “Car” again" of a save of it; "" when there is none.
func reopen_words(again: bool = false) -> String:
	if not can_reopen(again):
		return ""
	var other: String = str((undone_over if again else opened_over).back()["name"])
	if other == title:
		# A save of it, or another tab's: the same model as it was before.
		return "opened “%s” again" % title
	return "opened “%s” in place of “%s”" % ([other, title] if again else [title, other])


## Undo the latest open, or with [param again] redo the latest undone: the
## model it took off put back as it stood, under its name, and the one on
## the baseplate kept in turn for the other. How many parts landed; -1 when
## it did not open, [member not_opened] saying why, nothing changed.
func reopen(again: bool = false, job: Working.Job = null) -> int:
	if not can_reopen(again):
		not_opened = "there is no open to %s" % ("redo" if again else "undo")
		return -1
	var stack: Array[Dictionary] = undone_over if again else opened_over
	var entry: Dictionary = stack.back()
	var text: String = FileAccess.get_file_as_string(str(entry["path"]))
	if text.is_empty():
		not_opened = "its copy could not be read"
		return -1
	_reopening = "redo" if again else "undo"
	var result: Dictionary = await open_text_fetched(text, str(entry["path"]).get_file(), null, job)
	_reopening = ""
	if not str(result["error"]).is_empty():
		return -1
	stack.erase(entry)
	DirAccess.remove_absolute(str(entry["path"]))
	example = bool(entry["example"])
	_opened_whole = -1
	if title != str(entry["name"]):
		title = str(entry["name"])
		loaded.emit(title, int(result["placed"]))
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
## landed; 0 with [member not_opened] saying why when it could not be read,
## and nothing is changed.
func open_version(path: String, called: String = "", job: Working.Job = null) -> int:
	var text: String = ModelVersions.read(path)
	if text.is_empty():
		not_opened = "it could not be read"
		return 0
	var name: String = called if not called.is_empty() else title
	var result: Dictionary = await open_text_fetched(text, name, null, job)
	# Not by the parts placed or on their way: those on their way may be the
	# last model's, and that model was renamed for the one that did not open.
	if not str(result["error"]).is_empty():
		return 0
	# Not what its name's file holds: Save makes it the newest save.
	_opened_whole = -1
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
		# A meta line is never the title, and the app writes its own (share,
		# remix, credit, made with) after a file's first line: for an .mpd
		# that is its 0 FILE, so they stood before the title, and a model a
		# Claude session touched (made with assistant) lost its name in the
		# autosave (m166's suite, 2026-10-24). Read past them.
		if said.begins_with("!"):
			continue
		if said.is_empty() or said.begins_with("Name:") \
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
##
## [param parsed]: the file already parsed, as [method open_text_fetched]
## has it, so it is not parsed twice.
func open_text(text: String, name: String = "model", parsed: LdrModel = null) -> Dictionary:
	var out: Array = []
	_open_into(out, text, name, parsed, null)
	not_opened = str(out[0]["error"])
	return out[0]


## A model of this many parts or more opened over frames
## ([method open_text_fetched]) is laid a slice at a time; one of fewer in
## the one frame, as it always was.
const LAID_IN_SLICES_FROM := 200
## The least each slice of laying it is.
const LAID_SLICE_US := 40000

## The world's generation a model is being laid in a slice at a time, or -1:
## see [member laying].
var _laying_in: int = -1
## While a model opened over frames is being laid: from the world being
## cleared for it until every part is down and the model has its name. Its
## parts are not drawn meanwhile (BrickWorld.hold_drawing), the person's
## edits and Claude's tools wait for it (Shell.can, CommandSocket), and the
## autosave writes nothing ([method tick]): what is down is not the model.
## Over when the world is cleared again, by whatever clears it.
var laying: bool:
	get:
		return world != null and _laying_in >= 0 and _laying_in == world.generation()
## How many of its parts are not down yet, while [member laying].
var still_to_lay: int = 0
## Whether the model being laid holds the world's drawing (_let_go).
var _holding: bool = false
## A big model laid over frames is drawn once its parts are down, before
## the lattice is told of them ([signal shown]); the slices from then on
## are at least this long.
const SHOWN_SLICE_US := 250000

## A big model opened over frames is on the screen, every part down whose
## geometry is here, and is still being laid ([member laying]): the view is
## framed on it now, not once it is whole (Main).
signal shown


## [method open_text], its answer put in [param out]. With [param job] (it
## is then a coroutine) a model of [constant LAID_IN_SLICES_FROM] parts or
## more is opened a slice at a time, the job counting it: what its text says
## besides its parts read on a worker, then its parts laid over frames
## ([member laying]). 8466-1 from the library held a browser's one thread
## 3.3 to 4.2 s laying its 1,234 parts in one frame, and a desktop's 790 ms:
## 0.65 s of that was reading its 36 MB for its meta lines and keeping it as
## its file (SourceFile), the rest each part put down and told to the
## lattice.
func _open_into(out: Array, text: String, name: String, parsed: LdrModel,
		job: Working.Job) -> void:
	open_phases = {}
	_phase_at = Time.get_ticks_usec()
	var model: LdrModel = parsed if parsed != null else LdrModel.parse(text, name)
	_phase("parse")
	if model == null:
		out.append({"placed": 0, "missing": 0, "error": "that is not an LDraw file"})
		return
	# Parts the file brought with it, made here or somewhere else, join
	# the library before anything asks whether the library has them: with a
	# job, built over frames, after any worker reading the library has
	# finished (adding to it waits for those).
	var taken: Array = []
	if job != null:
		await CustomParts.readers_done(library)
		await CustomParts.take_into(taken, library, model, job)
	else:
		CustomParts.take_into(taken, library, model, null)
	var carried: Dictionary = taken[0]
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
		placement.part_id = studio_part(placement.part_id, library)
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
		# A part LDraw draws in one colour only, kept for old files, as the
		# part it draws in that colour (303923, 3039 in blue): drawn the same,
		# and the parts list and a BrickLink order name a part made now.
		var colour: int = library.current_colour(placement.part_id)
		if colour >= 0:
			placement.part_id = library.current(placement.part_id)
			placement.color_code = colour
	# A model saved with no parts opens as that: an empty model under its
	# name. It was refused as "no parts", and the model before it was left
	# on the baseplate for a save to write under this one's name.
	if flattened.is_empty():
		var why: String = _why_not_a_model(text)
		if not why.is_empty():
			out.append({"placed": 0, "missing": 0, "waiting": 0, "error": why})
			return

	# Everything decided before anything is destroyed.
	#
	# Tearing the world down and then discovering that not one part
	# could be placed leaves the person with an empty baseplate where
	# their model was, and — because the count was never checked — a
	# message saying it opened.
	var known: Array = []
	var missing: Dictionary = {}
	var waiting: Dictionary = {}
	var made_again: Dictionary = {}
	for item: Variant in flattened:
		var placement: LdrModel.Placement = item
		# A piece the app makes itself (a band's, a coil's) whose FILE
		# section the file has lost, as a tool that cannot read one drops
		# it: made again from its name, as the tool made it. A band went
		# off the baseplate whole without (springs, 2026-10-30).
		if not library.parts.has(placement.part_id) and Bands.is_piece_id(placement.part_id) \
				and not made_again.has(placement.part_id):
			made_again[placement.part_id] = Bands.piece_part(library, placement.part_id)
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
	if known.is_empty() and not flattened.is_empty():
		out.append({"placed": 0, "missing": missing.size(), "waiting": 0,
			"missing_ids": missing,
			"error": "none of the %d parts in that file are in the library (%s)"
				% [missing.size(), named_counts(missing)]})
		return

	var paced: bool = job != null and known.size() >= LAID_IN_SLICES_FROM
	if paced and not waiting.is_empty():
		await _await_geometry(waiting, job)
		_phase("geometry")
	var foreign: bool = model.author.strip_edges() != "Brickworks"
	# Someone else's file is kept, so a save writes back what nobody changed
	# as it was (SourceFile); the app's own are written whole, as always.
	# Made before the model is stood on the ground: the file's coordinates.
	# With what the text says besides its parts, read from the whole of it:
	# on a worker for a big model, the frames going on.
	var absent: Array = flattened.filter(func(p: LdrModel.Placement) -> bool:
		return not library.parts.has(p.part_id))
	var reading: Callable = func() -> Dictionary:
		return _read_text(text, model, known, mirrored_lines, authored, absent, foreign)
	var read: Dictionary
	if paced:
		read = await _off_frame(reading)
	else:
		read = reading.call()
	var source: SourceFile = read["source"]
	_phase("source")

	# What is on the baseplate kept first, so the open can be undone.
	await _set_aside(job != null)
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	scenery.clear()
	awaited.clear()
	_told_not_coming = false
	_phase("clear")
	_source = source
	_opened_in = world.generation()
	_opens_in = world.generation()
	# Whatever arrives from now is put down in this model (place_awaited).
	_awaited_in = world.generation()
	# What the file holds that is not on the baseplate: kept in it, and said.
	unshown = missing.duplicate()
	if source != null and not missing.is_empty():
		unshown = source.unshown(absent)
	elif not missing.is_empty():
		unshown = _unshown_of(absent)
	# The app's own file carries them itself (_text_into).
	_absent = absent if source == null else []

	# Each sub-model copy's step in the one that places it, by its path.
	if authored:
		world.unit_steps = model.unit_steps.duplicate()
		# And how its booklet shows them: ROTSTEP's turns and the app's own
		# lines (BookletLooks).
		world.step_looks = read["looks"]
	# Stood on the ground before anything is placed, from every part in it;
	# and brought down onto it, when another tool drew it up in the air.
	var up: Vector3 = lift_for(known, foreign)
	_phase("lift")
	var laying_in: int = world.generation()
	if paced:
		_laying_in = laying_in
		still_to_lay = known.size()
		world.hold_drawing()
		_holding = true
		# Nothing of it is drawn meanwhile, only the bar: long slices, as
		# each frame given back costs its own drawing (8466-1 in a browser
		# drawing in software was laid in 7.4 s of short slices where its
		# one frame took 6.1 s).
		job.slices_of(LAID_SLICE_US)
		job.percent = true
		job.count(0, known.size() * 2)
		# Each part's geometry to hand first, a slice at a time: on the
		# desktop it is read from disk when it is first asked for.
		var asked: Dictionary = {}
		for item: Variant in known:
			var part_id: String = (item as LdrModel.Placement).part_id
			if not asked.has(part_id):
				asked[part_id] = true
				library.mesh_for(part_id)
			if job.due():
				await job.next()
				if world.generation() != laying_in:
					_put_away(out, job)
					return
	# A turned part's cover is the slow half of putting it down, and depends
	# on nothing but the part and its turn: all of them set going at once,
	# first, and worked out while the parts are drawn.
	_unregistered = []
	if not lattice_later and paced:
		await builder.prepare_covers(known, job)
		if world.generation() != laying_in:
			_put_away(out, job)
			return
	elif not lattice_later:
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
		else:
			world.get_brick(brick_id).group = placement.group
			world.get_brick(brick_id).unit = placement.unit
			world.get_brick(brick_id).step = placement.step
			placed += 1
		if paced and job.due():
			job.count(down.size())
			await job.next()
			if world.generation() != laying_in:
				_put_away(out, job)
				return
	_phase("draw")
	if paced:
		# Drawn now, every part down whose geometry is here, and the rest
		# done with it on the screen: the covers, the lattice told of each
		# part, what arrived meanwhile. The hotel's 3,164 parts were nothing
		# to look at until all of that was (walk180, A8). Still being laid:
		# edits, Claude's tools, the autosave and whatever reads the model as
		# built wait (BrickWorld.is_being_laid). Once it is drawn a browser
		# drawing in software takes half a second a frame whatever the slice,
		# so the slices are long from here.
		var floor_said: ModelFloor = read["floor"]
		model_floor = floor_said if floor_said != null else ModelFloor.preferred()
		world.laying = true
		world.rebuild_slice_us = SHOWN_SLICE_US
		_let_go()
		job.slices_of(SHOWN_SLICE_US)
		shown.emit()
		_phase("shown")
	# Then the lattice told of each, in the same order, once the covers are in.
	if not lattice_later:
		while paced and not builder.covers_ready():
			await job.next()
			if world.generation() != laying_in:
				_put_away(out, job)
				return
		builder.finish_covers()
	_phase("covered")
	for n: int in known.size():
		if down[n] != 0:
			var placement: LdrModel.Placement = known[n]
			if lattice_later:
				_unregistered.append([down[n], placement.part_id, placement.transform])
			else:
				builder.register(down[n], placement.part_id, placement.transform)
		if paced and job.due():
			job.count(known.size() + n)
			still_to_lay = known.size() - n
			await job.next()
			if world.generation() != laying_in:
				_put_away(out, job)
				return
	if paced:
		# What arrived while the rest went down, down now: it was not put
		# down then (place_awaited), as the model was not whole. A slice at
		# a time too, as 8466-1's put down at once were 0.86 s of a
		# browser's frame; and looked over again until a look finds none,
		# as more may arrive between slices.
		var landed: bool = false
		var landing: bool = true
		while landing:
			landing = false
			var still: Array[LdrModel.Placement] = []
			for placement: LdrModel.Placement in awaited:
				if not library.is_resident(placement.part_id):
					still.append(placement)
					continue
				var brick_id: int = world.add_brick(
					placement.part_id, placement.color_code, placement.transform)
				if brick_id == 0:
					still.append(placement)
					continue
				world.get_brick(brick_id).group = placement.group
				world.get_brick(brick_id).unit = placement.unit
				world.get_brick(brick_id).step = placement.step
				builder.register(brick_id, placement.part_id, placement.transform)
				placed += 1
				landing = true
				if job.due():
					await job.next()
					if world.generation() != laying_in:
						_put_away(out, job)
						return
			awaited = still
			landed = landed or landing
		_laying_in = -1
		world.laying = false
		world.rebuild_slice_us = FramePace.LEAST_US
		still_to_lay = 0
		job.count(known.size() * 2)
		if landed and awaited.is_empty():
			_settle()
	_phase("place")

	# Ask for the ones that were not to hand, and put each down as it
	# arrives (place_awaited).
	var asked_for: Dictionary = {}
	for placement: LdrModel.Placement in awaited:
		if not asked_for.has(placement.part_id):
			asked_for[placement.part_id] = true
			library.request_mesh(placement.part_id, true)

	# A model from a file: nobody emptied the baseplate. Unless the file
	# itself is empty: then it is kept so, as one begun empty is (begin).
	emptied = flattened.is_empty()
	title = _title_of(model, name)
	if source != null:
		source.own_title = title
		var named: String = read["title"]
		if not named.is_empty():
			title = named
	share_id = read["share"]
	remixed_from = read["remix"]
	remixed_from_version = read["remix_version"] if not remixed_from.is_empty() else 0
	credit = read["credit"]
	made_with = read["made"]
	var said: ModelFloor = read["floor"]
	model_floor = said if said != null else ModelFloor.preferred()
	from_set = read["set"]
	hidden_scheme = read["hidden"]
	pins = read["pins"]
	bin_sets = read["bin"]
	reference = read["reference"]
	world.motions = read["motions"]
	if not world.motions.is_empty():
		# Where each part stood as the file has it: a joint is measured from
		# here, so a door saved open is known to be open (Motions.Joint.at).
		for brick: BrickWorld.Brick in world.bricks():
			world.motions.snapshot[brick.id] = brick.transform
	example = false
	_opened_whole = world.generation()
	_opened_parts = _parts_with_awaited()
	_phase("meta")
	loaded.emit(title, placed)
	_phase("loaded")
	out.append({"placed": placed, "missing": missing.size(),
		"waiting": waiting.size(), "missing_ids": missing, "error": "",
		"unshown": unshown, "kept": source != null or not _absent.is_empty()})


## Why [param text], which places no part, is not a model to open: "" for
## an LDraw model with nothing in it, every line of it a comment or a meta
## line as a model saved empty is, here or by any LDraw tool. A file of
## anything else places nothing because it is not a model, and opening it
## would put an empty baseplate where the person's model was.
static func _why_not_a_model(text: String) -> String:
	var lines: int = 0
	var drawn: bool = false
	for raw: String in text.trim_prefix("\ufeff").split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		lines += 1
		if line[0] not in "012345" or (line.length() > 1 and line[1] not in " \t"):
			return "that is not an LDraw file"
		drawn = drawn or line[0] != "0"
	if lines == 0:
		return "it is empty"
	return "there are no parts in that file" if drawn else ""


## What a model's [param text] says besides its parts, and the file kept as
## it is when it is someone else's ([param foreign]): read from the whole
## text and from nothing else, so on any thread.
static func _read_text(text: String, model: LdrModel, known: Array, mirrored_lines: Dictionary,
		authored: bool, absent: Array, foreign: bool) -> Dictionary:
	return {
		"source": SourceFile.make(text, model, known, mirrored_lines, authored, absent)
			if foreign else null,
		"looks": BookletLooks.read(text, model._assembly_names(), LdrModel._key(model.main.name))
			if authored else {},
		"title": title_meta_in(text) if foreign else "",
		"share": share_in(text),
		"remix": remix_in(text),
		"remix_version": remix_version_in(text),
		"credit": credit_in(text),
		"made": made_in(text),
		"floor": ModelFloor.read(text),
		"set": set_in(text),
		"bin": SetBin.read(text),
		"reference": ReferenceImage.read(text),
		"hidden": HiddenColours.read(text),
		"motions": Motions.read(text),
		"pins": PinnedComments.read(text),
	}


## [param work] done on a worker, the frames going on meanwhile: what it
## returns.
static func _off_frame(work: Callable) -> Variant:
	var done: Array = [null]
	var task: int = WorkerTasks.add(func() -> void: done[0] = work.call(), false,
		"read a model's text")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerTasks.collect(task)
	return done[0]


## A model being laid a slice at a time put away before it was whole: the
## world was cleared under it. What has been done of it stays undone.
func _put_away(out: Array, job: Working.Job) -> void:
	still_to_lay = 0
	_let_go()
	world.laying = false
	world.rebuild_slice_us = FramePace.LEAST_US
	job.count(0)
	out.append({"placed": 0, "missing": 0, "waiting": 0,
		"error": "it was put away before all of it was down"})


## The model being laid let go of, to be drawn from the end of this frame a
## slice of the batches a frame (BrickWorld.rebuilds_in_slices): once, as
## another may hold the drawing too (Assistant._apply).
func _let_go() -> void:
	if _holding:
		_holding = false
		world.release_drawing()


## The lattice told of a model's parts after it is on screen, a slice at a
## time (register_later), not as it opens: the shared model's viewer, whose
## parts are only looked at. It is what is under a pointer there, nothing
## more, and on 4,000 parts of a slowed phone it was over a second before
## the model was up.
var lattice_later: bool = false
var _unregistered: Array = []


## The parts open_text left the lattice to be told of, told now, a slice a
## frame. A model opened again meanwhile starts its own list.
func register_later() -> void:
	var pace := FramePace.new()
	var list: Array = _unregistered
	while not list.is_empty() and is_same(list, _unregistered):
		var item: Array = list.pop_back()
		if world.get_brick(int(item[0])) != null:
			builder.register(int(item[0]), str(item[1]), item[2])
		if pace.due():
			await pace.next()


## [method open_text], once the LDraw library's own files the parts the file
## carries are drawn from, which this build has not got, have been fetched
## (CustomParts.fetch_sources): on the web, the subparts and parts no build
## ships. At once, with nothing fetched or waited for, on the desktop and for
## a file that needs nothing.
## [param parsed] is [param text] already read (ModelBar.read_off_frame).
## With [param job], the work the status bar shows (File, Open, the
## library, a version), over frames: a big file read on a worker, its
## flexible parts built on workers, and a big model laid a slice at a time
## ([method _open_into]), the job counting it.
func open_text_fetched(text: String, name: String = "model", parsed: LdrModel = null,
		job: Working.Job = null) -> Dictionary:
	var began: int = Time.get_ticks_usec()
	var model: LdrModel = parsed
	if model == null and job != null and text.length() >= READ_OFF_FRAME_FROM:
		model = await _off_frame(func() -> LdrModel: return LdrModel.parse(text, name))
	elif model == null:
		model = LdrModel.parse(text, name)
	if model == null:
		return open_text(text, name)
	if job != null:
		ask_geometry(model)
	if job != null and not model.generated.is_empty():
		await CustomParts.warm_skins(library, model)
	var parsed_in: float = (Time.get_ticks_usec() - began) / 1000.0
	began = Time.get_ticks_usec()
	await CustomParts.fetch_sources(library, model, job == null)
	# And the skins that waited for a file fetched just now, built the same
	# way: built by the open, each was waited for in its frame (8466-1's
	# zdampedshock1 spring, 1.5 s of a browser's).
	if job != null and not model.generated.is_empty():
		await CustomParts.warm_skins(library, model)
	var fetched_in: float = (Time.get_ticks_usec() - began) / 1000.0
	var out: Array = []
	if job != null:
		await _open_into(out, text, name, model, job)
	else:
		_open_into(out, text, name, model, null)
	not_opened = str(out[0]["error"])
	open_phases["parse"] = parsed_in
	open_phases["fetch"] = fetched_in
	return out[0]


## A file this long or longer is read on a worker when it is opened over
## frames: 8466-1's 36 MB took 1.2 s of a desktop's frame to read.
const READ_OFF_FRAME_FROM := 262144


## The geometry of [param model]'s parts this build has not got, asked for
## as soon as the file is read: fetched while the rest of the open goes on,
## and waited for before the model is drawn (_await_geometry). The parts the
## file's own copies are of first, as its carried parts wait for those alone
## (CustomParts._fetch_copied). Asked again, nothing is asked twice.
func ask_geometry(model: LdrModel) -> void:
	library.want(_parts_named_in(model))
	library.want(CustomParts.copied_parts(library, model), true)


## Every part [param model] places, by the library's name for it, each once:
## what its open asks the geometry of. A sub-model's name is among them, and
## asks for nothing.
func _parts_named_in(model: LdrModel) -> Array:
	var named: Dictionary = {}
	for sub: LdrModel.SubModel in model.submodels.values():
		for placement: LdrModel.Placement in sub.placements:
			named[placement.part_id] = true
	var out: Dictionary = {}
	for part_id: String in named:
		out[library.resolve(studio_part(part_id, library))] = true
	return out.keys()


## The most a big model's open waits for the geometry on its way before it
## is laid without it, and the most it waits with none arriving: what comes
## after is put down as it comes (place_awaited).
const GEOMETRY_WAIT_MS := 20000
const GEOMETRY_STALL_MS := 4000


## Until the geometry of [param waiting] (part id -> true) on its way has
## come, or [constant GEOMETRY_WAIT_MS] or [constant GEOMETRY_STALL_MS], the
## job's slices given back. While nothing of the model is drawn a browser's frames
## are quick, and each fetch is polled once a frame: put down after the
## model was drawn, each came in a frame of the whole model drawn in
## software, two a second, and 10297-1's last 126 parts took 55 s to come
## so (walk180, A8).
func _await_geometry(waiting: Dictionary, job: Working.Job) -> void:
	library.want(waiting.keys())
	var began: int = Time.get_ticks_msec()
	var came_at: int = began
	var left: int = waiting.size()
	while true:
		var now_left: int = 0
		for part_id: String in waiting:
			if library.is_on_its_way(part_id):
				now_left += 1
		if now_left < left:
			came_at = Time.get_ticks_msec()
		left = now_left
		if left == 0 or Time.get_ticks_msec() - began >= GEOMETRY_WAIT_MS \
				or Time.get_ticks_msec() - came_at >= GEOMETRY_STALL_MS:
			return
		await job.next()


## What the last [method open_text] spent, phase by phase, in ms, in order:
## parse, carried, flatten, known, geometry (waiting for what is on its way),
## source, clear, lift, covers (set going), draw (the world), shown (the view
## framed on it), covered (waiting for the covers), place (the lattice),
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


## [param placements] not on the baseplate, by number, as an open says them
## (ModelBar.left_out_words): a band or a coil whose pieces could not be made
## named once, by the sub-model it is, as SourceFile.unshown names someone
## else's flexible parts, not as the hundred pieces it is drawn with.
static func _unshown_of(placements: Array) -> Dictionary:
	var out: Dictionary = {}
	var counted: Dictionary = {}
	for item: Variant in placements:
		var placement: LdrModel.Placement = item
		var named: String = placement.part_id
		if Bands.is_piece_id(placement.part_id) and not placement.unit.is_empty():
			if counted.has(placement.unit):
				continue
			counted[placement.unit] = true
			named = "%s (flexible)" % Assemblies.definition(Assemblies.leaf(placement.unit))
		out[named] = int(out.get(named, 0)) + 1
	return out


## [param unit] and the sub-models it is in, put among [param instances]
## where they are not, at [param frame] as the rest are: a sub-model with
## nothing of it on the baseplate (Assemblies.file_frames finds none) whose
## parts the file is written with still. Each a definition of its own, as a
## copy that went its own way is.
static func _hold_unit(instances: Dictionary, unit: String, frame: Transform3D) -> void:
	var path: String = ""
	for leaf: String in unit.split("/", false):
		path = leaf if path.is_empty() else path + "/" + leaf
		if instances.has(path):
			continue
		var def: String = Assemblies.definition(leaf)
		while instances.values().any(func(entry: Dictionary) -> bool: return str(entry["def"]) == def):
			def += "+"
		instances[path] = {"frame": frame, "def": def}


## The LDraw part a Studio model means by [param part_id].
##
## Studio draws parts its copy of LDraw had not got yet itself, and names
## them by BrickLink's number with "bl_" before it: a Studio set from 2025
## used bl_5095, a curved slope LDraw has since drawn as 5095. Where the
## library has that number it is that part; where it has not (a print only
## BrickLink knows, bl_3068pb2483), the name is kept, and the part is left
## out and named like any other the library has not got.
static func studio_part(part_id: String, library: PartLibrary) -> String:
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
## Brings a motion's joint's AT up to where it stands now (MotionPlayer.
## rebase), asked of each as the model is written, so the file says where
## it stood; unset, what the motion last knew is written.
var motion_rebase: Callable = Callable()


## The model's motions as lines (Motions.lines), each joint's ref and where
## it stands written as the model now is: its part's place, in the file's
## coordinates, and how far it stands from where it was built.
func _motion_lines() -> PackedStringArray:
	var motions: Motions = world.motions
	if motions == null or motions.is_empty():
		return PackedStringArray()
	var back: Vector3 = _lift_now()
	for joint: Motions.Joint in motions.joints:
		if motion_rebase.is_valid():
			motion_rebase.call(joint)
		var lead: BrickWorld.Brick = world.get_brick(joint.lead) if joint.lead != 0 else null
		if joint.by == "part" and lead != null and lead.part_id == joint.part:
			joint.place = (lead.transform.origin - back) * LdrModel.FLIP
	return motions.lines()


## How far the model was lifted to stand on the ground as it opened: a
## file's coordinates are a part's place less this.
func lift() -> Vector3:
	return _lift_now()


func _lift_now() -> Vector3:
	if world == null or world.generation() != _opened_in:
		return Vector3.ZERO
	return Vector3(0.0, _lifted_by, 0.0)


## The source file with the model on the baseplate written into it, or null
## when there is none or the change cannot be written into it as it is.
func _source_text(title_now: String) -> Variant:
	var asked: Dictionary = _source_asked(title_now)
	return null if asked.is_empty() else _source_text_of(asked)


## What someone else's file is written back from: its source, and the
## model's parts and what else is written into it as they stand now, copied,
## so it is written on a worker while the model goes on changing
## ([method _source_written]). {} when there is no source.
func _source_asked(title_now: String) -> Dictionary:
	var source: SourceFile = _live_source()
	if source == null:
		return {}
	var bricks: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		# A section broken out is written where it was pulled from: its
		# parts as they stand there (BrickWorld.home_of).
		var home := BrickWorld.Brick.new(brick.id, brick.part_id, brick.color_code,
			brick.transform if world.broken_out.is_empty() else world.home_of(brick))
		home.group = brick.group
		home.unit = brick.unit
		home.step = brick.step
		home.hidden = brick.hidden
		bricks.append(home)
	# In an order of their own, not the world's: which line a part is paired
	# with and where a part put down goes in the file follow it, and two
	# copies of a model built in another order (Together) wrote two files.
	bricks = _in_brick_order(bricks)
	var waiting: Dictionary = {}
	if world.generation() == _awaited_in:
		for placement: LdrModel.Placement in awaited:
			waiting["%d|%s" % [placement.line, placement.unit]] = true
	return {"source": source, "bricks": bricks, "lift": _lift_now(), "waiting": waiting,
		"library": library, "title": title_now,
		"unit_steps": world.unit_steps.duplicate(true) if source.authored else {},
		"floor": model_floor, "hidden": hidden_scheme.duplicate(true),
		"motions": _motion_lines(), "looks": world.step_looks.duplicate(true),
		"pins": pins.lines(world, _lift_now()),
		"authored": AuthorSteps.any(world, scenery), "set": from_set}


## The source file with the parts [method _source_asked] copied written into
## it, or null when the change cannot be written into it as it is. Reads
## only what it is given, so on any thread.
static func _source_text_of(asked: Dictionary) -> Variant:
	var source: SourceFile = asked["source"]
	var written: Variant = source.write(asked["bricks"], asked["lift"], asked["waiting"],
		asked["library"], asked["unit_steps"])
	if written == null:
		return null
	var text: String = _without_app_lines(str(written))
	var title_now: String = asked["title"]
	if title_now != source.own_title and not title_now.is_empty():
		text = _after_first_line(text, TITLE_META + title_now)
	return text


## [method _source_text_of], and what else the app keeps in someone else's
## file written into it: a hose's path, the floor, the hidden colours, the
## motions, the booklet's looks and the set it is. On any thread: the
## autosave makes it on a worker ([method _text_into]).
static func _source_written(asked: Dictionary) -> Variant:
	var from_source: Variant = _source_text_of(asked)
	if from_source == null:
		return null
	var kept: String = str(from_source)
	# A hose LDCad laid, bent by a grab: its path where it now lies.
	kept = LdcadPath.written_into(kept, asked["source"], asked["library"])
	var ground: ModelFloor = asked["floor"]
	kept = ground.written_into(kept) if ground != null else kept
	kept = HiddenColours.written_into(kept, asked["hidden"])
	kept = Motions.written_into(kept, asked["motions"])
	kept = PinnedComments.written_into(kept, asked["pins"])
	kept = _looks_into(kept, asked["looks"], asked["authored"])
	var number: String = asked["set"]
	return kept if set_in(kept) == number else with_set(kept, number)


## [param text] without the lines this app writes again on every save.
static func _without_app_lines(text: String) -> String:
	if not text.contains("0 !BRICKWORKS "):
		return text
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with(SHARE_META) or line.begins_with(REMIX_META) \
				or line.begins_with(REMIX_VERSION_META) or line.begins_with(CREDIT_META) \
				or line.begins_with(MADE_META) or line.begins_with(SetBin.META) \
				or line.begins_with(ReferenceImage.META) \
				or line.begins_with(ReferenceImage.PICTURE_META) \
				or line.begins_with(TITLE_META) or line.begins_with(SharedPages.PAGE.strip_edges()):
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
## Placements of the app's own file whose part the catalogue has not got
## (a newer build's, say), in the file's coordinates: written back where it
## had them, as [member awaited] are. Someone else's file keeps its own
## (SourceFile). Until 2026-10-20 they went from the app's own: a save, or an
## autosave once the model was edited, wrote it without them.
var _absent: Array = []
## Whether [method not_coming] has said this model's count.
var _told_not_coming: bool = false


## [param part_id] could not be fetched, asked again too
## (PartLibrary.RETRY_AFTER). How many of the open model's parts could not
## be loaded, the first time that leaves none of them on its way; 0 before,
## and after. They stay awaited: kept in the file a save writes, and put down
## if they arrive after all. Until 2026-10-20 a part whose fetch failed
## waited for ever and nothing said so (m115's preview: a crane short its
## 3709b).
func not_coming(part_id: String) -> int:
	if _told_not_coming or laying or awaited.is_empty() or world.generation() != _awaited_in \
			or not awaited.any(func(p: LdrModel.Placement) -> bool: return p.part_id == part_id):
		return 0
	for placement: LdrModel.Placement in awaited:
		if library.is_on_its_way(placement.part_id):
			return 0
	_told_not_coming = true
	return awaited.size()


## Put down what was waiting for [param part_id]. Returns how many landed;
## none once the world has been cleared since the model opened.
func place_awaited(part_id: String) -> int:
	# Not into a model still being laid: what arrived meanwhile is put down
	# once it is whole (_open_into).
	if awaited.is_empty() or laying:
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
	# Someone else's file: written back as it was, with what changed. On a
	# worker with a [param pace], the frames going on: made in one,
	# 8466-1's 36 MB were 1.3 to 3 s of a browser's after every part that
	# arrived as it opened.
	var asked: Dictionary = _source_asked(title)
	if not asked.is_empty():
		var kept: Variant
		if pace != null:
			kept = await WorkerTasks.awaited(func() -> Variant:
				return ModelStore._source_written(asked), "write the model's file", library)
		else:
			kept = _source_written(asked)
		if kept != null:
			made.append(kept)
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
	# What has not arrived, or could not be fetched, goes out last, where the
	# file had it, and so does what the catalogue has not got. Someone else's
	# file carries them below (carried_into); the app's own was saved without
	# them: a model saved on a phone that lost a part's fetch lost the part
	# (fetch_retry_probe, 2026-10-20).
	if _live_source() == null and world.generation() == _awaited_in:
		# Awaited parts were stood on the ground with the rest; the absent are
		# as the file had them.
		var held_at: Array = []
		for waiting: LdrModel.Placement in awaited:
			held_at.append([waiting, back * waiting.transform])
		for absent: LdrModel.Placement in _absent:
			held_at.append([absent, absent.transform])
		for pair: Array in held_at:
			var waiting: LdrModel.Placement = pair[0]
			var held := LdrModel.Placement.new(waiting.part_id, waiting.color_code,
				pair[1], waiting.step)
			held.group = waiting.group
			# In its sub-model, as the file had it: one with nothing on the
			# baseplate (a band whose pieces could not be made) is written
			# still, not its parts loose in the model.
			var unit: String = Assemblies.path_from(waiting.group, waiting.unit)
			_hold_unit(instances, unit, back)
			held.unit = unit
			placements.append(held)
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
		# And LDCad's hoses keep their paths, where they now lie.
		text = LdcadPath.written_into(text, _live_source(), library)
	# What it stands on goes with it, everywhere it goes: the autosave, a
	# save, an export, a shared link. Another program reads past the line.
	text = model_floor.written_into(text) if model_floor != null else text
	text = HiddenColours.written_into(text, hidden_scheme)
	text = Motions.written_into(text, _motion_lines())
	text = PinnedComments.written_into(text, pins.lines(world, _lift_now()))
	text = _with_looks(text, true)
	if model != world:
		model.free()
	made.append(with_set(text, from_set))


## [param text] with how the booklet shows each step written into it
## (BookletLooks): ROTSTEP for a turn, the app's own lines for the rest. A
## model with no steps of its own is left alone. [param whole]: the text was
## written whole, its steps one after another with none empty
## (BookletLooks.as_written), not written back over the file it came from.
func _with_looks(text: String, whole: bool = false) -> String:
	var written: Callable = func() -> Dictionary: return BookletLooks.as_written(world, scenery)
	return _looks_into(text, world.step_looks, AuthorSteps.any(world, scenery),
		written if whole else Callable())


## [method _with_looks] on any thread: [param looks] as the world has them,
## [param authored] whether its parts have the author's steps, and
## [param written] what gives the looks written, worked out only when they
## are; [param looks] when not given.
static func _looks_into(text: String, looks: Dictionary, authored: bool,
		written: Callable = Callable()) -> String:
	if looks.is_empty() and (not authored or not BookletLooks._written_in(text)):
		return text
	var parsed: LdrModel = LdrModel.parse(text, "model")
	return BookletLooks.written_into(text, written.call() if written.is_valid() else looks,
		parsed._assembly_names(), LdrModel._key(parsed.main.name))


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


## Whether writing this model (a save, an export, a share) is said on the
## bar before it begins: one paced, and one this big however it is written.
## A model with its author's steps is written in one go, and the Wizard's
## Tower's 10,105 parts held a frame for 0.4 to 0.9 s with nothing said once
## it had them (9d7c5ba3, command_probe). At a thousand parts that is 26 to
## 46 ms here, and a browser drawing in software takes several times longer.
func says_writing() -> bool:
	return paces() or (world.library != null
		and world.brick_count() - scenery.size() >= SAID_WRITING_FROM)


const SAID_WRITING_FROM := 2000


## The model's text with its build order, for an export or a share: on a
## big model worked out a slice at a time, the status bar saying
## [param doing] and counting, with Cancel ([method to_text_paced]). ""
## when it was cancelled.
func text_for_file(title: String, doing: String) -> String:
	if not says_writing():
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
		# And two of a part in one place turned two ways by how each is
		# turned, not by which the world held first: two copies of a model
		# built in another order (Together) wrote them the other way round.
		var turn: Basis = placement.transform.basis
		keys[n] = [placement.step, roundi(at.y * 1000.0), placement.group,
			placement.part_id, roundi(at.x * 1000.0), roundi(at.z * 1000.0),
			placement.color_code, _turn_key(turn.x), _turn_key(turn.y), _turn_key(turn.z), n]
	keys.sort()
	var ordered: Array = []
	ordered.resize(keys.size())
	for n: int in keys.size():
		ordered[n] = placements[int((keys[n] as Array)[10])]
	return ordered


## [param bricks] in an order of what each is and where, whatever order
## they were put down in ([method _in_file_order]'s, for bricks).
static func _in_brick_order(bricks: Array) -> Array:
	var keys: Array = []
	keys.resize(bricks.size())
	for n: int in bricks.size():
		var brick: BrickWorld.Brick = bricks[n]
		var at: Vector3 = brick.transform.origin
		var turn: Basis = brick.transform.basis
		keys[n] = [brick.step, brick.unit, brick.group, brick.part_id, roundi(at.y * 1000.0),
			roundi(at.x * 1000.0), roundi(at.z * 1000.0), brick.color_code, _turn_key(turn.x),
			_turn_key(turn.y), _turn_key(turn.z), n]
	keys.sort()
	var ordered: Array = []
	ordered.resize(keys.size())
	for n: int in keys.size():
		ordered[n] = bricks[int((keys[n] as Array)[11])]
	return ordered


## A column of a part's turn as one number, to the thousandth.
static func _turn_key(column: Vector3) -> int:
	return ((roundi(column.x * 1000.0) + 1001) * 2003 + roundi(column.y * 1000.0) + 1001) * 2003 \
		+ roundi(column.z * 1000.0) + 1001


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
	var text: String = ReferenceImage.written_into(SetBin.written_into(with_share(
		written if not written.is_empty() else to_text(title, with_steps), share_id,
		remixed_from, remixed_from_version, credit, made_with), bin_sets), reference)
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
		kept_save.emit(path)
	return true


## Whether LDraw [param text] places anything: a line of type 1 anywhere.
## Read without parsing it, since the autosave asks on every write.
static func _has_parts(text: String) -> bool:
	return text.begins_with("1 ") or text.find("\n1 ") >= 0


## [param text] with the link it is shared at and the link it was copied
## from, each on a line after its first (inside the model itself, for an
## .mpd), and who laid its parts ([member made_with]) when that is known;
## as it is for none.
static func with_share(text: String, id: String, remix: String = "", remix_version: int = 0,
		credited: Dictionary = {}, made: String = "") -> String:
	var lines: String = (SHARE_META + id + "\n" if not id.is_empty() else "") \
		+ (REMIX_META + remix + "\n" if not remix.is_empty() else "") \
		+ (REMIX_VERSION_META + str(remix_version) + "\n" if not remix.is_empty() and remix_version > 0 else "") \
		+ (CREDIT_META + JSON.stringify(credited) + "\n" if not credited.is_empty() else "") \
		+ (MADE_META + made + "\n" if made in MADE_WAYS else "")
	if lines.is_empty():
		return text
	var cut: int = text.find("\n")
	if cut < 0:
		return text + "\n" + lines
	return text.substr(0, cut + 1) + lines + text.substr(cut + 1)


## Who a model's text says made it ([member credit]), or {}: each of by,
## licence, page and from a line of words, the page an https address.
static func credit_in(text: String) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS CREDIT (\\{.*\\})\\s*$").search(text)
	if found == null:
		return {}
	var json := JSON.new()
	if json.parse(found.get_string(1)) != OK or not json.data is Dictionary:
		return {}
	var out: Dictionary = {}
	for key: String in ["by", "licence", "page", "from"]:
		var value: Variant = (json.data as Dictionary).get(key)
		if value is String and not (value as String).is_empty():
			out[key] = (value as String).replace("\n", " ").left(200)
	if not str(out.get("page", "")).begins_with("https://"):
		out.erase("page")
	return out


## Who a model's text says laid its parts ([member made_with]), or empty
## when it does not say.
static func made_in(text: String) -> String:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS MADE ([a-z]+)\\s*$").search(text)
	return found.get_string(1) if found != null and found.get_string(1) in MADE_WAYS else ""


## The link a model's text says it is shared at, or empty.
static func share_in(text: String) -> String:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS SHARE ([A-Za-z0-9]{10})\\s*$").search(text)
	return found.get_string(1) if found != null else ""


## Which version of that link a model's text says it was copied from, or 0.
static func remix_version_in(text: String) -> int:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^0 !BRICKWORKS REMIX_VERSION ([1-9][0-9]{0,5})\\s*$").search(text)
	return found.get_string(1).to_int() if found != null else 0


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
