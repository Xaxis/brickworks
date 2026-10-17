## Big models stay fast: the app's own work in the acts a builder makes,
## timed headless (nothing is drawn, so what is timed is this code's), and
## how it grows with the model.
##
##   godot --headless --path . --script src/dev/bigmodel_probe.gd
##   godot --headless --path . --script src/dev/bigmodel_probe.gd -- --profile [--bigmodel-out=FILE.json] PATH ...
##   godot --headless --path . --script src/dev/bigmodel_probe.gd -- --open [--times=N] [--dump=DIR] [--profile] PATH ...
##
## Bare, it is the check (tools/check.sh): two models made here, of 1,000
## and 5,000 parts in sub-models with author's steps, each opened as File,
## Open opens a file. On each, as a person makes them: a right-drag orbit,
## Ctrl-A, D (the selection nudged), Ctrl-Z and Ctrl-Shift-Z, Delete and
## Ctrl-Z, and the timeline's Next. What it holds is how each act grows
## from the small model to the big one, a ratio of two runs on the same
## machine in the same minute, never a wall clock: an orbit frame and a
## step of the timeline must not grow with the model, and select all, the
## move, its undo and redo, Delete and its undo no faster than the model
## (near-linear; quadratic is 25 times at five times the parts).
##
## With PATHs (real sets' files), each is opened and timed the same way,
## nothing judged. --profile says where each act's time went: every
## handler of the builder's, the world's, the timeline's and the store's
## signals timed one by one, every node's _process timed in the orbit,
## and the parts of the page's state the web build writes twice a second.
##
## With --open, each is only opened, N times (3), and the quickest kept, the
## first beside it (the first builds the parts the file carries): the open's
## phases (ModelStore.open_phases) and, with --profile, the bar's opened
## handlers and their pieces; with --dump, the world of the first open
## written to DIR part by part (each part's number, colour, place, sub-model
## path, step and lattice cover; the store's and the history's state), so
## two builds' opens are compared with cmp.
##
## Bare, it also opens two real sets where the checkout has them
## (REAL_SETS), and holds the big one's open to near-linear in its parts.
##
## Measured at 5,025 parts in a browser (CADTASK.md, 2026-10-16) an
## orbit frame's own work was 2.7 s, select all 65 s, and the undo of a
## Delete of everything had not ended after 15 minutes.
extends SceneTree

## Two real sets the check opens, of 925 and 4,139 parts (the LDraw model
## repository's files, vendor/omr): opening the second may take no more
## than LINEAR's share of how many more parts it has.
const REAL_SETS := ["res://vendor/omr/files/75969-1.mpd", "res://vendor/omr/files/42082-1.mpd"]

## The two sizes the check makes, in parts.
const SMALL := 1000
const BIG := 5000
## The most an act's time may grow from SMALL to BIG parts: five times the
## parts, so linear is 5 and quadratic 25. Acts that should not grow with
## the model at all are held to FLAT. Times under FLOOR_MS are read as
## FLOOR_MS, so a millisecond's noise on a fast act is not a ratio.
const LINEAR := 9.0
const FLAT := 3.0
const FLOOR_MS := 25.0

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _steps: StepsBar
var _failures: int = 0
var _profile: bool = false
var _open_only: bool = false
var _times: int = 3
var _dump: String = ""
## Name -> [calls, total us, most us], while profiling.
var _spent: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	var out_path: String = ""
	var paths: PackedStringArray = PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--profile":
			_profile = true
		elif argument.begins_with("--bigmodel-out="):
			out_path = argument.trim_prefix("--bigmodel-out=")
		elif argument == "--open":
			_open_only = true
		elif argument.begins_with("--times="):
			_times = maxi(int(argument.trim_prefix("--times=")), 1)
		elif argument.begins_with("--dump="):
			_dump = argument.trim_prefix("--dump=")
		else:
			paths.append(argument)
	# Parts a file carries are built on its first open, as for a person
	# opening a file new to them, and never kept: kept, the next run's start
	# built them and its first open was a second one.
	CustomParts.keeps = false
	CustomParts.dir = "user://bigmodel_probe_parts/"
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_steps = _main.get("_steps")
	if _profile:
		_wrap_signals()

	var rows: Array = []
	var sets: Array = []
	if paths.is_empty():
		for size: int in [SMALL, BIG]:
			rows.append(await _one("made %d" % size, _made(size)))
		# And two real sets opened, where this checkout has them: each its
		# first open, the parts the file carries built.
		sets = await _real_sets()
	else:
		for path: String in paths:
			if _open_only:
				rows.append(await _opened(path))
			else:
				rows.append(await _one(path.get_file(), FileAccess.get_file_as_string(path)))
	if not out_path.is_empty():
		var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"models": rows}, " "))
		file.close()
		print("bigmodel: written to %s" % out_path)
	if paths.is_empty():
		_judge(rows[0], rows[1])
		_judge_open(sets)
		await _open_mid_weigh()
		print("bigmodel: %s" % ("every act grows no faster than the model"
			if _failures == 0 else "%d acts grow faster than the model" % _failures))
	await _quit_mid_weigh()


## The next file opened at once, while the last is weighed on a worker
## (Main._weigh, 600 parts or more), as a person opens one file after
## another: 8202-1, whose hose is a part new to the library, after 42082-1.
## The library adds no part while a worker reads it, and until 2026-10-17
## the open waited out the weighing, 10.7 s of its 15.4 s. The weighing
## gives way (PartLibrary.reading_in's stop): the open takes a fraction of
## a whole weighing of the model before it, both timed here, and the model
## it opened is weighed.
func _open_mid_weigh() -> void:
	const NEXT := "res://vendor/omr/files/8202-1.mpd"
	if not FileAccess.file_exists(NEXT) or _world.brick_count() < 600:
		print("  ----  8202-1 is not in this checkout, or no big model is up: the open "
			+ "while a model is weighed was not judged")
		return
	var weighed: String = str(REAL_SETS[-1]).get_file().get_basename()
	var whole: int = -1
	for weighing: int in 2:
		_main.set("_stability_revision", -1)
		_main.set("_stability_at", 0)
		for _n: int in 300:
			if bool(_main.get("_weighing")):
				break
			await process_frame
		if not bool(_main.get("_weighing")):
			_check("%s was weighed on a worker" % weighed, false)
			return
		var began: int = Time.get_ticks_msec()
		if weighing == 0:
			while bool(_main.get("_weighing")) and Time.get_ticks_msec() - began < 300000:
				await process_frame
			whole = Time.get_ticks_msec() - began
			continue
		var result: Dictionary = _store.open_text(FileAccess.get_file_as_string(NEXT), "8202-1")
		(_main.get("_bar") as ModelBar).opened.emit(int(result["placed"]))
		var took: int = Time.get_ticks_msec() - began
		_check("8202-1 opened while %s was weighed, in %d ms: not waiting for the weighing, "
			% [weighed, took] + "%d ms whole" % whole, took * 3 < whole)
	for _n: int in 300:
		if not bool(_main.get("_weighing")) and int(_main.get("_stability_revision")) \
				== _world.revision:
			break
		await process_frame
	var said: String = str(_main.get("_stability_text"))
	_check("and 8202-1 was weighed after: \"%s\"" % said, not said.is_empty())


## Quit as a person closes the window after a big model: at once, the model
## up and its weigh on a worker (Main._weigh). The engine dumped core on the
## way out when it was (WorkerTasks), and the suite reads that exit as this
## check failing; until that was found, this cleared the model and let its
## work finish first, and opened the real sets in a process of its own.
func _quit_mid_weigh() -> void:
	_main.set("_stability_revision", -1)
	for _n: int in 300:
		if bool(_main.get("_weighing")):
			break
		await process_frame
	print("  quitting with the model's weigh %s" % ("on a worker" if bool(_main.get("_weighing"))
		else "not going"))
	quit(1 if _failures > 0 else 0)


## A model of [param parts] parts as a file: towers of bricks of four
## sizes in eight colours, fifty to a sub-model, each sub-model its own
## steps of ten, laid on a grid.
static func _made(parts: int) -> String:
	const PARTS := ["3001.dat", "3003.dat", "3010.dat", "3004.dat"]
	const COLOURS := [4, 1, 14, 2, 15, 0, 71, 72]
	const PER := 50
	var subs: int = ceili(float(parts) / PER)
	var across: int = ceili(sqrt(float(subs)))
	var text: String = "0 FILE big.ldr\n0 big\n0 Name: big.ldr\n0 Author: bigmodel_probe\n"
	for s: int in subs:
		text += "1 16 %d 0 %d 1 0 0 0 1 0 0 0 1 tower%d.ldr\n" % [(s % across) * 120,
			(s / across) * 80, s]
		if s % 10 == 9:
			text += "0 STEP\n"
	for s: int in subs:
		text += "0 FILE tower%d.ldr\n0 tower %d\n0 Name: tower%d.ldr\n" % [s, s, s]
		for n: int in mini(PER, parts - s * PER):
			text += "1 %d 0 %d 0 1 0 0 0 1 0 0 0 1 %s\n" % [COLOURS[(n + s) % COLOURS.size()],
				-24 * n, PARTS[(n / 3 + s) % PARTS.size()]]
			if n % 10 == 9:
				text += "0 STEP\n"
	return text


## Open [param text] and time each act on it.
func _one(name: String, text: String) -> Dictionary:
	_main.call("clear_model")
	await _frames(10)
	_spent.clear()
	var row: Dictionary = {"model": name}
	var began: int = Time.get_ticks_usec()
	var result: Dictionary = _store.open_text(text, name.get_basename())
	(_main.get("_bar") as ModelBar).opened.emit(int(result["placed"]))
	await _frames(2)
	row["open_ms"] = (Time.get_ticks_usec() - began) / 1000.0
	row["parts"] = _world.brick_count() - _store.scenery.size()
	await _quiet()
	row["open_settled_ms"] = (Time.get_ticks_usec() - began) / 1000.0
	_said("open", row["open_settled_ms"])
	_profiled(row, "open")
	# What the web build tells the page twice a second of the sub-assemblies,
	# kept while nothing changes: worked out each time, it walked the model
	# three times a telling (asked twice here, it is the same answer).
	row["page_kept"] = _main.has_method("_page_assemblies") and is_same(
		(_main.call("_page_assemblies") as Array)[0], (_main.call("_page_assemblies") as Array)[0])
	var view: Rect2 = (_main.call("model_cover") as Dictionary)["view"]
	var middle: Vector2 = view.get_center()

	row["idle"] = await _act("idle", func() -> void: pass, func() -> bool: return true, 10)

	# orbit: a right-drag across the middle, a step a frame.
	_move(middle, Vector2.ZERO, 0)
	await _frames(3)
	var nodes: Array = _take_processing() if _profile else []
	var verbs: EditVerbs = _main.get("_verbs")
	var looked: int = verbs.looked
	_press(MOUSE_BUTTON_RIGHT, middle, true)
	row["orbit"] = await _framed(30, func(n: int) -> void:
		_move(middle + Vector2(6.0 * n, 2.0 * sin(n * 0.4)), Vector2(6.0, 0.0),
			MOUSE_BUTTON_MASK_RIGHT), nodes)
	# How many times the model was asked what is under the pointer while the
	# view turned: a line marched through it, every frame, for a cursor the
	# turn decides anyway.
	row["orbit"]["looked"] = verbs.looked - looked
	_press(MOUSE_BUTTON_RIGHT, middle + Vector2(180.0, 0.0), false)
	_give_back(nodes)
	_profiled(row, "orbit")
	await _quiet()

	var everything: int = row["parts"]
	var sample: int = _a_part()
	var was: Vector3 = _origin(sample)
	row["select_all"] = await _act("select_all", func() -> void: _key(KEY_A, true),
		func() -> bool: return _builder.selection.size() >= everything)
	row["select_all"]["selected"] = _builder.selection.size()
	_profiled(row, "select_all")
	await _quiet()
	if _profile:
		await _sections(row)
	row["move"] = await _act("move", func() -> void: _key(KEY_D),
		func() -> bool: return _origin(sample) != was)
	var moved_to: Vector3 = _origin(sample)
	_profiled(row, "move")
	await _quiet()
	if _profile:
		await _edit_sections(row)
	row["undo_move"] = await _act("undo_move", func() -> void: _key(KEY_Z, true),
		func() -> bool: return _origin(sample) == was)
	_profiled(row, "undo_move")
	await _quiet()
	row["redo_move"] = await _act("redo_move", func() -> void: _key(KEY_Z, true, true),
		func() -> bool: return _origin(sample) == moved_to)
	_profiled(row, "redo_move")
	await _quiet()
	if not _profile:
		# Each again, and the quicker kept: on a shared machine one run of an
		# act now and then takes twice what it does, and a ratio of one such
		# to a quiet one says nothing about the code.
		_builder.clear_selection()
		await _quiet()
		row["select_all"] = _quicker(row["select_all"], await _act("select_all",
			func() -> void: _key(KEY_A, true),
			func() -> bool: return _builder.selection.size() >= everything))
		await _quiet()
		row["undo_move"] = _quicker(row["undo_move"], await _act("undo_move",
			func() -> void: _key(KEY_Z, true), func() -> bool: return _origin(sample) == was))
		await _quiet()
		row["redo_move"] = _quicker(row["redo_move"], await _act("redo_move",
			func() -> void: _key(KEY_Z, true, true),
			func() -> bool: return _origin(sample) == moved_to))
		await _quiet()
		row["move"] = _quicker(row["move"], await _act("move", func() -> void: _key(KEY_D),
			func() -> bool: return _origin(sample) != moved_to))
		await _quiet()
		row["lattice_true"] = _lattice_true()

	var rounds: int = 1 if _profile else 2
	for round: int in rounds:
		if _builder.selection.size() < everything:
			_key(KEY_A, true)
			await _quiet()
		var standing: int = _world.brick_count()
		var gone: Dictionary = await _act("delete", func() -> void: _key(KEY_DELETE),
			func() -> bool: return _world.brick_count() <= standing - everything)
		row["delete"] = gone if round == 0 else _quicker(row["delete"], gone)
		_profiled(row, "delete")
		await _quiet()
		var back: Dictionary = await _act("undo_delete", func() -> void: _key(KEY_Z, true),
			func() -> bool: return _world.brick_count() == standing)
		row["undo_delete"] = back if round == 0 else _quicker(row["undo_delete"], back)
		_profiled(row, "undo_delete")
		await _quiet()
	_builder.clear_selection()
	await _quiet()

	# The timeline, then its Next, as a click on it does.
	row["timeline"] = await _act("timeline", func() -> void: _key(KEY_B),
		func() -> bool: return _steps.is_playing_back() and not Working.is_busy(), 3000)
	_profiled(row, "timeline")
	await _quiet()
	var next: Button = _steps.controls_by_name().get("steps_next")
	var stepping: Array = []
	for _k: int in 3:
		var at: int = _steps.timeline_at().x
		stepping.append(await _act("step", func() -> void:
			if next != null:
				next.pressed.emit(),
			func() -> bool: return _steps.timeline_at().x != at))
		await _quiet()
	row["step"] = _worst(stepping)
	_profiled(row, "step")
	# Ten steps forward, as Next makes them, the work of the steps alone:
	# what a step costs without the frames around it.
	var steps_began: int = Time.get_ticks_usec()
	for _k: int in 10:
		_steps.step_forward()
	row["ten_steps_ms"] = (Time.get_ticks_usec() - steps_began) / 1000.0
	_said("ten steps", row["ten_steps_ms"])
	await _quiet()
	_key(KEY_B)
	await _quiet()
	print("  %s, %d parts: %s" % [name, row["parts"], JSON.stringify(_summary(row))])
	return row


## [param path] opened [member _times] times and nothing else, the quickest
## kept: to the second frame, and until it settles; its phases, and with
## --profile the handlers. With --dump, the world of the first open written
## out (_dumped).
func _opened(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var best: Dictionary = {}
	var first: Dictionary = {}
	var each: Array = []
	for n: int in _times:
		_main.call("clear_model")
		await _quiet()
		_spent.clear()
		var began: int = Time.get_ticks_usec()
		var result: Dictionary = _store.open_text(text, path.get_file().get_basename())
		var stored: int = Time.get_ticks_usec()
		var phases: Variant = _store.get("open_phases")
		(_main.get("_bar") as ModelBar).opened.emit(int(result["placed"]))
		var emitted: int = Time.get_ticks_usec()
		await _frames(2)
		var row: Dictionary = {"model": path.get_file(),
			"open_text_ms": (stored - began) / 1000.0,
			"opened_handlers_ms": (emitted - stored) / 1000.0,
			"open_ms": (Time.get_ticks_usec() - began) / 1000.0,
			"parts": _world.brick_count() - _store.scenery.size(),
			"phases": (phases as Dictionary).duplicate() if phases is Dictionary else {}}
		await _quiet()
		row["open_settled_ms"] = (Time.get_ticks_usec() - began) / 1000.0
		each.append(row["open_settled_ms"])
		print("  %s, %d parts: open_text %.0f ms, opened %.0f ms, to the second frame %.0f ms, "
			% [row["model"], row["parts"], row["open_text_ms"], row["opened_handlers_ms"],
			row["open_ms"]] + "settled %.0f ms" % row["open_settled_ms"])
		print("    phases %s" % JSON.stringify(row["phases"]))
		_profiled(row, "open")
		if n == 0 and not _dump.is_empty():
			_dumped(_dump.path_join(path.get_file().get_basename() + ".dump"))
		if _profile and n == 0:
			_open_sections(row)
		if n == 0:
			first = row
		if best.is_empty() or float(row["open_settled_ms"]) < float(best["open_settled_ms"]):
			best = row
	# The first open builds the parts the file carries; later ones find them
	# built, so the first is a person's open of a file new to them.
	best = best.duplicate()
	best["each_settled_ms"] = each
	best["first"] = first
	return best


## After an open: the pieces of what the bar's opened handlers do, each
## timed alone, again, on the model as it opened.
func _open_sections(row: Dictionary) -> void:
	var shell: Node = _main.get("_shell")
	var assemblies: Assemblies = shell.get("assemblies") if shell != null else null
	var parts: Dictionary = {
		"main._lay_baseplate": func() -> void: _main.call("_lay_baseplate"),
		"main._model_bounds": func() -> void: _main.call("_model_bounds"),
		"main._built_bounds": func() -> void: _main.call("_built_bounds"),
		"main._on_model_changed": func() -> void: _main.call("_on_model_changed"),
		"assistant.forget_built": func() -> void:
			(_main.get("_assistant") as Object).call("forget_built"),
		"seat_offer.check": func() -> void: (_main.get("_seat_offer") as Object).call("check"),
		"Seating.misplaced": func() -> void: Seating.misplaced(_world, _builder,
			_main.get("_assistant"), _store.scenery),
		"assemblies.enter": func() -> void:
			if assemblies != null:
				assemblies.enter(""),
	}
	var out: Dictionary = {}
	for name: String in parts:
		var t0: int = Time.get_ticks_usec()
		(parts[name] as Callable).call()
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		out[name] = snappedf(ms, 0.01)
		print("        section %8.2f ms  %s" % [ms, name])
	row["open_sections"] = out


## The world as it opened, a line a part in id order, then the store's,
## the lattice's and the history's state: what two builds' opens of one
## file are compared by.
func _dumped(file_path: String) -> void:
	var lines := PackedStringArray()
	var lattice: BrickLattice = _builder.lattice
	for brick: BrickWorld.Brick in _world.bricks():
		var at: Transform3D = brick.transform
		var numbers := PackedStringArray()
		for v: float in [at.origin.x, at.origin.y, at.origin.z, at.basis.x.x, at.basis.x.y,
				at.basis.x.z, at.basis.y.x, at.basis.y.y, at.basis.y.z, at.basis.z.x, at.basis.z.y,
				at.basis.z.z]:
			numbers.append("%.4f" % v)
		var cover: PackedInt32Array = lattice.boxes_of(brick.id)
		lines.append("%d %s %d [%s] group=%s unit=%s step=%d scenery=%s cover=%d:%d" % [brick.id,
			brick.part_id, brick.color_code, " ".join(numbers), brick.group, brick.unit, brick.step,
			_store.scenery.has(brick.id), cover.size() / 6, hash(cover)])
	lines.append("title=%s whole=%s awaited=%d unshown=%s lifted=%.4f floor=%s set=%s share=%s"
		% [_store.title, _store.whole, _store.awaited.size(), JSON.stringify(_store.unshown),
		float(_store.get("_lifted_by")), _store.model_floor.words(), _store.from_set,
		_store.share_id])
	lines.append("unit_steps=%s" % JSON.stringify(_world.unit_steps))
	lines.append("history=%d redo=%d bricks=%d" % [(_builder.get("_history") as Array).size(),
		(_builder.get("_redo") as Array).size(), _world.brick_count()])
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("    the world as it opened: %s" % file_path)


## After moves, undos and redos of everything: whether the lattice holds
## each part where it stands, its cover what the part's own makes it there
## and the cell at its cover's low corner found as it, by its buckets.
func _lattice_true() -> bool:
	var lattice: BrickLattice = _builder.lattice
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var held: PackedInt32Array = lattice.boxes_of(brick.id)
		var made: PackedInt32Array = _builder.boxes_for(
			_builder.library.mesh_for(brick.part_id), brick.transform)
		if held != made:
			print("    the lattice holds brick %d as %s, its part makes %s"
				% [brick.id, held.slice(0, 6), made.slice(0, 6)])
			return false
		if not held.is_empty():
			var corner := Vector3i(held[0], held[1], held[2])
			var found: int = lattice.brick_at(corner)
			if found != brick.id and found == 0:
				print("    no brick at the low corner of brick %d's cover" % brick.id)
				return false
	return true


## A part of the model's, not the ground's.
func _a_part() -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			return brick.id
	return 0


func _origin(brick_id: int) -> Vector3:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	return brick.transform.origin if brick != null else Vector3.INF


## Press, then frames until [param done] says so (at most [param most]),
## then two more for what it deferred. The act's whole time, its worst
## frame, and how many frames it took.
func _act(name: String, press: Callable, done: Callable, most: int = 1200) -> Dictionary:
	await process_frame
	var began: int = Time.get_ticks_usec()
	var last: int = began
	press.call()
	var frames: Array = []
	var finished: bool = false
	var after: int = 0
	while frames.size() < most and after < 2:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		if finished:
			after += 1
		elif done.call():
			finished = true
	var out: Dictionary = {"total_ms": (last - began) / 1000.0, "worst_ms": frames.max(),
		"frames": frames.size(), "done": finished}
	_said(name, out["total_ms"], out["worst_ms"])
	return out


## [param count] frames, calling [param each] with the frame's number
## before each: each frame's time. With [param nodes], their _process is
## called here, one at a time, timed.
func _framed(count: int, each: Callable, nodes: Array = []) -> Dictionary:
	await process_frame
	var last: int = Time.get_ticks_usec()
	var frames: Array = []
	for n: int in count + 1:
		if n < count:
			each.call(n)
		await process_frame
		var now: int = Time.get_ticks_usec()
		if not nodes.is_empty():
			for node: Node in nodes:
				if is_instance_valid(node) and node.is_inside_tree():
					var t0: int = Time.get_ticks_usec()
					node.call("_process", 1.0 / 60.0)
					_add("_process " + _node_name(node), Time.get_ticks_usec() - t0)
			now = Time.get_ticks_usec()
		if n > 0:
			frames.append((now - last) / 1000.0)
		last = now
	var sorted: Array = frames.duplicate()
	sorted.sort()
	var out: Dictionary = {"median_ms": sorted[sorted.size() / 2], "worst_ms": sorted.back(),
		"frames": frames.size()}
	_said("orbit", out["median_ms"], out["worst_ms"])
	return out


## The quicker of two runs of an act, with both times.
static func _quicker(one: Dictionary, two: Dictionary) -> Dictionary:
	var out: Dictionary = (one if float(one["total_ms"]) <= float(two["total_ms"]) else two).duplicate()
	out["each_ms"] = [one["total_ms"], two["total_ms"]]
	out["done"] = bool(one["done"]) and bool(two["done"])
	return out


static func _worst(acts: Array) -> Dictionary:
	var out: Dictionary = {"total_ms": 0.0, "worst_ms": 0.0, "done": true, "each_ms": []}
	for one: Dictionary in acts:
		out["total_ms"] = maxf(out["total_ms"], one["total_ms"])
		out["worst_ms"] = maxf(out["worst_ms"], one["worst_ms"])
		out["done"] = out["done"] and one["done"]
		(out["each_ms"] as Array).append(one["total_ms"])
	return out


## Frames until nothing is working and a frame takes under 50 ms, or two
## hundred.
func _quiet() -> void:
	var calm: int = 0
	for _n: int in 400:
		var t0: int = Time.get_ticks_usec()
		await process_frame
		if Working.is_busy() or Time.get_ticks_usec() - t0 > 50000:
			calm = 0
		else:
			calm += 1
		if calm >= 5:
			return


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _said(name: String, ms: float, worst: float = -1.0) -> void:
	if worst >= 0.0:
		print("    %-12s %9.1f ms, worst frame %8.1f ms" % [name, ms, worst])
	else:
		print("    %-12s %9.1f ms" % [name, ms])


static func _summary(row: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in row:
		if row[key] is Dictionary and (row[key] as Dictionary).has("worst_ms"):
			var act: Dictionary = row[key]
			out[key] = snappedf(float(act.get("total_ms", act.get("median_ms", 0.0))), 0.1)
	out["open_ms"] = snappedf(float(row["open_settled_ms"]), 0.1)
	return out


# -- the check ------------------------------------------------------------


func _judge(small: Dictionary, big: Dictionary) -> void:
	var grew: float = float(big["parts"]) / maxf(float(small["parts"]), 1.0)
	print("  %d parts against %d: %.1f times the parts" % [big["parts"], small["parts"], grew])
	_check("the big model opened whole", int(big["parts"]) >= BIG * 0.98)
	for act: String in ["select_all", "move", "undo_move", "redo_move", "delete", "undo_delete",
			"step"]:
		_check("%s finished at both sizes" % act, bool(small[act]["done"]) and bool(big[act]["done"]))
	_check("after moving everything, undoing it and redoing it, the lattice holds every part "
		+ "where it stands", bool(small.get("lattice_true", false))
		and bool(big.get("lattice_true", false)))
	_check("what the page is told of the sub-assemblies is kept while nothing changes",
		bool(small["page_kept"]) and bool(big["page_kept"]))
	# Not with the model: a frame of the orbit, and a step of the timeline.
	_ratio("an orbit frame", small["orbit"]["median_ms"], big["orbit"]["median_ms"], FLAT)
	# A right press is a click until it has moved a few pixels (a menu, on a
	# part), and the pointer is asked about while it is one.
	_check("the view turned without asking the model what is under the pointer, past "
		+ "the press (%d times in 30 frames)" % int(big["orbit"]["looked"]),
		int(big["orbit"]["looked"]) <= 3)
	_ratio("a step of the timeline", small["step"]["total_ms"], big["step"]["total_ms"], FLAT)
	_ratio("ten steps of the timeline, alone", small["ten_steps_ms"], big["ten_steps_ms"], FLAT)
	# With it, no faster.
	for act: String in ["select_all", "move", "undo_move", "redo_move", "delete", "undo_delete"]:
		_ratio(act, small[act]["total_ms"], big[act]["total_ms"], LINEAR)


## The real sets' first opens (_opened), each once, the parts the file
## carries built: [] when the checkout has not got them.
func _real_sets() -> Array:
	for path: String in REAL_SETS:
		if not FileAccess.file_exists(path):
			return []
	var times: int = _times
	_times = 1
	var sets: Array = []
	for path: String in REAL_SETS:
		sets.append(await _opened(path))
	_times = times
	return sets


## The real sets' first opens (_opened): the big one opened whole, and in
## no more time than its parts, near-linearly (LINEAR over five times the
## parts, of the parts it has more). Measured 2026-10-16: 10.5 s against
## 2.0 s on main (5.3x), 3.1 s against 0.7 s after (4.5x); said, not judged,
## where vendor/omr is not.
func _judge_open(sets: Array) -> void:
	if sets.size() < 2:
		if not FileAccess.file_exists(REAL_SETS[0]) or not FileAccess.file_exists(REAL_SETS[1]):
			print("  ----  the real sets are not in this checkout (vendor/omr): their opens "
				+ "were not judged")
		return
	var small: Dictionary = sets[0]
	var big: Dictionary = sets[1]
	var grew: float = float(big["parts"]) / maxf(float(small["parts"]), 1.0)
	_check("%s opened whole, %d parts" % [big["model"], big["parts"]], int(big["parts"]) >= 4139)
	_ratio("opening %s against %s (%.1f times the parts)" % [big["model"], small["model"], grew],
		small["open_settled_ms"], big["open_settled_ms"], LINEAR / (float(BIG) / SMALL) * grew)


func _ratio(what: String, small_ms: float, big_ms: float, most: float) -> void:
	var ratio: float = maxf(big_ms, FLOOR_MS) / maxf(small_ms, FLOOR_MS)
	_check("%s grows %.1fx (%.0f ms -> %.0f ms; at most %.0fx)" % [what, ratio, small_ms, big_ms,
		most], ratio <= most)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


# -- where the time went (--profile) ---------------------------------------


func _add(name: String, us: int) -> void:
	var was: Array = _spent.get(name, [0, 0, 0])
	_spent[name] = [was[0] + 1, was[1] + us, maxi(was[2], us)]


## The time each handler took since the last act, the largest first, into
## [param row] under [param act], and printed.
func _profiled(row: Dictionary, act: String) -> void:
	if not _profile:
		return
	var names: Array = _spent.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return int(_spent[a][1]) > int(_spent[b][1]))
	var out: Array = []
	for name: String in names.slice(0, 14):
		var was: Array = _spent[name]
		if int(was[1]) < 2000:
			break
		out.append([name, was[0], snappedf(was[1] / 1000.0, 0.1), snappedf(was[2] / 1000.0, 0.1)])
		print("        %8.1f ms in %4d calls (most %7.1f)  %s" % [was[1] / 1000.0, was[0],
			was[2] / 1000.0, name])
	row[act + "_profile"] = out
	_spent.clear()


## Every handler of these objects' signals, timed: disconnected and
## connected again through a wrapper that times it, in the same order with
## the same flags.
func _wrap_signals() -> void:
	var shell: Node = _main.get("_shell")
	var objects: Dictionary = {"builder": _builder, "world": _world, "store": _store,
		"steps": _steps, "bar": _main.get("_bar"), "verbs": _main.get("_verbs"),
		"playback": _main.get("_playback")}
	if shell != null:
		objects["assemblies"] = shell.get("assemblies")
	for label: String in objects:
		var target: Object = objects[label]
		if target == null:
			continue
		for info: Dictionary in target.get_signal_list():
			var signal_name: String = info["name"]
			var count: int = (info["args"] as Array).size()
			var index: int = 0
			for connection: Dictionary in target.get_signal_connection_list(signal_name):
				var callable: Callable = connection["callable"]
				var flags: int = connection["flags"]
				var name: String = "%s.%s -> %s #%d" % [label, signal_name, _callable_name(callable),
					index]
				index += 1
				var wrapped: Callable = _wrapper(name, callable, count)
				if not wrapped.is_valid():
					continue
				target.disconnect(signal_name, callable)
				target.connect(signal_name, wrapped, flags)


func _wrapper(name: String, callable: Callable, count: int) -> Callable:
	match count:
		0:
			return func() -> void: _timed_call(name, callable, [])
		1:
			return func(a: Variant) -> void: _timed_call(name, callable, [a])
		2:
			return func(a: Variant, b: Variant) -> void: _timed_call(name, callable, [a, b])
		3:
			return func(a: Variant, b: Variant, c: Variant) -> void:
				_timed_call(name, callable, [a, b, c])
	return Callable()


func _timed_call(name: String, callable: Callable, args: Array) -> void:
	var t0: int = Time.get_ticks_usec()
	# A handler bound to fewer arguments than the signal has takes the first.
	var takes: int = callable.get_argument_count()
	callable.callv(args.slice(0, takes) if takes >= 0 and takes < args.size() else args)
	_add(name, Time.get_ticks_usec() - t0)


static func _callable_name(callable: Callable) -> String:
	var target: Object = callable.get_object()
	var where: String = ""
	if target != null:
		var script: Script = target.get_script()
		where = script.resource_path.get_file() if script != null else target.get_class()
	return "%s.%s" % [where, callable.get_method()]


static func _node_name(node: Node) -> String:
	var script: Script = node.get_script()
	return "%s (%s)" % [node.name, script.resource_path.get_file() if script != null else ""]


## Every node whose script has a _process and is processing, in the order
## the tree processes them, its processing taken over by _framed.
func _take_processing() -> Array:
	var found: Array = []
	_processing_in(root, found)
	var order: Dictionary = {}
	for n: int in found.size():
		order[found[n]] = n
	found.sort_custom(func(a: Node, b: Node) -> bool:
		if a.process_priority != b.process_priority:
			return a.process_priority < b.process_priority
		return int(order[a]) < int(order[b]))
	for node: Node in found:
		node.set_process(false)
	return found


func _processing_in(node: Node, found: Array) -> void:
	if node != self and node.is_processing() and node.get_script() != null:
		for method: Dictionary in (node.get_script() as Script).get_script_method_list():
			if method["name"] == "_process":
				found.append(node)
				break
	for child: Node in node.get_children():
		_processing_in(child, found)


func _give_back(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.set_process(true)


## With everything selected: the pieces of a selection's handlers, and of
## the page's state the web build writes twice a second, each timed alone.
func _sections(row: Dictionary) -> void:
	var shell: Node = _main.get("_shell")
	var assemblies: Assemblies = shell.get("assemblies") if shell != null else null
	var outline: SelectionOutline = _main.get("_outline")
	var parts: Dictionary = {
		"outline.show_selection": func() -> void: outline.show_selection(_builder.selection),
		"main._tell_bin_selection": func() -> void: _main.call("_tell_bin_selection"),
		"world.drawn_as": func() -> void: _world.drawn_as(_builder.selection),
		"page: assemblies.parts_by_path": func() -> void:
			if assemblies != null:
				assemblies.parts_by_path(),
		"page: assemblies.own_bounds": func() -> void:
			if assemblies != null:
				assemblies.own_bounds(),
		"page: builder.joint_sites": func() -> void: _builder.joint_sites(),
		"page: main._part_ids_now": func() -> void: _main.call("_part_ids_now"),
		"page: steps.page_state": func() -> void: _steps.page_state(),
		"page: Working.page_state": func() -> void: Working.page_state(),
		"main._model_bounds": func() -> void: _main.call("_model_bounds"),
		"world.model_bounds": func() -> void: _world.model_bounds(),
		"world._flush (all dirty)": func() -> void: _world._flush(),
	}
	var out: Dictionary = {}
	for name: String in parts:
		var t0: int = Time.get_ticks_usec()
		(parts[name] as Callable).call()
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		out[name] = snappedf(ms, 0.01)
		print("        section %8.2f ms  %s" % [ms, name])
	row["sections"] = out
	await _quiet()


## After the move: the pieces of what an edit of everything costs, each
## timed alone (Main._on_model_edited and the undo's own work).
func _edit_sections(row: Dictionary) -> void:
	var shell: Node = _main.get("_shell")
	var assemblies: Assemblies = shell.get("assemblies") if shell != null else null
	var step: Dictionary = _builder.last_step()
	var parts: Dictionary = {
		"builder.touched_groups": func() -> void: _builder.touched_groups(step),
		"assemblies.copies_follow": func() -> void:
			if assemblies != null:
				assemblies.copies_follow(_builder.touched_groups(step)),
		"assemblies.paths": func() -> void:
			if assemblies != null:
				assemblies.paths(),
		"assemblies.tree": func() -> void:
			if assemblies != null:
				assemblies.tree(),
		"main._model_bounds": func() -> void: _main.call("_model_bounds"),
		"builder._living_selection": func() -> void: _builder._living_selection(),
		# An undo's work a part at a time, on everything selected, each piece
		# alone: where each part's cover is worked out, the lattice let go of
		# and taken again, and the world told (in place: nothing moves).
		"undo piece: builder.boxes_for": func() -> void:
			for brick_id: int in _builder.selection:
				var brick: BrickWorld.Brick = _world.get_brick(brick_id)
				if brick != null:
					_builder.boxes_for(_builder.library.mesh_for(brick.part_id), brick.transform),
		"undo piece: lattice release and occupy": func() -> void:
			for brick_id: int in _builder.selection:
				var boxes: PackedInt32Array = _builder.lattice.boxes_of(brick_id)
				_builder.lattice.release(brick_id)
				_builder.lattice.occupy_boxes(brick_id, boxes),
		"undo piece: world.move_brick": func() -> void:
			for brick_id: int in _builder.selection:
				var brick: BrickWorld.Brick = _world.get_brick(brick_id)
				if brick != null:
					_world.move_brick(brick_id, brick.transform),
		"undo piece: world._flush": func() -> void: _world._flush(),
		"lattice piece: _bound_of": func() -> void:
			for brick_id: int in _builder.selection:
				BrickLattice._bound_of(_builder.lattice.boxes_of(brick_id)),
		"lattice piece: _rows_of": func() -> void:
			for brick_id: int in _builder.selection:
				var boxes: PackedInt32Array = _builder.lattice.boxes_of(brick_id)
				if boxes.size() > BrickLattice.ROWS_FROM * 6:
					BrickLattice._rows_of(boxes, BrickLattice._bound_of(boxes)),
		"lattice piece: _near": func() -> void:
			for brick_id: int in _builder.selection:
				_builder.lattice._near(_builder.lattice.boxes_of(brick_id)),
		"lattice piece: release alone, then occupy alone": func() -> void:
			var kept: Dictionary = {}
			var t0: int = Time.get_ticks_usec()
			for brick_id: int in _builder.selection:
				kept[brick_id] = _builder.lattice.boxes_of(brick_id)
				_builder.lattice.release(brick_id)
			var t1: int = Time.get_ticks_usec()
			var met: int = 0
			for brick_id: int in kept:
				if _builder.lattice.collides_boxes(kept[brick_id]):
					met += 1
			var t2: int = Time.get_ticks_usec()
			for brick_id: int in kept:
				_builder.lattice.occupy_boxes(brick_id, kept[brick_id])
			var t3: int = Time.get_ticks_usec()
			var boxes: int = 0
			for brick_id: int in kept:
				boxes += (kept[brick_id] as PackedInt32Array).size() / 6
			print("        release %.1f ms, collides_boxes %.1f ms (%d met), occupy %.1f ms; %d boxes"
				% [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, met, (t3 - t2) / 1000.0, boxes]),
	}
	var out: Dictionary = {}
	for name: String in parts:
		var t0: int = Time.get_ticks_usec()
		(parts[name] as Callable).call()
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		out[name] = snappedf(ms, 0.01)
		print("        section %8.2f ms  %s" % [ms, name])
	if assemblies != null:
		print("        %d assembly paths" % assemblies.paths().size())
		var t0: int = Time.get_ticks_usec()
		var unlike: Array = assemblies.unlike_copies(_builder.touched_groups(step))
		print("        %d pairs of copies not alike after the move (%.1f ms to find)"
			% [unlike.size(), (Time.get_ticks_usec() - t0) / 1000.0])
	print("        the move's undo step: %d changes for %d selected"
		% [_builder.next_change_size(), _builder.selection.size()])
	var t1: int = Time.get_ticks_usec()
	_builder.move_selection(Vector3i(10, 0, 0))
	var t2: int = Time.get_ticks_usec()
	_builder.move_selection(Vector3i(-10, 0, 0))
	print("        builder.move_selection alone: %.1f ms, and back %.1f ms"
		% [(t2 - t1) / 1000.0, (Time.get_ticks_usec() - t2) / 1000.0])
	# The undo and redo of that, the builder's own work, then the world's
	# drawing of it, then Main's after an edit.
	var t3: int = Time.get_ticks_usec()
	_builder.undo()
	var t4: int = Time.get_ticks_usec()
	_world._flush()
	var t5: int = Time.get_ticks_usec()
	_main.call("_on_model_edited")
	var t6: int = Time.get_ticks_usec()
	_builder.redo()
	var t7: int = Time.get_ticks_usec()
	print("        builder.undo alone %.1f ms, world._flush %.1f ms, main._on_model_edited %.1f ms;"
		% [(t4 - t3) / 1000.0, (t5 - t4) / 1000.0, (t6 - t5) / 1000.0]
		+ " builder.redo alone %.1f ms" % ((t7 - t6) / 1000.0))
	row["edit_sections"] = out
	await _quiet()


# -- input, as a person makes it ------------------------------------------


func _press(which: int, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which as MouseButton
	event.pressed = down
	if down:
		event.button_mask = MOUSE_BUTTON_MASK_RIGHT if which == MOUSE_BUTTON_RIGHT \
			else MOUSE_BUTTON_MASK_LEFT
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)


func _move(at: Vector2, by: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = by
	event.button_mask = mask
	Input.parse_input_event(event)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		event.meta_pressed = command and OS.get_name() == "macOS"
		Input.parse_input_event(event)
