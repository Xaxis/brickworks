## Undo has to belong to the model it was recorded against.
##
##   godot --headless --path . --script src/dev/history_probe.gd
##
## BrickWorld numbers bricks from one and starts again at one whenever
## it is cleared. A history kept across a Clear or an Open therefore
## refers to ids that now belong to different bricks — and undo does not
## fail on that, it succeeds: it removes whatever happens to hold the id
## a step remembers, out of a model that step never touched.
##
## The damage is quiet, which is why it is checked rather than watched
## for. Nothing errors. A brick simply goes.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	# A SceneTree script runs before the tree processes, so nodes added
	# here have not had _ready called. Builder makes its ghost there,
	# and update_preview would assign a mesh to nothing.
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
	await process_frame

	# Build something, by the path that records history.
	builder.held_part = "3001"
	builder.held_color = 4
	for column: int in 3:
		builder.update_preview(
			Vector3(column * 80.0 + 40.0, 400.0, 40.0), Vector3.DOWN)
		builder.place()
	_check("three bricks placed, got %d" % world.brick_count(),
		world.brick_count() == 3)
	_check("and three steps to undo, got %d" % builder.history_depth(),
		builder.history_depth() == 3)

	# Now replace the model, as Clear and Open both do.
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	_check("clearing leaves nothing to undo, got %d" % builder.history_depth(),
		builder.history_depth() == 0)

	# A different model, whose bricks take the same ids the old ones had.
	var at := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	var kept: int = world.add_brick("3005", 1, at)
	builder.register(kept, "3005", at)
	_check("the new brick reuses id %d" % kept, kept == 1)

	var before: int = world.brick_count()
	builder.undo()
	_check("undo does not touch a model it never saw, %d -> %d"
		% [before, world.brick_count()], world.brick_count() == before)
	_check("...and the brick is still the one that was put there",
		world.get_brick(kept) != null)

	print("")
	print("%d failed" % _failures if _failures
		else "undo belongs to the model it was recorded against")
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
