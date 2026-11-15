## The parts a model's file names by a number LDraw has moved ("3023",
## "~Moved to 3023b") or keeps as an alias of another ("=Slope Brick 45 2 x 2
## Double Concave", 4723 for 3046), and those the library has no file for:
## listed as the model opens (ModelStore.moved), shown to the person
## (MovedPartsDialog) and told to a session (open_model), and each moved or
## alias number written in the file as the part it points to (rewritten).
##
## Brickworks draws a moved part as the part it moved to, where its stub puts
## it (ModelStore._as_placed), and an alias as itself, drawn the same. The
## file kept the old number and nobody was told; a part with no file at all
## was drawn as missing and named in the status bar. StudWorx lists all three
## on open and replaces the checked ones in every sub-model in one undo
## (APP_UX8 #15).
##
## The replace writes the file's own lines: each placing line, in the model
## and in every sub-model, that names a listed number names the part it
## points to, and every other character of it is as it was. A stub that
## turns or shifts its part (3139, a tyre, forwards to 3139b a quarter turn
## round) has that turn put into the line's own numbers, so the part stands
## where it was drawn; a chain of moves is followed to its end
## (PartLibrary.moved_by).
class_name MovedParts
extends RefCounted

## Why a number is listed.
const MOVED := "moved"
const ALIAS := "alias"
const MISSING := "missing"


## What [param library] puts in the place of [param part_id], a number as a
## file names it: {"kind", "to", "by"}, the part it points to and where in
## the line's own frame (identity for an alias, which draws its part where
## it stands); {} for a part that is itself.
static func target_of(part_id: String, library: PartLibrary, twins: Dictionary = {}) -> Dictionary:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info == null:
		return {"kind": MISSING, "to": "", "by": Transform3D.IDENTITY}
	if info.is_redirect():
		var real: String = library.resolve(part_id)
		# A stub whose part is not in the library is drawn as the stub.
		if real == part_id:
			return {}
		return {"kind": MOVED, "to": real, "by": library.moved_by(part_id)}
	if is_alias(info):
		var twin: String = alias_of(info, library, twins)
		if twin.is_empty():
			return {}
		return {"kind": ALIAS, "to": twin, "by": Transform3D.IDENTITY}
	return {}


## Whether LDraw files [param info] as an alias of another part: a file of
## that part's geometry under another number, "Part Alias" in its header.
static func is_alias(info: PartLibrary.PartInfo) -> bool:
	return info.kind.contains("Alias") and not info.custom


## The part [param info], an alias, is of: the one part of the library of the
## same geometry that is no alias, no moved number and no part a file
## carried, so drawn where the alias stands. Of several, the one
## PartLibrary.current names, else the one most sets use. "" where none is
## the same: an alias that turns or mirrors its part (6059341d) is left as
## it is. [param twins], mesh -> ids, is made here once for many.
static func alias_of(info: PartLibrary.PartInfo, library: PartLibrary,
		twins: Dictionary = {}) -> String:
	if twins.is_empty():
		_twins_into(twins, library)
	var same: Array = twins.get(info.mesh_hash, [])
	if same.is_empty():
		return ""
	var named: String = library.current(info.id)
	if same.has(named):
		return named
	var best: String = ""
	var most: int = -1
	for id: String in same:
		var other: PartLibrary.PartInfo = library.parts[id]
		if other.in_sets > most or (other.in_sets == most and id < best):
			best = id
			most = other.in_sets
	return best


## Each geometry's parts that are no alias, moved number or carried part, by
## its mesh: the parts an alias may be of.
static func _twins_into(twins: Dictionary, library: PartLibrary) -> void:
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.mesh_hash.is_empty() or info.is_redirect() or info.custom or is_alias(info):
			continue
		if not twins.has(info.mesh_hash):
			twins[info.mesh_hash] = []
		(twins[info.mesh_hash] as Array).append(id)
	# Marked as made, where no part is.
	twins[""] = []


## The number each of [param flattened]'s placements has in its file, read
## before an open makes them what it puts down (ModelStore._as_placed).
static func said_of(flattened: Array) -> PackedStringArray:
	var out := PackedStringArray()
	out.resize(flattened.size())
	for n: int in flattened.size():
		out[n] = (flattened[n] as LdrModel.Placement).part_id
	return out


## The numbers of a file listed as it opens: each [param said] (the file's
## number of [param flattened]'s placement of the same index) that is moved,
## an alias or not in the library ([param missing], the open's, by the name
## each is laid under), number -> {"kind", "to", "name" (the part it points
## to's), "by" (Transform3D), "count" (parts placed), "in" (sub-model ->
## parts, "" the model's own)}. A number the file carries itself is its own.
## Studio's names are LDraw's, as an open reads them.
static func listing(flattened: Array, said: PackedStringArray, missing: Dictionary,
		library: PartLibrary) -> Dictionary:
	var out: Dictionary = {}
	var seen: Dictionary = {}
	var twins: Dictionary = {}
	for n: int in flattened.size():
		var placement: LdrModel.Placement = flattened[n]
		var number: String = said[n]
		if not seen.has(number):
			var target: Dictionary = {}
			if missing.has(placement.part_id):
				target = {"kind": MISSING, "to": "", "by": Transform3D.IDENTITY}
			elif library.parts.has(placement.part_id):
				var named: String = ModelStore.studio_part(number, library)
				target = target_of(named, library, twins) if library.parts.has(named) else {}
				if not target.is_empty() and str(target["kind"]) == MISSING:
					target = {}
			if not target.is_empty():
				var to: PartLibrary.PartInfo = library.parts.get(str(target["to"]))
				# Its name without the padding LDraw aligns its names by ("Plate  1 x  2").
				target["name"] = Inventory._tidy(to.name) if to != null else ""
				target["count"] = 0
				target["in"] = {}
			seen[number] = target
		var row: Dictionary = seen[number]
		if row.is_empty():
			continue
		row["count"] = int(row["count"]) + 1
		var where: String = section_of(placement.unit)
		var places: Dictionary = row["in"]
		places[where] = int(places.get(where, 0)) + 1
		out[number] = row
	return out


## Why a row of [method listing] is listed and what it points to: "moved to
## 3023b, Plate 1 x 2 with Groove", "an alias of 3046, …", "no file: the
## library has no part of this number".
static func why_words(row: Dictionary) -> String:
	match str(row["kind"]):
		MOVED:
			return "moved to %s, %s" % [row["to"], row["name"]]
		ALIAS:
			return "an alias of %s, %s" % [row["to"], row["name"]]
	return "no file: the library has no part of this number"


## How many a row's number places, and where: "46 used: 12 in the model; 34
## in wing".
static func used_words(row: Dictionary) -> String:
	var places: Dictionary = row["in"]
	var where := PackedStringArray()
	var sections: Array = places.keys()
	sections.sort()
	for section: String in sections:
		where.append(("%d in the model" % int(places[section])) if section.is_empty()
			else ("%d in %s" % [int(places[section]), section]))
	return "%d used: %s" % [int(row["count"]), "; ".join(where)]


## The sub-model a part placed in copy [param unit] ("House#1/Window#3") is
## a line of: "Window"; "" for the model's own.
static func section_of(unit: String) -> String:
	if unit.is_empty():
		return ""
	var last: String = unit.get_slice("/", unit.get_slice_count("/") - 1)
	return last.get_slice("#", 0)


## [param text], a model's file, with each placing line of the model and of
## every sub-model that names one of [param numbers] (number -> {"to", "by"},
## as [method listing] gives them) naming the part it points to instead:
## {"text", "lines" (how many changed), "parts" (number -> lines)}. Only the
## name's field changes, and for a stub that turns or shifts its part, the
## numbers that say its place or its turn; every other character as it was,
## the line's end too. A line in a part the file carries is the part's, not
## the model's, and is left.
static func rewritten(text: String, numbers: Dictionary) -> Dictionary:
	var bom: bool = text.begins_with(LdrModel.bom())
	var body: String = text.substr(1) if bom else text
	var model: LdrModel = LdrModel.parse(body, "model")
	var lines: PackedStringArray = body.split("\n")
	var changed: Dictionary = {}
	var parts: Dictionary = {}
	if model != null:
		for sub: LdrModel.SubModel in model.submodels.values():
			# A shortcut or primitive the file carries is the library's file.
			if sub.library_file:
				continue
			for placement: LdrModel.Placement in sub.placements:
				var row: Dictionary = numbers.get(placement.part_id, {})
				if row.is_empty() or placement.line < 0 or placement.line >= lines.size() \
						or changed.has(placement.line):
					continue
				var line: String = lines[placement.line]
				var made: String = line_with(line, str(row["to"]), row.get("by", Transform3D.IDENTITY))
				if made == line:
					continue
				lines[placement.line] = made
				changed[placement.line] = true
				parts[placement.part_id] = int(parts.get(placement.part_id, 0)) + 1
	return {"text": (LdrModel.bom() if bom else "") + "\n".join(lines), "lines": changed.size(),
		"parts": parts}


## Placing [param line] naming [param to] in place of its part, placed at
## [param by] in the old part's frame: its name's field written in the case
## the file wrote the old one, with its folder and its ".dat" as written;
## and where [param by] is not the identity, each of the twelve numbers
## that it changes written anew (SourceFile._number_said), the others as
## they were. Its gaps, tabs and line end are kept.
static func line_with(line: String, to: String, by: Transform3D = Transform3D.IDENTITY) -> String:
	var spans: Array[Vector2i] = _field_spans(line)
	if spans.size() < 15:
		return line
	var name_at: int = spans[14].x
	var name_end: int = line.rstrip(LdrModel.SPACE).length()
	var name: String = line.substr(name_at, name_end - name_at)
	var folder: int = maxi(name.rfind("/"), name.rfind("\\")) + 1
	var file: String = name.substr(folder)
	var extension: String = ""
	for suffix: String in [".dat", ".ldr"]:
		if file.to_lower().ends_with(suffix):
			extension = file.right(4)
			file = file.left(file.length() - 4)
	var upper: bool = file == file.to_upper() and file != file.to_lower()
	var named: String = name.left(folder) + (to.to_upper() if upper else to) + extension
	var out: String = line.left(name_at) + named + line.substr(name_end)
	if by.is_equal_approx(Transform3D.IDENTITY):
		return out
	var was := PackedFloat64Array()
	for n: int in range(2, 14):
		var token: String = line.substr(spans[n].x, spans[n].y - spans[n].x)
		if not token.is_valid_float():
			return line
		was.append(token.to_float())
	var now: PackedFloat64Array = composed(was, by)
	# The numbers from the last back, so each span is where it was.
	for n: int in range(11, -1, -1):
		if absf(now[n] - was[n]) <= 1e-9:
			continue
		var span: Vector2i = spans[n + 2]
		out = out.left(span.x) + SourceFile._number_said(now[n], n < 3) + out.substr(span.y)
	return out


## A placing line's twelve numbers [param was] (x y z a b c d e f g h i, as
## LDraw writes them) placing in turn [param by] in its own frame: what the
## line says once the stub's own line is put into it. In LDraw's numbers, in
## double precision, so a number the turn does not change is the same to the
## last digit; [param by]'s own read to a millionth, as the catalogue gave
## them.
static func composed(was: PackedFloat64Array, by: Transform3D) -> PackedFloat64Array:
	var stub: PackedFloat64Array = LdrModel.from_transform(by)
	for n: int in 12:
		stub[n] = snappedf(stub[n], 0.000001)
	var out := PackedFloat64Array()
	out.resize(12)
	# The place: M * p' + p.
	for row: int in 3:
		var sum: float = was[row]
		for k: int in 3:
			sum += was[3 + row * 3 + k] * stub[k]
		out[row] = sum
	# The turn: M * M'.
	for row: int in 3:
		for col: int in 3:
			var sum: float = 0.0
			for k: int in 3:
				sum += was[3 + row * 3 + k] * stub[3 + k * 3 + col]
			out[3 + row * 3 + col] = sum
	return out


## Where each field of [param line] begins and ends, as LdrModel reads its
## fields: split on any run of spaces and tabs.
static func _field_spans(line: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at: int = 0
	var size: int = line.length()
	while at < size and out.size() < 15:
		while at < size and LdrModel._is_space(line.unicode_at(at)):
			at += 1
		if at >= size:
			break
		var start: int = at
		while at < size and not LdrModel._is_space(line.unicode_at(at)):
			at += 1
		out.append(Vector2i(start, at))
	return out
