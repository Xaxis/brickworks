## Each brief designed twice, side by side, and the better one kept.
##
## How a design reads depends more on the session's own draw than on any
## change made so far to how designs are made, and [DesignPick], shown two
## designs of one brief, named the one that did better against the real set
## in 15 of 18 asks where they differed (docs/DESIGN_SCORES.md, "Best of
## two"). So where the app runs the designer on the person's subscription (My
## Claude in the panel), a new design is made twice at once: the person's own
## session in this app, which they watch build, and a second, started at the
## same moment, in a copy of this app with no window: its own Claude Code
## session, its own port, its own baseplate. Its pictures are drawn here
## (LeasedShots), where the window and the graphics card are. When both have
## ended, DesignPick is shown each one's corner, front and close pictures and
## the brief, and the one it keeps is the person's model. The second goes
## down in place of the first as one step of the history, so Undo brings the
## first back, and the steps before it are as they were.
##
## Side by side, so the wait is about one design's: once the first has
## ended, the second is given [constant WAIT_SHARE] of the first's time
## more, at least [constant LEAST_WAIT_S], and is then stopped. If either
## fails, the other is kept without asking; if the pick fails, the first.
##
## Only a new design of a whole model, on an empty baseplate: a change to a
## model, a selection or a sketch is one session, as it always was. And never
## a session from outside (the MCP port, the connector): that Claude is the
## person's own, and decides for itself.
class_name BestOfTwo
extends Node

## Said once the kept design stands, in place of the first session's own
## end: whether a design stands, and the kept one's summary.
signal finished(ok: bool, summary: String)
## The kept design's name, when the second is kept and named itself.
signal titled(name: String)

## What the second app is started with: the folder its files go in.
const ARGUMENT := "--second-design="
## Once the first has ended, how much more of the first's time the second
## is given. Of 13 designs of each of three subjects, the slower of two took
## 1.14 times one design (DESIGN_SCORES.md, "Best of two, step 1").
const WAIT_SHARE := 0.3
## ...and never less than this, in seconds: a first that ended early on a
## short brief is no reason to throw away a second a minute behind it.
const LEAST_WAIT_S := 90.0
## How long a second asked to stop has before it is ended.
const STOP_GRACE_S := 20.0
## The most the pick may take, in seconds. Asked on the proof's 44 pairs it
## took about 11.
const PICK_MOST_S := 180.0
## Where the second's files go: its model, how it went, its pictures'
## requests, and the six pictures the pick was shown. Only the last run's
## is kept.
const ROOT := "user://best_of/"
## How often the second is told this app is still there, and how long
## without word it waits before it stops its session and ends: an app that
## crashed must not leave a session spending somebody's subscription.
const BEAT_S := 5.0
const ORPHANED_S := 60.0

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var store: ModelStore
## The brief both were given.
var brief: String = ""
## What happened, for the window to print and a probe to read: each
## design's {ok, summary, seconds, parts}, the pick's answer, which was
## kept ("first" or "second") and how long the whole wait was.
var record: Dictionary = {}

var _dir: String = ""
var _pid: int = -1
var _port: int = -1
var _drawer: LeasedShots.Drawer = null
var _drawing: bool = false
var _started_ms: int = 0
var _first: Dictionary = {}
var _second: Dictionary = {}
var _deadline_ms: int = 0
var _stop_asked: bool = false
var _stop_asked_ms: int = 0
## Set once the second app is known to have ended: asked again, the
## system says it never had such a child.
var _gone: bool = false
var _beat_ms: int = 0
var _deciding: bool = false
var _shot: ModelShot = null
## Parts the person put down while the two were designed: theirs, and left
## standing whichever design is kept.
var _theirs: Dictionary = {}


## The second design's folder, when this app is one; "" otherwise.
static func second_of() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(ARGUMENT):
			return argument.substr(ARGUMENT.length())
	return ""


## Where a second design asks for its pictures, when this app is one.
static func shots_dir() -> String:
	var dir: String = second_of()
	return "" if dir.is_empty() else dir.path_join("shots")


## How the second app is started: this app again, as New window starts it
## (TabSession.window_arguments), but with no window, designing [param text]
## on [param port] as a run from the command line does (--ask-claude-code),
## its model and its saves in [param dir].
static func arguments(text: String, port: int, dir: String) -> PackedStringArray:
	var words := PackedStringArray()
	if not OS.has_feature("template"):
		words.append_array(["--path", ProjectSettings.globalize_path("res://")])
	words.append_array(["--headless", "--log-file", dir.path_join("app.log"), "--",
		"--mcp=%d" % port, "--ask-claude-code=" + text,
		"--out=" + dir.path_join("second.ldr"), ARGUMENT + dir])
	return words


## Start the second beside [param first], which is already designing
## [param text] in this app. False, having started nothing, when it cannot:
## then the first goes on alone and says its own end.
func start(text: String, first: ClaudeCode, after_port: int) -> bool:
	if Assistant.BEST_OF < 2 or OS.has_feature("web") or ClaudeCode.found().is_empty():
		return false
	brief = text
	_dir = _fresh_dir()
	if _dir.is_empty():
		return false
	_port = _free_port(after_port + 1)
	if _port < 0:
		return false
	_beat()
	_pid = OS.create_process(OS.get_executable_path(), arguments(text, _port, _dir))
	if _pid <= 0:
		push_warning("best of two: could not start a second design")
		return false
	_started_ms = Time.get_ticks_msec()
	_drawer = LeasedShots.Drawer.new()
	_drawer.library = library
	_drawer.parent = self
	first.finished.connect(_first_ended, CONNECT_ONE_SHOT)
	builder.placed.connect(func(id: int, _part: String) -> void: _theirs[id] = true)
	print("best of two: a second design started on port %d, in %s" % [_port, _dir])
	return true


## Whether the second app is still running.
func second_running() -> bool:
	if _pid <= 0 or _gone:
		return false
	_gone = not OS.is_process_running(_pid)
	return not _gone


func _process(_delta: float) -> void:
	if _dir.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - _beat_ms > int(BEAT_S * 1000.0):
		_beat()
	if not _drawing and _second.is_empty():
		var asked: String = LeasedShots.Drawer.next(_dir.path_join("shots"))
		if not asked.is_empty():
			_draw(asked)
	if not _second.is_empty():
		return
	if not second_running():
		_second_ended()
	elif _deadline_ms > 0 and now > _deadline_ms:
		if not _stop_asked:
			_stop_asked = true
			_stop_asked_ms = now
			_ask_to_stop()
		elif now - _stop_asked_ms > int(STOP_GRACE_S * 1000.0):
			_end_second()


## Nothing of the second left running when the app closes.
func _exit_tree() -> void:
	stop()


## Stop the second, if it runs: asked first, so it stops its own session,
## and ended if it does not.
func stop() -> void:
	if not second_running():
		return
	_ask_to_stop()
	var until: int = Time.get_ticks_msec() + 3000
	while second_running() and Time.get_ticks_msec() < until:
		OS.delay_msec(50)
	if second_running():
		_end_second()


## End the second that did not stop when asked, and its session first: the
## session is the second's child, and ending the second alone would leave it
## running on the person's subscription.
func _end_second() -> void:
	var session: int = FileAccess.get_file_as_string(_dir.path_join("session.pid")).to_int()
	if session > 0:
		OS.kill(session)
	OS.kill(_pid)
	_gone = true


func _draw(asked: String) -> void:
	_drawing = true
	await _drawer.answer(_dir.path_join("shots"), asked)
	_drawing = false


func _first_ended(ok: bool, summary: String) -> void:
	var seconds: float = (Time.get_ticks_msec() - _started_ms) / 1000.0
	_first = {"ok": ok, "summary": summary, "seconds": seconds, "parts": _parts()}
	record["first"] = _first
	_deadline_ms = Time.get_ticks_msec() + int(maxf(LEAST_WAIT_S, seconds * WAIT_SHARE) * 1000.0)
	_maybe_decide()


func _second_ended() -> void:
	var written: String = FileAccess.get_file_as_string(_dir.path_join("result.json"))
	var said: Variant = JSON.parse_string(written) if not written.is_empty() else null
	var result: Dictionary = said if said is Dictionary else {}
	_second = {"ok": bool(result.get("ok", false)) and not _stop_asked,
		"summary": str(result.get("summary", "")), "title": str(result.get("title", "")),
		"seconds": (Time.get_ticks_msec() - _started_ms) / 1000.0,
		"parts": int(result.get("parts", 0)), "stopped": _stop_asked}
	record["second"] = _second
	_maybe_decide()


func _maybe_decide() -> void:
	if _first.is_empty() or _second.is_empty() or _deciding:
		return
	_deciding = true
	_decide()


func _decide() -> void:
	var text: String = FileAccess.get_file_as_string(_dir.path_join("second.ldr"))
	var first_stands: bool = bool(_first["ok"]) and int(_first["parts"]) > 0
	var second_stands: bool = bool(_second["ok"]) and not _placements(text).is_empty()
	var keep_second: bool = false
	if first_stands and second_stands:
		var pick: Dictionary = await _pick(text)
		record["pick"] = pick
		keep_second = str(pick.get("keep", "")) == "B"
	elif second_stands:
		keep_second = true
	if keep_second and not _put_down(text):
		keep_second = false
	record["kept"] = "second" if keep_second else "first"
	record["seconds"] = (Time.get_ticks_msec() - _started_ms) / 1000.0
	_write_record()
	var pick: Dictionary = record.get("pick", {})
	print("best of two: kept the %s design in %.0f s; the first %s in %.0f s, the second %s in %.0f s%s"
		% [record["kept"], record["seconds"], "stood" if first_stands else "did not stand",
			_first["seconds"], "stood" if second_stands else "did not stand",
			_second["seconds"], "" if pick.is_empty() else "; the pick: %s %s" % [
				pick.get("keep", "no answer"), pick.get("why", pick.get("error", ""))]])
	if _drawer != null:
		_drawer.clear()
	if keep_second:
		if not str(_second["title"]).is_empty():
			titled.emit(str(_second["title"]))
		finished.emit(true, str(_second["summary"]))
	else:
		finished.emit(bool(_first["ok"]), str(_first["summary"]))
	queue_free()


## DesignPick, asked once, the first shown as A: the order it is shown them in
## did not lean its answer (it kept the first shown in 41 of 88 asks).
func _pick(text: String) -> Dictionary:
	var a: Array = await _views(world, store.scenery, "first")
	var shown := BrickWorld.new()
	shown.library = library
	shown.keeps_history = false
	shown.visible = false
	add_child(shown)
	shown.hold_drawing()
	for item: Dictionary in _placements(text):
		shown.add_brick(str(item["part"]), int(item["color"]), item["at"])
	var b: Array = await _views(shown, {}, "second")
	shown.queue_free()
	if a.size() < DesignPick.VIEWS.size() or b.size() < DesignPick.VIEWS.size():
		return {"error": "no pictures to choose by"}
	var picker := DesignPick.new()
	var thread := Thread.new()
	thread.start(picker.ask.bind(brief, a, b))
	var until: int = Time.get_ticks_msec() + int(PICK_MOST_S * 1000.0)
	while thread.is_alive():
		if Time.get_ticks_msec() > until:
			picker.stop()
		await get_tree().process_frame
	var answer: Variant = thread.wait_to_finish()
	return answer if answer is Dictionary else {"error": "no answer"}


## The pictures the pick is shown (DesignPick.pictures), kept in this run's
## folder and handed back as content blocks.
func _views(of: BrickWorld, skip: Dictionary, name: String) -> Array:
	if _shot == null:
		_shot = ModelShot.new()
		_shot.library = library
		_shot.give_up_after = 120.0
		add_child(_shot)
	var images: Array[Image] = await DesignPick.pictures(_shot, of, skip, library)
	var blocks: Array = []
	for n: int in images.size():
		var path: String = _dir.path_join("%s_%s.png" % [name, DesignPick.VIEWS[n]])
		images[n].save_png(path)
		blocks.append(DesignPick.picture(path))
	return blocks


## The second's parts, read from its file as Open reads one: {part, color,
## at, path, step}, where the first's stood. Empty when the file has none, or
## a part whose shape this app cannot draw, so a second is put down whole or
## not at all.
func _placements(text: String) -> Array:
	if text.is_empty():
		return []
	var model: LdrModel = LdrModel.parse(text, "second")
	if model == null:
		return []
	CustomParts.take_from(library, model)
	var placed: Array = []
	for placement: LdrModel.Placement in model.flatten(library.parts):
		if library.mesh_for(placement.part_id) == null:
			return []
		placed.append(placement)
	if placed.is_empty():
		return []
	var up: Vector3 = store.lift_for(placed)
	var items: Array = []
	for placement: LdrModel.Placement in placed:
		var at: Transform3D = placement.transform
		at.origin += up
		items.append({"part": placement.part_id, "color": placement.color_code, "at": at,
			"path": placement.unit, "step": placement.step})
	return items


## The second in place of the first, as one step of the history: Undo puts
## the first back, and every step before it stays as it was. What the
## person put down meanwhile stays where they put it.
func _put_down(text: String) -> bool:
	var items: Array = _placements(text)
	if items.is_empty():
		return false
	var first := PackedInt64Array()
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id) and not _theirs.has(brick.id):
			first.append(brick.id)
	builder.clear_selection()
	var steps: Array = builder.swap_bricks(first, items)
	builder.record(steps, "Claude's design (%s)" % SelectionScope.words_for(steps))
	if ClaudeStep.lays({"steps": steps}):
		store.laid_by("assistant")
	return true


func _parts() -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id):
			count += 1
	return count


## A folder for this run, the last run's taken away first.
func _fresh_dir() -> String:
	var root: String = ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(root):
		for old: String in DirAccess.get_directories_at(root):
			_remove(root.path_join(old))
	var dir: String = root.path_join("%d" % int(Time.get_unix_time_from_system()))
	if DirAccess.make_dir_recursive_absolute(dir.path_join("shots")) != OK:
		return ""
	return dir


static func _remove(dir: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


## The first port after [param from] nothing listens on.
static func _free_port(from: int) -> int:
	for port: int in range(from, from + 64):
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return -1


func _beat() -> void:
	_beat_ms = Time.get_ticks_msec()
	var file: FileAccess = FileAccess.open(_dir.path_join("beat"), FileAccess.WRITE)
	if file != null:
		file.store_string(str(Time.get_unix_time_from_system()))
		file.close()


func _ask_to_stop() -> void:
	var file: FileAccess = FileAccess.open(_dir.path_join("stop"), FileAccess.WRITE)
	if file != null:
		file.close()


func _write_record() -> void:
	var file: FileAccess = FileAccess.open(_dir.path_join("record.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(record, " "))
		file.close()


# -- in the second app ----------------------------------------------------


## In the second app: stop [param session] when the app that started it
## asks, or has not said it is there for [constant ORPHANED_S].
static func watch_from_second(owner: Node, session: ClaudeCode,
		dir: String = second_of()) -> void:
	var pid: FileAccess = FileAccess.open(dir.path_join("session.pid"), FileAccess.WRITE)
	if pid != null:
		pid.store_string(str(session._pid))
		pid.close()
	var clock := Timer.new()
	clock.wait_time = 2.0
	clock.autostart = true
	clock.timeout.connect(func() -> void:
		var beat: int = FileAccess.get_modified_time(dir.path_join("beat"))
		var gone: bool = beat > 0 and Time.get_unix_time_from_system() - beat > ORPHANED_S
		if (FileAccess.file_exists(dir.path_join("stop")) or gone) and session.busy():
			print("best of two: stopping the second design (%s)" % (
				"asked to" if not gone else "the app that started it has gone"))
			session.stop())
	owner.add_child(clock)


## In the second app, once its session has ended: how it went, for the app
## that started it.
static func say_how_it_went(ok: bool, summary: String, parts: int, title: String) -> void:
	var file: FileAccess = FileAccess.open(second_of().path_join("result.json"),
		FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"ok": ok, "summary": summary, "parts": parts,
			"title": title}))
		file.close()
