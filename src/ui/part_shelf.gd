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


# ── palettes (APP_UX6 palettes) ────────────────────────────────────────────
#
# A person's own palettes, as Studio keeps custom palettes: each named, of
# parts in their colours and of sub-assemblies, kept apart from any model so
# what was gathered in one is there in the next. Favourites stays one list of
# parts, as it was.
#
# In a file of their own (palettes_file), so choosing a part, which writes
# Recent, never rewrites them, however big a kept sub-assembly is.
#
# Never lost when two windows or tabs change them. Every palette and every
# entry has an id of its own, and what is taken out is remembered by its id
# (gone). Before any change the file is read again and merged with what this
# window holds: both windows' additions stay, and nothing taken out comes
# back. A tab whose copy another tab's older write replaced (the web copies
# each tab's writes to the others a moment late) finds its own additions
# missing when it next reads, and writes them back.
#
# Never lost to an older build either: after an update a tab left open runs
# the old build beside a new one, on the same file. What this build does not
# know (a word a later build adds to a palette or an entry, or a kind of entry
# of its own) is held as it was read and written back whole, never shown.
# A file that cannot be read is kept beside it before a change writes over it.

## Where they are kept. A probe points this elsewhere, as it does [member file].
static var palettes_file: String = "user://palettes.cfg"
## Each {id, name, named, entries}; an entry {id, part, colour} or a
## sub-assembly's {id, name, named, ldraw, count}. ``named`` is when its
## name was given (ms since 1970), so the later of two renames wins.
static var _palettes: Array = []
## The ids of palettes and entries taken out, id -> true.
static var _gone: Dictionary = {}
## Entries of kinds a later build keeps, palette id -> [entry], as read.
static var _later: Dictionary = {}
static var _palettes_from: String = ""
## The file's time and size when it was last read or written here.
static var _palettes_stamp: Array = []
## Counts every change to what is held, read or made: the bin redraws on it.
static var palettes_revision: int = 0
## Taken-out ids remembered, the oldest forgotten past this.
const GONE_MOST := 4000
## The longest name kept.
const NAME_MOST := 60


## The palettes, in the order they were made. Read only: change them with
## the functions below.
static func palettes() -> Array:
	_load_palettes()
	return _palettes


## The palette with [param id], or an empty one.
static func palette(id: String) -> Dictionary:
	_load_palettes()
	for one: Dictionary in _palettes:
		if str(one["id"]) == id:
			return one
	return {}


## Whether another window or tab changed the file since it was last read
## here: read and merged if so. The bin asks about once a second while it
## shows a palette.
static func palettes_changed() -> bool:
	var was: int = palettes_revision
	_load_palettes()
	return palettes_revision != was


## A new palette called [param name] (or "Palette 2" and on, where none is
## given or the name is taken). Returns its id.
static func make_palette(name: String = "") -> String:
	_load_palettes(true)
	var id: String = _new_id()
	_palettes.append({"id": id, "name": unused_palette_name(name), "named": _now(), "entries": []})
	_changed()
	return id


static func rename_palette(id: String, name: String) -> bool:
	_load_palettes(true)
	var one: Dictionary = palette(id)
	var named: String = clean_name(name)
	if one.is_empty() or named.is_empty() or named == str(one["name"]):
		return false
	one["name"] = named
	one["named"] = _now()
	_changed()
	return true


## Take a palette out, all it holds with it.
static func delete_palette(id: String) -> bool:
	_load_palettes(true)
	for n: int in _palettes.size():
		if str(_palettes[n]["id"]) == id:
			_palettes.remove_at(n)
			_forget(id)
			_changed()
			return true
	return false


## [param pairs], each [part, colour], kept in the palette, each once.
## Returns how many were not there already, or -1 with no such palette.
static func keep_parts(id: String, pairs: Array) -> int:
	_load_palettes(true)
	var one: Dictionary = palette(id)
	if one.is_empty():
		return -1
	var there: Dictionary = {}
	for entry: Dictionary in one["entries"]:
		if entry.has("part"):
			there[_key_of(str(entry["part"]), int(entry["colour"]))] = true
	var added: int = 0
	for pair: Array in pairs:
		var part: String = str(pair[0]).strip_edges()
		var key: String = _key_of(part, int(pair[1]))
		if part.is_empty() or there.has(key):
			continue
		there[key] = true
		(one["entries"] as Array).append({"id": _new_id(), "part": part, "colour": int(pair[1])})
		added += 1
	if added > 0:
		_changed()
	return added


## A sub-assembly kept in the palette: [param ldraw], its parts as LDraw lines
## (Carry.as_ldraw), [param count] of them, called [param name]. Returns its
## entry's id, or "" with no such palette or nothing in it.
static func keep_assembly(id: String, name: String, ldraw: String, count: int) -> String:
	_load_palettes(true)
	var one: Dictionary = palette(id)
	if one.is_empty() or count <= 0 or not ldraw.contains("1 "):
		return ""
	var entry_id: String = _new_id()
	var named: String = clean_name(name)
	(one["entries"] as Array).append({"id": entry_id,
		"name": named if not named.is_empty() else "Sub-assembly",
		"named": _now(), "ldraw": ldraw, "count": count})
	_changed()
	return entry_id


## A sub-assembly's new name.
static func rename_entry(id: String, entry_id: String, name: String) -> bool:
	_load_palettes(true)
	var named: String = clean_name(name)
	for entry: Dictionary in palette(id).get("entries", []):
		if str(entry["id"]) == entry_id and entry.has("ldraw") and not named.is_empty() \
				and named != str(entry["name"]):
			entry["name"] = named
			entry["named"] = _now()
			_changed()
			return true
	return false


## An entry taken out of its palette.
static func take_out(id: String, entry_id: String) -> bool:
	_load_palettes(true)
	var entries: Array = palette(id).get("entries", [])
	for n: int in entries.size():
		if str(entries[n]["id"]) == entry_id:
			entries.remove_at(n)
			_forget(entry_id)
			_changed()
			return true
	return false


## [param wanted], or "Palette" where it is empty, and a number after it
## where a palette has that name already: "Palette 2".
static func unused_palette_name(wanted: String = "") -> String:
	var base: String = clean_name(wanted)
	if base.is_empty():
		base = "Palette"
	var taken: Dictionary = {}
	for one: Dictionary in _palettes:
		taken[str(one["name"]).to_lower()] = true
	if not taken.has(base.to_lower()):
		return base
	var n: int = 2
	while taken.has(("%s %d" % [base, n]).to_lower()):
		n += 1
	return "%s %d" % [base, n]


## What is held forgotten and read from the file afresh, as a new window
## starts: for a probe's restart.
static func forget_palettes() -> void:
	_palettes_from = ""
	_palettes = []
	_gone = {}
	_later = {}
	_palettes_stamp = []


static func _changed() -> void:
	palettes_revision += 1
	_keep_palettes()


static func _forget(id: String) -> void:
	_gone[id] = true
	while _gone.size() > GONE_MOST:
		_gone.erase(_gone.keys()[0])


static func clean_name(name: String) -> String:
	var out: String = name.strip_edges().replace("\n", " ").replace("\t", " ")
	return out.left(NAME_MOST).strip_edges()


static func _key_of(part: String, colour: int) -> String:
	return "%s/%d" % [part.to_lower(), colour]


static func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


## An id no other window will make: the time and a random number.
static func _new_id() -> String:
	return "%x%06x" % [_now(), randi() & 0xffffff]


static func _stamp_of(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	return [FileAccess.get_modified_time(path), FileAccess.get_size(path)]


## The file merged into what is held: when its time or size changed since it
## was last read or written here, and always before a change ([param force]).
static func _load_palettes(force: bool = false) -> void:
	if _palettes_from != palettes_file:
		forget_palettes()
		_palettes_from = palettes_file
		force = true
	if not keeps:
		return
	var stamp: Array = _stamp_of(palettes_file)
	if not force and stamp == _palettes_stamp:
		return
	var read: Variant = _read_palettes(palettes_file)
	# There, but not readable: another window halfway through writing it, or
	# damaged. What is held stays and the file is read again once it changes; a
	# change about to write over it keeps a copy of it beside it first.
	if read == null:
		if force:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(palettes_file),
				ProjectSettings.globalize_path(palettes_file + ".unreadable"))
		else:
			# Read again when it changes, not each second the bin asks.
			_palettes_stamp = stamp
		return
	var theirs: Dictionary = read
	var merged: Array = _merged(_palettes, _gone, theirs["palettes"], theirs["gone"])
	var before: String = var_to_str([_palettes, _gone.keys()])
	_palettes = merged[0]
	_gone = merged[1]
	_later = _later_merged(_later, theirs["later"])
	_palettes_stamp = stamp
	if var_to_str([_palettes, _gone.keys()]) != before:
		palettes_revision += 1
	# What was held here and the file lacks, or the other way round: written
	# back, so both windows' changes are in the file.
	if var_to_str(_palettes) != var_to_str(theirs["palettes"]) \
			or _gone.size() != (theirs["gone"] as Dictionary).size() \
			or var_to_str(_later) != var_to_str(theirs["later"]):
		_keep_palettes()


## {palettes, gone, later} as [param path] holds them, every entry checked:
## those not whole are left out, and those of kinds a later build keeps go in
## later (palette id -> [entry]). Nothing there is none; null when it is
## there and cannot be read.
static func _read_palettes(path: String) -> Variant:
	var none: Dictionary = {"palettes": [], "gone": {}, "later": {}}
	if not FileAccess.file_exists(path):
		return none
	var kept := ConfigFile.new()
	if kept.load(path) != OK:
		return null
	var palettes_read: Array = []
	var later: Dictionary = {}
	var listed: Variant = kept.get_value("palettes", "list", [])
	for one: Variant in (listed as Array if listed is Array else []):
		var theirs_later: Array = []
		var whole: Dictionary = _palette_read(one, theirs_later)
		if whole.is_empty():
			continue
		palettes_read.append(whole)
		if not theirs_later.is_empty():
			later[str(whole["id"])] = theirs_later
	var gone: Dictionary = {}
	var ids: Variant = kept.get_value("palettes", "gone", PackedStringArray())
	if ids is PackedStringArray or ids is Array:
		for id: Variant in ids:
			gone[str(id)] = true
	return {"palettes": palettes_read, "gone": gone, "later": later}


## A palette as read: what it holds checked, and whatever else a later build
## wrote in it kept as it was. Entries of kinds this build does not know go
## in [param later].
static func _palette_read(one: Variant, later: Array) -> Dictionary:
	if not one is Dictionary:
		return {}
	var given: Dictionary = one
	var id: String = str(given.get("id", ""))
	var name: String = clean_name(str(given.get("name", "")))
	if id.is_empty() or name.is_empty():
		return {}
	var entries: Array = []
	var listed: Variant = given.get("entries", [])
	for entry: Variant in (listed as Array if listed is Array else []):
		if entry is Dictionary and not (entry as Dictionary).has("part") \
				and not (entry as Dictionary).has("ldraw") \
				and not str((entry as Dictionary).get("id", "")).is_empty():
			later.append((entry as Dictionary).duplicate(true))
			continue
		var whole: Dictionary = _entry_read(entry)
		if not whole.is_empty():
			entries.append(whole)
	var out: Dictionary = given.duplicate(true)
	out["id"] = id
	out["name"] = name
	out["named"] = int(given.get("named", 0))
	out["entries"] = entries
	return out


static func _entry_read(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var given: Dictionary = entry
	var id: String = str(given.get("id", ""))
	if id.is_empty():
		return {}
	var out: Dictionary = given.duplicate(true)
	out["id"] = id
	if given.has("part"):
		var part: String = str(given["part"]).strip_edges()
		if part.is_empty():
			return {}
		out["part"] = part
		out["colour"] = int(given.get("colour", 16))
		return out
	var ldraw: String = str(given.get("ldraw", ""))
	var count: int = int(given.get("count", 0))
	if not ldraw.contains("1 ") or count <= 0:
		return {}
	var name: String = clean_name(str(given.get("name", "")))
	out["name"] = name if not name.is_empty() else "Sub-assembly"
	out["named"] = int(given.get("named", 0))
	out["ldraw"] = ldraw
	out["count"] = count
	return out


## The later builds' entries held here and those the file has, made one:
## the file's first, then those only held here (an older copy stored over
## the file lacks them), none taken out, none of a palette no longer kept.
static func _later_merged(held: Dictionary, theirs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for one: Dictionary in _palettes:
		var id: String = str(one["id"])
		var entries: Array = []
		var placed: Dictionary = {}
		for entry: Dictionary in (theirs.get(id, []) as Array) + (held.get(id, []) as Array):
			var entry_id: String = str(entry.get("id", ""))
			if _gone.has(entry_id) or placed.has(entry_id):
				continue
			placed[entry_id] = true
			entries.append(entry)
		if not entries.is_empty():
			out[id] = entries
	return out


## [mine] and [theirs] made one, as [palettes, gone]: every palette and entry
## of either that neither took out, the file's first and in its order, then
## those only held here; of two names, the later given.
static func _merged(mine: Array, mine_gone: Dictionary, theirs: Array,
		theirs_gone: Dictionary) -> Array:
	var gone: Dictionary = mine_gone.duplicate()
	gone.merge(theirs_gone)
	var own: Dictionary = {}
	for one: Dictionary in mine:
		own[str(one["id"])] = one
	var out: Array = []
	var placed: Dictionary = {}
	for one: Dictionary in theirs:
		var id: String = str(one["id"])
		if gone.has(id) or placed.has(id):
			continue
		placed[id] = true
		out.append(_palette_merged(own.get(id, {}), one, gone))
	for one: Dictionary in mine:
		var id: String = str(one["id"])
		if gone.has(id) or placed.has(id):
			continue
		placed[id] = true
		out.append(_palette_merged({}, one, gone))
	return [out, gone]


static func _palette_merged(mine: Dictionary, theirs: Dictionary, gone: Dictionary) -> Dictionary:
	var named_by: Dictionary = theirs if mine.is_empty() \
		or int(theirs["named"]) >= int(mine["named"]) else mine
	var own: Dictionary = {}
	for entry: Dictionary in mine.get("entries", []):
		own[str(entry["id"])] = entry
	var entries: Array = []
	var placed: Dictionary = {}
	var parts: Dictionary = {}
	for entry: Dictionary in (theirs["entries"] as Array) + (mine.get("entries", []) as Array):
		var id: String = str(entry["id"])
		if gone.has(id) or placed.has(id):
			continue
		placed[id] = true
		# The same part and colour kept by two windows at once: once.
		if entry.has("part"):
			var key: String = _key_of(str(entry["part"]), int(entry["colour"]))
			if parts.has(key):
				continue
			parts[key] = true
			entries.append(entry.duplicate())
			continue
		var kept: Dictionary = entry.duplicate()
		var here: Dictionary = own.get(id, {})
		if not here.is_empty() and int(here["named"]) > int(entry["named"]):
			kept["name"] = here["name"]
			kept["named"] = here["named"]
		entries.append(kept)
	# What else the file's palette holds (a later build's words) stays.
	var out: Dictionary = theirs.duplicate()
	out["name"] = named_by["name"]
	out["named"] = named_by["named"]
	out["entries"] = entries
	return out


static func _keep_palettes() -> void:
	if not keeps:
		return
	var list: Array = _palettes
	if not _later.is_empty():
		list = []
		for one: Dictionary in _palettes:
			var with_later: Dictionary = one
			if _later.has(str(one["id"])):
				with_later = one.duplicate()
				with_later["entries"] = (one["entries"] as Array) + (_later[str(one["id"])] as Array)
			list.append(with_later)
	var kept := ConfigFile.new()
	kept.set_value("palettes", "list", list)
	kept.set_value("palettes", "gone", PackedStringArray(_gone.keys()))
	TabSession.writing(palettes_file)
	# On a computer another window may read it at any moment: written beside
	# it and put in its place whole, so a read never finds half of it. A
	# browser's tabs each have their own copy, which the page stores whole.
	if OS.has_feature("web"):
		kept.save(palettes_file)
	else:
		var beside: String = palettes_file + ".new"
		if kept.save(beside) != OK or DirAccess.rename_absolute(
				ProjectSettings.globalize_path(beside),
				ProjectSettings.globalize_path(palettes_file)) != OK:
			kept.save(palettes_file)
	_palettes_stamp = _stamp_of(palettes_file)
