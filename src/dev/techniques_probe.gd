## Does every construction in the library actually build?
##
##   godot --headless --path . --script src/dev/techniques_probe.gd
##
## The library tells a design how to do the things the prompt asks of it
## — stagger a wall, turn a face sideways, make a diagonal that is not a
## staircase — in part numbers and coordinates, because "how" in this
## system is a part number and four numbers after it.
##
## A library of constructions that do not hold together would be worse
## than none: a design that followed one and was refused would learn that
## the technique does not work here, and go back to stacking bricks
## studs-up. So every entry is built against the same lattice a design is
## checked against, and this fails if any of them is refused.
extends SceneTree

var _failures: int = 0


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
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame

	print("  every construction in the library")
	for one: Variant in Techniques.all():
		var technique: Dictionary = one
		var name: String = str(technique["name"])

		# Every part of it is a part that exists. A technique naming a
		# number nobody has is a technique nobody can follow.
		var missing := PackedStringArray()
		for raw: Variant in technique["bricks"]:
			var part: String = str((raw as Dictionary)["part"])
			if not library.parts.has(part):
				missing.append(part)
		if not missing.is_empty():
			_fail("%s names a part that does not exist: %s"
				% [name, ", ".join(missing)])
			continue

		# Read as a design's own words are, so a section's hinge is laid and
		# a repeat is said again. Turned as it says, where it says: an angled
		# construction is a section, and built without one it is a different
		# construction.
		var model: Assistant.Model = assistant._read_model({"bricks": technique["bricks"],
			"sections": technique.get("sections", []),
			"repeat_section": technique.get("repeat_section", [])})
		var verdict: Dictionary = assistant._check(model)
		if not bool(verdict["ok"]):
			_fail("%s does not build: %s" % [name, verdict["summary"]])
			print("        " + str(verdict["feedback"]).replace(
				"\n", " ").substr(0, 200))
			# The one cause that is not the technique's: a turntable, a
			# hinge or a clip needs the catalogue's shafts and bores, and
			# a catalogue built before them reads every one as an overlap.
			var base: PartLibrary.PartInfo = library.parts.get("3680")
			if base != null and not base.has_connector("bore"):
				print("        the catalogue has no shafts or bores: it predates "
					+ "them, and needs tools/build_meshes.py run again")
			continue

		# And stood on a floor, as add_rooms stands it, it is on the floor's
		# studs. Read off real sets, the potion shelf, the campfire and the
		# rocky ground each came out a tenth or two of a stud off the grid
		# as a whole, which on the baseplate nothing measures and on a
		# room's floor is a part off its studs.
		var lifted_bricks: Array = [{"part": "91405", "color": 72, "x": -6, "y": 0,
			"z": -6, "rot": 0}]
		for raw: Variant in technique["bricks"]:
			var lifted: Dictionary = (raw as Dictionary).duplicate()
			if str(lifted.get("section", "")).is_empty():
				lifted["y"] = float(lifted["y"]) + 1.0
			lifted_bricks.append(lifted)
		var lifted_sections: Array = []
		for raw: Variant in technique.get("sections", []):
			var lifted: Dictionary = (raw as Dictionary).duplicate()
			if str(lifted.get("within", "")).is_empty():
				lifted["y"] = float(lifted["y"]) + 1.0
			lifted_sections.append(lifted)
		var floored: Assistant.Model = assistant._read_model({"bricks": lifted_bricks,
			"sections": lifted_sections,
			"repeat_section": technique.get("repeat_section", [])})
		var on_floor: String = str(assistant._check(floored)["feedback"])
		if on_floor.contains("off its studs"):
			_fail("%s stood on a floor is off its studs: %s" % [name,
				on_floor.substr(on_floor.find("off its studs"), 220).replace("\n", " ")])
			continue

		# And it says what it is for. A construction with no "when" is a
		# puzzle rather than an answer.
		if str(technique.get("when", "")).length() < 20:
			_fail("%s does not say when to use it" % name)
			continue
		if str(technique.get("why", "")).length() < 40:
			_fail("%s does not say why it works" % name)
			continue
		# Found by what it is for, or it is one more name in a list of
		# sixty that a design looking for a roof has to read through.
		if not Techniques.GROUPS.has(str(technique.get("group", ""))):
			_fail("%s is in no group show_technique lists" % name)
			continue
		# A real set's construction says whose it is: the repository's
		# licence asks for the modeller's name, and the set is the
		# evidence that LEGO builds it this way.
		var why: String = str(technique["why"])
		if why.contains("model repository") and not (why.contains("model by ")
				and why.contains("CC BY") and why.contains("As the LEGO Group built it in ")):
			_fail("%s is from a real set and does not credit it" % name)
			continue
		print("  ok    %-22s %d parts, %s" % [name,
			model.placements.size(), verdict["summary"]])

	print("")
	print("  and they can be found by name")
	_check("an exact name finds it",
		str(Techniques.named("round tower").get("name", "")) == "round tower")
	# Half a name, because a design that remembers "wedge" should not be
	# told nothing exists.
	_check("a partial name finds it",
		not Techniques.named("diagonal").is_empty())
	_check("a name nobody has finds nothing",
		Techniques.named("hyperdrive").is_empty())
	# Whole words, not letters: "street lamp" has "tree" in it.
	_check("a name inside the question, as words: \"street lamp\" is not the tree",
		str(Techniques.named("street lamp").get("name", "")) != "tree")
	# Read back name by name, not searched for: "bed" is inside
	# "four-poster bed", so a substring test passes with it missing.
	var listed := PackedStringArray()
	for group: String in Techniques.listing().split("; "):
		listed.append_array(group.get_slice(": ", 1).split(", "))
	var unlisted := PackedStringArray()
	var seen: Dictionary = {}
	for name: String in Techniques.names():
		if not listed.has(name):
			unlisted.append(name)
		seen[name] = int(seen.get(name, 0)) + 1
	_check("every one is in the grouped list show_technique offers%s"
		% ("" if unlisted.is_empty() else ": not " + ", ".join(unlisted)),
		unlisted.is_empty())
	_check("and no two share a name", seen.size() == Techniques.names().size())
	# What a design actually reads: the tool's answer when it names
	# nothing, and the tool's own description.
	var offered: String = assistant._show_technique("")
	_check("asked for nothing, show_technique answers by group",
		offered.contains("walls and stone: ") and offered.contains("plants: "))
	var described: String = ""
	for tool: Variant in assistant._tools():
		if str((tool as Dictionary).get("name", "")) == "show_technique":
			described = str((tool as Dictionary)["description"])
	_check("...and its description lists them by group too",
		described.contains("furniture and interiors: ") and described.contains("bookcase"))
	_check("asked for one, it gets the parts: \"a castle bookcase\"",
		assistant._show_technique("a castle bookcase").contains("87087"))
	# The prompt's fill table used to send a round tower to an ellipse,
	# which is where the 354 1x1 bricks came from. Both halves asserted:
	# the technique exists under a findable name, and the table no longer
	# offers a tower as something to fill.
	_check("a wide round tower is a technique you can look up",
		not Techniques.named("wide round tower").is_empty())
	_check("...and the fill table does not offer a tower instead",
		not assistant.guidance().contains("a round tower   ellipse"))
	# Read with its line breaks' indents folded, as the model reads it.
	var flat: String = " ".join(assistant.guidance().split(" ", false))
	_check("...and says what to call for instead: the round pattern",
		flat.contains("A round tower is the round pattern"))
	# And the example is a ring: its four corner rounds were turned as a bow
	# tie for a year, and it stacked and checked just the same.
	var ring: Dictionary = Techniques.named("wide round tower")
	var leans := PackedStringArray()
	for raw: Variant in ring.get("bricks", []):
		var brick: Dictionary = raw
		if str(brick["part"]) != "48092" or float(brick["y"]) != 0.0:
			continue
		var mesh: Lbm.PartMesh = library.mesh_for("48092")
		var lean: Vector2 = Rounds.lean(mesh, int(brick["rot"]))
		# Out of the ring: away from its middle at (4, 4).
		var out := Vector2(signf(float(brick["x"]) - 3.5), signf(float(brick["z"]) - 3.5))
		leans.append("ok" if lean == out else "in")
	_check("...and its four corner rounds each curve out of the ring: %s" % ", ".join(leans),
		leans.size() == 4 and not leans.has("in"))

	_check("there are enough of them to be worth having",
		Techniques.names().size() >= 6)

	# A face built as features, each a part, and each feature one piece: the
	# held-out owl's face was a panel of white 1 x 1 tiles with 1 x 1 dots for
	# eyes and a tan tile for a beak, because nothing said how a designer
	# builds an eye. One piece, or a feature followed falls off its face.
	print("")
	print("  and a face is built as features")
	var features: PackedStringArray = []
	for one: Variant in Techniques.all():
		var technique: Dictionary = one
		if str(technique.get("group", "")) != "faces and features":
			continue
		var model := Assistant.Model.new()
		var parts: Dictionary = {}
		for raw: Variant in technique["bricks"]:
			model.placements.append(Assistant.Placement.from_dict(raw))
			parts[str((raw as Dictionary)["part"])] = true
		var verdict: Dictionary = assistant._check(model, true)
		features.append(str(technique["name"]))
		_check("%s: %d parts, %d shapes, %s, %d piece(s)" % [technique["name"],
			model.placements.size(), parts.size(), verdict["summary"], int(verdict["pieces"])],
			bool(verdict["ok"]) and int(verdict["pieces"]) == 1)
	_check("...eyes, a round face, a beak, ears, talons and a vehicle's lamps: %s"
		% ", ".join(features), features.size() >= 6 and features.has("eye with a highlight")
			and features.has("round face") and features.has("talons")
			and features.has("headlamps and grille"))
	var eye: Dictionary = Techniques.named("eye")
	var eye_parts: Array = (eye.get("bricks", []) as Array).map(
		func(brick: Dictionary) -> String: return str(brick["part"]))
	_check("an eye is a round plate and a printed pupil with its highlight, not a dot: %s"
		% ", ".join(PackedStringArray(eye_parts)), eye_parts.has("18674")
			and eye_parts.has("98138p07"))
	_check("...and the guidance sends a face to them, and away from a grid of tiles",
		flat.contains("show_technique \"eye with a highlight\"")
			and flat.contains("(\"round face\")") and flat.contains("pixel picture"))

	# A pane in its frame is forgiven its overlap only where real sets
	# seat it. A rule that let glass pass through anything would let
	# every technique above pass too, so the same window with its pane
	# a plate too high has to be refused.
	print("")
	print("  and an insert is forgiven only in its seat")
	var window: Dictionary = Techniques.named("window in a wall")
	var high := Assistant.Model.new()
	var panes: int = 0
	for raw: Variant in window["bricks"]:
		var put: Assistant.Placement = Assistant.Placement.from_dict(raw)
		if put.part == "60602":
			put.y += 1
			panes += 1
		high.placements.append(put)
	var refused: Dictionary = assistant._check(high)
	_check("a pane a plate above its seat is an overlap: %s"
		% refused["summary"], panes == 1 and not bool(refused["ok"])
			and str(refused["summary"]).contains("overlap"))
	var door: Dictionary = Techniques.named("door in a wall")
	var wide := Assistant.Model.new()
	for raw: Variant in door["bricks"]:
		var put: Assistant.Placement = Assistant.Placement.from_dict(raw)
		if put.part == "60623":
			put.x += 0.5
		wide.placements.append(put)
	var swung: Dictionary = assistant._check(wide)
	_check("...and a door half a stud along its frame: %s"
		% swung["summary"], not bool(swung["ok"])
			and str(swung["summary"]).contains("overlap"))

	print("")
	if _failures == 0:
		print("every technique in the library builds")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_fail(what)


func _fail(what: String) -> void:
	_failures += 1
	print("  FAIL  %s" % what)
