## How long Replace holds the window on a big model, and what it makes.
##
##   godot --path . --resolution 1400x900 --script src/dev/replace_cost_probe.gd -- [--tries=3]
##       [--into=DIR]
##
## Replace with the part in hand, a 2 x 4, of all of the Wizard's Tower
## (10,105 parts), as its menu item runs it (Shell.run), and undone. On the
## tower it held one frame for 1.1 s (bigmodels2): the window stood still.
## Pass: the longest frame of the app's own work from the press until
## nothing is worked on is under BAR_MS at least of TRIES (less what the
## main thread waited for a CPU; three times as long at a load past the
## box's cores), every try saves what the first did, byte for byte, and the
## undo saves the file before it. With --into, the save after the first
## replace is written there (replaced.ldr, and what the status bar said in
## said.txt), to hold against another checkout's: a change made only to be
## quicker makes the same model.
extends SceneTree

const BAR_MS := 100.0

var _failures: int = 0
var _into: String = ""
var _tries: int = 3
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _bar: ModelBar
var _verbs: EditVerbs
## [began usec, own ms (less the main thread's wait for a CPU), ended usec,
## the wait ms], a frame each.
var _frames_seen: Array = []
var _began_us: int = 0
var _began_waited: float = 0.0
var _saves: int = 0


## After every other node's _process: a frame's own work ends after it.
class _End extends Node:
	var probe: Object

	func _ready() -> void:
		process_priority = 1000000

	func _process(_delta: float) -> void:
		probe.call("_frame_ended_later")


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_began_us = Time.get_ticks_usec()
	_began_waited = ProbeTime.waited_ms()
	return false


func _frame_ended_later() -> void:
	_frame_ended.call_deferred()


func _frame_ended() -> void:
	var now: int = Time.get_ticks_usec()
	var waited: float = ProbeTime.waited_ms() - _began_waited
	_frames_seen.append([_began_us, maxf((now - _began_us) / 1000.0 - waited, 0.0), now, waited])
	if _frames_seen.size() > 20000:
		_frames_seen = _frames_seen.slice(-10000)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


## Until nothing is being worked on and eight frames in a row had little
## work of their own, or [param seconds].
func _quiet(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var calm: int = 0
	while Time.get_ticks_msec() < until and calm < 8:
		await process_frame
		var last: Array = _frames_seen.back() if not _frames_seen.is_empty() else [0, 0.0]
		calm = 0 if Working.is_busy() or float(last[1]) > 40.0 else calm + 1


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_into = arg.substr(7)
		elif arg.begins_with("--tries="):
			_tries = maxi(1, int(arg.substr(8)))
	if not _into.is_empty():
		DirAccess.make_dir_recursive_absolute(_into)
	var end := _End.new()
	end.probe = self
	root.add_child(end)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	(_main.get("_playback") as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_bar = _main.get("_bar")
	_verbs = _main.get("_verbs")
	var placed: int = await _bar.open_with_progress("res://models/orthanc.ldr")
	_bar.opened.emit(placed)
	await _quiet(120.0)
	print("tower: %d parts open" % _world.brick_count())
	_builder.held_part = "3001"
	var first: PackedByteArray = PackedByteArray()
	var first_said: String = ""
	var same: bool = true
	var undone: bool = true
	var least: float = INF
	var tries := PackedStringArray()
	var busy: float = 0.0
	for attempt: int in _tries:
		_verbs.select_by("all")
		await _quiet(60.0)
		var before: PackedByteArray = _saved()
		# Saving all of it is a long frame of the probe's own: pressed after.
		await _quiet(30.0)
		var load_at: float = ProbeTime.box_load()
		var from: int = Time.get_ticks_usec()
		_shell.run("replace")
		await _quiet(60.0)
		var total: float = (Time.get_ticks_usec() - from) / 1000.0
		busy = maxf(busy, maxf(load_at, ProbeTime.box_load()))
		var longest: float = 0.0
		var waited: float = 0.0
		for frame: Array in _frames_seen:
			if int(frame[2]) >= from and float(frame[1]) > longest:
				longest = float(frame[1])
				waited = float(frame[3])
		least = minf(least, longest)
		tries.append("%.0f" % longest)
		var said: String = _bar.status_text()
		var after: PackedByteArray = _saved()
		print("  try %d: the longest frame %.0f ms of its own (%.0f waiting for a CPU), %.0f ms in all; %s"
			% [attempt + 1, longest, waited, total, said])
		if attempt == 0:
			first = after
			first_said = said
		else:
			same = same and after == first and said == first_said
		_verbs.press("undo")
		await _quiet(60.0)
		var back: PackedByteArray = _saved()
		undone = undone and back == before and after != before
		_verbs.select_by("none")
		await _quiet(30.0)
	if not _into.is_empty():
		var file := FileAccess.open(_into.path_join("replaced.ldr"), FileAccess.WRITE)
		file.store_buffer(first)
		file.close()
		file = FileAccess.open(_into.path_join("said.txt"), FileAccess.WRITE)
		file.store_string(first_said + "\n")
		file.close()
	var bar: float = BAR_MS * ProbeTime.slack(busy)
	_check("tower: Replace's longest frame %.0f ms of its own at least (%s ms; %s), the bar %.0f ms"
		% [least, ", ".join(tries), ProbeTime.load_said(busy), bar], least <= bar)
	_check("tower: each of %d tries saved what the first did (%d bytes): %s" % [_tries, first.size(),
		first_said], same and not first.is_empty())
	_check("tower: each undone, the save is the file before it, byte for byte", undone)
	print("")
	print("replace cost: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	for n: int in _saves:
		DirAccess.remove_absolute("user://replace_cost_%d.ldr" % (n + 1))
	# A big model left standing at the quit can take the engine down with it.
	_world.clear()
	await _frames(10)
	_main.queue_free()
	await _frames(10)
	quit(1 if _failures > 0 else 0)


## The model as Save writes it.
func _saved() -> PackedByteArray:
	_saves += 1
	var path: String = "user://replace_cost_%d.ldr" % _saves
	_store.save_file(path, "replace cost")
	return FileAccess.get_file_as_bytes(path)
