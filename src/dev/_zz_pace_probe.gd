extends SceneTree

func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	for name: String in ["house","tree","bench","tower","boat","rocket","car","lighthouse"]:
		world.clear()
		var model: LdrModel = LdrModel.load_file("res://models/%s.ldr" % name)
		if model == null:
			print("%s: unreadable" % name); continue
		var n: int = 0
		for item: Variant in model.flatten(library.parts):
			var p: LdrModel.Placement = item
			if world.add_brick(p.part_id, p.color_code, p.transform) != 0:
				n += 1
		var steps: Array[Instructions.Step] = Instructions.plan(world, library)
		var sizes := PackedInt32Array()
		var forced: int = 0
		for s: Instructions.Step in steps:
			sizes.append(s.brick_ids.size())
			if s.unsupported: forced += 1
		var hist: Dictionary = {}
		for v: int in sizes: hist[v] = int(hist.get(v,0)) + 1
		var keys: Array = hist.keys(); keys.sort()
		var parts := PackedStringArray()
		for k: int in keys: parts.append("%dx%d" % [int(hist[k]), k])
		print("%-11s %3d bricks -> %3d steps  (sizes %s)  forced=%d  dwell0.8s=%.0fs" % [
			name, n, steps.size(), ", ".join(parts), forced, steps.size()*0.8])
	quit(0)
