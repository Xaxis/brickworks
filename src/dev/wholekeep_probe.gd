## A model written whole keeps what its file carried: its sub-model files,
## its comments and other programs' lines beside the parts they were beside,
## and its TEXMAP blocks round the parts they cover (wholekeep).
##
##   godot --headless --path . --script src/dev/wholekeep_probe.gd
##   WK_CASES=ldcad,own,built,castle   those files only
##
## Up to wholekeep every edit that makes a save write the model whole (any
## edit of the app's own file; on someone else's a step edit of a file with
## no steps, a sub-assembly made, a copy put down...) rebuilt the file from
## what the app models and dropped what it does not, in silence: an MPD's
## sub-models flattened into the model's own section under "0 !BRICKWORKS
## IN" lines once its copies were built in its steps (the castle: 11
## sections to 1 and 420 IN lines), so LDCad, LDView, Studio and LPub no
## longer open them as sub-models; every comment but a sub-model's head's
## (the castle's "0 // Designed by ..."); and a TEXMAP block round a part in
## a model's section, so a printed part lost its picture (dkfix N2).
##
## Each file here is opened as the app opens one, given one edit as a person
## makes it, and written as Save writes it (ModelStore.to_text with steps).
## Its structure is then held to the file's: every section it had is still a
## section, placed as often as before but for what the edit placed; no IN
## line where the file had none; every comment and line of another program
## still in the file, in its section, before the same part or sub-model it
## was before; every TEXMAP block still round the parts it covered, with its
## picture, and its points where they stand from its part (a part moved, or
## written in another section's frame, moves its picture). The edits: add,
## move, remove, recolour, group (a sub-assembly made), ungroup, swap, Plan
## steps, Lay (each surface laid), paste, and where the save is whole the
## printed tile lifted (its TEXMAP NEXT with it). The saved file opens
## again as the model saved (each part in place, colour, copy and step), and
## the edit undone writes the file's structure again. The files:
## - ldcad: an LDCad-made MPD with no steps, a wing placed twice with its
##   engine nested in it, a tower with a panel whose print is a TEXMAP START
##   / FALLBACK / END block, a TEXMAP NEXT, CYLINDRICAL and SPHERICAL blocks,
##   comments and LDCad's lines in each section and two !DATA pictures; each
##   edit once alone and once after a step edit (Plan steps: written whole);
## - own: the same file as the app's own (Author: Brickworks), which every
##   edit writes whole;
## - built: the app's own file whose wings, each with its engine, are built a
##   course of each in turn and keep their sections (BUILT_META): read first
##   with each part in the step its line says, then each edit;
## - castle: models/castle.ldr (the app's own, 11 sections, a comment of
##   its own) and the same as someone else's file, given Plan steps.
extends SceneTree

const CASTLE := "res://models/castle.ldr"
## A picture, one pixel, as a !DATA section carries it.
const PIXEL := "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

const LDCAD := """0 FILE wk_house.ldr
0 Workshop
0 Name: wk_house.ldr
0 Author: Jane Builder
0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt
0 // Built in LDCad for the wholekeep probe
0 // the floor
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 80 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 // the two wings, one each side
1 16 -100 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 16 180 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
0 !TEXMAP NEXT PLANAR -20 -32 -10 20 -32 -10 -20 -32 10 sign.png
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3068b.dat
0 !TEXMAP START CYLINDRICAL 80 -24 0 80 -48 0 100 -24 0 360 sign.png
1 14 80 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
0 !TEXMAP END
1 16 40 -24 40 1 0 0 0 1 0 0 0 1 tower.ldr
0 !LDCAD GROUP_NXT [ids=1] [nrs=-1]
1 1 0 -24 -20 1 0 0 0 1 0 0 0 1 3024.dat
1 7 -40 0 -60 1 0 0 0 1 0 0 0 1 3005.dat
1 7 -20 0 -60 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Jane Builder
0 // a wing: a plate and its engine
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
0 // its engine, under the plate
1 16 0 8 0 1 0 0 0 1 0 0 0 1 engine.ldr
0 NOFILE
0 FILE engine.ldr
0 Engine
0 Name: engine.ldr
0 Author: Jane Builder
0 // a round brick, its print wrapped round it
0 !TEXMAP START SPHERICAL 0 0 0 0 -24 0 10 0 0 360 180 sign.png
1 0 0 0 0 1 0 0 0 1 0 0 0 1 3062b.dat
0 !TEXMAP END
1 71 0 24 0 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
0 FILE tower.ldr
0 Tower
0 Name: tower.ldr
0 Author: Jane Builder
0 // the tower's panel carries the sign
1 7 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 !TEXMAP START PLANAR -20 -24 -10 20 -24 -10 -20 0 -10 panel.png
0 !: 1 15 0 -24 0 1 0 0 0 1 0 0 0 1 4865b.dat
0 !TEXMAP FALLBACK
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 4865b.dat
0 !TEXMAP END
0 // the roof
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat
0 NOFILE
0 !DATA sign.png
0 !: %s
0 !DATA panel.png
0 !: %s
""" % [PIXEL, PIXEL]

## The app's own file whose two wings are built in its steps, a course of
## each in turn, each with the engine nested in it, and keep the sections the
## file has (LdrModel.BUILT_META): the first wing's plate in step 0 and its
## engine in 2, the second's in 1 and 3.
const BUILT := """0 FILE wk_built.ldr
0 Built house
0 Name: wk_built.ldr
0 Author: Brickworks
0 !BRICKWORKS AUTHORED_STEPS
0 // the app's own file, its wings built a course of each in turn
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3068b.dat
0 // the first wing
0 !BRICKWORKS BUILT 0=0 1=2
1 16 -100 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
0 STEP
0 // the second wing
0 !BRICKWORKS BUILT 0=1 1=3
0 !BRICKWORKS COPY 2
1 16 180 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
0 STEP
0 STEP
1 7 -40 0 -60 1 0 0 0 1 0 0 0 1 3005.dat
1 7 -20 0 -60 1 0 0 0 1 0 0 0 1 3005.dat
1 14 30 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Brickworks
0 // a wing: a plate and its engine
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
0 STEP
0 // its engine, under the plate
0 !BRICKWORKS BUILT 0=1
1 16 0 8 0 1 0 0 0 1 0 0 0 1 engine.ldr
0 NOFILE
0 FILE engine.ldr
0 Engine
0 Name: engine.ldr
0 Author: Brickworks
1 0 0 0 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 71 0 24 0 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
"""
## Each of its parts as it opens: part, colour, copy, step in the model's.
const BUILT_READ: Array = ["3001 4  step 0", "3068b 15  step 0", "3062b 14  step 3",
	"3020 2 Wing#1 step 0",
	"3062b 0 Wing#1/Engine#1 step 2", "3005 71 Wing#1/Engine#1 step 2", "3020 2 Wing#2 step 1",
	"3062b 0 Wing#2/Engine#2 step 3", "3005 71 Wing#2/Engine#2 step 3", "3005 7  step 3"]

## The edits, each made as a person makes it ([method _edit]).
const EDITS: Array = ["none", "plan", "add", "move", "remove", "recolour", "group", "ungroup",
	"swap", "paste", "lay"]
## Edits only a whole write is held to: the printed tile (its TEXMAP NEXT)
## lifted, its picture's points moved with it. A patch of someone else's file
## writes the moved part's line alone (SourceFile), so its picture stays where
## the part was: not this unit's (FINDINGS).
const WHOLE_EDITS: Array = ["lift"]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _summary: Array = []


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


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
	var only: String = OS.get_environment("WK_CASES")
	var files: Array = ["ldcad", "own", "built", "castle"] if only.is_empty() \
		else Array(only.split(",", false))
	var own: String = LDCAD.replace("Jane Builder", "Brickworks")
	for file: String in files:
		match file:
			"ldcad":
				for edit: String in EDITS:
					await _case("ldcad", LDCAD, edit, false)
				for edit: String in EDITS + WHOLE_EDITS:
					if edit != "none" and edit != "plan":
						await _case("ldcad", LDCAD, edit, true)
			"own":
				for edit: String in EDITS + WHOLE_EDITS:
					await _case("own", own, edit, false)
			"built":
				await _open(BUILT)
				var read: Dictionary = _state()
				var missing: Array = BUILT_READ.filter(func(want: String) -> bool:
					return not (read["parts"] as Array).any(func(line: String) -> bool:
						return line.begins_with(want + " at ")))
				var stepped: bool = (read["units"] as Dictionary).values().all(
					func(said: Variant) -> bool: return str(said) == "in its parent's")
				_check("built: each part opens in the step its BUILT line says%s" % (""
					if missing.is_empty() and stepped else ": not %s; %s in %s" % [str(missing),
					str(read["units"]), str(read["parts"])]), missing.is_empty() and stepped)
				for edit: String in EDITS + WHOLE_EDITS:
					if edit != "ungroup":
						await _case("built", BUILT, edit, false)
			"castle":
				var castle: String = FileAccess.get_file_as_string(CASTLE)
				await _case("castle", castle, "plan", false)
				await _case("castle", castle, "move", false)
				await _case("castle", castle, "part", false)
				await _case("castle (someone else's)", castle.replace("0 Author: Brickworks",
					"0 Author: A. Builder [abuilder]"), "plan", false)
			_:
				_check("no such file %s" % file, false)
	print("\n%-34s %-6s %-8s %s" % ["file, edit", "whole", "lost", "what"])
	for row: Array in _summary:
		print("%-34s %-6s %-8s %s" % row)
	print("\nwholekeep probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- a case ------------------------------------------------------------------


## [param text] opened, given [param edit] (after a step edit where
## [param planned]), saved, held to the file, opened again and undone.
func _case(name: String, text: String, edit: String, planned: bool) -> void:
	var what: String = "%s, %s%s" % [name, "Plan steps then " if planned else "", edit]
	# WHOLEKEEP_ONLY=castle runs the cases of the files so named alone.
	var only: String = OS.get_environment("WHOLEKEEP_ONLY")
	if not only.is_empty() and not name.begins_with(only):
		return
	print("\n== %s" % what)
	await _open(text)
	var depth: int = _builder.history_depth()
	var before: Dictionary = _structure(text)
	if planned:
		await _edit("plan")
	var allowed: Dictionary = await _edit(edit)
	if allowed.has("refused"):
		_check("%s: %s" % [edit, allowed["refused"]], false)
		_summary.append([what, "-", "-", "edit refused"])
		return
	var edited: Dictionary = _state()
	var saved: String = _store.to_text("model", true)
	# Each case's file as opened and as saved, in the run's data folder
	# (probe.sh keeps it when a check fails): user://wholekeep/.
	DirAccess.make_dir_recursive_absolute("user://wholekeep")
	var stem: String = "user://wholekeep/" + what.validate_filename().replace(" ", "_")
	for pair: Array in [[".opened.ldr", text], [".saved.ldr", saved]]:
		var file := FileAccess.open(stem + str(pair[0]), FileAccess.WRITE)
		if file != null:
			file.store_string(str(pair[1]))
	var whole: String = str(_store.last_whole)
	var own_file: bool = _store.call("_live_source") == null
	var written: String = "whole" if own_file or not whole.is_empty() else "patch"
	if not whole.is_empty():
		print("  (written whole: %s)" % whole)
	var after: Dictionary = _structure(saved)
	var lost: Array = _lost(before, after, allowed)
	var changed: int = _changed_lines(text, saved)
	print("  lines changed: %d of %d" % [changed, text.split("\n").size()])
	# One part put down or moved in the castle: its line, and the floor line
	# a whole save of the app's own file pins (ModelFloor.unsaid).
	# Its STEP lines aside: the steps an own file's whole write gives it are
	# stepkeep2's (pre261 reads the castle's 2,364 parts in other steps).
	if name == "castle" and edit in ["part", "move"]:
		var changes: Array = _changes(text, saved)
		var other: Array = changes.filter(func(c: String) -> bool: return c.substr(2) != "0 STEP")
		print("  STEP lines changed: %d" % (changes.size() - other.size()))
		if not _check("%s: the part's lines changed and the floor's, no more but STEP lines (%d)"
				% [what, other.size()], other.size() <= 3):
			print("      " + "\n      ".join(other.slice(0, 24)))
	if not _check("%s: the file's structure kept: %d lost%s" % [what, lost.size(),
			"" if lost.is_empty() else "\n      " + "\n      ".join(lost.slice(0, 14))],
			lost.is_empty()):
		print("    | " + "\n    | ".join(Array(saved.split("\n")).slice(0, 120).map(
			func(line: String) -> String: return line.left(120))))
	_summary.append([what, written, str(lost.size()), _kinds(lost)])
	await _open(saved)
	var now: Dictionary = _state()
	# A part or copy put down in no step comes back in the step a save put it in.
	var parts: Array = _unlike(edited["parts"], now["parts"], true)
	_check("...opened again: %d of %d parts not as saved%s" % [parts.size(),
		(edited["parts"] as Array).size(), "" if parts.is_empty() else ": " + str(parts[0])],
		parts.is_empty())
	var units_same: bool = now["tree"] == edited["tree"]
	for unit: String in edited["units"]:
		if str(edited["units"][unit]) != "-1" and str((now["units"] as Dictionary).get(unit, "")) \
				!= str(edited["units"][unit]):
			units_same = false
	_check("...the same copies, each in its step%s" % ("" if units_same
		else ": %s, %s against %s, %s" % [str(now["tree"]),
		str(now["units"]), str(edited["tree"]), str(edited["units"])]), units_same)
	var again: String = _store.to_text("model", true)
	var twice: Array = _lost(after, _structure(again), {})
	_check("...saved again: %d more lost%s" % [twice.size(), "" if twice.is_empty()
		else ": " + str(twice[0])], twice.is_empty())
	# Undone in the model as edited: the file's structure again.
	await _open(text)
	if planned:
		await _edit("plan")
	allowed = await _edit(edit)
	_back_to(depth)
	await _frames(4)
	var undone: Array = _lost(before, _structure(_store.to_text("model", true)), {})
	_check("...undone: %d of the file's lost%s" % [undone.size(), "" if undone.is_empty()
		else ": " + str(undone[0])], undone.is_empty())


## [param edit] made, as a person makes it. What the structure check allows
## it to change: "sections" -> {name: true} it may move lines out of,
## "placed" -> {name: change in how often it is placed}, "swapped" true.
func _edit(edit: String) -> Dictionary:
	var main_parts: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and Assemblies.path_of(brick).is_empty():
			main_parts.append(brick)
	var by_part := func(part_id: String) -> int:
		for brick: BrickWorld.Brick in main_parts:
			if brick.part_id == part_id:
				return brick.id
		return -1
	match edit:
		"none":
			return {}
		"plan":
			var part: int = int((main_parts[main_parts.size() - 1] as BrickWorld.Brick).id)
			var said: String = _shell.change_steps("next", [part], _step_holding(part))
			print("  plan: %s" % said.get_slice("\n", 0).left(100))
			await _frames(4)
			return {}
		"add":
			var wing: String = _first_path("Wing")
			if wing.is_empty():
				return {"refused": "no wing"}
			_shell.assemblies.enter(wing)
			var plate: int = -1
			for brick: BrickWorld.Brick in _world.bricks():
				if Assemblies.path_of(brick) == wing and brick.part_id == "3020":
					plate = brick.id
			_select_only([plate])
			(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
			var put: int = await _put_down(true)
			_shell.assemblies.leave_to("")
			print("  add: a plate put down in %s (%d)" % [wing, put])
			return {} if put > 0 else {"refused": "nothing put down"}
		"move":
			# Up into the air, clear of everything: a move refused for a
			# part in the way is no move.
			var mover: int = by_part.call("3024")
			if mover < 0 and not main_parts.is_empty():
				mover = (main_parts[0] as BrickWorld.Brick).id
			_select_only([mover])
			var moved: int = _builder.move_selection(Vector3i(0, 200, 0))
			await _frames(4)
			return {} if moved > 0 else {"refused": "nothing moved"}
		"part":
			# One part put down on the model's own, as a person adds one
			# (stepkeep2's flatq: on pre261 the castle's save changed 4,431
			# lines for it).
			if main_parts.is_empty():
				return {"refused": "no part of the model's own"}
			_select_only([(main_parts[0] as BrickWorld.Brick).id])
			(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
			var placed_one: int = await _put_down(true)
			return {} if placed_one > 0 else {"refused": "nothing put down"}
		"lift":
			_select_only([by_part.call("3068b")])
			var lifted: int = _builder.move_selection(Vector3i(0, 200, 0))
			await _frames(4)
			return {} if lifted > 0 else {"refused": "nothing lifted"}
		"remove":
			_select_only([by_part.call("3001")])
			var taken: int = _builder.remove_selection()
			await _frames(4)
			return {} if taken > 0 else {"refused": "nothing taken off"}
		"recolour":
			_select_only([by_part.call("3068b")])
			var painted: int = _builder.paint_selection(1)
			await _frames(4)
			return {} if painted > 0 else {"refused": "nothing painted"}
		"group":
			var two: Array = []
			for brick: BrickWorld.Brick in main_parts:
				if brick.part_id == "3005":
					two.append(brick.id)
			if two.size() < 2:
				return {"refused": "no two bricks to make a sub-assembly of"}
			_select_only(two)
			_shell.run("make_submodel")
			await _frames(2)
			print("  make_submodel: %s" % _name_it("Made Here"))
			await _frames(4)
			_shell.assemblies.leave_to("")
			return {"placed": {"made_here.ldr": 1}}
		"ungroup":
			var tower: String = _first_path("Tower")
			if tower.is_empty():
				return {"refused": "no tower"}
			_select_assembly(tower)
			_shell.run("leave_submodel")
			await _frames(6)
			return {"sections": {"tower.ldr": true}, "placed": {"tower.ldr": -1}}
		"swap":
			# The model's own round brick made a 2 x 2 one, else a square 1 x 1
			# (built's stands beside a tile, which a 2 x 2 runs into).
			var swapped := Vector2i.ZERO
			for into: String in ["6143", "3005"]:
				for brick: BrickWorld.Brick in main_parts:
					if brick.part_id == "3062b" and swapped.x == 0:
						_select_only([brick.id])
						swapped = _builder.replace_selection(into, true)
			await _frames(4)
			return {"swapped": true} if swapped.x > 0 else {"refused": "nothing swapped (%s)" % swapped}
		"paste":
			var wing: String = _first_path("Wing")
			_select_assembly(wing)
			(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
			# A wing built in the model's steps (built's) is put down as a copy
			# with steps of its own, so the two kinds of copy of one sub-model
			# cannot be written as one section: it is written from the new one,
			# and the two built in the model's steps after IN lines, each with
			# its engine (LdrModel.built_sections), their lines with them.
			var source_built: bool = int(_world.unit_steps.get(wing, -1)) == AuthorSteps.IN_PARENT
			var had: Dictionary = _top_copies()
			var put: int = await _put_down(false)
			_shell.assemblies.leave_to("")
			if put <= 0:
				return {"refused": "nothing put down"}
			var mixed: bool = false
			for top: String in _top_copies():
				if source_built and not had.has(top) \
						and int(_world.unit_steps.get(top, -1)) != AuthorSteps.IN_PARENT:
					mixed = true
			return {"placed": {"wing.ldr": 1}, "flat": {"wing.ldr": 2, "engine.ldr": 0}, "in": 4} \
				if mixed else {"placed": {"wing.ldr": 1}}
		"lay":
			# Edit > Finish the surfaces..., its Lay: tiles and slopes put on
			# and parts swapped as one undo step (FinishBar).
			_shell.run("finish_surfaces")
			await _frames(2)
			var bar: FinishBar = _main.get("_finish_made")
			if bar == null:
				return {"refused": "no finish bar"}
			var until: int = Time.get_ticks_msec() + 300000
			while Time.get_ticks_msec() < until and (bar.busy or not bar.visible):
				await process_frame
			var laid: Dictionary = await bar.lay_now()
			await _frames(6)
			bar.close()
			await _frames(2)
			print("  lay: %d parts in %d places" % [int(laid.get("parts", 0)),
				int(laid.get("laid", 0))])
			return {"swapped": true, "laid": true} if int(laid.get("parts", 0)) > 0 \
				else {"refused": "nothing laid (%s)" % str(bar.counts())}
		"plan_only":
			return {}
	return {"refused": "no such edit"}


# -- the file's structure ------------------------------------------------------


## What a file's structure is: each section by its FILE name (lower case,
## "" before the first) -> {"placing": name -> how many lines place it,
## "kept": [[the line, the part or sub-model the next placing line names,
## whether it is in the section's head: before its first part or step]],
## "maps": [[the TEXMAP block's lines but its parts', the parts it covers]]};
## a TEXMAP's points and a block's own geometry ("0 !:") as they stand from
## the part they are round ([method _from_part]), so a write that moves the
## part or frames its section anew keeps them only where they move with it;
## "in": how many IN lines; "data": the !DATA names.
static func _structure(text: String) -> Dictionary:
	var sections: Dictionary = {}
	var section: String = ""
	var waiting: Array = []        ## kept lines waiting for the next placing line
	var block: Array = []          ## an open TEXMAP block: [its lines, its parts]
	var in_lines: int = 0
	var data: Dictionary = {}
	var in_data: bool = false
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	for raw: String in lines:
		var line: String = raw.strip_edges()
		var words: PackedStringArray = line.split(" ", false)
		if words.is_empty():
			continue
		if in_data and line.begins_with("0 !:"):
			continue
		in_data = false
		var at: Dictionary = sections.get(section, {"placing": {}, "kept": [], "maps": []})
		sections[section] = at
		if words[0] == "1" and words.size() >= 15:
			(at.get_or_add("lines", []) as Array).append(" ".join(words))
			var named: String = " ".join(words.slice(14)).to_lower()
			if not block.is_empty():
				(block[1] as Array).append(named.get_file())
				if block[2] == null:
					block[2] = words
			# A section's head (what is before its first part or sub-model)
			# is beside the head; a line before the part it is about is that
			# part's too where the part is now the section's first.
			var head: bool = not at.has("placed")
			at["placed"] = true
			for kept: String in waiting:
				(at["kept"] as Array).append([_from_part(kept, words), named.get_file(), head])
			waiting.clear()
			if named.ends_with(".ldr") or named.ends_with(".mpd"):
				at["placing"][named] = int((at["placing"] as Dictionary).get(named, 0)) + 1
			continue
		if words[0] != "0" or words.size() < 2:
			continue
		var keyword: String = words[1].to_upper()
		if keyword == "FILE":
			for kept: String in waiting:
				(at["kept"] as Array).append([kept, "(end)", false])
			waiting.clear()
			section = " ".join(words.slice(2)).to_lower()
			continue
		if keyword == "NOFILE":
			for kept: String in waiting:
				(at["kept"] as Array).append([kept, "(end)", false])
			waiting.clear()
			continue
		if keyword == "!DATA":
			data[" ".join(words.slice(2)).to_lower()] = true
			in_data = true
			continue
		if keyword == "!TEXMAP" and words.size() > 2 and words[2].to_upper() == "START":
			block = [[line], [], null]
			continue
		if not block.is_empty() and (keyword == "!TEXMAP" or keyword.begins_with("!:")):
			(block[0] as Array).append(line)
			if keyword == "!TEXMAP" and words.size() > 2 and words[2].to_upper() == "END":
				if block[2] != null:
					var part: PackedStringArray = block[2]
					block[0] = (block[0] as Array).map(func(said: String) -> String:
						return _from_part(said, part))
				(at["maps"] as Array).append(block)
				block = []
			continue
		if keyword == "!BRICKWORKS":
			if words.size() > 2 and words[2].to_upper() == "IN":
				in_lines += 1
				# What waits before it is the copy's, by its definition: the
				# copy's last segment, "Wing#1" -> wing.ldr.
				if words.size() > 3:
					var copy: String = " ".join(words.slice(3)).get_slice("/",
						" ".join(words.slice(3)).count("/")).get_slice("#", 0).to_lower() + ".ldr"
					var head: bool = not at.has("placed")
					at["placed"] = true
					for kept: String in waiting:
						(at["kept"] as Array).append([kept, copy, head])
					waiting.clear()
			continue
		if keyword in ["STEP", "ROTSTEP"]:
			at["placed"] = true
			continue
		if keyword in ["NAME:", "AUTHOR:"] or line == "0":
			continue
		# The title: the first line of a section that is none of these.
		if (at["kept"] as Array).is_empty() and waiting.is_empty() \
				and not at.has("placed") and not keyword.begins_with("!") \
				and not keyword.begins_with("//") and not at.has("title"):
			at["title"] = line
			continue
		waiting.append(line)
	if not waiting.is_empty():
		var at: Dictionary = sections.get(section, {"placing": {}, "kept": [], "maps": []})
		for kept: String in waiting:
			(at["kept"] as Array).append([kept, "(end)", false])
		sections[section] = at
	return {"sections": sections, "in": in_lines, "data": data}


## The lines [param _changed_lines] counts, "+ line" or "- line".
static func _changes(text: String, saved: String) -> Array:
	var count: Dictionary = {}
	for line: String in text.replace("\r", "").split("\n"):
		var said: String = " ".join(line.strip_edges().split(" ", false))
		if not said.is_empty():
			count[said] = int(count.get(said, 0)) + 1
	var out: Array = []
	for line: String in saved.replace("\r", "").split("\n"):
		var said: String = " ".join(line.strip_edges().split(" ", false))
		if said.is_empty():
			continue
		if int(count.get(said, 0)) > 0:
			count[said] = int(count[said]) - 1
		else:
			out.append("+ " + said.left(90))
	for said: String in count:
		for _n: int in int(count[said]):
			out.append("- " + said.left(90))
	return out


## How many lines [param saved] has that [param text] has not, and the other
## way round, each line by its words.
static func _changed_lines(text: String, saved: String) -> int:
	var count: Dictionary = {}
	for line: String in text.replace("\r", "").split("\n"):
		var said: String = " ".join(line.strip_edges().split(" ", false))
		if not said.is_empty():
			count[said] = int(count.get(said, 0)) + 1
	var added: int = 0
	for line: String in saved.replace("\r", "").split("\n"):
		var said: String = " ".join(line.strip_edges().split(" ", false))
		if said.is_empty():
			continue
		if int(count.get(said, 0)) > 0:
			count[said] = int(count[said]) - 1
		else:
			added += 1
	var removed: int = 0
	for said: String in count:
		removed += int(count[said])
	return added + removed


## What of [param before]'s structure [param after] has not got, but what
## [param allowed] lets the edit change ([method _edit]).
static func _lost(before: Dictionary, after: Dictionary, allowed: Dictionary) -> Array:
	var out: Array = []
	var was: Dictionary = before["sections"]
	var now: Dictionary = after["sections"]
	var free: Dictionary = allowed.get("sections", {})
	var placed: Dictionary = allowed.get("placed", {})
	var flat: Dictionary = allowed.get("flat", {})
	if int(after["in"]) > int(before["in"]) + int(allowed.get("in", 0)):
		out.append("sections: %d IN lines, the file had %d" % [after["in"], before["in"]])
	for name: String in was:
		if name.is_empty():
			continue
		if not now.has(name) and not free.has(name):
			out.append("sections: %s is no longer a section" % name)
	# How often each sub-model is placed, all told.
	var placing_was: Dictionary = {}
	var placing_now: Dictionary = {}
	for name: String in was:
		for ref: String in (was[name] as Dictionary)["placing"]:
			placing_was[ref] = int(placing_was.get(ref, 0)) + int(was[name]["placing"][ref])
	for name: String in now:
		for ref: String in (now[name] as Dictionary)["placing"]:
			placing_now[ref] = int(placing_now.get(ref, 0)) + int(now[name]["placing"][ref])
	for ref: String in placing_was:
		var wanted: int = int(placing_was[ref]) + int(placed.get(ref, 0)) - int(flat.get(ref, 0))
		if int(placing_now.get(ref, 0)) != wanted and was.has(ref):
			out.append("placements: %s placed %d times, wanted %d" % [ref,
				int(placing_now.get(ref, 0)), wanted])
	# Each sub-model in the frame its file gave it: every line of its section
	# still in it as the file had it, and every line placing one, but what
	# the edit changes (a section taken apart, one written after IN lines, a
	# Lay, which may swap a part inside one).
	if not bool(allowed.get("laid", false)):
		var main_name: String = ""
		for name: String in was:
			if main_name.is_empty() and not name.is_empty():
				main_name = name
		for name: String in was:
			if name.is_empty() or free.has(name) or flat.has(name):
				continue
			var here_lines: Dictionary = {}
			for line: String in (now.get(name, {}) as Dictionary).get("lines", []):
				here_lines[line] = true
			var moved: Array = []
			for line: String in (was[name] as Dictionary).get("lines", []):
				var ref: String = line.get_slice(" ", line.count(" ")).to_lower()
				var placing: bool = ref.ends_with(".ldr") or ref.ends_with(".mpd")
				if name == main_name and not placing or free.has(ref) or flat.has(ref):
					continue
				if not here_lines.has(line):
					moved.append(line)
			for line: String in moved.slice(0, 3):
				out.append("frame: %s's line not as the file had it: %s" % [_said(name), line.left(64)])
			if moved.size() > 3:
				out.append("frame: and %d more of %s's" % [moved.size() - 3, _said(name)])
	# Each line kept: still in the file; in its section, before the same part.
	var everywhere: Dictionary = {}
	for name: String in now:
		for pair: Array in (now[name] as Dictionary)["kept"]:
			everywhere[pair[0]] = int(everywhere.get(pair[0], 0)) + 1
	for name: String in was:
		var here: Array = (now.get(name, {}) as Dictionary).get("kept", [])
		for pair: Array in (was[name] as Dictionary)["kept"]:
			var line: String = pair[0]
			if int(everywhere.get(line, 0)) <= 0:
				out.append("%s: lost from %s: %s" % [_kind(line), _said(name), line.left(70)])
				continue
			everywhere[line] = int(everywhere[line]) - 1
			if free.has(name):
				continue
			var found: bool = false
			for other: Array in here:
				if other[0] == line:
					found = true
					# A head line still in the head; any other before the part
					# it was before (one swapped is another part).
					var moved: bool = not bool(other[2]) if bool(pair[2]) \
						else pair[1] != "(end)" and other[1] != pair[1] \
							and not bool(allowed.get("swapped", false))
					if moved:
						out.append("%s: in %s before %s, was before %s: %s" % [_kind(line), _said(name),
							_where(other), _where(pair), line.left(60)])
					break
			# A copy written after IN lines ([param allowed]'s "flat"): its
			# section's lines and its placing line's in the section it is
			# written in, before it.
			if not found and (flat.has(name) or flat.has(str(pair[1]))):
				for other_name: String in now:
					for other: Array in (now[other_name] as Dictionary)["kept"]:
						found = found or other[0] == line and other[1] == pair[1]
			if not found:
				out.append("%s: out of its section %s: %s" % [_kind(line), _said(name), line.left(60)])
	# Each TEXMAP block: round as many parts, of the same lines.
	var maps_now: Array = []
	for name: String in now:
		for map: Array in (now[name] as Dictionary)["maps"]:
			maps_now.append([name, map])
	for name: String in was:
		for map: Array in (was[name] as Dictionary)["maps"]:
			var matched: bool = false
			for k: int in maps_now.size():
				var other: Array = maps_now[k][1]
				if other[0] == map[0] and (other[1] == map[1] or bool(allowed.get("swapped", false))
						and (other[1] as Array).size() == (map[1] as Array).size()) \
						and (maps_now[k][0] == name or free.has(name)):
					matched = true
					maps_now.remove_at(k)
					break
			if not matched:
				out.append("TEXMAP: lost from %s: %s round %s" % [_said(name), str(map[0][0]).left(50),
					str(map[1])])
	for name: String in before["data"]:
		if not (after["data"] as Dictionary).has(name):
			out.append("picture: !DATA %s lost" % name)
	return out


## [param line] as it stands from the part [param part] (a type-1 line's
## words) it is round: a TEXMAP START or NEXT with its three points, or a
## "0 !: 1" line with its place, in that part's own frame, to a tenth of an
## LDU. Any other line as it is.
static func _from_part(line: String, part: PackedStringArray) -> String:
	var words: PackedStringArray = line.split(" ", false)
	if words.size() < 3 or part.size() < 14:
		return line
	var inverse: Transform3D = _ld_transform(part, 2).affine_inverse()
	if words.size() >= 13 and words[1].to_upper() == "!TEXMAP" \
			and words[2].to_upper() in ["START", "NEXT"]:
		for k: int in 3:
			var at: int = 4 + k * 3
			var point: Vector3 = inverse * Vector3(words[at].to_float(), words[at + 1].to_float(),
				words[at + 2].to_float())
			words[at] = "%.1f" % (snappedf(point.x, 0.1) + 0.0)
			words[at + 1] = "%.1f" % (snappedf(point.y, 0.1) + 0.0)
			words[at + 2] = "%.1f" % (snappedf(point.z, 0.1) + 0.0)
		return " ".join(words)
	if words.size() >= 17 and words[1] == "!:" and words[2] == "1":
		var placed: Transform3D = inverse * _ld_transform(words, 4)
		var numbers := PackedStringArray()
		for v: Vector3 in [placed.origin, placed.basis.x, placed.basis.y, placed.basis.z]:
			for n: float in [v.x, v.y, v.z]:
				numbers.append("%.1f" % (snappedf(n, 0.1) + 0.0))
		return "0 !: 1 %s %s %s" % [words[3], " ".join(numbers), " ".join(words.slice(16))]
	return line


## The place twelve numbers say, from word [param from] of [param words] on:
## x y z, then the matrix a..i by rows, as LDraw writes them.
static func _ld_transform(words: PackedStringArray, from: int) -> Transform3D:
	var v: Array = []
	for n: int in 12:
		v.append(words[from + n].to_float())
	return Transform3D(Basis(Vector3(v[3], v[6], v[9]), Vector3(v[4], v[7], v[10]),
		Vector3(v[5], v[8], v[11])), Vector3(v[0], v[1], v[2]))


static func _where(kept: Array) -> String:
	return "(head)" if bool(kept[2]) else str(kept[1])


static func _said(section: String) -> String:
	return section if not section.is_empty() else "(before the first FILE)"


static func _kind(line: String) -> String:
	if line.begins_with("0 //"):
		return "comment"
	if line.to_upper().begins_with("0 !TEXMAP"):
		return "TEXMAP"
	return "meta"


## What kinds of thing [param lost] has, for the summary.
static func _kinds(lost: Array) -> String:
	var kinds: Dictionary = {}
	for item: String in lost:
		var kind: String = item.get_slice(":", 0)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	var out := PackedStringArray()
	for kind: String in kinds:
		out.append("%s %d" % [kind, kinds[kind]])
	return ", ".join(out)


# -- the model -----------------------------------------------------------------


## Every part as it stands in the file's coordinates, with its copy and the
## rank of its step in its section, and each copy's step (kt3r_probe's).
func _state() -> Dictionary:
	var lift: Vector3 = _store.lift()
	var tree: Dictionary = {}
	var spaces: Dictionary = {}
	var bricks: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		bricks.append(brick)
		var path: String = Assemblies.path_of(brick)
		var at: String = ""
		for segment: String in Assemblies.segments(path):
			at = Assemblies.join(at, segment)
			tree[at] = true
		_add(spaces, _home(path), brick.step)
	for unit: String in tree:
		var step: int = int(_world.unit_steps.get(unit, -1))
		if step != AuthorSteps.IN_PARENT:
			_add(spaces, _home(Assemblies.parent_of(unit)), step)
	var ranks: Dictionary = {}
	for home: String in spaces:
		var steps: Array = (spaces[home] as Dictionary).keys()
		steps.sort()
		var rank: Dictionary = {}
		for step: int in steps:
			rank[step] = -1 if step < 0 else rank.size() - (1 if rank.has(-1) else 0)
		ranks[home] = rank
	var parts: Array = []
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var path: String = Assemblies.path_of(brick)
		var t := Transform3D(brick.transform.basis, brick.transform.origin - lift)
		var place := PackedStringArray()
		for v: Vector3 in [t.origin / 10.0, t.basis.x, t.basis.y, t.basis.z]:
			for n: float in [v.x, v.y, v.z]:
				place.append("%.1f" % (snappedf(n, 0.1) + 0.0))
		parts.append("%s %d %s step %d at %s" % [brick.part_id, brick.color_code, path,
			int(ranks[_home(path)][brick.step]), " ".join(place)])
	parts.sort()
	var units: Dictionary = {}
	for unit: String in tree:
		var step: int = int(_world.unit_steps.get(unit, -1))
		units[unit] = "in its parent's" if step == AuthorSteps.IN_PARENT \
			else str(ranks[_home(Assemblies.parent_of(unit))].get(step, step))
	var paths: Array = tree.keys()
	paths.sort()
	return {"parts": parts, "tree": paths, "units": units}


static func _add(spaces: Dictionary, home: String, step: int) -> void:
	if not spaces.has(home):
		spaces[home] = {}
	(spaces[home] as Dictionary)[step] = true


func _home(path: String) -> String:
	while not path.is_empty() and int(_world.unit_steps.get(path, -1)) == AuthorSteps.IN_PARENT:
		path = Assemblies.parent_of(path)
	return path


static func _unlike(a: Array, b: Array, loose: bool = false) -> Array:
	var have: Dictionary = {}
	for line: String in b:
		have[line] = int(have.get(line, 0)) + 1
	var out: Array = []
	for line: String in a:
		if int(have.get(line, 0)) > 0:
			have[line] = int(have[line]) - 1
		else:
			out.append(line)
	if loose and not out.is_empty():
		# One put down in no step (-1) is in whichever step the save gave it.
		var stepless: RegEx = RegEx.create_from_string(" step -?\\d+ ")
		var left: Dictionary = {}
		for line: String in have:
			for _n: int in int(have[line]):
				var key: String = stepless.sub(line, " step ? ")
				left[key] = int(left.get(key, 0)) + 1
		var still: Array = []
		for line: String in out:
			var key: String = stepless.sub(line, " step ? ")
			if line.contains(" step -1 ") and int(left.get(key, 0)) > 0:
				left[key] = int(left[key]) - 1
			else:
				still.append(line)
		out = still
	if out.is_empty() and a.size() != b.size():
		out.append("%d parts, %d before" % [b.size(), a.size()])
	return out


# -- driving it ----------------------------------------------------------------


func _first_path(definition: String) -> String:
	var paths: Array = Array(_shell.assemblies.paths())
	paths.sort()
	for path: String in paths:
		if Assemblies.definition(Assemblies.leaf(path)) == definition \
				and Assemblies.parent_of(path).is_empty():
			return path
	return ""


func _put_down(up: bool = false) -> int:
	var carry: Carry = _builder.carrying
	if carry == null:
		return 0
	var low := Vector3(INF, INF, INF)
	var high := -low
	for brick: BrickWorld.Brick in _world.bricks():
		low = low.min(brick.transform.origin)
		high = high.max(brick.transform.origin)
	var room: float = 4.0 * BrickLattice.STUD
	carry.stand_where_lifted(_builder.lattice, _builder)
	carry.pin()
	for k: int in 6:
		var by: Vector3 = Vector3(0.0, high.y - low.y + room * (k + 1), 0.0) if up \
			else Vector3(high.x - low.x + room * (k + 1), 0.0, 0.0)
		if carry.show_moved(Transform3D(Basis.IDENTITY, by), _builder.lattice, _builder):
			var put: int = _builder.place()
			await _frames(4)
			_builder.cancel_carry()
			return put
	_builder.cancel_carry()
	return 0


## The copies the model's own section places, by their paths.
func _top_copies() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var path: String = Assemblies.path_of(brick)
		if not path.is_empty():
			out[str(Assemblies.segments(path)[0])] = true
	return out


func _select_assembly(path: String) -> void:
	_shell.assemblies.leave_to(Assemblies.parent_of(path))
	_select_only(Array(_shell.assemblies.ids_under(path)))


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		if brick_id >= 0:
			_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _name_it(name: String) -> String:
	var verbs: EditVerbs = _main.get("_verbs")
	var field: LineEdit = verbs.get("_name_field")
	var dialog: ConfirmationDialog = verbs.get("_naming")
	if field == null or dialog == null or not dialog.visible:
		return "no naming dialog"
	field.text = name
	dialog.hide()
	dialog.confirmed.emit()
	return "named %s" % name


func _step_holding(brick_id: int) -> Instructions.Step:
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		if step.brick_ids.has(brick_id):
			return step
	return null


func _back_to(depth: int) -> void:
	while _builder.history_depth() > depth:
		_builder.undo()


func _open(text: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, "model")
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
