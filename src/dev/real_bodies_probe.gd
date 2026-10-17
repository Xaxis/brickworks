## Is a design shown how real sets of its line build a body, before its
## first brick?
##
##   godot --headless --path . --script src/dev/real_bodies_probe.gd
##
## how_real_sets_build_this is the call every session opens with (twenty of
## twenty on the tune half), and the body's build is settled at the first
## submission. So it answers first with the real-set index's biggest built
## sub-assemblies of the line the brief names (src/ai/real_snippets.gd
## line_of, bodies), each with how it is built, and the nearest to each mass
## the session names in assemblies; held-out sets never among them. Where the
## brief names no line, sets about the subject; where it names neither, as a
## revision does, nothing. Says SKIP where there is no index.
extends SceneTree

var _failures: int = 0

const PYRAMID := ("Scorpion Pyramid, in the style of LEGO® Pharaoh's Quest sets: "
	+ "fitting in about 48 x 59 studs, 630 to 1040 pieces.")


func _initialize() -> void:
	_run()


func _run() -> void:
	# The set under test, as realset.py starts a design: its pieces are out.
	DesignMemory.hold_out(PackedStringArray(["7327-1"]))
	if not RealSnippets.available():
		print("SKIP no real-set index at %s (tools/snippets.py build)" % RealSnippets.INDEX)
		quit(0)
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

	# 1. The line a brief names.
	_ok(RealSnippets.line_of(PYRAMID) == "Pharaoh's Quest",
		"\"in the style of LEGO® Pharaoh's Quest sets\" is the Pharaoh's Quest line (%s)"
			% RealSnippets.line_of(PYRAMID))
	var tokyo: String = ("Tokyo, in the style of LEGO® Architecture sets: fitting in about "
		+ "13 x 36 studs. city skyline")
	_ok(RealSnippets.line_of(tokyo) == "Architecture",
		"...the brief's own line ahead of a word said after it (%s, not City)"
			% RealSnippets.line_of(tokyo))
	_ok(RealSnippets.line_of("a Technic telehandler with a working boom") == "Technic",
		"\"a Technic telehandler\" is the Technic line")
	_ok(RealSnippets.line_of("a barn owl perched on a branch").is_empty(),
		"a brief that names no line has none")
	_ok(RealSnippets.line_of("a crate of other bricks, an exclusive promotional one").is_empty(),
		"...and a way of selling sets is not a line (Other, Promotional, LEGO Exclusive)")

	# 2. The line's bodies: built pieces first, none of the held-out set.
	var found: Array = RealSnippets.bodies("Pharaoh's Quest", "pyramid", 6)
	var lines_ok: bool = not found.is_empty()
	var held: int = 0
	var built: int = 0
	for entry: Dictionary in found:
		lines_ok = lines_ok and RealSnippets.line_named(entry) == "Pharaoh's Quest" \
			and int(entry["parts"]) >= RealSnippets.BODY_PARTS
		held += int(str(entry["set"]) == "7327-1")
		built += int(not RealSnippets.how_built(entry).is_empty())
	_ok(lines_ok, "the line's bodies are its own sets' pieces of %d parts or more (%d)"
		% [RealSnippets.BODY_PARTS, found.size()])
	_ok(held == 0, "...never the held-out set's")
	_ok(built >= found.size() - 1, "...built on hinges, sideways or of slopes, all but one at most (%d of %d)"
		% [built, found.size()])
	var any_of_7327: bool = false
	for raw: Variant in RealSnippets.document()["entries"]:
		any_of_7327 = any_of_7327 or str((raw as Dictionary)["set"]) == "7327-1"
	_ok(not any_of_7327, "the held-out set is out of the whole index")

	# 3. The tool's answer: first, with each mass the session names.
	assistant.heard(PYRAMID, true)
	var answer: Variant = await assistant.use_tool("how_real_sets_build_this",
		{"subject": "pyramid", "assemblies": ["leg", "temple tower", "zzqx"]})
	var text: String = ""
	var first: String = ""
	for block: Variant in (answer as Array if answer is Array else []):
		var said: String = str((block as Dictionary).get("text", ""))
		if first.is_empty():
			first = said
		text += said + "\n"
	_ok(first.begins_with("HOW REAL SETS BUILD ITS BODY"), "the answer opens with how real sets build its body")
	_ok(text.contains("From the LEGO® Pharaoh's Quest line"), "...from the brief's line")
	_ok(text.contains("Built on hinges or clips") or text.contains("Built studs sideways")
		or text.contains("Built of slopes"), "...each piece with how it is built, in a builder's words")
	_ok(text.contains("  leg: 7326-1/"), "...the leg mass finds the line's own jointed leg")
	_ok(text.contains("  zzqx: no real set has a piece"), "...a mass nothing is called says so")
	_ok(not text.contains("7327-1/"), "...and never the held-out set's pieces")
	_ok(text.contains("place_technique with its id"), "...and how to lay one whole")
	_ok(text.contains("Decide it here, for each mass, before the first brick"),
		"...asking for the choice before the first brick")

	# 4. No line: sets about the subject; no subject either: nothing.
	assistant.heard("a scarlet macaw parrot on a perch", true)
	var bird: Variant = await assistant.use_tool("how_real_sets_build_this", {"subject": "parrot"})
	var bird_text: String = str(((bird as Array)[0] as Dictionary).get("text", "")) if bird is Array else ""
	_ok(bird_text.contains("From real sets about parrot"), "a brief of no line is shown sets about its subject")
	var opening: String = ""
	for block: Variant in assistant.opening_for("make it two studs taller"):
		opening += str((block as Dictionary).get("text", ""))
	_ok(not opening.contains("HOW REAL SETS BUILD ITS BODY"),
		"a revision that names no line and no subject is shown none")
	var loop_opening: String = ""
	for block: Variant in assistant.opening_for(PYRAMID):
		loop_opening += str((block as Dictionary).get("text", ""))
	_ok(loop_opening.contains("From the LEGO® Pharaoh's Quest line"),
		"the app's own loop opens with it too, unasked")

	# 5. A feature's piece from the brief's line first, where the line has one
	# the feature's words find: a Technic grille, not a Tower Bridge pinnacle.
	assistant.heard("Telehandler, in the style of LEGO® Technic sets: fitting in about "
		+ "14 x 34 studs.", true)
	var grilles: Array = assistant.feature_pass().candidates_for("engine grille")
	_ok(not grilles.is_empty() and RealSnippets.line_named(grilles[0]) == "Technic",
		"a Technic brief's engine grille is a Technic set's piece first (%s)"
			% (str(grilles[0]["id"]) if not grilles.is_empty() else "none"))
	var all_fit: bool = true
	for entry: Dictionary in grilles:
		all_fit = all_fit and bool(entry.get("lays", false)) and int(entry["parts"]) <= FeaturePass.MOST_PARTS
	_ok(all_fit, "...each one that lays whole, as before")
	assistant.heard("a scarlet macaw parrot on a perch", true)
	var eyes: Array = assistant.feature_pass().candidates_for("eyes")
	_ok(not eyes.is_empty(), "a brief of no line still finds pieces for a feature (%d)" % eyes.size())

	# 6. The tool says so, and the head a session reads does.
	var schema: Dictionary = {}
	for tool: Variant in assistant._tools():
		if str((tool as Dictionary)["name"]) == "how_real_sets_build_this":
			schema = tool
	_ok((schema.get("input_schema", {}) as Dictionary).get("properties", {}).has("assemblies"),
		"how_real_sets_build_this takes the masses planned as assemblies")
	_ok(Assistant.GUIDE_HEAD.contains("main masses as assemblies"),
		"the head a session reads asks for them in step 1")

	assistant.queue_free()
	builder.queue_free()
	world.queue_free()
	await process_frame
	print("")
	if _failures == 0:
		print("real bodies: every check passed")
	else:
		print("real bodies: %d failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _ok(condition: bool, label: String) -> void:
	print("  %s %s" % ["ok  " if condition else "FAIL", label])
	if not condition:
		_failures += 1
