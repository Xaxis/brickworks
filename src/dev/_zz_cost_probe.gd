extends SceneTree

func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.library = library
	builder.world = world
	root.add_child(builder)

	# 1. Does the live baseplate touch a brick resting at y = 0?
	var plate_at := Transform3D(Basis.IDENTITY, Vector3(0.0, -8.0, 0.0))
	var plate_mesh: Lbm.PartMesh = library.mesh_for("3811")
	var plate_cells: Array[Vector3i] = builder._cells_for(plate_mesh, plate_at)
	var top: int = -99999
	for c: Vector3i in plate_cells:
		top = maxi(top, c.y)
	print("baseplate 3811 at y=-8: %d cells, top cell y=%d" % [plate_cells.size(), top])
	var brick_mesh: Lbm.PartMesh = library.mesh_for("3001")
	# assistant _transform for x=0,y=0,z=0: origin = (across/2*20, 3*8, deep/2*20)
	var brick_at := Transform3D(Basis.IDENTITY, Vector3(40.0, 24.0, 20.0))
	var brick_cells: Array[Vector3i] = builder._cells_for(brick_mesh, brick_at)
	var low: int = 99999
	for c: Vector3i in brick_cells:
		low = mini(low, c.y)
	print("3001 placed at plate y=0: lowest cell y=%d  -> gap of %d cells" % [low, low - top - 1])

	# do they actually share a column so vertical adjacency would fire?
	builder.lattice.clear()
	builder.lattice.occupy(1, plate_cells)
	var touching: int = 0
	for c: Vector3i in brick_cells:
		if builder.lattice.brick_at(Vector3i(c.x, c.y - 1, c.z)) != 0:
			touching += 1
	print("cells of the brick with baseplate directly beneath: %d" % touching)

	# 2. Cost of a full re-check, on the biggest shipped models.
	for name: String in ["tower", "lighthouse", "boat"]:
		var model: LdrModel = LdrModel.load_file("res://models/%s.ldr" % name)
		var places: Array = model.flatten(library.parts)
		var t0: int = Time.get_ticks_usec()
		var lattice := BrickLattice.new()
		var cells_of: Dictionary = {}
		var n: int = 0
		for item: Variant in places:
			var p: LdrModel.Placement = item
			var mesh: Lbm.PartMesh = library.mesh_for(p.part_id)
			if mesh == null: continue
			var cells: Array[Vector3i] = builder._cells_for(mesh, p.transform)
			lattice.blockers(cells)
			lattice.occupy(n + 1, cells)
			cells_of[n] = cells
			n += 1
		var t1: int = Time.get_ticks_usec()
		# support pass, as _check_support does it
		for index: int in cells_of:
			var cells: Array[Vector3i] = cells_of[index]
			var floor_y: int = 0x7FFFFFFF
			for cell: Vector3i in cells:
				floor_y = mini(floor_y, cell.y)
			for cell: Vector3i in cells:
				if cell.y == floor_y:
					lattice.brick_at(Vector3i(cell.x, cell.y - 1, cell.z))
		var t2: int = Time.get_ticks_usec()
		# connectivity, vertical only
		var occ: Dictionary = {}
		for index: int in cells_of:
			for c: Vector3i in cells_of[index]:
				occ[c] = index
		var adj: Dictionary = {}
		for index: int in cells_of:
			for c: Vector3i in cells_of[index]:
				for dy: int in [1, -1]:
					var other: Variant = occ.get(Vector3i(c.x, c.y + dy, c.z))
					if other != null and int(other) != index:
						adj[index] = true
		var t3: int = Time.get_ticks_usec()
		print("%-11s %3d bricks: rasterise+collide %5.1f ms, support %4.1f ms, connectivity(vertical) %5.1f ms" % [
			name, n, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0])
	quit(0)
