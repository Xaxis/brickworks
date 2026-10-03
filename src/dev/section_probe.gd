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
	print("  a tipped section that does not quite fit")
	# The window where a turned section touches without digging in is
	# one quarter of a plate wide — overlap below it, open air above.
	# Nothing finds that by reasoning. Three designs tried an angled
	# pylon, were told it ran into the hull, lifted it a whole plate,
	# were told it was adrift, and concluded an angled pylon could not
	# be attached in this system at all. One wrote exactly that.
	for lift: float in [3.0, 3.5]:
		var pylon := Assistant.Model.new()
		for n: int in 4:
			pylon.placements.append(Assistant.Placement.from_dict(
				{"part": "3001", "color": 7, "x": n * 4, "y": 0,
					"z": 0, "rot": 0}))
		for n: int in 4:
			pylon.placements.append(Assistant.Placement.from_dict(
				{"part": "3001", "color": 4, "x": 0, "y": n * 3,
					"z": 0, "rot": 0, "section": "pylon"}))
		pylon.sections["pylon"] = Assistant.Section.from_dict({
			"name": "pylon", "x": 2.0, "y": lift, "z": 0.0,
			"axis": "z", "degrees": 20.0})
		var told: String = str(_assistant._check(pylon)["feedback"])
		# The height it names, rather than the sentence it names it in:
		# the sentence has been reworded once already, because "rest
		# against" read as a rule about gravity and cost a design its
		# angled nacelles.
		_check("at y=%.1f it is told where it would fit" % lift,
			told.contains(" At y=") and told.contains("meets the model"))

	# Told from further away than a plate, too. One plate of reach was
	# not enough: a section declared well below where it fits was told
	# nothing at all, which reads as "there is nowhere" and is the
	# answer that ends runs.
	var distant := Assistant.Model.new()
	for n: int in 4:
		distant.placements.append(Assistant.Placement.from_dict(
			{"part": "3001", "color": 7, "x": n * 4, "y": 0, "z": 0,
				"rot": 0}))
	for n: int in 4:
		distant.placements.append(Assistant.Placement.from_dict(
			{"part": "3001", "color": 4, "x": 0, "y": n * 3, "z": 0,
				"rot": 0, "section": "pylon"}))
	distant.sections["pylon"] = Assistant.Section.from_dict({
		"name": "pylon", "x": 2.0, "y": 1.5, "z": 0.0,
		"axis": "z", "degrees": 20.0})
	var far_off: Dictionary = _assistant._check(distant)
	_check("a section far from where it fits is still told",
		str(far_off["feedback"]).contains(" At y=")
			and str(far_off["feedback"]).contains("meets the model"))
	# And the advice is not itself counted as a fault. It was added with
	# the same call that records a problem, and every one of those is
	# counted — so the one thing here trying to help was reported as a
	# second problem.
	_check("and the advice is not counted as a problem, %s"
		% str(far_off["summary"]),
		str(far_off["summary"]).begins_with("1 problem"))

	# And that the place it names actually works.
	var fitted := Assistant.Model.new()
	for n: int in 4:
		fitted.placements.append(Assistant.Placement.from_dict(
			{"part": "3001", "color": 7, "x": n * 4, "y": 0, "z": 0,
				"rot": 0}))
	for n: int in 4:
		fitted.placements.append(Assistant.Placement.from_dict(
			{"part": "3001", "color": 4, "x": 0, "y": n * 3, "z": 0,
				"rot": 0, "section": "pylon"}))
	fitted.sections["pylon"] = Assistant.Section.from_dict({
		"name": "pylon", "x": 2.0, "y": 3.25, "z": 0.0,
		"axis": "z", "degrees": 20.0})
	_check("and a tipped section really can be attached",
		bool(_assistant._check(fitted)["ok"]))

	# And once it is standing, it can be measured by name.
	#
	# A section is the thing a designer thinks in — the saucer, the port
	# nacelle, the neck — and the questions that matter are about them
	# and not about the box round everything: do the two nacelles match
	# each other, is the saucer wider than the hull is long. A render
	# cannot answer either.
	print("")
	print("  a named part of the model, measured on its own")
	_assistant._apply(fitted)
	var measured: String = _assistant._measured()
	_check("the section is named: %s" % measured.split("\n")[-1].strip_edges(),
		measured.contains("pylon"))
	# Four 2x4s stacked is 4 studs across and 12 plates tall as it was
	# built. Tipped twenty degrees it leans, so its box is wider and
	# taller than that — 5.5 and 15 — and those are the numbers that
	# say whether it clears the hull. Measuring it in its own square
	# coordinates would say 4 and 12 and be useless for that.
	var leaning: PackedStringArray = PackedStringArray()
	for line: String in measured.split("\n"):
		if line.strip_edges().begins_with("pylon"):
			leaning.append(line)
	var across: float = 0.0
	var plates: float = 0.0
	if not leaning.is_empty():
		var words: PackedStringArray = leaning[0].split(" ", false)
		across = words[1].to_float()
		for n: int in words.size():
			if words[n].begins_with("plates"):
				plates = words[n - 1].to_float()
	_check("...and measured as it is carried, not as it was built: "
		+ "%s across and %s plates, against 4 and 12 built square"
		% [Assistant.Placement._num(across),
			Assistant.Placement._num(plates)],
		across > 4.5 and plates > 12.5)
	_assistant.forget_built()
	world.clear()
	builder.lattice.clear()

	# And the rule is written down rather than left to be discovered.
	#
	# A real design run spent eight checks probing it: "still working
	# through the checker's support rules... now testing whether a whole
	# sub-assembly can be a section held by touch". The answer is yes
	# and always was. Eight checks is most of the turns a design has.
	# And a check with several failing sections comes back at all.
	#
	# Measured before this was bounded: one failing section cost 46
	# seconds of sweeping, two 82, four 182 — and the relay a session
	# talks through gives up at 180. A starship has four candidates,
	# two pylons and two nacelles, and a real run reported "the
	# brickworks server has stopped responding" on every call after one
	# edit while it was still fighting its pylons. The app was alive the
	# whole time; the check was not coming back.
	print("")
	print("  a check with four failing sections comes back")
	var crowd := Assistant.Model.new()
	for n: int in 60:
		crowd.placements.append(Assistant.Placement.from_dict({
			"part": "3001", "color": 7,
			"x": (n % 10) * 4, "y": (n / 10) * 3, "z": 0}))
	for pylon: int in 4:
		var named: String = "pylon%d" % pylon
		for n: int in 4:
			crowd.placements.append(Assistant.Placement.from_dict({
				"part": "3001", "color": 4, "x": 0, "y": n * 3, "z": 0,
				"section": named}))
		# High in the air on purpose: nothing within the sweep's reach,
		# which is the case that costs the most.
		crowd.sections[named] = Assistant.Section.from_dict({
			"name": named, "x": 4.0 + float(pylon) * 8.0, "y": 30.0,
			"z": 0.0, "axis": "z", "degrees": 40.0})
	var began: float = Time.get_unix_time_from_system()
	var crowded: Dictionary = _assistant._check(crowd)
	var took: float = Time.get_unix_time_from_system() - began
	_check("four of them are all reported, %s" % str(crowded["summary"]),
		not bool(crowded["ok"]))
	if took < 30.0:
		print("  ok    ...and it took %.1f s, against the 182 it used to "
			% took + "and the 180 the relay waits")
	else:
		_failures += 1
		print("  FAIL  it took %.0f s — the relay gives up at 180, so a "
			% took + "design gets no answer at all")

	print("")
	print("  and the rule is stated, not left to be found by experiment")
	var rules: String = _assistant.guidance()
	_check("support inside a section is said to be ordinary",
		rules.contains("in that section's own square coordinates"))
	_check("...and that a whole sub-assembly can be one section",
		rules.contains("whole nacelle, a whole saucer"))
	_check("...and that nothing need be underneath it",
		rules.contains("Nothing has to be"))

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

	# A pylon four bricks tall, which is what a nacelle hangs off.
	#
	# A design asked for Voyager built one, decided that "a hinged
	# section has to rest on something, not just touch the side", and
	# threw its angled nacelles away for a stack of square bricks. That
	# conclusion is wrong, and this is here to keep it wrong: a pylon of
	# real height holds together from twenty degrees to eighty, and the
	# bricks above the first are not called floating at any of them.
	#
	# At ninety it is adrift, and correctly — laid flat from that origin
	# it no longer reaches the hull — and the message says which height
	# would meet it. That is the answer the Voyager design misread as a
	# rule about resting.
	# On a bare baseplate, so what comes back is about the pylon and not
	# about whatever the checks above left standing.
	world.clear()
	builder.lattice.clear()
	_assistant.forget_built()
	await process_frame

	print("")
	print("  a pylon tall enough to carry something")
	for angle: float in [20.0, 35.0, 55.0, 70.0, 80.0, 90.0]:
		var pylon := Assistant.Model.new()
		for raw: Variant in [
				{"part": "3001", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3001", "color": 71, "x": 4, "y": 0, "z": 0, "rot": 0},
				{"part": "3001", "color": 71, "x": 0, "y": 0, "z": 2, "rot": 0},
				{"part": "3001", "color": 71, "x": 4, "y": 0, "z": 2, "rot": 0},
				{"part": "3010", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0,
					"section": "pylon"},
				{"part": "3010", "color": 71, "x": 0, "y": 3, "z": 0, "rot": 0,
					"section": "pylon"},
				{"part": "3010", "color": 71, "x": 0, "y": 6, "z": 0, "rot": 0,
					"section": "pylon"},
				{"part": "3010", "color": 71, "x": 0, "y": 9, "z": 0, "rot": 0,
					"section": "pylon"}]:
			pylon.placements.append(Assistant.Placement.from_dict(raw))
		pylon.sections["pylon"] = Assistant.Section.from_dict({
			"name": "pylon", "x": 6.0, "y": 3.25, "z": 2.0,
			"axis": "z", "degrees": angle})
		var held: Dictionary = _assistant._check(pylon)
		_check("a four-brick pylon at %d degrees is not called floating: %s"
			% [int(angle), held["summary"]],
			not str(held["feedback"]).contains("floating"))
		# And up to eighty it is a design that could be built as it
		# stands, not merely one that was not complained about.
		if int(angle) < 90:
			_check("  ...and holds together at %d" % int(angle),
				bool(held["ok"]))



	# And what it says when a section really is adrift, because the
	# wording is what a design acts on. "It would rest against the
	# model" was the old hint, and a model asked for Voyager read that
	# as a rule about gravity, decided a hinged section must sit on
	# something, and rebuilt its angled pylons as square stacks.
	var loose := Assistant.Model.new()
	for raw: Variant in [
			{"part": "3001", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3010", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0,
				"section": "pylon"},
			{"part": "3010", "color": 71, "x": 0, "y": 3, "z": 0, "rot": 0,
				"section": "pylon"}]:
		loose.placements.append(Assistant.Placement.from_dict(raw))
	loose.sections["pylon"] = Assistant.Section.from_dict({
		"name": "pylon", "x": 20.0, "y": 20.0, "z": 20.0,
		"axis": "z", "degrees": 35.0})
	var told: String = str(_assistant._check(loose)["feedback"])
	print("")
	print("  what a section adrift is told")
	_check("it is told it is adrift", told.contains("not touching anything"))
	_check("...that touching anywhere counts, in any direction",
		told.contains("any direction"))
	_check("...and that nothing need be underneath it",
		told.contains("needs nothing underneath"))
	_check("...and nothing in it reads as a rule about resting",
		not told.contains("rest"))

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
