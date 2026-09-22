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
	print("  a section that runs into the hull")
	# The answer to a section colliding is to move the section, not to
	# rebuild its bricks — and certainly not to give up on the angle. A
	# design told "brick 7 overlaps brick 3" did give up: "my pylon
	# sections dipped into the hull", and it came back with stepped
	# pylons and nothing angled anywhere.
	var into: Assistant.Model = _model(0.0, -4.0, 0.0)
	var complaint: String = str(_assistant._check(into)["feedback"])
	_check("says which section, and to move the section",
		complaint.contains("section 'nacelle' runs into")
			and complaint.contains("Move the section"))

	print("")
	print("  a section lifted into the air")
	# Its base course is written at the section's own y=0, which is not
	# the world's. Read off the written number, that brick counts as
	# standing on the ground however high the section is carried.
	var lifted: Assistant.Model = _model(0.0, 0.0, 9.0)
	var said: String = str(_assistant._check(lifted)["feedback"])
	_check("its base course is not excused from being held up",
		said.contains("nothing holding it"))

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
	print("  and a section survives being built")
	# The world holds one composed transform per brick — the section's
	# angle multiplied by the brick's own square placement, with no
	# record that the two were separate. Read back, the basis snaps to
	# the nearest of twenty-four and the angle is gone. So without
	# somewhere to keep it, an edit cannot give a section a new angle,
	# which the rules promise it can.
	var built: Assistant.Model = _model(30.0, 0.0, 0.0)
	_assistant._apply(built, false)
	await process_frame
	var reread: Assistant.Model = _assistant._model_from_world()
	var kept: int = 0
	for placement: Assistant.Placement in reread.placements:
		if placement.section == "nacelle":
			kept += 1
	_check("its bricks still know which section they are in, %d" % kept,
		kept == 2)
	_check("and the section itself is remembered",
		reread.sections.has("nacelle"))

	print("")
	print("  opening it further without naming a brick")
	var before: Basis = _first_of_section(world)
	var edited: Assistant.Model = _assistant._edit({"sections": [{
		"name": "nacelle", "x": 4.0, "y": 0.0, "z": 0.0,
		"axis": "z", "degrees": 70.0}]})
	_assistant._apply_edit(edited)
	await process_frame
	var after: Basis = _first_of_section(world)
	_check("a new angle on the section moves what is in it",
		not before.is_equal_approx(after))

	print("")
	print("  a tall section, tipped")
	# The thing that blocked sections completely. A part not square to
	# the grid cannot be rasterised onto it exactly, so it reserves
	# every cell it touches at all — safe against other assemblies and
	# quite wrong within one. Two bricks that abut exactly each reach a
	# little into the other once tipped, and a six-brick pylon came back
	# with three overlaps at every angle but zero. A design asked for
	# Voyager hit this, wrote "the rotated sections collide with
	# everything once tipped", and went back to stepped slabs.
	for degrees: float in [15.0, 35.0, 60.0]:
		var pylon := Assistant.Model.new()
		for n: int in 6:
			pylon.placements.append(Assistant.Placement.from_dict(
				{"part": "3001", "color": 4, "x": 0, "y": n * 3,
					"z": 0, "rot": 0, "section": "pylon"}))
		pylon.sections["pylon"] = Assistant.Section.from_dict({
			"name": "pylon", "x": 0.0, "y": 0.0, "z": 0.0,
			"axis": "z", "degrees": degrees})
		var pylon_said: String = str(_assistant._check(pylon)["feedback"])
		# Any overlap at all, because this pylon stands on its own —
		# there is nothing else in the model for it to run into, so an
		# overlap can only be one of its own bricks. Asking only about
		# the words "inside section" was not enough: without the fix
		# the same collision is reported in the section's own wording
		# and the check passed either way.
		_check("at %.0f degrees its own bricks do not collide" % degrees,
			not pylon_said.contains("overlap"))

	print("")
	print("  a brick claiming a section nobody declared")
	var orphan := Assistant.Model.new()
	orphan.placements.append(Assistant.Placement.from_dict(
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0}))
	orphan.placements.append(Assistant.Placement.from_dict(
		{"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0,
			"section": "nowhere"}))
	_check("is caught rather than quietly built square",
		str(_assistant._check(orphan)["feedback"]).contains(
			"not one of the sections given"))

	print("")
	print("  and is forgotten when the model is")
	# These are keyed by brick id and BrickWorld numbers from one again
	# after a clear, so a stale entry would name an ordinary brick
	# placed later — which would then be read back as part of a section
	# that no longer exists, and moved whenever that section moved.
	_assistant.forget_built()
	_check("nothing is left pointing at a brick that has gone",
		_assistant._section_of.is_empty()
			and _assistant._local_of.is_empty()
			and _assistant._sections.is_empty())

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


## The orientation of the first brick the assistant put in a section.
func _first_of_section(world: BrickWorld) -> Basis:
	for brick_id: int in _assistant._section_of:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null:
			return brick.transform.basis
	return Basis.IDENTITY


static func _angle_of(basis: Basis) -> float:
	var up: Vector3 = (basis * Vector3.UP).normalized()
	return rad_to_deg(absf(atan2(up.x, up.y)))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
