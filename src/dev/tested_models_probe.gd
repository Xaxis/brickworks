## The Tested mark on whole models, by the exact check (Tested's whole test):
## a model a person can build is marked, one that does not go together is
## not, and says why.
##
##   godot --headless --path . --script src/dev/tested_models_probe.gd
##
## models175 found the whole test held a part whenever it touched a held one
## and never asked about collisions, so Orthanc (145 pairs through each other,
## 72 pieces by the exact check, as it was at rel-m155) could have been marked. Here: Orthanc is not
## Tested and says both; the kart, the castle and the orrery the app ships are
## Tested; three bricks stacked with a tile on top are, and the same with a
## brick only resting on the tile are not, saying what it rests on; a 1 x 1
## cheese slope on a round plate's rim where it has no stud (the outline161
## rabbit's fault) is not; and the bench's six sculpt170 designs, each one
## piece by verify.py and by the design check, pass the whole test, and are
## Tested where their other three pass.
extends SceneTree

const SHIPPED: Array[String] = ["res://models/kart.ldr", "res://models/castle.ldr",
	"res://models/orrery.ldr"]
## Orthanc as models175 measured it (models/orthanc.ldr at rel-m155), kept
## here: orthanc177 mends the shipped one.
## Shipped models whose steps build a sub-model in the hand that is not one
## piece there, so they fail the steps test as they did before the exact
## check: the orrery builds each planet's ring and the beams over it in one
## sub-model, and the beams are pinned to the ring above, not to it.
const BUILT_IN_PIECES: Array[String] = ["res://models/orrery.ldr"]
const ORTHANC := "res://src/dev/fixtures/orthanc_models175.ldr.gz"
const BENCH := "res://src/dev/fixtures/bench/"

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
		print("tested_models probe: SKIPPED, no exact shapes in this build")
		quit(0)
		return

	print("\none part only resting")
	var stack: Array = [[["3001", 4, Vector3(0, 0, 0)]], [["3001", 1, Vector3(0, -24, 0)]],
		[["3069b", 14, Vector3(-20, -32, -10)]]]
	var tiled: Dictionary = await _test(_model("tiled", stack))
	print("  %s" % _said(tiled))
	_ok(Tested.passed(tiled), "two bricks stacked with a tile on top are Tested: %s" % _why(tiled, "whole"))
	var resting: Dictionary = await _test(_model("resting", stack + [[["3004", 2, Vector3(-20, -56, -10)]]]))
	print("  %s" % _said(resting))
	_ok(not Tested.passed(resting) and _why(resting, "whole").contains("Brick 1 x 2 rests on Tile 1 x 2"),
		"...a 1 x 2 brick resting on the tile is not, and says what it rests on: %s" % _why(resting, "whole"))
	# As exact_probe stands it, outline161 model-078's.
	var rim: Dictionary = await _test(_model("rim", [[["11213", 71, Vector3(80, -8, -100)]],
		[["54200", 71, Vector3(50, -8, -150)]]]))
	print("  %s" % _said(rim))
	_ok(not Tested.passed(rim) and _why(rim, "whole").contains("where it has no stud"),
		"a cheese slope on a 6 x 6 round plate's rim, where it has no stud, is not: %s" % _why(rim, "whole"))

	print("\nthe models the app ships")
	for path: String in SHIPPED:
		var found: Dictionary = await _test(FileAccess.get_file_as_string(path))
		print("  %s" % _said(found))
		_ok(_passes(found, "whole"), "%s is one piece, every part held, none in another: %s" % [
			path.get_file(), _why(found, "whole")])
		_ok(Tested.passed(found) or path in BUILT_IN_PIECES,
			"%s is %sTested: %s" % [path.get_file(), "" if Tested.passed(found) else "not ",
			Tested.words(found)])

	print("\nthe bench's one-piece designs")
	var designs: PackedStringArray = DirAccess.get_files_at(BENCH)
	var marked: int = 0
	var stood: int = 0
	for file: String in designs:
		var found: Dictionary = await _test(FileAccess.get_file_as_string(BENCH + file))
		print("  %s: %s" % [file, _said(found)])
		var stands: bool = _passes(found, "stands")
		stood += 1 if stands else 0
		marked += 1 if Tested.passed(found) else 0
		var others: bool = stands and _passes(found, "steps") and _passes(found, "parts")
		_ok(_passes(found, "whole") and Tested.passed(found) == others,
			"%s is one piece, every part held, none in another, and %s" % [file,
			"Tested" if Tested.passed(found) else "not Tested, for its other tests: %s" % Tested.words(found)])
	_ok(designs.size() == 6 and marked >= 1, "%d of %d designs stand, and %d are Tested" % [
		stood, designs.size(), marked])

	print("\nOrthanc")
	var packed: PackedByteArray = FileAccess.get_file_as_bytes(ORTHANC)
	var orthanc: Dictionary = await _test(packed.decompress_dynamic(-1,
		FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	print("  %s" % _said(orthanc))
	var whole: String = _why(orthanc, "whole")
	_ok(not Tested.passed(orthanc) and orthanc.has("tests") and not _passes(orthanc, "whole")
		and whole.contains("pass into each other") and whole.contains("pieces, not one"),
		"Orthanc is not Tested, and says why: %s" % whole)
	_ok(whole.length() <= Tested.MOST_WHY, "...in the %d characters the site keeps (%d)" % [
		Tested.MOST_WHY, whole.length()])
	_ok(Tested.words(orthanc).begins_with("Not marked Tested (only you see why)"),
		"...and its owner is told so: \"%s\"" % Tested.words(orthanc).left(200))

	print("%d FAILED" % _failures if _failures else
		"a model is Tested when it goes together, and one that does not says why")
	quit(1 if _failures else 0)


func _test(text: String) -> Dictionary:
	return (await SharedPages.attach_tested(text, _library, _store))["tested"]


func _passes(found: Dictionary, test: String) -> bool:
	return bool(((found.get("tests", {}) as Dictionary).get(test, {}) as Dictionary).get("ok", false))


func _why(found: Dictionary, test: String) -> String:
	return str(((found.get("tests", {}) as Dictionary).get(test, {}) as Dictionary).get("why", ""))


func _said(found: Dictionary) -> String:
	if found.is_empty() or not found.has("tests"):
		return "not tested: %s" % str(found.get("untested", ""))
	var out := PackedStringArray()
	for test: String in ["stands", "steps", "parts", "whole"]:
		out.append("%s %s (%s)" % [test, "ok" if _passes(found, test) else "FAILS", _why(found, test)])
	return "%d parts, %d steps, %d ms: %s" % [int(found.get("parts", 0)), int(found.get("steps", 0)),
		int(found.get("ms", 0)), "; ".join(out)]


## A model in its author's steps: each step a list of [part, colour, where].
func _model(name: String, steps: Array) -> String:
	var lines := PackedStringArray(["0 FILE %s.ldr" % name, "0 %s" % name, "0 Name: %s.ldr" % name,
		"0 Author: Tested models probe", ""])
	for step: Array in steps:
		for one: Array in step:
			var at: Vector3 = one[2]
			lines.append("1 %d %d %d %d 1 0 0 0 1 0 0 0 1 %s.dat" % [int(one[1]),
				int(at.x), int(at.y), int(at.z), str(one[0])])
		lines.append("0 STEP")
	return "\r\n".join(lines) + "\r\n"


func _ok(passed: bool, what: String) -> void:
	print(("ok   " if passed else "FAIL ") + what)
	if not passed:
		_failures += 1
