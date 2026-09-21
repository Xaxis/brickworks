extends SceneTree

func _initialize() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	var parts: Array[String] = []
	for info: PartLibrary.PartInfo in library.search("brick 2 x", 40):
		if not info.is_redirect() and info.reachable and parts.size() < 14:
			library.request_mesh(info.id)
			if library.mesh_for(info.id) != null:
				parts.append(info.id)

	for n: int in [400, 2000]:
		world.clear()
		var ids := PackedInt64Array()
		for i: int in n:
			var at := Transform3D(Basis.IDENTITY, Vector3(
				(i % 20) * 40.0, float(i / 20) * 24.0, float((i / 20) % 3) * 40.0))
			var id: int = world.add_brick(parts[i % parts.size()], 1 + (i % 6), at)
			if id != 0: ids.append(id)
		await process_frame
		var steps: Array[Instructions.Step] = Instructions.plan(world, library)

		# Reveal everything, then measure a show_only that changes NOTHING:
		# that is the _bricks scan alone, with no _flush and no _rebuild.
		var showing: Dictionary = {}
		for bid: int in ids: showing[bid] = true
		world.show_only(showing)
		var t0: int = Time.get_ticks_usec()
		for _k: int in 100:
			world.show_only(showing)
		var t1: int = Time.get_ticks_usec()

		# Now the real playback cost per step.
		world.show_only({1: true})
		var live: Dictionary = {}
		var t2: int = Time.get_ticks_usec()
		for s: Instructions.Step in steps:
			for bid: int in s.brick_ids: live[bid] = true
			world.show_only(live)
		var t3: int = Time.get_ticks_usec()
		world.show_only({})

		print("n=%4d steps=%3d | bare _bricks scan %.3f ms/call | real show_only %.3f ms/step | scan is %.0f%% of it" % [
			n, steps.size(), (t1-t0)/100000.0, (t3-t2)/1000.0/maxf(1.0,steps.size()),
			100.0 * ((t1-t0)/100000.0) / maxf(0.0001, (t3-t2)/1000.0/maxf(1.0,steps.size()))])
	quit(0)
