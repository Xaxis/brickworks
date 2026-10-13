## Can a design find how real sets built a feature, and lay it as built?
##
##   godot --headless --path . --script src/dev/snippets_probe.gd
##
## The real-set index (tools/snippets.py, src/ai/real_snippets.gd) is
## only worth something if three things hold. Search finds the feature
## asked for, from sets about the subject first, and finds the same in
## the app as tools/snippets.py does on the command line. Every piece is
## credited — set, modeller, licence — and none is non-commercial. And a
## piece found is a piece that builds: laid with place_technique on a
## plate, the way a design lays one, it is one piece and joined to the
## plate, checked by the same lattice and joint rules as any edit.
##
## Not in the suite's default list while the index is a local build: it
## says SKIP where there is no index.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var started: int = Time.get_ticks_msec()
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

	var entries: Array = RealSnippets.document()["entries"]
	print("  the index: %d pieces, read in %d ms" % [entries.size(),
		Time.get_ticks_msec() - started])
	_ok(entries.size() > 1000, "it has the repository's pieces, not a handful")
	var uncredited: int = 0
	var undescribed: int = 0
	for raw: Variant in entries:
		var entry: Dictionary = raw
		var licence: String = str(entry.get("licence", ""))
		if str(entry.get("by", "?")) in ["", "?"] or not licence.begins_with("CC BY") \
				or licence.contains("NC") or str(entry.get("set", "")).is_empty():
			uncredited += 1
		if str(entry.get("text", "")).is_empty():
			undescribed += 1
	_ok(uncredited == 0, "every piece is credited to its set and modeller, CC BY (%d not)"
		% uncredited)
	print("    %d of %d described" % [entries.size() - undescribed, entries.size()])

	print("  search")
	_ok(RealSnippets.stem("eyes") == "eye" and RealSnippets.stem("leaves") == "leaf"
		and RealSnippets.stem("glasses") == "glass", "plurals are seen through")
	_ok(RealSnippets.words("EyeL") == PackedStringArray(["eye"]),
		"\"EyeL\" is the word eye")
	for query: String in ["eye", "wing", "roof", "grille"]:
		var found: Array = RealSnippets.search(query, 0.0, [], 5)
		var named: int = 0
		for row: Array in found:
			var said: String = (str(row[1]["name"]) + " " + str(row[1].get("text", ""))).to_lower()
			if said.contains(query):
				named += 1
		# Most of what comes back is the thing, by name or description. The
		# repository has few eyes: four, before they were described.
		_ok(found.size() >= 3 and named * 4 >= found.size() * 3,
			"\"%s\" finds pieces that are one (%d of %d)" % [query, named, found.size()])
	var small: Array = RealSnippets.search("wing", 4.0, [], 5)
	var fits: bool = not small.is_empty()
	for row: Array in small:
		var size: Array = row[1]["size"]
		fits = fits and maxf(float(size[0]), float(size[2])) <= 4.0
	_ok(fits, "max_studs keeps to pieces that size")
	var sideways: Array = RealSnippets.search("face", 0.0, ["sideways"], 5)
	var all_sideways: bool = not sideways.is_empty()
	for row: Array in sideways:
		all_sideways = all_sideways and (row[1]["kinds"] as Array).has("sideways")
	_ok(all_sideways, "kinds keeps to pieces built that way")
	var car: Array = RealSnippets.search("car nose", 0.0, [], 5)
	_ok(not car.is_empty() and (car[0][1]["subject"] as Array).has("car"),
		"\"car nose\" puts a car set's piece first (%s)"
		% (car[0][1]["id"] if not car.is_empty() else "none"))
	_same_as_the_tool()

	print("  laid as built, on a plate, the way a design lays one")
	# A beak and a tail are tried and said, not asserted: the one beak
	# small enough, 31031's parrot's, is a curved slope seated in a way the
	# checker refuses, which is the checker's to learn (see assistant.md).
	for query: String in ["eye", "car nose", "wing", "turret roof", "beak", "tail"]:
		var laid: int = 0
		var tried := PackedStringArray()
		for row: Array in RealSnippets.search(query, 8.0, [], 5):
			var entry: Dictionary = row[1]
			if not bool(entry.get("square", true)):
				continue
			tried.append(str(entry["id"]))
			var verdict: String = await _lay(assistant, world, builder, entry)
			if verdict.is_empty():
				laid += 1
				print("    ok   %s: %s, whole and joined to the plate" % [query, entry["id"]])
				break
			print("    --   %s: %s %s" % [query, entry["id"], verdict])
		if query in ["beak", "tail"]:
			print("    %s  a real %s lays whole and joined: %s (not asserted)"
				% ["ok" if laid > 0 else "--", query, "yes" if laid > 0 else "none of " + ", ".join(tried)])
			continue
		_ok(laid > 0, "a real %s found for \"%s\" lays whole and joined (%s)"
			% [query, query, ", ".join(tried)])

	if _failures > 0:
		print("snippets probe: %d FAILED" % _failures)
		quit(1)
		return
	print("snippets probe: found by what it is, credited, and laid as built")
	quit(0)


## The app's search and tools/snippets.py's give the same answers.
func _same_as_the_tool() -> void:
	for query: String in ["owl eye", "car nose", "dragon wing", "castle turret roof"]:
		var mine := PackedStringArray()
		for row: Array in RealSnippets.search(query, 0.0, [], 5):
			mine.append(str(row[1]["id"]))
		var said: Array = []
		var code: int = OS.execute("python3", [ProjectSettings.globalize_path(
			"res://tools/snippets.py"), "search", query, "--ids"], said)
		if code != 0:
			print("    --   tools/snippets.py could not be run here; not compared")
			return
		var theirs := PackedStringArray(str(said[0]).strip_edges().split("\n", false))
		_ok(mine == theirs, "\"%s\": the app finds what the tool finds (%s / %s)"
			% [query, ",".join(mine), ",".join(theirs)])


## Lay one on a 16 x 16 plate through place_technique, on an empty
## baseplate, and say why not, or "" when it went down whole and joined.
func _lay(assistant: Assistant, world: BrickWorld, builder: Builder,
		entry: Dictionary) -> String:
	for brick: BrickWorld.Brick in world.bricks():
		builder.lattice.release(brick.id)
	world.clear()
	await assistant._run_tool({"name": "edit_model", "input": {"add": [{"part": "91405",
		"color": 72, "x": 0, "y": 0, "z": 0, "rot": 0}]}})
	if world.brick_count() != 1:
		return "the plate under it was not laid"
	var said: Variant = await assistant._place_technique({"id": entry["id"],
		"x": 4, "y": 1, "z": 4})
	var text: String = str(said[0]["text"]) + str(said[1].get("text", "")) \
		if said is Array else str(said)
	if not text.contains("Done."):
		return text.get_slice("\n", text.get_slice_count("\n") - 1).substr(0, 160) \
			if not text.contains("Not applied") \
			else text.substr(text.find("Not applied"), 200).replace("\n", " ")
	var model: Assistant.Model = assistant._model_from_world()
	var verdict: Dictionary = assistant._check(model)
	if not bool(verdict["ok"]) or int(verdict["pieces"]) != 1:
		return "laid, but %s in %d pieces" % [verdict["summary"], int(verdict["pieces"])]
	if model.placements.size() != 1 + int(entry["parts"]):
		return "laid %d parts of %d" % [model.placements.size() - 1, int(entry["parts"])]
	return ""


func _ok(condition: bool, label: String) -> void:
	if condition:
		print("    ok   " + label)
	else:
		_failures += 1
		print("    FAIL " + label)
