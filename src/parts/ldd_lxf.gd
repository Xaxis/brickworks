## Reading a LEGO Digital Designer model (.lxf, or the .lxfml inside one).
##
## An .lxf is a zip around an LXFML file: XML listing every part by LEGO's
## design number, its colour by LEGO's material number, and where it is as
## a matrix (a "bone": the part's X, Y and Z axes as the world sees them,
## then where its origin is). LDD's world is Y up and in centimetres, a stud
## 0.8 apart; LDraw's is Y down and in LDU, 20 to a stud, so 25 LDU to LDD's
## unit. And LDD's part has its origin somewhere else than LDraw's — a
## brick's at the corner of its bottom, LDraw's at the middle of its top —
## which ldraw.xml records for each part as a move and a turn
## (assets/ldraw/ldd.json, written by tools/ldd_map.py; lxf2ldr, LeoCAD and
## Studio read the same table).
##
## A part's LDraw placement is then, with A the turn from Y up to Y down
## (diag(1, -1, -1)), R and T the bone, and r and t the table's turn and
## move for the part:
##
##     M = R r⁻¹           (the table's turn is undone; r⁻¹ turns by -angle)
##     LDraw matrix   = A M A
##     LDraw position = 25 A (T - M t)
##
## What comes out is LDraw text, which the app reads like any other file.
## A part the table cannot place is left out and named, never dropped
## silently: the LDraw text carries a comment for each, and [method read]
## says which and how many.
class_name LddLxf
extends RefCounted

const TABLE := "res://assets/ldraw/ldd.json"
## LDraw units in one of LDD's.
const LDU := 25.0
## A colour LDD names that the table does not: light bluish grey, so the
## part is there and plainly not its own colour.
const UNKNOWN_COLOUR := 71

static var _table: Dictionary = {}


## The LDraw text of an .lxf (or a bare .lxfml): {"text", "error", "parts":
## how many were placed, "unknown": {LDD design number: how many}, "note":
## a sentence about what was left out, or ""}.
static func read(bytes: PackedByteArray, name: String = "model") -> Dictionary:
	var xml: PackedByteArray = bytes
	# A zip starts "PK"; LXFML on its own starts with its XML.
	if bytes.size() > 4 and bytes[0] == 0x50 and bytes[1] == 0x4b:
		var entries: Dictionary = StudioIo._entries(bytes)
		if entries.has("error"):
			return _failed("that is not an LDD .lxf file")
		var member: String = ""
		for entry_name: String in entries:
			if entry_name.ends_with(".lxfml"):
				member = entry_name
				break
		if member.is_empty():
			return _failed("there is no model inside that .lxf file")
		xml = StudioIo._unpack(bytes, entries[member])
		if xml.is_empty():
			return _failed("could not unpack the model from that .lxf file")
	return from_lxfml(xml, name)


## LXFML, as LDraw text: see [method read].
static func from_lxfml(xml: PackedByteArray, name: String = "model") -> Dictionary:
	var table: Dictionary = _load_table()
	if table.is_empty():
		return _failed("this build has no table of LDD's part numbers")
	var parser := XMLParser.new()
	if parser.open_buffer(xml) != OK:
		return _failed("that LDD file could not be read")
	var lines := PackedStringArray([
		"0 %s" % name,
		"0 Name: %s.ldr" % name.validate_filename(),
		"0 Author: converted from an LDD .lxf file by Brickworks",
		"0 !LDRAW_ORG Unofficial_Model",
		""])
	var placed: int = 0
	var unknown: Dictionary = {}
	var unplaced: int = 0
	var unknown_colours: int = 0
	var lxfml: bool = false
	var part: Dictionary = {}
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		match parser.get_node_name():
			"LXFML":
				lxfml = true
			"Part":
				if not part.is_empty():
					# A part with no bone: LXFML from before LDD 4.
					unplaced += 1
				part = {"design": parser.get_named_attribute_value_safe("designID"),
					"materials": parser.get_named_attribute_value_safe("materials")}
			"Bone":
				if part.is_empty():
					continue
				var placing: Dictionary = _place(part, parser.get_named_attribute_value_safe(
					"transformation"), table)
				part = {}
				if placing.has("unknown"):
					var design: String = str(placing["unknown"])
					unknown[design] = int(unknown.get(design, 0)) + 1
					lines.append("0 // LDD part %s has no LDraw part this table knows: left out"
						% design)
					continue
				if bool(placing["colour_unknown"]):
					unknown_colours += 1
				lines.append(str(placing["line"]))
				placed += 1
	if not part.is_empty():
		unplaced += 1
	if not lxfml:
		return _failed("that is not an LDD model")
	if placed == 0 and unknown.is_empty() and unplaced > 0:
		return _failed("that LDD file is from before LDD 4 and has no placements this "
			+ "reads — open it in LDD 4 and save it again")
	if placed == 0 and unknown.is_empty():
		return _failed("there are no parts in that LDD file")
	return {"text": "\n".join(lines) + "\n", "error": "", "parts": placed,
		"unknown": unknown, "note": _note(unknown, unknown_colours, unplaced)}


## One part's LDraw line: {"line", "colour_unknown"}, or {"unknown": design}
## when the table cannot place it.
static func _place(part: Dictionary, transformation: String, table: Dictionary) -> Dictionary:
	var design: String = str(part["design"])
	var renamed: Dictionary = table.get("parts", {})
	var origins: Dictionary = table.get("origins", {})
	var ldraw: String = str(renamed.get(design, design.to_lower()))
	var origin: Variant = origins.get(ldraw)
	var numbers: PackedFloat64Array = PackedFloat64Array()
	for value: String in transformation.split(","):
		numbers.append(value.to_float())
	if origin == null or numbers.size() != 12:
		return {"unknown": design}
	var bone := Basis(Vector3(numbers[0], numbers[1], numbers[2]),
		Vector3(numbers[3], numbers[4], numbers[5]),
		Vector3(numbers[6], numbers[7], numbers[8]))
	var at := Vector3(numbers[9], numbers[10], numbers[11])
	var move := Vector3(float(origin[0]), float(origin[1]), float(origin[2]))
	var axis := Vector3(float(origin[3]), float(origin[4]), float(origin[5]))
	var angle: float = float(origin[6])
	var turn := Basis.IDENTITY
	if axis.length_squared() > 1e-12 and absf(angle) > 1e-12:
		turn = Basis(axis.normalized(), -angle)
	var m: Basis = bone * turn
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
	var matrix: Basis = flip * m * flip
	var position: Vector3 = flip * (at - m * move) * LDU

	var colours: Dictionary = table.get("colours", {})
	var material: String = str(part["materials"]).split(",")[0].strip_edges()
	var colour: Variant = colours.get(material)
	var colour_unknown: bool = colour == null
	var code: int = UNKNOWN_COLOUR if colour_unknown else int(colour)

	var numbers_out := PackedStringArray([str(code), _tidy(position.x), _tidy(position.y),
		_tidy(position.z)])
	# Row by row, as LDraw writes a matrix: Basis is held by columns.
	for row: int in 3:
		for column: int in 3:
			numbers_out.append(_tidy(matrix[column][row], 6))
	return {"line": "1 %s %s.dat" % [" ".join(numbers_out), ldraw],
		"colour_unknown": colour_unknown}


## A number as a file keeps it: LDD writes floats, 1.1999998 for 1.2, so a
## stud's position comes out a hair off; to the nearest 1/10000 LDU, and
## whole numbers written whole.
static func _tidy(value: float, places: int = 4) -> String:
	var rounded: float = snappedf(value, pow(10.0, -places))
	if absf(rounded - roundf(rounded)) < pow(10.0, -places) * 0.5:
		rounded = roundf(rounded)
	if rounded == 0.0:
		return "0"
	var text: String = String.num(rounded, places)
	return text


static func _note(unknown: Dictionary, unknown_colours: int, unplaced: int) -> String:
	var said := PackedStringArray()
	if not unknown.is_empty():
		var named := PackedStringArray()
		var count: int = 0
		for design: String in unknown:
			count += int(unknown[design])
			named.append(design if int(unknown[design]) == 1
				else "%s ×%d" % [design, int(unknown[design])])
		said.append("%d LDD part%s with no LDraw match left out (%s)" % [count,
			"" if count == 1 else "s", ", ".join(named.slice(0, 6))
			+ (", …" if named.size() > 6 else "")])
	if unknown_colours > 0:
		said.append("%d in a colour LDraw has no match for, shown light bluish grey"
			% unknown_colours)
	if unplaced > 0:
		said.append("%d with no position, left out" % unplaced)
	return "; ".join(said)


static func _failed(why: String) -> Dictionary:
	return {"text": "", "error": why, "parts": 0, "unknown": {}, "note": ""}


static func _load_table() -> Dictionary:
	if _table.is_empty():
		var text: String = FileAccess.get_file_as_string(TABLE)
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
		if parsed is Dictionary:
			_table = parsed
	return _table
