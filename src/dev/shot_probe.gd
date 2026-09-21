## Is the picture the assistant is shown a picture of the model?
##
##   godot --path . --resolution 1200x800 --script src/dev/shot_probe.gd
##
## Needs a real window: a headless run has no rendering device, and the
## interesting thing about this path is that it only exists where one
## does. That is also why it is worth a probe of its own — the code that
## runs in the app is not the code the offline suite exercises.
##
## The failure to catch is a blank image. Asking a viewport that cannot
## draw to draw does not error; it hands back a picture of nothing, and
## a picture of nothing presented as a picture of the model is worse
## than the letters it replaced.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var library: PartLibrary = main.get("_library")
	if world == null:
		print("no world")
		quit(1)
		return

	if not ModelShot.possible():
		print("  no rendering device — this probe needs a window")
		quit(1)
		return

	var shot := ModelShot.new()
	main.add_child(shot)

	# A world with nothing in it: no picture, and the caller falls back
	# to letters. The app's own world is never this — it has a
	# baseplate in it, which is a brick and does photograph.
	var bare := BrickWorld.new()
	bare.library = library
	main.add_child(bare)
	await process_frame
	if (await shot.block(bare, "corner")).is_empty():
		print("  ok    a world with nothing in it yields no picture")
	else:
		_failures += 1
		print("  FAIL  an empty world produced a picture anyway")
	bare.queue_free()

	# Something unmistakable, on its own. The app opens whatever was
	# last being worked on, and a red tower is not a large share of
	# somebody's half-finished house.
	world.clear()
	builder.lattice.clear()
	for y: int in 8:
		var at := Transform3D(Basis.IDENTITY,
			Vector3(40.0, y * 24.0 + 24.0, 40.0))
		var brick_id: int = world.add_brick("3001", 4, at)
		if brick_id != 0:
			builder.register(brick_id, "3001", at)
	for _n: int in 10:
		await process_frame

	print("  a tower of %d bricks, on its own" % world.brick_count())
	for from: String in ["corner", "far corner", "front", "top", "left"]:
		var image: Image = await shot.take(world, from)
		pass
		if image == null:
			_failures += 1
			print("  FAIL  no picture from the %s" % from)
			continue
		if image.get_width() != ModelShot.SIZE:
			_failures += 1
			print("  FAIL  %s came back %d wide, wanted %d"
				% [from, image.get_width(), ModelShot.SIZE])
			continue

		# Is there a model in it? Count strongly red pixels. Not "close
		# to the palette's red": the shader linearises colour and the
		# viewport does not hand it back the way the palette wrote it,
		# so matching the number is matching the wrong thing. Whether a
		# pixel is much redder than it is anything else survives that.
		var hits: int = 0
		var step: int = 8
		for x: int in range(0, image.get_width(), step):
			for y: int in range(0, image.get_height(), step):
				var pixel: Color = image.get_pixel(x, y)
				if pixel.r > 0.4 and pixel.r > pixel.g * 2.0 \
						and pixel.r > pixel.b * 2.0:
					hits += 1
		var sampled: int = (image.get_width() / step) * (image.get_height() / step)
		var share: float = float(hits) / float(sampled)
		# Kept where a person can look, since "27% red" is a claim
		# about a picture and the picture settles it.
		image.save_png("user://shot_%s.png" % from)
		# Framed, not merely present: a model that fills the picture edge
		# to edge has no edges in it and cannot be judged.
		if share > 0.75:
			_failures += 1
			print("  FAIL  the %s is %.0f%% model — nothing but model, "
				% [from, share * 100.0] + "so none of its outline is in it")
		elif share < 0.02:
			_failures += 1
			print("  FAIL  the %s shows %.1f%% of the model's colour — "
				% [from, share * 100.0] + "that is a picture of nothing")
		else:
			print("  ok    the %s is %.0f%% model" % [from, share * 100.0])

	# And as a block, which is what actually gets sent.
	var block: Dictionary = await shot.block(world, "corner")
	if block.get("type", "") != "image":
		_failures += 1
		print("  FAIL  the block is not an image block")
	else:
		var data: String = str(block["source"]["data"])
		var bytes: PackedByteArray = Marshalls.base64_to_raw(data)
		# A PNG, not merely some base64. The first eight bytes say so.
		if bytes.size() < 8 or bytes[0] != 0x89 or bytes[1] != 0x50:
			_failures += 1
			print("  FAIL  the block's data is not a PNG")
		else:
			print("  ok    a %d KB PNG, ready to send" % (bytes.size() / 1024))

	print("")
	if _failures == 0:
		print("the assistant is shown the model it built")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
