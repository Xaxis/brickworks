## Where real sets hide their colours: which of each set's parts nobody
## sees in the finished model, and what colour LEGO made those.
##
##   godot --path . --script src/dev/hidden_colours_audit.gd -- [--shard=K/N]
##       [--out=FILE] [--views=48] [--most=1024] [--finest=1.0] [--on-table]
##       [FILE.mpd ...]
##
## Needs a window: what is hidden is measured by SeenParts, from pictures.
## Every file of the LDraw model repository (vendor/omr/files) is opened as
## File, Open opens it; its parts are measured from --views sides, a pixel
## no finer than --finest LDU and at most --most pixels across (with
## --on-table, "hidden" is seen from no side but underneath, as a display
## model is looked at; the counts of both go in every line); and one
## line a file goes to the out file (JSON):
##   {file, parts, drawn, see_through, hidden, hidden_anywhere, hidden_on_table,
##    on_table, views, coarsest, seconds,
##    colours: {code: [seen, hidden, hidden from every side]},
##    groups: {sub-model: [parts, hidden, hidden in a colour no seen part has]},
##    build: [[code, at], ...]   each hidden part in a hidden-only colour, where
##                               in the build it goes (0 first, 1 last)
##    hidden_build: [at, ...]    every hidden part's, a sample of 400
##    mirror: {x: [pairs, same colour, both hidden-only and different,
##                 {"a|b": pairs in colours a and b}], z: [...]}
##    names: [sub-model, ...], hidden_parts: [[colour, at, sub-model index], ...]
##    accent_groups: {code: {sub-model: n}}}
## tools/hidden_colours_audit.py adds the lines up into docs/HIDDEN_COLOURS.md.
## Not in the suite: an hour and more over the repository.
extends SceneTree

const SETS := "res://vendor/omr/files"

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _seen: SeenParts
var _views: int = 48
var _most: int = 1024
var _finest: float = 1.0
## Hidden as a display model hides it: seen from no side but underneath.
var _on_table: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var shard: int = 0
	var shards: int = 1
	var out_path: String = "user://hidden_colours_audit.jsonl"
	var named: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shard="):
			var said: PackedStringArray = argument.trim_prefix("--shard=").split("/")
			shard = int(said[0])
			shards = maxi(1, int(said[1]))
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--views="):
			_views = int(argument.trim_prefix("--views="))
		elif argument.begins_with("--most="):
			_most = int(argument.trim_prefix("--most="))
		elif argument == "--on-table":
			_on_table = true
		elif argument.begins_with("--finest="):
			_finest = float(argument.trim_prefix("--finest="))
		else:
			named.append(argument)
	if not SeenParts.possible():
		print("  no rendering device — this needs a window")
		quit(1)
		return
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	_world.keeps_history = false
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
	_seen = SeenParts.new()
	_seen.library = _library
	get_root().add_child(_seen)
	await process_frame
	# The model's own world is not drawn: only the measure's pictures are.
	_world.visible = false

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
		var row: Dictionary = await _audit(path)
		out.store_line(JSON.stringify(row))
		out.flush()
		print("  %s: %d parts, %d hidden, %.1f s" % [path.get_file(), int(row.get("parts", 0)),
			int(row.get("hidden", 0)), float(row.get("seconds", 0.0))])
	out.close()
	print("hidden colours audit: done")
	quit(0)


func _audit(path: String) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	_builder.forget_history()
	_store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	var bricks: Array = []
	var by_id: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		bricks.append([brick.id, brick.part_id, brick.color_code, brick.transform])
		by_id[brick.id] = brick
	var row: Dictionary = {"file": path.get_file(), "parts": bricks.size()}
	if bricks.is_empty():
		row["seconds"] = float(Time.get_ticks_msec() - started) / 1000.0
		row["error"] = "nothing placed"
		return row
	var result: SeenParts.Result = await _seen.measure(bricks, _views, _finest, _most)
	var hidden: Dictionary = result.hidden(_on_table)
	row["on_table"] = _on_table
	row["hidden_anywhere"] = result.hidden().size()
	row["hidden_on_table"] = result.hidden(true).size()
	row["drawn"] = result.drawn.size()
	row["see_through"] = result.see_through.size()
	row["hidden"] = hidden.size()
	row["views"] = result.views
	row["complete"] = result.complete
	row["coarsest"] = snappedf(result.coarsest, 0.01)

	# Colours, seen and hidden, by plain colour (a rubber tyre is black):
	# [seen, hidden as this audit counts it, hidden from every side].
	var anywhere: Dictionary = result.hidden()
	var colours: Dictionary = {}
	var seen_colours: Dictionary = {}
	for brick_id: int in by_id:
		var brick: BrickWorld.Brick = by_id[brick_id]
		var code: int = _library.plain_code(brick.color_code)
		var counts: Array = colours.get(code, [0, 0, 0])
		if hidden.has(brick_id):
			counts[1] += 1
		else:
			counts[0] += 1
			seen_colours[code] = true
		if anywhere.has(brick_id):
			counts[2] += 1
		colours[code] = counts
	row["colours"] = colours

	# Where in the build each goes: the author's steps, as the booklet
	# follows them, else the order of the file.
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery, {},
		true)
	var at: Dictionary = {}
	var placed: int = 0
	for step: Instructions.Step in steps:
		for brick_id: int in step.brick_ids:
			if not at.has(brick_id):
				at[brick_id] = placed
				placed += 1
	if at.size() < by_id.size():
		for brick_id: int in by_id:
			if not at.has(brick_id):
				at[brick_id] = placed
				placed += 1
	var groups: Dictionary = {}
	var build: Array = []
	var hidden_build: Array = []
	var accent_groups: Dictionary = {}
	# Every hidden part: [colour, where in the build, its sub-model's index
	# in [member names]], for an accent read any way afterwards.
	var names: Array = []
	var every: Array = []
	for brick_id: int in by_id:
		var brick: BrickWorld.Brick = by_id[brick_id]
		var top: String = Assemblies.segments(Assemblies.path_of(brick))[0] \
			if not Assemblies.path_of(brick).is_empty() else ""
		top = Assemblies.definition(top)
		var counts: Array = groups.get(top, [0, 0, 0])
		counts[0] += 1
		if hidden.has(brick_id):
			counts[1] += 1
			var code: int = _library.plain_code(brick.color_code)
			var where: float = snappedf(float(at[brick_id]) / maxf(1.0, float(placed - 1)), 0.001)
			hidden_build.append(where)
			if not names.has(top):
				names.append(top)
			every.append([code, where, names.find(top)])
			if not seen_colours.has(code):
				counts[2] += 1
				build.append([code, where])
				var by_group: Dictionary = accent_groups.get(code, {})
				by_group[top] = int(by_group.get(top, 0)) + 1
				accent_groups[code] = by_group
		groups[top] = counts
	row["groups"] = groups
	row["build"] = build
	if hidden_build.size() > 400:
		var sample: Array = []
		for n: int in 400:
			sample.append(hidden_build[n * hidden_build.size() / 400])
		hidden_build = sample
	row["hidden_build"] = hidden_build
	row["accent_groups"] = accent_groups
	row["names"] = names
	row["hidden_parts"] = every
	row["mirror"] = {"x": _mirrored(by_id, hidden, seen_colours, 0),
		"z": _mirrored(by_id, hidden, seen_colours, 2)}
	row["seconds"] = snappedf(float(Time.get_ticks_msec() - started) / 1000.0, 0.1)
	return row


## Hidden parts and their mirror image across the model's middle on
## [param axis] (0 x, left and right; 2 z, front and back): [pairs found,
## pairs the same colour, pairs both in hidden-only colours and different].
## A part's image is the same part (or its other hand) where the mirror
## puts it, within half a plate.
func _mirrored(by_id: Dictionary, hidden: Dictionary, seen_colours: Dictionary,
		axis: int) -> Array:
	var whole := AABB()
	var any: bool = false
	var near: Dictionary = {}
	for brick_id: int in by_id:
		var brick: BrickWorld.Brick = by_id[brick_id]
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = brick.transform * part.bounds
		whole = box if not any else whole.merge(box)
		any = true
	if not any:
		return [0, 0, 0, {}]
	var middle: float = whole.get_center()[axis]
	var centres: Dictionary = {}
	for brick_id: int in hidden:
		var brick: BrickWorld.Brick = by_id[brick_id]
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var centre: Vector3 = brick.transform * (part.bounds.get_center() if part != null
			else Vector3.ZERO)
		centres[brick_id] = centre
		var key := Vector3i((centre / 4.0).round())
		near[key] = (near.get(key, []) as Array) + [brick_id]
	var pairs: int = 0
	var same: int = 0
	var coded: int = 0
	var by_colours: Dictionary = {}
	var counted: Dictionary = {}
	for brick_id: int in hidden:
		if counted.has(brick_id):
			continue
		var brick: BrickWorld.Brick = by_id[brick_id]
		var centre: Vector3 = centres[brick_id]
		var image: Vector3 = centre
		image[axis] = 2.0 * middle - image[axis]
		if absf(image[axis] - centre[axis]) < 10.0:
			continue
		var other_hand: String = Mirror.counterpart(_library, brick.part_id)
		var mate: int = 0
		var key := Vector3i((image / 4.0).round())
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					for other_id: int in near.get(key + Vector3i(dx, dy, dz), []):
						if other_id == brick_id or counted.has(other_id):
							continue
						var other: BrickWorld.Brick = by_id[other_id]
						if other.part_id != brick.part_id and other.part_id != other_hand:
							continue
						if (centres[other_id] as Vector3).distance_to(image) < 4.0:
							mate = other_id
		if mate == 0:
			continue
		counted[brick_id] = true
		counted[mate] = true
		pairs += 1
		var a: int = _library.plain_code(brick.color_code)
		var b: int = _library.plain_code((by_id[mate] as BrickWorld.Brick).color_code)
		var pair_key: String = "%d|%d" % [mini(a, b), maxi(a, b)]
		by_colours[pair_key] = int(by_colours.get(pair_key, 0)) + 1
		if a == b:
			same += 1
		elif not seen_colours.has(a) and not seen_colours.has(b):
			coded += 1
	return [pairs, same, coded, by_colours]
