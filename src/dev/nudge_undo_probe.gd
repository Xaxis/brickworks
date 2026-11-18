## A nudge in a copied sub-model undone by one Ctrl+Z (smalls5, 2026-11-18).
##
##   godot --headless --path . --script src/dev/nudge_undo_probe.gd
##   NUDGE_IDS=894,898   those parts of 10179 (the default: flreview's four
##                       and two whose first Undo flreview saw take it back)
##   NUDGE_READ=frames   read the model two frames after the key, as
##                       flreview's probe did, not once the Undo has run
##
## flreview (bench/results/flreview-2026-11-15/nudge_flrevpre.log) nudged
## each part of 10179's copied sub-models a plate up by the handles (the
## drag's end, then what the app does after an edit), pressed Undo and read
## the file a frame later: #894, #898, #944 and #952 were a plate up, and
## put back by "the next Undo". There was no next Undo. The app had timed an
## Undo on 10179 at 150 ms or more (the nudge's copies following it, the
## save written, the steps worked out), so it says "Undoing…" first and runs
## the Undo once that line is drawn, up to three frames later
## (Working.attend, SAY_FIRST_MS): the file was read before the Undo had
## run, and the Undo ran in the next part's turn ("not made, undid: moved 1
## part"). Each part is nudged here and Ctrl+Z pressed once; once Working
## has nothing left to do the part and its copies' twins stand exactly
## where they stood, by transform, the history is as deep as before and the
## file is as it opened. NUDGE_READ=frames shows flreview's reading.
extends "res://src/dev/copyfaults_probe.gd"

const NUDGE_IDS: Array = [894, 898, 944, 952, 897, 940]

var _verbs: EditVerbs


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(1800.0).timeout.connect(func() -> void:
		print("nudge_undo probe: not finished in time")
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	print("\n== nudge")
	await _c_nudge()
	print("\nnudge_undo probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


## Each part nudged a plate up as the handles nudge it (Builder.drag_begin,
## drag_end, then the app's after-edit), and Ctrl+Z pressed once.
func _c_nudge() -> void:
	await _open(FileAccess.get_file_as_string("res://vendor/omr/files/10179-1.mpd"))
	var ids: Array = NUDGE_IDS
	if OS.has_environment("NUDGE_IDS"):
		ids = Array(OS.get_environment("NUDGE_IDS").split(",", false)).map(func(s: String) -> int: return int(s))
	var by_frames: bool = OS.get_environment("NUDGE_READ") == "frames"
	print("  read %s" % ("two frames after the key, as flreview did" if by_frames
		else "once the Undo has run (Working has nothing left to do)"))
	var start: String = _save()
	var made: int = 0
	var said_first: int = 0
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if not _check("#%d is a part of 10179" % brick_id, brick != null):
			continue
		var path: String = Assemblies.path_of(brick)
		var all_at: Dictionary = _every_transform()
		var depth: int = _builder.history_depth()
		_pick([brick_id])
		_builder.drag_begin()
		var moved: int = _builder.drag_end(Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
		if moved > 0:
			_verbs.edited.call()
		await _frames(2)
		if _builder.history_depth() == depth:
			print("  #%d %s in %s: not made (%s)" % [brick_id, brick.part_id, path, _bar_said()])
			continue
		var added: PackedStringArray = _builder.history_words(_builder.history_depth() - depth)
		var followed: int = _changed_since(all_at).size()
		made += 1
		var raised: Transform3D = brick.transform
		var expected: float = Working.expected_ms("undo", _world.brick_count() - _store.scenery.size())
		var waited: int = await _ctrl_z(by_frames)
		var first: bool = waited > 0 and _said_undoing
		if first:
			said_first += 1
		var changed: Array = _changed_since(all_at)
		print("  #%d %s in %s: nudged, %d step %s, %d parts moved with its copies; raised to %s; Ctrl+Z once%s, read %d frames on: %s" % [
			brick_id, brick.part_id, path, added.size(), added, followed, raised.origin,
			" (\"Undoing…\" said first, the Undo timed at %.0f ms)" % expected if first else "",
			waited, "every part where it stood" if changed.is_empty() else "%d parts moved, %s" % [
			changed.size(), changed.slice(0, 3)]])
		_check("#%d nudged is one step in the history, and one Ctrl+Z takes it" % brick_id,
			_builder.history_depth() == depth and added.size() == 1)
		_check("#%d nudged and undone once stands exactly where it stood, and every other part" % brick_id,
			changed.is_empty())
		# What is left of it, by the app's own Undo, so the next starts clean.
		var guard: int = 0
		while _builder.history_depth() > depth and guard < 4:
			await _ctrl_z(false)
			guard += 1
	_check("some nudges were made (%d)" % made, made > 0)
	if not by_frames:
		_check("an Undo said first and run after it was drawn, as the review's were (%d)" % said_first,
			said_first > 0)
	_check("the file as it opened, after every nudge undone", _save() == start)


var _said_undoing: bool = false


## Ctrl+Z pressed and let go, as a person does, and the model read two
## frames on ([param by_frames]) or once Working has nothing left to do (the
## Undo said first runs after its line is drawn). How many frames that was.
func _ctrl_z(by_frames: bool) -> int:
	_said_undoing = false
	var frames: int = 0
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_Z
		key.physical_keycode = KEY_Z
		key.ctrl_pressed = true
		key.pressed = down
		Input.parse_input_event(key)
		if down:
			await process_frame
			frames += 1
			var job: Working.Job = Working.current()
			_said_undoing = job != null and job.words.begins_with("Undoing")
	if by_frames:
		await process_frame
		return frames + 1
	while Working.is_busy() and frames < 600:
		await process_frame
		frames += 1
	await _frames(2)
	return frames + 2


## Every part's transform, by id.
func _every_transform() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


## The parts whose transform is not [param was]'s, or that came or went:
## "#id origin" each.
func _changed_since(was: Dictionary) -> Array:
	var out: Array = []
	var now: Dictionary = _every_transform()
	for brick_id: int in was:
		if not now.has(brick_id):
			out.append("#%d gone" % brick_id)
		elif now[brick_id] != was[brick_id]:
			out.append("#%d at %s, was %s" % [brick_id, (now[brick_id] as Transform3D).origin,
				(was[brick_id] as Transform3D).origin])
	for brick_id: int in now:
		if not was.has(brick_id):
			out.append("#%d new" % brick_id)
	return out


func _bar_said() -> String:
	var bar: ModelBar = _main.get("_bar")
	return bar.status_text().left(100) if bar.has_method("status_text") else ""
