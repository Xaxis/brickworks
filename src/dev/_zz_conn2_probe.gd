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

	# Which car bricks end up alone?
	var model: LdrModel = LdrModel.load_file("res://models/car.ldr")
	var cells_of: Dictionary = {}
	var part_of: Dictionary = {}
	var n: int = 0
	for item: Variant in model.flatten(library.parts):
		var p: LdrModel.Placement = item
		var mesh: Lbm.PartMesh = library.mesh_for(p.part_id)
		if mesh == null: continue
		cells_of[n] = builder._cells_for(mesh, p.transform)
		part_of[n] = "%s at %s" % [p.part_id, str(p.transform.origin)]
		n += 1
	var occ: Dictionary = {}
	for i: int in cells_of:
		for c: Vector3i in cells_of[i]:
			if not occ.has(c):
				occ[c] = i
	var adj: Dictionary = {}
	for i: int in cells_of:
		adj[i] = {}
	for i: int in cells_of:
		for c: Vector3i in cells_of[i]:
			for dy: int in [1, -1]:
				var o: int = occ.get(Vector3i(c.x, c.y + dy, c.z), -1)
				if o >= 0 and o != i:
					adj[i][o] = true
					adj[o][i] = true
	var seen: Dictionary = {}
	for start: int in cells_of:
		if seen.has(start): continue
		seen[start] = true
		var q: Array = [start]
		var members: Array = []
		while not q.is_empty():
			var cur: int = q.pop_back()
			members.append(cur)
			for nx: int in adj[cur]:
				if not seen.has(nx):
					seen[nx] = true
					q.append(nx)
		if members.size() < 5:
			var names := PackedStringArray()
			for m: int in members:
				names.append(part_of[m])
			print("car: component of %d -> %s" % [members.size(), ", ".join(names)])

	# Boundary-only connectivity: only each brick's top and bottom layers.
	for name: String in ["tower", "lighthouse"]:
		var m2: LdrModel = LdrModel.load_file("res://models/%s.ldr" % name)
		var co: Dictionary = {}
		var k: int = 0
		var lat := BrickLattice.new()
		for item: Variant in m2.flatten(library.parts):
			var p2: LdrModel.Placement = item
			var mesh2: Lbm.PartMesh = library.mesh_for(p2.part_id)
			if mesh2 == null: continue
			var cs: Array[Vector3i] = builder._cells_for(mesh2, p2.transform)
			lat.occupy(k + 1, cs)
			co[k] = cs
			k += 1
		var t0: int = Time.get_ticks_usec()
		var edges: int = 0
		for i: int in co:
			var cs2: Array[Vector3i] = co[i]
			var lo: int = 0x7FFFFFFF
			var hi: int = -0x7FFFFFFF
			for c: Vector3i in cs2:
				lo = mini(lo, c.y)
				hi = maxi(hi, c.y)
			for c: Vector3i in cs2:
				if c.y == lo and lat.brick_at(Vector3i(c.x, c.y - 1, c.z)) != 0:
					edges += 1
				elif c.y == hi and lat.brick_at(Vector3i(c.x, c.y + 1, c.z)) != 0:
					edges += 1
		var t1: int = Time.get_ticks_usec()
		print("%s: boundary-only contact pass %.1f ms (%d contacts), vs whole-volume" % [
			name, (t1 - t0) / 1000.0, edges])
	quit(0)
