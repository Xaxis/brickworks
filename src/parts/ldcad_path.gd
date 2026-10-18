## LDCad's path for a hose written again where the hose now lies (G10).
##
## LDCad keeps the path a flexible part follows in meta lines (`0 !LDCAD
## PATH_POINT`, `PATH_CAP`) above what it generated along it (`0 !LDCAD
## GENERATED` and the parts after it): 42080-1's pneumatic tubes are a path
## of seven points and 166 pieces of tube (CustomParts, docs/CADTASK.md). A
## grab that bends such a tube lays its pieces again (FlexFollow), and the
## file is written with them; its path lines, left as they were, would have
## LDCad lay it back where it was the next time anything there changed. So
## a sub-model of a file that was such a path, whose ends no longer stand
## where its caps were, is given its path again, along its pieces as they
## lie: a point every [constant SPACING] LDU or so, each pointing along the
## hose (LDCad's point runs along its own -y, in LDraw's axes), its control
## points a third of the way to its neighbours, which is the curve through
## them; its caps where its end pieces stand. A path untouched is left as
## it was, byte for byte; and a model written whole (a copy of a sub-model
## made its own) keeps the path lines it would otherwise have lost.
class_name LdcadPath
extends RefCounted

## About how far apart the points written along a path are, LDU.
const SPACING := 20.0
## A cap within this of where the file had it has not moved, LDU.
const STILL := 0.05


## [param text], a model file written over [param source] or written whole,
## with each of the source's LDCad paths of parts given where its parts now
## lie. [param library] says what each part number is.
static func written_into(text: String, source: SourceFile, library: PartLibrary) -> String:
	if source == null or source.flexible.is_empty() or library == null:
		return text
	var paths: Dictionary = _paths_of(source)
	if paths.is_empty():
		return text
	var lines: PackedStringArray = text.split("\n")
	var out := PackedStringArray()
	var section := PackedStringArray()
	var changed: bool = false
	for n: int in lines.size() + 1:
		var line: String = lines[n] if n < lines.size() else ""
		var starts: bool = n == lines.size() or line.strip_edges().begins_with("0 FILE ")
		if starts and not section.is_empty():
			var key: String = _match(section[0], paths)
			if not key.is_empty():
				var again: PackedStringArray = _section_again(section, paths[key], library)
				changed = changed or again != section
				section = again
			out.append_array(section)
			section = PackedStringArray()
		if n < lines.size():
			section.append(line)
	return "\n".join(out) if changed else text


## Each of the source's sections that is an LDCad path of parts: key ->
## {"meta": its !LDCAD lines but the generated one, "generated": that line,
## "start", "end": where its caps were (app axes, the section's frame)}.
static func _paths_of(source: SourceFile) -> Dictionary:
	var out: Dictionary = {}
	for key: String in source.flexible:
		if not source.sections.has(key):
			continue
		var span: Array = source.sections[key]
		var meta := PackedStringArray()
		var generated: String = ""
		var caps: Dictionary = {}
		var points: int = 0
		for n: int in range(int(span[0]), int(span[1])):
			var line: String = source.lines[n].strip_edges()
			if line.begins_with("0 !LDCAD GENERATED"):
				generated = line
			elif line.begins_with("0 !LDCAD "):
				meta.append(line)
				if line.begins_with("0 !LDCAD PATH_POINT"):
					points += 1
				elif line.begins_with("0 !LDCAD PATH_CAP"):
					var at: Variant = _pos_ori(line)
					if at != null:
						caps["end" if line.contains("[group=end]") else "start"] = (at as Transform3D).origin
		if points >= 2 and not generated.is_empty() and caps.size() == 2:
			out[key] = {"meta": meta, "generated": generated, "start": caps["start"], "end": caps["end"]}
	return out


## The source's path a written section is, by its FILE line: the same name
## (written back over the file), or the name it was written whole under
## ("pneumatic_hose_lq_12.ldr" for "42080 - pneumaticHoseLQ-12.ldr"), when
## one and only one source path ends so. "" for none.
static func _match(file_line: String, paths: Dictionary) -> String:
	var name: String = LdrModel._key(file_line.strip_edges().substr(7).strip_edges())
	if paths.has(name):
		return name
	var plain: String = _letters(name)
	if plain.is_empty():
		return ""
	var found: String = ""
	for key: String in paths:
		if _letters(key).ends_with(plain):
			if not found.is_empty():
				return ""
			found = key
	return found


static func _letters(name: String) -> String:
	var out: String = ""
	for character: String in name.to_lower():
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			out += character
	return out


## A section of the written file, its path written where its pieces lie.
static func _section_again(section: PackedStringArray, path: Dictionary,
		library: PartLibrary) -> PackedStringArray:
	var pieces: Array = []
	var kind: String = ""
	for line: String in section:
		var words: PackedStringArray = LdrModel._fields(line.strip_edges())
		if words.size() < 15 or words[0] != "1":
			continue
		var numbers := PackedFloat64Array()
		for k: int in range(2, 14):
			numbers.append(float(words[k]))
		var part: String = library.resolve(LdrModel._key(" ".join(words.slice(14))))
		var its: String = Flex.strung(library, part)
		if kind.is_empty():
			kind = its
		if its != kind:
			return section
		pieces.append({"part": part, "at": LdrModel.to_transform(numbers)})
	if not Flex.KINDS.has(kind) or str(Flex.KINDS[kind]["family"]) != "scaled" and kind != "ribbed_hose":
		return section
	var ends: Array = Flex.ends_of_item(kind, pieces)
	if ends.size() != 2:
		return section
	var start: Vector3 = path["start"]
	var end: Vector3 = path["end"]
	var tip0: Vector3 = (ends[0] as Flex.Port).tip
	var tip1: Vector3 = (ends[1] as Flex.Port).tip
	if tip1.distance_to(start) + tip0.distance_to(end) < tip0.distance_to(start) + tip1.distance_to(end):
		ends.reverse()
		tip0 = (ends[0] as Flex.Port).tip
		tip1 = (ends[1] as Flex.Port).tip
	var still: bool = tip0.distance_to(start) < STILL and tip1.distance_to(end) < STILL
	var has_points: bool = false
	for line: String in section:
		if line.strip_edges().begins_with("0 !LDCAD PATH_POINT"):
			has_points = true
	if still and has_points:
		return section
	var meta: PackedStringArray = path["meta"] if still \
		else _meta_again(path["meta"], kind, pieces, ends)
	var eol: String = "\r" if section[0].ends_with("\r") else ""
	var out := PackedStringArray()
	if has_points:
		# Written back over the file: its path lines replaced where they are.
		var put: bool = false
		for line: String in section:
			var said: String = line.strip_edges()
			if said.begins_with("0 !LDCAD PATH_POINT"):
				if not put:
					for one: String in meta:
						if one.begins_with("0 !LDCAD PATH_POINT"):
							out.append(one + eol)
					put = true
				continue
			if said.begins_with("0 !LDCAD PATH_CAP"):
				var group: String = "[group=end]" if said.contains("[group=end]") else "[group=start]"
				for one: String in meta:
					if one.begins_with("0 !LDCAD PATH_CAP") and one.contains(group):
						said = one
				out.append(said + eol)
				continue
			out.append(line)
		return out
	# Written whole: the path lines and the generated line before its first
	# part, where LDCad has them.
	var placed: bool = false
	for line: String in section:
		if not placed and line.strip_edges().begins_with("1 "):
			for one: String in meta:
				out.append(one + eol)
			out.append(str(path["generated"]) + eol)
			placed = true
		out.append(line)
	return out


## The path's lines with its points along [param pieces] as they lie and
## its caps on their end pieces; its other lines as they were.
static func _meta_again(meta: PackedStringArray, kind: String, pieces: Array, ends: Array) -> PackedStringArray:
	var a: Flex.Port = ends[0]
	var b: Flex.Port = ends[1]
	var line := Flex.Path.new()
	line.points.append(a.tip)
	for point: Vector3 in Flex.centreline(kind, pieces, a.tip):
		if point.distance_to(line.points[line.points.size() - 1]) > 0.01:
			line.points.append(point)
	if b.tip.distance_to(line.points[line.points.size() - 1]) > 0.01:
		line.points.append(b.tip)
	line.measure()
	var total: float = line.total()
	var count: int = clampi(ceili(total / SPACING), 1, 60)
	var at := PackedFloat64Array()
	for n: int in count + 1:
		at.append(total * float(n) / float(count))
	var template: String = ""
	var out := PackedStringArray()
	var caps: Array = []
	for one: String in meta:
		if one.begins_with("0 !LDCAD PATH_POINT"):
			if template.is_empty():
				template = one
				out.append("")   # where the points go
			continue
		if one.begins_with("0 !LDCAD PATH_CAP"):
			caps.append(one)
			continue
		out.append(one)
	var points := PackedStringArray()
	var across := Vector3.ZERO
	for n: int in at.size():
		var s: float = at[n]
		var way: Vector3
		if n == 0:
			way = a.out
		elif n == at.size() - 1:
			way = -b.out
		else:
			way = (line.at(minf(s + 1.0, total)) - line.at(maxf(s - 1.0, 0.0))).normalized()
		# Turned no more than the path does from one point to the next.
		across = (across - way * across.dot(way))
		if across.length_squared() < 1e-6:
			across = Vector3.UP if absf(way.y) < 0.9 else Vector3.RIGHT
			across = across - way * across.dot(way)
		across = across.normalized()
		var basis := Basis(across, way, across.cross(way))
		var before: float = (s - at[n - 1]) / 3.0 if n > 0 else (at[1] - s) / 3.0
		var after: float = (at[n + 1] - s) / 3.0 if n < at.size() - 1 else before
		var said: String = _with(template, "posOri", _numbers(Transform3D(basis, line.at(s))))
		said = _with(said, "prevCPDist", _number(before))
		points.append(_with(said, "nextCPDist", _number(after)))
	var index: int = out.find("")
	if index >= 0:
		out.remove_at(index)
		for n: int in range(points.size() - 1, -1, -1):
			out.insert(index, points[n])
	# Each cap on its end piece as the pieces now stand.
	var end_pieces: Array = []
	var spec: Dictionary = Flex.KINDS[kind]
	var middle: String = str(spec.get("middle", spec.get("segment", "")))
	for piece: Dictionary in pieces:
		if str(piece["part"]) != middle:
			end_pieces.append(piece)
	for cap: String in caps:
		var tip: Vector3 = b.tip if cap.contains("[group=end]") else a.tip
		var best: Dictionary = {}
		var nearest: float = INF
		for piece: Dictionary in end_pieces:
			var gap: float = (piece["at"] as Transform3D).origin.distance_to(tip)
			if gap < nearest:
				nearest = gap
				best = piece
		out.append(_with(cap, "posOri", _numbers(best["at"])) if not best.is_empty() else cap)
	return out


## [param line] with its [name=...] field set to [param value].
static func _with(line: String, name: String, value: String) -> String:
	var at: int = line.find("[%s=" % name)
	if at < 0:
		return line
	var close: int = line.find("]", at)
	return line.substr(0, at) + "[%s=%s]" % [name, value] + line.substr(close + 1)


## A place in the app's axes as LDCad's posOri: x y z and the matrix by
## rows, in LDraw's.
static func _numbers(at: Transform3D) -> String:
	var said := PackedStringArray()
	for value: float in LdrModel.from_transform(at):
		said.append(_number(value))
	return " ".join(said)


static func _number(value: float) -> String:
	var shown: String = String.num(value, 6)
	if shown.contains("."):
		shown = shown.rstrip("0").rstrip(".")
	return "0" if shown == "-0" or shown.is_empty() else shown


## A path line's posOri as a place in the app's axes, or null.
static func _pos_ori(line: String) -> Variant:
	var at: int = line.find("[posOri=")
	if at < 0:
		return null
	var words: PackedStringArray = line.substr(at + 8, line.find("]", at) - at - 8).split(" ", false)
	if words.size() < 12:
		return null
	var numbers := PackedFloat64Array()
	for k: int in 12:
		numbers.append(float(words[k]))
	return LdrModel.to_transform(numbers)
