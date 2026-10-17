## A shared model's steps carried with it (SharedPages), headless.
##
##   godot --headless --path . --script src/dev/share_pages_probe.gd
##   godot --headless --path . --script src/dev/share_pages_probe.gd -- --write IN OUT [IN OUT...]
##
## For the house, the castle and the lowest 1,000 parts of Orthanc: the
## steps worked out and written at the end of the text; the text opened as
## the viewer opens it (ModelStore.open_text, a baseplate laid under it as
## scenery) and the carried steps read back for that world; and those the
## very steps the viewer works out there itself (Instructions.plan_paced,
## as StepsBar.start runs it), step for step, every field the step player
## and the booklet read. Then what must not be used: the text edited by one
## part, an old link with none, steps written twice (the second replaces
## the first), and a model with a part this catalogue lacks.
##
## --write puts the steps in each IN and writes it to OUT (the share steps
## browser flow serves those).
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "--write":
		for n: int in range(1, args.size() - 1, 2):
			var text: String = FileAccess.get_file_as_string(args[n])
			var began: int = Time.get_ticks_msec()
			var out: String = await SharedPages.attach(text, _library, _store)
			var file := FileAccess.open(args[n + 1], FileAccess.WRITE)
			file.store_string(out)
			file.close()
			print("%s -> %s: steps %s in %d ms, %d bytes more" % [args[n], args[n + 1],
				"carried" if out.contains(SharedPages.HEAD) else "NOT carried",
				Time.get_ticks_msec() - began, out.length() - text.length()])
		quit(0)
		return
	await _same_steps("the house", FileAccess.get_file_as_string("res://models/house.ldr"))
	await _same_steps("the castle", FileAccess.get_file_as_string("res://models/castle.ldr"))
	await _same_steps("Orthanc's lowest 1,000 parts", _lowest_of_orthanc(1000))
	await _not_used()
	print("%d FAILED" % _failures if _failures else
		"a shared model's steps are carried with it and read back as the viewer would work them out")
	quit(1 if _failures else 0)


## The lowest [param count] parts of Orthanc's own model, as the share steps
## flow makes them.
func _lowest_of_orthanc(count: int) -> String:
	var text: String = FileAccess.get_file_as_string("res://models/orthanc.ldr")
	var lines := PackedStringArray(["0 FILE steps_%d.ldr" % count, "0 Steps %d" % count,
		"0 Name: steps_%d.ldr" % count, "0 Author: Brickworks", ""])
	for line: String in text.split("\n0 FILE ")[0].split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("1 ") and trimmed.to_lower().ends_with(".dat"):
			lines.append(trimmed)
			if lines.size() - 5 >= count:
				break
	return "\r\n".join(lines) + "\r\n"


## The world as the viewer has it: the text opened, a baseplate under it.
func _open_as_the_viewer(text: String) -> void:
	_store.open_text(text, "shared")
	var plate: int = _world.add_brick("3811", 2, Transform3D(Basis(), Vector3(0, 0, 0)))
	_store.scenery = {plate: true} if plate != 0 else {}


func _same_steps(what: String, text: String) -> void:
	print("\n%s" % what)
	var began: int = Time.get_ticks_msec()
	var attached: String = await SharedPages.attach(text, _library, _store)
	var took: int = Time.get_ticks_msec() - began
	_ok(attached.contains(SharedPages.HEAD), "its steps are written at the end of its text "
		+ "(%d ms, %d bytes on %d)" % [took, attached.length() - text.length(), text.length()])
	_open_as_the_viewer(attached)
	var read_began: int = Time.get_ticks_usec()
	var carried: Dictionary = SharedPages.read(attached, _world, _store.scenery)
	var read_ms: float = (Time.get_ticks_usec() - read_began) / 1000.0
	_ok(not carried.is_empty(), "...and read back for the world the viewer opens (%.1f ms)" % read_ms)
	if carried.is_empty():
		return
	var job := Working.Job.new()
	var worked: Array[Instructions.Step] = await Instructions.plan_paced(
		_world, _library, _store.scenery, {}, job, AuthorSteps.any(_world, _store.scenery))
	var mine: Array[Instructions.Step] = carried["steps"]
	var differ: int = 0
	var first: String = ""
	for n: int in maxi(mine.size(), worked.size()):
		var a: String = _said(mine[n]) if n < mine.size() else "none"
		var b: String = _said(worked[n]) if n < worked.size() else "none"
		if a != b:
			differ += 1
			if first.is_empty():
				first = "step %d: carried %s, worked out %s" % [n + 1, a.left(120), b.left(120)]
	_ok(differ == 0 and mine.size() == worked.size(),
		"...and they are the steps the viewer works out itself, step for step (%d of %d, %d differ%s)"
		% [mine.size(), worked.size(), differ, (": " + first) if differ > 0 else ""])
	var pages_carried: BuildSteps = BuildSteps.of(_world, _library, mine, _store.scenery)
	var pages_worked: BuildSteps = BuildSteps.of(_world, _library, worked, _store.scenery)
	var same_pages: bool = pages_carried.last() == pages_worked.last()
	for page: int in range(0, pages_carried.last() + 1):
		if not same_pages:
			break
		same_pages = pages_carried.caption(page) == pages_worked.caption(page) \
			and pages_carried.note(page) == pages_worked.note(page) \
			and pages_carried.fresh(page) == pages_worked.fresh(page) \
			and pages_carried.count(page) == pages_worked.count(page) \
			and str(pages_carried.lots(page)) == str(pages_worked.lots(page))
	_ok(same_pages, "...so every page of Build it shows the same: caption, note, new parts, "
		+ "what is on the baseplate and the parts to pick up (%d pages)" % pages_carried.last())


## Every field of a step the player, the timeline and the booklet read.
func _said(step: Instructions.Step) -> String:
	var copies: Array = step.copies.map(func(copy: PackedInt64Array) -> Array: return Array(copy))
	return JSON.stringify([step.index, step.number, Array(step.brick_ids), step.parts, step.unsupported,
		step.section, step.assembly, step.callout, step.callout_step, step.callout_steps, step.times,
		step.figure, Array(step.shown_ids), copies, step.authored_in, step.authored_step])


func _not_used() -> void:
	print("\nwhat must not be used")
	var text: String = FileAccess.get_file_as_string("res://models/house.ldr")
	var attached: String = await SharedPages.attach(text, _library, _store)
	# One part moved a stud: the steps are another model's.
	var lines: PackedStringArray = attached.split("\n")
	for n: int in lines.size():
		if lines[n].begins_with("1 "):
			var tokens: PackedStringArray = lines[n].strip_edges().split(" ", false)
			tokens[2] = str(float(tokens[2]) + 20.0)
			lines[n] = " ".join(tokens)
			break
	var edited: String = "\n".join(lines)
	_open_as_the_viewer(edited)
	_ok(SharedPages.read(edited, _world, _store.scenery).is_empty(),
		"the text edited by one part: its steps are not used")
	_open_as_the_viewer(text)
	_ok(SharedPages.read(text, _world, _store.scenery).is_empty(), "an old link, with none: none")
	var twice: String = await SharedPages.attach(attached, _library, _store)
	_ok(twice.count(SharedPages.HEAD) == 1 and twice == attached,
		"written twice, the second replaces the first (%d blocks)" % twice.count(SharedPages.HEAD))
	_open_as_the_viewer(attached)
	# The world the viewer opened lacks a part the steps count: another
	# catalogue, or a part that did not arrive.
	var last: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			last = maxi(last, brick.id)
	_world.remove_brick(last)
	_ok(SharedPages.read(attached, _world, _store.scenery).is_empty(),
		"a part fewer in the world than the steps count: not used")


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
