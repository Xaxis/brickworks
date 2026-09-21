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

	for name: String in ["house","tree","bench","tower","boat","rocket","car","lighthouse"]:
		world.clear()
		builder.lattice.clear()
		var model: LdrModel = LdrModel.load_file("res://models/%s.ldr" % name)
		if model == null:
			print("%s: no file" % name); continue
		var ids: Array = []
		var cells_of: Dictionary = {}
		var missing: int = 0
		for item: Variant in model.flatten(library.parts):
			var p: LdrModel.Placement = item
			var mesh: Lbm.PartMesh = library.mesh_for(p.part_id)
			if mesh == null:
				missing += 1
				continue
			var id: int = world.add_brick(p.part_id, p.color_code, p.transform)
			if id == 0:
				missing += 1
				continue
			var cells: Array[Vector3i] = builder._cells_for(mesh, p.transform)
			var blocked: PackedInt64Array = builder.lattice.blockers(cells)
			if not blocked.is_empty():
				print("   OVERLAP %s at %s hits brick %d" % [p.part_id, str(p.transform.origin), blocked[0]])
			builder.lattice.occupy(id, cells)
			cells_of[id] = cells
			ids.append(id)

		# occupancy map
		var occ: Dictionary = {}
		for id: int in cells_of:
			for c: Vector3i in cells_of[id]:
				occ[c] = id
		var vert: Array = [Vector3i(0,1,0), Vector3i(0,-1,0)]
		var orth: Array = [Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
		var v: Array = _components(ids, cells_of, occ, vert)
		var o: Array = _components(ids, cells_of, occ, orth)
		print("%-12s %3d bricks, %6d cells, missing=%d | vertical %s | ortho %s" % [
			name, ids.size(), occ.size(), missing, str(v), str(o)])
	quit(0)

func _components(ids: Array, cells_of: Dictionary, occ: Dictionary, steps: Array) -> Array:
	var adj: Dictionary = {}
	for id: int in ids:
		adj[id] = {}
	for id: int in ids:
		for c: Vector3i in cells_of[id]:
			for d: Vector3i in steps:
				var other: int = occ.get(c + d, 0)
				if other != 0 and other != id:
					adj[id][other] = true
					adj[other][id] = true
	var seen: Dictionary = {}
	var sizes: Array = []
	for start: int in ids:
		if seen.has(start): continue
		seen[start] = true
		var queue: Array = [start]
		var n: int = 0
		while not queue.is_empty():
			var cur: int = queue.pop_back()
			n += 1
			for nxt: int in adj[cur]:
				if not seen.has(nxt):
					seen[nxt] = true
					queue.append(nxt)
		sizes.append(n)
	sizes.sort()
	sizes.reverse()
	return sizes
