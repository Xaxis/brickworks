extends SceneTree

func _initialize() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	for name: String in ["house", "tower"]:
		world.clear()
		var model: LdrModel = LdrModel.load_file("res://models/%s.ldr" % name)
		var ids := PackedInt64Array()
		for item: Variant in model.flatten(library.parts):
			var p: LdrModel.Placement = item
			var id: int = world.add_brick(p.part_id, p.color_code, p.transform)
			if id != 0: ids.append(id)
		await process_frame

		var t0: int = Time.get_ticks_usec()
		var steps: Array[Instructions.Step] = Instructions.plan(world, library)
		var t1: int = Time.get_ticks_usec()
		print("%s: %d bricks, plan took %.1f ms, %d steps" % [
			name, ids.size(), (t1 - t0) / 1000.0, steps.size()])

		# Reveal one brick at a time, the way a per-brick animation would.
		var showing: Dictionary = {}
		var t2: int = Time.get_ticks_usec()
		for s: Instructions.Step in steps:
			for bid: int in s.brick_ids:
				showing[bid] = true
				world.show_only(showing)
		var t3: int = Time.get_ticks_usec()
		print("   %d show_only() calls took %.1f ms total, %.2f ms each" % [
			ids.size(), (t3 - t2) / 1000.0, (t3 - t2) / 1000.0 / maxf(1.0, ids.size())])

		# How many live batches, since _flush costs per batch.
		var batches: int = 0
		for key: String in world.get("_batches"):
			batches += 1
		print("   %d batches" % batches)
	quit(0)
