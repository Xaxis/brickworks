## GrabDrag's own work in each frame after a model opens, while it stands
## still, and while a part on a joint is dragged, and what a press during
## the reading of its joints takes hold of.
##
##   godot --path . --resolution 1400x900 --script src/dev/grabtake_probe.gd \
##       [-- --models=orthanc,6660-1,10176-1]
##
## After a model opens, GrabDrag reads its joints on a worker from copies of
## the model and its lattice. Up to grabtake those copies were made in one
## frame (97 ms on Orthanc's 10,119 parts) and freed, with the reading they
## replaced, in the frame the reading was taken in, wherever the worker
## ended (40-75 ms): a hitch seconds after the model opened (simple3,
## 2026-11-27). Each frame's GrabDrag._process is timed between two nodes
## that process just before and just after it, so the probe times a
## checkout from before grabtake the same way.
##
## For each model: opened, read and left standing; a press on a part on a
## joint while its joints are read again (read_again), and one after; then
## that part dragged and let go, and the model read again after the change.
## Checked: no frame of GrabDrag's own over BAR_MS from the open to the end;
## a press during the reading takes hold of the same parts as one after it,
## or says the joints are being read, as a big model's press does; the
## press and each move of the drag under BAR_MS. Said, not judged: the
## frame the drag is kept in (an edit, the same either way), the status
## bar's weighing (Main._weigh, its own copies), and what copying and
## freeing a model whole costs here (the pieces other readers pay).
extends SceneTree

const MODELS := {
	"orthanc": "res://models/orthanc.ldr",
	"6660-1": "res://vendor/omr/files/6660-1.mpd",
	"10176-1": "res://vendor/omr/files/10176-1.mpd",
}
## No frame of GrabDrag's own over this, ms.
const BAR_MS := 16.0
## Frames over this are listed, ms.
const LIST_MS := 8.0
## A reading waited for at most this long, ms.
const WAIT_MS := 180000
## GrabDrag's turn in the frame, and the two that time it.
const TURN := 555555


class Mark extends Node:
	var marks: Array
	var slot: int

	func _process(_delta: float) -> void:
		marks[slot] = Time.get_ticks_usec()
		if slot == 1:
			marks[2] = Engine.get_process_frames()


var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _grab: GrabDrag
var _store: ModelStore
## [before, after, the frame], usec, by the two Marks.
var _marks: Array = [0, 0, -1]
var _phase: String = ""
## Phase -> [frames, worst ms, its frame and state, over LIST_MS, over BAR_MS, listed lines].
var _seen: Dictionary = {}
## Per phase: frames, the whole frame's longest processing, frames over the bar.
var _whole: Dictionary = {}
var _weigh_worst: float = 0.0
var _weigh_frame: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	var names: Array = MODELS.keys()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--models="):
			names = Array(arg.trim_prefix("--models=").split(",", false))
	print("  %s, %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name()])
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(90)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_grab = _main.get("_grab_drag")
	_store = _main.get("_store")
	if _grab == null:
		_check("the app has its GrabDrag", false)
		_finish()
		return
	_grab.process_priority = TURN
	for slot: int in 2:
		var mark := Mark.new()
		mark.marks = _marks
		mark.slot = slot
		mark.process_priority = TURN - 1 if slot == 0 else TURN + 1
		root.add_child(mark)
	process_frame.connect(_on_frame)
	for name: String in names:
		if not MODELS.has(name):
			_check("%s is a model this probe knows" % name, false)
			continue
		await _model(name, MODELS[name])
	_finish()


## The frame before this one: GrabDrag's own work, and the weighing's.
func _on_frame() -> void:
	if _phase.is_empty():
		return
	# The whole frame's processing (every node, every coroutine resumed):
	# the weighing's copy and free resume in it, outside GrabDrag's own.
	var whole: Array = _whole.get(_phase, [0, 0.0, 0])
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	whole[0] += 1
	whole[1] = maxf(whole[1], process_ms)
	if process_ms > BAR_MS:
		whole[2] += 1
	_whole[_phase] = whole
	if int(_marks[2]) != Engine.get_process_frames() - 1:
		return
	var ms: float = float(int(_marks[1]) - int(_marks[0])) / 1000.0
	var state: String = _state()
	var seen: Array = _seen.get(_phase, [0, 0.0, "", 0, 0, []])
	seen[0] += 1
	if ms > seen[1]:
		seen[1] = ms
		seen[2] = "frame %d %s" % [seen[0], state]
	if ms > LIST_MS:
		seen[3] += 1
		if (seen[5] as Array).size() < 12:
			seen[5].append("%.1f@%d:%s" % [ms, seen[0], state])
	if ms > BAR_MS:
		seen[4] += 1
	_seen[_phase] = seen
	var weighed: float = float(_main.get("_weighed_us")) / 1000.0
	if weighed > _weigh_worst:
		_weigh_worst = weighed
		_weigh_frame = "%s frame %d" % [_phase, seen[0]]


## What GrabDrag is doing about its reading.
func _state() -> String:
	if _grab.get("_copying") != null:
		return "copying"
	if int(_grab.get("_readying")) >= 0:
		return "reading"
	return "ready" if _grab.is_ready() else "-"


func _model(name: String, path: String) -> void:
	print("")
	print("%s:" % name)
	_seen.clear()
	_whole.clear()
	_weigh_worst = 0.0
	_weigh_frame = ""
	if _grab.get("taken_worst_ms") != null:
		_grab.set("taken_worst_ms", 0.0)
	var opened_at: int = Time.get_ticks_msec()
	_phase = "open"
	var placed: int = int(_main.call("_open", ProjectSettings.globalize_path(path)))
	_check("%s opens (%d parts)" % [name, placed], placed > 0)
	if placed <= 0:
		_phase = ""
		return
	if playback_of() != null:
		playback_of().stop()
	_camera.set_view("default")
	_camera.frame(_main.call("_built_bounds"))
	var ready_ms: int = await _until_read()
	print("    read %d ms after it opened (%d parts)" % [ready_ms - opened_at, _world.brick_count()])
	_phase = "idle"
	await _frames(90)

	# The part to take hold of: one on a joint that a press moves, or with
	# none, the first part (a press carries it; a big model's still says
	# its joints are being read while they are).
	var target: int = _target()
	var jointed: bool = target > 0
	if not jointed:
		var bricks: Array = _world.bricks()
		target = (bricks[0] as BrickWorld.Brick).id if not bricks.is_empty() else 0
		print("    no part on a joint that a press moves: pressing #%d, which it carries" % target)
	else:
		print("    the part on a joint: #%d" % target)
	if target == 0:
		_phase = ""
		_report(name)
		return

	# A press while the joints are read again: the model as it stands, read
	# afresh as after a change. A small model's copy is taken a little at a
	# time here, so the press comes while it is being made.
	var small: bool = _world.brick_count() < GrabDrag.WAITED_BELOW
	if small and _grab.get("copy_slice_us") != null:
		_grab.set("copy_slice_us", 30)
	_phase = "during"
	_grab.read_again()
	# Woken, as the input that asks it would wake it (asleep at rest, it
	# begins nothing).
	Wake.all("grabtake probe")
	var asked: int = Time.get_ticks_msec()
	while not _grab.is_reading() and Time.get_ticks_msec() - asked < 10000:
		await process_frame
	var while_state: String = _state()
	var during: Array = _press(target)
	print("    pressed while %s: %s, %s" % [while_state, during[0], during[2]])
	print("MOVING %s during %s" % [name, during[1]])
	if _grab.is_grabbing():
		_grab.cancel()
	if _grab.get("copy_slice_us") != null:
		_grab.set("copy_slice_us", 0)
	await _until_read()
	await _frames(10)
	_phase = "drag"
	var after: Array = _press(target)
	print("    pressed once read: %s, %s (%.1f ms)" % [after[0], after[2], after[3]])
	print("MOVING %s after %s" % [name, after[1]])
	if jointed:
		_check("%s: a press once read takes hold of the part on its joint" % name, after[0] == "moves")
	if small:
		_check("%s: a press while the joints are read (%s) does what one after does (%s, %s)"
			% [name, while_state, during[0], during[1]], during[0] == after[0] and during[1] == after[1])
	else:
		_check("%s: a press while the joints are read (%s) says so and holds nothing, as a big model's does"
			% [name, while_state], during[0] == "reading" and during[1] == "[]")
	_check("%s: the press took %.1f ms of its frame (under %.0f)" % [name, after[3], BAR_MS], after[3] < BAR_MS)
	if after[0] != "moves":
		_grab.cancel()
		await _frames(30)
		_phase = ""
		_report(name)
		_pieces(name)
		return
	# Dragged a little each frame, as a mouse does, then let go.
	var from: Vector2 = _camera.unproject_position(_world.get_brick(target).transform.origin)
	var worst_move: float = 0.0
	for step: int in 24:
		await process_frame
		var at: Vector2 = from + Vector2(5.0, -3.0) * float(step + 1)
		var began: int = Time.get_ticks_usec()
		_grab.motion(at)
		worst_move = maxf(worst_move, float(Time.get_ticks_usec() - began) / 1000.0)
	await _frames(8)
	var let_go: int = Time.get_ticks_usec()
	var words: String = _grab.release()
	var release_ms: float = float(Time.get_ticks_usec() - let_go) / 1000.0
	print("    moves: the worst %.1f ms; let go in %.1f ms: %s" % [worst_move, release_ms, words])
	_check("%s: each move of the drag took under %.0f ms (the worst %.1f)" % [name, BAR_MS, worst_move],
		worst_move < BAR_MS)
	# Kept, and the model read again for the next press.
	var settle_began: int = Time.get_ticks_msec()
	while (_grab.is_settling() or _grab.is_grabbing()) and Time.get_ticks_msec() - settle_began < 30000:
		await process_frame
	print("    kept in %.1f ms of its frame (an edit's)" % float(_grab.keep_ms))
	await _until_read()
	await _frames(60)
	_phase = ""
	_report(name)
	_pieces(name)


func playback_of() -> BuildPlayback:
	return _main.get("_playback")


## Frames until GrabDrag has read the model as it stands and is taking
## nothing in: the clock then, ms.
func _until_read() -> int:
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < WAIT_MS:
		await process_frame
		if _grab.is_ready() and not _grab.is_reading() and not _world.is_being_laid() \
				and _store.awaited.is_empty():
			return Time.get_ticks_msec()
	_check("the joints are read within %d s" % (WAIT_MS / 1000), false)
	return Time.get_ticks_msec()


## A part on a joint a press moves, the first such by its id: 0 when none.
func _target() -> int:
	var bodies: Bodies = _grab.read_bodies()
	if bodies == null:
		return 0
	var candidates: Array = []
	for body: Variant in bodies.parent_link:
		if bodies.flexible.has(body):
			continue
		var ids: Array = Array(bodies.members.get(body, PackedInt64Array()))
		ids.sort()
		if not ids.is_empty():
			candidates.append(int(ids[0]))
	candidates.sort()
	for id: int in candidates.slice(0, 12):
		var screen: Vector2 = _camera.unproject_position(_world.get_brick(id).transform.origin)
		_grab.press(id, screen)
		var moves: bool = _grab.is_moving()
		_grab.cancel()
		if moves:
			return id
	return 0


## A press on [param id]: what it did ("moves", "reading", or the words), the
## parts it moves, what it said, and its cost, ms.
func _press(id: int) -> Array:
	var screen: Vector2 = _camera.unproject_position(_world.get_brick(id).transform.origin)
	var began: int = Time.get_ticks_usec()
	_grab.press(id, screen)
	var ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	var moving: Array = []
	var did: String = _grab.last_words
	if _grab.grab != null and _grab.is_moving():
		moving = _grab.grab.moving.keys()
		did = "moves"
	elif _grab.last_words == "reading":
		did = "reading"
	moving.sort()
	return [did, str(moving), _grab.grab.said if _grab.grab != null else _grab.last_words, ms]


func _report(name: String) -> void:
	var worst: float = 0.0
	var over: int = 0
	for phase: String in ["open", "idle", "during", "drag"]:
		if not _seen.has(phase):
			continue
		var seen: Array = _seen[phase]
		print("    %s: %d frames, GrabDrag's own worst %.1f ms (%s), %d over %.0f ms, %d over %.0f ms %s"
			% [phase, seen[0], seen[1], seen[2], seen[3], LIST_MS, seen[4], BAR_MS, seen[5]])
		worst = maxf(worst, seen[1])
		over += int(seen[4])
	for phase: String in ["open", "idle", "during", "drag"]:
		if _whole.has(phase):
			var whole: Array = _whole[phase]
			print("    %s, the whole frame's processing: %d frames, the longest %.1f ms, %d over %.0f ms"
				% [phase, whole[0], whole[1], whole[2], BAR_MS])
			print("WHOLE %s %s longest %.1f over16 %d" % [name, phase, whole[1], whole[2]])
	var copy_frames: Variant = _grab.get("copy_frames")
	if copy_frames != null:
		print("    the last copy: %d frames, its longest slice %.1f ms; the longest taking in %.1f ms"
			% [copy_frames, _grab.get("copy_worst_ms"), _grab.get("taken_worst_ms")])
	print("    the status bar's weighing (Main._weigh): its longest frame %.1f ms (%s)" % [_weigh_worst, _weigh_frame])
	print("GRABTAKE %s worst %.1f over16 %d" % [name, worst, over])
	_check("%s: no frame of GrabDrag's own over %.0f ms from the open to the end (the worst %.1f)"
		% [name, BAR_MS, worst], over == 0)


## What copying the model and its lattice whole costs here, and freeing
## those copies: what each reader that copies at once pays on the main
## thread (Main.weigh_joints, Strengthen, StressView, Stability).
func _pieces(name: String) -> void:
	var clock: int = Time.get_ticks_usec()
	var still: BrickWorld = _world.copy_for_reading()
	var copy_world: float = float(Time.get_ticks_usec() - clock) / 1000.0
	clock = Time.get_ticks_usec()
	var cells: BrickLattice = _builder.lattice.copy_for_reading()
	var copy_lattice: float = float(Time.get_ticks_usec() - clock) / 1000.0
	clock = Time.get_ticks_usec()
	still.free()
	var free_world: float = float(Time.get_ticks_usec() - clock) / 1000.0
	clock = Time.get_ticks_usec()
	cells = null
	var free_lattice: float = float(Time.get_ticks_usec() - clock) / 1000.0
	print("PIECES %s copy world %.1f, copy lattice %.1f, free world %.1f, free lattice %.1f ms"
		% [name, copy_world, copy_lattice, free_world, free_lattice])
	# The autosave's own (ModelStore): a model opened from a file has its
	# parts copied where they came from, in one go, and a section broken out
	# the whole model copied home.
	clock = Time.get_ticks_usec()
	var asked: Dictionary = _store.call("_source_asked", name) if _store != null else {}
	var source_ms: float = float(Time.get_ticks_usec() - clock) / 1000.0
	clock = Time.get_ticks_usec()
	asked = {}
	var source_free: float = float(Time.get_ticks_usec() - clock) / 1000.0
	clock = Time.get_ticks_usec()
	var home: BrickWorld = _world.copy_at_home()
	var home_ms: float = float(Time.get_ticks_usec() - clock) / 1000.0
	clock = Time.get_ticks_usec()
	home.free()
	var home_free: float = float(Time.get_ticks_usec() - clock) / 1000.0
	print("PIECES %s autosave's parts where they came from %.1f (dropped %.1f), copied home %.1f (freed %.1f) ms"
		% [name, source_ms, source_free, home_ms, home_free])


func _finish() -> void:
	_phase = ""
	print("")
	print("grabtake probe: %s" % ("%d FAILED" % _failures if _failures > 0
		else "no frame of GrabDrag's own over %.0f ms after a model opens" % BAR_MS))
	quit(1 if _failures > 0 else 0)
