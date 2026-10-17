## The collisions the exact check finds between parts real sets join by a joint.
##
##   godot --headless --path . --script src/dev/joint_collisions.gd -- [--shard=K/N] [--out=FILE] [--parts-only=LIST] [FILE.mpd ...]
##
## Every set in the LDraw model repository (vendor/omr/files) is built, so a
## pair of its parts the exact check calls colliding is a false refusal, and
## one joined by a ball, a clip on a bar, a hinge, a turntable or a pin is the
## refusal a design on joints meets (docs/DESIGN_SCORES.md, "Technique: joints
## held by their real shapes"). Each file is opened as File, Open opens it and placed as the check places a
## model read off the world (Assistant._joined_at); every pair of parts whose
## BrickNet pieces overlap by more than 1 LDU, less the pairs the check
## already excuses (gears in mesh, a wheel turned on its axle), is put down to
## the joint BrickNet's labels join the two by, or to none: what the check
## refused before it held a joint to be one. For a jointed pair each
## overlapping pair of pieces goes out with how far the overlap can reach from
## the joint (its ball, or its line), and whether the check now holds it to be
## the joint (ExactCheck.at_joint), which it no longer refuses: by_kind less
## at_joint is what is refused now. One JSON line a file:
##   {file, parts, shaped, pairs, by_kind: {kind: n}, at_joint: {kind: n},
##    jointed: [{a, b, kinds, depth, at_joint, hits: [[depth, [kind, reach]...]],
##      lines: the two as LDraw lines}],
##    seconds}
## A tool for measuring, not a check: it passes or fails nothing. Not in the
## suite: an hour over the whole repository.
extends SceneTree

const SETS := "res://vendor/omr/files"

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
	var shard: int = 0
	var shards: int = 1
	var out_path: String = "user://joint_collisions.jsonl"
	var named: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shard="):
			var said: PackedStringArray = argument.trim_prefix("--shard=").split("/")
			shard = int(said[0])
			shards = maxi(1, int(said[1]))
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif not argument.begins_with("--"):
			# --parts-only=FILE is PartsOnly's: a run kept to BrickBench's parts.
			named.append(argument)
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
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame

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
	var totals: Dictionary = {}
	var excused: Dictionary = {}
	for path: String in files:
		if done.has(_named(path)):
			continue
		out.store_line(JSON.stringify({"file": _named(path), "begin": true}))
		out.flush()
		var row: Dictionary = _audit(path)
		out.store_line(JSON.stringify(row))
		out.flush()
		for kind: Variant in row.get("by_kind", {}):
			totals[kind] = int(totals.get(kind, 0)) + int(row["by_kind"][kind])
		for kind: Variant in row.get("at_joint", {}):
			excused[kind] = int(excused.get(kind, 0)) + int(row["at_joint"][kind])
		print("  %s: %d parts, %d colliding pairs %s, at the joint %s, %.1f s" % [_named(path),
			int(row.get("parts", 0)), int(row.get("pairs", 0)), JSON.stringify(row.get("by_kind", {})),
			JSON.stringify(row.get("at_joint", {})), float(row.get("seconds", 0.0))])
	out.close()
	print("joint collisions: %s; at the joint: %s" % [JSON.stringify(totals), JSON.stringify(excused)])
	quit(0)


func _audit(path: String) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	_store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	var model: Assistant.Model = _assistant._model_from_world()
	var row: Dictionary = {"file": _named(path), "parts": model.placements.size()}
	if model.placements.is_empty():
		row["seconds"] = float(Time.get_ticks_msec() - started) / 1000.0
		return row
	var exact: ExactCheck = _assistant._exact_check_for(model, true)
	var shaped: int = 0
	for index: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = _library.mesh_for(placement.part)
		if part == null:
			continue
		exact.place(index, placement.part, placement.exact_at(
			_assistant._joined_at(placement, part, model)))
		if exact.items[index] != null:
			shaped += 1
	row["shaped"] = shaped
	var meshing: Dictionary = Joints.meshing(_assistant._mating_entries(model))
	var by_kind: Dictionary = {}
	var at_joint: Dictionary = {}
	var jointed: Array = []
	var pairs: int = 0
	# Every pair the shapes find colliding, as the check found them before it
	# held a joint to be one (ExactCheck.between); at_joint says which it now
	# lets be.
	for pair: Vector2i in exact.pairs_near({}, Exact.TAU):
		var found: Dictionary = Exact.clash(exact.items[pair.x], exact.items[pair.y])
		if found.is_empty():
			continue
		var a: int = pair.x
		var b: int = pair.y
		if (meshing.get(a, {}) as Dictionary).has(b) or (meshing.get(b, {}) as Dictionary).has(a):
			continue
		if exact.turned_on_axle(a, b):
			continue
		pairs += 1
		var joints: Array = exact.joints_between(a, b)
		var kinds: Dictionary = {}
		for joint: Array in joints:
			if joint[0] != "stud":
				kinds[joint[0]] = true
		var kind: String = "+".join(kinds.keys()) if not kinds.is_empty() \
			else ("stud" if not joints.is_empty() else "none")
		if _turntable(model, a) or _turntable(model, b):
			kind = "turntable" if kinds.has("hinge") or kinds.has("axle") else kind
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		if kinds.is_empty():
			continue
		var excused: String = exact.at_joint(a, b)
		if not excused.is_empty():
			at_joint[kind] = int(at_joint.get(kind, 0)) + 1
		jointed.append({"a": model.placements[a].part, "b": model.placements[b].part,
			"ia": a, "ib": b, "kinds": kind, "depth": snappedf(float(found["depth"]), 0.01),
			"at_joint": excused, "hits": _hits(exact, a, b),
			"lines": [_ldraw(model.placements[a], exact.items[a]),
				_ldraw(model.placements[b], exact.items[b])]})
	row["pairs"] = pairs
	row["by_kind"] = by_kind
	row["at_joint"] = at_joint
	row["jointed"] = jointed
	row["seconds"] = float(Time.get_ticks_msec() - started) / 1000.0
	return row


## A set by its file's name; anything else (a bench's model.mpd) by its path.
static func _named(path: String) -> String:
	return path.get_file() if path.begins_with(SETS) else path


func _turntable(model: Assistant.Model, i: int) -> bool:
	var info: PartLibrary.PartInfo = _library.parts.get(model.placements[i].part)
	return info != null and info.name.to_lower().contains("turntable")


## A part where the check has it, as an LDraw line (LDraw's frame: x, -y, -z).
static func _ldraw(placement: Assistant.Placement, item: Exact.Item) -> String:
	var c := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
	var r: Basis = c * item.at.basis * c
	var o: Vector3 = c * item.at.origin
	return "1 %d %.4f %.4f %.4f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %s.dat" % [
		placement.color, o.x, o.y, o.z, r.x.x, r.y.x, r.z.x, r.x.y, r.y.y, r.z.y,
		r.x.z, r.y.z, r.z.z, placement.part]


## Each overlapping pair of pieces of [param a] and [param b]: [depth, then
## for each joint between them how far the overlap can reach from its ball or
## its line, LDU] (ExactCheck.joint_reaches).
static func _hits(exact: ExactCheck, a: int, b: int) -> Array:
	var out: Array = []
	for hit: Array in exact.joint_reaches(a, b):
		var row: Array = [snappedf(float(hit[0]), 0.01)]
		for joint: Array in hit[1]:
			row.append([joint[0], snappedf(float(joint[1]), 0.1)])
		out.append(row)
	return out
