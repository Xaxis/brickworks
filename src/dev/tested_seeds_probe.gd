## The Tested mark on the 30 real sets the gallery is seeded with from the
## LDraw library (tools/web/gallery_seeds/ldraw_library.json), each built by
## its modeller's own steps: each fails no more than tested301 left it
## ([constant MOST], lowered as the tests are put right), and still for each
## fault its file really has ([constant FAULTS]).
##
##   godot --headless --path . --script src/dev/tested_seeds_probe.gd
##   godot --headless --path . --script src/dev/tested_seeds_probe.gd -- --only=2,13 --dump=OUT.json
##
## tools296 seeded them (2026-10-26) and every one came back not Tested:
## whole 28, steps 22, parts 16, stands 9. Real sets built by millions do not
## all fail; most of those were the tests wrong (tested301). Put right: a
## tyre in Rubber Black is a Black one, an older file's colour code is the
## colour it meant, a part is made in what its other moulds were made in,
## an author's sub-model may be built in the hand, and a part is held by a
## joint the app reads besides BrickNet's.
## --only runs those of the list (1 is its first); --dump writes every
## failure each test found, in full (Tested.said_all), by set.
extends SceneTree

const LIST := "res://tools/web/gallery_seeds/ldraw_library.json"
## The most failures each seed may have, by test: stands, steps, parts,
## whole. As published (app 0.8.0) the 30 had 134, 525, 45 and 297, every
## seed failing one; at tested301, 83, 230, 22 and 263, and the 21st,
## 346-2 House with Car, Tested.
const MOST: Dictionary = {
	1: [0, 0, 0, 4], 2: [0, 16, 0, 8], 3: [1, 18, 0, 7], 4: [0, 43, 0, 8], 5: [2, 17, 0, 3],
	6: [0, 2, 0, 8], 7: [0, 9, 0, 2], 8: [0, 0, 0, 7], 9: [12, 25, 1, 25], 10: [0, 1, 1, 22],
	11: [34, 2, 1, 7], 12: [0, 8, 1, 16], 13: [0, 0, 0, 10], 14: [0, 14, 0, 12], 15: [0, 7, 0, 11],
	16: [9, 7, 0, 7], 17: [0, 6, 0, 9], 18: [0, 0, 0, 2], 19: [23, 5, 0, 7], 20: [0, 3, 0, 18],
	21: [0, 0, 0, 0], 22: [0, 6, 0, 5], 23: [0, 3, 0, 0], 24: [1, 0, 1, 2], 25: [0, 1, 0, 0],
	26: [0, 19, 0, 15], 27: [1, 18, 16, 20], 28: [0, 0, 1, 8], 29: [0, 0, 0, 17], 30: [0, 0, 0, 3],
}
## Faults the files really have, each still to be found: [seed, test, what
## it says]. Each set's own inventory (Rebrickable) has the part otherwise.
const FAULTS: Array = [
	# 6396-1 has 3009, the 1 x 6 brick, in White; 3067 is the old one, made in trans colours.
	[10, "parts", "Brick 1 x 6 without Centre Studs (2) never made in White"],
	# 42022-1's tan axle pin is 3749, without friction.
	[11, "parts", "Technic Axle Pin with Friction never made in Tan"],
	# 40138-1 has 10314, the curved brick without studs, in Dark Green.
	[12, "parts", "Brick 1 x 4 x 1.333 with Curved Top (2) never made in Dark Green"],
	# 5984-1's plates are Dark Purple and its gold Pearl Gold.
	[27, "parts", "Plate 1 x 10 (8) never made in Dark Blue Violet"],
	[27, "parts", "Cone 1 x 1 (3) never made in Chrome Gold"],
	# 6361-1's hook is Black.
	[28, "parts", "Crane Hook Metal 1 x 4 x 1 never made in Pearl Black"],
]

var _failures: int = 0
var _library: PartLibrary
var _store: ModelStore


func _initialize() -> void:
	_run()


func _arg(name: String) -> String:
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with("--%s=" % name):
			return given.substr(name.length() + 3)
	return ""


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
		print("tested_seeds probe: SKIPPED, no exact shapes in this build")
		quit(3)
		return

	var seeds: Array = JSON.parse_string(FileAccess.get_file_as_string(LIST))
	var only: Dictionary = {}
	for n: String in _arg("only").split(",", false):
		only[int(n)] = true
	var dump: Dictionary = {}
	var passed: int = 0
	var ran: int = 0
	for n: int in range(1, seeds.size() + 1):
		if not only.is_empty() and not only.has(n):
			continue
		var entry: Dictionary = seeds[n - 1]
		var text: String = FileAccess.get_file_as_string("res://" + str(entry["file"]))
		var made: Dictionary = await SharedPages.attach_tested(text, _library, _store)
		var found: Dictionary = made["tested"]
		ran += 1
		passed += 1 if Tested.passed(found) else 0
		print("%d %s: %s" % [n, entry["name"], _said(found)])
		var all: Dictionary = Tested.said_all.duplicate(true) if found.has("tests") else {}
		dump[str(n)] = {"name": entry["name"], "file": entry["file"], "ms": int(found.get("ms", 0)),
			"failed": Tested.failed(found), "all": all}
		var counts: Array = []
		for test: String in ["stands", "steps", "parts", "whole"]:
			var failed: bool = found.has("tests") and not _passes(found, test)
			counts.append((all.get(test, []) as Array).size() if failed else 0)
			if failed:
				for one: Variant in (all.get(test, []) as Array):
					print("    %s: %s" % [test, str(one)])
		var most: Array = MOST.get(n, [0, 0, 0, 0])
		_ok(found.has("tests") and range(4).all(func(k: int) -> bool: return int(counts[k]) <= int(most[k])),
			"%d %s fails no more than it did: %s of at most %s" % [n, entry["name"], str(counts), str(most)])
		var parts_said: String = " ".join(PackedStringArray(all.get("parts", [])))
		_ok(not parts_said.contains("Rubber"), "...and no part of it is never made in a rubber colour")
		for fault: Array in FAULTS:
			if int(fault[0]) == n:
				_ok((all.get(str(fault[1]), []) as Array).has(fault[2]),
					"...and its file's fault is found: %s" % str(fault[2]))
	if not _arg("dump").is_empty():
		var file := FileAccess.open(_arg("dump"), FileAccess.WRITE)
		file.store_string(JSON.stringify(dump, " "))
		file.close()
	print("%d of %d seeds Tested" % [passed, ran])
	if only.is_empty():
		_ok(passed >= 1, "at least one of the 30 is Tested")
	print("%d FAILED" % _failures if _failures else "each seed fails no more than it did, and for its file's own faults")
	quit(1 if _failures else 0)


func _passes(found: Dictionary, test: String) -> bool:
	return bool(((found.get("tests", {}) as Dictionary).get(test, {}) as Dictionary).get("ok", false))


func _said(found: Dictionary) -> String:
	if found.is_empty() or not found.has("tests"):
		return "not tested: %s" % str(found.get("untested", ""))
	var out := PackedStringArray()
	for test: String in ["stands", "steps", "parts", "whole"]:
		out.append("%s %s" % [test, "ok" if _passes(found, test) else "FAILS"])
	return "%d parts, %d steps, %d ms: %s" % [int(found.get("parts", 0)), int(found.get("steps", 0)),
		int(found.get("ms", 0)), ", ".join(out)]


func _ok(passed: bool, what: String) -> void:
	print(("ok   " if passed else "FAIL ") + what)
	if not passed:
		_failures += 1
