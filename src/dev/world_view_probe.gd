## Check that the assistant reads back what it wrote.
##
##   godot --headless --path . --script src/dev/world_view_probe.gd
##
## look_at_model describes the baseplate in the same stud and plate
## coordinates the model places parts in, which is only useful if the
## two are exact inverses. If they are not, the assistant is told a
## brick is somewhere it is not, and every edit it makes from that
## reading lands in the wrong place — silently, because the placement
## itself is legal.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)

	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)

	# Every rotation, a few parts, a spread of positions — including
	# negative ones, which a naive integer conversion rounds the wrong
	# way across zero.
	var cases: Array = []
	for part: String in ["3001", "3005", "3024", "3040b", "3622"]:
		for rot: int in 4:
			for at: Vector3i in [Vector3i(0, 0, 0), Vector3i(3, 6, 2),
					Vector3i(-5, 0, -7), Vector3i(12, 15, -3)]:
				cases.append({"part": part, "rot": rot, "at": at})

	var wrong: int = 0
	var first_bad := ""
	for case: Dictionary in cases:
		world.clear()
		var placement := Assistant.Placement.new()
		placement.part = case["part"]
		placement.color = 4
		placement.x = case["at"].x
		placement.y = case["at"].y
		placement.z = case["at"].z
		placement.rot = case["rot"]

		var mesh: Lbm.PartMesh = library.mesh_for(placement.part)
		var at: Transform3D = assistant._transform(placement, mesh)
		var brick_id: int = world.add_brick(placement.part, 4, at)
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var info: PartLibrary.PartInfo = library.parts[placement.part]

		var read: Vector3i = assistant._to_studs(brick, info)
		var turns: int = Assistant._quarter_turns(brick.transform.basis)
		if read != case["at"] or turns != placement.rot:
			wrong += 1
			if first_bad.is_empty():
				first_bad = "%s rot %d at %v read back as %v rot %d" % [
					placement.part, placement.rot, case["at"], read, turns]

	_check("%d placements round-trip exactly%s"
		% [cases.size(), "" if first_bad.is_empty() else " — " + first_bad],
		wrong == 0)

	# Parts drawn inside their footprint, placed at whole studs, on them.
	#
	# A placement's corner was its cover's, and a 4 x 4 wing's cover
	# starts at its cut edge, two LDU in from its footprint. So at whole
	# studs it stood a tenth of a stud off the studs below it, and 24 of
	# the wing tips on one tower of Orthanc did, and the owner saw them.
	# Read back by the same corner, too, or every save and reopen moves
	# them. A wing, its other hand, a 4 x 6 wing, a turntable's top, a
	# tap, a flag, an antenna, plant leaves.
	var inset: Array = ["3935", "3936", "48205", "3679", "4599b", "4495b",
		"3957a", "2423"]
	var seated_wrong: Array = []
	var read_wrong: Array = []
	for part: String in inset:
		for rot: int in 4:
			for at: Vector3i in [Vector3i(0, 0, 0), Vector3i(3, 6, 2),
					Vector3i(-5, 0, -7)]:
				world.clear()
				var placement := Assistant.Placement.from_dict({"part": part,
					"color": 4, "x": at.x, "y": at.y, "z": at.z, "rot": rot})
				var mesh: Lbm.PartMesh = library.mesh_for(part)
				var put: Transform3D = assistant._transform(placement, mesh)
				var off: float = _off_the_studs(mesh, put)
				if off > 0.5:
					seated_wrong.append("%s rot %d at %v, %.1f LDU off" % [part, rot, at, off])
				var brick: BrickWorld.Brick = world.get_brick(world.add_brick(part, 4, put))
				var back: Vector3 = assistant._to_studs(brick, library.parts[part])
				if not back.is_equal_approx(Vector3(at)):
					read_wrong.append("%s rot %d at %v read back as %v" % [part, rot, at, back])
	_check("parts drawn inside their footprint, at whole studs, sit on studs%s"
		% ("" if seated_wrong.is_empty() else ": %d off, first %s" % [seated_wrong.size(), seated_wrong[0]]),
		seated_wrong.is_empty())
	_check("...and read back where they were put%s"
		% ("" if read_wrong.is_empty() else ": %d moved, first %s" % [read_wrong.size(), read_wrong[0]]),
		read_wrong.is_empty())

	# And the wings a pattern lays round an ellipse, which is where the
	# tower's came from: the pattern meant the footprint all along.
	world.clear()
	var wings: Array = Patterns.expand([{"pattern": "fill", "shape": "ellipse",
		"at": {"x": 0, "y": 0, "z": 0}, "across": 14, "deep": 10, "layers": 1,
		"rise": 1, "color": 71}], [], [], library)
	var laid: int = 0
	var laid_off: Array = []
	for raw: Variant in wings:
		var one: Dictionary = raw
		if not Patterns.WEDGES.has(str(one["part"])):
			continue
		laid += 1
		var mesh: Lbm.PartMesh = library.mesh_for(str(one["part"]))
		var off: float = _off_the_studs(mesh, assistant._transform(
			Assistant.Placement.from_dict(one), mesh))
		if off > 0.5:
			laid_off.append("%s rot %d at %s,%s, %.1f LDU off"
				% [one["part"], one.get("rot", 0), one["x"], one["z"], off])
	_check("the %d wings an ellipse is laid with sit on their studs%s"
		% [laid, "" if laid_off.is_empty() else ": %d off, first %s" % [laid_off.size(), laid_off[0]]],
		laid > 0 and laid_off.is_empty())

	# And the description itself has to say something usable.
	world.clear()
	world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	world.add_brick("3001", 1, Transform3D(Basis.IDENTITY, Vector3(80, 24, 0)))
	var text: String = assistant._describe_world()
	_check("names the parts it can see", text.contains("3001"))
	_check("counts them, got '%s'" % text.split("\n")[0],
		text.begins_with("2 parts"))
	_check("gives the extent in studs", text.contains("span x"))
	# And the extent covers the parts, not the corners they are named by.
	#
	# Two 2 x 4 bricks at x=0 and x=4 reach eight studs across and two
	# deep. The span used to be taken from the low corners alone, so it
	# said "x 0..4, z 0..0" — a model reported as a line. Anything
	# deciding whether something fits beside it was told the wrong size,
	# and four wing plates all placed at z=0 came back as "z 0..0".
	# Two 2 x 4 bricks, side by side and resting on the ground, are eight
	# studs across, two deep and one brick tall. Counting corners alone
	# made that "x 0..4, z 0..0, y 0..0" — a model reported as a point,
	# which is what anything deciding whether something fits was given.
	_check("...and it covers the parts, not the corners: %s"
		% text.split("\n")[1],
		text.contains("span x -2..6") and text.contains("z -1..1")
		and text.contains("y 0..3"))
	_check("says which were placed by hand", text.contains("placed by hand"))

	# How big it came out, which is the question the critique most needs
	# answered and the one a render answers worst. Two columns of 2x4s:
	# eight studs across, two deep, twelve plates tall — and twelve, not
	# twelve and a half, because the stud on top is not a course.
	world.clear()
	builder.lattice.clear()
	var stack := Assistant.Model.new()
	for n: int in 8:
		stack.placements.append(Assistant.Placement.from_dict({
			"part": "3001", "color": 4,
			"x": 0 if n < 4 else 4, "y": (n % 4) * 3, "z": 0}))
	assistant._apply(stack)
	var sizes: String = assistant._measured()
	_check("measures the model: %s" % sizes.split("\n")[0],
		sizes.contains("8 across") and sizes.contains("2 deep")
		and sizes.contains("12 plates tall"))
	# Banded by height, which is what says a saucer is too thick.
	_check("...and bands it by height, %d rows" % (sizes.count("plates ") - 1),
		sizes.contains("plates 0-2") and sizes.contains("plates 9-11")
		and not sizes.contains("plates 12-14"))

	# A taper has to read as one. This is the whole use of the thing: a
	# dome that came out as a cylinder is invisible in a photograph and
	# obvious in three numbers.
	world.clear()
	builder.lattice.clear()
	assistant.forget_built()
	var dome: Assistant.Model = assistant._read_model({"patterns": [{
		"pattern": "fill", "shape": "ellipse", "at": {"x": 0, "y": 0, "z": 0},
		"across": 16, "deep": 16, "layers": 8, "shrink": 2, "color": 71}]})
	assistant._apply(dome)
	var tapered: String = assistant._measured()
	_check("a dome reads as a taper: %s"
		% tapered.split("\n")[tapered.split("\n").size() - 1].strip_edges(),
		tapered.contains("16 across") and tapered.contains("4 across"))

	world.clear()
	_check("an empty baseplate says so",
		assistant._describe_world().contains("empty"))

	# A part whose size is a hair over a stud multiple used to be
	# anchored a whole stud wider than it is, so two of them placed
	# side by side reported an overlap that was not there — and the
	# repair loop would teach the model to stop using the part.
	for pair: Array in [["3941", "2 x 2 round brick"], ["6143", "2 x 2 round, reinforced"],
			["3001", "2 x 4 brick"], ["3005", "1 x 1 brick"]]:
		var part: String = pair[0]
		var info: PartLibrary.PartInfo = library.parts.get(part)
		if info == null:
			continue
		var wide: int = Assistant._cover_studs(library.mesh_for(part), info).x
		var side_by_side := Assistant.Model.new()
		for column: int in 2:
			var at := Assistant.Placement.new()
			at.part = part
			at.color = 4
			at.x = column * wide
			at.y = 0
			at.z = 0
			side_by_side.placements.append(at)
		var report: Dictionary = assistant._check(side_by_side)
		_check("two %s side by side: %s" % [pair[1], report["summary"]],
			bool(report["ok"]))

	# The body goes to Anthropic as it is, and a field it does not take
	# refuses every request — which is what a proxy's design_id once did.
	var direct: Dictionary = assistant.request_body()
	var strays := PackedStringArray()
	for field: String in direct:
		if not Assistant.ANTHROPIC_FIELDS.has(field):
			strays.append(field)
	_check("the call sends only fields Anthropic takes%s"
		% ("" if strays.is_empty() else " — stray: " + ", ".join(strays)),
		strays.is_empty())
	_check("...and asks for thinking itself", direct.has("thinking"))

	# And the drawing it gets back has to be a drawing — the whole point
	# is that a shape mistake is visible in it.
	world.clear()
	builder.lattice.clear()
	# A wall two studs thick and four tall, with a gap in the middle:
	# the notch must show.
	for level: int in 4:
		for column: int in 5:
			if level >= 1 and level <= 2 and column == 2:
				continue
			var at := Transform3D(Basis.IDENTITY,
				Vector3(column * 20.0 + 10.0, level * 24.0 + 24.0, 10.0))
			var id: int = world.add_brick("3005", 4, at)
			builder.register(id, "3005", at)

	var front: String = ModelView.draw(world, library, "front")
	var rows: PackedStringArray = front.split("\n")
	var drawn := PackedStringArray()
	for row: String in rows:
		if row.length() > 4 and (row.contains(".") or row.contains("a")):
			if not row.contains("="):
				drawn.append(row)
	_check("the front view has %d lines of drawing" % drawn.size(),
		drawn.size() >= 10)
	var has_gap: bool = false
	for row: String in drawn:
		var inside: String = row.substr(2, row.length() - 4)
		if inside.contains("."):
			has_gap = true
	_check("a hole in the wall shows as a hole", has_gap)
	_check("the legend names the colour", front.contains("Red"))
	_check("it says which way is up", front.to_lower().contains("up the page"))

	var plan: String = ModelView.draw(world, library, "top")
	_check("a plan from above says so", plan.to_lower().contains("looking down"))
	_check("an unknown side is refused",
		ModelView.draw(world, library, "sideways").contains("No view"))
	world.clear()
	_check("an empty baseplate draws nothing",
		ModelView.draw(world, library, "front").contains("Nothing is built"))

	print("")
	print("%d failed" % _failures if _failures
		else "the assistant reads back exactly what it writes")
	quit(1 if _failures else 0)


## How far the part's upward studs stand from the middles of the
## baseplate's, in LDU, the worst of them; its tubes where it has no
## studs, which for a one-by-one stand at a middle too.
static func _off_the_studs(mesh: Lbm.PartMesh, at: Transform3D) -> float:
	var worst: float = 0.0
	for kind: String in ["stud", "tube"]:
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != kind \
					or absf((at.basis * connector.axis).normalized().y) < 0.99:
				continue
			var where: Vector3 = at * connector.position
			for v: float in [where.x - 10.0, where.z - 10.0]:
				var r: float = fposmod(v, 20.0)
				worst = maxf(worst, minf(r, 20.0 - r))
		if worst > 0.0 or kind == "stud" and mesh.connectors.any(
				func(c: Lbm.Connector) -> bool: return c.kind == "stud"):
			return worst
	return worst


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
