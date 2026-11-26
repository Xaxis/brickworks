## handkeep: what is in hand never leaves the model's file until it is put
## down. A selection carried (lift_selection) and a figure lifted by X, each
## with the working model written as the autosave writes it, the process
## killed, and the model opened again in a new one: nothing lost, every part
## where it stood, in its own step, sub-model and file line. And a selection
## carried with a session's edit and a nudge between: Escape puts it back, put
## down it is each part moved, and Undo leaves the file byte for byte.
##
##   godot --path . --resolution 1280x720 --script src/dev/handkeep_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh handkeep_probe --case=between     in one process
##   PROBE_DATA=DIR PROBE_SIZE=1280x720 tools/probe.sh handkeep_probe --case=kill --kind=carry
##   PROBE_DATA=DIR PROBE_SIZE=1280x720 tools/probe.sh handkeep_probe --case=reopen --kind=carry
##
## --case= between (the in-process cases), kill (lift, autosave, kill the
## process: it exits by SIGKILL, so its exit is not 0), reopen (the next run,
## with the same PROBE_DATA, opens what the killed one left). --kind= carry or
## figure.
extends "res://src/dev/figreview2_probe.gd"

const DIR3 := "user://handkeep_probe/"

var _kind: String = "carry"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("handkeep_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.substr(7)
		if arg.begins_with("--kind="):
			_kind = arg.substr(7)
	if _case == "all":
		_case = "between"
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "phone" if mini(window.x, window.y) < int(Phone.NARROW) else "desktop"
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = false
	Keymap.reset()
	Keymap.use("brickworks")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(20)
	_store = _main.get("_store")
	_store.keeps = false
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_steps = _main.get("_steps")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_socket2 = CommandSocket.new()
	_socket2.assistant = _main.get("_assistant")
	_socket2.app = _main
	_main.add_child(_socket2)
	_gate = _builder.has_method("holds_lifted_figure")
	_code = "handkeep" if _builder.has_method("holds_lift") else "before handkeep"
	print("handkeep_probe: a %s window, case %s, kind %s, code %s" % [_size, _case, _kind, _code])
	match _case:
		"kill":
			await _kill()
		"reopen":
			await _reopen()
		_:
			await _between_carried()
	print("\nhandkeep_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## The parts a carried selection takes: REPLAN's two wall bricks of main's
## second step, and the plate inside the figure's sub-model, a step after it.
func _carried_ids() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		var part: String = brick.part_id.get_basename()
		if part == "3003" and brick.transform.origin.x > 100.0 or part == "3023":
			out.append(brick.id)
	out.sort()
	return out


func _other_wall() -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("3003") and brick.transform.origin.x < 0.0:
			return brick.id
	return 0


## Into hand: the selection lifted, or the figure by its torso.
func _take() -> bool:
	_builder.clear_selection()
	if _kind == "figure":
		return _builder.lift_brick(int(_torsos()[0])) and _builder.is_holding_figure()
	for brick_id: int in _carried_ids():
		_builder.select_brick(brick_id, true)
	return _builder.lift_selection() == 3 and _builder.is_carrying()


# -- killed with it in hand, opened again -----------------------------------------------


func _kill() -> void:
	print("\nK. %s in hand, the autosave, the process killed" % _kind)
	var path: String = _fixture2("handkeep_kill", REPLAN)
	if not await _to_step(path, "last"):
		_check("kill: opens", false)
		return
	_store.keeps = true
	# The working model as opened, written as the autosave writes it.
	_store.touch()
	var before: String = _store.write_now()
	var text0: String = FileAccess.get_file_as_string(before) if not before.is_empty() else ""
	var full0: Array = _full()
	var line0: String = _timeline()
	var held: bool = await _take()
	await _frames(6)
	var unsaved: bool = _store.has_unsaved_work()
	# The autosave's own tick, 2.5 s after the change it hears (the parts no
	# longer drawn), as it runs in the app: four seconds of frames.
	var until: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until:
		await process_frame
	var written: String = _store.write_now()
	var text1: String = FileAccess.get_file_as_string(written) if not written.is_empty() else ""
	_result("kill.%s" % _kind, "in hand %s; unsaved %s; autosave %s: %d bytes as opened, %d in hand, same %s; timeline in hand %s (was %s)"
		% [held, unsaved, written.get_file(), text0.length(), text1.length(), text0 == text1, _timeline(), line0])
	_check("kill %s: in hand" % _kind, held)
	_check("kill %s: in hand counts as unsaved work" % _kind, unsaved)
	_check("kill %s: the autosave written in hand is the model as opened, byte for byte" % _kind,
		not text1.is_empty() and text1 == text0)
	_check("kill %s: the timeline in hand as it was (%s)" % [_kind, _timeline()], _same_steps(_timeline(), line0))
	DirAccess.make_dir_recursive_absolute(DIR3)
	var keep := FileAccess.open(DIR3 + "kill_%s.txt" % _kind, FileAccess.WRITE)
	keep.store_string("%s\n%s\n" % [written, "\n".join(full0)])
	keep.close()
	print("\nhandkeep_probe: kill %s: %s, killed now with it in hand" % [_kind,
		"all passed" if _failures == 0 else "%d failed" % _failures])
	# SIGKILL: no close, no save, nothing of the app's own let run.
	OS.kill(OS.get_process_id())
	await _frames(600)


func _reopen() -> void:
	print("\nO. opened again after the process was killed with %s in hand" % _kind)
	var kept: String = FileAccess.get_file_as_string(DIR3 + "kill_%s.txt" % _kind)
	var lines: PackedStringArray = kept.split("\n", false)
	if lines.size() < 2:
		_check("reopen %s: the killed run left what it wrote (%s)" % [_kind, DIR3], false)
		return
	var written: String = lines[0]
	var full0: Array = Array(lines.slice(1))
	var text: String = FileAccess.get_file_as_string(written)
	# As the next start restores it (ModelStore.restore_fetched), when it is
	# this run's autosave; else opened as Open opens it.
	var how: String = "restored"
	if written == ModelStore.autosave():
		if _steps.is_playing_back():
			_steps.stop()
		await _store.restore_fetched()
		await _frames(30)
	else:
		how = "opened"
		await _open(_fixture2("handkeep_reopen", text))
	var full1: Array = _full()
	var lost: Array = full0.filter(func(one: String) -> bool: return not full1.has(one))
	var gained: Array = full1.filter(func(one: String) -> bool: return not full0.has(one))
	_result("reopen.%s" % _kind, "%s %s: %d parts (were %d); lost %s; gained %s"
		% [how, written.get_file(), full1.size(), full0.size(), lost.slice(0, 6), gained.slice(0, 6)])
	_check("reopen %s: nothing lost, every part where it stood, in its own step, sub-model and line (%d lost, %d new)"
		% [_kind, lost.size(), gained.size()], lost.is_empty() and gained.is_empty() and full1.size() == full0.size())


# -- a carried selection with edits between ---------------------------------------------


func _between_carried() -> void:
	print("\nB. a selection carried, a session's edit and a nudge between, then Escape; then put down")
	var path: String = _fixture2("handkeep_between", REPLAN)
	if not await _to_step(path, "last"):
		_check("between: opens", false)
		return
	var name: String = "handkeep between"
	var t0: String = _text(name)
	var kept0: Array = _kept()
	var full0: Array = _full()
	var depth: int = _builder.history_depth()
	var other: int = _other_wall()
	# Escape after a session's edit laid over the lift.
	var held: bool = await _take()
	var said: String = await _call("edit_model", {"recolor": [{"bricks": [other], "color": 14}], "picture": false})
	await _frames(6)
	var still: bool = _builder.is_carrying()
	_verbs.put_away()
	await _frames(6)
	var full1: Array = _full()
	var changed: Array = full1.filter(func(one: String) -> bool: return not full0.has(one))
	_result("between.escape", "%s; in hand %s, after the edit %s; parts changed %s"
		% [said.left(80).replace("\n", " / "), held, still, changed])
	_check("between escape: the edit leaves the selection in hand", held and still)
	_check("between escape: Escape puts each part back where it stood; only the brick the session painted changed (%s)"
		% [changed], changed.size() == 1 and str(changed[0]).begins_with("3003 14"))
	await _back_to(depth)
	_check("between escape: undone, the file as opened byte for byte", _text(name) == t0)
	# Put down elsewhere after a nudge of another part.
	held = await _take()
	_builder.select_brick(other, false)
	_main.call("_nudge_by", Vector3i(1, 0, 0))
	await _frames(6)
	still = _builder.is_carrying()
	await _aim(Vector3(-200, 0, 200))
	var id: int = _builder.place()
	await _frames(6)
	var kept1: Array = _kept()
	var lost: Array = kept0.filter(func(one: String) -> bool: return not kept1.has(one))
	var t1: String = _text(name)
	_result("between.put", "in hand %s, after the nudge %s; put #%d; parts not in their own step/sub-model/line %s; file %s"
		% [held, still, id, lost, _line_diff(t0, t1).slice(0, 10)])
	_check("between put: put down after a nudge, each part in its own step, sub-model and line (%d not)"
		% lost.size(), id != 0 and lost.is_empty())
	_check("between put: the file changed only in the three parts moved and the one nudged (%d lines)"
		% _line_diff(t0, t1).size(), _line_diff(t0, t1).size() == 8)
	await _undo()
	await _undo()
	_check("between put: two Undos, the file as opened byte for byte", _text(name) == t0)
	# Lifted and put down with nothing between: one Undo.
	held = await _take()
	await _aim(Vector3(-200, 0, 200))
	id = _builder.place()
	await _frames(6)
	var one_step: bool = _builder.history_depth() == depth + 1
	await _undo()
	_check("between none: lift and put down with nothing between is one step, one Undo the file as opened",
		held and id != 0 and one_step and _text(name) == t0)
	await _back_to(depth)
