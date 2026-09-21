## Temporary: replay the assistant's own _check over the shipped models.
extends SceneTree

var _library: PartLibrary
var _builder: Builder
var _world: BrickWorld
var _store: ModelStore
var _assistant: Assistant
var _stability: Stability


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	_library = main.get("_library")
	_builder = main.get("_builder")
	_world = main.get("_world")
	_store = main.get("_store")
	_assistant = main.get("_assistant")
	_stability = main.get("_stability")

	for name: String in ["house", "tree", "bench", "tower", "boat",
			"rocket", "car", "lighthouse"]:
		await _examine(name)
	print("")
	quit()


func _examine(name: String) -> void:
	_world.clear()
	_builder.lattice.clear()
	_store.open("res://models/%s.ldr" % name)
	for _n: int in 40:
		await process_frame

	var bricks: Array = _world.bricks()
	# Pass A: cells straight from the file's transforms.
	var lat_a := BrickLattice.new()
	var cells_a: Dictionary = {}
	var order: Array = []
	for brick: BrickWorld.Brick in bricks:
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			print("  %s: NO MESH for %s" % [name, brick.part_id])
			continue
		var cells: Array[Vector3i] = _builder._cells_for(mesh, brick.transform)
		cells_a[brick.id] = cells
		order.append(brick.id)
		lat_a.occupy(brick.id, cells)

	# Pass B: round-trip through the coordinates the model speaks.
	var model := Assistant.Model.new()
	var drift: int = 0
	var mapping: Array = []
	for brick: BrickWorld.Brick in bricks:
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		if info == null:
			continue
		var studs: Vector3i = _assistant._to_studs(brick, info)
		var p := Assistant.Placement.new()
		p.part = brick.part_id
		p.color = brick.color_code
		p.x = studs.x
		p.y = studs.y
		p.z = studs.z
		p.rot = Assistant._quarter_turns(brick.transform.basis)
		model.placements.append(p)
		mapping.append(brick.id)
		var back: Transform3D = _assistant._transform(p, null)
		if back.origin.distance_to(brick.transform.origin) > 0.01:
			drift += 1

	var report: Dictionary = _assistant._check(model)
	var comps: Dictionary = _components(lat_a, cells_a, order)
	print("")
	print("== %s : %d bricks ==" % [name, bricks.size()])
	print("  roundtrip drift: %d of %d" % [drift, model.placements.size()])
	print("  _check says: %s" % report["summary"])
	var fb: String = str(report["feedback"])
	for line: String in fb.split("\n"):
		print("    | %s" % line)
	print("  components (vertical adjacency): %s" % str(comps["sizes"]))
	print("  floating by pass A: %d  %s" % [
		comps["floating"].size(), str(comps["floating"].slice(0, 8))])


## Union-find over vertical cell adjacency, on the file's own geometry.
func _components(
	lat: BrickLattice, cells_of: Dictionary, order: Array
) -> Dictionary:
	var parent: Dictionary = {}
	for id: int in order:
		parent[id] = id

	var floating: Array = []
	for id: int in order:
		var cells: Array[Vector3i] = cells_of[id]
		var floor_y: int = 0x7FFFFFFF
		for cell: Vector3i in cells:
			floor_y = mini(floor_y, cell.y)
		var held: bool = floor_y <= 0
		for cell: Vector3i in cells:
			var up: int = lat.brick_at(Vector3i(cell.x, cell.y + 1, cell.z))
			if up != 0 and up != id:
				_union(parent, id, up)
			var down: int = lat.brick_at(Vector3i(cell.x, cell.y - 1, cell.z))
			if down != 0 and down != id:
				_union(parent, id, down)
				if cell.y == floor_y:
					held = true
		if not held:
			floating.append(id)

	var counts: Dictionary = {}
	for id: int in order:
		var root: int = _find(parent, id)
		counts[root] = int(counts.get(root, 0)) + 1
	var sizes: Array = counts.values()
	sizes.sort()
	sizes.reverse()
	return {"sizes": sizes, "floating": floating}


func _find(parent: Dictionary, a: int) -> int:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a


func _union(parent: Dictionary, a: int, b: int) -> void:
	var ra: int = _find(parent, a)
	var rb: int = _find(parent, b)
	if ra != rb:
		parent[rb] = ra
