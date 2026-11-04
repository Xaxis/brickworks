## What real sets show that LDraw's names do not, measured from them: which
## minifigure parts a licence or a named cast alone carries, the arms official
## figures put with a plain torso of each colour (tools/minifig_sets.py), and
## how big the official minifigure-scale models of each kind are
## (tools/set_sizes.py), and how much of its box each fills (Massing,
## src/dev/set_massing.gd).
##
## Read from assets/knowledge; on the web, which leaves that folder out of the
## pack, fetched from beside the build the first time a design asks, as the
## real-set index is (RealSnippets.fetch).
class_name SetKnowledge
extends RefCounted

const FIGURES := "res://assets/knowledge/minifig_sets.json"
const SIZES := "res://assets/knowledge/set_sizes.json"
const MASSING := "res://assets/knowledge/set_massing.json"

static var _read: Dictionary = {}
## sizes() with the sets under test left out, and what was held when it was.
static var _sized: Array = []
static var _sized_for: String = ""
## massing() with the sets under test left out, and what was held when it was.
static var _massed: Dictionary = {}
static var _massed_for: String = ""


## minifig_sets.json: {"parts": {id: [sets, generic sets]}, "plain_arms":
## {torso colour: [[arm colour, figures]]}}, or {} where this build has none.
static func figures() -> Dictionary:
	return _load(FIGURES)


## set_sizes.json's models: [set, set name, theme, model, parts, studs long,
## studs wide, plates tall]. None of a set under test (DesignMemory.holds):
## plan_scale told 7242-1's session "7242 Street Sweeper 15" (2026-10-31).
static func sizes() -> Array:
	var models: Array = _load(SIZES).get("models", [])
	if DesignMemory.held_out().is_empty() and DesignMemory.held_names().is_empty():
		return models
	var held: String = ",".join(DesignMemory.held_out()) + "|" + "|".join(DesignMemory.held_names())
	if _sized_for != held or _sized.is_empty():
		_sized_for = held
		_sized = models.filter(func(row: Variant) -> bool:
			return not DesignMemory.holds(str((row as Array)[0]), str((row as Array)[1])))
	return _sized


## set_massing.json: {"keys": [measure], "models": [[set, set name, theme,
## parts, each measure]]}, none of a set under test (DesignMemory.holds), or
## {} where this build has none.
static func massing() -> Dictionary:
	var table: Dictionary = _load(MASSING)
	if DesignMemory.held_out().is_empty() and DesignMemory.held_names().is_empty():
		return table
	var held: String = ",".join(DesignMemory.held_out()) + "|" + "|".join(DesignMemory.held_names())
	if _massed_for != held or _massed.is_empty():
		_massed_for = held
		_massed = {"keys": table.get("keys", []), "models": (table.get("models", []) as Array).filter(
			func(row: Variant) -> bool:
				return not DesignMemory.holds(str((row as Array)[0]), str((row as Array)[1])))}
	return _massed


static func _load(path: String) -> Dictionary:
	if not _read.has(path) and (not OS.has_feature("web") or FileAccess.file_exists(path)):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_read[path] = parsed if parsed is Dictionary else {}
	return _read.get(path, {})


## The files, fetched on the web where the build left them out. Awaited.
static func ensure(host: Node) -> void:
	for path: String in [FIGURES, SIZES, MASSING]:
		if _read.has(path) or not OS.has_feature("web") or FileAccess.file_exists(path):
			continue
		_read[path] = {}
		var bytes: PackedByteArray = await RealSnippets.fetch(host, path.get_file())
		var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		_read[path] = parsed if parsed is Dictionary else {}


## 2 for a minifigure part sets carry outside a licence or a named cast (at
## least half of those that carry it), 0 for one only theirs carry, 1 where
## no set inventory is known to carry it.
static func generic(part_id: String) -> int:
	var known: Variant = (figures().get("parts", {}) as Dictionary).get(part_id)
	if not known is Array or (known as Array).size() < 2:
		return 1
	return 2 if int(known[1]) * 2 >= int(known[0]) else 0


## How many sets carry a minifigure part, by the figures' own inventories.
static func carried(part_id: String) -> int:
	var known: Variant = (figures().get("parts", {}) as Dictionary).get(part_id)
	return int(known[0]) if known is Array and not (known as Array).is_empty() else 0


## The arm colour official figures put most with a plain torso in
## [param torso], or -1 where none is known.
static func plain_arms(torso: int) -> int:
	var pairs: Array = (figures().get("plain_arms", {}) as Dictionary).get(str(torso), [])
	return int((pairs[0] as Array)[0]) if not pairs.is_empty() else -1
