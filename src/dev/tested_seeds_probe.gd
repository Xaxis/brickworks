## The Tested mark on the 30 real sets the gallery is seeded with from the
## LDraw library (tools/web/gallery_seeds/ldraw_library.json), each built by
## its modeller's own steps: each passes, or fails only for a fault its file
## really has, named here.
##
##   godot --headless --path . --script src/dev/tested_seeds_probe.gd
##   godot --headless --path . --script src/dev/tested_seeds_probe.gd -- --only=2,13 --dump=OUT.json
##
## tools296 seeded them (2026-10-26) and every one came back not Tested:
## whole 28, steps 22, parts 16, stands 9. Real sets built by millions do not
## all fail; most of those were the tests wrong (tested301).
## --only runs those of the list (1 is its first); --dump writes every
## failure each test found, in full (Tested.said_all), by set.
extends SceneTree

const LIST := "res://tools/web/gallery_seeds/ldraw_library.json"

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
		dump[str(n)] = {"name": entry["name"], "file": entry["file"], "ms": int(found.get("ms", 0)),
			"failed": Tested.failed(found), "all": Tested.said_all.duplicate(true)}
		for test: String in Tested.failed(found):
			for one: Variant in (Tested.said_all.get(test, []) as Array):
				print("    %s: %s" % [test, str(one)])
	if not _arg("dump").is_empty():
		var file := FileAccess.open(_arg("dump"), FileAccess.WRITE)
		file.store_string(JSON.stringify(dump, " "))
		file.close()
	print("%d of %d seeds Tested" % [passed, ran])
	print("%d FAILED" % _failures if _failures else "every seed is Tested, or fails only for its file's own faults")
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
