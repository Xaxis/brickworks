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

	print("")
	print("%d failed" % _failures if _failures
		else "the assistant reads back exactly what it writes")
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
