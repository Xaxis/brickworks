## The Tested mark on model files, without publishing them: its four tests
## (stands, steps, parts, whole) and why each failed, as the Share panel works
## them out (SharedPages.attach_tested, src/assembly/tested.gd).
##
##   godot --headless --path . --script tools/house_models/tested_check.gd -- FILE.ldr ...
##
## About a minute, most of it the catalogue. Used by seed211 (2026-10-24) to
## check each house model by hand between fixes; the gallery seed's Godot half
## (src/dev/gallery_seed.gd) is the last word, the panel's own run.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
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
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	await process_frame
	var passed: int = 0
	for path: String in OS.get_cmdline_user_args():
		var found: Dictionary = (await SharedPages.attach_tested(FileAccess.get_file_as_string(path),
			library, store))["tested"]
		passed += 1 if Tested.passed(found) else 0
		print("%s: %s" % [path.get_file(), "TESTED" if Tested.passed(found) else "not tested"])
		if not found.has("tests"):
			print("   untested: %s" % str(found.get("untested", "")))
			continue
		print("   %d parts, %d steps, %d ms" % [int(found.get("parts", 0)), int(found.get("steps", 0)),
			int(found.get("ms", 0))])
		for test: String in ["stands", "steps", "parts", "whole"]:
			var t: Dictionary = (found.get("tests", {}) as Dictionary).get(test, {})
			print("   %s %s: %s" % [test, "ok" if bool(t.get("ok", false)) else "FAILS", str(t.get("why", ""))])
	quit(0 if passed == OS.get_cmdline_user_args().size() else 1)
