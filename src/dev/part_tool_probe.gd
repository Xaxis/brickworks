## The assistant makes a part it needs, and builds with it.
##
##   godot --headless --path . --script src/dev/part_tool_probe.gd
##
## make_part is in the assistant's tool list — and so in every MCP
## session's — with a schema. Called as a design run calls a tool
## (Assistant.use_tool, which the command socket uses too), it makes a
## part the way the dialog does: the same file a person's spec makes, the
## same refusals in the same words for a Technic brick two studs wide, side
## studs on a plate, a family that does not exist, a part with no slice to
## repeat. Then the part is used as any part is: a 1 x 9 Technic brick on
## two 2 x 4s with a pin in a hole, a bracket holding a plate on its
## upright, 3700 made six long with a pin in its fourth hole — each passed
## by check_design, each a stud off refused — and a submitted design with
## the made part in it stands in the world, and the saved file carries it.
##
## Made parts go to user://custom_parts_tool_probe/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://custom_parts_tool_probe/"

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore


func _initialize() -> void:
	_forget_kept()
	CustomParts.dir = PROBE_DIR
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

	print("\nthe tool is offered, with a schema")
	var offered: Dictionary = {}
	for tool: Variant in _assistant.tool_catalogue():
		if str((tool as Dictionary).get("name", "")) == "make_part":
			offered = tool
	var properties: Dictionary = (offered.get("input_schema", {}) as Dictionary).get(
		"properties", {})
	_ok(not offered.is_empty() and properties.has("family") and properties.has("from"),
		"make_part is in the assistant's tools, taking a family or a part to change from")

	print("\nit makes what the dialog makes")
	var said: String = await _call({"family": "technic", "across": 9})
	_ok(said.begins_with("Made part \"bw-h1x9\"") and _library.parts.has("bw-h1x9"),
		"a 1 x 9 Technic brick: %s" % said.left(160))
	var spec := ElementMaker.from_words("family=technic across=9 deep=1 plates=3 studs=yes")
	_ok(_library.custom_source("bw-h1x9") == ElementMaker.dat(spec, "bw-h1x9"),
		"...the very file the dialog's spec makes")
	_ok(FileAccess.file_exists(PROBE_DIR + "bw-h1x9.dat"), "...and kept, as a person's part is")
	_ok(said.contains("8 Technic holes through it") and said.contains("Footprint 9 x 1 studs (x by z), 3 plates tall"),
		"...and said in a design's terms: its footprint and its 8 holes")
	said = await _call({"family": "bracket", "across": 2, "deep": 1, "rise": 1, "way": "down"})
	_ok(said.begins_with("Made part \"bw-k1x2x1d\"") and said.contains("on its +z face")
			and said.contains("2.5 plates tall"),
		"a bracket, its upright's studs said to face +z, its height 2.5 plates: %s"
			% said.left(240))
	said = await _call({"family": "brick", "across": 4, "deep": 1, "plates": 3, "sides": "f",
		"name": "Brick 1 x 4 for the headlights"})
	_ok(said.contains("\"Brick 1 x 4 for the headlights\"") or said.contains("headlights"),
		"a brick with studs on its side, named as asked: %s" % said.left(140))
	said = await _call({"from": "3700", "across": 6})
	_ok(said.begins_with("Made part \"bw-3700-l6\"") and said.contains("5 Technic holes"),
		"3700 changed to six long, its own holes repeated: %s" % said.left(140))

	print("\nit refuses what a person is refused, in the same words")
	for refused: Array in [
			[{"family": "technic", "across": 4, "deep": 2}, "one stud wide"],
			[{"family": "brick", "across": 2, "deep": 1, "plates": 1, "sides": "f"},
				"at least a brick (3 plates) tall"],
			[{"family": "wing", "across": 2}, "no family called wing"],
			[{"from": "3062b", "across": 3}, "no 20 LDU slice"],
			[{"from": "99999zz"}, "no part 99999zz"]]:
		said = await _call(refused[0])
		_ok(said.begins_with("Not made") and said.contains(str(refused[1])),
			"%s: %s" % [JSON.stringify(refused[0]), said.left(160)])

	print("\nand what it made is a part to build with")
	_judge("the 1 x 9 Technic brick on two 2 x 4s, a pin in its first hole", true, [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3001", "color": 4, "x": 5, "y": 0, "z": 0, "rot": 0},
		{"part": "bw-h1x9", "color": 1, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "3673", "color": 0, "x": 0.6, "y": 3.75, "z": -0.5, "face": "up", "rot": 1},
	])
	_judge("...and the pin a stud along, between the holes, is not", false, [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3001", "color": 4, "x": 5, "y": 0, "z": 0, "rot": 0},
		{"part": "bw-h1x9", "color": 1, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "3673", "color": 0, "x": 1.1, "y": 3.75, "z": -0.5, "face": "up", "rot": 1},
	])
	_judge("the bracket holding a 1 x 2 plate on its upright", true, [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "bw-k1x2x1d", "color": 4, "x": 0, "y": 1.5, "z": 1, "rot": 0},
		{"part": "3023", "color": 15, "x": 0, "y": 1.5, "z": 2.2, "face": "+z", "rot": 0},
	])
	_judge("3700 made six long, a pin in its fourth hole", true, [
		{"part": "bw-3700-l6", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3673", "color": 0, "x": 3.6, "y": 0.75, "z": -0.5, "face": "up", "rot": 1},
	])

	print("\nsubmitted, it stands in the world, and the saved file carries it")
	var answer: Variant = await _assistant.use_tool("submit_design", {
		"name": "made parts", "description": "a Technic beam of a made brick",
		"bricks": [
			{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 4, "x": 5, "y": 0, "z": 0, "rot": 0},
			{"part": "bw-h1x9", "color": 1, "x": 0, "y": 3, "z": 0, "rot": 0},
		],
		"assemblies": [{"name": "beam", "x_from": 0, "x_to": 9, "z_from": 0, "z_to": 2}],
	})
	var standing: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "bw-h1x9":
			standing += 1
	_ok(standing == 1, "the design stands, the made brick in it (%s)"
		% str(answer).left(120).replace("\n", " "))
	var text: String = _store.to_text("made parts", true)
	_ok(text.contains("0 FILE bw-h1x9.dat") and text.contains("Technic Brick  1 x  9"),
		"the saved file carries bw-h1x9.dat")

	_forget_kept()
	print("")
	if _failures == 0:
		print("the assistant makes the part it needs, and builds with it")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _call(args: Dictionary) -> String:
	var answer: Variant = await _assistant.use_tool("make_part", args)
	return str(answer)


func _judge(what: String, want_ok: bool, bricks: Array) -> void:
	var answer: Variant = await _assistant.use_tool("check_design", {"bricks": bricks})
	var text: String = ""
	if answer is Array:
		for block: Variant in answer:
			if block is Dictionary and (block as Dictionary).get("type", "") == "text":
				text += str((block as Dictionary)["text"])
	else:
		text = str(answer)
	var model := Assistant.Model.new()
	for raw: Variant in bricks:
		model.placements.append(Assistant.Placement.from_dict(raw))
	var verdict: Dictionary = _assistant._check(model, true)
	var got: bool = bool(verdict["ok"])
	_ok(got == want_ok, "%s — %s%s" % [what, verdict["summary"], "" if got == want_ok
		else ": " + str(verdict["feedback"]).left(300).replace("\n", " / ")])


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _forget_kept() -> void:
	if not DirAccess.dir_exists_absolute(PROBE_DIR):
		return
	for name: String in DirAccess.get_files_at(PROBE_DIR):
		DirAccess.remove_absolute(PROBE_DIR + name)
	DirAccess.remove_absolute(PROBE_DIR)
