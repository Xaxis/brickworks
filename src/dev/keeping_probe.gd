## Does the app keep what it was given?
##
##   godot --headless --path . --script src/dev/keeping_probe.gd
##
## Two ways it did not, both silent and both permanent.
##
## A brick marked as scenery is left out of Save, Export, the parts list
## and the booklet. BrickWorld numbers from one again after a clear, so
## a stale id in that set names an ordinary brick placed later — and
## somebody builds the thing, saves it, and finds a piece missing with
## nothing to explain why.
##
## And a model that opened short of parts — which on the web is any
## model using geometry that had not arrived yet — was written straight
## back over the file it came from by the autosave a second later,
## turning a few seconds of network into a deletion.
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
	var store := ModelStore.new()
	store.world = world
	store.builder = builder
	store.library = library
	await process_frame

	_scenery_after_clear(world, builder, store)
	print("")
	_short_open(store, world)

	print("")
	if _failures == 0:
		print("nothing is kept that should go, and nothing lost that should stay")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## A brick placed after a clear must not inherit the baseplate's place
## in the scenery set.
func _scenery_after_clear(world: BrickWorld, builder: Builder,
		store: ModelStore) -> void:
	var plate := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var plate_id: int = world.add_brick("3811", 288, plate)
	builder.register(plate_id, "3811", plate)
	store.scenery[plate_id] = true
	print("  a baseplate, which is scenery, is brick %d" % plate_id)

	# Clear, the way the app does it.
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	store.scenery.clear()

	# And build something. Its first brick takes the number the
	# baseplate had.
	var at := Transform3D(Basis.IDENTITY, Vector3(40.0, 24.0, 40.0))
	var brick_id: int = world.add_brick("3001", 4, at)
	builder.register(brick_id, "3001", at)
	print("  after clearing, the first brick placed is brick %d" % brick_id)

	if store.scenery.has(brick_id):
		_failures += 1
		print("  FAIL  it was counted as scenery")
	else:
		print("  ok    it is not counted as scenery")

	var text: String = store.to_text("After")
	if text.contains("3001"):
		print("  ok    and it is in the saved model")
	else:
		_failures += 1
		print("  FAIL  it is missing from the saved model")
	world.clear()
	builder.lattice.clear()


## A model that could not be opened whole must not be written back over
## the file it came from.
func _short_open(store: ModelStore, world: BrickWorld) -> void:
	var whole: String = "0 Whole\n" \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" \
		+ "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
	store.open_text(whole, "whole.ldr")
	if store.whole:
		print("  ok    a model that opened whole is marked so")
	else:
		_failures += 1
		print("  FAIL  a model that opened whole was marked short")

	# One part real, one that this library does not have.
	var short: String = "0 Short\n" \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" \
		+ "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 9999991.dat\n"
	var result: Dictionary = store.open_text(short, "short.ldr")
	if int(result["placed"]) == 1 and int(result["missing"]) == 1:
		print("  ok    a model missing a part opens with the rest of it")
	else:
		_failures += 1
		print("  FAIL  %d placed, %d missing" % [
			int(result["placed"]), int(result["missing"])])

	if store.whole:
		_failures += 1
		print("  FAIL  and it was marked whole, so the autosave would "
			+ "write it back over the file it came from")
	else:
		print("  ok    and it is marked short, so the autosave leaves "
			+ "the file alone")

	# Until somebody changes it by hand, at which point it is theirs.
	store.adopt()
	if store.whole:
		print("  ok    changing it by hand makes it theirs to save")
	else:
		_failures += 1
		print("  FAIL  it is still marked short after being edited")
	world.clear()
