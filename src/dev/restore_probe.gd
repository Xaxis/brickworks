## A design that fails must leave the model it was asked to change.
##
##   godot --headless --path . --script src/dev/restore_probe.gd
##
## Every path through a design replaces what the assistant built: the
## submission, each repair, and each draft shown along the way. That is
## right when the design succeeds and ruinous when it does not, because
## the model being replaced is the one the person already had — and
## running out of repairs, cancelling, or losing the network are all
## ordinary endings, not rare ones.
##
## Checked without the network, by driving the same internals the loop
## drives.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	await process_frame

	# Something the person has: three bricks by hand.
	var by_hand: Array[Transform3D] = []
	for column: int in 3:
		var at := Transform3D(Basis.IDENTITY, Vector3(column * 80.0 + 40.0, 24.0, 40.0))
		by_hand.append(at)
		var id: int = world.add_brick("3001", 4, at)
		builder.register(id, "3001", at)

	# And something the assistant built for them last time.
	var previous := Assistant.Model.new()
	for column: int in 2:
		var placement := Assistant.Placement.new()
		placement.part = "3005"
		placement.color = 1
		placement.x = column
		placement.y = 3
		placement.z = 4
		previous.placements.append(placement)
	assistant._apply(previous)
	var whole: int = world.brick_count()
	_check("a model of %d bricks to start with" % whole, whole == 5)

	# A new instruction begins. The snapshot is taken here; _start would
	# also fire a request, and this is about what happens to the model
	# rather than about the network.
	assistant._before = assistant._snapshot()
	_check("the snapshot holds %d bricks" % assistant._before.size(),
		assistant._before.size() == whole)

	# It shows a draft, which replaces what it built before.
	var draft := Assistant.Model.new()
	var one := Assistant.Placement.new()
	one.part = "3024"
	one.color = 14
	one.x = 0
	one.y = 3
	one.z = 0
	draft.placements.append(one)
	assistant._apply(draft, false)
	_check("the draft replaced its previous work, now %d bricks"
		% world.brick_count(), world.brick_count() < whole)

	# And then it fails, as designs do.
	assistant._stop(false, "ran out of repairs")
	_check("the model came back: %d bricks" % world.brick_count(),
		world.brick_count() == whole)

	var hand_survived: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		for at: Transform3D in by_hand:
			if brick.transform.origin.is_equal_approx(at.origin) and brick.part_id == "3001":
				hand_survived += 1
	_check("all three hand-placed bricks are where they were, got %d"
		% hand_survived, hand_survived == 3)

	# And the assistant still knows which bricks are its own, or the
	# next design would refuse to replace them.
	var mine: int = assistant.built_count()
	_check("it still owns the two it built, got %d" % mine, mine == 2)

	print("")
	print("%d failed" % _failures if _failures
		else "a failed design leaves the model it found")
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
