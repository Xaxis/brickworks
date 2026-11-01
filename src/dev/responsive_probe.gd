## Does the app keep running while a big design is checked?
##
##   godot --headless --path . --script src/dev/responsive_probe.gd
##
## On the web the page has one thread. The owner's Falcon Heavy (4,242
## parts, src/dev/fixtures/falcon_heavy.json) took 3.4 s to check on the
## desktop and held a browser for 31 s, and every check_design, submit,
## edit and review did it again: no frames, no clicks, and Claude told the
## tab "did not answer in time". A big check now runs on a worker
## (Assistant._checked) while the main thread goes on. This holds that: the
## same answer as checking in place, frames all the while, and what a
## person or a fetch does meanwhile neither lost nor crashing it.
##
## A frame's time is the app's own, less the main thread's wait for a CPU,
## and its bar three times as long at a load past the box's cores
## (ProbeTime): the frames are the main thread's, which the worker's check
## and the box's load both slow.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


## Each frame from the next on, kept until [method _timed].
func _timing() -> ProbeTime.Frames:
	var frames := ProbeTime.Frames.new()
	frames.from_now = false
	root.add_child(frames)
	return frames


## How the frames since [method _timing] went against [param bar] ms:
## [how many from one to the next, whether the longest was under the bar,
## in words]; the frames let go.
func _timed(frames: ProbeTime.Frames, bar: float) -> Array:
	var longest: Array = ProbeTime.longest(frames.gaps)
	var busy: float = maxf(frames.busy, ProbeTime.box_load())
	var most: float = bar * ProbeTime.slack(busy)
	var count: int = frames.gaps.size()
	frames.queue_free()
	return [count, float(longest[0]) < most,
		"the longest %.0f ms of its own (%.0f waiting for a CPU), under %.0f; %s"
		% [float(longest[0]), float(longest[2]), most, ProbeTime.load_said(busy)]]


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
	await process_frame

	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://src/dev/fixtures/falcon_heavy.json"))
	var bricks: Array = []
	for row: Array in fixture["bricks"]:
		bricks.append({"part": row[0], "color": row[1], "x": row[2], "y": row[3],
			"z": row[4], "face": row[5], "rot": row[6]})
	# A brick standing before the design, which the design must fit around.
	var standing_at := Transform3D(Basis.IDENTITY, Vector3(-200.0, 24.0, -200.0))
	var standing: int = world.add_brick("3001", 14, standing_at)
	builder.register(standing, "3001", standing_at)
	var model: Assistant.Model = assistant._read_model({"bricks": bricks})

	var started: int = Time.get_ticks_usec()
	var in_place: Dictionary = assistant._check(model)
	var in_place_ms: float = (Time.get_ticks_usec() - started) / 1000.0

	# The same check, waited for a frame at a time — with a person placing a
	# brick and a part's geometry arriving while it runs.
	var unloaded: String = _a_part_not_loaded(library)
	var frames: ProbeTime.Frames = _timing()
	started = Time.get_ticks_usec()
	var waiting: Array = [null]
	var checking := func() -> void:
		waiting[0] = await assistant._checked(model)
	checking.call()
	var placed: int = 0
	var arrived: bool = false
	while waiting[0] == null:
		await process_frame
		if placed == 0 and frames.gaps.size() >= 2:
			var at := Transform3D(Basis.IDENTITY, Vector3(-300.0, 24.0, -300.0))
			placed = world.add_brick("3003", 4, at)
			builder.register(placed, "3003", at)
		if not arrived and frames.gaps.size() >= 3 and not unloaded.is_empty():
			arrived = library.mesh_for(unloaded) != null
	var timed: Array = _timed(frames, 150.0)
	var off_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	var off: Dictionary = waiting[0]

	_check("checked in place: %.0f ms, %s" % [in_place_ms, in_place["summary"]],
		bool(in_place["ok"]))
	_check("checked on a worker: the same answer",
		off.get("summary") == in_place["summary"]
		and off.get("feedback") == in_place["feedback"])
	_check("...in %.0f ms, with %d frames meanwhile, %s" % [off_ms, int(timed[0]), timed[2]],
		int(timed[0]) >= 4 and bool(timed[1]))
	_check("a brick placed during it is in the world", placed != 0
		and world.get_brick(placed) != null)
	_check("a part loaded during it is in the library after%s"
		% ("" if not unloaded.is_empty() else " (none to try)"),
		unloaded.is_empty() or (arrived and library.is_resident(unloaded)
			and library._arrived.is_empty() and library._readers == 0))

	# Through the tools, as Claude calls them: a check and a submit of the
	# Falcon, each answered while frames go on.
	world.clear()
	builder.lattice.clear()
	for tool: String in ["check_design", "submit_design"]:
		frames = _timing()
		started = Time.get_ticks_usec()
		var answer: Variant = await assistant.use_tool(tool, {"bricks": bricks})
		var tool_timed: Array = _timed(frames, 600.0)
		var said: String = str(answer).substr(0, 60).replace("\n", " ")
		_check("%s of the Falcon: %.0f ms, %d frames, %s: %s"
			% [tool, (Time.get_ticks_usec() - started) / 1000.0, int(tool_timed[0]),
				tool_timed[2], said],
			int(tool_timed[0]) >= 4 and bool(tool_timed[1]) and not said.contains("Not applied"))

	await _stopped_while_going_down(world, builder, assistant, bricks)

	print("")
	print("%d FAILURE(S)" % _failures if _failures
		else "a big design is checked while the app goes on")
	quit(1 if _failures else 0)


## The app's own design loop, stopped while a design is going down a slice
## a frame: what was there before is put back, and no more of it is placed.
func _stopped_while_going_down(world: BrickWorld, builder: Builder,
		assistant: Assistant, bricks: Array) -> void:
	world.clear()
	builder.lattice.clear()
	var before: int = 0
	for n: int in 12:
		var at := Transform3D(Basis.IDENTITY, Vector3(-400.0, 24.0 * (n + 1), -400.0))
		var id: int = world.add_brick("3001", 1, at)
		builder.register(id, "3001", at)
		assistant._placed_ids.append(id)
		before += 1
	assistant._before = assistant._snapshot()
	assistant._busy = true
	var built: Array = [0]
	var on_built := func(_n: int) -> void: built[0] += 1
	assistant.built.connect(on_built)
	var model: Assistant.Model = assistant._read_model({"bricks": bricks})
	var going: Array = [false]
	var put_down := func() -> void:
		await assistant._apply(model, true, true)
		going[0] = true
	put_down.call()
	# Into putting bricks down, which is the part that has to be undone.
	for _n: int in 600:
		if going[0] or assistant.fresh_ids.size() > 100:
			break
		await process_frame
	var part_way: int = world.brick_count()
	assistant.cancel()
	for _n: int in 30:
		await process_frame
	assistant.built.disconnect(on_built)
	_check("stopped part way down (%d bricks of %d), the model is as it was: %d bricks"
		% [part_way, before + bricks.size(), world.brick_count()],
		going[0] and world.brick_count() == before and built[0] == 0
		and not world.is_drawing_held())


## A part on disk whose geometry is not loaded yet, to load mid-check.
func _a_part_not_loaded(library: PartLibrary) -> String:
	for part_id: String in ["3062b", "4073", "3794b", "2412b", "3069b"]:
		if library.parts.has(part_id) and not library.is_resident(part_id):
			return part_id
	return ""


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
