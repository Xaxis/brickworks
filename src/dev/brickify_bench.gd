extends SceneTree
## Brickify measured on models from outside, against a plain stack of
## bricks. For docs/BRICKIFY.md: each model at each size laid three ways —
##
##   smooth  Brickify as the panel lays it (slopes, curves, tiles, sideways
##           studs), checked and mended;
##   plain   Brickify with Surface set to plain bricks and plates;
##   greedy  what the simplest converters make: the same measured model cut
##           into whole bricks (a stud across, a brick tall), each course
##           covered greedily by the largest standard brick of one colour
##           that fits, studs up, courses turned alternately. Not mended.
##
## Each is checked as check_design checks a design, and weighed (Balance).
## What it writes, for tools/bench/brickify_bench.py to measure likeness:
##
##   OUT/palette.json                  the colours Brickify may lay, RGB
##   OUT/parts/<id>.f32, <id>.json     a part's triangles in its own frame
##   OUT/<slug>/source.f32             the model's triangles, file units
##   OUT/<slug>/colour.f32             its surface colour, sampled: x y z r g b
##   OUT/<slug>/<studs>/frame.json     file units into the build's LDU
##   OUT/<slug>/<studs>/<arm>.json     the check, the counts, the times, and
##                                     every part with its transform
##   OUT/<slug>/<studs>/<arm>.ldr      the build, to look at or verify
##
##   godot --headless --path . --script src/dev/brickify_bench.gd -- JOBS.json OUT
##
## JOBS.json: {"models": [{"slug", "file", "up", "sizes": [24, 48]}]}.

const ARMS: PackedStringArray = ["smooth", "plain", "greedy"]
const COLOUR_SAMPLES := 250000

var _library: PartLibrary
var _checker: Assistant
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _out: String = ""
## Part id -> "curved", "sloped" or "tile": what it does on a surface.
var _kind: Dictionary = {}
var _written: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- JOBS.json OUTDIR")
		quit(2)
		return
	var jobs: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out.path_join("parts"))
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = _world
	_checker.builder = _builder
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	_kinds()
	var palette: Array = []
	for code: int in Brickify.PALETTE:
		var known: PartLibrary.BrickColor = _library.color(code)
		palette.append({"code": code, "name": known.name,
			"rgb": [known.rgb.r, known.rgb.g, known.rgb.b]})
	_write_json(_out.path_join("palette.json"), palette)
	for job: Dictionary in (jobs as Dictionary).get("models", []):
		await _model(job)
	print("brickify_bench: done")
	quit(0)


## What each part Brickify lays does on a surface, as brickify_probe sorts them.
func _kinds() -> void:
	for entry: Array in Shapes.Plan.SLOPES:
		for id: Variant in [entry[3], entry[4]]:
			if not str(id).is_empty():
				_kind[str(id)] = "curved" if entry[0] == "curved" else "sloped"
	for entry: Array in Shapes.Plan.INVERTED:
		for id: Variant in [entry[3], entry[4]]:
			if not str(id).is_empty():
				_kind[str(id)] = "sloped"
	for id: Variant in Patterns.WEDGES + Shapes.EDGE_PLATES + Shapes.EDGE_BRICKS:
		_kind[str(id)] = "sloped"
	for id: Variant in Shapes.ROUND_PLATES + Shapes.ROUND_BRICKS:
		_kind[str(id)] = "curved"
	for entry: Array in Shapes.TOPS:
		_kind[str(entry[2])] = "tile"
	for id: Variant in Assistant.PANELS.values():
		_kind[str(id)] = "tile"


func _model(job: Dictionary) -> void:
	var slug: String = str(job["slug"])
	var path: String = str(job["file"])
	var dir: String = _out.path_join(slug)
	DirAccess.make_dir_recursive_absolute(dir)
	var t0: int = Time.get_ticks_msec()
	var mesh: MeshFile = _read(path)
	var read_ms: int = Time.get_ticks_msec() - t0
	if not mesh.error.is_empty():
		print("%s: %s" % [slug, mesh.error])
		_write_json(dir.path_join("error.json"), {"error": mesh.error})
		return
	var up: String = str(job.get("up", mesh.up))
	print("%s: %d triangles, %s, up %s, read in %d ms" % [slug, mesh.triangle_count(),
		"coloured" if mesh.coloured else "no colour", up, read_ms])
	var source := FileAccess.open(dir.path_join("source.f32"), FileAccess.WRITE)
	source.store_buffer(mesh.positions.to_byte_array())
	source.close()
	_samples(mesh, dir.path_join("colour.f32"))
	_write_json(dir.path_join("source.json"), {"triangles": mesh.triangle_count(),
		"coloured": mesh.coloured, "up": up, "read_ms": read_ms,
		"file": path.get_file()})
	for studs: Variant in job.get("sizes", [24, 48]):
		await _size(mesh, up, int(studs), dir.path_join(str(int(studs))), slug,
			PackedStringArray(job.get("arms", ARMS)))
		var outside: Dictionary = (job.get("outside", {}) as Dictionary).get(str(int(studs)), {})
		if not str(outside.get("file", "")).is_empty():
			await _outside(outside, int(studs), dir.path_join(str(int(studs))), slug)


func _size(mesh: MeshFile, up: String, studs: int, dir: String, slug: String,
		arms: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var grid: Brickify.Grid = null
	for arm: String in ARMS:
		if not arms.has(arm):
			continue
		var options := Brickify.Options.new()
		options.studs = studs
		options.up = up
		options.smooth = arm != "plain"
		var model: Assistant.Model
		var info: Dictionary = {"arm": arm, "studs": studs}
		var t0: int = Time.get_ticks_msec()
		if arm == "greedy":
			var t1: int = Time.get_ticks_msec()
			if grid == null:
				grid = Brickify.voxelise(mesh, options, _library)
			var measured: int = Time.get_ticks_msec() - t1
			var t2: int = Time.get_ticks_msec()
			model = _greedy(grid, mesh.name)
			info["ms"] = {"measure": measured, "lay": Time.get_ticks_msec() - t2, "check": 0}
			info["mended"] = 0
		else:
			var result: Dictionary = Brickify.build(mesh, options, _checker)
			if result.has("error"):
				print("  %s %d %s: %s" % [slug, studs, arm, result["error"]])
				_write_json(dir.path_join("%s.json" % arm), {"error": result["error"]})
				continue
			model = result["model"]
			grid = result["grid"]
			info["ms"] = result["ms"]
			info["mended"] = int((result["report"] as Dictionary).get("mended", 0))
			info["coverage"] = float((result["report"] as Dictionary).get("coverage", 0.0))
		info["total_ms"] = Time.get_ticks_msec() - t0
		if arm == "greedy":
			info["coverage"] = Brickify.coverage(grid, model, _checker)
		if not FileAccess.file_exists(dir.path_join("frame.json")):
			_write_json(dir.path_join("frame.json"), _frame(mesh, up, studs, grid))
		info["grid"] = [grid.across, grid.tall, grid.deep]
		info["cells"] = grid.cells
		await _record(model, info, dir.path_join(arm), slug)


## An outside tool's build of the same model at the same scale, read as a
## file a person opens, then checked and measured as ours are. Its frame is
## its own: brickify_bench.py lines it up with the model ("align").
func _outside(outside: Dictionary, studs: int, dir: String, slug: String) -> void:
	var text: String = FileAccess.get_file_as_string(str(outside["file"]))
	var opened: Dictionary = _store.open_text(text, slug)
	for _n: int in 3:
		await process_frame
	var model: Assistant.Model = _checker._model_from_world()
	_world.clear()
	_builder.lattice.clear()
	_checker.forget_built()
	var seconds: float = float(outside.get("seconds", 0.0))
	var info: Dictionary = {"arm": "outside", "studs": studs, "mended": 0,
		"ms": {"measure": 0, "lay": roundi(seconds * 1000.0), "check": 0},
		"total_ms": roundi(seconds * 1000.0),
		"opened": {"placed": int(opened.get("placed", 0)), "missing": opened.get("missing_ids", {}),
			"error": str(opened.get("error", ""))},
		"grid": [0, 0, 0], "cells": 0, "align": true}
	await _record(model, info, dir.path_join("outside"), slug)


## The model in whole bricks: a cell a stud across and a brick tall is in
## where the middle of its middle plate is in, its colour the one most of
## its plates have; each course covered greedily, largest brick first, by
## bricks of one colour, the long way turned on every other course.
func _greedy(grid: Brickify.Grid, title: String) -> Assistant.Model:
	var model := Assistant.Model.new()
	model.name = title
	var courses: int = grid.tall / 3
	for k: int in courses:
		var colour_of := PackedInt32Array()
		colour_of.resize(grid.across * grid.deep)
		colour_of.fill(-1)
		for x: int in grid.across:
			for z: int in grid.deep:
				var middle: int = grid.index(x, 3 * k + 1, z)
				if grid.state[middle] != 1:
					continue
				var votes: Dictionary = {}
				for j: int in range(3 * k, 3 * k + 3):
					var i: int = grid.index(x, j, z)
					if grid.state[i] == 1 and grid.colour[i] >= 0:
						votes[grid.colour[i]] = int(votes.get(grid.colour[i], 0)) + 1
				var best: int = grid.colour[middle]
				for c: Variant in votes:
					if int(votes[c]) > int(votes.get(best, 0)):
						best = int(c)
				colour_of[x * grid.deep + z] = best if best >= 0 else grid.dominant
		var taken := PackedByteArray()
		taken.resize(grid.across * grid.deep)
		# Long way across on even courses, along on odd ones: the table lists
		# each size across first, so odd courses read each pair the other way.
		var sizes: Array = []
		for n: int in range(0, Shapes.CORE_BRICKS.size()):
			sizes.append(Shapes.CORE_BRICKS[n])
		if k % 2 == 1:
			sizes = []
			var n: int = 0
			while n < Shapes.CORE_BRICKS.size():
				var one: Array = Shapes.CORE_BRICKS[n]
				var next: Array = Shapes.CORE_BRICKS[n + 1] if n + 1 < Shapes.CORE_BRICKS.size() else []
				if not next.is_empty() and next[2] == one[2]:
					sizes.append(next)
					sizes.append(one)
					n += 2
				else:
					sizes.append(one)
					n += 1
		for z: int in grid.deep:
			for x: int in grid.across:
				var here: int = x * grid.deep + z
				if colour_of[here] < 0 or taken[here] == 1:
					continue
				var c: int = colour_of[here]
				for entry: Array in sizes:
					var w: int = int(entry[0])
					var d: int = int(entry[1])
					if x + w > grid.across or z + d > grid.deep:
						continue
					var fits: bool = true
					for a: int in w:
						for b: int in d:
							var cell: int = (x + a) * grid.deep + z + b
							if taken[cell] == 1 or colour_of[cell] != c:
								fits = false
								break
						if not fits:
							break
					if not fits:
						continue
					for a: int in w:
						for b: int in d:
							taken[(x + a) * grid.deep + z + b] = 1
					model.placements.append(Assistant.Placement.from_dict({"part": entry[2],
						"color": c, "x": x, "y": 3 * k, "z": z, "rot": entry[3]}))
					break
	return model


## File units into the build's own LDU, as Brickify.voxelise measures:
## turned to stand up, from its corner, scaled to the studs asked for and
## centred on its studs; 20 LDU a stud each way.
func _frame(mesh: MeshFile, up: String, studs: int, grid: Brickify.Grid) -> Dictionary:
	var turn: Basis = Brickify.turn_for(up)
	var box: AABB = Brickify._turned_bounds(mesh, turn)
	var shift := Vector3((grid.across - box.size.x * grid.scale) / 2.0, 0.0,
		(grid.deep - box.size.z * grid.scale) / 2.0)
	return {"turn": [turn.x.x, turn.y.x, turn.z.x, turn.x.y, turn.y.y, turn.z.y,
			turn.x.z, turn.y.z, turn.z.z],
		"corner": [box.position.x, box.position.y, box.position.z],
		"scale": grid.scale, "shift": [shift.x, shift.y, shift.z], "studs": studs,
		"grid": [grid.across, grid.tall, grid.deep]}


func _record(model: Assistant.Model, info: Dictionary, stem: String, slug: String) -> void:
	var t0: int = Time.get_ticks_msec()
	var report: Dictionary = _checker._check(model, true, true)
	info["check_ms"] = Time.get_ticks_msec() - t0
	info["parts"] = model.placements.size()
	info["ok"] = bool(report.get("ok", false))
	info["pieces"] = int(report.get("pieces", 0))
	info["loose"] = int(report.get("loose", 0))
	info["summary"] = str(report.get("summary", ""))
	info["problem_kinds"] = report.get("kinds", [])
	info["floating"] = (report.get("floating", []) as Array).size()
	var balance: Balance.Report = report.get("balance")
	if balance != null:
		info["balance"] = {"grams": balance.grams, "margin": balance.margin,
			"tilt": balance.tilt, "bridges": balance.joints.size(), "over": balance.over,
			"adrift": balance.adrift, "stands": balance.stands()}
	var counts: Dictionary = {"curved": 0, "sloped": 0, "tile": 0, "plain": 0, "sideways": 0}
	var colours: Dictionary = {}
	var lots: Dictionary = {}
	var no_element: Dictionary = {}
	var placed: Array = []
	var lattice := BrickLattice.new()
	var at_of: Array = []
	for index: int in model.placements.size():
		var p: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = _library.mesh_for(p.part)
		if part == null:
			at_of.append(Transform3D())
			continue
		var at: Transform3D = _checker._transform(p, part)
		at_of.append(at)
		lattice.occupy_boxes(index + 1, _builder.boxes_for(part, at))
		var kind: String = str(_kind.get(p.part, "plain"))
		counts[kind] = int(counts[kind]) + 1
		if p.face != "up":
			counts["sideways"] = int(counts["sideways"]) + 1
		colours[p.color] = true
		var lot: String = "%s/%d" % [p.part, p.color]
		lots[lot] = int(lots.get(lot, 0)) + 1
		# By the number the part has today: Shapes lays 3023, which LDraw
		# moved to 3023b, and the element list knows only 3023b.
		if _library.element_for(_library.resolve(p.part), p.color).is_empty():
			no_element[lot] = true
		_part_file(p.part, part)
		var b: Basis = at.basis
		var o: Vector3 = at.origin
		placed.append([p.part, p.color, [b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y,
			b.x.z, b.y.z, b.z.z, o.z]])
	# Studs left showing on top, and what the top of each stud of the plan is.
	var bare: int = 0
	var highest: Dictionary = {}
	for index: int in model.placements.size():
		var p: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = _library.mesh_for(p.part)
		if part == null:
			continue
		var at: Transform3D = at_of[index]
		for connector: Lbm.Connector in part.connectors:
			if connector.kind == "stud" and connector.gender == "male" \
					and (at.basis * connector.axis).normalized().dot(Vector3.UP) > 0.9:
				var tip: Vector3 = at * (connector.position + connector.axis.normalized() * 5.0)
				if lattice.brick_at(BrickLattice.to_cell(tip)) == 0:
					bare += 1
		var box: AABB = at * part.bounds
		for x: int in range(roundi(box.position.x / 20.0), roundi(box.end.x / 20.0)):
			for z: int in range(roundi(box.position.z / 20.0), roundi(box.end.z / 20.0)):
				var key := Vector2i(x, z)
				if not highest.has(key) or box.end.y > float(highest[key][0]):
					highest[key] = [box.end.y, p.part]
	var tops: Dictionary = {"curved": 0, "sloped": 0, "tile": 0, "plain": 0}
	for key: Variant in highest:
		var kind: String = str(_kind.get(str(highest[key][1]), "plain"))
		tops[kind] = int(tops[kind]) + 1
	info["kinds"] = counts
	info["tops"] = tops
	info["bare_studs"] = bare
	info["colours"] = colours.size()
	info["lots"] = lots.size()
	info["lots_no_element"] = no_element.size()
	info["parts_no_element"] = 0
	for lot: Variant in no_element:
		info["parts_no_element"] = int(info["parts_no_element"]) + int(lots[lot])
	info["placed"] = placed
	_write_json(stem + ".json", info)
	print("  %s %d %s: %d parts, %s, %d piece(s), %d mended, %d ms (check %d ms)" % [slug,
		int(info["studs"]), info["arm"], model.placements.size(), info["summary"],
		info["pieces"], int(info.get("mended", 0)), int(info["total_ms"]), int(info["check_ms"])])
	if not model.placements.is_empty():
		_checker._apply(model)
		for _n: int in 3:
			await process_frame
		_store.export_to(stem + ".ldr", "%s %d %s" % [slug, int(info["studs"]), info["arm"]])
		_world.clear()
		_builder.lattice.clear()
		_checker.forget_built()


## A part's triangles once, in its own frame, and the colour each surface
## is moulded in (16: the colour it is placed in).
func _part_file(id: String, part: Lbm.PartMesh) -> void:
	if _written.has(id):
		return
	_written[id] = true
	var safe: String = id.replace("/", "_").replace("\\", "_")
	var all := PackedVector3Array()
	var surfaces: Array = []
	for s: int in part.surfaces.size():
		var arrays: Array = part.surfaces[s].surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		var before: int = all.size()
		if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty():
			for i: int in (idx as PackedInt32Array):
				all.append(verts[i])
		else:
			all.append_array(verts)
		var code: int = part.surface_colors[s] if s < part.surface_colors.size() else 16
		var known: PartLibrary.BrickColor = _library.color(code)
		surfaces.append({"triangles": (all.size() - before) / 3, "colour": code,
			"rgb": [known.rgb.r, known.rgb.g, known.rgb.b]})
	var file := FileAccess.open(_out.path_join("parts/%s.f32" % safe), FileAccess.WRITE)
	file.store_buffer(all.to_byte_array())
	file.close()
	_write_json(_out.path_join("parts/%s.json" % safe), {"id": id, "surfaces": surfaces,
		"bounds": [part.bounds.position.x, part.bounds.position.y, part.bounds.position.z,
			part.bounds.size.x, part.bounds.size.y, part.bounds.size.z]})


## Its surface colour where it is, by area: what the bricks are scored against.
func _samples(mesh: MeshFile, path: String) -> void:
	var total: float = 0.0
	var areas := PackedFloat32Array()
	areas.resize(mesh.triangle_count())
	for t: int in mesh.triangle_count():
		var a: Vector3 = mesh.positions[3 * t]
		var area: float = (mesh.positions[3 * t + 1] - a).cross(mesh.positions[3 * t + 2] - a).length() / 2.0
		areas[t] = area
		total += area
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261015
	var out := PackedFloat32Array()
	for t: int in mesh.triangle_count():
		var n: int = floori(areas[t] / maxf(total, 1e-12) * COLOUR_SAMPLES + rng.randf())
		for _s: int in n:
			var u: float = rng.randf()
			var v: float = rng.randf()
			if u + v > 1.0:
				u = 1.0 - u
				v = 1.0 - v
			var b := Vector3(1.0 - u - v, u, v)
			var p: Vector3 = mesh.positions[3 * t] * b.x + mesh.positions[3 * t + 1] * b.y \
				+ mesh.positions[3 * t + 2] * b.z
			var c: Color = mesh.colour_at(t, b)
			for value: float in [p.x, p.y, p.z, c.r, c.g, c.b]:
				out.append(value)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(out.to_byte_array())
	file.close()


## The file with what it names beside it, as the desktop's picker reads it.
func _read(path: String) -> MeshFile:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var extras: Dictionary = {}
	for _round: int in 2:
		for wanted: String in MeshFile.companions(bytes, path.get_file(), extras):
			var beside: String = path.get_base_dir().path_join(
				wanted.replace("\\", "/")).simplify_path()
			if FileAccess.file_exists(beside):
				extras[wanted] = FileAccess.get_file_as_bytes(beside)
	return MeshFile.read(bytes, path.get_file(), extras)


func _write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
