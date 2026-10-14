## Does a designer get what our scored designs of its subject did, and
## never the design for a subject under test?
##
##   godot --headless --path . --script src/dev/design_memory_probe.gd
##   godot --headless --path . --script src/dev/design_memory_probe.gd -- --held-out=speed_champions
##
## The memory (tools/design_memory.py, src/ai/design_memory.gd) is worth
## something only if three things hold. Asked about a subject in words no
## title uses — a race car, a corner store, a parrot — it finds the scored
## designs of the nearest one, and a revision that names no subject finds
## nothing. The bench's subject under test is never found while it runs.
## And the answer reaches the designer: in how_real_sets_build_this, which
## a session asks with the subject before building, and in the first
## message of the app's own loop, with the judge's faults in it.
##
## Run with --held-out=ID, it checks the flag as the bench passes it hides
## that subject, the same flag tools/bench/run.py gives every design run.
extends SceneTree

## Phrasings no design's title uses, and the subject each should find
## nearest. Written before the search was tuned; the misses are kept.
const HELD_OUT_QUERIES := [
	["barn owl", "barn_owl"],
	["race car", "speed_champions"],
	["corner store", "corner_shop"],
	["a parrot on a perch", "barn_owl"],
	["an eagle", "barn_owl"],
	["a sports car with a spoiler", "speed_champions"],
	["a knight's fortress", "castle_gatehouse"],
	["a space shuttle on its launch pad", "falcon_heavy"],
	["a rocket", "falcon_heavy"],
	["an X-wing", "starfighter"],
	["a tow truck", "mobile_crane"],
	["a Technic excavator", "mobile_crane"],
	["a bust of Einstein", "astronaut_bust"],
	["a pine tree in a pot", "bonsai"],
	["a cottage by a lake", "mountain_cabin"],
	["a bakery on a street corner", "corner_shop"],
]
## Briefs that name no subject: a revision, a part of a model.
const NOTHING_NEAR := ["make it two studs taller", "add a door on the left",
	"use darker colours"]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var flagged: PackedStringArray = DesignMemory.held_out()
	if (DesignMemory.document().get("entries", []) as Array).is_empty():
		print("FAIL no design memory at %s (tools/design_memory.py build)" % DesignMemory.INDEX)
		quit(1)
		return
	if not flagged.is_empty():
		_check_the_flag(flagged)
		_finish("the subject under test is held out, as the bench's flag asks")
		return

	var entries: Array = DesignMemory.document()["entries"]
	print("the index")
	var subjects: Dictionary = {}
	var whole: int = 0
	for raw: Variant in entries:
		var entry: Dictionary = raw
		subjects[str(entry["subject"])] = true
		if (entry["scores"] as Dictionary).size() == 6 and not str(entry["reasons"]["technique"]).is_empty() \
				and not str(entry.get("thumb", "")).is_empty() and not str(entry["built"]).is_empty():
			whole += 1
	_ok(entries.size() >= 20, "%d scored designs" % entries.size())
	# Ten, and two held out since the sides round (tools/bench/suite.py).
	_ok(subjects.size() == 12, "of the suite's twelve subjects (%d)" % subjects.size())
	_ok(whole == entries.size(), "each with six scores, the judge's reasons, how it was "
		+ "built and a picture (%d of %d)" % [whole, entries.size()])

	print("\nfound in words no title uses")
	var first: int = 0
	var third: int = 0
	for pair: Array in HELD_OUT_QUERIES:
		var order: PackedStringArray = PackedStringArray()
		for designs: Variant in DesignMemory.near(str(pair[0])):
			order.append(str((designs as Array)[0]["subject"]))
		var at: int = order.find(str(pair[1]))
		first += int(at == 0)
		third += int(at >= 0 and at < 3)
		var verdict: String = "nearest" if at == 0 else "#%d" % (at + 1) if at > 0 else "MISSED"
		print("    %-36s %-17s %-8s (%s)" % ["\"%s\"" % pair[0], pair[1], verdict,
			", ".join(order.slice(0, 3))])
	_ok(first * 10 >= HELD_OUT_QUERIES.size() * 8, "the right subject nearest for %d of %d"
		% [first, HELD_OUT_QUERIES.size()])
	_ok(third == HELD_OUT_QUERIES.size(), "...and among the first three for %d of %d"
		% [third, HELD_OUT_QUERIES.size()])
	for brief: String in NOTHING_NEAR:
		_ok(DesignMemory.recall(brief).is_empty(), "\"%s\" is handed nothing" % brief)

	print("\nwhat a designer is handed")
	var said: String = DesignMemory.recall_text("race car")
	print("    " + said.replace("\n", "\n    "))
	_ok(said.contains("Nearest: a Porsche 911 Turbo"), "a race car is handed the Porsche")
	_ok(said.contains("What the judge faulted") and said.contains("- technique "),
		"...with the judge's faults, technique among them")
	_ok(said.contains("Built with: studs sideways"), "...and how the best one was built")
	_ok(said.length() < 2600, "...in %d characters" % said.length())
	var blocks: Array = DesignMemory.recall("race car")
	_ok(blocks.any(func(block: Variant) -> bool:
			return str((block as Dictionary).get("type", "")) == "image"),
		"...and a picture of the best one")

	print("\nheld out, as the bench holds out the subject under test")
	_held_out_check("speed_champions", "race car", "Porsche")
	_held_out_check("barn_owl", "barn owl", "barn owl")
	_ok(DesignMemory.held_out_of(PackedStringArray(["--mcp=4000", "--held-out=barn_owl,bonsai"]))
			== PackedStringArray(["barn_owl", "bonsai"]), "the flag is read as the bench writes it")
	DesignMemory.hold_out(PackedStringArray())

	await _through_the_app()
	_finish("a designer starts past the faults the judge found")


## Nothing of [param subject] is found or said while it is held out.
func _held_out_check(subject: String, query: String, words: String) -> void:
	DesignMemory.hold_out(PackedStringArray([subject]))
	var leaked: bool = false
	for pair: Variant in DesignMemory.search(query, 64):
		leaked = leaked or str((pair as Array)[1]["subject"]) == subject
	var said: String = DesignMemory.recall_text(query)
	_ok(not leaked and not said.containsn(words), "\"%s\" finds none of %s held out%s" % [
		query, subject, "" if said.is_empty() else
			" (nearest now: %s)" % said.get_slice("Nearest: ", 1).get_slice(".", 0)])


## Run with --held-out: the subject named is never found, by its own words
## or any other, and every other subject still is.
func _check_the_flag(flagged: PackedStringArray) -> void:
	print("held out by the flag: %s" % ", ".join(flagged))
	for pair: Array in HELD_OUT_QUERIES:
		var found: PackedStringArray = PackedStringArray()
		for row: Variant in DesignMemory.search(str(pair[0]), 64):
			found.append(str((row as Array)[1]["subject"]))
		if flagged.has(str(pair[1])):
			_ok(not found.has(str(pair[1])), "\"%s\" does not find %s" % [pair[0], pair[1]])
		else:
			_ok(found.has(str(pair[1])), "\"%s\" still finds %s" % [pair[0], pair[1]])


## The answer as a design gets it: the tool a session asks with the
## subject, and the first message of the app's own loop.
func _through_the_app() -> void:
	print("\nthrough the app")
	var library := PartLibrary.new()
	if not library.load_catalogue():
		_ok(false, "the catalogue loads")
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
	var answer: Variant = await assistant.use_tool("how_real_sets_build_this",
		{"subject": "race car"})
	var text: String = ""
	var pictures: int = 0
	for block: Variant in (answer as Array if answer is Array else []):
		text += str((block as Dictionary).get("text", "")) + "\n"
		pictures += int(str((block as Dictionary).get("type", "")) == "image")
	_ok(text.contains("FROM OUR OWN SCORED DESIGNS") and text.contains("Porsche"),
		"how_real_sets_build_this \"race car\" hands over the Porsche's scores and faults")
	_ok(text.contains("CAR") or text.contains("No kind"), "...after what real sets are built from")
	_ok(pictures == 1, "...with its picture (%d)" % pictures)
	var opening: String = ""
	var opened_pictures: int = 0
	for block: Variant in assistant.opening_for("A barn owl perched on a branch, about 25 cm tall"):
		opening += str((block as Dictionary).get("text", ""))
		opened_pictures += int(str((block as Dictionary).get("type", "")) == "image")
	_ok(opening.contains("Nearest: a barn owl"), "the app's own loop opens with it, unasked")
	_ok(opened_pictures == 0 and not opening.contains("The picture is that best"),
		"...in words, so the only pictures there are the reference")
	var revision: String = ""
	for block: Variant in assistant.opening_for("make it two studs taller"):
		revision += str((block as Dictionary).get("text", ""))
	_ok(not revision.contains("FROM OUR OWN"), "...and a revision that names nothing does not")
	var head: String = assistant.guidance().left(3500)
	_ok(head.contains("how_real_sets_build_this with the subject"),
		"the head a Claude Code session reads tells it to ask, with the subject")
	assistant.queue_free()
	builder.queue_free()
	world.queue_free()


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
