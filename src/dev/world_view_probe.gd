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

	# And the description itself has to say something usable.
	world.clear()
	world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	world.add_brick("3001", 1, Transform3D(Basis.IDENTITY, Vector3(80, 24, 0)))
	var text: String = assistant._describe_world()
	_check("names the parts it can see", text.contains("3001"))
	_check("counts them, got '%s'" % text.split("\n")[0],
		text.begins_with("2 parts"))
	_check("gives the extent in studs", text.contains("span x"))
	_check("says which were placed by hand", text.contains("placed by hand"))

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

	# The two routes do not take the same body, and getting that wrong
	# refuses every request on the direct path — which is what happened.
	assistant.direct_key = "sk-not-a-real-key"
	assistant.account = null
	var direct: Dictionary = assistant.request_body()
	var strays := PackedStringArray()
	for field: String in direct:
		if not Assistant.ANTHROPIC_FIELDS.has(field):
			strays.append(field)
	_check("the direct call sends only fields Anthropic takes%s"
		% ("" if strays.is_empty() else " — stray: " + ", ".join(strays)),
		strays.is_empty())
	_check("...and asks for thinking itself", direct.has("thinking"))

	assistant.direct_key = ""
	assistant.account = Account.new()
	var proxied: Dictionary = assistant.request_body()
	_check("the proxied call carries the conversation id",
		proxied.has("design_id"))
	_check("...and leaves thinking to the proxy", not proxied.has("thinking"))

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


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
