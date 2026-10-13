## The parts a person keeps reaching for: the ones used lately, and the
## ones they marked to keep.
##
## A bin of twenty-eight thousand parts is searched once per part and then
## wanted again and again — the 1 x 2 plate, the window that goes in every
## wall. Studio keeps a recently-used row and custom palettes for this;
## here the only way back to a part was its number or the eyedropper.
##
## Kept in the app's own settings, apart from any model, so it is the same
## from one model and one visit to the next.
class_name PartShelf
extends RefCounted

## Where it is kept. A probe points this elsewhere so a run never touches
## the shelf of the person at this machine.
static var file: String = "user://part_shelf.cfg"
## How many recent parts are remembered.
const MOST_RECENT := 24

## Whether it is kept on disk at all. Not under a probe (any run with
## --script), which would otherwise write this machine's own shelf; a
## probe about the shelf points [member file] somewhere of its own and
## turns this back on.
static var keeps: bool = not OS.get_cmdline_args().has("--script")

static var _recent: PackedStringArray = PackedStringArray()
static var _favourites: PackedStringArray = PackedStringArray()
static var _read_from: String = ""
## When the file was last read or written here: another tab or window
## that changes the shelf writes it too, and its parts are read again
## before this one changes anything, rather than written over.
static var _read_at: int = 0


## Read the shelf again: another tab changed it (Main, _watch_other_tabs).
static func reread() -> void:
	_read_from = ""


static func _load() -> void:
	if _read_from == file and (not keeps or not FileAccess.file_exists(file)
			or FileAccess.get_modified_time(file) == _read_at):
		return
	_read_from = file
	_read_at = FileAccess.get_modified_time(file) if FileAccess.file_exists(file) else 0
	_recent = PackedStringArray()
	_favourites = PackedStringArray()
	var kept := ConfigFile.new()
	if not keeps or kept.load(file) != OK:
		return
	_recent = PackedStringArray(kept.get_value("shelf", "recent", PackedStringArray()))
	_favourites = PackedStringArray(kept.get_value("shelf", "favourites", PackedStringArray()))


static func _keep() -> void:
	if not keeps:
		return
	var kept := ConfigFile.new()
	kept.set_value("shelf", "recent", _recent)
	kept.set_value("shelf", "favourites", _favourites)
	TabSession.writing(file)
	kept.save(file)
	_read_at = FileAccess.get_modified_time(file)


## A part was reached for: it goes to the front of the recent ones.
static func used(part_id: String) -> void:
	if part_id.is_empty():
		return
	_load()
	var at: int = _recent.find(part_id)
	if at == 0:
		return
	if at > 0:
		_recent.remove_at(at)
	_recent.insert(0, part_id)
	if _recent.size() > MOST_RECENT:
		_recent.resize(MOST_RECENT)
	_keep()


static func recent() -> PackedStringArray:
	_load()
	return _recent


static func favourites() -> PackedStringArray:
	_load()
	return _favourites


static func is_favourite(part_id: String) -> bool:
	_load()
	return _favourites.has(part_id)


## Mark it to keep, or unmark it. Returns whether it is kept now.
static func toggle_favourite(part_id: String) -> bool:
	_load()
	var at: int = _favourites.find(part_id)
	if at >= 0:
		_favourites.remove_at(at)
	else:
		_favourites.append(part_id)
	_keep()
	return at < 0


## Forget everything, for a probe starting clean.
static func clear() -> void:
	_recent = PackedStringArray()
	_favourites = PackedStringArray()
	_read_from = file
	_keep()
