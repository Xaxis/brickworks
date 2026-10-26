## The feature pass offers a piece only of the kind the feature names.
##
##   godot --headless --path . --script src/dev/feature_kinds_probe.gd
##
## main's and main2's proof sessions (2026-10-19, -22) were handed a real
## piece for 300 features, accepted 9 and rejected 63 as the wrong thing: a
## Technic gearbox for a skyscraper's crown, a pool-cue rack for a reflecting
## pool, a bed for a clock face, a nightstand for a street lamp. The piece was
## matched on any word of what it is ("a light grey 24-tooth crown gear"), so a
## word that only described it decided. A piece is what its head noun says
## (RealSnippets.kind_of): a pool-cue rack is a rack, a gearbox a gearbox.
##
## With --cases=FILE (rows of {brief, feature, widest}) it prints the pieces
## offered for each, as JSON lines to --out=FILE, for counting the right kind
## against the wrong by hand; without, it checks the cases below.
extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if not RealSnippets.available():
		print("SKIP no real-set index at %s (tools/snippets.py build)" % RealSnippets.INDEX)
		quit(3)
		return
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
	await process_frame
	var cases: String = ""
	var out_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--cases="):
			cases = argument.trim_prefix("--cases=")
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	if not cases.is_empty():
		await _measure(assistant, cases, out_path)
		quit(0)
		return
	await _checks(assistant)
	print("")
	if _failures == 0:
		print("OK feature_kinds_probe")
	else:
		print("FAILED feature_kinds_probe: %d" % _failures)
	quit(1 if _failures > 0 else 0)


## The pieces the feature pass would offer for a feature of a subject, best
## first, on a model [param widest] studs across.
func _offered(assistant: Assistant, brief: String, feature: String, widest: int) -> Array:
	assistant.world.clear()
	assistant.builder.lattice.clear()
	assistant._brief = brief
	var row: Array = []
	for x: int in [0, maxi(1, widest - 1)]:
		row.append({"part": "3024", "color": 71, "x": x, "y": 0, "z": 0, "rot": 0})
	await assistant._run_tool({"name": "edit_model", "input": {"add": row}})
	return assistant.feature_pass().candidates_for(feature)


func _measure(assistant: Assistant, path: String, out_path: String) -> void:
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out: FileAccess = FileAccess.open(out_path, FileAccess.WRITE) if not out_path.is_empty() \
		else null
	var whole: Dictionary = RealSnippets.read(RealSnippets.INDEX)
	for raw: Variant in rows as Array:
		var case: Dictionary = raw
		# The set under test held out, as realset's run holds it out.
		DesignMemory.hold_out(PackedStringArray([str(case.get("set", ""))]))
		RealSnippets._take(whole.duplicate(false))
		var found: Array = await _offered(assistant, str(case["brief"]), str(case["feature"]),
			int(case.get("widest", 16)))
		var said: Array = []
		for entry: Variant in found.slice(0, 3):
			said.append({"id": (entry as Dictionary)["id"],
				"text": str((entry as Dictionary).get("text", "")).left(110)})
		var line: Dictionary = {"set": case.get("set", ""), "arm": case.get("arm", ""),
			"feature": case["feature"], "offered": said}
		print(JSON.stringify(line))
		if out != null:
			out.store_line(JSON.stringify(line))


## Features of main's and main2's proof sessions, with the brief and the
## model's width, and the piece handed then that the session rejected as the
## wrong thing.
const CASES: Array = [
	["21028-1", "New York City, in the style of LEGO® Architecture sets: fitting in about "
		+ "6 x 33 studs, 450 to 750 pieces.", "Chrysler crown", 34,
		"8022-1_Plane/plane-step-4"],
	["21017-1", "Imperial Hotel, in the style of LEGO® Architecture sets: fitting in about "
		+ "30 x 36 studs, 890 to 1490 pieces.", "reflecting pool", 38,
		"10246-1/ground-floor-cue-holder"],
	["7992-1", "Container Stacker, in the style of LEGO® City sets: fitting in about "
		+ "25 x 34 studs, 170 to 280 pieces.", "warning beacon", 33, "6681-1/road-sign-2"],
	["21045-1", "Trafalgar Square, in the style of LEGO® Architecture sets: fitting in "
		+ "about 26 x 30 studs, 890 to 1490 pieces.", "lions", 31,
		"21311-1/yellow-lion-step-29"],
	["21045-1", "Trafalgar Square, in the style of LEGO® Architecture sets: fitting in "
		+ "about 26 x 30 studs, 890 to 1490 pieces.", "double-decker bus", 31,
		"8880-1/step27combo"],
	["21020-1", "The Trevi Fountain, in the style of LEGO® Architecture sets: fitting in "
		+ "about 18 x 26 studs, 550 to 910 pieces.", "coat of arms", 28,
		"40412-1/hagrid-step-18"],
	["40183-1", "Bricktober Town Hall, in the style of LEGO® Promotional sets: fitting in "
		+ "about 8 x 12 studs, 140 to 230 pieces.", "clock face", 15, "75948-1/bed"],
	["5934-1", "Dino Explorer, in the style of LEGO® Adventurers sets: fitting in about "
		+ "21 x 21 studs, 80 to 130 pieces.", "dinosaur horns", 26, "8868-1/horn"],
]


func _checks(assistant: Assistant) -> void:
	print("\na piece is what its head noun says")
	_ok(RealSnippets.heads_of({"text": "pool cue rack: black 1x4x3 panel"}) == [
		PackedStringArray(["rack"])], "a pool cue rack is a rack, not a pool")
	_ok(RealSnippets.heads_of({"text": "traffic cone or warning beacon: red 2x2x2 cone"}) == [
		PackedStringArray(["cone"]), PackedStringArray(["beacon"])],
		"a traffic cone or warning beacon is a cone first, a beacon second")
	_ok(RealSnippets.heads_of({"text": "car windscreen and roof: trans brown"}) == [
		PackedStringArray(["windscreen", "roof"])], "a car windscreen and roof is both")
	_ok(RealSnippets.heads_of({"text": "tower roof ridge section: tan slopes"}) == [
		PackedStringArray(["ridge"])], "a tower roof ridge section is a ridge")
	_ok(RealSnippets.heads_of({"text": "gearbox for the plane: a 24-tooth crown gear"}) == [
		PackedStringArray(["gearbox"])], "a gearbox for a plane is a gearbox, its crown gear "
			+ "only how it is built")
	_ok(RealSnippets.heads_of({"text": "bus front end with grille: yellow plates"}) == [
		PackedStringArray(["end"])], "a bus's front end is not a bus")

	print("\na feature is what it names, not where it is")
	_ok(FeaturePass.nouns_of("torch on the wall")[0][0] == "torch"
		and FeaturePass.nouns_of("torch on the wall").size() == 1, "a torch on the wall is a torch")
	_ok(FeaturePass.nouns_of("gate doors in the arch")[0][0] == "door",
		"gate doors in the arch are doors")
	_ok(FeaturePass.nouns_of("coat of arms")[0][0] == "coat"
		and FeaturePass.of_what("coat of arms") == PackedStringArray(["arm"]),
		"a coat of arms is a coat, of arms")
	_ok(FeaturePass.nouns_of("row of windows")[0][0] == "window"
		and FeaturePass.of_what("row of windows").is_empty(), "a row of windows is windows")

	print("\nwhat is held by the model where it goes is offered too; what the check refuses is not")
	_ok(RealSnippets.holdable({"square": true, "lays": false, "why": "floating"})
		and RealSnippets.holdable({"square": true, "lays": false, "why": "2 pieces"})
		and RealSnippets.holdable({"square": true, "lays": true}),
		"a piece that lays, or floats or comes in pieces alone, can be laid whole")
	_ok(not RealSnippets.holdable({"square": true, "lays": false, "why": "collision, floating"})
		and not RealSnippets.holdable({"square": false}),
		"one whose own parts collide, or built at an angle, cannot")

	print("\nthe features handed the wrong thing in the proof sessions")
	var whole: Dictionary = RealSnippets.read(RealSnippets.INDEX)
	for case: Array in CASES:
		DesignMemory.hold_out(PackedStringArray([str(case[0])]))
		RealSnippets._take(whole.duplicate(false))
		var found: Array = await _offered(assistant, case[1], case[2], case[3])
		var nouns: Array = FeaturePass.nouns_of(case[2])
		var right: bool = true
		for entry: Variant in found:
			var heads: Array = RealSnippets.heads_of(entry)
			var named: bool = false
			for reading: Variant in heads:
				for kin: PackedStringArray in nouns:
					for word: String in kin:
						named = named or (reading as PackedStringArray).has(word)
			right = right and named and str((entry as Dictionary)["id"]) != case[4]
		_ok(right, "%s (%s): %s, never %s" % [case[2], case[0], ("first " + str(
			(found[0] as Dictionary)["text"]).get_slice(":", 0)) if not found.is_empty()
			else "none offered", case[4]])


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
