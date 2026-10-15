## The exact check's findings in LDraw files, to set beside BrickBench's own.
##
##   godot --headless --path . --script src/dev/exact_dump.gd -- --out=FILE MODEL.ldr ...
##
## Each file is opened as File, Open opens it; every pair of parts whose
## exact shapes overlap by more than 1 LDU (Exact.clashes) and BrickNet's
## connection pieces (Exact.connections) go out as one JSON line a file:
## {file, parts, shaped, pairs: [[a, b, part a, part b, depth]], pieces,
## largest, seconds}, a and b in the file's order of parts. A tool for
## comparing with verify.py, not a check: it passes or fails nothing.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_path: String = "user://exact_dump.jsonl"
	var files: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		else:
			files.append(argument)
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
	var out := FileAccess.open(out_path, FileAccess.WRITE)
	if out == null:
		print("cannot write %s" % out_path)
		quit(1)
		return
	for path: String in files:
		var started: int = Time.get_ticks_msec()
		store.open_text(FileAccess.get_file_as_string(path), path.get_file())
		var bricks: Array = world.bricks()
		var items: Array = []
		var shaped: int = 0
		for brick: BrickWorld.Brick in bricks:
			var shape: Exact.Shape = Exact.shape_for(library, brick.part_id)
			if shape != null and shape.has_pieces():
				shaped += 1
			items.append(Exact.Item.new(shape, brick.transform) if shape != null else null)
		var loaded: int = Time.get_ticks_msec()
		var pairs: Array = []
		for found: Dictionary in Exact.clashes(items):
			var a: BrickWorld.Brick = bricks[int(found["a"])]
			var b: BrickWorld.Brick = bricks[int(found["b"])]
			pairs.append([int(found["a"]), int(found["b"]), a.part_id, b.part_id,
				snappedf(float(found["depth"]), 0.001)])
		var clashed: int = Time.get_ticks_msec()
		var edges: Array = Exact.connections(items)
		var root: PackedInt32Array = Exact.pieces(items.size(), edges)
		var sizes: Dictionary = {}
		for r: int in root:
			sizes[r] = int(sizes.get(r, 0)) + 1
		var largest: int = 0
		for r: Variant in sizes:
			largest = maxi(largest, int(sizes[r]))
		var row: Dictionary = {"file": path.get_file(), "parts": bricks.size(), "shaped": shaped,
			"pairs": pairs, "pieces": sizes.size(), "largest": largest, "edges": edges.size(),
			"load_s": float(loaded - started) / 1000.0, "clash_s": float(clashed - loaded) / 1000.0,
			"connect_s": float(Time.get_ticks_msec() - clashed) / 1000.0}
		out.store_line(JSON.stringify(row))
		out.flush()
		print("  %s: %d parts (%d shaped), %d pairs, %d pieces, clash %.2f s, connect %.2f s" % [
			path.get_file(), bricks.size(), shaped, pairs.size(), sizes.size(),
			row["clash_s"], row["connect_s"]])
	out.close()
	quit(0)
