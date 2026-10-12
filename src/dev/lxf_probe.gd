## Opening a LEGO Digital Designer model (.lxf).
##
##   godot --headless --path . --script src/dev/lxf_probe.gd
##
## A real one first: src/dev/fixtures/49311_test.lxf, saved by LDD 4.3 (from
## github.com/sttng/LDD, MIT; docs/ATTRIBUTION.md). Fourteen green 2 x 4
## bricks standing as a wall on a red 8 x 8 plate, and a red 1 x 4 x 3 brick
## on the ground beside it, as LDD's own thumbnail in the file shows. Every
## part has to come out where LDD put it: the plate on the ground, each
## course of bricks one brick above the last, every brick on the plate's
## studs. Then it is opened the way a person opens it, through the file
## picker's own path, and the bricks are counted in the world.
##
## Then a part LDD has and LDraw has not: named, not dropped. A turned
## brick, turned. And models written out as LDD would write them — the
## house and the castle shipped in models/, every part at its LDraw
## placement — read back to the same placements, which they cannot be
## unless the turns, the axes, the units and every part's origin are right
## both ways.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_a_real_one()
	_unknown_parts()
	_turned()
	_written_and_read("res://models/house.ldr")
	_written_and_read("res://models/castle.ldr")
	await _opened_by_the_picker()
	print("")
	if _failures == 0:
		print("lxf: LDD's models open where LDD put every part, and what cannot be placed "
			+ "is named")
	else:
		print("lxf: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- a real one ---------------------------------------------------------------


func _a_real_one() -> void:
	print("  49311_test.lxf, from LDD 4.3")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		"res://src/dev/fixtures/49311_test.lxf")
	_check("the fixture is there (%d bytes)" % bytes.size(), bytes.size() > 1000)
	var read: Dictionary = LddLxf.read(bytes, "49311_test")
	_check("it reads (%s)" % (read["error"] if not str(read["error"]).is_empty() else "no error"),
		str(read["error"]).is_empty())
	_check("all 16 parts placed (%d), none left out" % int(read["parts"]),
		int(read["parts"]) == 16 and (read["unknown"] as Dictionary).is_empty()
		and str(read["note"]).is_empty())
	var lines: Array = _parts_in(str(read["text"]))
	var by_part: Dictionary = {}
	for line: Dictionary in lines:
		by_part[line["part"]] = int(by_part.get(line["part"], 0)) + 1
	_check("14 of 3001, a 41539 and a 49311 (%s)" % by_part,
		by_part == {"3001": 14, "41539": 1, "49311": 1})

	var plate: Dictionary = lines.filter(func(l: Dictionary) -> bool:
		return l["part"] == "41539")[0]
	_check("the 8 x 8 plate is red (%d) and lies on the ground, its top 8 LDU up (%s)"
		% [plate["colour"], plate["at"]], plate["colour"] == 4
		and is_equal_approx(plate["at"].y, -8.0) and plate["turn"] == Basis.IDENTITY)
	var tall: Dictionary = lines.filter(func(l: Dictionary) -> bool:
		return l["part"] == "49311")[0]
	_check("the 1 x 4 x 3 is red and stands on the ground beside it, its top 72 up (%s)"
		% tall["at"], tall["colour"] == 4 and is_equal_approx(tall["at"].y, -72.0)
		and tall["at"].x > 100.0)

	var bricks: Array = lines.filter(func(l: Dictionary) -> bool: return l["part"] == "3001")
	var courses: Dictionary = {}
	var on_studs: bool = true
	var level: bool = true
	var green: bool = true
	for brick: Dictionary in bricks:
		var at: Vector3 = brick["at"]
		courses[int(round(-at.y))] = int(courses.get(int(round(-at.y)), 0)) + 1
		green = green and brick["colour"] == 10
		var turn: Basis = brick["turn"]
		level = level and turn.y.is_equal_approx(Vector3.UP) \
			and is_equal_approx(absf(turn.x.x) + absf(turn.x.z), 1.0)
		# A 2 x 4's studs: across its 2 the centre is on a stud line, along
		# its 4 between two. Whichever way it is turned, one of x and z is a
		# multiple of 20 and the other is not.
		var x_on: bool = is_equal_approx(fposmod(at.x, 20.0), 0.0) \
			or is_equal_approx(fposmod(at.x, 20.0), 20.0)
		var z_on: bool = is_equal_approx(fposmod(at.z, 20.0), 0.0) \
			or is_equal_approx(fposmod(at.z, 20.0), 20.0)
		on_studs = on_studs and (x_on or z_on) and is_equal_approx(fposmod(at.x, 10.0), 0.0) \
			and is_equal_approx(fposmod(at.z, 10.0), 0.0)
	_check("the 2 x 4s are green (LDD's Bright Green, LDraw 10)", green)
	_check("...upright, turned only about the vertical", level)
	_check("...in courses a brick apart on the plate: tops at %s" % [courses.keys()],
		courses.keys().all(func(top: int) -> bool: return (top - 8) % 24 == 0 and top >= 32)
		and courses.has(32))
	_check("...every one on the plate's studs", on_studs)
	# The positions as worked by hand from the file and ldraw.xml, for two
	# of them: see LddLxf for the sum.
	var want: Array = [["3001", Vector3(20, -32, -100)], ["3001", Vector3(-40, -32, -120)],
		["41539", Vector3(-40, -8, -60)], ["49311", Vector3(160, -72, -90)]]
	for wanted: Array in want:
		var found: bool = lines.any(func(l: Dictionary) -> bool:
			return l["part"] == wanted[0] and (l["at"] as Vector3).is_equal_approx(wanted[1]))
		_check("a %s at %s, as worked by hand" % wanted, found)


# -- what cannot be placed ----------------------------------------------------


func _unknown_parts() -> void:
	print("  a part LDraw has not got")
	var xml: String = _lxfml([["999999", "21", "1,0,0,0,1,0,0,0,1,0,0,0"],
		["3001", "21", "1,0,0,0,1,0,0,0,1,0,0,0"],
		["999999", "1", "1,0,0,0,1,0,0,0,1,1.6,0,0"],
		["3001", "1234", "1,0,0,0,1,0,0,0,1,0,0.96,0"]])
	var read: Dictionary = LddLxf.from_lxfml(xml.to_utf8_buffer(), "unknown")
	_check("the parts it knows are placed (%d)" % int(read["parts"]), int(read["parts"]) == 2)
	_check("the one it does not is named with how many: %s" % read["unknown"],
		read["unknown"] == {"999999": 2})
	_check("...in what the person is told: \"%s\"" % read["note"],
		str(read["note"]).contains("999999 ×2") and str(read["note"]).contains("left out"))
	_check("...and in the file, where a person reading it will see it",
		str(read["text"]).contains("0 // LDD part 999999"))
	_check("a colour LDraw has no match for is said too", str(read["note"]).contains("colour"))
	var nothing: Dictionary = LddLxf.from_lxfml("<LXFML><Bricks></Bricks></LXFML>".to_utf8_buffer())
	_check("an empty model says so: \"%s\"" % nothing["error"],
		str(nothing["error"]).contains("no parts"))
	var other: Dictionary = LddLxf.read("hello".to_utf8_buffer())
	_check("something that is not LDD's says so: \"%s\"" % other["error"],
		not str(other["error"]).is_empty())


# -- turned -------------------------------------------------------------------


func _turned() -> void:
	print("  turned")
	var xml: String = _lxfml([["3001", "21", "1,0,0,0,1,0,0,0,1,0,0,0"],
		["3001", "21", "0,0,-1,0,1,0,1,0,0,4.8,0,0"]])
	var lines: Array = _parts_in(str(LddLxf.from_lxfml(xml.to_utf8_buffer())["text"]))
	_check("two bricks", lines.size() == 2)
	if lines.size() != 2:
		return
	var straight: Basis = lines[0]["turn"]
	var turned: Basis = lines[1]["turn"]
	_check("one as LDraw has it", straight.is_equal_approx(Basis.IDENTITY))
	# LDD's +Y is LDraw's -Y, so LDD's quarter turn about its up is a
	# quarter turn the other way about LDraw's.
	_check("the other a quarter turn about the vertical (%s)" % [turned],
		turned.y.is_equal_approx(Vector3.UP) and absf(turned.x.dot(Vector3.RIGHT)) < 1e-6)
	var long_way: Vector3 = turned * Vector3(80, 0, 0)
	_check("...so its four studs run along z (%s)" % long_way,
		absf(long_way.z) > 79.0 and absf(long_way.x) < 1.0)


# -- written as LDD would write them, and read back ---------------------------


## Every part of an LDraw model written as LXFML — LDD's numbers, LDD's axes,
## LDD's units, LDD's origins — and read back: the same parts at the same
## placements, which holds only if the conversion is right both ways.
func _written_and_read(path: String) -> void:
	print("  %s, written as LDD would and read back" % path.get_file())
	var table: Dictionary = LddLxf._load_table()
	var design_of: Dictionary = {}
	for design: String in table["parts"]:
		design_of[table["parts"][design]] = design
	var material_of: Dictionary = {}
	for material: String in table["colours"]:
		material_of[int(table["colours"][material])] = material
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
	var parts: Array = []
	var rows: Array = []
	var skipped: int = 0
	for line: Dictionary in _parts_in(FileAccess.get_file_as_string(path)):
		var origin: Variant = table["origins"].get(line["part"])
		var material: Variant = material_of.get(line["colour"])
		if origin == null or material == null:
			skipped += 1
			continue
		var m: Basis = flip * (line["turn"] as Basis) * flip
		var move := Vector3(origin[0], origin[1], origin[2])
		var axis := Vector3(origin[3], origin[4], origin[5])
		var turn := Basis.IDENTITY
		if axis.length_squared() > 1e-12 and absf(float(origin[6])) > 1e-12:
			turn = Basis(axis.normalized(), -float(origin[6]))
		var bone: Basis = m * turn.inverse()
		var at: Vector3 = flip * (line["at"] as Vector3) / LddLxf.LDU + m * move
		var numbers := PackedStringArray()
		for column: int in 3:
			for row: int in 3:
				numbers.append(str(bone[column][row]))
		for axis_n: int in 3:
			numbers.append(str(at[axis_n]))
		rows.append([str(design_of.get(line["part"], line["part"])), str(material),
			",".join(numbers)])
		parts.append(line)
	var read: Dictionary = LddLxf.from_lxfml(_lxfml(rows).to_utf8_buffer())
	var back: Array = _parts_in(str(read["text"]))
	var same: int = 0
	var first_wrong: String = ""
	for n: int in mini(parts.size(), back.size()):
		var a: Dictionary = parts[n]
		var b: Dictionary = back[n]
		if a["part"] == b["part"] and a["colour"] == b["colour"] \
				and (a["at"] as Vector3).distance_to(b["at"]) < 0.01 \
				and (a["turn"] as Basis).is_equal_approx(b["turn"]):
			same += 1
		elif first_wrong.is_empty():
			first_wrong = "%s at %s came back as %s at %s" % [a["part"], a["at"], b["part"],
				b["at"]]
	_check("%d of %d parts back where they were%s (%d had no LDD number to write)"
		% [same, parts.size(), "" if first_wrong.is_empty() else ": " + first_wrong, skipped],
		parts.size() > 0 and same == parts.size() and back.size() == parts.size())


# -- opened as a person opens it ----------------------------------------------


func _opened_by_the_picker() -> void:
	print("  opened through the file picker")
	var library := PartLibrary.new()
	if not library.load_catalogue():
		_check("the catalogue loads", false)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.builder = builder
	store.library = library
	var picker := ModelFilePicker.new()
	get_root().add_child(picker)
	await process_frame
	var got: Array = []
	picker.picked.connect(func(text: String, file_name: String) -> void:
		got.append([text, file_name]))
	picker.failed.connect(func(why: String) -> void: got.append(["", why]))
	picker.take(FileAccess.get_file_as_bytes("res://src/dev/fixtures/49311_test.lxf"),
		"49311_test.lxf")
	_check("the picker takes an .lxf and hands on LDraw (%s)" % (
		got[0][1] if not got.is_empty() else "nothing"),
		got.size() == 1 and str(got[0][0]).begins_with("0 49311_test"))
	if got.is_empty() or str(got[0][0]).is_empty():
		return
	var result: Dictionary = store.open_text(str(got[0][0]), "49311_test")
	_check("it opens: %d placed, %d not in the library" % [int(result["placed"]),
		int(result["missing"])], int(result["placed"]) == 16 and int(result["missing"]) == 0)
	await process_frame
	var heights: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id == "3001":
			heights[int(round(brick.transform.origin.y))] = true
	_check("the wall stands on the plate in the world, Y up: tops at %s" % [heights.keys()],
		heights.has(32) and heights.keys().all(func(y: int) -> bool: return (y - 8) % 24 == 0))
	picker.take("<LXFML><Bricks><Brick><Part designID=\"999999\" materials=\"21\"><Bone transformation=\"1,0,0,0,1,0,0,0,1,0,0,0\"/></Part></Brick><Brick><Part designID=\"3001\" materials=\"21\"><Bone transformation=\"1,0,0,0,1,0,0,0,1,0,0,0\"/></Part></Brick></Bricks></LXFML>".to_utf8_buffer(), "odd.lxfml")
	_check("a bare .lxfml opens too, and the picker says what it left out: \"%s\""
		% picker.notes, got.size() == 2 and picker.notes.contains("999999"))
	world.queue_free()
	builder.queue_free()
	picker.queue_free()


# -- reading ------------------------------------------------------------------


## An LXFML file with a part for each [design, material, transformation].
func _lxfml(rows: Array) -> String:
	var out := PackedStringArray(['<?xml version="1.0" encoding="UTF-8"?>',
		'<LXFML versionMajor="5" versionMinor="0" name="probe">', "<Bricks>"])
	for n: int in rows.size():
		out.append('<Brick refID="%d" designID="%s"><Part refID="%d" designID="%s" materials="%s">'
			% [n, rows[n][0], n, rows[n][0], rows[n][1]]
			+ '<Bone refID="%d" transformation="%s"></Bone></Part></Brick>' % [n, rows[n][2]])
	out.append("</Bricks></LXFML>")
	return "\n".join(out)


## The parts of an LDraw text: {part, colour, at, turn}, in order.
func _parts_in(text: String) -> Array:
	var out: Array = []
	for raw: String in text.split("\n"):
		var bits: PackedStringArray = raw.strip_edges().split(" ", false)
		if bits.size() < 15 or bits[0] != "1":
			continue
		var v: PackedFloat64Array = PackedFloat64Array()
		for n: int in range(2, 14):
			v.append(bits[n].to_float())
		out.append({"colour": bits[1].to_int(), "at": Vector3(v[0], v[1], v[2]),
			"turn": Basis(Vector3(v[3], v[6], v[9]), Vector3(v[4], v[7], v[10]),
				Vector3(v[5], v[8], v[11])),
			"part": bits[14].get_basename().to_lower()})
	return out
