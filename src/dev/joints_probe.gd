## Do the joints real sets use pass the checker, where they are joints and
## nowhere else?
##
##   godot --headless --path . --script src/dev/joints_probe.gd
##
## Of 880 real sets' sub-models (tools/omr.py harvest, src/dev/
## harvest_probe.gd) the checker refused 232 for overlaps, and most were
## not overlaps at all: a clip on a bar, a bar in a hollow stud, a hinge's
## two halves, a turntable's top on its base. Each is something round in
## something round that fits it, which the cover fills in like any other
## ring. The parts pipeline now records those rounds (shafts and bores,
## tools/ldraw/connectivity.py) and the checker forgives an overlap that
## lies inside one (Joints.rounds) — so each is tried here where real sets
## put it, and then a little wrong, which must still be refused: a bar
## through a brick with no hole, a turntable's top off its base, a clip on
## something too thick for it, a hinge's halves apart.
##
## Needs a catalogue built with shafts and bores. One without them is
## said, and fails: a checker that cannot see the joints refuses every
## one of the cases that should pass.
extends SceneTree

const PATH := "user://joints_probe.ldr"

var _failures: int = 0
var _assistant: Assistant
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame

	print("\nthe parts carry their rounds")
	_ok(_has(_library, "30374", "shaft", 4.0), "a bar (30374) has a shaft 4 across")
	_ok(_has(_library, "4085c", "bore", 4.0), "a clip (4085c) has a bore 4 across")
	_ok(_has(_library, "3062b", "bore", 4.0), "a hollow-stud brick (3062b) has a bore 4 across")
	_ok(_has(_library, "3831", "bore", 6.0) and _has(_library, "3830", "shaft", 6.0),
		"a hinge brick's base has an eye and its top a pin, 6 across")
	_ok(_has(_library, "3680", "bore", 17.5) and _has(_library, "3679", "shaft", 17.5),
		"a 2x2 turntable's base has a recess and its top a disc, 17.5 across")

	print("\nwhat a joint forgives")
	_check_cores()

	print("\na bar in a hollow stud")
	# 3062b is bored right through: a lightsaber blade in one, as sets
	# hold a pole, runs from the open stud down through the tube.
	await _passes("a bar through a 1x1 round brick with a hollow stud", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 36 0 -80 0 1 0 0 0 1 0 0 0 1 30374.dat
""")
	await _refused("the same bar through a 1x1 brick, which has no hole", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
1 36 0 -80 0 1 0 0 0 1 0 0 0 1 30374.dat
""")
	await _refused("the bar a stud to one side, through the brick beside it", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 4 20 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
1 36 20 -80 0 1 0 0 0 1 0 0 0 1 30374.dat
""")

	print("\na clip on a bar")
	# 4085c's clip holds a bar upright at z=-20 of the plate.
	await _passes("a bar upright in a plate's vertical clip", """
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 4085c.dat
1 0 0 -60 -20 1 0 0 0 1 0 0 0 1 87994.dat
""")
	await _refused("a Technic axle in the clip, which is too thick for it", """
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 4085c.dat
1 0 0 -40 -20 0 -1 0 1 0 0 0 0 1 3705.dat
""")
	await _refused("a 1x1 brick in the clip, which has no bar", """
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 4085c.dat
1 0 0 -24 -20 1 0 0 0 1 0 0 0 1 3005.dat
""")
	# And held by it: a flag clipped to a bar has nothing under it.
	await _passes("a flag clipped to a bar in a hollow stud, held only by the clips",
		"""
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 36 0 -80 0 1 0 0 0 1 0 0 0 1 30374.dat
1 4 0 -60 0 1 0 0 0 1 0 0 0 1 4495a.dat
""")

	print("\na hinge's two halves")
	await _passes("hinge brick 1x4, top on base, straight", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3830.dat
""")
	await _passes("the same hinge with the top swung a quarter turn", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 0 -24 0 0 0 1 0 1 0 -1 0 0 3830.dat
""")
	await _passes("hinge plate 1x4, top on base", """
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 2429.dat
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 2430.dat
""")
	# Half a stud into the base, not a whole one along: a whole stud the
	# other way only takes the two apart, which is no joint and no fault.
	await _refused("the hinge's top half a stud into its base", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 -10 -24 0 1 0 0 0 1 0 0 0 1 3830.dat
""")
	# The joint is real and the pin is in its eye, but the top is swung a
	# quarter turn the other way, into its own base: the overlap is
	# forgiven inside the eye and nowhere else, so the bodies collide.
	# (Half round is not a fault: the pivot is at the brick's edge, so the
	# top folds alongside its base.)
	await _refused("the hinge's top swung a quarter turn into its base", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 0 -24 0 0 0 -1 0 1 0 1 0 0 3830.dat
""")
	await _passes("the hinge's top swung half round, folded alongside its base", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 0 -24 0 -1 0 0 0 1 0 0 0 -1 3830.dat
""")
	await _refused("the hinge's top two LDU off its pivot", """
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3831.dat
1 4 2 -24 0 1 0 0 0 1 0 0 0 1 3830.dat
""")

	print("\na turntable's top on its base")
	await _passes("2x2 turntable, top on base", """
1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 3679.dat
""")
	await _refused("the top a stud off its base", """
1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat
1 4 20 -8 0 1 0 0 0 1 0 0 0 1 3679.dat
""")
	await _refused("the top two LDU off its base", """
1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat
1 4 2 -8 0 1 0 0 0 1 0 0 0 1 3679.dat
""")
	for degrees: float in [45.0, 30.0, 10.0]:
		var turned: Dictionary = await _turned(degrees, Vector2.ZERO)
		_ok(bool(turned["ok"]), "the top and a brick on it turned %d degrees about the base: %s"
			% [int(degrees), turned["summary"]])
	var off: Dictionary = await _turned(45.0, Vector2(1, 0))
	_ok(not bool(off["ok"]) and str(off["summary"]).contains("overlap"),
		"turned 45 degrees about a point a stud off the base's axis, refused: %s"
		% off["summary"])

	print("\na section that leans has to lean on a joint")
	# The spires of a tower of Orthanc leaned on nothing: a section tipped
	# out sat on the studs below at a slant, gripping none of them.
	# Held by its joint, a lean holds — which it did not, at first, for
	# want of a cell: the halves are shaped to clear each other as the top
	# turns, by less than a cover can show, and 3938 tipped ten degrees
	# shared 99 cells with 3937 outside the pin. Turned on round into its
	# own base, it is a collision and still refused.
	for degrees: float in [10.0, -10.0, 45.0]:
		var hinged: Dictionary = await _leaning(true, degrees)
		_ok(bool(hinged["ok"]),
			"a hinge top turned %d degrees on its hinge brick holds: %s"
			% [int(degrees), hinged["summary"]])
	var over: Dictionary = await _leaning(true, 180.0)
	_ok(not bool(over["ok"]) and str(over["summary"]).contains("overlap"),
		"turned on round into its own base, refused: %s" % over["summary"])
	var bare: Dictionary = await _leaning(false, 12.0)
	_ok(not bool(bare["ok"]) and str(bare["feedback"]).contains("nothing in it turns"),
		"a brick tipped 12 degrees on a plain brick is refused: %s" % bare["summary"])

	print("\na pane in a frame the table did not list (Assistant.NESTS)")
	# Where three of the repository's sets seat it: 34 along, 4 down, 5 in,
	# a quarter turn.
	await _passes("3854 in a 6556 train window, where real sets seat it", """
1 15 0 -72 0 1 0 0 0 1 0 0 0 1 6556.dat
1 47 34 -68 5 0 0 1 0 1 0 -1 0 0 3854.dat
""")
	# Not turned into it, so it stands across the frame instead of in it.
	await _refused("the same pane where it is seated but not turned into the groove", """
1 15 0 -72 0 1 0 0 0 1 0 0 0 1 6556.dat
1 47 34 -68 5 1 0 0 0 1 0 0 0 1 3854.dat
""")

	print("\nturned about the upright and read from a file, in a section of its own")
	# A file keeps where a part is, not the section it was laid in, so a part
	# turned off the square comes back in a section found for it
	# (Assistant._adopted). The joints hold there as anywhere, for a reader
	# that keeps the section.
	await _passes("the frame and its pane turned 30 degrees together",
		_turned_text(30.0, [["6556", 15, Vector3(0, -72, 0), Basis.IDENTITY],
			["3854", 47, Vector3(34, -68, 5), Basis(Vector3(0, 0, 1), Vector3(0, 1, 0),
				Vector3(-1, 0, 0)).transposed()]]), true)
	await _refused("...and the pane not turned into its groove",
		_turned_text(30.0, [["6556", 15, Vector3(0, -72, 0), Basis.IDENTITY],
			["3854", 47, Vector3(34, -68, 5), Basis.IDENTITY]]), true)
	await _passes("a turntable's top turned 30 degrees on its base, a brick on it",
		"1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat\n" + _turned_text(30.0, [
			["3679", 4, Vector3(0, -8, 0), Basis.IDENTITY],
			["3003", 1, Vector3(0, -32, 0), Basis.IDENTITY]]), true)

	print("")
	if _failures == 0:
		print("the joints real sets use pass, and the same parts apart do not")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


## A part shaped like 3941, a 2x2 round brick: a cavity 16 across with a
## tube 8 across standing in it, and a bore 6 across at the tube's foot. A
## pin pushed into the foot is a joint, and the cavity is empty — but the
## tube inside it is not, and a joint on its axis must not make it so.
func _check_cores() -> void:
	var brick := Lbm.PartMesh.new()
	brick.connectors = [_round("bore", Vector3.ZERO, 16.0, 16.0),
		_round("shaft", Vector3.ZERO, 16.0, 8.0),
		_round("bore", Vector3(0, 16, 0), 4.0, 6.0)]
	var pin := Lbm.PartMesh.new()
	pin.connectors = [_round("shaft", Vector3(0, 14, 0), 8.0, 6.0)]
	var held: Dictionary = Joints.rounds([[0, Transform3D.IDENTITY, brick],
		[1, Transform3D.IDENTITY, pin]])
	_ok(held.has(0) and (held[0] as Dictionary).has(1), "a pin in the bore at its foot is a joint")
	if not (held.has(0) and (held[0] as Dictionary).has(1)):
		return
	var zones: Array = held[0][1]
	_ok(_forgiven(zones, Vector3i(0, 9, 0)), "an overlap in the bore the pin is in is forgiven")
	_ok(_forgiven(zones, Vector3i(6, 4, 0)), "and in the empty cavity it reaches into")
	_ok(not _forgiven(zones, Vector3i(0, 4, 0)), "but not in the tube standing inside the cavity")
	_ok(not _forgiven(zones, Vector3i(10, 4, 0)), "nor past the cavity's wall")


func _round(kind: String, from: Vector3, length: float, radius: float) -> Lbm.Connector:
	var c := Lbm.Connector.new()
	c.kind = kind
	c.gender = "male" if kind == "shaft" else "female"
	c.position = from
	c.axis = Vector3.UP
	c.length = length
	c.radius = radius
	return c


## Whether an overlap of one cell there would be forgiven.
func _forgiven(zones: Array, cell: Vector3i) -> bool:
	var box := PackedInt32Array([cell.x, cell.y, cell.z, cell.x + 1, cell.y + 1, cell.z + 1])
	return Joints.overlap_within(box, box, zones, Transform3D.IDENTITY, Joints.ROUND_SLACK)


func _has(library: PartLibrary, part_id: String, kind: String, radius: float) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return false
	for connector: Lbm.Connector in part.connectors:
		if connector.kind == kind and absf(connector.radius - radius) < 0.3:
			return true
	return false


## LDraw lines, opened as a model and read back as the placements a design
## would write, then checked as a design on an empty baseplate.
## The parts read back as new placements. [param sections]: with the sections
## a file's turned parts were read into; without, as a square design is.
func _design(ldraw: String, sections: bool = false) -> Assistant.Model:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("0 joints probe\n" + ldraw.strip_edges() + "\n")
	file.close()
	_clear()
	_store.open(PATH)
	for _n: int in 10:
		await process_frame
	var read: Assistant.Model = _assistant._model_from_world()
	_clear()
	var fresh := Assistant.Model.new()
	if sections:
		fresh.sections = read.sections.duplicate()
	for put: Assistant.Placement in read.placements:
		fresh.placements.append(Assistant.Placement.from_dict({"part": put.part,
			"color": put.color, "x": put.x, "y": put.y, "z": put.z,
			"face": put.face, "rot": put.rot,
			"section": put.section if sections else ""}))
	return fresh


## LDraw lines for parts, each [part, colour, position, basis] in LDU, all
## turned [param degrees] about the upright through the origin.
static func _turned_text(degrees: float, parts: Array) -> String:
	# LDraw's y points down, so a turn about it is the same matrix.
	var turn := Basis(Vector3.UP, deg_to_rad(degrees))
	var lines := PackedStringArray()
	for one: Array in parts:
		var at: Vector3 = turn * (one[2] as Vector3)
		var basis: Basis = turn * (one[3] as Basis)
		# LDraw's matrix is by rows: a b c / d e f / g h i.
		var rows: Array = []
		for r: int in 3:
			for c: int in 3:
				rows.append("%.6f" % basis[c][r])
		lines.append("1 %d %.4f %.4f %.4f %s %s.dat" % [int(one[1]), at.x, at.y, at.z,
			" ".join(PackedStringArray(rows)), str(one[0])])
	return "\n".join(lines)


func _passes(said: String, ldraw: String, sections: bool = false) -> void:
	var model: Assistant.Model = await _design(ldraw, sections)
	var verdict: Dictionary = _assistant._check(model, true)
	_ok(bool(verdict["ok"]) and model.placements.size() >= 2,
		"%s (%s)" % [said, verdict["summary"]])


func _refused(said: String, ldraw: String, sections: bool = false) -> void:
	var model: Assistant.Model = await _design(ldraw, sections)
	var verdict: Dictionary = _assistant._check(model, true)
	_ok(not bool(verdict["ok"]) and str(verdict["summary"]).contains("overlap"),
		"%s: refused (%s)" % [said, verdict["summary"]])


## The turntable square, then its top and a 2x2 brick on it moved into a
## section turned about the base's axis — or about a point [param off]
## studs from it.
func _turned(degrees: float, off: Vector2) -> Dictionary:
	var square: Assistant.Model = await _design("""
1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat
1 4 0 -8 0 1 0 0 0 1 0 0 0 1 3679.dat
1 1 0 -32 0 1 0 0 0 1 0 0 0 1 3003.dat
""")
	var base: Assistant.Placement = square.placements[0]
	var top: Assistant.Placement = square.placements[1]
	var part: Lbm.PartMesh = _library.mesh_for(top.part)
	# Where the turntable's axis is, in studs: the top's own origin.
	var axis: Vector3 = _assistant._transform(top, part).origin / Assistant.STUD
	var model := Assistant.Model.new()
	model.placements.append(base)
	for put: Assistant.Placement in square.placements.slice(1):
		model.placements.append(Assistant.Placement.from_dict({"part": put.part,
			"color": put.color, "x": put.x - axis.x - off.x, "y": put.y,
			"z": put.z - axis.z - off.y, "face": put.face, "rot": put.rot,
			"section": "turned"}))
	model.sections["turned"] = Assistant.Section.from_dict({"name": "turned",
		"x": axis.x + off.x, "y": 0.0, "z": axis.z + off.y, "axis": "y",
		"degrees": degrees})
	return _assistant._check(model, true)


## A closed tilting hinge (3937 with 3938 on it) on a 1 x 2, with its top
## in a section turned [param degrees] about the hinge pin — or, unhinged,
## a plain 1 x 2 where the base was and another tipped the same way on it.
## (3830/3831 swivel about the upright: a door, not a lean.)
func _leaning(hinged: bool, degrees: float) -> Dictionary:
	var closed: Assistant.Model = await _design("""
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3004.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3937.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3938.dat
""")
	# By part: a design read back from the world comes in the world's order.
	var by_part: Dictionary = {}
	for put: Assistant.Placement in closed.placements:
		by_part[put.part] = put
	var under: Assistant.Placement = by_part["3004"]
	var base: Assistant.Placement = by_part["3937"]
	var top: Assistant.Placement = by_part["3938"]
	var mesh: Lbm.PartMesh = _library.mesh_for(base.part)
	var at: Transform3D = _assistant._transform(base, mesh)
	# The pin: the base's flat round bores and the top's shafts share an
	# axis; any point on it will do for the pivot.
	var pin := Vector3.ZERO
	var way := Vector3.RIGHT
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "bore" and absf(connector.axis.y) < 0.5:
			pin = at * connector.position
			way = (at.basis * connector.axis).normalized()
			break
	var axis: String = "x" if absf(way.x) > absf(way.z) else "z"
	var pivot := Vector3(pin.x / Assistant.STUD, pin.y / Assistant.PLATE, pin.z / Assistant.STUD)
	var model := Assistant.Model.new()
	model.placements.append(under)
	if hinged:
		model.placements.append(base)
		model.placements.append(Assistant.Placement.from_dict({"part": top.part,
			"color": top.color, "x": top.x - pivot.x, "y": top.y - pivot.y,
			"z": top.z - pivot.z, "face": top.face, "rot": top.rot, "section": "lean"}))
	else:
		model.placements.append(Assistant.Placement.from_dict({"part": "3004",
			"color": base.color, "x": under.x, "y": under.y + 3.0, "z": under.z,
			"face": under.face, "rot": under.rot}))
		model.placements.append(Assistant.Placement.from_dict({"part": "3004",
			"color": top.color, "x": under.x - pivot.x, "y": under.y + 6.0 - pivot.y,
			"z": under.z - pivot.z, "face": under.face, "rot": under.rot, "section": "lean"}))
	model.sections["lean"] = Assistant.Section.from_dict({"name": "lean",
		"x": pivot.x, "y": pivot.y, "z": pivot.z, "axis": axis, "degrees": degrees})
	return _assistant._check(model, true)


func _clear() -> void:
	for brick: BrickWorld.Brick in _world.bricks():
		_builder.lattice.release(brick.id)
	_world.clear()
