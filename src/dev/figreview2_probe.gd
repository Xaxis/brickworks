## figreview2: an independent review of stepfast2 (a minifig moved at a step
## keeps the person's steps and files). Each case opens a model, lifts a figure
## by its torso, does something with it in hand, and reads what the model, the
## timeline and the saved file hold, byte for byte where it should come back.
## The same file runs on live (129a7c3ed) and on stepfast2.
##
##   godot --path . --resolution 1280x720 --script src/dev/figreview2_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh figreview2_probe                 every case
##   PROBE_SIZE=1280x720 tools/probe.sh figreview2_probe --case=between  one case
##
## --case= moves, two, between, session, escape, stepnav, autosave, reload, copies
## (all when not said).
##   moves    lift and put down (home and away) at the figure's own step, the
##            first step, the last, inside a car's sub-model and in an OMR file
##            (6550-1, CRLF): every part's step, sub-model and file line, only
##            the figure's lines changed, Undo byte for byte, Redo byte for byte.
##   two      two figures of 6541-1 moved in turn, undone and redone; and X over
##            the second with the first in hand.
##   between  a part the person had selected nudged with the figure in hand,
##            then the figure put back.
##   session  a session's edit_model with the figure in hand, then put back.
##   escape   Escape with the figure in hand (as the key does: drop_figure),
##            and with one brick lifted by X.
##   stepnav  the timeline stepped back with the figure in hand, then put down.
##   autosave the working model written with the figure in hand (as the
##            window's close and the autosave write it) and opened again.
##   reload   the model opened again with the figure in hand (another tab
##            saved it, and Reload was pressed), then put down.
##   copies   a figure inside a car placed twice, moved out of one copy.
## Exits non-zero when a check fails.
extends "res://src/dev/stepfast2_probe.gd"

const DIR2 := "user://figreview2_probe/"

## REPLAN's figure in the first step of main.
const FIRST := """0 FILE main.ldr
0 figreview2: a figure in main's first step, a step of bricks after it
0 Name: main.ldr
0 Author: figreview2_probe
1 71 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
1 16 0 -80 0 1 0 0 0 1 0 0 0 1 fig.ldr
0 STEP
1 4 200 -16 0 1 0 0 0 1 0 0 0 1 3003.dat
1 4 200 -40 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 2 -120 -16 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
0 NOFILE
0 FILE fig.ldr
0 fig
0 Name: fig.ldr
1 1 0 32 0 1 0 0 0 1 0 0 0 1 3815.dat
1 1 0 44 0 1 0 0 0 1 0 0 0 1 3816.dat
1 1 0 44 0 1 0 0 0 1 0 0 0 1 3817.dat
1 4 0 0 0 1 0 0 0 1 0 0 0 1 973.dat
1 4 15.552 9 0 0.985 0.174 0 -0.174 0.985 0 0 0 1 3818.dat
1 4 -15.552 9 0 0.985 -0.174 0 0.174 0.985 0 0 0 1 3819.dat
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3626b.dat
0 STEP
1 15 60 20 0 1 0 0 0 1 0 0 0 1 3023.dat
0 STEP
0 NOFILE
"""

## A figure inside a car's sub-model, a step of the car's before it and after
## it; the car in main's second step. %CARS% is the line(s) placing the car.
const NEST := """0 FILE main.ldr
0 figreview2: a figure in a car, the car in main
0 Name: main.ldr
0 Author: figreview2_probe
1 4 -200 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
%CARS%0 STEP
1 2 -120 -16 -200 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
0 NOFILE
0 FILE car.ldr
0 car
0 Name: car.ldr
1 72 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
1 72 0 0 40 1 0 0 0 1 0 0 0 1 3020.dat
0 STEP
1 16 0 -80 0 1 0 0 0 1 0 0 0 1 driver.ldr
0 STEP
1 15 0 -24 40 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 NOFILE
0 FILE driver.ldr
0 driver
0 Name: driver.ldr
1 1 0 32 0 1 0 0 0 1 0 0 0 1 3815.dat
1 1 0 44 0 1 0 0 0 1 0 0 0 1 3816.dat
1 1 0 44 0 1 0 0 0 1 0 0 0 1 3817.dat
1 4 0 0 0 1 0 0 0 1 0 0 0 1 973.dat
1 4 15.552 9 0 0.985 0.174 0 -0.174 0.985 0 0 0 1 3818.dat
1 4 -15.552 9 0 0.985 -0.174 0 0.174 0.985 0 0 0 1 3819.dat
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3626b.dat
0 STEP
0 NOFILE
"""

const ONE_CAR := "1 16 0 0 0 1 0 0 0 1 0 0 0 1 car.ldr\n"
const TWO_CARS := "1 16 0 0 0 1 0 0 0 1 0 0 0 1 car.ldr\n1 16 0 0 200 1 0 0 0 1 0 0 0 1 car.ldr\n"

## The parts a figure (and REPLAN's held plate) is made of, as file names.
const FIG_PARTS := ["3815", "3816", "3817", "973", "973p81", "3818", "3819", "3820", "3626b",
	"3626bp05", "3023", "2446", "2447", "fig", "driver"]

var _socket2: CommandSocket
var _rpc2: int = 0
var _gate: bool = false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("figreview2_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.substr(7)
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
	_code = "stepfast2" if _gate else "live"
	print("figreview2_probe: a %s window, case %s, code %s" % [_size, _case, _code])
	# --case= one case or several, comma separated.
	var wants: PackedStringArray = _case.split(",")
	if wants.has("all") or wants.has("moves"):
		await _moves()
	if wants.has("all") or wants.has("two"):
		await _two_figures()
	if wants.has("all") or wants.has("between"):
		await _between(false)
	if wants.has("all") or wants.has("session"):
		await _between(true)
	if wants.has("all") or wants.has("escape"):
		await _escape()
	if wants.has("all") or wants.has("stepnav"):
		await _stepnav()
	if wants.has("all") or wants.has("autosave"):
		await _autosave()
	if wants.has("all") or wants.has("reload"):
		await _reload()
	if wants.has("all") or wants.has("copies"):
		await _copies()
	print("\nfigreview2_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


func _fixture2(tag: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR2)
	var path: String = ProjectSettings.globalize_path(DIR2 + "%s.mpd" % tag)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func _omr(set_num: String) -> String:
	var text: String = FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("res://vendor/omr/files/%s.mpd" % set_num))
	return _fixture2("omr_" + set_num, text)


# -- reading the model and the file ---------------------------------------------


## Every part: part, colour, place, step, sub-model path and the file line it
## was read from (Brick.origin).
func _full() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		out.append("%s %d %s step %d in %s line %s" % [brick.part_id.get_basename(), brick.color_code,
			brick.transform.origin.snapped(Vector3.ONE * 0.01), brick.step,
			Assemblies.path_from(brick.group, brick.unit), brick.origin])
	out.sort()
	return out


## The same with no place: what a move must keep.
func _kept() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		out.append("%s %d step %d in %s line %s" % [brick.part_id.get_basename(), brick.color_code,
			brick.step, Assemblies.path_from(brick.group, brick.unit), brick.origin])
	out.sort()
	return out


## The model saved under [param name]: the file's text, the save taken off.
func _text(name: String) -> String:
	_forget(name)
	_store.title = name
	if not _store.save_as(name):
		return "(not saved)"
	var text: String = FileAccess.get_file_as_string(ModelStore.saved_path(name))
	_forget(name)
	return text


## Lines of [param a] not in [param b] ("- ") and of b not in a ("+ "), as
## multisets.
static func _line_diff(a: String, b: String) -> Array:
	var count: Dictionary = {}
	for line: String in a.split("\n"):
		count[line] = int(count.get(line, 0)) + 1
	for line: String in b.split("\n"):
		count[line] = int(count.get(line, 0)) - 1
	var out: Array = []
	for line: String in count:
		var n: int = int(count[line])
		for _k: int in absi(n):
			out.append(("- " if n > 0 else "+ ") + line.strip_edges())
	return out


## Whether every line of a diff is a part line of a figure part.
static func _only_figure(diff: Array) -> bool:
	for one: String in diff:
		var words: PackedStringArray = one.substr(2).split(" ", false)
		if words.size() < 15 or words[0] != "1":
			return false
		var part: String = " ".join(words.slice(14)).get_basename().to_lower()
		var hit: bool = false
		for name: String in FIG_PARTS:
			if part == name or part.ends_with(" " + name) or part.contains("minifig"):
				hit = true
		if not hit:
			return false
	return true


func _torsos() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("973"):
			out.append(brick.id)
	out.sort()
	return out


func _figure_count_in(text: String) -> int:
	var n: int = 0
	for line: String in text.split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() >= 15 and words[0] == "1" and words[14].to_lower().begins_with("973"):
			n += 1
	return n


func _lifted_gate() -> String:
	return str(_builder.call("holds_lifted_figure")) if _gate else "n/a"


func _undo() -> void:
	await _verbs.press("undo")
	await _frames(4)


func _redo() -> void:
	await _verbs.press("redo")
	await _frames(4)


func _back_to(depth: int) -> void:
	if _builder.is_holding_figure():
		_builder.drop_figure()
	_builder.cancel_carry()
	var guard: int = 0
	while _builder.history_depth() > depth and guard < 40:
		await _undo()
		guard += 1


func _call(tool: String, arguments: Dictionary) -> String:
	_rpc2 += 1
	var answer: Variant = await _socket2.answer_rpc({"jsonrpc": "2.0", "id": _rpc2,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	await _frames(6)
	return text


## Opened at the step a torso [param torso_at] (its index among the torsos)
## first shows: "fig" the first step it is on and a later part of it is not,
## "shown" the first step it is on, "last" the end.
func _to_step(path: String, where: String, torso_at: int = 0) -> bool:
	if not await _open(path):
		return false
	if where == "last":
		_steps.to_end()
		await _frames(6)
		return true
	for _n: int in 60:
		var torsos: Array = _torsos()
		if torsos.size() > torso_at and not _ahead(int(torsos[torso_at])):
			if where == "shown":
				return true
			var f: Dictionary = _ids()
			if int(f["plate"]) == 0 or _ahead(int(f["plate"])) or int(f["head"]) != 0 and _ahead(int(f["head"])):
				return true
		_steps.step_forward()
		await _frames(4)
	return false


# -- moves: put down home and away, undone and redone byte for byte -------------


func _moves() -> void:
	print("\nM. a figure lifted and put down: steps, sub-models, file lines, undo and redo by the byte")
	var replan: String = _fixture2("replan", REPLAN)
	var first: String = _fixture2("first", FIRST)
	var nest: String = _fixture2("nest", NEST.replace("%CARS%", ONE_CAR))
	var omr: String = _omr("6550-1")
	var cases: Array = [
		["replan fig step", replan, "fig"], ["replan last", replan, "last"],
		["first step", first, "shown"], ["first last", first, "last"],
		["car fig step", nest, "shown"], ["car last", nest, "last"],
		["6550-1 last", omr, "last"], ["6550-1 shown", omr, "shown"],
	]
	# --only=WORD: the cases whose name holds it.
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	for one: Array in cases:
		for put: String in ["home", "away"]:
			var tag: String = "%s %s" % [one[0], put]
			if only.is_empty() or tag.contains(only):
				await _move_case(tag, one[1], one[2], put)


func _move_case(tag: String, path: String, where: String, put: String) -> void:
	if not await _to_step(path, where):
		_check("%s: opens at the step asked" % tag, false)
		return
	var name: String = "figreview2 " + tag.replace(" ", "_")
	var t0: String = _text(name)
	var depth: int = _builder.history_depth()
	var full0: Array = _full()
	var kept0: Array = _kept()
	var line0: String = _timeline()
	var torso: int = int(_torsos()[0])
	var torso_was: Transform3D = _world.get_brick(torso).transform
	_builder.clear_selection()
	if not _builder.lift_brick(torso) or not _builder.is_holding_figure():
		_check("%s: X over the torso holds the figure" % tag, false)
		await _back_to(depth)
		return
	await _frames(4)
	var spot: Vector3 = Vector3(torso_was.origin.x, 0, torso_was.origin.z) if put == "home" \
		else Vector3(-200, 0, 200)
	await _aim(spot)
	var valid: bool = bool(_builder.get("_ghost_valid"))
	var id: int = _builder.place()
	await _frames(6)
	var t1: String = _text(name)
	var kept1: Array = _kept()
	var placed1: Array = _placed()
	var line1: String = _timeline()
	var diff: Array = _line_diff(t0, t1)
	_result("moves.%s" % tag, "valid %s put #%d; depth %d -> %d; timeline %s -> %s; %d lines changed: %s"
		% [valid, id, depth, _builder.history_depth(), line0, line1, diff.size(), diff.slice(0, 8)])
	var lost: Array = _arr_diff(kept0, kept1)
	_check("%s: put down, every part keeps its step, sub-model and file line (%d not: %s)"
		% [tag, lost.size(), lost.slice(0, 6)], id != 0 and lost.is_empty())
	_check("%s: the file's change is the figure's own lines only (%d lines: %s)"
		% [tag, diff.size(), diff.slice(0, 4)], id != 0 and _only_figure(diff))
	_check("%s: the timeline's steps as they were (%s / %s)" % [tag, line1, line0],
		_same_steps(line1, line0))
	_check("%s: lift and put down are one step (depth %d, was %d)" % [tag, _builder.history_depth(), depth],
		_builder.history_depth() == depth + 1)
	await _undo()
	var t2: String = _text(name)
	_check("%s: one Undo, the model and the file as before, byte for byte (%d lines differ: %s)"
		% [tag, _line_diff(t0, t2).size(), _line_diff(t0, t2).slice(0, 4)],
		t2 == t0 and _full() == full0)
	_check("%s: one Undo, the timeline as before (%s)" % [tag, _timeline()], _same_steps(_timeline(), line0))
	await _redo()
	var t3: String = _text(name)
	_check("%s: Redo, the file as moved, byte for byte (%d lines differ: %s)"
		% [tag, _line_diff(t1, t3).size(), _line_diff(t1, t3).slice(0, 4)], t3 == t1 and _kept() == kept1)
	await _back_to(depth)
	_check("%s: undone again, as opened" % tag, _full() == full0 and _text(name) == t0)
	await _reopen_check(tag, t1, placed1)


## Every part with no file line: part, colour, place, step and sub-model path.
func _placed() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		out.append("%s %d %s step %d in %s" % [brick.part_id.get_basename(), brick.color_code,
			brick.transform.origin.snapped(Vector3.ONE * 0.1), brick.step,
			Assemblies.path_from(brick.group, brick.unit)])
	out.sort()
	return out


## [param text] (a file saved after a move) opened afresh: every part where
## the model had it when it was saved ([param placed]).
func _reopen_check(tag: String, text: String, placed: Array) -> void:
	# Kept under the case's name, to read (the run's data folder is kept when
	# a check fails).
	var path: String = _fixture2("reopen_" + tag.replace(" ", "_"), text)
	if not await _open(path):
		_check("%s: the saved file opens again" % tag, false)
		return
	var differ: Array = _arr_diff(placed, _placed())
	_result("reopen.%s" % tag, "%d parts differ: %s" % [differ.size(), differ])
	_check("%s: saved after the move and opened again, every part where it was, in its step and sub-model (%d differ: %s)"
		% [tag, differ.size(), differ.slice(0, 6)], differ.is_empty())


static func _arr_diff(before: Array, after: Array) -> Array:
	var left: Dictionary = {}
	for one: String in after:
		left[one] = int(left.get(one, 0)) + 1
	var out: Array = []
	for one: String in before:
		if int(left.get(one, 0)) > 0:
			left[one] = int(left[one]) - 1
		else:
			out.append("was: " + one)
	for one: String in left:
		for _n: int in int(left[one]):
			out.append("now: " + one)
	return out


# -- two figures ---------------------------------------------------------------------


func _two_figures() -> void:
	print("\nT. two figures of 6541-1 moved in turn; X over the second with the first in hand")
	var path: String = _omr("6541-1")
	if not await _to_step(path, "last"):
		_check("two: opens", false)
		return
	var name: String = "figreview2 two"
	var t0: String = _text(name)
	var full0: Array = _full()
	var kept0: Array = _kept()
	var depth: int = _builder.history_depth()
	var torsos: Array = _torsos()
	_result("two.opened", "%d torsos, %d parts, depth %d" % [torsos.size(), full0.size(), depth])
	if torsos.size() < 2:
		_check("two: two figures", false)
		return
	var puts: Array = [Vector3(-400, 0, 400), Vector3(400, 0, 400)]
	var texts: Array = [t0]
	for n: int in 2:
		var torso: int = int(_torsos()[n])
		_builder.clear_selection()
		var held: bool = _builder.lift_brick(torso) and _builder.is_holding_figure()
		await _frames(4)
		await _aim(puts[n])
		var id: int = _builder.place() if held else 0
		await _frames(6)
		texts.append(_text(name))
		_result("two.put%d" % n, "held %s put #%d depth %d; %d lines changed" % [held, id, _builder.history_depth(),
			_line_diff(texts[n], texts[n + 1]).size()])
		_check("two: figure %d moved, only its own lines change (%s)" % [n + 1,
			_line_diff(texts[n], texts[n + 1]).slice(0, 4)], id != 0 and _only_figure(_line_diff(texts[n], texts[n + 1])))
	_check("two: both moved, every part keeps its step, sub-model and line (%s)" % [_arr_diff(kept0, _kept()).slice(0, 4)],
		_arr_diff(kept0, _kept()).is_empty())
	var placed2: Array = _placed()
	await _undo()
	_check("two: one Undo, the second back, byte for byte", _text(name) == texts[1])
	await _undo()
	_check("two: two Undos, as opened byte for byte", _text(name) == t0 and _full() == full0)
	await _redo()
	await _redo()
	_check("two: two Redos, as moved byte for byte", _text(name) == texts[2])
	await _back_to(depth)
	# X over the second with the first in hand.
	torsos = _torsos()
	_builder.clear_selection()
	_builder.lift_brick(int(torsos[0]))
	await _frames(4)
	var second: bool = _builder.lift_brick(int(_torsos()[0]))
	await _frames(6)
	var t_hand: String = _text(name)
	_result("two.swap", "X over the second with the first in hand: lifted %s, holding %s, figures on the model %d (were %d), in the file %d; depth %d; lifted gate %s"
		% [second, _builder.is_holding_figure(), _torsos().size(), torsos.size(), _figure_count_in(t_hand),
			_builder.history_depth(), _lifted_gate()])
	await _aim(Vector3(-400, 0, 400))
	var id2: int = _builder.place()
	await _frames(6)
	var t_put: String = _text(name)
	_result("two.swap_put", "put #%d: figures on the model %d, in the file %d (opened %d)"
		% [id2, _torsos().size(), _figure_count_in(t_put), _figure_count_in(t0)])
	_check("two: with one figure in hand, X over another leaves no figure off the model unsaid (%d on the model, %d opened)"
		% [_torsos().size(), torsos.size()], _torsos().size() == torsos.size())
	await _back_to(depth)
	_check("two: undone, as opened", _full() == full0)
	await _reopen_check("two", texts[2], placed2)


# -- an edit with the figure in hand ---------------------------------------------------


func _between(session: bool) -> void:
	var tag: String = "session" if session else "between"
	print("\n%s. %s with the figure in hand, then put back where it stood" % [tag.to_upper(),
		"a session's edit_model" if session else "a selected part nudged"])
	var path: String = _fixture2("replan_b", REPLAN)
	for where: String in ["fig", "last"]:
		if not await _to_step(path, where):
			_check("%s %s: opens" % [tag, where], false)
			continue
		var name: String = "figreview2 %s %s" % [tag, where]
		var t0: String = _text(name)
		var kept0: Array = _kept()
		var line0: String = _timeline()
		var depth: int = _builder.history_depth()
		var wall: int = 0
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id.begins_with("3003") and brick.transform.origin.x > 100.0 and wall == 0:
				wall = brick.id
		var torso: int = int(_torsos()[0])
		var torso_was: Transform3D = _world.get_brick(torso).transform
		if not session:
			_builder.clear_selection()
			_builder.select_brick(wall, false)
		_builder.lift_brick(torso)
		await _frames(4)
		var said: String = ""
		if session:
			said = await _call("edit_model", {"recolor": [{"bricks": [wall], "color": 14}], "picture": false})
		else:
			_main.call("_nudge_by", Vector3i(1, 0, 0))
		await _frames(6)
		var line_mid: String = _timeline()
		var still: bool = _builder.is_holding_figure()
		await _aim(Vector3(torso_was.origin.x, 0, torso_was.origin.z))
		var id: int = _builder.place()
		await _frames(6)
		var t1: String = _text(name)
		var figure_lost: Array = []
		for one: String in _arr_diff(kept0, _kept()):
			if not one.contains("3003"):
				figure_lost.append(one)
		_result("%s.%s" % [tag, where], "%s; holding after it %s, lifted gate %s; timeline in hand %s (was %s); put #%d; timeline %s; figure parts not in their own step/sub-model/line: %s; file: %s"
			% [said.left(80).replace("\n", " / "), still, _lifted_gate(), line_mid, line0, id, _timeline(),
				figure_lost.slice(0, 6), _line_diff(t0, t1).slice(0, 10)])
		_check("%s %s: put back after the edit, the figure's parts each in its own step, sub-model and file line (%d not)"
			% [tag, where, figure_lost.size()], id != 0 and figure_lost.is_empty())
		var figure_lines: Array = _line_diff(t0, t1).filter(func(one: String) -> bool:
			return not one.contains("3003"))
		_check("%s %s: the file changed only in the edited brick and the figure's own lines (%s)"
			% [tag, where, figure_lines.slice(0, 6)], _only_figure(figure_lines))
		await _back_to(depth)
		_check("%s %s: undone, the file as opened, byte for byte" % [tag, where], _text(name) == t0)


# -- Escape -----------------------------------------------------------------------------


func _escape() -> void:
	print("\nE. Escape with a figure in hand, and with one brick lifted by X")
	var path: String = _fixture2("replan_e", REPLAN)
	if not await _to_step(path, "fig"):
		_check("escape: opens", false)
		return
	var name: String = "figreview2 escape"
	var t0: String = _text(name)
	var full0: Array = _full()
	var line0: String = _timeline()
	var depth: int = _builder.history_depth()
	_builder.clear_selection()
	_builder.lift_brick(int(_torsos()[0]))
	_verbs.set_mode("place")
	await _frames(4)
	# What Escape does with a figure in hand (Main, KEY_ESCAPE).
	_builder.drop_figure()
	_bar.say("")
	_main.call("_refresh_preview")
	await _frames(8)
	var t1: String = _text(name)
	_result("escape.figure", "on the model %d torsos (were 1), in the file %d; parts %d (were %d); timeline %s (was %s); depth %d (was %d); the next undo says %s"
		% [_torsos().size(), _figure_count_in(t1), _full().size(), full0.size(), _timeline(), line0,
			_builder.history_depth(), depth, ", ".join(_builder.history_words(1))])
	_check("escape: Escape with a figure lifted off puts it back where it was, as Escape does a carried selection (%d torsos on the model)"
		% _torsos().size(), _torsos().size() == 1)
	await _undo()
	_check("escape: one Undo, the model and file as opened byte for byte, the timeline as it was (%s)" % _timeline(),
		_text(name) == t0 and _full() == full0 and _same_steps(_timeline(), line0))
	await _back_to(depth)
	# One brick lifted by X, then Escape (back to Select).
	var wall: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("3003") and brick.transform.origin.x > 100.0 and wall == 0:
			wall = brick.id
	_builder.lift_brick(wall)
	_verbs.set_mode("place")
	await _frames(4)
	_verbs.set_mode("select")
	_main.call("_refresh_preview")
	await _frames(6)
	_result("escape.brick", "one brick lifted by X, Escape: parts %d (were %d), depth %d (was %d)"
		% [_full().size(), full0.size(), _builder.history_depth(), depth])
	await _back_to(depth)
	# A selection picked up (lift_selection), Escape: put back (put_away).
	_check("escape: undone, as opened", _full() == full0)


# -- the timeline stepped with the figure in hand ---------------------------------------


func _stepnav() -> void:
	print("\nN. the timeline stepped back with the figure in hand, then put down")
	var path: String = _fixture2("replan_n", REPLAN)
	if not await _to_step(path, "last"):
		_check("stepnav: opens", false)
		return
	var name: String = "figreview2 stepnav"
	var t0: String = _text(name)
	var full0: Array = _full()
	var depth: int = _builder.history_depth()
	_builder.clear_selection()
	_builder.lift_brick(int(_torsos()[0]))
	await _frames(4)
	var at_lift: String = _timeline()
	for _n: int in 6:
		_steps.step_back()
		await _frames(3)
	var stepped: String = _timeline()
	await _aim(Vector3(-200, 0, 200))
	var id: int = _builder.place()
	await _frames(8)
	var shown: int = 0
	var hidden: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if FIG_PARTS.has(brick.part_id.get_basename()):
			if _ahead(brick.id):
				hidden += 1
			else:
				shown += 1
	var t1: String = _text(name)
	_result("stepnav", "in hand %s; stepped back %s; put #%d; the figure's parts shown %d, not shown %d; timeline %s; file lines changed %d"
		% [at_lift, stepped, id, shown, hidden, _timeline(), _line_diff(t0, t1).size()])
	_check("stepnav: put down at an earlier step, the figure is in view or said where it went (%d of %d shown, said: %s)"
		% [shown, shown + hidden, str(_bar.get("_said") if _bar.get("_said") != null else "?")], hidden == 0)
	await _back_to(depth)
	_check("stepnav: undone, as opened", _full() == full0 and _text(name) == t0)


# -- the working model written with the figure in hand ------------------------------------


func _autosave() -> void:
	print("\nA. the working model written with the figure in hand (autosave, window closed), opened again")
	var path: String = _fixture2("replan_a", REPLAN)
	for where: String in ["fig", "last"]:
		if not await _to_step(path, where):
			_check("autosave %s: opens" % where, false)
			continue
		var depth: int = _builder.history_depth()
		_builder.clear_selection()
		_builder.lift_brick(int(_torsos()[0]))
		await _frames(4)
		_store.keeps = true
		var written: String = _store.write_now()
		_store.keeps = false
		var text: String = FileAccess.get_file_as_string(written) if not written.is_empty() else ""
		var unsaved: bool = _store.has_unsaved_work()
		# Ctrl+S in hand, then what New or Open would ask.
		var name: String = "figreview2 autosave %s" % where
		_forget(name)
		_store.title = name
		_store.save_as(name)
		var unsaved_after_save: bool = _store.has_unsaved_work()
		_forget(name)
		# Opened again, as the next start restores it.
		var again: String = _fixture2("autosave_" + where, text)
		_builder.drop_figure()
		var reopened: bool = await _open(again)
		_result("autosave.%s" % where, "written %s: %d bytes, %d torsos in it; reopened %s: %d torsos on the model; unsaved work in hand %s, after Ctrl+S in hand %s"
			% [written.get_file(), text.length(), _figure_count_in(text), reopened, _torsos().size(), unsaved,
				unsaved_after_save])
		# A torso line in the file is not the figure kept: its sub-model's
		# section stays when main no longer places it. Opened again is.
		_check("autosave %s: the working model written in hand, opened again, has the figure (%d torsos), so a close or a crash loses nothing"
			% [where, _torsos().size()], _torsos().size() == 1)
		_check("autosave %s: after Ctrl+S in hand, the figure in hand still counts as unsaved work" % where,
			unsaved_after_save)


# -- opened again with the figure in hand ---------------------------------------------------


func _reload() -> void:
	print("\nR2. the model opened again (Reload) with the figure in hand, then put down")
	var path: String = _fixture2("replan_r", REPLAN)
	if not await _to_step(path, "last"):
		_check("reload: opens", false)
		return
	_builder.clear_selection()
	_builder.lift_brick(int(_torsos()[0]))
	await _frames(4)
	# As ReloadOffer.reopen does.
	var placed: int = await _bar.open_with_progress(path)
	if placed >= 0:
		_bar.opened.emit(placed)
	await _frames(30)
	var holding: bool = _builder.is_holding_figure()
	var on: int = _torsos().size()
	var id: int = 0
	if holding:
		_verbs.set_mode("place")
		await _aim(Vector3(-200, 0, 200))
		id = _builder.place()
		await _frames(6)
	var text: String = _text("figreview2 reload")
	_result("reload", "after the reload: holding %s, torsos on the model %d; put #%d; torsos now %d, in the file %d"
		% [holding, on, id, _torsos().size(), _figure_count_in(text)])
	_check("reload: a reload with a figure in hand makes no second figure (%d torsos)" % _torsos().size(),
		_torsos().size() <= 1)
	if _builder.is_holding_figure():
		_builder.drop_figure()


# -- a figure in a car placed twice --------------------------------------------------------


func _copies() -> void:
	print("\nC. a figure inside a car placed twice, moved out of one copy")
	var path: String = _fixture2("cars", NEST.replace("%CARS%", TWO_CARS))
	for where: String in ["shown", "last"]:
		if not await _to_step(path, where):
			_check("copies %s: opens" % where, false)
			continue
		var name: String = "figreview2 copies %s" % where
		var t0: String = _text(name)
		var full0: Array = _full()
		var kept0: Array = _kept()
		var depth: int = _builder.history_depth()
		var torsos: Array = _torsos()
		var torso: int = int(torsos[0])
		var torso_was: Transform3D = _world.get_brick(torso).transform
		_builder.clear_selection()
		var lifted: bool = _builder.lift_brick(torso)
		var figure: bool = _builder.is_holding_figure()
		await _frames(6)
		var off_in_hand: int = torsos.size() - _torsos().size()
		var reopen_text: String = ""
		var reopen_placed: Array = []
		for put: String in ["away", "home"]:
			if not _builder.is_holding_figure():
				break
			var spot: Vector3 = Vector3(-200, 0, 300) if put == "away" \
				else Vector3(torso_was.origin.x, 0, torso_was.origin.z)
			await _aim(spot)
			var id: int = _builder.place()
			await _frames(8)
			var t1: String = _text(name)
			if put == "away":
				reopen_text = t1
				reopen_placed = _placed()
			var refused: String = str(_verbs.assemblies.refused) if _verbs.assemblies != null else ""
			_result("copies.%s.%s" % [where, put], "lifted %s figure %s; torsos off in hand %d; put #%d; torsos %d (were %d); refused %s; parts kept: %s; %d lines changed: %s"
				% [lifted, figure, off_in_hand, id, _torsos().size(), torsos.size(), refused,
					_arr_diff(kept0, _kept()).slice(0, 6), _line_diff(t0, t1).size(), _line_diff(t0, t1).slice(0, 8)])
			_check("copies %s %s: put down, every part keeps its step, sub-model and line, or the move is refused with words"
				% [where, put], _arr_diff(kept0, _kept()).is_empty() or not refused.is_empty())
			await _undo()
			_check("copies %s %s: one Undo, the file as opened byte for byte" % [where, put],
				_text(name) == t0 and _full() == full0)
			if put == "away":
				_builder.clear_selection()
				_builder.lift_brick(int(_torsos()[0]))
				await _frames(4)
		await _back_to(depth)
		_check("copies %s: undone, as opened" % where, _full() == full0)
		if not reopen_text.is_empty():
			await _reopen_check("copies " + where, reopen_text, reopen_placed)
