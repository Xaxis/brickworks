## Corner, front and close pictures of a model, as the assistant's own camera takes them.
##
##   gpu xvfb-run -a godot --path . --resolution 1600x900 \
##     --script src/dev/bench_views.gd -- --model=X.ldr --views_out=PREFIX [--close=x0,x1,y0,y1,z0,z1]
##
## Writes PREFIX_corner.png, PREFIX_front.png and PREFIX_close.png. The design
## bench (tools/bench/run.py) takes every design, every real set it shows as a
## reference and both anchors with it, so the judge compares like with like.
## --close is in studs and plates (as view_model's where), --closef in
## fractions of the bounds; without either, the nearest quarter from the corner.
extends SceneTree


func _initialize() -> void:
	_run()


func _arg(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix + "="):
			return a.substr(prefix.length() + 1)
	return ""


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	var world: BrickWorld = null
	var last: int = -1
	var steady: int = 0
	for _n: int in 3000:
		await process_frame
		world = main.get("_world")
		if world == null:
			continue
		var count: int = world.brick_count()
		if count > 1 and count == last:
			steady += 1
			if steady > 60:
				break
		else:
			steady = 0
		last = count
	if world == null:
		print("no world")
		quit(1)
		return
	print("bricks %d" % world.brick_count())
	for _n: int in 30:
		await process_frame
	var shot := ModelShot.new()
	shot.give_up_after = 120.0
	main.add_child(shot)
	var prefix: String = _arg("--views_out")
	var bounds: AABB = main.call("_built_bounds")
	var close := AABB()
	var said: String = _arg("--close")
	var frac: String = _arg("--closef")
	if not frac.is_empty():
		var f: PackedFloat64Array = PackedFloat64Array()
		for bit: String in frac.split(","):
			f.append(bit.to_float())
		var lo := bounds.position + bounds.size * Vector3(f[0], f[2], f[4])
		var hi := bounds.position + bounds.size * Vector3(f[1], f[3], f[5])
		close = AABB(lo, hi - lo)
	elif not said.is_empty():
		var n: PackedFloat64Array = PackedFloat64Array()
		for bit: String in said.split(","):
			n.append(bit.to_float())
		var lo := Vector3(n[0] * 20.0, n[2] * 8.0, n[4] * 20.0)
		var hi := Vector3(n[1] * 20.0, n[3] * 8.0, n[5] * 20.0)
		close = AABB(lo.min(hi), (hi - lo).abs())
	else:
		var mid: Vector3 = bounds.get_center()
		close = AABB(Vector3(mid.x, bounds.position.y, mid.z),
			Vector3(bounds.end.x - mid.x, bounds.size.y, bounds.end.z - mid.z))
	print("bounds %s close %s" % [bounds, close])
	var scenery: Dictionary = (main.get("_store") as ModelStore).scenery
	var bounds_skip: AABB = AABB()
	for view: Array in [["corner", "corner", AABB()], ["front", "front", AABB()],
			["close", "corner", close]]:
		var image: Image = await shot.take(world, view[1], scenery, view[2])
		if image == null:
			print("  no picture for %s" % view[0])
			continue
		var path: String = "%s_%s.png" % [prefix, view[0]]
		image.save_png(path)
		print("  wrote %s %dx%d" % [path, image.get_width(), image.get_height()])
	quit(0)
