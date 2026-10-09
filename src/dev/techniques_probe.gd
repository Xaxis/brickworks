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

		var model := Assistant.Model.new()
		for raw: Variant in technique["bricks"]:
			model.placements.append(Assistant.Placement.from_dict(raw))
		var verdict: Dictionary = assistant._check(model)
		if not bool(verdict["ok"]):
			_fail("%s does not build: %s" % [name, verdict["summary"]])
			print("        " + str(verdict["feedback"]).replace(
				"\n", " ").substr(0, 200))
			continue

		# And it says what it is for. A construction with no "when" is a
		# puzzle rather than an answer.
		if str(technique.get("when", "")).length() < 20:
			_fail("%s does not say when to use it" % name)
			continue
		if str(technique.get("why", "")).length() < 40:
			_fail("%s does not say why it works" % name)
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
	# The prompt's fill table used to send a round tower to an ellipse,
	# which is where the 354 1x1 bricks came from. Both halves asserted:
	# the technique exists under a findable name, and the table no longer
	# offers a tower as something to fill.
	_check("a wide round tower is a technique you can look up",
		not Techniques.named("wide round tower").is_empty())
	_check("...and the fill table does not offer a tower instead",
		not assistant.guidance().contains("a round tower   ellipse"))
	_check("...and says what to call for instead",
		assistant.guidance().contains("wide round tower"))

	_check("there are enough of them to be worth having",
		Techniques.names().size() >= 6)

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
