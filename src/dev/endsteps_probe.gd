## Steps at the end of a model, and groups of steps, written as LPub3D reads
## them (smalls5, from streview's findings, 2026-11-15).
##
##   godot --headless --path . --script src/dev/endsteps_probe.gd
##   ENDSTEPS_CASES=loose,groups,moves   those cases (the default: all three)
##
## loose: a part put down on top outside the author's steps (step -1, a page
## of its own after the last) in a model whose last step has no STEP line to
## end it, one whose turn (ROTSTEP) holds to the end, and one that is both.
## Saved, the file is opened again: the pages are as they were shown, the
## new part in a step of its own and in the usual view, and the saved file
## has a STEP line (or "0 ROTSTEP END", where a turn held) between the last
## step's parts and it. Each written as a patch of the file and written
## whole (ModelStore.patch_files off). On pre261 the patch put it in the
## last step, or let the turn hold into it (358-1 opened as 29 pages, not
## 30; "an empty step with a ROTSTEP" opened upside down).
##
## groups: steps taken out and merged round LPub's MULTI_STEP BEGIN and END
## (streview's srmetas): every BEGIN and END the saved file has is right
## after a STEP line, no part of a step on both sides of one, as LPub3D
## reads a group of steps; the pages opened again as they were shown. On
## pre261 the 4th step taken out left "MULTI_STEP END" between the 3rd's
## parts and the 4th's, and the 1st taken out left "MULTI_STEP BEGIN"
## inside the step made of the 1st and 2nd. A "BUFEXCHG A STORE" stays where
## it was, inside a step made of two: LPub3D stores the parts above it, as
## it did (OMR files write it inside a step); at the step's end it would
## store the next step's too. A "BUFEXCHG A RETRIEVE" stays at the head of
## the step it starts: a merge or a step taken out that would put it in the
## middle of one is refused, with why, and nothing changes, the file saved
## as it was (mergekeep: up to it, a step made of the 4th and 5th showed the
## stored base where the RETRIEVE stood, and the 4th's tiles never).
##
## moves: the same file's parts moved a step across the RETRIEVE, by
## Shift-[ and Shift-], a drop on the timeline's step and edit_steps over
## MCP. Every part of a step moved into the other is refused as the merge is;
## one part moved is done, one undo, written below the RETRIEVE in the step
## it starts (above it in the step before), and opened again as shown. On
## pre261 each left the RETRIEVE in the middle of a step (mkreview M1).
extends "res://src/dev/keep_text_probe.gd"

## A model whose last step has no STEP line after it.
const UNCLOSED := """0 Unclosed
0 Name: unclosed.ldr
0 Author: A. Builder
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 40 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
"""

## Turned over from the 2nd step to the end (7140's carts), the last closed.
const TURNED := """0 Turned
0 Name: turned.ldr
0 Author: A. Builder
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 40 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 ROTSTEP 180 0 0 ABS
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
"""

## Turned to the end, the last step not closed.
const BOTH := """0 Both
0 Name: both.ldr
0 Author: A. Builder
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 40 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 ROTSTEP 0 90 0 REL
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 40 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
"""

## streview's srmetas (bench/results/streview-2026-11-15/srmetas.ldr), its
## LPub, LDCad and MLCad lines round steps.
const GROUPS := """0 Review metas
0 Name: srmetas.ldr
0 Author: A. Builder [abuilder]
0 !LDRAW_ORG Unofficial_Model
0 !LPUB PAGE SIZE GLOBAL 8.2677 11.6929 "A4"
0 !LDCAD GROUP_DEF [topLevel=true] [LID=7] [GID=srGrp0001] [name=Pair] [center=0 0 0]
0 // the base
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 0 0 80 1 0 0 0 1 0 0 0 1 3001.dat
1 4 0 0 160 1 0 0 0 1 0 0 0 1 3001.dat
0 BUFEXCHG A STORE
0 STEP
0 !LPUB MULTI_STEP BEGIN
0 // the second
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 !LDCAD GROUP_NXT [ids=7] [nrs=-1]
1 1 0 -24 80 1 0 0 0 1 0 0 0 1 3003.dat
1 1 0 -24 160 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
0 // the third
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3004.dat
0 !LDCAD GROUP_NXT [ids=7] [nrs=-1]
1 2 0 -48 80 1 0 0 0 1 0 0 0 1 3004.dat
1 2 0 -48 160 1 0 0 0 1 0 0 0 1 3004.dat
0 STEP
0 !LPUB MULTI_STEP END
0 !LPUB PAGE SIZE LOCAL 5.8268 8.2677 "A5"
0 !LPUB PLI BEGIN IGN
1 14 0 -72 0 1 0 0 0 1 0 0 0 1 3020.dat
0 !LPUB PLI END
1 14 0 -72 80 1 0 0 0 1 0 0 0 1 3020.dat
1 14 0 -72 160 1 0 0 0 1 0 0 0 1 3020.dat
0 STEP
0 BUFEXCHG A RETRIEVE
0 GHOST 1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 !BRICKWORKS STEP_NAME Fifth
1 15 0 -80 0 1 0 0 0 1 0 0 0 1 3023.dat
1 15 0 -80 80 1 0 0 0 1 0 0 0 1 3023.dat
1 15 0 -80 160 1 0 0 0 1 0 0 0 1 3023.dat
0 STEP
0 !BRICKWORKS STEP_NAME Sixth
1 0 0 -88 0 1 0 0 0 1 0 0 0 1 3023.dat
1 0 0 -88 80 1 0 0 0 1 0 0 0 1 3023.dat
1 0 0 -88 160 1 0 0 0 1 0 0 0 1 3023.dat
0 STEP
1 4 0 -96 0 1 0 0 0 1 0 0 0 1 3024.dat
1 4 0 -96 80 1 0 0 0 1 0 0 0 1 3024.dat
0 STEP
"""


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
	var only: PackedStringArray = OS.get_environment("ENDSTEPS_CASES").split(",", false)
	if only.is_empty() or "loose" in only:
		await _loose_case()
	if only.is_empty() or "groups" in only:
		await _groups_case()
	if only.is_empty() or "moves" in only:
		await _moves_case()
	ModelStore.patch_files = true
	print("\nendsteps probe: %s" % ("all checks passed" if _failures == 0 else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


func _loose_case() -> void:
	print("\n== loose: a part put down outside the author's steps, after the last")
	for whole: bool in [false, true]:
		ModelStore.patch_files = not whole
		for entry: Array in [["unclosed", UNCLOSED, "0 STEP"], ["turned", TURNED, "0 ROTSTEP END"],
				["turned and unclosed", BOTH, "0 ROTSTEP END"]]:
			var name: String = "%s, %s" % [entry[0], "written whole" if whole else "patched"]
			await _open(str(entry[1]), str(entry[0]))
			var steps: Array = _ops_steps("")
			_select_only([(steps[0][1] as Array)[0]])
			(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
			var put: int = await _put_down(true)
			await _frames(4)
			var brick: BrickWorld.Brick = _world.get_brick(put)
			if not _check("%s: a part put down outside the steps (#%d, step %d)" % [name, put,
					brick.step if brick != null else -9], brick != null and brick.step < 0):
				continue
			var shown: Array = _pages()
			var saved: String = _store.saved_text()
			var wrote: String = str(_store.get("last_whole"))
			await _open(saved, str(entry[0]))
			var again: Array = _pages()
			var before: String = _line_before_new(str(entry[1]), saved)
			print("  %s (%s): %d pages shown, %d opened again; the line before it \"%s\"" % [name,
				"patched" if wrote.is_empty() else "whole: " + wrote.left(50), shown.size(), again.size(), before])
			print("      shown last: %s\n      opened last: %s" % [str(shown[-1]), str(again[-1])])
			print("      the saved file's end:\n%s" % _tail(saved, 6))
			_check("%s: opened again as it was shown, the new part a step of its own, unturned" % name,
				shown == again and str(shown[-1]).contains("turn[-]") and shown.size() == steps.size() + 1)
			_check("%s: \"%s\" between the last step's parts and it" % [name, entry[2]], before == str(entry[2]))
			_check("%s: %s" % [name, "patched, as it was" if not whole else "written whole, as asked"],
				wrote.is_empty() != whole)


## The steps taken out and merged round a group of steps.
func _groups_case() -> void:
	print("\n== groups: LPub's MULTI_STEP round steps taken out and merged")
	ModelStore.patch_files = true
	# [what, the verb, the step index the timeline is on, refused]
	for edit: Array in [["take out the 4th (MULTI_STEP END after its STEP)", "delete", 3, false],
			["merge the 3rd and 4th", "merge", 2, false],
			["take out the 1st (BUFEXCHG STORE, then MULTI_STEP BEGIN)", "delete", 0, false],
			["take out the 2nd (the group's first)", "delete", 1, false],
			["merge the 2nd and 3rd (inside the group)", "merge", 1, false],
			["merge the 4th and 5th (RETRIEVE between)", "merge", 3, true],
			["take out the 5th (RETRIEVE starts it)", "delete", 4, true],
			["take out the 6th (after the RETRIEVE's)", "delete", 5, false]]:
		for whole: bool in [false, true]:
			ModelStore.patch_files = not whole
			var name: String = "%s, %s" % [edit[0], "written whole" if whole else "patched"]
			await _open(GROUPS, "groups")
			var steps: Array = _ops_steps("")
			var before: Array = _pages()
			var depth: int = _builder.history_depth()
			var said: String = _shell.change_steps(str(edit[1]), [], _ops_step("", steps[int(edit[2])]))
			await _frames(4)
			if bool(edit[3]):
				_check("%s: refused, with why (\"%s\"), the steps as they were, nothing to undo"
					% [name, said.left(140)], said.contains("BUFEXCHG A RETRIEVE")
					and said.contains("never be shown") and _pages() == before
					and _builder.history_depth() == depth)
				# The same verb by a session (edit_steps), by the booklet's number.
				var tools := AppTools.new()
				tools.app = _main
				tools.assistant = _main.get("_assistant")
				var by_mcp: String = str(await tools.run("edit_steps", {"op": str(edit[1]),
					"step": int(edit[2]) + 1}))
				await _frames(4)
				_check("%s: refused over MCP too (\"%s\")" % [name, by_mcp.left(100)],
					by_mcp.contains("BUFEXCHG A RETRIEVE") and _pages() == before
					and _builder.history_depth() == depth)
			else:
				_check("%s: done (\"%s\")" % [name, said.left(60)],
					not said.contains("never be shown") and _builder.history_depth() > depth)
			var shown: Array = _pages()
			var saved: String = _store.saved_text()
			var wrote: String = str(_store.get("last_whole"))
			await _open(saved, "groups")
			var again: Array = _pages()
			var wrong: String = _group_mid_step(saved)
			print("  %s (\"%s\"; %s): %s" % [name, said.get_slice("\n", 0).left(50),
				"patched" if wrote.is_empty() else "whole: " + wrote.left(50), "every group line after a STEP"
				if wrong.is_empty() else wrong])
			_check("%s: each MULTI_STEP line right after a STEP, as LPub3D reads it, both kept" % name,
				wrong.is_empty() and saved.count("MULTI_STEP BEGIN") == 1 and saved.count("MULTI_STEP END") == 1)
			_check("%s: opened again as it was shown (%d pages)" % [name, shown.size()], shown == again)
			_check("%s: the BUFEXCHG lines kept, as many, \"STORE\" after the same parts (%s)" % [name,
				_stored(saved)], saved.count("BUFEXCHG A STORE") == 1
				and saved.count("BUFEXCHG A RETRIEVE") == 1 and _stored(saved) == _stored(GROUPS))
			var retrieved: String = _retrieve_mid_step(saved)
			_check("%s: \"RETRIEVE\" at the head of the step it starts (%s)" % [name,
				"so" if retrieved.is_empty() else retrieved], retrieved.is_empty())
			if wrong.is_empty() and not whole and edit[2] == 3 and edit[1] == "delete":
				print("      the file round it:\n%s" % _round(saved, "MULTI_STEP END"))


## Parts moved a step across the RETRIEVE: by Shift-[ and Shift-] (Previous
## and Next step), dragged onto a step on the timeline (To step) and by
## edit_steps over MCP. Every part of the step the RETRIEVE starts moved to
## the step before, or every part of the step before it moved on, makes the
## two one step as a merge does: refused in a merge's words or a step taken
## out's, nothing changed, nothing to undo. One part moved across is done,
## and written on the RETRIEVE's side of its step (mkreview M1: up to it each
## left the RETRIEVE in the middle of a step, a part moved into the step it
## starts above it, put on and taken away at once).
func _moves_case() -> void:
	print("\n== moves: parts moved a step across a RETRIEVE")
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	# [what, the verb, the step index whose parts move, which of them, how,
	# refused, "below" or "above" the RETRIEVE the moved part is written]
	for edit: Array in [
			["every part of the 5th by Shift-[ (Previous step)", "prev", 4, "all", "keys", true, ""],
			["every part of the 4th by Shift-] (Next step)", "next", 3, "all", "keys", true, ""],
			["every part of the 5th by edit_steps prev", "prev", 4, "all", "mcp", true, ""],
			["every part of the 4th by edit_steps next", "next", 3, "all", "mcp", true, ""],
			["every part of the 4th dragged onto the 5th (To step)", "to", 3, "all", "bar", true, ""],
			["every part of the 4th by edit_steps to the 5th", "to", 3, "all", "mcp", true, ""],
			["one part of the 4th dragged onto the 5th (To step)", "to", 3, "one", "bar", false, "below"],
			["one part of the 4th by Shift-] (Next step)", "next", 3, "one", "keys", false, "below"],
			["one part of the 5th by edit_steps prev", "prev", 4, "one", "mcp", false, "above"]]:
		for whole: bool in [false, true]:
			ModelStore.patch_files = not whole
			var name: String = "%s, %s" % [edit[0], "written whole" if whole else "patched"]
			await _open(GROUPS, "groups")
			var unedited: String = _store.saved_text()
			var steps: Array = _ops_steps("")
			var from: Array = steps[int(edit[2])][1]
			var ids: Array = from if edit[3] == "all" else [from[0]]
			var before: Array = _pages()
			var depth: int = _builder.history_depth()
			var said: String = ""
			match str(edit[4]):
				"keys":
					_select_only(ids)
					var key := InputEventKey.new()
					key.keycode = KEY_BRACKETLEFT if edit[1] == "prev" else KEY_BRACKETRIGHT
					key.shift_pressed = true
					key.pressed = true
					root.push_input(key)
					await _frames(2)
					said = _shell.bar.status_text()
				"bar":
					# The timeline's drop of parts on a step (StepsBar._drop_data).
					said = _shell.change_steps("to", ids, _ops_step("", steps[int(edit[2]) + 1]))
				"mcp":
					var args: Dictionary = {"op": edit[1], "bricks": ids}
					if edit[1] == "to":
						args["step"] = int(edit[2]) + 2
					said = str(await tools.run("edit_steps", args))
			await _frames(4)
			if bool(edit[5]):
				_check("%s: refused, with why (\"%s\"), the steps as they were, nothing to undo"
					% [name, said.left(140)], said.contains("BUFEXCHG A RETRIEVE")
					and said.contains("would never be shown") and _pages() == before
					and _builder.history_depth() == depth and _store.saved_text() == unedited)
				continue
			_check("%s: done (\"%s\"), one undo step" % [name, said.left(60)],
				not said.contains("never be shown") and _builder.history_depth() == depth + 1)
			var shown: Array = _pages()
			var saved: String = _store.saved_text()
			var retrieved: String = _retrieve_mid_step(saved)
			_check("%s: \"RETRIEVE\" at the head of the step it starts (%s)" % [name,
				"so" if retrieved.is_empty() else retrieved], retrieved.is_empty())
			# One part fewer above it, the one moved into the step it starts;
			# or one more, the one moved out of it into the step before.
			var was: int = _above_retrieve(unedited)
			var now: int = _above_retrieve(saved)
			_check("%s: the part moved %s the RETRIEVE (%d parts above it, were %d)" % [name, edit[6],
				now, was], now == (was - 1 if edit[6] == "below" else was + 1))
			_builder.undo()
			await _frames(4)
			_check("%s: undone, the file as it was" % name, _store.saved_text() == unedited)
			_builder.redo()
			await _frames(4)
			_check("%s: redone, the same save" % name, _store.saved_text() == saved)
			await _open(saved, "groups")
			_check("%s: opened again as it was shown (%d pages)" % [name, shown.size()], _pages() == shown)
	ModelStore.patch_files = true

## What the booklet's pages show: each step's number, turn and parts.
func _pages() -> Array:
	var out: Array = []
	var lift: Vector3 = _store.lift()
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		var parts: Array = []
		for id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			if brick != null:
				var o: Vector3 = brick.transform.origin - lift
				parts.append("%s/%d@%.0f,%.0f,%.0f" % [brick.part_id, brick.color_code, o.x, o.y, o.z])
		parts.sort()
		var turn: Dictionary = BookletLooks.turn_at(_world, step.authored_in, step.authored_step)
		out.append("#%d turn[%s] [%s]" % [step.number, "-" if turn.is_empty()
			else "%s %s" % [turn.get("how", "REL"), str(turn["turn"])], " ".join(parts)])
	return out


## The first line before the saved file's first part line the opened file
## has not got, over the lines that place nothing.
static func _line_before_new(text: String, saved: String) -> String:
	var had: Dictionary = {}
	for line: String in text.split("\n"):
		had[line.strip_edges()] = int(had.get(line.strip_edges(), 0)) + 1
	var lines: PackedStringArray = saved.split("\n")
	for n: int in lines.size():
		var line: String = lines[n].strip_edges()
		if line.begins_with("1 ") and int(had.get(line, 0)) == 0:
			for k: int in range(n - 1, -1, -1):
				var before: String = lines[k].strip_edges()
				if not before.is_empty():
					return before
			return ""
		if had.has(line):
			had[line] = int(had[line]) - 1
	return "(no new line)"


## "" when every "!LPUB MULTI_STEP" line of [param text] follows a STEP or a
## ROTSTEP with no part between, BEGINs and ENDs in turn; else the first
## that does not.
static func _group_mid_step(text: String) -> String:
	var parts: bool = false
	var open: bool = false
	var n: int = 0
	for raw: String in text.split("\n"):
		n += 1
		var line: String = raw.strip_edges()
		var words: PackedStringArray = line.split(" ", false)
		if words.size() >= 2 and words[0] == "0" and words[1] in ["STEP", "ROTSTEP"]:
			parts = false
			continue
		if line.begins_with("0 FILE"):
			parts = false
			open = false
			continue
		if line.begins_with("0 !LPUB MULTI_STEP"):
			if parts:
				return "line %d, \"%s\", is inside a step" % [n, line]
			var begins: bool = line.ends_with("BEGIN")
			if begins == open:
				return "line %d, \"%s\", %s" % [n, line, "begins inside a group" if begins else "ends no group"]
			open = begins
			continue
		if words.size() >= 15 and words[0] == "1":
			parts = true
	return "a group never ended" if open else ""


## Where a "BUFEXCHG A RETRIEVE" of [param text] has a part of its step
## above it, so LPub3D never shows that part: "" for none.
static func _retrieve_mid_step(text: String) -> String:
	var parts: int = 0
	var n: int = 0
	for raw: String in text.split("\n"):
		n += 1
		var words: PackedStringArray = raw.strip_edges().split(" ", false)
		if words.size() >= 2 and words[0] == "0" and words[1] in ["STEP", "ROTSTEP", "FILE"]:
			parts = 0
		elif words.size() >= 15 and words[0] == "1":
			parts += 1
		elif words.size() >= 4 and words[1] == "BUFEXCHG" and words[3] == "RETRIEVE" and parts > 0:
			return "line %d, below %d parts of its step" % [n, parts]
	return ""


## How many parts [param text] puts on above its "BUFEXCHG A RETRIEVE".
static func _above_retrieve(text: String) -> int:
	var parts: int = 0
	for raw: String in text.split("\n"):
		var words: PackedStringArray = raw.strip_edges().split(" ", false)
		if words.size() >= 4 and words[1] == "BUFEXCHG" and words[3] == "RETRIEVE":
			return parts
		if words.size() >= 15 and words[0] == "1":
			parts += 1
	return -1


## The parts above "BUFEXCHG A STORE", the ones LPub3D stores (sorted).
static func _stored(text: String) -> String:
	var parts: Array = []
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 BUFEXCHG A STORE"):
			parts.sort()
			return "%d parts, %s" % [parts.size(), str(" | ".join(parts).hash())]
		if line.begins_with("1 "):
			parts.append(line)
	return "no STORE"


static func _tail(text: String, many: int) -> String:
	var lines: PackedStringArray = text.strip_edges().split("\n")
	return "\n".join(Array(lines.slice(maxi(lines.size() - many, 0))).map(
		func(l: String) -> String: return "        | " + l.strip_edges()))


static func _round(text: String, words: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		if lines[n].contains(words):
			return "\n".join(Array(lines.slice(maxi(n - 5, 0), mini(n + 4, lines.size()))).map(
				func(l: String) -> String: return "        | " + l.strip_edges()))
	return "        (none)"
