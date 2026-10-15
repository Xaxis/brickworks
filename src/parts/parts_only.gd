## A run limited to a list of parts: --parts-only=FILE on the command line.
##
## BrickBench, the outside benchmark (docs/BRICKBENCH.md), allows only
## BrickNet's 14,441 parts: no stickers, no unofficial parts, under half of
## this catalogue. tools/bench/brickbench.py starts each of its designs with
## this flag, and the run keeps to the list where a design chooses parts:
##
##   - search_parts and find_parts_like list only parts on it;
##   - a design or an edit with a part off it is refused, naming the part
##     and asking for a swap (Assistant._check);
##   - add_minifig chooses only parts on it;
##   - make_part, lay_flex and print_part, which make parts no list has,
##     are refused;
##   - and every call that leaves a part off the list on the model says so
##     (CommandSocket), so nothing another tool laid goes unnoticed.
##
## Without the flag nothing changes: [method allows] is true of every part
## and [method active] is false, so a person's app is the app it was.
##
## The file: one part number a line; lines starting # are notes, and the
## first of them names the list in what the designer is told.
class_name PartsOnly
extends RefCounted

const FLAG := "--parts-only="
## The tools that make parts of their own, which no list holds.
const MAKERS: Array[String] = ["make_part", "lay_flex", "print_part"]

static var _lock := Mutex.new()
static var _read: bool = false
## Part number, lower case -> true. Empty is no limit.
static var _allowed: Dictionary = {}
static var _named: String = ""


## Whether this run keeps to a list.
static func active() -> bool:
	_load()
	return not _allowed.is_empty()


## Whether [param part_id] may be used: always, without a list.
static func allows(part_id: String) -> bool:
	_load()
	return _allowed.is_empty() or _allowed.has(part_id.to_lower())


## What the list is, as the designer is told it.
static func named() -> String:
	_load()
	return _named if not _named.is_empty() else "the parts on this run's list"


## The parts of [param ids] that may not be used, each once.
static func barred(ids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for part_id: String in ids:
		if not allows(part_id) and not out.has(part_id):
			out.append(part_id)
	return out


## Use this list instead of the flag's: empty for none. For probes.
static func use(ids: PackedStringArray, name: String = "") -> void:
	_lock.lock()
	_read = true
	_allowed = {}
	for part_id: String in ids:
		_allowed[part_id.strip_edges().to_lower()] = true
	_named = name
	_lock.unlock()


## A list file read: [part number -> true, its name].
static func read_list(text: String) -> Array:
	var allowed: Dictionary = {}
	var name: String = ""
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("#"):
			if name.is_empty():
				name = line.trim_prefix("#").strip_edges()
			continue
		allowed[line.to_lower()] = true
	return [allowed, name]


## Why a design that uses [param part_id] is refused, and what to do.
static func swap_words(part_id: String) -> String:
	return "%s is not among %s; swap it for one search_parts lists" % [part_id, named()]


## Why [param tool] is not done in this run, or "".
static func tool_refusal(tool: String) -> String:
	if not active() or not MAKERS.has(tool):
		return ""
	return ("Not in this run: %s makes parts of its own, and this run uses only %s. "
		% [tool, named()] + "Build it from parts search_parts lists.")


## What is on the model and off the list, as a line for the designer, or "".
## [param scenery] holds the floor's brick ids, which are not the design's.
static func on_model(world: BrickWorld, scenery: Dictionary,
		library: PartLibrary = null) -> String:
	if not active() or world == null:
		return ""
	var found: Dictionary = {}     ## part -> brick ids
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id) or allows(brick.part_id):
			continue
		if not found.has(brick.part_id):
			found[brick.part_id] = []
		(found[brick.part_id] as Array).append(brick.id)
	if found.is_empty():
		return ""
	var named_parts := PackedStringArray()
	for part_id: String in found:
		var ids: Array = found[part_id]
		var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
		var numbers := PackedStringArray()
		for brick_id: Variant in ids.slice(0, 3):
			numbers.append("#%d" % int(brick_id))
		named_parts.append("%s%s x%d (%s%s)" % [part_id,
			(" " + info.name.strip_edges()) if info != null else "", ids.size(),
			", ".join(numbers), ", ..." if ids.size() > 3 else ""])
	return ("This run uses only %s, and the model has parts that are not among them: %s. "
		% [named(), "; ".join(named_parts)] + "Swap each with edit_model for one "
		+ "search_parts lists, or take it off: until then every edit is refused.")


static func _load() -> void:
	_lock.lock()
	if not _read:
		_read = true
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with(FLAG):
				_take(argument.trim_prefix(FLAG))
	_lock.unlock()


## The flag's file. One that cannot be read keeps the run to nothing at all,
## so it fails where it can be seen rather than running unlimited.
static func _take(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var read: Array = read_list(text)
	_allowed = read[0]
	_named = read[1]
	if _allowed.is_empty():
		_allowed = {"": true}
		push_error("parts only: nothing could be read from %s, so no part is allowed" % path)
		return
	# In the run's log, so a batch shows the flag took.
	print("parts only: %d parts (%s), from %s" % [_allowed.size(),
		_named if not _named.is_empty() else "unnamed", path])
