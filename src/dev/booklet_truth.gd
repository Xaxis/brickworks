## A model's booklet, and what each of its pages adds, for a builder to be
## judged against (tools/bench/booklet_follow.py).
##
##   godot --path . --resolution 1200x800 --script src/dev/booklet_truth.gd -- \
##       --model=FILE --html=OUT.html --json=OUT.json
##
## Opens the file as File, Open does (ModelStore), makes its booklet as
## Instructions does (BookletMaker, the hidden parts' colours marked), and
## writes the booklet and, from the same plan, every page's steps with the
## parts each adds: part, colour and place in the file's coordinates, as
## save_model writes them. One process makes both, so the parts said for a
## page are the parts drawn on it. Needs a window: the pictures are drawn.
extends SceneTree

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var model: String = ""
	var html_path: String = ""
	var json_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--model="):
			model = argument.trim_prefix("--model=")
		elif argument.begins_with("--html="):
			html_path = argument.trim_prefix("--html=")
		elif argument.begins_with("--json="):
			json_path = argument.trim_prefix("--json=")
	if model.is_empty() or html_path.is_empty() or json_path.is_empty():
		print("booklet truth: --model=, --html= and --json= are needed")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		print("booklet truth: needs a window, the pictures are drawn")
		quit(2)
		return
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("booklet truth: no catalogue")
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
	var text: String = FileAccess.get_file_as_string(model)
	var opened: Dictionary = _store.open_text(text, model.get_file())
	if _world.brick_count() == 0:
		print("booklet truth: nothing opened from %s (%s)" % [model, opened.get("error", "")])
		quit(1)
		return
	var title: String = model.get_file().get_basename().capitalize()
	for line: String in text.split("\n"):
		var said: String = line.strip_edges()
		if said.begins_with("0 ") and not said.begins_with("0 FILE") \
				and not said.begins_with("0 !") and not said.begins_with("0 //") \
				and not said.begins_with("0 Name:") and said.length() > 2:
			title = said.substr(2).strip_edges()
			break

	BookletMaker.open_when_written = false
	var maker := BookletMaker.new()
	maker.library = _library
	maker.marks = HiddenColours.live_marks(_store.hidden_scheme, _world, _library,
		_store.scenery)
	get_root().add_child(maker)
	var started: int = Time.get_ticks_msec()
	var html: String = await maker.make(_world, _store.scenery, title)
	if html.is_empty() or maker.document == null:
		print("booklet truth: no booklet made")
		quit(1)
		return
	var out := FileAccess.open(html_path, FileAccess.WRITE)
	out.store_string(html)
	out.close()

	var back := Transform3D(Basis.IDENTITY, -_store.lift())
	var bricks: Dictionary = {}
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if _store.scenery.has(brick.id):
			continue
		var numbers: PackedFloat64Array = LdrModel.from_transform(back * brick.transform)
		var rounded: Array = []
		for value: float in numbers:
			rounded.append(snappedf(value, 0.0001))
		bricks[str(brick.id)] = {"part": brick.part_id, "colour": brick.color_code,
			"ldraw": rounded}
	var plan: Array = []
	for index: int in maker.plan.size():
		var step: Instructions.Step = maker.plan[index]
		var copies: Array = []
		for copy: PackedInt64Array in step.copies:
			copies.append(Array(copy))
		plan.append({"index": index, "number": step.number, "callout": step.callout,
			"callout_step": step.callout_step, "callout_steps": step.callout_steps,
			"assembly": step.assembly, "times": step.times, "figure": step.figure,
			"attaches": step.attaches(), "bricks": Array(step.brick_ids),
			"shown": Array(step.shown_ids), "copies": copies})
	var pages: Array = []
	for page: Booklet.Page in maker.document.pages:
		var steps: Array = []
		for entry: Booklet.Entry in page.entries:
			if entry.has_meta("step"):
				steps.append({"plan": int(entry.get_meta("step")), "number": entry.number,
					"in_callout": entry.in_callout})
			# A callout drawn in a box beside its step is on this page too.
			if entry.callout != null and not entry.callout.own_pages \
					and Booklet._fits_inline(entry.callout):
				for inside: Booklet.Entry in entry.callout.steps:
					if inside.has_meta("step"):
						steps.append({"plan": int(inside.get_meta("step")),
							"number": inside.number, "in_callout": true, "inline": true})
		pages.append({"number": page.number, "kind": page.kind, "name": page.name,
			"banner": page.banner, "steps": steps})
	var truth := {"model": model, "title": title, "html": html_path,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0,
		"steps": maker.document.steps, "pieces": maker.document.pieces,
		"pages": pages, "plan": plan, "bricks": bricks}
	var written := FileAccess.open(json_path, FileAccess.WRITE)
	written.store_string(JSON.stringify(truth))
	written.close()
	print("booklet truth: %d pages, %d steps, %d parts in %.1f s" % [pages.size(),
		maker.document.steps, bricks.size(), truth["seconds"]])
	quit(0)
