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
	# Everything here is counted in frames, and a window nothing is
	# looking at gets one a second on this machine. That made this
	# probe seven minutes of waiting, almost all of it in the hundred
	# and fifty frames below. The speed check puts vsync back on for its
	# own measurement, which is the only part that cares.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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

	# A close look at one part of it.
	#
	# The whole model framed is right for fifty bricks. For a thousand,
	# an assembly is a few dozen pixels and the critique is being asked
	# about something it cannot make out.
	var whole: Image = await shot.take(world, "corner")
	var close: Image = await shot.take(world, "corner", {},
		AABB(Vector3(0, 0, 0), Vector3(40, 24, 40)))
	if whole == null or close == null:
		_failures += 1
		print("  FAIL  could not take both pictures")
	elif _share(close) <= _share(whole):
		_failures += 1
		print("  FAIL  looking closely filled %.0f%% against %.0f%% "
			% [_share(close) * 100.0, _share(whole) * 100.0]
			+ "for the whole model")
	else:
		print("  ok    looking closely fills more of the frame, "
			+ "%.0f%% against %.0f%%"
			% [_share(close) * 100.0, _share(whole) * 100.0])

	await _check_ruler(shot, world)
	await _check_speed(shot, world)
	await _check_highlight(main, world, builder, library)

	print("")
	if _failures == 0:
		print("the assistant is shown the model it built")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## How much of a picture is model rather than background.
static func _share(image: Image) -> float:
	var step: int = maxi(image.get_width() / 60, 1)
	var hits: int = 0
	for x: int in range(0, image.get_width(), step):
		for y: int in range(0, image.get_height(), step):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.r > 0.4 and pixel.r > pixel.g * 2.0 \
					and pixel.r > pixel.b * 2.0:
				hits += 1
	var sampled: int = (image.get_width() / step) \
		* (image.get_height() / step)
	return float(hits) / float(maxi(sampled, 1))


## The studs written on the picture.
##
## A render says what was built and not where it is, so a design that can
## see the nacelle is too far forward has to guess by how much, in a unit
## the picture does not carry. The ruler is two lines along the model's
## near corner, ticked and numbered in studs, drawn by projecting world
## positions through the same camera that took the picture — so a number
## on the image is the number to write in a placement.
##
## Checked by taking the same model twice, with the ruler and without,
## and asking whether the pictures differ. Reading the numbers off is
## something only a person or a model can do; that something was drawn
## is what can be checked here.
func _check_ruler(shot: ModelShot, world: BrickWorld) -> void:
	print("")
	print("  the studs written on it")
	shot.rulers = true
	var ruled: Image = await shot.take(world, "corner")
	shot.rulers = false
	var plain: Image = await shot.take(world, "corner")
	shot.rulers = true
	if ruled == null or plain == null:
		_failures += 1
		print("  FAIL  no picture came back to compare")
		return
	if ruled.get_size() != plain.get_size():
		_failures += 1
		print("  FAIL  the two pictures are not the same size")
		return
	var differ: int = 0
	for x: int in range(0, ruled.get_width(), 3):
		for y: int in range(0, ruled.get_height(), 3):
			if not ruled.get_pixel(x, y).is_equal_approx(plain.get_pixel(x, y)):
				differ += 1
	# A ruler is thin: a few hundred samples out of a hundred thousand.
	if differ > 40:
		print("  ok    the ruler draws something, %d samples differ" % differ)
	else:
		_failures += 1
		print("  FAIL  the ruler drew nothing, %d samples differ" % differ)
	if differ < 8000:
		print("  ok    ...and it is a ruler, not a wash over the picture")
	else:
		_failures += 1
		print("  FAIL  the ruler covers the picture, %d samples" % differ)


## Can a design find its own change in the picture of the model?
##
## The honest failure here is that it cannot: an edit that moves eight
## bricks in four hundred comes back as a render of four hundred bricks,
## and the only way to tell which eight moved is to read the coordinate
## list again — which is the thing the picture was supposed to replace.
## So the bricks an edit added or moved are restaged in one colour
## nothing nearby is built in.
##
## Driven through the tool a real run calls, not through ModelShot, so
## that the wiring in between is what is being checked: ``edit_model``
## records the numbers, the answer sets them on the stage, and the stage
## is a copy — the model keeps the colours it was given.
func _check_highlight(main: Node, world: BrickWorld, builder: Builder,
		library: PartLibrary) -> void:
	print("")
	print("  what changed, picked out")
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	main.add_child(assistant)
	await process_frame

	# Eight red bricks in two columns, so that moving two is a quarter
	# of the model and not most of it.
	world.clear()
	builder.lattice.clear()
	var start := Assistant.Model.new()
	for n: int in 8:
		start.placements.append(Assistant.Placement.from_dict({
			"part": "3001", "color": 4,
			"x": 0 if n < 4 else 4, "y": (n % 4) * 3, "z": 0}))
	assistant._apply(start)
	for _n: int in 10:
		await process_frame
	var ids: Array = _ids(world)
	if ids.size() != 8:
		_failures += 1
		print("  FAIL  built %d bricks, wanted 8" % ids.size())
		assistant.queue_free()
		return

	# Nothing has changed yet, so nothing should be picked out.
	var before: int = _magenta(await assistant._ensure_shot().take(
		world, "corner"))
	if before == 0:
		print("  ok    an unedited model has none of the colour in it")
	else:
		_failures += 1
		print("  FAIL  %d samples are already the highlight colour, so "
			% before + "finding it later proves nothing")

	# One moved and one added, so that both halves of the recording are
	# covered. Both have to stand up: an edit that would leave a brick
	# floating is refused and changes nothing, which would make this
	# check pass for the wrong reason — the picture would simply be of
	# the model it already was.
	#
	# So the top of the first column moves across onto the second, and
	# a new brick takes the place it left.
	var answer: Variant = await assistant.use_tool("edit_model", {
		"move": [{"bricks": [ids[3]], "dx": 4, "dy": 3}],
		"add": [{"part": "3001", "color": 4, "x": 0, "y": 9, "z": 0}]})
	if answer is String:
		_failures += 1
		print("  FAIL  the edit answered with words, not a picture: %s"
			% str(answer).substr(0, 120))
		assistant.queue_free()
		return

	var image: Image = _picture_in(answer)
	if image == null:
		_failures += 1
		print("  FAIL  no picture in the edit's answer")
		assistant.queue_free()
		return
	image.save_png("user://shot_highlight.png")
	var after: int = _magenta(image)
	if after > 0:
		print("  ok    the two it moved are picked out, %d samples" % after)
	else:
		_failures += 1
		print("  FAIL  nothing in the picture is the highlight colour, "
			+ "so the change is as hard to find as before")

	# A quarter of the model, not the model.
	var red: float = _share(image)
	if after > 0 and float(after) > _samples(image) * 0.5:
		_failures += 1
		print("  FAIL  %d of %d samples are the highlight colour — that "
			% [after, _samples(image)] + "is a magenta model, not a change")
	elif red <= 0.0:
		_failures += 1
		print("  FAIL  no red left in the picture, so the highlight "
			+ "took the whole model")
	else:
		print("  ok    ...and the rest of it is still red, %.0f%% of it"
			% (red * 100.0))

	# The model itself is untouched. This is the part that would be a
	# real bug rather than a dull picture: a highlight that recoloured
	# the world would hand somebody a magenta brick they never chose,
	# and the next save would keep it.
	var wrong: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if brick.color_code != 4:
			wrong += 1
	if wrong == 0:
		print("  ok    and every brick in the model is still the colour "
			+ "it was given")
	else:
		_failures += 1
		print("  FAIL  %d bricks in the model were actually recoloured"
			% wrong)

	# And it does not stick. The next picture anybody asks for is of the
	# model, not of the last edit.
	var later: Variant = await assistant.use_tool("view_model", {})
	var next_image: Image = _picture_in(later)
	if next_image == null:
		_failures += 1
		print("  FAIL  no picture from view_model to check against")
	elif _magenta(next_image) == 0:
		print("  ok    a later look has none of it left in it")
	else:
		_failures += 1
		print("  FAIL  the highlight survived into the next picture, "
			+ "%d samples" % _magenta(next_image))
	assistant.queue_free()


## Brick numbers in the world, in the order they were made.
func _ids(world: BrickWorld) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		out.append(brick.id)
	out.sort()
	return out


## The image out of an answer made of blocks.
static func _picture_in(answer: Variant) -> Image:
	if not answer is Array:
		return null
	for block: Variant in answer:
		if not block is Dictionary:
			continue
		if block.get("type", "") != "image":
			continue
		var image := Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(
				str(block["source"]["data"]))) != OK:
			return null
		return image
	return null


## How many samples are the highlight colour.
##
## Matched the way the red is: much more of two channels than of the
## third, rather than against the palette's numbers, because the shader
## linearises colour on the way in and the viewport does not hand it
## back the way it was written.
static func _magenta(image: Image) -> int:
	if image == null:
		return 0
	var step: int = maxi(image.get_width() / 60, 1)
	var hits: int = 0
	for x: int in range(0, image.get_width(), step):
		for y: int in range(0, image.get_height(), step):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.r > 0.25 and pixel.b > 0.1 \
					and pixel.r > pixel.g * 2.5 \
					and pixel.b > pixel.g * 1.5:
				hits += 1
	return hits


## How many samples the counters above look at.
static func _samples(image: Image) -> int:
	var step: int = maxi(image.get_width() / 60, 1)
	return (image.get_width() / step) * (image.get_height() / step)


## How long does a picture take?
##
## It has to be a question this probe asks, because the answer was six
## seconds and nothing said so. Six frames of waiting is a tenth of a
## second at sixty frames and six seconds at one, and one is what this
## machine gives a window nothing is looking at. Measured: the same six
## seconds at every model size from one brick to four hundred, so the
## model was never the cost. A design that takes twenty pictures spent
## two minutes of its half hour on it, and a picture that needed more
## than one try went past the relay's three minutes and came back as
## nothing — a starship designed by somebody who never saw it.
##
## Pictures run with vsync off now. The number to watch is the second
## one and later: the first of a session also compiles shaders.
## How many frames of waiting a picture may cost. Measured: with vsync
## on and the machine quiet, a frame is 192 ms and a picture takes about
## eight of them. Twenty leaves room for a loaded machine to be slow at
## every frame without this reading as a regression in the code.
const MOST_FRAMES := 20.0
## And the point past which the frame itself is the problem, so nothing
## can be proven about the picture either way.
const A_FRAME_IS_HOPELESS := 0.4


func _check_speed(shot: ModelShot, world: BrickWorld) -> void:
	print("")
	print("  and it does not take six seconds")
	# The slow condition, put back deliberately: this probe runs with
	# vsync off so that it finishes at all, and a check that measured
	# its own fast setting would pass however slow a picture really is.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 0
	var idle: float = Time.get_unix_time_from_system()
	for _n: int in 10:
		await process_frame
	var per: float = (Time.get_unix_time_from_system() - idle) / 10.0
	print("  ...   with vsync on, one frame takes %.0f ms" % (per * 1000.0))
	var first: float = await _timed(shot, world, "corner")
	print("  ...   the first of a session, shaders and all: %.2f s" % first)
	var worst: float = 0.0
	for from: String in ["far corner", "front", "corner"]:
		worst = maxf(worst, await _timed(shot, world, from))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _check_giving_up(shot, world)
	# Counted in frames, not seconds.
	#
	# Two seconds was the threshold, and on a box shared with another
	# project's video encode at load average 104 a picture took 2.1 s
	# and this failed with nothing about the code changed — twice today,
	# passing in between. The suite already says the right thing about
	# its windowed probes: "nothing was proven. Check the load: these
	# starve above about 12."
	#
	# A picture is a fixed number of frames of waiting. What a frame
	# costs is the machine's business, and `per` above has just measured
	# it on this machine in this run, so the fair question is how many
	# frames a picture took. The cost that mattered — six seconds a
	# picture at every model size — was a frame costing 989 ms because a
	# window nobody is looking at gets one a second from the
	# compositor, and that shows up here as frames, not as seconds.
	var frames: float = worst / maxf(per, 0.0001)
	if frames <= MOST_FRAMES:
		print("  ok    and the ones after it in %.2f s, which is %.0f "
			% [worst, frames] + "frames of this machine's %.0f ms — "
			% (per * 1000.0) + "vsync on the whole time")
	elif per > A_FRAME_IS_HOPELESS:
		# Not a pass and not a failure, said the way the suite says it.
		print("  ...   a frame costs %.0f ms here, so nothing is proven "
			% (per * 1000.0) + "about how long a picture takes. Check "
			+ "the load and run it again when the machine is quiet")
	else:
		_failures += 1
		print("  FAIL  a picture takes %.0f frames (%.1f s at %.0f ms a "
			% [frames, worst, per * 1000.0] + "frame) — at twenty "
			+ "pictures a design that is most of an hour, and the relay "
			+ "gives up at three minutes")


## Seconds for one picture.
func _timed(shot: ModelShot, world: BrickWorld, from: String) -> float:
	var began: float = Time.get_unix_time_from_system()
	var image: Image = await shot.take(world, from)
	var took: float = Time.get_unix_time_from_system() - began
	if image == null:
		_failures += 1
		print("  FAIL  no picture from the %s to time" % from)
	return took


## And when a picture cannot be had in time, is the design left blind?
##
## It was. On a machine running four other copies of this engine — an
## ordinary afternoon here — the app stalled past the relay's three
## minutes with three view requests queued, and a real design run
## reported it: "every request timed out, so I haven't checked those
## proportions by eye." A picture capped in frames is not capped in
## time. Capped in time, the caller falls back to the letters, which
## draw the plan and an elevation and hide nothing. A worse picture
## beats no picture.
func _check_giving_up(shot: ModelShot, world: BrickWorld) -> void:
	var was: float = shot.give_up_after
	shot.give_up_after = 0.0
	var nothing: Image = await shot.take(world, "corner")
	var block: Dictionary = await shot.block(world, "corner")
	shot.give_up_after = was
	if nothing == null and block.is_empty():
		print("  ok    ...and a picture that cannot be had in time is "
			+ "given up on, so the caller can draw the letters instead")
	else:
		_failures += 1
		print("  FAIL  no time left and it still waited for a picture, "
			+ "which is how a design ends up blind")
	# And it recovers: the next one is an ordinary picture again.
	if (await shot.take(world, "corner")) != null:
		print("  ok    ...and the one after it is a picture again")
	else:
		_failures += 1
		print("  FAIL  giving up once stopped it taking pictures at all")
