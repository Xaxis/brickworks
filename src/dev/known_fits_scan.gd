## Every pair of parts whose exact shapes pass into each other in the LDraw
## model repository's official sets, for tools/known_fits.py to learn the
## fits real sets are built with (KnownFits).
##
##   godot --headless --path . --script src/dev/known_fits_scan.gd -- [--shard=K/N] [--out=FILE] [--fits] [FILE.mpd ...]
##
## Each file is opened as File, Open opens it and judged as Tested's whole
## test judges collisions (Tested._exact_whole): every pair the exact shapes
## find overlapping by more than 1 LDU, less gears in mesh and what
## ExactCheck.forgiven forgives at a joint or on an axle, but not what
## KnownFits forgives, which is what this is for. One JSON line a file:
##   {file, parts, shaped, forgiven, seconds, pairs: [{a, b, ka, kb, d, m, rel}]}
## a and b the part ids, ka and kb their kinds (KnownFits.kind_of: "torso",
## "hand", ...; "" for a part that is not a minifigure's), d the depth the
## check says and m the deepest any two of their convex pieces meet, LDU,
## and rel where b stands in a's frame (origin, then the basis's columns).
## A line {file, begin} goes out before each file, and a rerun with the same
## out file carries on after the files already done. With --kinds=FILE it
## writes every catalogue part's kind instead (the table's "kinds"). With
## --fits it leaves out what KnownFits forgives too (ExactCheck.forgiven, as
## the check does), so its pairs are what the check still refuses.
## Not in the suite: an hour or more over the whole repository.
extends SceneTree

const SETS := "res://vendor/omr/files"

var _library: PartLibrary
var _world: BrickWorld
var _store: ModelStore
var _fits: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	var shard: int = 0
	var shards: int = 1
	var out_path: String = "user://known_fits_scan.jsonl"
	var kinds_path: String = ""
	var named: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shard="):
			var said: PackedStringArray = argument.trim_prefix("--shard=").split("/")
			shard = int(said[0])
			shards = maxi(1, int(said[1]))
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--kinds="):
			kinds_path = argument.trim_prefix("--kinds=")
		elif argument == "--fits":
			_fits = true
		else:
			named.append(argument)
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	if not kinds_path.is_empty():
		quit(_write_kinds(kinds_path))
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	var builder := Builder.new()
	builder.world = _world
	builder.library = _library
	get_root().add_child(builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = builder
	_store.keeps = false
	await process_frame
	if Exact.shape_for(_library, "3001") == null:
		print("known_fits_scan: no exact shapes in this build")
		quit(1)
		return

	var files: Array = named
	if files.is_empty():
		var all: Array = Array(DirAccess.get_files_at(SETS)).filter(
			func(f: String) -> bool: return f.ends_with(".mpd") or f.ends_with(".ldr"))
		all.sort()
		for n: int in all.size():
			if n % shards == shard:
				files.append(SETS.path_join(all[n]))
	var done: Dictionary = {}
	if FileAccess.file_exists(out_path):
		for line: String in FileAccess.get_file_as_string(out_path).split("\n"):
			var row: Variant = JSON.parse_string(line) if not line.is_empty() else null
			if row is Dictionary and not (row as Dictionary).has("begin"):
				done[str(row["file"])] = true
	var out := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path)
		else FileAccess.WRITE)
	if out == null:
		print("cannot write %s (%s)" % [out_path, error_string(FileAccess.get_open_error())])
		quit(1)
		return
	out.seek_end()
	for path: String in files:
		if done.has(path.get_file()):
			continue
		out.store_line(JSON.stringify({"file": path.get_file(), "begin": true}))
		out.flush()
		var row: Dictionary = _scan(path)
		out.store_line(JSON.stringify(row))
		out.flush()
		print("  %s: %d parts, %d pairs, %.1f s" % [path.get_file(), int(row["parts"]),
			(row["pairs"] as Array).size(), float(row["seconds"])])
	out.close()
	quit(0)


func _scan(path: String) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	_store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	var bricks: Array = _world.bricks()
	var ids: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		ids[brick.part_id] = true
	var shapes: Dictionary = Exact.shapes_for(_library, ids.keys())
	var count: int = bricks.size()
	var exact := ExactCheck.new(shapes, count)
	var entries: Array = []
	var floor_y: float = INF
	var shaped: int = 0
	for n: int in count:
		var brick: BrickWorld.Brick = bricks[n]
		exact.place(n, brick.part_id, brick.transform)
		var item: Exact.Item = exact.items[n]
		if item != null:
			shaped += 1
			floor_y = minf(floor_y, item.lo.y)
		entries.append([n, brick.transform, _library.mesh_for(brick.part_id), brick.part_id])
	exact.ground = floor_y if floor_y < INF else 0.0
	var meshing: Dictionary = Joints.meshing(entries)
	var pairs: Array = []
	var forgiven: int = 0
	for found: Dictionary in exact.collisions({}):
		var a: int = found["a"]
		var b: int = found["b"]
		if (meshing.get(a, {}) as Dictionary).has(b) or (meshing.get(b, {}) as Dictionary).has(a):
			continue
		if exact.forgiven(a, b) if _fits else \
				exact.turned_on_axle(a, b) or not exact.at_joint(a, b).is_empty():
			forgiven += 1
			continue
		var deepest: float = 0.0
		for hit: Array in Exact.overlaps(exact.items[a], exact.items[b]):
			deepest = maxf(deepest, float(hit[0]))
		var pa: String = (bricks[a] as BrickWorld.Brick).part_id
		var pb: String = (bricks[b] as BrickWorld.Brick).part_id
		var rel: Transform3D = (bricks[a] as BrickWorld.Brick).transform.affine_inverse() \
			* (bricks[b] as BrickWorld.Brick).transform
		pairs.append({"a": pa, "b": pb, "ka": KnownFits.kind_for(_library, pa),
			"kb": KnownFits.kind_for(_library, pb), "d": snappedf(float(found["depth"]), 0.001),
			"m": snappedf(deepest, 0.001), "rel": [snappedf(rel.origin.x, 0.01),
			snappedf(rel.origin.y, 0.01), snappedf(rel.origin.z, 0.01),
			snappedf(rel.basis.x.x, 0.001), snappedf(rel.basis.x.y, 0.001), snappedf(rel.basis.x.z, 0.001),
			snappedf(rel.basis.y.x, 0.001), snappedf(rel.basis.y.y, 0.001), snappedf(rel.basis.y.z, 0.001),
			snappedf(rel.basis.z.x, 0.001), snappedf(rel.basis.z.y, 0.001), snappedf(rel.basis.z.z, 0.001)]})
	return {"file": path.get_file(), "parts": count, "shaped": shaped, "forgiven": forgiven,
		"pairs": pairs, "seconds": float(Time.get_ticks_msec() - started) / 1000.0}


## Every catalogue part that is a minifigure's, by kind: {kind: [id, ...]}.
func _write_kinds(path: String) -> int:
	var out: Dictionary = {}
	for part_id: Variant in _library.parts:
		var kind: String = KnownFits.kind_for(_library, str(part_id))
		if kind.is_empty():
			continue
		if not out.has(kind):
			out[kind] = []
		(out[kind] as Array).append(str(part_id))
	for kind: Variant in out:
		(out[kind] as Array).sort()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("cannot write %s" % path)
		return 1
	file.store_string(JSON.stringify(out, "", true))
	file.close()
	print("kinds: %s" % ", ".join(out.keys().map(func(k: String) -> String:
		return "%s %d" % [k, (out[k] as Array).size()])))
	return 0
