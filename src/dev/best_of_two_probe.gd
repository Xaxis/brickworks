## Is a brief designed twice kept whole, the person's undo with it?
##
##   godot --headless --path . --script src/dev/best_of_two_probe.gd
##
## BestOfTwo (src/ai/best_of_two.gd) runs a second design beside the
## person's and keeps the one DesignPick prefers. Everything here but the
## two sessions and the pick, which spend the subscription: those are
## best_of_two_walk_probe's. Checked: how the second app is started (no
## window, its own port and folder, nothing of this run's own); which is
## kept when both stand, when one fails or is stopped, and when the pick
## fails; the second put down in place of the first as one step, so Undo
## brings the first back and the steps before it are as they were; and the
## panel's card closed by the pair's end, not the first session's.
extends SceneTree


## The pick's answer given, not asked.
## A session that is busy until it is stopped, and says so.
class Stoppable extends ClaudeCode:
	var stopped: int = 0

	func busy() -> bool:
		return stopped == 0

	func stop() -> void:
		stopped += 1


class Picked extends BestOfTwo:
	var answer: Dictionary = {}
	var asked: int = 0

	func _pick(_text: String) -> Dictionary:
		asked += 1
		return answer


var _failures: int = 0
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("best_of_two probe: no catalogue")
		quit(1)
		return

	print("how the second design is started")
	var dir: String = OS.get_user_data_dir().path_join("best_of_two_probe")
	var words: PackedStringArray = BestOfTwo.arguments("a red lighthouse", 8952, dir)
	var line: String = " ".join(words)
	_check(words.has("--headless"), "with no window: %s" % line)
	var user: PackedStringArray = words.slice(words.find("--") + 1)
	_check(user.has("--mcp=8952") and user.has("--ask-claude-code=a red lighthouse")
		and user.has("--out=" + dir.path_join("second.ldr"))
		and user.has(BestOfTwo.ARGUMENT + dir),
		"on its own port, designing the same brief, its model in its own folder")
	_check(not words.has("--script") and not line.contains(".gd"),
		"none of this run's own switches")
	_check(words.has("--path") == not OS.has_feature("template"),
		"from this project when it runs from source")
	_check(Assistant.BEST_OF == 2, "made twice by default (Assistant.BEST_OF %d)"
		% Assistant.BEST_OF)

	print("")
	print("which is kept")
	var second_text: String = _second_model()
	_check(not second_text.is_empty(), "a second design's file to put down")
	var cases: Array = [
		["both stand, the pick keeps B", true, true, false, {"keep": "B", "why": "x"},
			"second", 1],
		["both stand, the pick keeps A", true, true, false, {"keep": "A", "why": "x"},
			"first", 1],
		["both stand, the pick fails", true, true, false, {"error": "no answer"},
			"first", 1],
		["the first fails", false, true, false, {}, "second", 0],
		["the second fails", true, false, false, {}, "first", 0],
		["the second is stopped at its time", true, true, true, {}, "first", 0],
		["both fail", false, false, false, {}, "first", 0],
	]
	for case: Array in cases:
		var made: Dictionary = await _decided(second_text, case[1], case[2], case[3], case[4])
		_check(made["kept"] == case[5] and made["asked"] == case[6],
			"%s: the %s kept, asked %d time%s (%s, %d)" % [case[0], case[5], case[6],
				"" if case[6] == 1 else "s", made["kept"], made["asked"]])
		_check(made["summary"] == ("second's summary" if case[5] == "second"
			else "first's summary") and made["ok"] == (case[5] == "second" or case[1]),
			"...and its own end said: %s, %s" % [made["ok"], made["summary"]])
		_check(made["parts"] == (made["second_parts"] if case[5] == "second"
			else made["first_parts"]), "...and its parts on the baseplate (%d)" % made["parts"])

	print("")
	print("the second in place of the first, and the undo")
	await _undo_check(second_text)

	print("")
	print("the wait")
	var timed := Picked.new()
	timed.world = _world()
	timed.store = _store(timed.world, null)
	timed._started_ms = Time.get_ticks_msec() - 600000
	timed._second = {"pending": true}
	timed._deciding = true
	timed._first_ended(true, "")
	var given: float = (timed._deadline_ms - Time.get_ticks_msec()) / 1000.0
	_check(absf(given - 180.0) < 2.0,
		"a first of 10 minutes gives the second 3 minutes more (%.0f s)" % given)
	timed._started_ms = Time.get_ticks_msec() - 60000
	timed._first_ended(true, "")
	given = (timed._deadline_ms - Time.get_ticks_msec()) / 1000.0
	_check(absf(given - BestOfTwo.LEAST_WAIT_S) < 2.0,
		"a first of one minute gives it %.0f s, not 18" % given)
	timed.world.queue_free()
	timed.free()

	print("")
	print("a second that runs too long")
	await _stop_check()

	print("")
	print("the panel's card")
	await _panel_check()

	print("")
	if _failures == 0:
		print("best_of_two probe: all passed")
	else:
		print("best_of_two probe: %d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


## A two-part design in a world of its own, written as the second app
## writes its --out (ModelStore.export_to).
func _second_model() -> String:
	var world := _world()
	var store := _store(world, null)
	world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	world.add_brick("3003", 14, Transform3D(Basis.IDENTITY, Vector3(40, 48, 0)))
	world.add_brick("3062b", 1, Transform3D(Basis.IDENTITY, Vector3(0, 72, 0)))
	var text: String = store.to_text("Model", true)
	world.queue_free()
	return text


## One pair decided, the first's parts built as a session's calls build them
## (a step a call), the second's file in the run's folder.
func _decided(text: String, first_ok: bool, second_ok: bool, stopped: bool,
		answer: Dictionary) -> Dictionary:
	var world := _world()
	var builder := _builder(world)
	var store := _store(world, builder)
	_first_parts(builder)
	var pair := Picked.new()
	pair.world = world
	pair.builder = builder
	pair.library = _library
	pair.store = store
	pair.answer = answer
	pair._dir = OS.get_user_data_dir().path_join("best_of_two_probe")
	DirAccess.make_dir_recursive_absolute(pair._dir)
	var file: FileAccess = FileAccess.open(pair._dir.path_join("second.ldr"), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	get_root().add_child(pair)
	pair._first = {"ok": first_ok, "summary": "first's summary", "seconds": 100.0,
		"parts": pair._parts() if first_ok else 0}
	pair._second = {"ok": second_ok and not stopped, "summary": "second's summary",
		"title": "", "seconds": 110.0, "parts": 3, "stopped": stopped}
	var ended: Array = []
	pair.finished.connect(func(ok: bool, summary: String) -> void: ended.append([ok, summary]))
	var first_parts: int = pair._parts()
	pair._deciding = true
	await pair._decide()
	var made: Dictionary = {"kept": pair.record.get("kept", ""), "asked": pair.asked,
		"ok": ended[0][0] if not ended.is_empty() else null,
		"summary": ended[0][1] if not ended.is_empty() else "",
		"parts": world.brick_count() - store.scenery.size(),
		"first_parts": first_parts, "second_parts": 3}
	world.queue_free()
	builder.queue_free()
	return made


## The first design's parts, each its own step as a session's calls are.
func _first_parts(builder: Builder) -> void:
	for at: Vector3 in [Vector3(0, 24, 0), Vector3(0, 48, 0)]:
		var steps: Array = builder.swap_bricks(PackedInt64Array(), [{"part": "3001",
			"color": 1, "at": Transform3D(Basis.IDENTITY, at)}])
		builder.record(steps, "a call")


func _undo_check(text: String) -> void:
	var world := _world()
	var builder := _builder(world)
	var store := _store(world, builder)
	# The person's own part first, then the first design's two calls.
	var theirs: Array = builder.swap_bricks(PackedInt64Array(), [{"part": "3005",
		"color": 15, "at": Transform3D(Basis.IDENTITY, Vector3(200, 24, 200))}])
	builder.record(theirs, "theirs")
	_first_parts(builder)
	var first: Dictionary = _parts_of(world, store)
	var depth: int = builder.history_depth()
	var pair := Picked.new()
	pair.world = world
	pair.builder = builder
	pair.library = _library
	pair.store = store
	get_root().add_child(pair)
	# And one more of theirs while the two were designed (Builder.placed).
	var during: Array = builder.swap_bricks(PackedInt64Array(), [{"part": "3004",
		"color": 2, "at": Transform3D(Basis.IDENTITY, Vector3(-200, 24, -200))}])
	builder.record(during, "theirs, meanwhile")
	pair._theirs[int(during[0]["brick"])] = true
	first = _parts_of(world, store)
	depth = builder.history_depth()
	_check(pair._put_down(text), "the second put down")
	var second: Dictionary = _parts_of(world, store)
	_check(second.size() == 4 and second.has("3001|4|0,24,0") and second.has("3003|14|40,48,0")
		and second.has("3062b|1|0,72,0"),
		"...whole and where it stood in its own app: %s" % str(second.keys()))
	_check(second.has("3004|2|-200,24,-200"), "...and the part the person put down meanwhile stays")
	_check(builder.history_depth() == depth + 1, "...as one step (%d, was %d)"
		% [builder.history_depth(), depth])
	builder.undo()
	_check(_parts_of(world, store) == first, "Undo brings the first back, the person's part with it")
	builder.redo()
	_check(_parts_of(world, store) == second, "Redo puts the second down again")
	for _n: int in 4:
		builder.undo()
	var before: Dictionary = _parts_of(world, store)
	_check(before.size() == 1 and before.has("3005|15|200,24,200"),
		"and the steps before it undo as they were, to the person's own part: %s"
		% str(before.keys()))
	pair.queue_free()
	world.queue_free()
	builder.queue_free()


func _stop_check() -> void:
	var dir: String = OS.get_user_data_dir().path_join("best_of_two_stop")
	DirAccess.make_dir_recursive_absolute(dir)
	# In the second: its session stopped when asked, and when the app that
	# started it has said nothing for a minute.
	var holder := Node.new()
	get_root().add_child(holder)
	var session := Stoppable.new()
	session._pid = 4242
	BestOfTwo.watch_from_second(holder, session, dir)
	_check(FileAccess.get_file_as_string(dir.path_join("session.pid")) == "4242",
		"the second says which process its session is")
	var beat: FileAccess = FileAccess.open(dir.path_join("beat"), FileAccess.WRITE)
	beat.store_string("now")
	beat.close()
	await create_timer(2.5).timeout
	_check(session.stopped == 0, "a second told the app is there goes on")
	FileAccess.open(dir.path_join("stop"), FileAccess.WRITE).close()
	await create_timer(2.5).timeout
	_check(session.stopped == 1, "...and stops its session when asked")
	DirAccess.remove_absolute(dir.path_join("stop"))
	var quiet := Stoppable.new()
	BestOfTwo.watch_from_second(holder, quiet, dir)
	OS.execute("touch", ["-d", "2 minutes ago", dir.path_join("beat")])
	await create_timer(2.5).timeout
	_check(quiet.stopped == 1, "...and when the app that started it has been quiet a minute")
	holder.free()
	session.free()
	quiet.free()

	# In the app: past its time and its grace, the second and its session
	# are ended, the session first, and it is not kept.
	var pair := Picked.new()
	pair.world = _world()
	pair.store = _store(pair.world, null)
	pair._dir = dir
	var child: int = OS.create_process("sleep", ["300"])
	var grandchild: int = OS.create_process("sleep", ["300"])
	var file: FileAccess = FileAccess.open(dir.path_join("session.pid"), FileAccess.WRITE)
	file.store_string(str(grandchild))
	file.close()
	pair._pid = child
	pair._first = {"ok": true, "summary": "", "seconds": 100.0, "parts": 1}
	pair._deciding = true
	pair._deadline_ms = Time.get_ticks_msec() - 1
	pair._process(0.0)
	_check(pair._stop_asked_ms > 0 and FileAccess.file_exists(dir.path_join("stop")),
		"past its time, the second is asked to stop")
	pair._stop_asked_ms = Time.get_ticks_msec() - int(BestOfTwo.STOP_GRACE_S * 1000.0) - 1
	pair._process(0.0)
	await create_timer(0.5).timeout
	_check(not DirAccess.dir_exists_absolute("/proc/%d" % child)
		or FileAccess.get_file_as_string("/proc/%d/stat" % child).contains(") Z"),
		"past its grace, it is ended")
	_check(not DirAccess.dir_exists_absolute("/proc/%d" % grandchild)
		or FileAccess.get_file_as_string("/proc/%d/stat" % grandchild).contains(") Z"),
		"...and its session with it")
	pair._process(0.0)
	_check(not pair._second.is_empty() and not bool(pair._second["ok"])
		and bool(pair._second["stopped"]), "...and what it built is not kept: %s" % str(pair._second))
	pair.world.queue_free()
	pair.free()


func _panel_check() -> void:
	var panel := ChatPanel.new()
	get_root().add_child(panel)
	await process_frame
	var session := ClaudeCode.new()
	get_root().add_child(session)
	var pair := BestOfTwo.new()
	get_root().add_child(pair)
	panel._working = true
	panel.follow(session, pair.finished)
	session.finished.emit(true, "the first")
	_check(panel._working, "the first session's end does not close the card")
	pair.finished.emit(true, "the kept one")
	_check(not panel._working, "the pair's end does")
	# The next request, a change, is one session again.
	panel._working = true
	panel.follow(session)
	session.finished.emit(true, "a change")
	_check(not panel._working, "a later request's own session closes its card")
	pair.free()
	session.free()
	panel.free()


func _world() -> BrickWorld:
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	return world


func _builder(world: BrickWorld) -> Builder:
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	return builder


func _store(world: BrickWorld, builder: Builder) -> ModelStore:
	var store := ModelStore.new()
	store.world = world
	store.library = _library
	store.builder = builder
	store.keeps = false
	return store


## Every part standing that is not scenery, as part|colour|where.
func _parts_of(world: BrickWorld, store: ModelStore) -> Dictionary:
	var found: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if store.scenery.has(brick.id):
			continue
		var at: Vector3 = brick.transform.origin
		found["%s|%d|%d,%d,%d" % [brick.part_id, brick.color_code, roundi(at.x),
			roundi(at.y), roundi(at.z)]] = true
	return found


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
