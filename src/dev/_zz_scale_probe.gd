extends SceneTree

func _initialize() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	# Many distinct parts -> many batches, which is what _flush costs per.
	var parts: Array[String] = []
	for info: PartLibrary.PartInfo in library.search("brick", 60):
		if not info.is_redirect() and info.reachable:
			parts.append(info.id)
	for info: PartLibrary.PartInfo in library.search("plate", 60):
		if not info.is_redirect() and info.reachable:
			parts.append(info.id)
	print("%d distinct parts to hand" % parts.size())

	var ids := PackedInt64Array()
	var n: int = 0
	for i: int in 400:
		var part: String = parts[i % parts.size()]
		library.request_mesh(part)
		var at := Transform3D(Basis.IDENTITY,
			Vector3((i % 20) * 200.0, (i / 20) * 24.0, 0.0))
		var id: int = world.add_brick(part, 1 + (i % 15), at)
		if id != 0:
			ids.append(id); n += 1
	await process_frame
	var batches: int = world.get("_batches").size()
	print("%d bricks, %d batches" % [n, batches])

	var showing: Dictionary = {}
	var t0: int = Time.get_ticks_usec()
	for bid: int in ids:
		showing[bid] = true
		world.show_only(showing)
	var t1: int = Time.get_ticks_usec()
	print("per-brick reveal: %.2f ms each, %.0f ms for the lot" % [
		(t1 - t0) / 1000.0 / maxf(1.0, n), (t1 - t0) / 1000.0])

	var t2: int = Time.get_ticks_usec()
	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	var t3: int = Time.get_ticks_usec()
	print("plan: %.0f ms for %d steps" % [(t3 - t2) / 1000.0, steps.size()])
	quit(0)
