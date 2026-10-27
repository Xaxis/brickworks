## The worked-out steps put each part on what holds it (HeldSteps), headless,
## on designs the app's own designer saved.
##
##   godot --headless --path . --script src/dev/held_steps_probe.gd
##
## Three of seed211's twelve house models as the designer first saved them
## (2026-10-24), in fixtures/house: the fox, whose worked-out steps put 122
## parts down before what holds them; the pagoda, whose sub-assemblies built
## in the hand are each two pieces until they are put on; and the robot,
## which put a sub-assembly on before what holds it. Each fails the Tested
## mark's steps test with the planner alone (HeldSteps.mends off) and passes
## it with the mend, but the fox's one part that its body hides from every
## side even beside what holds it, which the test still names (two, judged
## by boxes from the front and the back, tested306); and every part is in the
## steps once, where the share's pages carry it, its file unchanged. A
## bench design whose planned steps already pass (sculpt170's model-043) is
## left exactly as planned.
extends SceneTree

const HOUSE := "res://src/dev/fixtures/house/"
const BUILDS := "res://src/dev/fixtures/bench/sculpt170-043.ldr"

var _failures: int = 0
var _library: PartLibrary
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	_store = ModelStore.new()
	_store.world = world
	_store.library = _library
	_store.builder = builder
	_store.keeps = false
	await process_frame
	if Exact.shape_for(_library, "3001") == null:
		print("held_steps probe: SKIPPED, no exact shapes in this build")
		quit(3)
		return

	for name: String in ["fox", "pagoda", "robot"]:
		print("\n%s, as the designer saved it" % name)
		var text: String = FileAccess.get_file_as_string(HOUSE + name + ".ldr")
		HeldSteps.mends = false
		var alone: Dictionary = (await SharedPages.attach_tested(text, _library, _store))["tested"]
		HeldSteps.mends = true
		var made: Dictionary = await SharedPages.attach_tested(text, _library, _store)
		var mended: Dictionary = made["tested"]
		var said: Dictionary = HeldSteps.said.duplicate()
		print("  planner alone: %s" % _why(alone, "steps"))
		print("  mended: %s; %s" % [_why(mended, "steps"), str(said)])
		_ok(not _passes(alone, "steps"), "the planner alone puts parts down in the air: %s"
			% _why(alone, "steps").left(160))
		if name == "fox":
			_ok(int(said.get("floating", -1)) == 0 and int(said.get("hidden", -1)) == 1
					and _why(mended, "steps").count("is hidden behind what is already built") == 1
					and not _why(mended, "steps").contains("in the air"),
				"mended, nothing is in the air; the one part its body hides from every side even beside what holds it is named: %s"
					% _why(mended, "steps"))
			_ok(int(said.get("waited", 0)) >= 100, "...%d parts waited for the step that holds them"
				% int(said.get("waited", 0)))
		else:
			_ok(_passes(mended, "steps"), "mended, it passes the steps test: %s (%d waited, %d sooner)" % [
				_why(mended, "steps"), int(said.get("waited", 0)), int(said.get("sooner", 0))])
		_ok(_passes(mended, "stands") == _passes(alone, "stands") and _passes(mended, "whole")
				and _passes(mended, "parts") == _passes(alone, "parts"),
			"...and its other tests are as they were: stands %s, parts %s, whole %s" % [
				_passes(mended, "stands"), _passes(mended, "parts"), _passes(mended, "whole")])
		_ok(_once(str(made["text"])), "...every part in its steps once, in the pages the share carries")
		_ok(SharedPages.strip(str(made["text"])).strip_edges() == text.strip_edges(),
			"...and the file the share carries is the file, but for the pages")

	print("\na design whose planned steps already build")
	var builds: String = FileAccess.get_file_as_string(BUILDS)
	HeldSteps.mends = false
	var planned: String = str((await SharedPages.attach_tested(builds, _library, _store))["text"])
	HeldSteps.mends = true
	var made: Dictionary = await SharedPages.attach_tested(builds, _library, _store)
	print("  %s" % str(HeldSteps.said))
	_ok(_passes(made["tested"], "steps") and str(made["text"]) == planned,
		"model-043 passes the steps test as planned, and its steps are exactly the planner's")

	print("%d FAILED" % _failures if _failures else
		"the worked-out steps put each part on what holds it, and leave what builds as it was planned")
	quit(1 if _failures else 0)


## Whether every part of the model in [param text] is in exactly one of the
## steps it carries, on the model or in a sub-assembly put on.
func _once(text: String) -> bool:
	var at: int = text.find(SharedPages.HEAD)
	if at < 0:
		return false
	var lines: PackedStringArray = text.substr(at).split("\n")
	var head: Dictionary = JSON.parse_string(lines[0].strip_edges().trim_prefix(SharedPages.HEAD.strip_edges()))
	var seen: Dictionary = {}
	for n: int in range(1, lines.size()):
		var line: String = lines[n].strip_edges()
		if not line.begins_with(SharedPages.PAGE.strip_edges()):
			continue
		var step: Dictionary = JSON.parse_string(line.trim_prefix(SharedPages.PAGE.strip_edges()))
		if step.has("c") and int((step["c"] as Array)[1]) > 0:
			continue
		var ids: Array = step.get("b", [])
		for copy: Variant in step.get("k", []):
			ids = ids + (copy as Array)
		for id: Variant in ids:
			if seen.has(int(id)):
				return false
			seen[int(id)] = true
	return seen.size() == int(head.get("parts", -1))


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _passes(found: Dictionary, test: String) -> bool:
	return bool(((found.get("tests", {}) as Dictionary).get(test, {}) as Dictionary).get("ok", false))


func _why(found: Dictionary, test: String) -> String:
	return str(((found.get("tests", {}) as Dictionary).get(test, {}) as Dictionary).get("why", ""))
