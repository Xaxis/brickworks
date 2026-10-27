## The Tested mark's four tests (Tested), headless, on models whose answers
## are known: each test passed by one and failed by another, with the reason
## said.
##
##   godot --headless --path . --script src/dev/tested_probe.gd
##   godot --headless --path . --script src/dev/tested_probe.gd -- --sets FILE.mpd ...
##   godot --headless --path . --script src/dev/tested_probe.gd -- --write IN OUT [IN OUT...]
##
## A real set from vendor/omr, whose own steps stand (stands, parts), and
## whose figures stand beside its car as builds of their own (whole);
## three bricks stacked in order, and the same with the top one put in a step
## before what holds it (steps: in the air), and with the top two (a
## sub-assembly built in the hand, passed); a closed box with a brick put in
## it after its roof (steps: hidden, from every side and from below), and a
## plate put under a bigger one's edge, seen with the model turned over
## (passed); an arm that tips its base over onto
## the arm's tip, and lies there whole (stands, passed), and a table on one
## leg that a stack on one stud tips over, the stud letting go as it lies
## (stands, failed); a 1 x 1 brick in a colour it was never made in (parts);
## a brick held by nothing (whole). And the time on a model of about 2,000
## parts.
##
## --sets prints the four results for each file, and how long they took.
## --write puts the steps in each IN, as the Share panel does, and writes it
## to OUT with what it found beside it as OUT.tested.json: the tested flow
## publishes those (tools/web/tested_flow.mjs).
extends SceneTree

const BIG := "res://vendor/omr/files/10218-1.mpd"
const REAL := "res://vendor/omr/files/6680-1.mpd"

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
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
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "--sets":
		for n: int in range(1, args.size()):
			var found: Dictionary = await _test(FileAccess.get_file_as_string(args[n]))
			print("%s: %s" % [args[n].get_file(), _said(found)])
			print("  laps (ms): %s" % str(Tested.laps.keys().map(func(key: String) -> String:
				return "%s %d" % [key, int(Tested.laps[key]) / 1000])))
		quit(0)
		return
	if args.size() > 0 and args[0] == "--write":
		for n: int in range(1, args.size() - 1, 2):
			var made: Dictionary = await SharedPages.attach_tested(
				FileAccess.get_file_as_string(args[n]), _library, _store)
			var file := FileAccess.open(args[n + 1], FileAccess.WRITE)
			file.store_string(str(made["text"]))
			file.close()
			var finding := FileAccess.open(args[n + 1] + ".tested.json", FileAccess.WRITE)
			finding.store_string(JSON.stringify(made["tested"]))
			finding.close()
			print("%s -> %s: %s" % [args[n], args[n + 1], _said(made["tested"])])
		quit(0)
		return

	print("\na real set, built by its own steps")
	var real: Dictionary = await _test(FileAccess.get_file_as_string(REAL))
	print("  %s" % _said(real))
	_ok(_passes(real, "stands"), "6680-1 stands at every one of its own steps: %s" % _why(real, "stands"))
	_ok(_passes(real, "parts"), "...every part of it is made in its colour: %s" % _why(real, "parts"))
	# Its two figures and its stretcher stand beside the ambulance, builds of
	# their own. The file puts a 1 x 2 plate inside a 1 x 6 one (6680 -
	# main.ldr, 3023 at 30 -16 150 in the 3666 at 30 -16 110), which the exact
	# check finds, and which is the plate its steps hide.
	_ok(_why(real, "whole") == "1 pair of parts passes into each other: Plate 1 x 6 into Plate 1 x 2 by 4 LDU",
		"...its figures and stretcher are builds of their own, and the whole test names only the plate the file puts in another: %s"
		% _why(real, "whole"))

	print("\nthe order of the steps")
	var stacked: Dictionary = await _test(_model("stacked", [
		[["3001", 4, Vector3(0, 0, 0)]], [["3001", 1, Vector3(0, -24, 0)]], [["3001", 14, Vector3(0, -48, 0)]]]))
	print("  %s" % _said(stacked))
	_ok(Tested.passed(stacked), "three bricks stacked in order pass all four: %s" % _said(stacked))
	var air: Dictionary = await _test(_model("in the air", [
		[["3001", 4, Vector3(0, 0, 0)]], [["3001", 14, Vector3(0, -48, 0)]], [["3001", 1, Vector3(0, -24, 0)]]]))
	print("  %s" % _said(air))
	_ok(not _passes(air, "steps") and _why(air, "steps").contains("Step 2: Brick 2 x 4 is put down in the air"),
		"the top one put in before what holds it fails steps, saying where: %s" % _why(air, "steps"))
	_ok(_passes(air, "whole"), "...and is not loose, since the finished model holds it")
	var boxed: Dictionary = await _test(_closed_box())
	print("  %s" % _said(boxed))
	_ok(not _passes(boxed, "steps") and _why(boxed, "steps").contains("hidden behind what is already built"),
		"a brick put in a box after its roof fails steps as hidden: %s" % _why(boxed, "steps"))
	# A booklet turns a model over to build its underside: a 1 x 1 plate
	# under a 6 x 6 plate's edge, hidden from every side above.
	var under: Dictionary = await _test(_model("under", [
		[["3001", 4, Vector3(0, 0, 0)]], [["3958", 7, Vector3(0, -8, 0)]], [["3024", 14, Vector3(50, 0, 0)]]]))
	print("  %s" % _said(under))
	_ok(_passes(under, "steps"), "a plate put under a bigger one's edge is seen with the model turned over: %s"
		% _why(under, "steps"))
	# Two bricks put down in the air, one on the other, and then the brick
	# under them: a sub-assembly built in the hand, as a booklet's callout.
	var hand: Dictionary = await _test(_model("in the hand", [
		[["3001", 4, Vector3(0, 0, 0)]], [["3001", 14, Vector3(0, -48, 0)]], [["3001", 1, Vector3(0, -72, 0)]],
		[["3001", 1, Vector3(0, -24, 0)]]]))
	print("  %s" % _said(hand))
	_ok(_passes(hand, "steps"), "two bricks built in the hand and then put on pass steps: %s" % _why(hand, "steps"))

	print("\nstanding up")
	# Tipping is no fault: a build is set down as a builder would (tested305).
	# An arm eight studs long tips its 1 x 2 base over onto the arm's tip, 11
	# degrees, and lies there whole, its two studs carrying almost nothing.
	var arm: Dictionary = await _test(_model("arm", [
		[["3004", 4, Vector3(0, 0, 0)]], [["3008", 1, Vector3(60, -24, 0)]], [["3008", 1, Vector3(60, -48, 0)]]]))
	print("  %s" % _said(arm))
	_ok(_passes(arm, "stands"),
		"an arm eight studs long tips its 1 x 2 base over onto its own tip, and lies there whole: %s"
		% _why(arm, "stands"))
	# A 6 x 16 plate on a leg of six 2 x 2 bricks, and on it a stack of 4 x 12
	# bricks on the one stud of a 1 x 1 round plate. Past the leg, the stack
	# tips the table over onto its edge, 46 degrees, and leaning so the stack
	# hangs from that stud: five bricks it holds, eight it lets go.
	var held: Dictionary = await _test(_table(5))
	print("  %s" % _said(held))
	_ok(_passes(held, "stands"), "a table that a stack of five tips over onto its edge holds them: %s"
		% _why(held, "stands"))
	var table: Dictionary = await _test(_table(8))
	print("  %s" % _said(table))
	_ok(not _passes(table, "stands") and _why(table, "stands").begins_with("At step 4 it tipped over")
		and _why(table, "stands").contains("Plate 1 x 1 Round is held by Plate 6 x 16 on 1 stud past where it lets go"),
		"...a stack of eight on its one stud comes away as it lies, and fails stands at the step it goes on: %s"
		% _why(table, "stands"))
	_ok(_passes(table, "whole") and _passes(table, "steps"), "...though it goes together, a step at a time")
	_ok(_passes(stacked, "stands"), "...where three bricks stacked stand: %s" % _why(stacked, "stands"))

	print("\nits colours")
	var code: int = _never_made("3005")
	_ok(code >= 0, "a colour the 1 x 1 brick was never made in: %s (%d)" % [
		HiddenColours.colour_name(_library, code), code])
	var odd: Dictionary = await _test(_model("odd colour", [
		[["3001", 4, Vector3(0, 0, 0)]], [["3005", code, Vector3(-30, -24, -10)]]]))
	print("  %s" % _said(odd))
	_ok(not _passes(odd, "parts") and _why(odd, "parts").contains("Brick 1 x 1")
		and _why(odd, "parts").contains("never made in %s" % HiddenColours.colour_name(_library, code)),
		"a 1 x 1 brick in it fails parts, naming it and the colour: %s" % _why(odd, "parts"))
	_ok(_passes(stacked, "parts"), "...where bricks in red, blue and yellow pass: %s" % _why(stacked, "parts"))

	print("\nheld together")
	var loose: Dictionary = await _test(_model("loose", [
		[["3001", 4, Vector3(0, 0, 0)]], [["3001", 1, Vector3(0, -24, 0)]], [["3005", 14, Vector3(200, -120, 0)]]]))
	print("  %s" % _said(loose))
	_ok(not _passes(loose, "whole") and _why(loose, "whole").contains("1 piece is held by nothing")
		and _why(loose, "whole").contains("Brick 1 x 1 falls"),
		"a brick held by nothing fails whole, naming it: %s" % _why(loose, "whole"))
	_ok(_passes(loose, "steps"), "...and is not held against its step too: %s" % _why(loose, "steps"))
	_ok(Tested.words(loose).begins_with("Not marked Tested") and Tested.words(stacked).begins_with("Marked Tested"),
		"the share panel says which, plainly: \"%s\"" % Tested.words(loose))

	print("\nthe finding names its file")
	var made: Dictionary = await SharedPages.attach_tested(_model("named", [[["3001", 4, Vector3.ZERO]]]),
		_library, _store)
	_ok(str(made["tested"].get("model", "")) == Tested.fingerprint(str(made["text"]))
		and str(made["tested"].get("app", "")) == BuildInfo.version(),
		"what it found is of the text with its steps carried, by app %s" % BuildInfo.version())

	print("\na model of about 2,000 parts")
	var began: int = Time.get_ticks_msec()
	var big: Dictionary = await _test(FileAccess.get_file_as_string(BIG))
	var whole_ms: int = Time.get_ticks_msec() - began
	print("  %s" % _said(big))
	_ok(not big.is_empty() and int(big.get("parts", 0)) >= 1800,
		"10218-1, %d parts in %d steps: the tests take %d ms of the %d ms its steps and tests take" % [
			int(big.get("parts", 0)), int(big.get("steps", 0)), int(big.get("ms", 0)), whole_ms])

	print("%d FAILED" % _failures if _failures else
		"each of the four tests passes a model that should and fails one that should not, saying why")
	quit(1 if _failures else 0)


func _test(text: String) -> Dictionary:
	return (await SharedPages.attach_tested(text, _library, _store))["tested"]


func _passes(found: Dictionary, test: String) -> bool:
	return bool(((found.get("tests", {}) as Dictionary).get(test, {}) as Dictionary).get("ok", false))


func _why(found: Dictionary, test: String) -> String:
	return str(((found.get("tests", {}) as Dictionary).get(test, {}) as Dictionary).get("why", ""))


func _said(found: Dictionary) -> String:
	if found.is_empty():
		return "not tested"
	var out := PackedStringArray()
	for test: String in ["stands", "steps", "parts", "whole"]:
		out.append("%s %s (%s)" % [test, "ok" if _passes(found, test) else "FAILS", _why(found, test)])
	return "%d parts, %d steps, %d ms: %s" % [int(found.get("parts", 0)), int(found.get("steps", 0)),
		int(found.get("ms", 0)), "; ".join(out)]


## A model in its author's steps: each step a list of [part, colour, where].
func _model(name: String, steps: Array) -> String:
	var lines := PackedStringArray(["0 FILE %s.ldr" % name, "0 %s" % name, "0 Name: %s.ldr" % name,
		"0 Author: Tested probe", ""])
	for step: Array in steps:
		for one: Array in step:
			var at: Vector3 = one[2]
			lines.append("1 %d %s %s %s 1 0 0 0 1 0 0 0 1 %s.dat" % [int(one[1]),
				_n(at.x), _n(at.y), _n(at.z), str(one[0])])
		lines.append("0 STEP")
	return "\r\n".join(lines) + "\r\n"


static func _n(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)


## A floor, four walls two bricks high and a roof, and then a brick put in
## on the floor inside it.
func _closed_box() -> String:
	var floor_plate: Array = [["3958", 7, Vector3(0, 0, 0)]]
	var walls: Array = []
	for course: int in 2:
		var y: float = -24.0 - 24.0 * course
		walls.append(["3009", 4, Vector3(0, y, -50)])
		walls.append(["3009", 4, Vector3(0, y, 50)])
		walls.append(["3010", 4, Vector3(-50, y, 0)])
		walls.append(["3010", 4, Vector3(50, y, 0)])
	var roof: Array = [["3958", 7, Vector3(0, -56, 0)]]
	var steps: Array = [floor_plate, walls, roof, [["3005", 14, Vector3(10, -24, 10)]]]
	# The side walls turned a quarter, along z.
	return _quarter(_model("closed box", steps), "3010")


## A 6 x 16 plate on a leg of six 2 x 2 bricks, a 1 x 1 round plate on it
## and on that a stack of [param bricks] 4 x 12 bricks, their length across.
func _table(bricks: int) -> String:
	var leg: Array = []
	for course: int in 6:
		leg.append(["3003", 4, Vector3(0, -24 * course, 0)])
	var stack: Array = []
	for course: int in bricks:
		stack.append(["4202", 1, Vector3(40, -160 - 24 * course, 0)])
	return _quarter(_model("table", [leg, [["3027", 71, Vector3(0, -128, 0)]],
		[["6141", 14, Vector3(50, -136, 10)]], stack]), "4202")


## [param text] with each of [param part] turned a quarter about the vertical.
func _quarter(text: String, part: String) -> String:
	var lines: PackedStringArray = text.split("\r\n")
	for n: int in lines.size():
		if lines[n].ends_with(part + ".dat"):
			var bits: PackedStringArray = lines[n].split(" ")
			bits[5] = "0"
			bits[7] = "1"
			bits[11] = "-1"
			bits[13] = "0"
			lines[n] = " ".join(bits)
	return "\r\n".join(lines)


## A colour [param part] was never made in, by the catalogue, that LDraw
## knows: -1 when it knows none.
func _never_made(part: String) -> int:
	var info: PartLibrary.PartInfo = _library.parts.get(part)
	if info == null:
		return -1
	var codes: Array = _library.colors.keys()
	codes.sort()
	for code: Variant in codes:
		if int(code) in [16, 24] or int(code) >= 1000:
			continue
		if info.never_made_in(int(code)):
			return int(code)
	return -1


func _ok(passed: bool, what: String) -> void:
	print(("ok   " if passed else "FAIL ") + what)
	if not passed:
		_failures += 1
