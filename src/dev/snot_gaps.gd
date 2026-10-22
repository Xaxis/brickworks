extends SceneTree
## Where a model's turned sides leave it in no part: each of its studs and
## plates no part fills with its sides turned that the build with them
## upright fills, said by why. Laid step by step as Brickify.build lays it,
## so what the lay leaves is told from what the mend takes out.
##
##   godot --headless --path . --script src/dev/snot_gaps.gd -- SPEC ...
##   SPEC is bunny:STUDS[:one] (brickify_probe's bunny; one: blue, one colour) or FILE:STUDS:UP
##
## Each line: cells, share of the model, why. "Cut off" is a piece of the core
## beside a shell taken out before the check (Shapes.Plan.cut_off,
## caps_apart), said by where it is against the nearest shell and whether
## the shell gave it back; "a shell's plate" is the shell's and no part of
## it is there.

var _library: PartLibrary
var _checker: Assistant


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	root.add_child(builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = world
	_checker.builder = builder
	await process_frame
	for id: String in Brickify.parts_needed(_library):
		_library.mesh_for(id)
	for spec: String in OS.get_cmdline_user_args():
		var bits: PackedStringArray = spec.split(":")
		var mesh: MeshFile
		var options := Brickify.Options.new()
		options.studs = int(bits[1])
		if bits[0] == "bunny":
			var obj: String = BrickifySamples.to_obj(BrickifySamples.bunny())
			mesh = MeshFile.read(obj.to_utf8_buffer(), "bunny.obj")
			if bits.size() > 2 and bits[2] == "one":
				options.colours = "one"
				options.colour = 1
		else:
			var read: Dictionary = MeshFilePicker.read_path(bits[0])
			mesh = MeshFile.read(read["bytes"], bits[0].get_file(), read["extras"])
			options.up = bits[2]
		var turned: Dictionary = _lay(mesh, options)
		var upright_options: Brickify.Options = options.copied()
		upright_options.snot = false
		var upright: Dictionary = _lay(mesh, upright_options)
		_tell(spec, turned, upright)
	print("snot_gaps: done")
	quit(0)


## Laid as Brickify.build lays it: what is covered before and after the mend.
func _lay(mesh: MeshFile, options: Brickify.Options) -> Dictionary:
	var grid: Brickify.Grid = Brickify.voxelise(mesh, options, _library)
	var shape: Dictionary = Brickify.pattern(grid, options)
	var trouble: Array = []
	var made: Array = Shapes.lay(shape, trouble, _library)
	var last: Dictionary = Shapes.last.duplicate()
	var model := Assistant.Model.new()
	var shells_only := Assistant.Model.new()
	for raw: Dictionary in made:
		var one: Dictionary = raw
		if one.has("panel"):
			var tile: Dictionary = _checker._panel(one, str(one["panel"]))
			one.erase("panel")
			if not tile.is_empty():
				model.placements.append(Assistant.Placement.from_dict(tile))
		var placement := Assistant.Placement.from_dict(one)
		model.placements.append(placement)
		if bool(one.get("_shell", false)):
			shells_only.placements.append(placement)
	Brickify.made_colours(model, options, _library)
	var before: PackedByteArray = Brickify._covered(grid, model, _checker)
	var boxes: Array = []
	for p: Assistant.Placement in shells_only.placements:
		var part: Lbm.PartMesh = _library.mesh_for(p.part)
		if part != null:
			boxes.append(_checker._transform(p, part) * part.bounds)
	var report: Dictionary = Brickify.mend(model, _checker)
	var after: PackedByteArray = Brickify._covered(grid, model, _checker)
	return {"grid": grid, "before": before, "after": after, "mended": int(report.get("mended", 0)),
		"parts": model.placements.size(), "last": last, "boxes": boxes}


func _count(grid: Brickify.Grid, covered: PackedByteArray) -> int:
	var n: int = 0
	for i: int in covered.size():
		if grid.state[i] == 1 and covered[i] == 1:
			n += 1
	return n


func _tell(spec: String, turned: Dictionary, upright: Dictionary) -> void:
	var grid: Brickify.Grid = turned["grid"]
	var cells: int = grid.cells
	print("GAPS %s: %d cells; turned %.2f%% in a part before the mend, %.2f%% after (%d mended, %d parts); upright %.2f%%, %.2f%% (%d mended, %d parts)" % [
		spec, cells, 100.0 * _count(grid, turned["before"]) / cells,
		100.0 * _count(grid, turned["after"]) / cells, turned["mended"], turned["parts"],
		100.0 * _count(grid, upright["before"]) / cells, 100.0 * _count(grid, upright["after"]) / cells,
		upright["mended"], upright["parts"]])
	var last: Dictionary = turned["last"]
	var shelled: Dictionary = last.get("shelled", {})
	var cut: Dictionary = last.get("cut_cells", {})
	var given: Dictionary = last.get("given_back", {})
	var frames: Array = last.get("shell_frames", [])
	var why: Dictionary = {}
	var examples: Dictionary = {}
	var up_after: PackedByteArray = upright["after"]
	var tb: PackedByteArray = turned["before"]
	var ta: PackedByteArray = turned["after"]
	for x: int in grid.across:
		for z: int in grid.deep:
			for j: int in grid.tall:
				var i: int = grid.index(x, j, z)
				if grid.state[i] != 1 or ta[i] == 1:
					continue
				var key := Vector3i(x, j, z)
				var w: String
				if up_after[i] == 0:
					w = "upright misses it too"
				elif tb[i] == 1:
					w = "taken out by the mend"
				elif cut.has(key):
					w = "cut off (%s), %s, %s" % [cut[key], _where(key, frames),
						"given back" if given.has(key) else "the core's"]
				elif shelled.has(key):
					var centre := Vector3((x + 0.5) * 20.0, (j + 0.5) * 8.0, (z + 0.5) * 20.0)
					var near: float = INF
					for box: AABB in turned["boxes"]:
						near = minf(near, centre.clamp(box.position, box.end).distance_to(centre))
					w = "a shell's plate, no part of it there, the nearest %s" % (
						"within 4 LDU" if near <= 4.0 else ("within 10 LDU" if near <= 10.0 else "further"))
				else:
					var beside: bool = false
					for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
							Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
						beside = beside or shelled.has(key + step)
					w = "beside a shell, no part" if beside else "elsewhere, no part"
				why[w] = int(why.get(w, 0)) + 1
				if not examples.has(w):
					examples[w] = []
				if (examples[w] as Array).size() < 6:
					(examples[w] as Array).append(key)
	var lines: Array = []
	for w: Variant in why:
		lines.append("  %5d %5.2f%%  %s  e.g. %s" % [why[w], 100.0 * int(why[w]) / cells, w, str(examples[w])])
	lines.sort()
	lines.reverse()
	for line: String in lines:
		print(line)
	print("  %d shells, %d plates theirs, %d given back, %d cut off; cubes %s; joined %d, cut %d" % [
		frames.size(), shelled.size(), given.size(), cut.size(), str(last.get("cubes", {})),
		int(last.get("joined_cut_off", 0)), int(last.get("cut_off", 0))])


## Where cell [param key] is against the nearest shell, in its frame: in its
## box, behind it (between it and the core), past its face, over or under it,
## at its end, or off a corner.
func _where(key: Vector3i, frames: Array) -> String:
	var best: String = "no shell near"
	var best_d: int = 1 << 30
	for frame: Dictionary in frames:
		var facing: Vector2i = frame["facing"]
		var lt: Vector2i = Shapes.Plan._lane(Vector2i(key.x, key.z), facing, frame["along"])
		var face: int = frame["face"]
		var deep: int = ceili(float(frame["depth"]) / Shapes.PLATES_PER_STUD)
		var top: int = frame["top"]
		var bottom: int = top - roundi(float(frame["rows"]) * Shapes.PLATES_PER_STUD)
		var da: int = maxi(0, maxi(int(frame["a0"]) - lt.x, lt.x - (int(frame["a1"]) - 1)))
		var dt: int = maxi(0, maxi(face - lt.y, lt.y - (face + deep - 1)))
		var dj: int = maxi(0, maxi(bottom - key.y, key.y - (top - 1)))
		var d: int = da + dt + dj
		if d >= best_d:
			continue
		best_d = d
		if d == 0:
			best = "in its box"
		elif da == 0 and dj == 0:
			best = "behind it" if lt.y < face else "past its face"
		elif da == 0 and dt == 0:
			best = "over it" if key.y >= top else "under it"
		elif dj == 0 and dt == 0:
			best = "at its end"
		else:
			best = "off its corner"
	return best
