## The build animation: does it show the right bricks, and is it cheap?
##
##   godot --headless --path . --script src/dev/playback_probe.gd
##
## The owner asked the web app for a Falcon Heavy and it "damn near froze
## my computer". On that model (src/dev/fixtures/falcon_heavy.json, 4,242
## parts) the animation planned the booklet's order in one frame, 15.5 s,
## at every submit and every edit; then each step walked every brick and
## rebuilt every batch it touched. So this checks both halves: that a
## reveal shows exactly the bricks it should, in order, a prefix of each
## batch; and that on the Falcon starting one and running it through cost
## milliseconds, not seconds.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	var playback := BuildPlayback.new()
	playback.world = world
	playback.library = library
	root.add_child(playback)
	await process_frame

	_reveal_in_order(world)
	_only_what_is_new(world, playback)
	await _falcon(world, library, builder, assistant, playback)

	print("")
	print("%d FAILURE(S)" % _failures if _failures
		else "the build animation shows what is new, in order, for milliseconds a step")
	quit(1 if _failures else 0)


## Twelve bricks in two batches; reveal eight of them in a given order.
func _reveal_in_order(world: BrickWorld) -> void:
	world.clear()
	var ids := PackedInt64Array()
	for n: int in 12:
		var part: String = "3001" if n % 2 == 0 else "3003"
		ids.append(world.add_brick(part, 4 if n < 6 else 1,
			Transform3D(Basis.IDENTITY, Vector3(n * 80.0, 0.0, 0.0))))
	world._flush()
	# Out of id order on purpose: the batches must follow the order given.
	var order := PackedInt64Array([ids[7], ids[2], ids[11], ids[4],
		ids[9], ids[6], ids[3], ids[10]])
	var ended: Array = [0]
	var on_end := func() -> void: ended[0] += 1
	world.reveal_ended.connect(on_end)
	world.begin_reveal(order)
	_check("a reveal hides exactly the bricks to come",
		_hidden(world) == _as_set(order))
	_check("...and draws only the rest", _drawn(world) == 4)
	world.reveal_through(2)
	_check("three steps in, the first three of the order are shown",
		_hidden(world) == _as_set(order.slice(3)))
	_check("...and drawn, each batch's shown bricks first",
		_drawn(world) == 7 and _prefix_is_shown(world))
	world.reveal_through(5)
	_check("six in, the first six", _hidden(world) == _as_set(order.slice(6)))
	world.reveal_through(7)
	_check("the last brick shown ends the reveal",
		not world.is_revealing() and ended[0] == 1 and _hidden(world).is_empty()
		and _drawn(world) == 12)

	# A change somewhere else leaves it playing: the ground laid wider under
	# a design that outgrew it, the moment it was built.
	world.begin_reveal(order)
	world.reveal_through(1)
	var ground: int = world.add_brick("3811", 2,
		Transform3D(Basis.IDENTITY, Vector3(0, -8, 800)))
	world._flush()
	_check("a brick of another part added mid-reveal leaves it playing",
		world.is_revealing() and ended[0] == 1
		and _hidden(world) == _as_set(order.slice(2)))
	world.remove_brick(ground)
	world._flush()
	_check("...and so does taking it away", world.is_revealing())

	# A change to what is being revealed puts everything back first.
	world.add_brick("3001", 14, Transform3D(Basis.IDENTITY, Vector3(0, 0, 400)))
	world._flush()
	_check("a brick added to the bricks being revealed ends it, everything shown and drawn",
		not world.is_revealing() and ended[0] == 2 and _hidden(world).is_empty()
		and _drawn(world) == 13)
	world.reveal_ended.disconnect(on_end)


## What was standing stays standing; only what is new goes up.
func _only_what_is_new(world: BrickWorld, playback: BuildPlayback) -> void:
	world.clear()
	var standing: Dictionary = {}
	for n: int in 10:
		var id: int = world.add_brick("3001", 4,
			Transform3D(Basis.IDENTITY, Vector3(0.0, 24.0 * n, 0.0)))
		standing[id] = true
	world._flush()
	_check("a change that put nothing new down plays nothing",
		not playback.play(standing))
	var fresh := PackedInt64Array()
	for n: int in 20:
		fresh.append(world.add_brick("3003", 1,
			Transform3D(Basis.IDENTITY, Vector3(100.0, 24.0 * n, 0.0))))
	world._flush()
	var played: bool = playback.play(standing)
	_check("twenty new bricks beside ten standing play", played)
	_check("...hiding only the twenty but the first step's",
		_hidden(world).size() > 0 and _hidden(world).size() < 20
		and _as_set(fresh).has_all(_hidden(world).keys()))
	playback.stop()
	_check("stopping shows everything", _hidden(world).is_empty()
		and _drawn(world) == 30 and not playback.is_playing())
	_check("the same twenty, named rather than everything else, play the same",
		playback.play_new(fresh) and _hidden(world).size() > 0
		and _as_set(fresh).has_all(_hidden(world).keys()))
	playback.stop()
	_check("one brick named plays nothing",
		not playback.play_new(fresh.slice(0, 1)) and _hidden(world).is_empty())


## The owner's Falcon Heavy, put down whole, then animated.
func _falcon(world: BrickWorld, library: PartLibrary, builder: Builder,
		assistant: Assistant, playback: BuildPlayback) -> void:
	world.clear()
	builder.lattice.clear()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://src/dev/fixtures/falcon_heavy.json"))
	var bricks: Array = []
	for row: Array in fixture["bricks"]:
		bricks.append({"part": row[0], "color": row[1], "x": row[2], "y": row[3],
			"z": row[4], "face": row[5], "rot": row[6]})
	var model: Assistant.Model = assistant._read_model({"bricks": bricks})
	assistant._apply(model)
	world._flush()
	_check("the Falcon is down: %d bricks, all of them new" % world.brick_count(),
		world.brick_count() == 4242 and assistant.fresh_ids.size() == 4242)

	var started: int = Time.get_ticks_usec()
	var played: bool = playback.play({})
	var start_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	_check("starting it takes %.0f ms (main planned it in 15,500)" % start_ms,
		played and start_ms < 400.0)
	_check("it lays the Falcon out in %d steps, at most %.1f s"
		% [playback._step_ends.size(), BuildPlayback.LONGEST_MS / 1000.0],
		playback._step_ends.size() > 100
		and playback._per_step * playback._step_ends.size() <= BuildPlayback.LONGEST_MS + 1.0)

	# Course by course: no step starts lower than the one before it.
	var lowest: float = -INF
	var climbing: bool = true
	var from: int = 0
	for end: int in playback._step_ends:
		var low: float = INF
		for n: int in range(from, end):
			var brick: BrickWorld.Brick = world.get_brick(playback._order[n])
			var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
			low = minf(low, (brick.transform * part.bounds).position.y)
		climbing = climbing and low >= lowest - 0.01
		lowest = maxf(lowest, low)
		from = end
	_check("it goes up from the bottom, step by step", climbing)

	# Every frame of it, as the engine would run them.
	var worst: float = 0.0
	var frames: int = 0
	while playback.is_playing() and frames < 2000:
		var frame: int = Time.get_ticks_usec()
		playback._process(1000.0 / 60.0 / 1000.0)
		world._flush()
		worst = maxf(worst, (Time.get_ticks_usec() - frame) / 1000.0)
		frames += 1
	_check("it plays out in %d frames, the slowest %.1f ms" % [frames, worst],
		not playback.is_playing() and frames <= int(BuildPlayback.LONGEST_MS / 16.0) + 2
		and worst < 30.0)
	_check("...and ends with the whole Falcon shown",
		_hidden(world).is_empty() and _drawn(world) == 4242)

	# And by the clock on the wall, however slow the frames: a browser
	# drawing it in software said each second-long frame took 33 ms, and the
	# 2.5 s animation took 16 s. Here one frame comes after it should have
	# ended, and says it took 16 ms.
	var again: bool = playback.play({})
	playback._started_ms -= int(BuildPlayback.LONGEST_MS) + 1
	playback._process(1000.0 / 60.0 / 1000.0)
	world._flush()
	_check("a frame that comes after its time ends it, whatever the frame says it took",
		again and not playback.is_playing() and _hidden(world).is_empty()
		and _drawn(world) == 4242)
	await process_frame


func _hidden(world: BrickWorld) -> Dictionary:
	var hidden: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if brick.hidden:
			hidden[brick.id] = true
	return hidden


func _as_set(ids: PackedInt64Array) -> Dictionary:
	var out: Dictionary = {}
	for id: int in ids:
		out[id] = true
	return out


## Instances drawn, over every batch.
func _drawn(world: BrickWorld) -> int:
	var total: int = 0
	for key: String in world._batches:
		var batch: BrickWorld.Batch = world._batches[key]
		total += batch.multimesh.visible_instance_count \
			if batch.multimesh.visible_instance_count >= 0 \
			else batch.multimesh.instance_count
	return total


## Every drawn slot holds a brick that is shown.
func _prefix_is_shown(world: BrickWorld) -> bool:
	for key: String in world._batches:
		var batch: BrickWorld.Batch = world._batches[key]
		for slot: int in batch.multimesh.visible_instance_count:
			if world.get_brick(batch.brick_ids[slot]).hidden:
				return false
	return true


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
