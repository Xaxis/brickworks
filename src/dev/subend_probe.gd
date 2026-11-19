## A part put on top at the end of a sub-model keeps its page through a save
## and a reopen (smalls6, from mergekeep's finding, 2026-11-18). The booklet
## showed a part put down outside the author's steps (step -1) after every
## step of the model, and the file wrote it in a step of its own after its
## sub-model's last (AuthorSteps.numbers_for_file), so once opened again its
## page came among the sub-model's, before the main model's steps after the
## one that puts it on: 358-1's rocket, 8063-1's tractor, a sub-model turned
## to its end; a sub-model placed twice was one page shown and two reopened.
##
## Each case is opened, then (sub) the sub-model of the most steps entered
## and a copy of its last part put down above the model, or (subon) on the
## part it is a copy of, or (subclose) above and the step closed, or (main)
## a part put above the main model. A sub-model built on the side (5540-1's
## sub05) has the step put on it as its callout's last; one put above it
## holds it together no more, and it is built where it stands, shown and
## reopened. Patched, then
## written whole. A row is ok when the pages, read as the booklet orders
## them (number, banner, callout, the turn in force, the look without the
## turn's own fields, copies, parts), are the same opened again; the save
## opened again saves to the same bytes; the part put is a page alone;
## undone, the model saves the bytes it saved unedited and shows the pages it
## showed; unedited, it saves alike twice, and patched, as the file, the
## app's title alone put in; an LPub3D group's BEGIN and END each just after
## a STEP, so the step put in is in the group or out of it whole (endsteps');
## and, patched, the save is the file with lines put in alone (a part's, a
## STEP, a ROTSTEP END, the app's title).
##
##   godot --headless --path . --script src/dev/subend_probe.gd
##   SUBEND_ONLY=a,b   the cases whose name is one of them
##   SUBEND_ALL=1      8063-1 too (~6 min more)
##   S5_SAVE=DIR       each save written there
extends "res://src/dev/s5steps_probe.gd"

## A sub-model turned from its 2nd step to its end, its last step unclosed
## (s5review's), put on in the main model's first step.
const TURNED := """0 FILE main.ldr
0 Main
0 Name: main.ldr
0 Author: A. Builder
1 16 0 0 0 1 0 0 0 1 0 0 0 1 turnsub.ldr
0 STEP
1 4 0 -100 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 40 -100 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 NOFILE
0 FILE turnsub.ldr
0 Turned Sub
0 Name: turnsub.ldr
0 Author: A. Builder
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 40 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 ROTSTEP 180 0 0 ABS
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

## A plain sub-model, every step closed, put on in the main model's 2nd
## step after a part of its own, and a step of the main model's after it.
const PLAIN := """0 FILE main.ldr
0 Main
0 Name: main.ldr
0 Author: A. Builder
1 4 -120 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 16 0 0 0 1 0 0 0 1 0 0 0 1 plainsub.ldr
0 STEP
1 4 0 -100 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 40 -100 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 NOFILE
0 FILE plainsub.ldr
0 Plain Sub
0 Name: plainsub.ldr
0 Author: A. Builder
1 14 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 14 40 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 NOFILE
"""

## The plain sub-model's last step begun on a new page ("PAGE NEW" above
## its parts), and in another case on a page of its own ("PAGE ALONE"
## below them): the step put in after it takes neither line.
const PAGE_FROM := "0 STEP\n1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n0 NOFILE\n"
const PAGE_NEW := "0 STEP\n0 !BRICKWORKS PAGE NEW\n1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n0 NOFILE\n"
const PAGE_ALONE := "0 STEP\n1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 !BRICKWORKS PAGE ALONE\n0 STEP\n0 NOFILE\n"
## Its last two steps one LPub3D group, the last's first part off the
## parts list, and the group's END after its STEP, as LPub3D writes one.
const LPUB_FROM := "0 STEP\n1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 1 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n0 NOFILE\n"
const LPUB_TO := "0 STEP\n0 !LPUB MULTI_STEP BEGIN\n1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 1 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n0 !LPUB PLI BEGIN IGN\n1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 !LPUB PLI END\n1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n0 !LPUB MULTI_STEP END\n0 NOFILE\n"

## The plain sub-model put on bricks of the main model's first step (shown,
## it is still built where it stands, not on the side).
const BASE_FROM := "1 4 -120 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
const BASE_TO := "1 4 0 24 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 4 40 24 0 1 0 0 0 1 0 0 0 1 3001.dat\n"

const EndSteps := preload("res://src/dev/endsteps_probe.gd")

var _end_rows: Array = []
var _end_bad: int = 0


func _run() -> void:
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
	_s5_save = OS.get_environment("S5_SAVE")
	if not _s5_save.is_empty():
		DirAccess.make_dir_recursive_absolute(_s5_save)
	var plain_twice: String = PLAIN.replace("1 4 0 -100 0 1 0 0 0 1 0 0 0 1 3001.dat\n",
		"1 16 200 0 0 1 0 0 0 1 0 0 0 1 plainsub.ldr\n1 4 0 -100 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
	var turned_twice: String = TURNED.replace("1 16 0 0 0 1 0 0 0 1 0 0 0 1 turnsub.ldr\n",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 turnsub.ldr\n1 16 200 0 0 1 0 0 0 1 0 0 0 1 turnsub.ldr\n")
	var cases: Array = [
		["turned1", TURNED, ["sub", "subclose"]],
		["turned2", turned_twice, ["sub"]],
		["plain1", PLAIN, ["sub", "subclose", "main"]],
		["plain2", plain_twice, ["sub", "subclose"]],
		["pagenew", PLAIN.replace(PAGE_FROM, PAGE_NEW), ["sub"]],
		["pagealone", PLAIN.replace(PAGE_FROM, PAGE_ALONE), ["sub"]],
		["lpub", PLAIN.replace(LPUB_FROM, LPUB_TO), ["sub"]],
		["onbase", PLAIN.replace(BASE_FROM, BASE_TO), ["sub", "subon"]],
		["358", "res://vendor/omr/files/358-1.mpd", ["sub", "subon"]],
		["5540", "res://vendor/omr/files/5540-1_Plane.mpd", ["sub", "subon"]]]
	if OS.get_environment("SUBEND_ALL") == "1":
		cases.append(["8063", "res://vendor/omr/files/8063-1.mpd", ["sub"]])
	var only: PackedStringArray = OS.get_environment("SUBEND_ONLY").split(",", false)
	for entry: Array in cases:
		var name: String = entry[0]
		if not only.is_empty() and not name in only:
			continue
		var text: String = entry[1]
		if text.begins_with("res://"):
			text = FileAccess.get_file_as_string(text)
		if name in ["pagenew", "pagealone", "lpub", "onbase"] and text == PLAIN:
			print("  FAIL %s: the case's file was not made" % name)
			_end_bad += 1
			continue
		print("\n== %s" % name)
		for mode: String in entry[2]:
			for whole: bool in [false, true]:
				await _one(name, text, mode, whole)
	ModelStore.patch_files = true
	print("\nsubend rows:")
	for row: String in _end_rows:
		print("  " + row)
	print("subend: %d of %d rows failed" % [_end_bad, _end_rows.size()])
	_world.clear()
	await _frames(4)
	quit(1 if _end_bad > 0 or _end_rows.is_empty() else 0)


func _one(name: String, text: String, mode: String, whole: bool) -> void:
	ModelStore.patch_files = not whole
	await _open(text, name)
	var unedited: String = _store.saved_text()
	var unedited_again: String = _store.saved_text()
	_s5_keep(name, "unedited", "whole" if whole else "patch", unedited)
	# Patched, unedited: the file, with the app's title alone put in.
	var kept: String = "" if whole else _added_alone(text, unedited, name, true)
	var section: String = "" if mode == "main" else _most_steps()
	var label: String = "%s %s %s %s" % [name, mode, section if not section.is_empty() else "main",
		"whole" if whole else "patch"]
	if mode != "main" and section.is_empty():
		print("  FAIL %s: no sub-model of its own steps" % label)
		_end_bad += 1
		_end_rows.append("FAIL " + label)
		return
	var steps: Array = _ops_steps(section)
	var top: int = -1
	for j: int in range(steps.size() - 1, -1, -1):
		if not (steps[j][1] as Array).is_empty():
			top = int((steps[j][1] as Array)[-1])
			break
	var before: Array = _pages()
	var depth: int = _builder.history_depth()
	if mode != "main":
		_shell.assemblies.enter(section)
		await _frames(2)
	_select_only([top])
	(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
	var put: int = 0
	if mode == "subon":
		put = await _put_on()
	else:
		put = await _put_down(true)
	await _frames(4)
	var said: String = ""
	if mode == "subclose":
		said = _shell.change_steps("close", [], null)
		await _frames(4)
	if mode != "main":
		_shell.assemblies.leave_to("")
		await _frames(2)
	var brick: BrickWorld.Brick = _world.get_brick(put)
	var shown: Array = _pages()
	# The step put in: a page of the part alone. Not a page more: a part put
	# above a sub-model built on the side holds it together no more, and it
	# is built where it stands (5540-1's sub05, 61 pages both).
	var page: String = ""
	var alone: bool = false
	for line: String in shown:
		if line.contains(_part_said(brick)):
			page = line.get_slice(" turn[", 0)
			alone = line.get_slice(" [", line.get_slice_count(" [") - 1).count("@") == 1
	var where: String = "#%d step %d in %s, on page %s%s" % [put, brick.step if brick != null else -9,
		AuthorSteps.home(_world, Assemblies.path_of(brick)) if brick != null else "?", page,
		"" if alone else " NOT ALONE"]
	var saved: String = _store.saved_text()
	var wrote: String = str(_store.get("last_whole"))
	_s5_keep(name, "%s_end" % mode, "whole" if whole else "patch", saved)
	# Undone: what it was, to the byte, and its pages.
	await _back_to(depth)
	var undone: String = _store.saved_text()
	var undone_pages: Array = _pages()
	var undo_ok: bool = undone == unedited and undone_pages == before
	# Opened again: the pages shown, and the bytes saved.
	await _open(saved, name)
	var again: Array = _pages()
	var resaved: String = _store.saved_text()
	var unlike: String = _s5_unlike(shown, again)
	var touched: String = "" if whole else _added_alone(text, saved, name)
	# An LPub3D group's BEGIN and END each just after a STEP, as LPub3D
	# reads a group: the step put in is in the group or out of it whole.
	# Judged so only where the file's own are (5540-1 ends a group it never
	# began, line 247); else counted.
	var grouped: String = EndSteps._group_mid_step(_groups_only(saved)) \
		if EndSteps._group_mid_step(_groups_only(text)).is_empty() else ""
	if grouped.is_empty() and _groups_only(saved).count("MULTI_STEP") != _groups_only(text).count("MULTI_STEP"):
		grouped = "%d MULTI_STEP BEGIN and END lines, the file's %d" % [
			_groups_only(saved).count("MULTI_STEP"), _groups_only(text).count("MULTI_STEP")]
	var ok: bool = put > 0 and unlike.is_empty() and resaved == saved and alone \
		and undo_ok and unedited == unedited_again and kept.is_empty() and touched.is_empty() \
		and grouped.is_empty()
	print("  %s %s (%s%s): %s; pages %d -> %d shown, %d reopened; saves to itself %s; undone to the byte %s, its pages %s; unedited saves alike %s%s%s%s%s%s" % [
		"ok  " if ok else "FAIL", label, where, "" if said.is_empty() else ", \"%s\"" % said.left(60),
		"patched" if wrote.is_empty() else "whole: " + wrote.left(50), before.size(), shown.size(),
		again.size(), resaved == saved, undone == unedited, undone_pages == before,
		unedited == unedited_again, "" if whole else ", the file's own %s" % kept.is_empty(),
		"" if kept.is_empty() else "\n      UNEDITED " + kept,
		"" if touched.is_empty() else "\n      WROTE AGAIN " + touched,
		"" if grouped.is_empty() else "\n      GROUP " + grouped,
		"" if unlike.is_empty() else "\n      UNLIKE " + unlike])
	if not ok:
		_end_bad += 1
		if not unlike.is_empty():
			var a: Array = shown.duplicate()
			var b: Array = again.duplicate()
			for x: String in shown:
				if b.has(x):
					b.erase(x)
					a.erase(x)
			print("      only shown (%d):\n        %s" % [a.size(), "\n        ".join(a.map(
				func(s: String) -> String: return s.left(240)))])
			print("      only reopened (%d):\n        %s" % [b.size(), "\n        ".join(b.map(
				func(s: String) -> String: return s.left(240)))])
	_end_rows.append("%s %s" % ["ok  " if ok else "FAIL", label])


## What is in hand put down on what it was copied from: the lowest place
## above it it fits, a plate at a time, so it is held there and not in the
## air. The part put down, or 0.
func _put_on() -> int:
	var carry: Carry = _builder.carrying
	carry.stand_where_lifted(_builder.lattice, _builder)
	carry.pin()
	for k: int in 40:
		if carry.show_moved(Transform3D(Basis.IDENTITY, Vector3(0.0, BrickLattice.PLATE * (k + 1), 0.0)),
				_builder.lattice, _builder):
			var put: int = _builder.place()
			await _frames(4)
			_builder.cancel_carry()
			return put
	_builder.cancel_carry()
	return 0


## [param brick] as a page of [method _pages] lists it.
func _part_said(brick: BrickWorld.Brick) -> String:
	if brick == null:
		return "(none)"
	var o: Vector3 = brick.transform.origin - _store.lift()
	return "%s/%d@%.1f,%.1f,%.1f" % [brick.part_id, brick.color_code, o.x, o.y, o.z]


## The sub-model copy, in steps of its own, with the most steps.
func _most_steps() -> String:
	var paths: Array = AuthorSteps.paths_in(_world, _store.scenery).keys()
	paths.sort()
	var best: String = ""
	var most: int = 0
	for path: String in paths:
		if path.is_empty() or AuthorSteps.home(_world, path) != path:
			continue
		var n: int = _ops_steps(path).size()
		if n > most:
			most = n
			best = path
	return best


## Each page in the booklet's order, as [method _s5_pages] reads one, with
## the callout it is in and its place there.
func _pages() -> Array:
	var lift: Vector3 = _store.lift()
	var out: Array = []
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		var parts: Array = []
		for id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			if brick != null:
				var o: Vector3 = brick.transform.origin - lift
				parts.append("%s/%d@%.1f,%.1f,%.1f" % [brick.part_id, brick.color_code, o.x, o.y, o.z])
		parts.sort()
		var turn: Dictionary = BookletLooks.turn_at(_world, step.authored_in, step.authored_step)
		var look: Dictionary = BookletLooks.of(_world, step.authored_in, step.authored_step).duplicate(true)
		look.erase("turn")
		look.erase("how")
		look.erase("line")
		out.append("#%d sec'%s'%s turn[%s] look%s x%d [%s]" % [step.number, step.section,
			"" if step.callout == 0 else " callout %d.%d/%d" % [step.callout, step.callout_step,
				step.callout_steps],
			"-" if turn.is_empty() else "%s %s" % [turn.get("how", "REL"), str(turn["turn"])],
			JSON.stringify(look, "", true), step.times, " ".join(parts)])
	return out


## "" when [param saved] is [param text] with lines put in alone: a part's,
## a STEP or a "0 ROTSTEP END" (a turn ended for the part put on), the
## app's title, and the name the probe opened it by in its head
## (s5steps' _s5_touched, a turn's end let in); with [param title_only],
## the title and that name alone. Else the first of the file's lines
## written again or left out.
static func _added_alone(text: String, saved: String, name: String, title_only: bool = false) -> String:
	var was: PackedStringArray = text.replace("\r", "").split("\n")
	var now: PackedStringArray = saved.replace("\r", "").split("\n")
	var i: int = 0
	for line: String in now:
		if i < was.size() and line == was[i]:
			i += 1
		elif i < 3 and line == "0 " + name:
			i += 1
		elif not (line.begins_with("0 !BRICKWORKS TITLE ") or not title_only and (line.begins_with("1 ")
				or line == "0 STEP" or line == "0 ROTSTEP END")):
			return "line %d of the file, \"%s\", written \"%s\"" % [i + 1, was[i] if i < was.size() else "", line]
	return "" if i == was.size() else "line %d of the file, \"%s\", left out" % [i + 1, was[i]]


## [param text] with only its LPub3D groups' BEGIN and END of the
## MULTI_STEP lines: a group's settings ("MULTI_STEP STEP_NUMBER FONT ...",
## 5540-1's) begin and end nothing.
static func _groups_only(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		var bare: String = line.strip_edges()
		if not bare.begins_with("0 !LPUB MULTI_STEP") or bare.ends_with(" BEGIN") or bare.ends_with(" END"):
			out.append(line)
	return "\n".join(out)
