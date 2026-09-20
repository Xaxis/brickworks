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


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Call whenever the model changes. Writing is deferred and coalesced.
func touch() -> void:
	_dirty_at = Time.get_ticks_msec()
	_pending = true


## Call once a frame. Writes the working model when it has settled.
func tick() -> void:
	if not _pending:
		return
	if Time.get_ticks_msec() - _dirty_at < AUTOSAVE_DELAY_MS:
		return
	_pending = false
	_write(AUTOSAVE, "Working model")


## Restore the working model from the last session, if there is one.
func restore() -> int:
	if not FileAccess.file_exists(AUTOSAVE):
		return 0
	return open(AUTOSAVE)


func save_as(name: String) -> bool:
	var clean: String = _safe_name(name)
	if clean.is_empty():
		return false
	if _write(SAVE_DIR + clean + ".ldr", name):
		saved.emit(name)
		return true
	return false


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
func open(path: String) -> int:
	var model: LdrModel = LdrModel.load_file(path)
	if model == null:
		return 0

	world.clear()
	builder.lattice.clear()
	scenery.clear()

	var placed: int = 0
	for item: Variant in model.flatten(library.parts):
		var placement: LdrModel.Placement = item
		var brick_id: int = world.add_brick(
			placement.part_id, placement.color_code, placement.transform)
		if brick_id != 0:
			builder.register(brick_id, placement.part_id, placement.transform)
			placed += 1

	loaded.emit(path.get_file(), placed)
	return placed


## The model as LDraw text, for export or for handing to something else.
func to_text(title: String = "Model") -> String:
	var placements: Array = []
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		if scenery.has(brick.id):
			continue
		placements.append(LdrModel.Placement.new(
			brick.part_id, brick.color_code, brick.transform, 0))
	# Bottom to top, so the file reads in the order it would be built.
	placements.sort_custom(func(a: LdrModel.Placement, b: LdrModel.Placement) -> bool:
		return a.transform.origin.y < b.transform.origin.y)
	return LdrModel.write_ldr(placements, title, "Brickworks")


## Send the model to the person as a file.
##
## On desktop this is a write. In a browser a page cannot write to disk,
## so the bytes are handed to the browser as a download instead — the
## same model either way, by two entirely different mechanisms.
func export_to(path: String, title: String = "Model") -> bool:
	var text: String = to_text(title)
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


func _write(path: String, title: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s (%d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(to_text(title))
	file.close()
	return true


static func _count_bricks(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var count: int = 0
	while not file.eof_reached():
		if file.get_line().begins_with("1 "):
			count += 1
	file.close()
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
