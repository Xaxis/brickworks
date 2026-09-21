extends SceneTree

# What a per-brick reveal costs when the model is big and homogeneous —
# the case the landing animation would hit hardest, because show_only()
# flushes synchronously and a flush rebuilds every instance of every
# touched batch.
func _initialize() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	for total: int in [500, 2000]:
		world.clear()
		var ids := PackedInt64Array()
		for i: int in total:
			var id: int = world.add_brick("3001", 4, Transform3D(Basis.IDENTITY,
				Vector3((i % 40) * 80.0, (i / 40) * 24.0, 0.0)))
			if id != 0: ids.append(id)
		await process_frame

		# Per-step, as today: 8 bricks at a time.
		var showing: Dictionary = {}
		var t0: int = Time.get_ticks_usec()
		var n: int = 0
		for id: int in ids:
			showing[id] = true
			n += 1
			if n % 8 == 0:
				world.show_only(showing)
		var t1: int = Time.get_ticks_usec()

		# Per-brick, as a landing animation must reveal.
		showing = {}
		var t2: int = Time.get_ticks_usec()
		for id: int in ids:
			showing[id] = true
			world.show_only(showing)
		var t3: int = Time.get_ticks_usec()

		print("%4d bricks, %d batches:  per-step %.1f ms total (%.2f ms/flush)   per-brick %.1f ms total (%.2f ms/flush)" % [
			total, (world.get("_batches") as Dictionary).size(),
			(t1 - t0) / 1000.0, (t1 - t0) / 1000.0 / (total / 8.0),
			(t3 - t2) / 1000.0, (t3 - t2) / 1000.0 / total])
	quit(0)
