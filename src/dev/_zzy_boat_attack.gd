## Which parts of boat.ldr / car.ldr are loose, and does the app's own
## support test flag anything?
extends SceneTree


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	for name: String in ["boat", "car"]:
		print("== %s" % name)
		_one(library, name)
	quit(0)


func _one(library: PartLibrary, name: String) -> void:
	var model: LdrModel = LdrModel.load_file("res://models/%s.ldr" % name)
	var placements: Array = model.flatten(library.parts)
	var lattice := BrickLattice.new()
	var cells_of: Dictionary = {}
	var label: Dictionary = {}
	var index: int = 0
	for p: Variant in placements:
		index += 1
		var mesh: Lbm.PartMesh = library.mesh_for(p.part_id)
		if mesh == null:
			continue
		var cells: Array[Vector3i] = BrickLattice.cells_for(
			mesh.boxes, BrickLattice.to_cell(p.transform.origin),
			BrickLattice.snap_basis(p.transform.basis))
		if not lattice.blockers(cells).is_empty():
			print("   overlap: #%d %s at %v" % [index, p.part_id, p.transform.origin])
			continue
		lattice.occupy(index, cells)
		cells_of[index] = cells
		label[index] = "%s at %v" % [p.part_id, p.transform.origin]

	# support
	for id: int in cells_of:
		var cells: Array[Vector3i] = cells_of[id]
		var floor_y: int = 0x7FFFFFFF
		for c: Vector3i in cells:
			floor_y = mini(floor_y, c.y)
		if floor_y <= 0:
			continue
		var ok: bool = false
		for c: Vector3i in cells:
			if c.y != floor_y:
				continue
			var b: int = lattice.brick_at(Vector3i(c.x, c.y - 1, c.z))
			if b != 0 and b != id:
				ok = true
				break
		if not ok:
			print("   floating: #%d %s (floor cell y=%d)" % [id, label[id], floor_y])

	var nbr: Dictionary = {}
	for id: int in cells_of:
		nbr[id] = {}
	for id: int in cells_of:
		for c: Vector3i in cells_of[id]:
			for step: int in [-1, 1]:
				var o: int = lattice.brick_at(Vector3i(c.x, c.y + step, c.z))
				if o != 0 and o != id and cells_of.has(o):
					nbr[id][o] = true
					nbr[o][id] = true
	var seen: Dictionary = {}
	for start: int in cells_of:
		if seen.has(start):
			continue
		var members: Array = []
		var q: Array = [start]
		seen[start] = true
		while not q.is_empty():
			var cur: int = q.pop_back()
			members.append(cur)
			for nx: int in nbr[cur]:
				if not seen.has(nx):
					seen[nx] = true
					q.append(nx)
		if members.size() <= 6:
			var names: PackedStringArray = PackedStringArray()
			for m: int in members:
				names.append(label[m])
			print("   loose group of %d: %s" % [members.size(), ", ".join(names)])
		else:
			print("   main group of %d" % members.size())
