## The collection this device keeps for whoever uses it signed out
## (localbricks, APP_UX6 #8, 2026-11-07).
##
## A first visit could not say what it owns until it had an account, and
## LEGO from my bricks keeps a person's bricks without one. So with nobody
## signed in, My collection is this device's own: loose lots and sets added,
## counted, marked missing and taken out as they are with an account, the
## same ops checked the same way ([method apply] is api/collection.js's
## applyOp, op for op), and offered to the account when somebody signs in
## (CollectionStore.join), never put there unasked.
##
## Nothing of it may be lost, with two tabs or windows open at once: every
## tab of a site shares the browser's storage and every window of the app
## one folder, and a file written whole by two at once keeps only the
## second's. So each tab or window writes only a file of its own in
## [member folder] (TabSession's id), holding what it changed: each lot's
## count as a sum of what it added and took away, per part, colour and
## whose ([method lot_key], api/collection.js's lotKey), and each set's
## copies and missing parts the same way. The collection is every file's
## sums put together ([method read]). A change is checked against that, as
## the account checks one against its row, and kept as how far it moves
## each count; two made at the same moment in two tabs, each before it saw
## the other, both stay.
##
## A join, once asked for, is kept in the file of the tab that made it
## with what it sent and its id before it is sent, and settled when the
## account answers: "applied" takes what it sent off this device, once
## however many tabs saw the answer; "returned" (refused, so never made)
## leaves it here. With no answer it stays pending: shown here signed out,
## offered to nobody, and sent again with its id, which the account never
## makes twice, when its account signs in again.
class_name CollectionHere
extends RefCounted

## The most one lot holds, as the account keeps it (api/collection.js
## MAX_QTY).
const MAX_QTY := 100000
## The most lots one set is marked as missing (MOST_MISSING).
const MOST_MISSING := 5000
## The most lots one change names (MOST_LOT_CHANGES).
const MOST_LOT_CHANGES := 2000
## The most sets and lots a collection holds (MAX_SETS, MAX_LOTS).
const MAX_SETS := 5000
const MAX_LOTS := 20000
## Where a lot or a set comes from, as the account knows them; "hand" is My
## collection's own.
const SOURCES := ["hand", "rebrickable", "bricklink_xml"]
const HAND := "hand"

static var _part_shape: RegEx = RegEx.create_from_string("^[a-z0-9][a-z0-9._-]{0,40}$")
static var _set_shape: RegEx = RegEx.create_from_string("^[a-z0-9][a-z0-9._]{0,24}(-[0-9]{1,3})?$")
static var _fig_shape: RegEx = RegEx.create_from_string("^[a-z0-9][a-z0-9._]{0,40}$")
static var _versioned: RegEx = RegEx.create_from_string("-[0-9]{1,3}$")
static var _chat_shape: RegEx = RegEx.create_from_string("^[A-Za-z0-9][A-Za-z0-9._:-]{0,99}$")
static var _digits: RegEx = RegEx.create_from_string("^[0-9]{1,9}$")


# --- the files ------------------------------------------------------------

## One lot per part, colour and whose: api/collection.js's lotKey.
static func lot_key(lot: Dictionary) -> String:
	return JSON.stringify([str(lot.get("part", "")), int(lot.get("colour", 0)), _text(lot, "src"),
		_text(lot, "by"), _text(lot, "chat")])


## One set entry per number and source: setKey.
static func set_key(entry: Dictionary) -> String:
	return JSON.stringify([str(entry.get("set", "")), _text(entry, "src")])


static func _text(entry: Dictionary, field: String) -> String:
	return str(entry.get(field, "")) if entry.get(field) != null else ""


## Every tab's file in [param folder], put together: {"raw": the sums,
## unshown ones too ({"parts": key -> {"lot", "qty", "at"}, "sets": key ->
## {"entry", "qty", "at", "missing": key -> {"lot", "qty"}}}), "shown": the
## collection as kept ({"sets", "parts"}, Collection.from_json's shape),
## "pending": the joins sent with no answer yet, "declined": account ->
## what was offered when it said Not now, "unread": files that could not
## be read (never dropped: said)}.
static func read(folder: String) -> Dictionary:
	var raw: Dictionary = {"parts": {}, "sets": {}}
	var joins: Dictionary = {}
	var settled: Dictionary = {}
	var declined: Dictionary = {}
	var unread := PackedStringArray()
	for name: String in _writers(folder):
		var file: Variant = _read_file(folder, name)
		if file == null:
			unread.append(name)
			continue
		_add_file(raw, file)
		for join: Variant in (file as Dictionary).get("joins", []):
			if join is Dictionary and not joins.has(str(join.get("id", ""))):
				joins[str(join["id"])] = join
		var said: Variant = (file as Dictionary).get("settled", {})
		if said is Dictionary:
			for id: String in said:
				# Applied wins: a join the account made is off this device,
				# whatever another tab heard before it was.
				if str(said[id]) == "applied" or not settled.has(id):
					settled[id] = str(said[id])
		var turned: Variant = (file as Dictionary).get("declined", {})
		if turned is Dictionary:
			for who: String in turned:
				var at: Dictionary = turned[who] if turned[who] is Dictionary else {}
				if not declined.has(who) or int(at.get("at", 0)) > int((declined[who] as Dictionary).get("at", 0)):
					declined[who] = at
	var pending: Array = []
	for id: String in joins:
		if settled.get(id, "") == "applied":
			_take_off(raw, joins[id])
		elif not settled.has(id):
			pending.append(joins[id])
	return {"raw": raw, "shown": shown(raw), "pending": pending, "declined": declined, "unread": unread}


## The writers' names in [param folder]: each a tab's or window's.
static func _writers(folder: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return out
	for name: String in DirAccess.get_files_at(folder):
		var writer: String = ""
		if name.ends_with(".json"):
			writer = name.trim_suffix(".json")
		elif name.ends_with(".json.writing"):
			writer = name.trim_suffix(".json.writing")
		if not writer.is_empty() and not out.has(writer):
			out.append(writer)
	out.sort()
	return out


## A writer's file: its own, or what it was writing when it stopped (a
## crash between the two steps of [method _write_file]); null when there
## is one and it cannot be read, {} when there is none.
static func _read_file(folder: String, writer: String) -> Variant:
	for path: String in [folder.path_join(writer + ".json"), folder.path_join(writer + ".json.writing")]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
	for path: String in [folder.path_join(writer + ".json"), folder.path_join(writer + ".json.writing")]:
		if FileAccess.file_exists(path):
			return null
	return {}


static func _add_file(raw: Dictionary, file: Dictionary) -> void:
	for lot: Variant in file.get("parts", []):
		if not lot is Dictionary or str((lot as Dictionary).get("part", "")).is_empty():
			continue
		var key: String = lot_key(lot)
		var held: Dictionary = raw["parts"].get(key, {})
		if held.is_empty():
			held = {"lot": named_lot(lot), "qty": 0, "at": int(lot.get("at", 0))}
			raw["parts"][key] = held
		held["qty"] = int(held["qty"]) + int(lot.get("qty", 0))
		held["at"] = mini(int(held["at"]), int(lot.get("at", held["at"])))
	for entry: Variant in file.get("sets", []):
		if not entry is Dictionary or str((entry as Dictionary).get("set", "")).is_empty():
			continue
		var key: String = set_key(entry)
		var held: Dictionary = raw["sets"].get(key, {})
		if held.is_empty():
			held = {"entry": {"set": str(entry["set"])}, "qty": 0, "at": int(entry.get("at", 0)), "missing": {}}
			if not _text(entry, "src").is_empty():
				held["entry"]["src"] = _text(entry, "src")
			raw["sets"][key] = held
		_add_set(held, entry, 1)
		held["at"] = mini(int(held["at"]), int(entry.get("at", held["at"])))


## [param entry]'s copies and missing lots, times [param sign], into
## [param held]; its marks of a minifigure, spares and name kept.
static func _add_set(held: Dictionary, entry: Dictionary, sign: int) -> void:
	held["qty"] = int(held["qty"]) + sign * int(entry.get("qty", 0))
	if entry.get("fig") == true:
		held["entry"]["fig"] = true
	if entry.get("spares") == true:
		held["entry"]["spares"] = true
	if not _text(entry, "name").is_empty() and _text(held["entry"], "name").is_empty():
		held["entry"]["name"] = _text(entry, "name")
	var marks: Variant = entry.get("missing", [])
	for lot: Variant in marks if marks is Array else []:
		if not lot is Dictionary:
			continue
		var key: String = lot_key({"part": lot.get("part", ""), "colour": lot.get("colour", 0)})
		var was: Dictionary = (held["missing"] as Dictionary).get(key, {})
		if was.is_empty():
			was = {"lot": {"part": str(lot.get("part", "")), "colour": int(lot.get("colour", 0))}, "qty": 0}
			held["missing"][key] = was
		was["qty"] = int(was["qty"]) + sign * int(lot.get("qty", 0))


## What an applied join sent, taken off the sums.
static func _take_off(raw: Dictionary, join: Dictionary) -> void:
	for lot: Variant in join.get("parts", []):
		if not lot is Dictionary:
			continue
		var key: String = lot_key(lot)
		if not raw["parts"].has(key):
			raw["parts"][key] = {"lot": named_lot(lot), "qty": 0, "at": int(join.get("at", 0))}
		raw["parts"][key]["qty"] = int(raw["parts"][key]["qty"]) - int(lot.get("qty", 0))
	for entry: Variant in join.get("sets", []):
		if not entry is Dictionary:
			continue
		var key: String = set_key(entry)
		if not raw["sets"].has(key):
			raw["sets"][key] = {"entry": {"set": str(entry.get("set", ""))}, "qty": 0, "at": int(join.get("at", 0)),
				"missing": {}}
			if not _text(entry, "src").is_empty():
				raw["sets"][key]["entry"]["src"] = _text(entry, "src")
		_add_set(raw["sets"][key], entry, -1)


## The sums as a collection: each lot and set with a count of one or more,
## in the order each was first added, its missing lots those of one or more.
static func shown(raw: Dictionary) -> Dictionary:
	var parts: Array = []
	for key: String in raw["parts"]:
		var held: Dictionary = raw["parts"][key]
		if int(held["qty"]) > 0:
			var lot: Dictionary = (held["lot"] as Dictionary).duplicate()
			lot["qty"] = mini(MAX_QTY, int(held["qty"]))
			parts.append([int(held["at"]), key, lot])
	var sets: Array = []
	for key: String in raw["sets"]:
		var held: Dictionary = raw["sets"][key]
		if int(held["qty"]) <= 0:
			continue
		var entry: Dictionary = (held["entry"] as Dictionary).duplicate()
		entry["qty"] = int(held["qty"])
		entry["spares"] = entry.get("spares") == true
		var missing: Array = []
		for mark: String in held["missing"]:
			var lot: Dictionary = held["missing"][mark]
			if int(lot["qty"]) > 0 and entry.get("fig") != true:
				var kept: Dictionary = (lot["lot"] as Dictionary).duplicate()
				kept["qty"] = int(lot["qty"])
				missing.append(kept)
		if not missing.is_empty():
			entry["missing"] = missing
		sets.append([int(held["at"]), key, entry])
	var by_time := func(a: Array, b: Array) -> bool:
		return int(a[0]) < int(b[0]) if int(a[0]) != int(b[0]) else str(a[1]) < str(b[1])
	parts.sort_custom(by_time)
	sets.sort_custom(by_time)
	return {"sets": sets.map(func(one: Array) -> Dictionary: return one[2]),
		"parts": parts.map(func(one: Array) -> Dictionary: return one[2]), "updated_at": null, "rev": null}


## What [param read] keeps that could go to an account: every tab's sums
## less what each pending join sent ({"sets", "parts"}): never offered twice
## while an answer is awaited.
static func offerable(read: Dictionary) -> Dictionary:
	var raw: Dictionary = (read["raw"] as Dictionary).duplicate(true)
	for join: Dictionary in read["pending"]:
		_take_off(raw, join)
	var out: Dictionary = shown(raw)
	return {"sets": out["sets"], "parts": out["parts"]}


## A short name for what was offered, to know it again: changed by any lot
## or set added, counted or taken out.
static func signature(what: Dictionary) -> String:
	return JSON.stringify(what).md5_text()


## A lot as an op names it: its part, colour and whose.
static func named_lot(lot: Dictionary) -> Dictionary:
	var out: Dictionary = {"part": str(lot.get("part", "")), "colour": int(lot.get("colour", 0))}
	for field: String in ["src", "by", "chat"]:
		if not _text(lot, field).is_empty():
			out[field] = _text(lot, field)
	return out


## The collection moved from [param raw] (what [method read] summed) to
## [param next] (a collection as [method apply] made it), kept in
## [param writer]'s own file as how far it moved each count; with
## [param extra]'s "joins" added, its "settled" and "declined" put in.
## Returns why it could not be written, empty when it was.
static func write(folder: String, writer: String, raw: Dictionary, next: Variant, extra: Dictionary = {}) -> String:
	var own: Variant = _read_file(folder, writer)
	if own == null:
		return "this window's own record of the collection on this device could not be read, so nothing was changed"
	var file: Dictionary = own
	var now: int = int(Time.get_unix_time_from_system() * 1000.0)
	var lots: Dictionary = {}
	for lot: Variant in file.get("parts", []):
		if lot is Dictionary:
			lots[lot_key(lot)] = (lot as Dictionary).duplicate()
	var entries: Dictionary = {}
	for entry: Variant in file.get("sets", []):
		if entry is Dictionary:
			entries[set_key(entry)] = (entry as Dictionary).duplicate(true)
	if next is Dictionary:
		_move_lots(lots, raw, next, now)
		_move_sets(entries, raw, next, now)
	var out: Dictionary = {"v": 1, "writer": writer,
		"parts": lots.values().filter(func(lot: Dictionary) -> bool: return int(lot.get("qty", 0)) != 0),
		"sets": entries.values().filter(func(entry: Dictionary) -> bool: return _moves(entry)),
		"joins": (file.get("joins", []) as Array) + (extra.get("joins", []) as Array),
		"settled": file.get("settled", {}) if file.get("settled") is Dictionary else {},
		"declined": file.get("declined", {}) if file.get("declined") is Dictionary else {}}
	for id: String in extra.get("settled", {}):
		out["settled"][id] = extra["settled"][id]
	for who: String in extra.get("declined", {}):
		out["declined"][who] = extra["declined"][who]
	return _write_file(folder, writer, JSON.stringify(out))


static func _move_lots(lots: Dictionary, raw: Dictionary, next: Dictionary, now: int) -> void:
	var wanted: Dictionary = {}
	for lot: Variant in next.get("parts", []):
		wanted[lot_key(lot)] = lot
	var keys: Array = wanted.keys()
	for key: String in raw["parts"]:
		if not wanted.has(key) and int(raw["parts"][key]["qty"]) > 0:
			keys.append(key)
	for key: String in keys:
		var held: Dictionary = raw["parts"].get(key, {})
		var had: int = int(held.get("qty", 0))
		var want: int = int((wanted[key] as Dictionary).get("qty", 0)) if wanted.has(key) else 0
		if want == had:
			continue
		if not lots.has(key):
			var lot: Dictionary = named_lot(wanted[key] if wanted.has(key) else held["lot"])
			lot["qty"] = 0
			lot["at"] = int(held.get("at", now))
			lots[key] = lot
		lots[key]["qty"] = int(lots[key]["qty"]) + want - had


static func _move_sets(entries: Dictionary, raw: Dictionary, next: Dictionary, now: int) -> void:
	var wanted: Dictionary = {}
	for entry: Variant in next.get("sets", []):
		wanted[set_key(entry)] = entry
	var keys: Array = wanted.keys()
	for key: String in raw["sets"]:
		if not wanted.has(key) and int(raw["sets"][key]["qty"]) > 0:
			keys.append(key)
	for key: String in keys:
		var held: Dictionary = raw["sets"].get(key, {"entry": {}, "qty": 0, "missing": {}})
		var want: Dictionary = wanted.get(key, {})
		if not entries.has(key):
			var made: Dictionary = {"set": str(want.get("set", held["entry"].get("set", ""))), "qty": 0,
				"at": int(held.get("at", now)), "missing": []}
			if not _text(want if not want.is_empty() else held["entry"], "src").is_empty():
				made["src"] = _text(want if not want.is_empty() else held["entry"], "src")
			entries[key] = made
		var mine: Dictionary = entries[key]
		mine["qty"] = int(mine.get("qty", 0)) + int(want.get("qty", 0)) - int(held["qty"])
		for field: String in ["fig", "spares"]:
			if want.get(field) == true:
				mine[field] = true
		if not _text(want, "name").is_empty():
			mine["name"] = _text(want, "name")
		# Its missing lots the same way: a set taken out takes its marks.
		var marks: Dictionary = {}
		for lot: Variant in mine.get("missing", []):
			if lot is Dictionary:
				marks[lot_key({"part": lot["part"], "colour": lot["colour"]})] = (lot as Dictionary).duplicate()
		var asked: Dictionary = {}
		for lot: Variant in want.get("missing", []):
			asked[lot_key({"part": lot["part"], "colour": lot["colour"]})] = lot
		var mark_keys: Array = asked.keys()
		for mark: String in held["missing"]:
			if not asked.has(mark) and int(held["missing"][mark]["qty"]) > 0:
				mark_keys.append(mark)
		for mark: String in mark_keys:
			var had: int = int((held["missing"] as Dictionary).get(mark, {}).get("qty", 0))
			var to: int = int((asked[mark] as Dictionary).get("qty", 0)) if asked.has(mark) else 0
			if to == had:
				continue
			if not marks.has(mark):
				var lot: Dictionary = asked[mark] if asked.has(mark) else held["missing"][mark]["lot"]
				marks[mark] = {"part": str(lot["part"]), "colour": int(lot["colour"]), "qty": 0}
			marks[mark]["qty"] = int(marks[mark]["qty"]) + to - had
		mine["missing"] = marks.values().filter(func(lot: Dictionary) -> bool: return int(lot["qty"]) != 0)


static func _moves(entry: Dictionary) -> bool:
	return int(entry.get("qty", 0)) != 0 or not (entry.get("missing", []) as Array).is_empty() \
		or entry.get("fig") == true or not _text(entry, "name").is_empty()


## [param text] as [param writer]'s file, whole or not at all: on the
## desktop written beside it and put in its place, so a crash halfway
## leaves the last one or the new one (read back either way, [method
## _read_file]); in a browser a write is whole as it is made.
static func _write_file(folder: String, writer: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join(writer + ".json")
	var writing: String = path + ".writing"
	var target: String = path if OS.has_feature("web") else writing
	TabSession.writing(target)
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return "could not write the collection on this device (%s)" % error_string(FileAccess.get_open_error())
	file.store_string(text)
	file.close()
	if target == path:
		return ""
	if DirAccess.rename_absolute(writing, path) != OK:
		# A system that will not rename over a file: the old one out first.
		# The new one is read back from beside it until it is in its place.
		DirAccess.remove_absolute(path)
		if DirAccess.rename_absolute(writing, path) != OK:
			return "could not put the collection on this device in its place"
	return ""


# --- the ops, as the account makes them ------------------------------------

## [param have] (a collection: {"sets", "parts"}) changed by one op or a
## typed import, checked as api/collection.js's applyOp checks it: {"next":
## the collection, or null for no change, "done": what was done}; or
## {"error": words, "status": 400 or 413, "conflict": true when what was
## seen is no longer so (409)}. Imports that need the account to read them
## into LDraw's numbers (a Rebrickable or BrickLink file, a Rebrickable
## account) are refused here with words. [param library], when given,
## checks colours as LDConfig has them.
static func apply(have: Dictionary, body: Dictionary, library: PartLibrary = null) -> Dictionary:
	var made: Variant = _apply(have, body, library)
	return made if made is Dictionary else {"error": str(made), "status": 400}


static func _apply(have: Dictionary, body: Dictionary, library: PartLibrary) -> Variant:
	var parts: Dictionary = _keyed(have.get("parts", []), true)
	var sets: Dictionary = _keyed(have.get("sets", []), false)
	var clamped: Array = []
	var op: String = str(body.get("op", "")) if body.get("op") != null else ""
	if op.is_empty() and body.has("from"):
		return _import(sets, parts, body)
	if op == "lots":
		var adding: Variant = _listed(body, "add", MOST_LOT_CHANGES)
		var removing: Variant = _listed(body, "remove", MOST_LOT_CHANGES)
		if adding is String or removing is String:
			return adding if adding is String else removing
		if (adding as Array).size() + (removing as Array).size() == 0:
			return "no lots to add or take off"
		if (adding as Array).size() + (removing as Array).size() > MOST_LOT_CHANGES:
			return {"error": "that is %d lots; one change is at most %d" % [(adding as Array).size()
				+ (removing as Array).size(), MOST_LOT_CHANGES], "status": 413}
		var adds: Array = []
		for n: int in (adding as Array).size():
			var id: Variant = _lot_id(adding[n], "add %d" % (n + 1), "may", library)
			if id is String:
				return id
			if not (id as Dictionary).has("by"):
				if not _text(id, "src").is_empty() and _text(id, "src") != HAND:
					return "add %d: a lot added here is the person's own (hand)" % (n + 1)
				id["src"] = HAND
			var qty: Variant = _counted((adding[n] as Dictionary).get("qty"), "add %d" % (n + 1))
			if qty is String:
				return qty
			adds.append([id, qty])
		var removes: Array = []
		for n: int in (removing as Array).size():
			var given: Dictionary = removing[n] if removing[n] is Dictionary else {}
			var id: Variant = _lot_id(removing[n], "remove %d" % (n + 1), "must", library)
			if id is String:
				return id
			var qty: Variant = 0 if given.get("qty") == null else _counted(given["qty"], "remove %d" % (n + 1), 0)
			var was: Variant = _counted(given.get("was"), "remove %d" % (n + 1), 1, "count seen")
			if qty is String or was is String:
				return qty if qty is String else was
			removes.append([id, qty, was])
		for n: int in removes.size():
			var id: Dictionary = removes[n][0]
			var held: Dictionary = parts.get(lot_key(id), {})
			if held.is_empty():
				return _conflict("remove %d: %s in colour %d is not a lot %s added%s (the person may have kept it or taken it back)"
					% [n + 1, id["part"], int(id["colour"]), id["by"], " in this chat" if id.has("chat") else ""])
			if int(held["qty"]) != int(removes[n][2]):
				return _conflict("remove %d: %s is %d now, not the %d seen" % [n + 1, _said(id), int(held["qty"]),
					int(removes[n][2])])
		for one: Array in removes:
			var held: Dictionary = parts.get(lot_key(one[0]), {})
			if held.is_empty():
				continue
			if int(one[1]) == 0 or int(one[1]) >= int(held["qty"]):
				parts.erase(lot_key(one[0]))
			else:
				held["qty"] = int(held["qty"]) - int(one[1])
		for one: Array in adds:
			_add_lot(parts, one[0], int(one[1]), clamped)
		return {"next": _next(sets, parts), "done": _with_clamped({"added": adds.size(), "taken_down": removes.size()},
			clamped)}
	if op == "set":
		var changes: Variant = _listed(body, "lots", MOST_LOT_CHANGES)
		if changes is String:
			return changes
		if (changes as Array).is_empty():
			return "no lots to set"
		var ids: Array = []
		var counts: Array = []
		for n: int in (changes as Array).size():
			var id: Variant = _lot_id(changes[n], "lot %d" % (n + 1), "may", library)
			if id is String:
				return id
			ids.append(id)
		var twice: String = _once(ids, "lot")
		if not twice.is_empty():
			return twice
		for n: int in (changes as Array).size():
			var given: Dictionary = changes[n]
			var was: Variant = _counted(given.get("was"), "lot %d" % (n + 1), 1, "count seen")
			var qty: Variant = _counted(given.get("qty"), "lot %d" % (n + 1), 0)
			if was is String or qty is String:
				return was if was is String else qty
			counts.append([was, qty])
		for n: int in ids.size():
			var held: Dictionary = parts.get(lot_key(ids[n]), {})
			if held.is_empty():
				return _conflict("lot %d: %s is not there any more" % [n + 1, _said(ids[n])])
			if int(held["qty"]) != int(counts[n][0]):
				return _conflict("lot %d: %s is %d now, not the %d shown" % [n + 1, _said(ids[n]), int(held["qty"]),
					int(counts[n][0])])
		for n: int in ids.size():
			if int(counts[n][1]) == 0:
				parts.erase(lot_key(ids[n]))
			else:
				parts[lot_key(ids[n])]["qty"] = int(counts[n][1])
		return {"next": _next(sets, parts), "done": {"set": ids.size()}}
	if op == "keep" or op == "take_back":
		var named: Variant = _listed(body, "lots", MAX_LOTS)
		if named is String:
			return named
		if (named as Array).is_empty():
			return "no lots named"
		var ids: Array = []
		var was: Array = []
		for n: int in (named as Array).size():
			var id: Variant = _lot_id(named[n], "lot %d" % (n + 1), "must", library)
			if id is String:
				return id
			ids.append(id)
		var twice: String = _once(ids, "lot")
		if not twice.is_empty():
			return twice
		for n: int in (named as Array).size():
			var seen: Variant = _counted((named[n] as Dictionary).get("was"), "lot %d" % (n + 1), 1, "count seen")
			if seen is String:
				return seen
			was.append(seen)
		for n: int in ids.size():
			var held: Dictionary = parts.get(lot_key(ids[n]), {})
			if held.is_empty():
				return _conflict("lot %d: %s is not there any more" % [n + 1, _said(ids[n])])
			if int(held["qty"]) != int(was[n]):
				return _conflict("lot %d: %s is %d now, not the %d shown" % [n + 1, _said(ids[n]), int(held["qty"]),
					int(was[n])])
		for n: int in ids.size():
			parts.erase(lot_key(ids[n]))
			if op == "keep":
				_add_lot(parts, {"part": ids[n]["part"], "colour": ids[n]["colour"], "src": HAND}, int(was[n]), clamped)
		return {"next": _next(sets, parts), "done": _with_clamped({"kept" if op == "keep" else "taken_back": ids.size()},
			clamped)}
	if op == "remove_set":
		var fig: String = fig_number(body.get("set"))
		var number: String = fig if body.get("fig") == true else set_number(body.get("set"))
		if number.is_empty():
			return "\"%s\" is not a set number" % str(body.get("set", ""))
		var src: String = _text(body, "src")
		if not src.is_empty() and not src in SOURCES:
			return "\"%s\" is not where a set comes from" % src
		var was: Variant = _counted(body.get("was"), number, 1, "count seen")
		if was is String:
			return was
		var id: Dictionary = {"set": number, "src": src}
		if not sets.has(set_key(id)) and not fig.is_empty() and body.get("fig") != true:
			var as_fig: Dictionary = {"set": fig, "src": src}
			if (sets.get(set_key(as_fig), {}) as Dictionary).get("fig") == true:
				id = as_fig
		var held: Dictionary = sets.get(set_key(id), {})
		if held.is_empty():
			return {"next": null, "done": {"removed_sets": 0}}
		if int(held["qty"]) != int(was):
			return _conflict("%s is %d now, not the %d shown" % [number, int(held["qty"]), int(was)])
		sets.erase(set_key(id))
		return {"next": _next(sets, parts), "done": {"removed_sets": 1}}
	if op == "missing":
		var number: String = set_number(body.get("set"))
		if number.is_empty():
			return "\"%s\" is not a set number" % str(body.get("set", ""))
		var src: String = _text(body, "src")
		if not src.is_empty() and not src in SOURCES:
			return "\"%s\" is not where a set comes from" % src
		var changes: Variant = _listed(body, "lots", MOST_LOT_CHANGES)
		if changes is String:
			return changes
		if (changes as Array).is_empty():
			return "no lots to mark"
		var ids: Array = []
		var counts: Array = []
		for n: int in (changes as Array).size():
			var given: Dictionary = changes[n] if changes[n] is Dictionary else {}
			var part: String = part_number(given.get("part"))
			if part.is_empty():
				return "lot %d: \"%s\" is not a part number" % [n + 1, str(given.get("part", ""))]
			var colour: Variant = colour_of(given.get("colour"), "lot %d" % (n + 1), library)
			if colour is String:
				return colour
			ids.append({"part": part, "colour": colour})
		var twice: String = _once(ids, "lot")
		if not twice.is_empty():
			return twice
		for n: int in (changes as Array).size():
			var given: Dictionary = changes[n]
			var was: Variant = _counted(given.get("was"), "lot %d" % (n + 1), 0, "count seen")
			var qty: Variant = _counted(given.get("qty"), "lot %d" % (n + 1), 0)
			if was is String or qty is String:
				return was if was is String else qty
			counts.append([was, qty])
		var held: Dictionary = sets.get(set_key({"set": number, "src": src}), {})
		if held.is_empty() or held.get("fig") == true:
			return _conflict("%s is not in your collection any more" % number)
		var missing: Dictionary = _keyed(held.get("missing", []), true)
		for n: int in ids.size():
			var now: int = int((missing.get(lot_key(ids[n]), {}) as Dictionary).get("qty", 0))
			if now != int(counts[n][0]):
				return _conflict("lot %d: %s in colour %d is %d missing now, not the %d shown" % [n + 1, ids[n]["part"],
					int(ids[n]["colour"]), now, int(counts[n][0])])
		for n: int in ids.size():
			var key: String = lot_key(ids[n])
			if int(counts[n][1]) == 0:
				missing.erase(key)
			elif missing.has(key):
				missing[key]["qty"] = int(counts[n][1])
			else:
				missing[key] = {"part": ids[n]["part"], "colour": ids[n]["colour"], "qty": int(counts[n][1])}
		if missing.size() > MOST_MISSING:
			return {"error": "that marks %d lots missing; a set is at most %d" % [missing.size(), MOST_MISSING],
				"status": 413}
		if missing.is_empty():
			held.erase("missing")
		else:
			held["missing"] = missing.values()
		var pieces: int = 0
		for lot: Dictionary in missing.values():
			pieces += int(lot["qty"])
		return {"next": _next(sets, parts), "done": {"marked": ids.size(), "missing": pieces}}
	if op == "start_over":
		var seen: Variant = null if body.get("rev") == null else int(body["rev"])
		var now: Variant = null if have.get("rev") == null else int(have["rev"])
		if seen != now:
			return _conflict("your collection changed since it was shown; here it is now")
		if sets.is_empty() and parts.is_empty():
			return {"next": null, "done": {}}
		return {"next": {"sets": [], "parts": []}, "done": {"started_over": true}}
	return ("say what this is: op lots, set, keep, take_back, remove_set, missing or start_over, "
		+ "or from sets or figs")


## A typed import: sets by number, or minifigures found by a photo, each the
## person's own ("hand"), added to any already kept as the account adds them.
static func _import(sets: Dictionary, parts: Dictionary, body: Dictionary) -> Variant:
	var from: String = str(body.get("from", ""))
	var adding: Array = []
	if from == "sets":
		var words: PackedStringArray = PackedStringArray()
		for word: String in RegEx.create_from_string("[\\s,;]+").sub(str(body.get("text", "") if body.get("text") != null
				else ""), " ", true).split(" ", false):
			words.append(word)
		if words.is_empty():
			return "no set number given"
		for word: String in words:
			var number: String = set_number(word)
			if number.is_empty():
				return "\"%s\" is not a set number" % word
			adding.append({"set": number, "qty": 1, "spares": false})
	elif from == "figs":
		var listed: Variant = body.get("figs")
		if not listed is Array or (listed as Array).is_empty():
			return "no minifigure given"
		if (listed as Array).size() > 100:
			return {"error": "that is %d minifigures; one change is at most 100" % (listed as Array).size(), "status": 413}
		for n: int in (listed as Array).size():
			var one: Dictionary = listed[n] if listed[n] is Dictionary else {}
			var fig: String = fig_number(one.get("fig"))
			if fig.is_empty():
				return "minifigure %d: \"%s\" is not a BrickLink minifigure number" % [n + 1, str(one.get("fig", ""))]
			var entry: Dictionary = {"set": fig, "qty": 1, "spares": false, "fig": true}
			var name: String = Collection.who_name(str(one.get("name", "")) if one.get("name") != null else "").left(120)
			if not name.is_empty():
				entry["name"] = name
			adding.append(entry)
	elif from in ["rebrickable_csv", "bricklink_xml", "rebrickable_api"]:
		return {"error": "sign in to bring in a file or your Rebrickable account: your account reads it into LDraw's "
			+ "numbers. Sets typed by number and loose parts are kept on this device until you do", "status": 401}
	else:
		return "say what this is: from sets or figs, or an op"
	for entry: Dictionary in adding:
		var kept: Dictionary = entry.duplicate()
		kept["src"] = HAND
		var held: Dictionary = sets.get(set_key(kept), {})
		if held.is_empty():
			sets[set_key(kept)] = kept
		else:
			held["qty"] = mini(MAX_QTY, int(held["qty"]) + int(kept["qty"]))
	return {"next": _next(sets, parts), "done": {"imported": {"sets": adding.size(), "lots": 0}, "left_out": []}}


static func _keyed(list: Variant, lots: bool) -> Dictionary:
	var out: Dictionary = {}
	for one: Variant in list if list is Array else []:
		if one is Dictionary:
			var key: String = lot_key(one) if lots else set_key(one)
			if out.has(key):
				out[key]["qty"] = mini(MAX_QTY, int(out[key]["qty"]) + int((one as Dictionary).get("qty", 0)))
			else:
				out[key] = (one as Dictionary).duplicate(true)
	return out


static func _next(sets: Dictionary, parts: Dictionary) -> Dictionary:
	return {"sets": sets.values(), "parts": parts.values()}


static func _add_lot(parts: Dictionary, id: Dictionary, qty: int, clamped: Array) -> void:
	var key: String = lot_key(id)
	if not parts.has(key):
		var lot: Dictionary = id.duplicate()
		lot["qty"] = mini(MAX_QTY, qty)
		parts[key] = lot
		return
	var sum: int = int(parts[key]["qty"]) + qty
	if sum > MAX_QTY:
		clamped.append({"part": parts[key]["part"], "colour": parts[key]["colour"], "over": sum - MAX_QTY})
	parts[key]["qty"] = mini(MAX_QTY, sum)


static func _with_clamped(done: Dictionary, clamped: Array) -> Dictionary:
	if clamped.is_empty():
		return done
	var out: Dictionary = done.duplicate()
	out["clamped"] = clamped.slice(0, 50)
	out["clamped_lots"] = clamped.size()
	return out


static func _conflict(words: String) -> Dictionary:
	return {"error": words, "status": 409, "conflict": true}


static func _said(lot: Dictionary) -> String:
	return "%s in colour %d%s" % [lot["part"], int(lot["colour"]), " that %s added" % lot["by"] if lot.has("by") else ""]


static func _listed(body: Dictionary, field: String, most: int) -> Variant:
	var list: Variant = body.get(field, [])
	if list == null:
		list = []
	if not list is Array:
		return "%s is a list of lots" % field
	if (list as Array).size() > most:
		return {"error": "that is %d lots; one change is at most %d" % [(list as Array).size(), most], "status": 413}
	return list


static func _once(ids: Array, where: String) -> String:
	var seen: Dictionary = {}
	for n: int in ids.size():
		var key: String = lot_key(ids[n])
		if seen.has(key):
			return "%s %d: %s is named twice" % [where, n + 1, _said(ids[n])]
		seen[key] = true
	return ""


## A lot as an op names it, checked as api/collection.js's lotId checks
## it: {"part", "colour", and "src", or "by" and "chat"}, or why not.
## [param session] "must" refuses the person's own.
static func _lot_id(given: Variant, where: String, session: String, library: PartLibrary) -> Variant:
	if not given is Dictionary:
		return "%s: a lot is {part, colour, qty}" % where
	var p: Dictionary = given
	var part: String = part_number(p.get("part"))
	if part.is_empty():
		return "%s: \"%s\" is not a part number" % [where, str(p.get("part", ""))]
	var colour: Variant = colour_of(p.get("colour"), where, library)
	if colour is String:
		return colour
	var lot: Dictionary = {"part": part, "colour": colour}
	if p.get("by") != null and not p.get("by") is String:
		return "%s: who added it is a name" % where
	var by: String = Collection.who_name(str(p.get("by", "")) if p.get("by") != null else "")
	if by.is_empty() and not _text(p, "by").is_empty():
		return "%s: %s is not a name" % [where, JSON.stringify(p["by"])]
	var chat: String = _text(p, "chat").strip_edges()
	var src: String = _text(p, "src")
	if not by.is_empty():
		if not src.is_empty():
			return "%s: a lot a session added comes from that session, not from %s" % [where, src]
		lot["by"] = by
		if not chat.is_empty():
			if _chat_shape.search(chat) == null:
				return "%s: \"%s\" is not a chat" % [where, chat]
			lot["chat"] = chat
		return lot
	if not chat.is_empty():
		return "%s: a chat is said only with who added the lot" % where
	if session == "must":
		return "%s: only a lot a session added is taken down, kept or taken back this way" % where
	if not src.is_empty():
		if not src in SOURCES:
			return "%s: \"%s\" is not where a lot comes from" % [where, src]
		lot["src"] = src
	return lot


## A whole number from [param least] to MAX_QTY, given as a number or its
## digits; or why not.
static func _counted(raw: Variant, where: String, least: int = 1, what: String = "count") -> Variant:
	var text: String = ""
	if raw is int:
		text = str(raw)
	elif raw is float and float(raw) == floorf(float(raw)) and float(raw) >= 0.0:
		text = str(int(raw))
	elif raw is String:
		text = (raw as String).strip_edges()
	if _digits.search(text) == null:
		return "%s: the %s %s is not a whole number" % [where, what, JSON.stringify(raw)]
	var n: int = int(text)
	if n < least or n > MAX_QTY:
		return "%s: a %s of %d is outside %d to %d" % [where, what, n, least, MAX_QTY]
	return n


## "10237" is "10237-1"; "" when it is no set number.
static func set_number(raw: Variant) -> String:
	var text: String = (str(raw) if raw != null else "").strip_edges().to_lower()
	if not text.is_empty() and _versioned.search(text) == null:
		text += "-1"
	return text if _set_shape.search(text) != null else ""


static func part_number(raw: Variant) -> String:
	var text: String = (str(raw) if raw != null else "").strip_edges().to_lower().trim_suffix(".dat")
	return text if _part_shape.search(text) != null else ""


static func fig_number(raw: Variant) -> String:
	var text: String = (str(raw) if raw != null else "").strip_edges().to_lower()
	return text if _fig_shape.search(text) != null and _versioned.search(text) == null else ""


## An LDraw colour code: a whole number LDConfig has (where [param library]
## is given), never 16 or 24; or why not.
static func colour_of(raw: Variant, where: String, library: PartLibrary = null) -> Variant:
	var text: String = ""
	if raw is int:
		text = str(raw)
	elif raw is float and float(raw) == floorf(float(raw)):
		text = str(int(raw))
	elif raw is String:
		text = (raw as String).strip_edges()
	var code: int = int(text) if _digits.search(text) != null else -1
	if code < 0 or code == 16 or code == 24 or (library != null and not library.colors.has(code)):
		return "%s: the colour %s is not an LDraw colour code" % [where, JSON.stringify(raw)]
	return code
