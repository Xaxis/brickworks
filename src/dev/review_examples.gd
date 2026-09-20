## Look at every example that ships, and say whether it holds up.
##
##   godot --path . --script src/dev/review_examples.gd
##
## These are the first models anybody opens, so they are the app arguing
## for itself. Two things can be wrong with one and only one of them can
## be checked by a machine: whether it stands, and whether it looks like
## the thing it is called.
##
## So this does the half it can — piece count, weight, stability, and a
## render of each to shots/ — and leaves the other half to a person
## looking at the pictures. The tree that came out of the first batch
## passed every automatic check and was a green slab on a stump.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
		RenderingServer.force_draw(false)

	var store: ModelStore = main.get("_store")
	var world: BrickWorld = main.get("_world")
	var library: PartLibrary = main.get("_library")
	var stability: Stability = main.get("_stability")
	var examples: Array[ModelStore.Entry] = store.list_examples()
	if examples.is_empty():
		print("no examples in res://models/")
		quit(1)
		return

	print("")
	print("  %-14s %6s %8s %7s  %s" % ["model", "bricks", "lots", "weight", "stability"])
	for entry: ModelStore.Entry in examples:
		world.clear()
		main.get("_builder").lattice.clear()
		store.open(entry.path)
		for _n: int in 40:
			await process_frame
			RenderingServer.force_draw(false)
		main.get("_camera").frame(world.model_bounds(), 1.05)
		for _n: int in 60:
			await process_frame
			RenderingServer.force_draw(false)

		var stock: Inventory = Inventory.of(world, library, store.scenery)
		var report: Stability.Report = stability.check(world)
		print("  %-14s %6d %8d %7s  %s" % [
			entry.name, world.brick_count(), stock.lot_count(),
			stock.weight(), report.summary()])

		var shot := "shots/ex_%s.png" % entry.name.to_lower()
		root.get_texture().get_image().get_region(
			Rect2i(380, 80, 760, 680)).save_png(shot)

	print("")
	print("  pictures in shots/ex_*.png — look at them before shipping one")
	quit()
