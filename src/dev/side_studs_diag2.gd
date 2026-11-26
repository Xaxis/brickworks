extends SceneTree
## A model laid as Brickify.build lays it, checked once before the mend: each
## part the check says nothing holds up (floating, unheld), and every stud
## between it and any other part by the parts' own shapes (socket at the stud's
## foot), so a part held by a side stud the check misses shows (snot6).
##
##   SNOT_TRY=back1 godot --headless --path . --script src/dev/side_studs_diag2.gd -- --mesh=FILE --up=Y --studs=48

var _library: PartLibrary
var _checker: Assistant
var _builder: Builder


func _initialize() -> void:
	_run()


func _arg(name: String, fallback: String = "") -> String:
	for one: String in OS.get_cmdline_user_args():
		if one.begins_with("--%s=" % name):
			return one.substr(name.length() + 3)
	return fallback


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	_builder = Builder.new()
	_builder.world = world
	_builder.library = _library
	root.add_child(_builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = world
	_checker.builder = _builder
	await process_frame
	var path: String = _arg("mesh")
	var read: Dictionary = MeshFilePicker.read_path(path)
	var mesh: MeshFile = MeshFile.read(read["bytes"], path.get_file(), read["extras"])
	var options := Brickify.Options.new()
	options.studs = int(_arg("studs", "48"))
	options.up = _arg("up", mesh.up)
	var grid: Brickify.Grid = Brickify.voxelise(mesh, options, _library)
	var trouble: Array = []
	var made: Array = Shapes.lay(Brickify.pattern(grid, options), trouble, _library)
	var model := Assistant.Model.new()
	for raw: Dictionary in made:
		var one: Dictionary = raw
		if one.has("panel"):
			var tile: Dictionary = _checker._panel(one, str(one["panel"]))
			one.erase("panel")
			if not tile.is_empty():
				model.placements.append(Assistant.Placement.from_dict(tile))
		model.placements.append(Assistant.Placement.from_dict(one))
	Brickify.made_colours(model, options, _library)
	if grid.stand.has_area():
		Brickify.lay_stand(model, grid.stand, grid.stand_why, _checker, options.smooth, grid.stand_colour)
	var report: Dictionary = _checker._check(model, true, false, true, false)
	var floating: Array = report.get("floating", [])
	var unheld: Array = report.get("unheld", [])
	print("parts %d, pieces %d, floating %d, unheld %d, kinds %s" % [model.placements.size(),
		int(report.get("pieces", 0)), floating.size(), unheld.size(), str(report.get("kinds", []))])
	var at_of: Array = []
	var boxes: Array = []
	for p: Assistant.Placement in model.placements:
		var part: Lbm.PartMesh = _library.mesh_for(p.part)
		var at: Transform3D = _checker._transform(p, part) if part != null else Transform3D()
		at_of.append(at)
		boxes.append(at * part.bounds if part != null else AABB())
	var asked: Dictionary = {}
	for index: Variant in floating + unheld:
		asked[int(index)] = "floating" if floating.has(index) else "unheld"
	var shown: int = 0
	var held_by_shape: int = 0
	var into_held: int = 0
	for index: Variant in asked:
		var n: int = int(index)
		var p: Assistant.Placement = model.placements[n]
		var mesh_n: Lbm.PartMesh = _library.mesh_for(p.part)
		var joins: PackedStringArray = []
		var to_held: bool = false
		# Its studs into another's socket, and another's studs into its own.
		for m: int in model.placements.size():
			if m == n or not (boxes[n] as AABB).grow(6.0).intersects(boxes[m]):
				continue
			var q: Assistant.Placement = model.placements[m]
			var mesh_m: Lbm.PartMesh = _library.mesh_for(q.part)
			for pair: Array in [[n, mesh_n, m, mesh_m, "its stud into"], [m, mesh_m, n, mesh_n, "a stud of"]]:
				var whose: int = pair[0]
				var into: int = pair[2]
				for connector: Lbm.Connector in (pair[1] as Lbm.PartMesh).connectors:
					if connector.kind != "stud" or connector.gender != "male":
						continue
					var foot: Vector3 = (at_of[whose] as Transform3D) * connector.position
					var way: Vector3 = ((at_of[whose] as Transform3D).basis * connector.axis).normalized()
					if Joints.socket_at(at_of[into], pair[3], foot, way):
						if not asked.has(m):
							to_held = true
						joins.append("%s %s #%d (%s, way %s)%s" % [pair[4], model.placements[m].part, m,
							model.placements[m].face, way.snapped(Vector3.ONE * 0.01),
							"" if asked.has(m) else " HELD"])
		if not joins.is_empty():
			held_by_shape += 1
		if to_held:
			into_held += 1
			print("into a held part: #%d %s face %s: %s" % [n, p.part, p.face, "; ".join(joins)])
		if shown < 40:
			shown += 1
			print("%s #%d %s face %s at %s: %s" % [asked[index], n, p.part, p.face, Vector3(p.x, p.y, p.z),
				"; ".join(joins) if not joins.is_empty() else "no stud in a socket either way"])
	print("%d of %d held by a stud in a socket, by the parts' shapes; %d by a stud into a part the check holds"
		% [held_by_shape, asked.size(), into_held])
	# What the loose parts touch of the rest, and which way: the part and its face.
	var touching: Dictionary = {}
	for index: Variant in asked:
		var n: int = int(index)
		for m: int in model.placements.size():
			if asked.has(m) or not (boxes[n] as AABB).grow(0.5).intersects(boxes[m]):
				continue
			var both: AABB = (boxes[n] as AABB).grow(0.5).intersection(boxes[m])
			var thin: String = "x" if both.size.x <= both.size.y and both.size.x <= both.size.z \
				else ("y" if both.size.y <= both.size.z else "z")
			var key: String = "%s face %s, across %s" % [model.placements[m].part, model.placements[m].face, thin]
			touching[key] = int(touching.get(key, 0)) + 1
	for key: String in touching:
		print("  touches %s: %d" % [key, touching[key]])
	var lowest: float = INF
	for index: Variant in asked:
		lowest = minf(lowest, (boxes[int(index)] as AABB).position.y)
	print("loose parts' lowest y %.1f LDU (y down, the floor the largest)" % lowest)
	# With --dump=FILE, every part (its index, part, face, colour, box in LDU)
	# and the loose ones, as JSON, for reading where they meet the rest (snot7).
	if _arg("dump") != "":
		var parts: Array = []
		for n: int in model.placements.size():
			var p: Assistant.Placement = model.placements[n]
			var b: AABB = boxes[n]
			parts.append({"id": n, "part": p.part, "face": p.face, "color": p.color, "box": [b.position.x,
				b.position.y, b.position.z, b.end.x, b.end.y, b.end.z]})
		var file := FileAccess.open(_arg("dump"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"parts": parts, "pieces": [{"ids": asked.keys(), "beyond": -1,
			"held_by": -1, "ratio": 0.0, "at": [0, 0, 0]}]}))
		file.close()
	quit(0)
