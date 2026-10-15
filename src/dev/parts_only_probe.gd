## Does a run kept to a list of parts keep to it, and does every other run not notice?
##
##   godot --headless --path . --script src/dev/parts_only_probe.gd
##   godot --headless --path . --script src/dev/parts_only_probe.gd -- --parts-only=FILE
##
## BrickBench allows only BrickNet's parts, and tools/bench/brickbench.py
## designs with --parts-only=FILE (src/parts/parts_only.gd). This checks
## the places a design chooses or lays a part: search_parts lists only parts
## on the list and says how many it left out; a design with a part off it is
## refused, naming the part; add_minifig chooses only parts on it and
## refuses a figure that needs one off it; make_part, lay_flex and
## print_part are refused; and a part off the list left on the model is
## said after any call. First without a list, where none of that happens.
##
## With the flag it checks the file was read: its count and its name.
extends SceneTree

## A part on BrickNet's list (3001, brick 2 x 4) and one that is not:
## 60602, the glass for window 1 x 2 x 3, which BrickNet leaves out.
const ON := "3001"
const OFF := "60602"
## A number LDraw has moved: "~Moved to 3023b", which BrickNet lists.
const MOVED := "3023"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var flagged: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(PartsOnly.FLAG):
			flagged = argument.trim_prefix(PartsOnly.FLAG)
	if not flagged.is_empty():
		_the_flag(flagged)
		_finish("the flag's list was read")
		return

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

	print("without a list, nothing changes")
	PartsOnly.use(PackedStringArray())
	_ok(not PartsOnly.active() and PartsOnly.allows(OFF), "every part is allowed")
	_ok(assistant._search("glass for window 1 x 2 x 3", 15).contains(OFF),
		"search_parts lists %s" % OFF)
	_ok(not assistant._search("glass for window 1 x 2 x 3", 15).contains("Not listed"),
		"and says nothing of a list")
	_ok(not str(_checked(assistant, [ON, OFF])["feedback"]).contains("not among"),
		"a design with %s is checked as ever" % OFF)
	_ok(PartsOnly.tool_refusal("lay_flex").is_empty(), "lay_flex is not refused")
	_ok(FigureTool.choose(library, "headwear", "wizard hat") != "?", "a figure gets a wizard's hat")
	world.add_brick(OFF, 47, Transform3D(Basis.IDENTITY, Vector3(0, -24, 0)))
	_ok(PartsOnly.on_model(world, {}, library).is_empty(), "and the model is not remarked on")
	world.clear()

	print("\nkept to a list")
	# A plain figure's own parts but its last, with a brick, a plate and a window.
	var plain: PackedStringArray = (FigureTool.figure_for({"name": "Wizard"}, library)[0]
		as Minifig).part_ids(library)
	var missing: String = plain[plain.size() - 1]
	var listed := PackedStringArray([ON, "3003", "60592"]) + plain.slice(0, plain.size() - 1)
	PartsOnly.use(listed, "the probe's list")
	_ok(PartsOnly.active() and PartsOnly.allows(ON) and not PartsOnly.allows(OFF),
		"%s is allowed and %s is not" % [ON, OFF])
	var found: String = assistant._search("glass for window 1 x 2 x 3", 15)
	_ok(not found.contains(OFF + " ") and not found.begins_with(OFF),
		"search_parts does not list %s" % OFF)
	_ok(found.contains("the probe's list"), "and says it left some out, and why: %s"
		% found.get_slice("\n", found.get_slice_count("\n") - 1).left(120))
	_ok(assistant._search("brick 2 x 4", 15).contains(ON), "it still lists %s" % ON)
	var good: Dictionary = _checked(assistant, [ON])
	_ok(bool(good["ok"]), "a design of %s alone is not refused (%s)" % [ON, good["summary"]])
	var bad: Dictionary = _checked(assistant, [ON, OFF])
	_ok(not bool(bad["ok"]) and str(bad["feedback"]).contains("not among this run's parts")
		and str(bad["feedback"]).contains(OFF) and str(bad["feedback"]).contains("swap"),
		"a design with %s is refused, naming it and asking for a swap" % OFF)
	# A number LDraw moved is the part it moved to: the generators lay 3023,
	# BrickNet lists 3023b, and a fill of 1 x 2 plates is not refused for it.
	PartsOnly.use(listed + PackedStringArray(["3023b"]), "the probe's list")
	_ok(PartsOnly.allows(MOVED, library) and not PartsOnly.allows(MOVED),
		"%s, moved to 3023b, is allowed by what it moved to" % MOVED)
	var filled: Dictionary = _checked_pattern(assistant, {"pattern": "fill",
		"at": {"x": 0, "y": 0, "z": 0}, "shape": "rectangle", "across": 1, "deep": 2, "color": 4})
	_ok(not str(filled["feedback"]).contains("not among"),
		"a fill laid in %s is not refused (%s)" % [MOVED, str(filled["summary"]).left(80)])
	PartsOnly.use(listed, "the probe's list")
	for tool: String in ["make_part", "lay_flex", "print_part"]:
		_ok(not PartsOnly.tool_refusal(tool).is_empty(), "%s is refused" % tool)
	_ok(PartsOnly.tool_refusal("edit_model").is_empty(), "edit_model is not")
	_ok(FigureTool.choose(library, "headwear", "wizard hat") == "?",
		"a figure gets no wizard's hat, which is off the list")
	_ok(FigureTool.choose(library, "torso", "plain") == "973", "and a plain torso, which is on it")
	var stood: Dictionary = await FigureTool.add({"name": "Wizard", "x": 0, "z": 0},
		library, world, builder)
	_ok(not bool(stood["ok"]) and str(stood["text"]).contains(missing)
		and world.brick_count() == 0,
		"a figure with a part off the list (%s) is not placed: %s" % [missing, str(stood["text"]).left(90)])
	listed.append(missing)
	PartsOnly.use(listed, "the probe's list")
	stood = await FigureTool.add({"name": "Wizard", "x": 0, "z": 0, "torso": "973pa1"},
		library, world, builder)
	var torsos: Array = world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id.begins_with("973"))
	_ok(bool(stood["ok"]) and torsos.size() == 1 and (torsos[0] as BrickWorld.Brick).part_id == "973",
		"asked for a torso off the list (973pa1), a figure stands in a plain one: %s"
			% str(stood["text"]).left(90))
	world.add_brick(ON, 4, Transform3D(Basis.IDENTITY, Vector3(0, -24, 0)))
	_ok(PartsOnly.on_model(world, {}, library).is_empty(), "a model of listed parts is not remarked on")
	var off_id: int = world.add_brick(OFF, 47, Transform3D(Basis.IDENTITY, Vector3(80, -24, 0)))
	var said: String = PartsOnly.on_model(world, {}, library)
	_ok(said.contains(OFF) and said.contains("#%d" % off_id) and said.contains("Swap"),
		"one off it on the model is said, with its number: %s" % said.left(100))
	_ok(PartsOnly.on_model(world, {off_id: true}, library).is_empty(),
		"unless it is the floor, which is not the design's")

	print("\nthe list's file")
	var read: Array = PartsOnly.read_list("# BrickNet's parts\n3001\n\n# a note\n3023B\n")
	_ok((read[0] as Dictionary).size() == 2 and (read[0] as Dictionary).has("3023b")
		and str(read[1]) == "BrickNet's parts", "parts a line, notes skipped, the first note names it")
	PartsOnly.use(PackedStringArray())
	_finish("a run kept to a list keeps to it, and one without a list is as it was")


func _the_flag(path: String) -> void:
	var read: Array = PartsOnly.read_list(FileAccess.get_file_as_string(path))
	var wanted: int = (read[0] as Dictionary).size()
	print("the flag: %s, %d parts" % [path, wanted])
	_ok(PartsOnly.active(), "the run is kept to a list")
	_ok(wanted > 0 and PartsOnly.named() == str(read[1]), "named \"%s\"" % PartsOnly.named())
	var allowed: int = 0
	for part_id: String in (read[0] as Dictionary):
		allowed += int(PartsOnly.allows(part_id))
	_ok(allowed == wanted, "all %d of its parts are allowed" % wanted)
	_ok(not PartsOnly.allows("no-such-part"), "and a part not on it is not")


## One brick of each part, side by side on the ground, checked as a design.
func _checked(assistant: Assistant, parts: Array) -> Dictionary:
	var model := Assistant.Model.new()
	for n: int in parts.size():
		model.placements.append(Assistant.Placement.from_dict({
			"part": parts[n], "color": 4, "x": n * 6, "y": 0, "z": 0}))
	return assistant._check(model, true)


## One pattern alone, checked as a design.
func _checked_pattern(assistant: Assistant, pattern: Dictionary) -> Dictionary:
	return assistant._check(assistant._read_model({"patterns": [pattern], "bricks": []}), true)


func _finish(sentence: String) -> void:
	print("")
	if _failures == 0:
		print(sentence)
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, label: String) -> void:
	if condition:
		print("    ok   " + label)
	else:
		_failures += 1
		print("    FAIL " + label)
