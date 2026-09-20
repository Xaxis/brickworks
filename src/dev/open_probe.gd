## Open a model the way the browser has to, and count what lands.
##
##   BRICKWORKS_API=... godot --path . --script src/dev/open_probe.gd
##
## The web build ships a few hundred parts and fetches the rest, so
## opening a model is not one operation — it is a placement now for what
## is resident and a placement later for everything else. That second
## half did not exist: a part whose geometry had not arrived was dropped
## and mentioned in a warning nobody reads, so you opened a lighthouse
## and got most of a lighthouse.
##
## The check is the same model twice. Once with the whole library on
## disk, which is the answer, and once with only the pack and the
## bucket, which is what a browser has.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	var library: PartLibrary = main.get("_library")
	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var models: Array[ModelStore.Entry] = (main.get("_store") as ModelStore).list_examples()

	# What the model actually contains, with everything to hand.
	var expected: Dictionary = {}
	for entry: ModelStore.Entry in models:
		world.clear()
		builder.lattice.clear()
		main._open(entry.path)
		await process_frame
		expected[entry.name] = world.brick_count()

	# Now as a browser sees it: the pack on disk, the rest over the wire.
	library._root = PartLibrary.PACK_ROOT
	if not library.load_catalogue():
		print("no web pack — tools/web_pack.py")
		quit(1)
		return
	library.release_geometry()
	library.remote_parts = _parts_url()
	print("  pack loaded, fetching from %s" % library.remote_parts)
	print("")

	for entry: ModelStore.Entry in models:
		world.clear()
		builder.lattice.clear()
		main.set("_awaited", [] as Array[LdrModel.Placement])
		main.set("_unavailable", {})

		var want: int = int(expected[entry.name])
		main._open(entry.path)

		# Wait on real time: the parts arrive over the network, and a
		# frame budget in a headless run expires in about a second.
		var deadline: int = Time.get_ticks_msec() + 120_000
		while world.brick_count() < want and Time.get_ticks_msec() < deadline:
			await process_frame

		_check("%s: %d of %d bricks" % [entry.name, world.brick_count(), want],
			world.brick_count() == want)

	print("")
	print("%d failed" % _failures if _failures
		else "every model opens whole, over the wire")
	quit(1 if _failures else 0)


static func _parts_url() -> String:
	var file: FileAccess = FileAccess.open("res://.env", FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with("PARTS_URL="):
			return line.substr(10).strip_edges()
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
