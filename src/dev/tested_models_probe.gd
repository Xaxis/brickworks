## The Tested mark on whole models, by the exact check (Tested's whole test):
## a model a person can build is marked, one that does not go together is
## not, and says why.
##
##   godot --headless --path . --script src/dev/tested_models_probe.gd
##
## models175 found the whole test held a part whenever it touched a held one
## and never asked about collisions, so Orthanc (145 pairs through each other,
## 72 pieces by the exact check, as it was at rel-m155) could have been marked. Here: Orthanc is not
## Tested and says both; the kart, the castle and the orrery the app ships
## are Tested (the orrery's steps are its own since orrery190: worked out,
## its top deck went up before the spine that carries it, and twelve gears
## went in behind what hides them); two bricks stacked with a tile on top
## are, and the same with a brick only resting on the tile are not, saying
## what it rests on; two stacks apart are
## two builds, and Tested, and a part left on the floor against one is not;
## 6680-1's figures and stretcher are builds of their own, and without the
## one plate its file draws inside another, it is Tested; a 1 x 1
## cheese slope on a round plate's rim where it has no stud (the outline161
## rabbit's fault) is not; and the bench's six sculpt170 designs, each one
## piece by verify.py and by the design check, pass the whole test, and are
## Tested where their other three pass.
extends SceneTree

const SHIPPED: Array[String] = ["res://models/kart.ldr", "res://models/castle.ldr",
	"res://models/orrery.ldr"]
## A real set whose figures and stretcher stand beside its ambulance, and
## whose file draws one 1 x 2 plate inside a 1 x 6 at the same height (the
## exact check finds it, and its steps hide it): without it, it builds.
const AMBULANCE := "res://vendor/omr/files/6680-1.mpd"
const MISPLACED := "1 16 30 -16 150 0 0 1 0 1 0 -1 0 0 3023.dat"
## Real sets of a vehicle with a figure standing beside it.
const TWO_BUILDS: Array[String] = ["res://vendor/omr/files/620-1.mpd", "res://vendor/omr/files/6511-1.mpd"]
## Orthanc as models175 measured it (models/orthanc.ldr at rel-m155), kept
## here: orthanc177 mends the shipped one.
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
	var two: Dictionary = await _test(_model("two", stack.slice(0, 2)
		+ [[["3001", 4, Vector3(200, 0, 0)]], [["3001", 1, Vector3(200, -24, 0)]]]))
	print("  %s" % _said(two))
	_ok(Tested.passed(two) and _why(two, "whole").begins_with("2 builds"),
		"two stacks apart are two builds, each standing on its own, and Tested: %s" % _why(two, "whole"))
	var leant: Dictionary = await _test(_model("against", stack.slice(0, 2)
		+ [[["4073", 14, Vector3(50, 16, 0)]]]))
	print("  %s" % _said(leant))
	_ok(not Tested.passed(leant) and _why(leant, "whole").contains("Plate 1 x 1 Round stands against Brick 2 x 4"),
		"...a round plate left on the floor against the stack is not: %s" % _why(leant, "whole"))
	# As exact_probe stands it, outline161 model-078's.
	var rim: Dictionary = await _test(_model("rim", [[["11213", 71, Vector3(80, -8, -100)]],
		[["54200", 71, Vector3(50, -8, -150)]]]))
	print("  %s" % _said(rim))
	_ok(not Tested.passed(rim) and _why(rim, "whole").contains("where it has no stud"),
		"a cheese slope on a 6 x 6 round plate's rim, where it has no stud, is not: %s" % _why(rim, "whole"))

	print("\na real set, its figures and stretcher beside it")
	var filed: String = FileAccess.get_file_as_string(AMBULANCE)
	var ambulance: Dictionary = await _test(filed)
	print("  %s" % _said(ambulance))
	_ok(_why(ambulance, "whole") == "1 pair of parts passes into each other: Plate 1 x 6 into Plate 1 x 2 by 4 LDU",
		"6680-1's figures and stretcher are builds of their own; its file puts a 1 x 2 plate inside a 1 x 6 one: %s"
		% _why(ambulance, "whole"))
	_ok(filed.contains(MISPLACED), "...the plate's line is in the file as filed")
	var mended: Dictionary = await _test(filed.replace(MISPLACED, "0 // " + MISPLACED))
	print("  %s" % _said(mended))
	_ok(Tested.passed(mended) and _why(mended, "whole").begins_with("4 builds"),
		"...without that plate, which its steps hide too, the ambulance, its figures and its stretcher are Tested: %s"
		% Tested.words(mended))
	for path: String in TWO_BUILDS:
		var found: Dictionary = await _test(FileAccess.get_file_as_string(path))
		print("  %s: %s" % [path.get_file(), _said(found)])
		_ok(_passes(found, "whole") and _why(found, "whole").begins_with("2 builds"),
			"%s, a vehicle and a figure beside it, passes the whole test as two builds: %s" % [
			path.get_file(), _why(found, "whole")])

	print("\nthe models the app ships")
	for path: String in SHIPPED:
		var found: Dictionary = await _test(FileAccess.get_file_as_string(path))
		print("  %s" % _said(found))
		_ok(_passes(found, "whole"), "%s has every part held, none in another: %s" % [
			path.get_file(), _why(found, "whole")])
		_ok(Tested.passed(found),
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
			"%s has every part held, none in another, and is %s" % [file,
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
		and whole.contains("pass into each other") and whole.contains("pieces are held by nothing"),
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
