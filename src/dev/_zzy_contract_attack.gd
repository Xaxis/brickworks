## Attack probe: does the app's own _check pass the shipped models, and
## is any of them disconnected under the rule the prompt calls the one
## that catches people?
##
##   godot --headless --path . --script src/dev/_zzy_contract_attack.gd
extends SceneTree

const FILES: Array[String] = [
	"house", "tree", "bench", "tower", "boat", "rocket", "lighthouse", "car",
]


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return

	for name: String in FILES:
		_one(library, name)
	quit(0)


func _one(library: PartLibrary, name: String) -> void:
	var model: LdrModel = LdrModel.load_file("res://models/%s.ldr" % name)
	if model == null:
		print("%-11s could not load" % name); return
	var placements: Array = model.flatten(library.parts)

	var lattice := BrickLattice.new()
	var cells_of: Dictionary = {}
	var overlaps: int = 0
	var missing: int = 0
	var index: int = 0
	for p: Variant in placements:
		index += 1
		var info: PartLibrary.PartInfo = library.parts.get(p.part_id)
		var mesh: Lbm.PartMesh = library.mesh_for(p.part_id)
		if info == null or mesh == null:
			missing += 1
			continue
		var boxes: Array[AABB] = mesh.boxes
		if boxes.is_empty():
			var b: AABB = mesh.bounds
			boxes = [AABB(
				Vector3(floor(b.position.x / 2.0), floor(b.position.y / 2.0),
					floor(b.position.z / 2.0)),
				Vector3(ceil(b.size.x / 2.0), ceil(b.size.y / 2.0),
					ceil(b.size.z / 2.0)))]
		var cells: Array[Vector3i] = BrickLattice.cells_for(
			boxes, BrickLattice.to_cell(p.transform.origin),
			BrickLattice.snap_basis(p.transform.basis))
		var blockers: PackedInt64Array = lattice.blockers(cells)
		if not blockers.is_empty():
			overlaps += 1
			continue
		lattice.occupy(index, cells)
		cells_of[index] = cells

	# Connectivity, by the rule the system prompt states: only stacking
	# joins. Flood fill over vertical neighbours.
	var nbr: Dictionary = {}
	for id: int in cells_of:
		nbr[id] = {}
	for id: int in cells_of:
		for cell: Vector3i in cells_of[id]:
			for step: int in [-1, 1]:
				var other: int = lattice.brick_at(
					Vector3i(cell.x, cell.y + step, cell.z))
				if other != 0 and other != id and cells_of.has(other):
					nbr[id][other] = true
					nbr[other][id] = true

	var seen: Dictionary = {}
	var groups: int = 0
	var largest: int = 0
	for start: int in cells_of:
		if seen.has(start):
			continue
		groups += 1
		var size: int = 0
		var queue: Array = [start]
		seen[start] = true
		while not queue.is_empty():
			var cur: int = queue.pop_back()
			size += 1
			for nx: int in nbr[cur]:
				if not seen.has(nx):
					seen[nx] = true
					queue.append(nx)
		largest = maxi(largest, size)

	print("%-11s %3d parts | overlaps %2d | missing %2d | groups %2d (largest %3d)"
		% [name, placements.size(), overlaps, missing, groups, largest])
