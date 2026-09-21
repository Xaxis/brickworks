## Rewrite the shipped models with the numbers those parts have now.
##
## A migration, not a probe: it edits the repository. Named so that
## whoever runs every probe in this directory does not run it too.
##
##   godot --headless --path . --script src/dev/retire_models.gd
##
## Placing a brick resolves a retired number to the part it became, so
## anything built from now on is clean. The files already on disk are
## not: three of them name 3023, which LDraw retired in favour of
## 3023b, and the parts list prints "~Moved to 3023b" where the name
## should be.
##
## Opening and saving is the whole migration — the open resolves, the
## save writes what was resolved — so this is mostly a loop and a
## check that nothing else moved in the process.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.builder = builder
	store.library = library

	var here: DirAccess = DirAccess.open("res://models")
	for file: String in here.get_files():
		if not file.ends_with(".ldr"):
			continue
		var path: String = "res://models/%s" % file
		var before: int = store.open(path)
		if before == 0:
			print("  %-16s could not open" % file)
			_failures += 1
			continue

		var retired := PackedStringArray()
		for brick: BrickWorld.Brick in world.bricks():
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			if info != null and info.is_redirect():
				retired.append(brick.part_id)
		if not retired.is_empty():
			_failures += 1
			print("  FAIL  %-16s still holds %s after opening"
				% [file, ", ".join(retired)])
			continue

		var text: String = store.to_text(
			file.get_basename().capitalize())
		var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if out == null:
			print("  %-16s could not be written" % file)
			_failures += 1
			continue
		out.store_string(text)
		out.close()

		# And it still opens to the same model afterwards, or the
		# migration has cost something.
		var after: int = store.open(path)
		if after == before:
			print("  ok    %-16s %d bricks, rewritten" % [file, after])
		else:
			_failures += 1
			print("  FAIL  %-16s was %d bricks and is now %d"
				% [file, before, after])

	print("")
	if _failures == 0:
		print("every shipped model names parts that still exist")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
