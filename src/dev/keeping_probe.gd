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
## turning a few seconds of network into a deletion. What it is short of
## is written back now, where the file had it.
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
	_on_the_ground(store, world, builder, library)

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


## A model that opened short of a part keeps it in what is written of it:
## the autosave a second after the open, Save, Export. Written without it,
## the autosave turned a part the library lacked into a deletion.
##
## Someone else's file keeps its own line (SourceFile). The app's own file
## wrote the model without it until 2026-10-20 (a part only a newer build's
## catalogue has), so the autosave refused it until somebody edited it, and
## then dropped the part (ModelStore._absent).
func _short_open(store: ModelStore, world: BrickWorld) -> void:
	for author: String in ["", "0 Author: Brickworks\n"]:
		var whose: String = "someone else's file" if author.is_empty() else "the app's own file"
		var short: String = "0 Short\n" + author \
			+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" \
			+ "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 9999991.dat\n"
		var result: Dictionary = store.open_text(short, "short.ldr")
		if int(result["placed"]) == 1 and int(result["missing"]) == 1:
			print("  ok    %s missing a part opens with the rest of it" % whose)
		else:
			_failures += 1
			print("  FAIL  %s: %d placed, %d missing" % [whose,
				int(result["placed"]), int(result["missing"])])
		# Changed by hand too: what it lacks is still the model's.
		store.adopt()
		var text: String = store.to_text("Short")
		if _places(text, "9999991", [0, -24, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]) \
				and _places(text, "3001", [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]):
			print("  ok    and what is written of it keeps the part, where it was")
		else:
			_failures += 1
			print("  FAIL  and what is written of it lost the part it lacks:\n%s" % text)
		world.clear()


## Whether [param text] places [param part_id] at [param numbers] (LDraw's
## twelve), to a hundredth of an LDU.
static func _places(text: String, part_id: String, numbers: Array) -> bool:
	for line: String in text.split("\n"):
		var cut: PackedStringArray = line.strip_edges().split(" ", false)
		if cut.size() != 15 or cut[0] != "1" or cut[14].get_basename() != part_id:
			continue
		var same: bool = true
		for n: int in 12:
			same = same and absf(cut[n + 2].to_float() - float(numbers[n])) <= 0.01
		if same:
			return true
	return false


## A model opens standing on the ground, not buried in it.
##
## The ground here is zero and nothing is meant to go under it. Other
## people's files do not know that: the LDraw demonstration car, which
## is what this app opens the very first time anybody runs it, is built
## around an origin one brick lower, so it arrived sunk to the axles in
## the baseplate. That was the first thing a new visitor saw.
func _on_the_ground(store: ModelStore, world: BrickWorld,
		builder: Builder, library: PartLibrary) -> void:
	for name: String in ["car", "house", "rocket", "tree"]:
		var path: String = "res://models/%s.ldr" % name
		if not FileAccess.file_exists(path):
			continue
		world.clear()
		builder.lattice.clear()
		if store.open(path) == 0:
			continue
		var lowest: int = 0x7FFFFFFF
		for brick: BrickWorld.Brick in world.bricks():
			var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if part == null:
				continue
			for cell: Vector3i in builder._cells_for(part, brick.transform):
				lowest = mini(lowest, cell.y)
		if lowest == 0:
			print("  ok    %s rests on the ground" % name)
		elif lowest > 0:
			print("  ok    %s floats %d cells clear, which is its own affair"
				% [name, lowest])
		else:
			_failures += 1
			print("  FAIL  %s is buried %d LDU into the baseplate"
				% [name, -lowest * 2])
	world.clear()
	builder.lattice.clear()
