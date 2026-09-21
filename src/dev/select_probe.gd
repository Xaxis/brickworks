## Can several bricks be worked on at once, and taken back at once?
##
##   godot --headless --path . --script src/dev/select_probe.gd
##
## Every edit before this was one brick at a time, which is fine for
## placing and hopeless for changing your mind: recolouring a roof was
## forty clicks and moving a wall meant taking it apart.
##
## Two things are easy to get wrong here and neither announces itself.
## A group of changes that undoes one change at a time is not an
## improvement on making them one at a time. And a move that shifts the
## bricks that fit and leaves the rest turns one wall into two half
## walls, with nothing to say so until much later.
extends SceneTree

var _failures: int = 0


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
	await process_frame

	# A wall of six, two courses of three.
	var ids: Array[int] = []
	for course: int in 2:
		for n: int in 3:
			var at := Transform3D(Basis.IDENTITY, Vector3(
				n * 80.0 + 40.0, course * 24.0 + 24.0, 20.0))
			var brick_id: int = world.add_brick("3001", 4, at)
			builder.register(brick_id, "3001", at)
			ids.append(brick_id)
	print("  a wall of %d" % ids.size())
	print("")

	for brick_id: int in ids:
		builder.selection[brick_id] = true

	# Painting all six is one change as far as undo is concerned.
	var painted: int = builder.paint_selection(1)
	_expect("painted six in one go", painted == 6, "%d painted" % painted)
	_expect("all six are blue now", _colours(world) == {1: 6},
		str(_colours(world)))
	builder.undo()
	_expect("one undo put all six back to red", _colours(world) == {4: 6},
		str(_colours(world)))
	builder.redo()
	_expect("and one redo made them blue again", _colours(world) == {1: 6},
		str(_colours(world)))

	print("")
	# Moving the lot two studs along.
	var before: Array = _places(world)
	var moved: int = builder.move_selection(
		Vector3i(BrickLattice.CELLS_PER_STUD * 2, 0, 0))
	_expect("moved six two studs", moved == 6, "%d moved" % moved)
	var shifted: bool = true
	for n: int in before.size():
		if not (_places(world)[n] as Vector3).is_equal_approx(
				(before[n] as Vector3) + Vector3(40.0, 0.0, 0.0)):
			shifted = false
	_expect("every one of them by the same two studs", shifted, "not all")
	builder.undo()
	_expect("one undo moved them all back", _places(world) == before,
		"positions differ")

	print("")
	# A move that cannot happen must not half happen.
	var wall: Transform3D = Transform3D(Basis.IDENTITY,
		Vector3(40.0 + 80.0 * 3, 24.0, 20.0))
	var blocker: int = world.add_brick("3001", 14, wall)
	builder.register(blocker, "3001", wall)
	var was: Array = _places(world)
	var refused: int = builder.move_selection(
		Vector3i(BrickLattice.CELLS_PER_STUD * 2, 0, 0))
	_expect("a move into something else is refused", refused == 0,
		"%d moved" % refused)
	_expect("and nothing moved at all", _places(world) == was,
		"some of it moved anyway")

	# And the lattice still knows where everything is, which is what
	# decides whether the next brick can be placed.
	var occupied: bool = true
	for brick: BrickWorld.Brick in world.bricks():
		var cells: Array[Vector3i] = builder._cells_for(
			library.mesh_for(brick.part_id), brick.transform)
		for cell: Vector3i in cells:
			if builder.lattice.brick_at(cell) != brick.id:
				occupied = false
	_expect("the lattice matches the world after all that", occupied,
		"a brick is somewhere the lattice does not think it is")

	print("")
	# Removing, and putting back.
	var count_before: int = world.brick_count()
	var gone: int = builder.remove_selection()
	_expect("removed six in one go", gone == 6, "%d removed" % gone)
	_expect("the selection is empty afterwards",
		builder.selection.is_empty(), "%d left in it" % builder.selection.size())
	builder.undo()
	_expect("one undo brought all six back",
		world.brick_count() == count_before,
		"%d bricks, wanted %d" % [world.brick_count(), count_before])

	print("")
	if _failures == 0:
		print("several bricks are one thing to change and one thing to undo")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _colours(world: BrickWorld) -> Dictionary:
	var tally: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if brick.color_code == 14:
			continue   # the blocker, which was never selected
		tally[brick.color_code] = int(tally.get(brick.color_code, 0)) + 1
	return tally


func _places(world: BrickWorld) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		out.append(brick.transform.origin)
	return out


func _expect(what: String, held: bool, detail: String) -> void:
	if held:
		print("  ok    %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s — %s" % [what, detail])
