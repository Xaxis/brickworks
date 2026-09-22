## Can part of a model be built square and then carried at an angle?
##
##   godot --headless --path . --script src/dev/section_probe.gd
##
## Every placement is one of twenty-four square orientations, so a
## nacelle pylon at thirty degrees, an opened hinge or a swept wing
## could not be said at all. Asking instead for each brick to carry its
## own angle would make the builder work out forty rotated positions by
## trigonometry, which is precisely the arithmetic that goes wrong.
##
## A real set does it the other way, and so does LDraw: the nacelle is a
## rigid square sub-assembly fixed to the hull at an angle. Inside it
## the coordinates are ordinary studs and plates; where it sits is said
## once.
extends SceneTree

var _failures: int = 0
var _assistant: Assistant


func _initialize() -> void:
	_run()


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	_assistant = Assistant.new()
	_assistant.library = library
	_assistant.world = world
	_assistant.builder = builder
	get_root().add_child(_assistant)
	await process_frame

	# Steep on purpose. At a shallow angle a stack inside the section
	# still happens to have its own cells underneath it in world
	# coordinates, so checking the wrong frame gives the right answer by
	# luck and the test proves nothing. Laid right over, the brick above
	# is beside the one below, and only a check done in the section's
	# own frame can tell that they are stacked.
	print("  a section carried at an angle")
	var tilted: Assistant.Model = _model(75.0, 0.0, 0.0)
	var pose: Transform3D = _pose_of(tilted, library, 2)
	_check("a brick inside it is actually turned, %.0f deg"
		% _angle_of(pose.basis),
		_angle_of(pose.basis) > 70.0 and _angle_of(pose.basis) < 80.0)
	_check("and the section's own bricks still hold each other",
		_no_issue(tilted, "floating"))

	print("")
	print("  a section hinged right over")
	# The case that decides which frame the support check has to run
	# in. Turned past the horizontal, the brick above another one in
	# the section sits *below* it in the world — so asking the world
	# lattice what is underneath finds nothing and calls a stack of two
	# bricks floating. Only the section's own frame knows they are
	# stacked.
	var over: Assistant.Model = _model(180.0, 0.0, 6.0)
	_check("its bricks are still holding each other",
		_no_issue(over, "floating"))

	print("")
	print("  a section level with the hull behaves as before")
	var flat: Assistant.Model = _model(0.0, 0.0, 0.0)
	_check("nothing is reported floating", _no_issue(flat, "floating"))
	_check("and nothing is adrift", _no_issue(flat, "section adrift"))

	print("")
	print("  a section that touches nothing")
	var adrift: Assistant.Model = _model(0.0, 40.0, 9.0)
	_check("is caught rather than passed", not _no_issue(adrift,
		"section adrift"))

	print("")
	print("  and a model with no sections is unchanged")
	var plain := Assistant.Model.new()
	plain.placements.append(Assistant.Placement.from_dict(
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0}))
	plain.placements.append(Assistant.Placement.from_dict(
		{"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0}))
	var verdict: Dictionary = _assistant._check(plain)
	_check("two stacked bricks are still buildable", bool(verdict["ok"]))

	print("")
	if _failures == 0:
		print("a section can be built square and carried at an angle")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## A hull on the ground, and a two-brick section beside it.
func _model(degrees: float, at_x: float, at_y: float) -> Assistant.Model:
	var model := Assistant.Model.new()
	for raw: Variant in [
			{"part": "3001", "color": 7, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 7, "x": 0, "y": 3, "z": 0, "rot": 0},
			{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0,
				"section": "nacelle"},
			{"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0,
				"section": "nacelle"}]:
		model.placements.append(Assistant.Placement.from_dict(raw))
	var section := Assistant.Section.from_dict({
		"name": "nacelle", "x": 4.0 + at_x, "y": at_y, "z": 0.0,
		"axis": "z", "degrees": degrees})
	model.sections["nacelle"] = section
	return model


## Where one placement ends up once its section has carried it.
func _pose_of(model: Assistant.Model, library: PartLibrary,
		index: int) -> Transform3D:
	var placement: Assistant.Placement = model.placements[index]
	return _assistant._transform(placement,
		library.mesh_for(placement.part), model.section_for(placement))


## Whether a check came back without a given kind of complaint.
func _no_issue(model: Assistant.Model, kind: String) -> bool:
	return not str(_assistant._check(model)["feedback"]).contains(kind)


static func _angle_of(basis: Basis) -> float:
	var up: Vector3 = (basis * Vector3.UP).normalized()
	return rad_to_deg(absf(atan2(up.x, up.y)))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
