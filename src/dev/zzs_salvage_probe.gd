## Temporary: would "build the subset in cells_of" actually build?
##
##   godot --headless --path . --script src/dev/zzs_salvage_probe.gd
##
## No network. Builds two designs whose answers are known by hand, runs
## the assistant's real _check on them, then runs it again on the subset
## the salvage proposal would place.
extends SceneTree


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)

	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)

	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)

	# Case 1: the reporter's own example, shrunk. Eight bricks in a
	# staggered stack that holds, two bricks floating in mid air.
	var one: Array = []
	for n: int in 8:
		one.append([ "3001", (n % 2) * 2, n * 3, 0 ])
	one.append(["3001", 0, 30, 0])   # nothing beneath it
	one.append(["3001", 8, 3, 0])    # nothing beneath it
	_case(assistant, builder, library, "eight good, two floating", one)

	# Case 2: one overlap at the bottom of a column of five.
	var two: Array = []
	two.append(["3001", 0, 0, 0])      # studs 0..3
	two.append(["3001", 3, 0, 0])      # studs 3..6: overlaps brick 0
	for n: int in 5:
		two.append(["3001", 5, 3 + n * 3, 0])   # studs 5..8, on brick 1 only
	_case(assistant, builder, library, "one overlap under a column", two)

	quit(0)


func _case(assistant: Assistant, builder: Builder, library: PartLibrary,
		label: String, rows: Array) -> void:
	var model := Assistant.Model.new()
	for row: Array in rows:
		model.placements.append(Assistant.Placement.from_dict({
			"part": row[0], "x": row[1], "y": row[2], "z": row[3], "rot": 0,
			"color": 4}))

	var report: Dictionary = assistant._check(model)
	print("\n== %s: %d bricks ==" % [label, model.placements.size()])
	print("what the person is told: \"could not make it hold together: %s\""
		% report["summary"])

	# The proposal's subset: exactly the loop in _check that fills
	# cells_of, copied, so what it keeps can be looked at.
	var lattice := BrickLattice.new()
	var kept: Array[int] = []
	for index: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		if placement.y < 0:
			continue
		var at: Transform3D = assistant._transform(placement, part)
		var cells: Array[Vector3i] = builder._cells_for(part, at)
		if not lattice.blockers(cells).is_empty():
			continue
		lattice.occupy(index + 1, cells)
		kept.append(index)
	print("cells_of keeps %d of %d: %s" % [
		kept.size(), model.placements.size(), str(kept)])

	var subset := Assistant.Model.new()
	for index: int in kept:
		subset.placements.append(model.placements[index])
	var again: Dictionary = assistant._check(subset)
	print("the salvaged subset, re-checked: ok=%s, %s"
		% [again["ok"], again["summary"]])
	if not again["ok"]:
		print(again["feedback"])
