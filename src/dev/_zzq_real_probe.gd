extends SceneTree

# A realistic large model: few distinct parts (real .ldr models use 3-26),
# genuinely stacked, so the support graph has work to do.
func _build(world: BrickWorld, library: PartLibrary, parts: Array[String],
		n: int) -> PackedInt64Array:
	world.clear()
	var ids := PackedInt64Array()
	var across: int = 20
	for i: int in n:
		var part: String = parts[i % parts.size()]
		var at := Transform3D(Basis.IDENTITY, Vector3(
			(i % across) * 40.0, float(i / across) * 24.0, float((i / across) % 3) * 40.0))
		var id: int = world.add_brick(part, 1 + (i % 6), at)
		if id != 0:
			ids.append(id)
	return ids

func _initialize() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	var _inst := Instructions.new()
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	# 14 distinct parts: the house's diversity, which measured 14 batches.
	var parts: Array[String] = []
	for info: PartLibrary.PartInfo in library.search("brick 2 x", 40):
		if not info.is_redirect() and info.reachable and parts.size() < 14:
			library.request_mesh(info.id)
			if library.mesh_for(info.id) != null:
				parts.append(info.id)
	print("%d distinct parts" % parts.size())

	for n: int in [98, 400, 1000, 2000]:
		var ids: PackedInt64Array = _build(world, library, parts, n)
		await process_frame
		var batches: int = world.get("_batches").size()

		var t0: int = Time.get_ticks_usec()
		var steps: Array[Instructions.Step] = Instructions.plan(world, library)
		var t1: int = Time.get_ticks_usec()

		# Split: survey + supports vs sequence.
		var nodes: Array = world.call("bricks")
		var t2: int = Time.get_ticks_usec()
		var surveyed: Array[Instructions.Node2] = []
		for b: BrickWorld.Brick in nodes:
			var part: Lbm.PartMesh = library.mesh_for(b.part_id)
			if part == null: continue
			var nd := Instructions.Node2.new()
			nd.id = b.id; nd.part_id = b.part_id; nd.box = b.transform * part.bounds
			surveyed.append(nd)
		var t3: int = Time.get_ticks_usec()
		_inst.call("_find_supports", surveyed)
		var t4: int = Time.get_ticks_usec()
		var seq: Array[Instructions.Step] = _inst.call("_sequence", surveyed)
		var t5: int = Time.get_ticks_usec()

		# Playback as it actually runs: one show_only per STEP, not per brick.
		world.show_only({1: true})
		var showing: Dictionary = {}
		var worst: float = 0.0
		var t6: int = Time.get_ticks_usec()
		for s: Instructions.Step in steps:
			for bid: int in s.brick_ids:
				showing[bid] = true
			var a: int = Time.get_ticks_usec()
			world.show_only(showing)
			var b2: float = (Time.get_ticks_usec() - a) / 1000.0
			if b2 > worst: worst = b2
		var t7: int = Time.get_ticks_usec()
		world.show_only({})

		print("n=%4d  batches=%2d  steps=%3d | plan %6.1f ms (survey %5.1f, supports %6.1f, sequence %6.1f) | playback %7.1f ms total, %5.2f ms/step avg, %5.2f worst" % [
			ids.size(), batches, steps.size(), (t1-t0)/1000.0,
			(t3-t2)/1000.0, (t4-t3)/1000.0, (t5-t4)/1000.0,
			(t7-t6)/1000.0, (t7-t6)/1000.0/maxf(1.0,steps.size()), worst])
		if seq.size() < 0: pass
	quit(0)
