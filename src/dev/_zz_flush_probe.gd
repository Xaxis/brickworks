extends SceneTree

func _initialize() -> void:
	await process_frame
	var library := PartLibrary.new()
	library.load_catalogue()
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var parts: Array[String] = []
	for q: String in ["brick", "plate"]:
		for info: PartLibrary.PartInfo in library.search(q, 60):
			if not info.is_redirect() and info.reachable:
				parts.append(info.id)
	for i: int in 400:
		library.request_mesh(parts[i % parts.size()])
		world.add_brick(parts[i % parts.size()], 1 + (i % 15),
			Transform3D(Basis.IDENTITY, Vector3((i % 20) * 200.0, (i / 20) * 24.0, 0.0)))
	await process_frame
	var batches: Dictionary = world.get("_batches")
	print("%d batches" % batches.size())

	# The whole of _flush with nothing dirty: the tally loop alone.
	var t0: int = Time.get_ticks_usec()
	for _n: int in 100:
		world.call("_flush")
	var t1: int = Time.get_ticks_usec()
	print("_flush with nothing dirty: %.2f ms each" % ((t1 - t0) / 100000.0))

	# surface_get_arrays across every batch, once.
	var t2: int = Time.get_ticks_usec()
	for _n: int in 100:
		for key: String in batches:
			var b: BrickWorld.Batch = batches[key]
			var m: Mesh = b.multimesh.mesh
			if m != null and m.get_surface_count() > 0:
				var _a: Array = m.surface_get_arrays(0)
	var t3: int = Time.get_ticks_usec()
	print("surface_get_arrays over every batch: %.2f ms each pass" % ((t3 - t2) / 100000.0))
	quit(0)
