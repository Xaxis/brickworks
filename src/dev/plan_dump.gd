## Instructions.plan, timed or written out whole, on files opened as File >
## Open opens them: what a change meant only to make planning faster is held
## to (tools/plan_diff.py compares two runs step for step; docs/INSTRUCTIONS.md,
## planspeed). Copied into another checkout, it times or dumps that one.
##
##   godot --headless --path . --script src/dev/plan_dump.gd -- --time --out=F --list=FILES
##   godot --headless --path . --script src/dev/plan_dump.gd -- --dump --out=F --list=FILES
##
## FILES holds a res:// path a line (or name them after the flags). --time
## writes each file's plan in ms, as opened, and the total. --dump writes four
## plans a file: as opened, the author's steps as the booklet draws them
## (authored), and the parts shuffled with and without their sub-models as
## src/dev/steps_score.gd plans them; each step's every field, its bricks as
## the file's part order, and the step player's view of each page
## (BuildSteps.view). Under XDG_DATA_HOME of its own, as tools/steps_score.py
## runs, so no person's saved state is read.
##
## And what the plans were made from besides the planner: the catalogue, on
## a first line, and each file's parts as the library read them ("geometry",
## a digest of each part's mesh file, or of its text for a part the file
## carries). A plan moves with its parts: for 13 minutes on 2026-10-17 the
## shared catalogue gave 421 wheels and tyres other covers, and two dumps of
## one checkout, made either side of it, differed in 7 files, which was read
## as the planner remembering what it planned before (docs/INSTRUCTIONS.md,
## samebooklet). tools/plan_diff.py says which files' parts differ.
extends SceneTree

const SEED := 20261015

var _library: PartLibrary
var _world: BrickWorld
var _other: BrickWorld
var _builder: Builder
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_path: String = ""
	var mode: String = "time"
	var named: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument == "--time":
			mode = "time"
		elif argument == "--dump":
			mode = "dump"
		elif argument.begins_with("--list="):
			for line: String in FileAccess.get_file_as_string(argument.trim_prefix("--list=")).split("\n"):
				if not line.strip_edges().is_empty():
					named.append(line.strip_edges())
		else:
			named.append(argument)
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_other = BrickWorld.new()
	_other.library = _library
	get_root().add_child(_other)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	var out := FileAccess.open(out_path, FileAccess.WRITE)
	out.store_line(JSON.stringify({"catalogue":
		FileAccess.get_md5(PartLibrary.FULL_ROOT + "catalogue.json")}))
	var total_usec: int = 0
	for path: String in named:
		_world.clear()
		_store.open_text(FileAccess.get_file_as_string(path), path.get_file())
		var bricks: Array = _world.bricks()
		bricks.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
			return a.id < b.id)
		var row: Dictionary = {"file": path.get_file(), "parts": bricks.size(),
			"geometry": _geometry(bricks)}
		if mode == "time":
			var began: int = Time.get_ticks_usec()
			var steps: Array[Instructions.Step] = Instructions.plan(_world, _library)
			var took: int = Time.get_ticks_usec() - began
			total_usec += took
			row["ms"] = took / 1000.0
			row["steps"] = steps.size()
		else:
			var index_of: Dictionary = {}
			for index: int in bricks.size():
				index_of[(bricks[index] as BrickWorld.Brick).id] = index
			row["opened"] = _dump(Instructions.plan(_world, _library), _world, index_of)
			row["drawn"] = _dump(Instructions.plan(_world, _library, {}, {}, true), _world,
				index_of)
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED ^ hash(path.get_file())
			var shuffled: Array = range(bricks.size())
			for at: int in range(shuffled.size() - 1, 0, -1):
				var other: int = rng.randi_range(0, at)
				var kept: int = shuffled[at]
				shuffled[at] = shuffled[other]
				shuffled[other] = kept
			for variant: String in ["ours", "flat"]:
				var back: Dictionary = _restaged(bricks, shuffled, variant == "ours")
				row[variant] = _dump(Instructions.plan(_other, _library), _other, back)
				_other.clear()
		out.store_line(JSON.stringify(row))
		out.flush()
		print("  %s: %d parts%s" % [path.get_file(), bricks.size(),
			", %.1f ms" % row["ms"] if row.has("ms") else ""])
	if mode == "time":
		out.store_line(JSON.stringify({"total_ms": total_usec / 1000.0, "files": named.size()}))
		print("total %.1f s over %d files" % [total_usec / 1.0e6, named.size()])
	out.close()
	quit(0)


## One digest of the geometry of [param bricks]' parts as the library read
## it: each part's mesh file, or the text of a part the file carries.
func _geometry(bricks: Array) -> String:
	var kinds: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		kinds[brick.part_id] = true
	var ids: Array = kinds.keys()
	ids.sort()
	var lines := PackedStringArray()
	for id: String in ids:
		var source: String = _library.custom_source(id)
		var info: PartLibrary.PartInfo = _library.parts.get(id)
		if not source.is_empty():
			lines.append("%s %s" % [id, source.md5_text()])
		elif info != null:
			lines.append("%s %s" % [id, FileAccess.get_md5(PartLibrary.FULL_ROOT + "parts/"
				+ info.mesh_hash + ".lbm")])
	return "\n".join(lines).md5_text()


func _restaged(bricks: Array, order: Array, structure: bool) -> Dictionary:
	_other.clear()
	var back: Dictionary = {}
	for index: int in order:
		var brick: BrickWorld.Brick = bricks[index]
		var id: int = _other.add_brick(brick.part_id, brick.color_code, brick.transform)
		if id == 0:
			continue
		if structure:
			_other.get_brick(id).group = brick.group
			_other.get_brick(id).unit = brick.unit
		back[id] = index
	return back


## Every field of every step, ids mapped through [param back] when given,
## and the step player's view of each page.
func _dump(steps: Array[Instructions.Step], world: BrickWorld, back: Dictionary) -> Array:
	var ids := func(packed: PackedInt64Array) -> Array:
		var out: Array = []
		for id: int in packed:
			out.append(int(back.get(id, id)) if not back.is_empty() else id)
		return out
	var pages: BuildSteps = BuildSteps.of(world, _library, steps)
	var out: Array = []
	for at: int in steps.size():
		var step: Instructions.Step = steps[at]
		var parts: Array = []
		for part_id: String in step.parts:
			parts.append("%s=%d" % [part_id, int(step.parts[part_id])])
		parts.sort()
		var copies: Array = []
		for copy: PackedInt64Array in step.copies:
			copies.append(ids.call(copy))
		var view: Dictionary = pages.view(at + 1)
		var from: Vector3 = view["from"]
		var box: AABB = view["box"]
		out.append([step.index, step.number, ids.call(step.brick_ids), parts, step.unsupported,
			step.section, step.assembly, step.callout, step.callout_step, step.callout_steps,
			step.times, step.figure, ids.call(step.shown_ids), copies, step.authored_in,
			step.authored_step, "%.4f,%.4f,%.4f" % [from.x, from.y, from.z],
			"%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [box.position.x, box.position.y, box.position.z,
				box.size.x, box.size.y, box.size.z]])
	return out
