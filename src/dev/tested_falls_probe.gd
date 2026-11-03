## Tested's whole test says a part falls only when it does: a part is where
## its real shape is, not where its box turned with it reaches, and a piece
## is judged by the parts it rests on another by, not by every part it is
## built of.
##
##   godot --headless --path . --script src/dev/tested_falls_probe.gd
##
## stability (2026-11-03): once 310 parts had their exact shapes (exactmiss),
## two real sets were said to fall that stand. 6043-1's floor was taken from
## a held halberd's box turned with it, 7.7 LDU under the ground, so its
## trebuchet stood 7.7 over the floor and fell; and ExactCheck.rests took
## the raised arm of the driver in 928-1's buggy for a part tilted loose.
## Each is built small here, from its set's own lines, and is not said to
## fall. What really falls still does: a part in the air, a plate resting
## past the edge of the tile under it, and a tile lying on a slope's face
## with nothing joining it.
extends SceneTree

const DEFENDER := "res://vendor/omr/files/6043-1.mpd"
const EXPLORER := "res://vendor/omr/files/928-1.mpd"

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
		print("tested_falls probe: SKIPPED, no exact shapes in this build")
		quit(3)
		return

	var stack: Array = ["1 4 -100 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 4 -100 -48 0 1 0 0 0 1 0 0 0 1 3001.dat"]

	print("\nstands, and is not said to fall")
	# 6043-1's halberdier holds the halberd turned two ways: its box reaches
	# 7.7 LDU under the ground the figure stands on, and the floor was taken
	# from it, so the stack beside it stood over the floor, held by nothing.
	var halberdier: String = _section(DEFENDER, "6043 - Halberdier.ldr")
	var beside: Dictionary = await _test(_model("beside", [stack,
		["1 16 40 -28 0 1 0 0 0 1 0 0 0 1 6043 - Halberdier.ldr"]], halberdier))
	print("  %s" % _said(beside))
	_ok(not _falls(beside) and _passes(beside, "whole") and _why(beside, "whole").begins_with("2 builds"),
		"a stack beside 6043-1's halberdier, the halberd turned in a hand, is two builds on one floor: %s"
		% _why(beside, "whole"))
	# 928-1's driver raises an arm, a hand and a torch, each held turned by its
	# joint, in the buggy standing on the studs of the plate under it.
	var buggy: String = _section(EXPLORER, "928 - Space Buggy.ldr") \
		+ _section(EXPLORER, "928 - White Minifig2.ldr")
	# Its 23 parts rest on the plate, joined to it by nothing, and come away in
	# the hand, as the set's own buggy does off its baseplate. (Its airtanks,
	# on a jumper's stud through the hole a neck goes in, fall in the set too.)
	var parked: Dictionary = await _test(_model("parked", [["1 7 0 0 0 1 0 0 0 1 0 0 0 1 3958.dat"],
		["1 16 0 -4 0 1 0 0 0 1 0 0 0 1 928 - Space Buggy.ldr"]], buggy))
	print("  %s" % _said(parked))
	var buggy_said: Array = (Tested.said_all.get("whole", []) as Array).filter(func(one: String) -> bool:
		return one.contains(" and 22 parts with it "))
	_ok(buggy_said.size() == 1 and str(buggy_said[0]).ends_with(" rests on Plate 6 x 6"),
		"928-1's buggy, its driver's arm raised, rests on a plate's studs, and is not said to fall: %s"
		% str(buggy_said))

	print("\nfalls, and is said to")
	var floating: Dictionary = await _test(_model("floating", [stack,
		["1 4 -100 -90 0 1 0 0 0 1 0 0 0 1 3004.dat"]]))
	print("  %s" % _said(floating))
	_ok(_falls(floating, "Brick 1 x 2"), "a 1 x 2 brick in the air over the stack falls: %s"
		% _why(floating, "whole"))
	# A 2 x 2 tile on a brick's studs, and a 1 x 6 plate lying on the tile's
	# smooth top with its middle 30 LDU past the tile's edge.
	var tiled: Array = ["1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 4 0 -32 0 1 0 0 0 1 0 0 0 1 3068b.dat"]
	var overhang: Dictionary = await _test(_model("overhang", [tiled,
		["1 1 50 -40 0 1 0 0 0 1 0 0 0 1 3666.dat"]]))
	print("  %s" % _said(overhang))
	_ok(_falls(overhang, "Plate 1 x 6"), "a 1 x 6 plate lying past the edge of the tile under it falls: %s"
		% _why(overhang, "whole"))
	# A 1 x 2 tile lying flat on a 45 degree slope's face, half a LDU off it:
	# all of it touches, its middle over the middle of the face, and it slides.
	var slope: Dictionary = await _test(_model("slope", [["1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 4 0 -48 10 1 0 0 0 1 0 0 0 1 3039.dat"],
		["1 1 0 -44.01 -16.01 1 0 0 0 0.707107 -0.707107 0 0.707107 0.707107 3069b.dat"]]))
	print("  %s" % _said(slope))
	_ok(_falls(slope, "Tile 1 x 2") and (Tested.said_all.get("whole", []) as Array).size() == 1,
		"a 1 x 2 tile lying on a slope's face, joined to nothing, falls, and nothing else is said: %s"
		% _why(slope, "whole"))

	print("%d FAILED" % _failures if _failures else
		"a part is said to fall when it falls, and not when it stands")
	quit(1 if _failures else 0)


func _test(text: String) -> Dictionary:
	return (await SharedPages.attach_tested(text, _library, _store))["tested"]


## Whether the whole test says a part falls: [param part], when given, the
## part said.
func _falls(found: Dictionary, part: String = "") -> bool:
	for one: String in (Tested.said_all.get("whole", []) as Array):
		if (one.contains(" falls off ") or one.ends_with(" falls")) and one.begins_with(part):
			return true
	return false


## The lines of [param file]'s sub-model [param name], from its FILE line to
## the next.
func _section(file: String, name: String) -> String:
	var out := PackedStringArray()
	var inside: bool = false
	for line: String in FileAccess.get_file_as_string(file).split("\n"):
		if line.begins_with("0 FILE "):
			if inside:
				break
			inside = line.strip_edges() == "0 FILE " + name
		if inside:
			out.append(line.strip_edges(false, true))
	return "\r\n".join(out) + "\r\n"


func _passes(found: Dictionary, test: String) -> bool:
	return bool(((found.get("tests", {}) as Dictionary).get(test, {}) as Dictionary).get("ok", false))


func _why(found: Dictionary, test: String) -> String:
	return str(((found.get("tests", {}) as Dictionary).get(test, {}) as Dictionary).get("why", ""))


func _said(found: Dictionary) -> String:
	if found.is_empty() or not found.has("tests"):
		return "not tested: %s" % str(found.get("untested", ""))
	return "%d parts: whole %s (%s)" % [int(found.get("parts", 0)),
		"ok" if _passes(found, "whole") else "FAILS", _why(found, "whole")]


## A model in steps of LDraw lines, with [param more] (its sub-models) after.
func _model(name: String, steps: Array, more: String = "") -> String:
	var lines := PackedStringArray(["0 FILE %s.ldr" % name, "0 %s" % name, "0 Name: %s.ldr" % name,
		"0 Author: Tested falls probe", ""])
	for step: Array in steps:
		lines.append_array(PackedStringArray(step))
		lines.append("0 STEP")
	return "\r\n".join(lines) + "\r\n\r\n" + more


func _ok(passed: bool, what: String) -> void:
	print(("ok   " if passed else "FAIL ") + what)
	if not passed:
		_failures += 1
