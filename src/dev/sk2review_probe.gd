## sk2review (2026-11-23): repros for the review of stepkeep2 (a file's STEP
## lines are its steps) and of its merge with wholekeep. A FAIL is a finding
## reproduced; each case says what it holds.
##
##   drag    a brick of the yard's first step dragged (picked up and put
##           down, as the mouse moves a part) onto the top of its step 5: in
##           the step of what it now rests on, as a moved part is
##           (AuthorSteps.follow_saved), not in the air from its old step
##   pair    two stacked bricks of the yard moved together onto that top by a
##           typed move, the upper one selected first, then the lower first:
##           the upper never in a step before the one it rests on
##           (the yard, YARD, since keepfix: the station's search for such
##           bricks found none, "0 tried", and each case asserts its count)
##   stack   ten bricks put one at a time each on the last, on the station's
##           top: how many steps they are in, held and as Plan steps plans them
##   mpd     an MPD of the app's own (three sections, a sub-model placed twice
##           and one nested, comments in each), Plan steps then Save: its
##           sections and comments kept, reopened in the steps saved, the whole
##           write the file; the same file as someone else's: Plan steps refused
##   castle  models/castle.ldr, Plan steps then Save: the same
##   into    the station put into a model whole (held_from): its saved steps
##           kept, as an open keeps them
##   hand    Plan steps asked over MCP (edit_steps plan) while the person holds
##           a part picked up: refused, or the part put down planned with the
##           rest, never the one part with a step and the model after it; and
##           Escape then puts the part back (control: edit_steps next instead)
##   looks   a step named (edit_steps name), then Plan steps: what it takes off
##           with the steps (the step's name) said in its words
##
## sk2fix's own, for its fixes:
##   redo      a drag and a stack, each undone and redone byte for byte, the
##             stack saved and opened again the same
##   ask       Plan steps pressed where two named steps come to share one:
##             asked first, with the count; confirmed, one name; one undo
##   heldlook  edit_steps name and the press of Plan steps while a part is
##             held: refused in words, Escape puts it back
##   fixtime   the follow's time on Orthanc as its own (16 ms a follow)
##
##   godot --headless --path . --script src/dev/sk2review_probe.gd
##   SK2R_ONLY=drag,pair,stack,mpd,castle,into,hand,looks,redo,ask,heldlook,fixtime   only those
##   -- --sk2r=drag,pair,...                     the same, as the suite gives it
##   SK2R_OUT=DIR                                the texts written there
extends SceneTree

const STATION := "res://models/station.ldr"
const CASTLE := "res://models/castle.ldr"
const AUTHORED := "0 !BRICKWORKS AUTHORED_STEPS"
const STACKS: Array = ["3001", "3002", "3003", "3004", "3005", "3008", "3009", "3010", "3622",
	"3020", "3021", "3022", "3023", "3024", "3710", "3666", "3460", "3795", "3034", "3832", "3623"]

## The owner's MPD of the app's own: a house on two bricks, a wing placed
## twice (each with its engine nested in it), a roof on both engines, a
## comment in every section, steps in each.
const HOUSE := """0 FILE sk_house.ldr
0 SK house
0 Name: sk_house.ldr
0 Author: Brickworks
0 // the owner's note on the house
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 80 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 // the two wings, one on each brick
1 16 0 -8 0 1 0 0 0 1 0 0 0 1 sk_wing.ldr
0 STEP
1 16 80 -8 0 1 0 0 0 1 0 0 0 1 sk_wing.ldr
0 STEP
0 // the roof, on both engines
1 1 40 -64 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 NOFILE
0 FILE sk_wing.ldr
0 SK wing
0 Name: sk_wing.ldr
0 Author: Brickworks
0 // a wing: a plate and its engine
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat
0 STEP
1 16 0 -32 0 1 0 0 0 1 0 0 0 1 sk_engine.ldr
0 STEP
0 NOFILE
0 FILE sk_engine.ldr
0 SK engine
0 Name: sk_engine.ldr
0 Author: Brickworks
0 // the engine, one brick
1 0 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
0 NOFILE
"""

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _bar: ModelBar
var _shell: Shell
var _out: String = ""
var _only: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	_out = OS.get_environment("SK2R_OUT")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	for _n: int in 30:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_bar = _main.get("_bar")
	_shell = _main.get("_shell")
	_store.keeps = true
	_only = OS.get_environment("SK2R_ONLY").split(",", false)
	# From the suite's list (tools/suite/headless.txt), which gives arguments
	# and no environment: a name of the probe's own, as main.tscn reads the
	# app's (--out, --model, --step...) from the same command line.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sk2r="):
			_only = arg.trim_prefix("--sk2r=").split(",", false)
	print("tree: %s" % ("stepkeep2 + wholekeep" if FileAccess.file_exists(
		"res://src/dev/wholekeep_probe.gd") else "stepkeep2"))
	if _asked("drag"):
		await _drag()
	if _asked("pair"):
		await _pair()
	if _asked("stack"):
		await _stack_up()
	if _asked("mpd"):
		await _mpd()
	if _asked("castle"):
		await _castle()
	if _asked("into"):
		await _into()
	if _asked("hand"):
		await _hand()
	if _asked("looks"):
		await _looks()
	if _asked("redo"):
		await _redo()
	if _asked("ask"):
		await _ask()
	if _asked("heldlook"):
		await _held_look()
	if _asked("fixtime"):
		await _fix_time()
	print("")
	print("%d FAILURE(S)" % _failures if _failures else "every case holds")
	quit(1 if _failures else 0)


func _asked(name: String) -> bool:
	return _only.is_empty() or _only.has(name)


# -- drag ----------------------------------------------------------------------


## A yard of the app's own that opens in its saved steps (steps_own): a
## column of five red 2 x 4 bricks, one a step (steps 1 to 5); beside it a
## blue 2 x 4 on the floor in step 1, and a green 2 x 4 in step 1 with
## another on it in step 2. The drag, the pair and the redo move these, by
## colour and place, onto the column's top: what the station's search found
## none of in sk2review's and sk2fix's runs ("0 tried"), so nothing was
## moved and neither FIX FIRST 1 nor FIX 3 was proven (keepfix).
const YARD := """0 Yard
0 Name: sk_yard.ldr
0 Author: Brickworks

1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 120 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 240 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 240 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 4 0 -72 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 4 0 -96 0 1 0 0 0 1 0 0 0 1 3001.dat
"""


## The yard opened ([constant YARD]): {"lone": the blue brick, "lower" and
## "upper": the green two, "top": the column's top}, ids; {} where it did not
## open so, said as a FAIL.
func _yard() -> Dictionary:
	var path: String = "user://sk2r_yard.ldr"
	_write(path, YARD)
	await _open(path)
	var red: Array = []
	var green: Array = []
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		match brick.color_code:
			1:
				out["lone"] = brick.id
			2:
				green.append(brick)
			4:
				red.append(brick)
	var by_height := func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.transform.origin.y < b.transform.origin.y
	red.sort_custom(by_height)
	green.sort_custom(by_height)
	if red.size() == 5 and green.size() == 2:
		out["top"] = (red[4] as BrickWorld.Brick).id
		out["lower"] = (green[0] as BrickWorld.Brick).id
		out["upper"] = (green[1] as BrickWorld.Brick).id
	var steps: Array = [int(_on_model_at(_plan()).get(int(out.get("lone", 0)), -1)),
		int(_on_model_at(_plan()).get(int(out.get("top", 0)), -1))]
	if not _check("yard: opens in its saved steps (%s), the blue brick in step %d, the column's top in step %d"
			% [_own_steps(), steps[0] + 1, steps[1] + 1], _own_steps() and out.size() == 4
			and steps == [0, 4]):
		return {}
	return out


## [param id] picked up and put down [param by] further, as the mouse drags a
## part (Builder.lift_selection, Carry.show_moved, Builder.place): the id it
## is put down as, or a word for the stage that refused it.
func _dragged(id: int, by: Vector3) -> Variant:
	_builder.clear_selection()
	_builder.selection[id] = true
	if _builder.lift_selection() == 0:
		return "not lifted"
	var carry: Carry = _builder.carrying
	carry.stand_where_lifted(_builder.lattice, _builder)
	carry.pin()
	if not carry.show_moved(Transform3D(Basis.IDENTITY, by), _builder.lattice, _builder):
		_builder.cancel_carry()
		await _frames(1)
		return "not shown there"
	if _builder.place() == 0:
		_builder.cancel_carry()
		await _frames(1)
		return "not put down"
	await _edited()
	var put: Array = _put_ids(_builder.last_step())
	if put.size() != 1:
		return "%d put down" % put.size()
	return int(put[0])


func _drag() -> void:
	print("\n== drag (yard): a brick of the first step dragged onto the top of step 5")
	var yard: Dictionary = await _yard()
	if yard.is_empty():
		return
	var at: Dictionary = _on_model_at(_plan())
	var brick: BrickWorld.Brick = _world.get_brick(int(yard["lone"]))
	var under: BrickWorld.Brick = _world.get_brick(int(yard["top"]))
	var from: Transform3D = brick.transform
	var by: Vector3 = under.transform.origin + Vector3(0.0, _rise(brick), 0.0) - from.origin
	var air_before: Array = await _air(_store.to_text(_store.title, true))
	var tried: int = 1
	var put: Variant = await _dragged(brick.id, by)
	_check("drag: %d tried, the brick dragged onto the top (%s)" % [tried, put], put is int)
	if not put is int:
		return
	var now: Dictionary = _on_model_at(_plan())
	var rests: Array = _rests(int(put)).map(func(b: BrickWorld.Brick) -> int: return b.id)
	var shown: int = int(now.get(int(put), -1))
	var support: int = int(now.get(under.id, -1))
	_check("drag: shown in step %d, on the model no earlier than what it rests on (step %d; it rests on it: %s)"
		% [shown + 1, support + 1, rests.has(under.id)], shown >= support and support == int(at[under.id])
		and rests.has(under.id))
	var text_after: String = _store.to_text(_store.title, true)
	var air_after: Array = await _air(text_after)
	_check("drag: the share's steps test, parts put down in the air: %d before, %d after"
		% [int(air_before[0]), int(air_after[0])], int(air_after[0]) >= 0
		and int(air_after[0]) <= int(air_before[0]))
	_keep("drag_yard.ldr", text_after)
	# The same act as a typed move: followed (stepkeep's C), the control.
	_builder.undo()
	await _frames(2)
	var again: BrickWorld.Brick = _brick_at(brick.part_id, from)
	if _check("drag: undone, the brick back where it was", again != null):
		_builder.clear_selection()
		_builder.selection[again.id] = true
		if _builder.move_selection_by(by) > 0:
			await _edited()
			var typed: Dictionary = _on_model_at(_plan())
			print("  control: the same move typed: shown in step %d (support %d)"
				% [int(typed.get(again.id, -1)) + 1, int(typed.get(under.id, -1)) + 1])
			_builder.undo()
			await _frames(2)


# -- pair ----------------------------------------------------------------------


func _pair() -> void:
	print("\n== pair (yard): two stacked bricks moved together onto the top of step 5")
	var tried: int = 0
	for upper_first: bool in [true, false]:
		var yard: Dictionary = await _yard()
		if yard.is_empty():
			return
		var at: Dictionary = _on_model_at(_plan())
		var lower: BrickWorld.Brick = _world.get_brick(int(yard["lower"]))
		var upper: BrickWorld.Brick = _world.get_brick(int(yard["upper"]))
		var under: BrickWorld.Brick = _world.get_brick(int(yard["top"]))
		if not _check("pair: the upper green rests on the lower alone (%s)" % str(_rests(upper.id).map(
				func(b: BrickWorld.Brick) -> int: return b.id)), _rests(upper.id).size() == 1
				and (_rests(upper.id)[0] as BrickWorld.Brick).id == lower.id):
			return
		var by: Vector3 = under.transform.origin + Vector3(0.0, _rise(lower), 0.0) \
			- lower.transform.origin
		var steps_before: Array = [upper.step, lower.step]
		_builder.clear_selection()
		if upper_first:
			_builder.selection[upper.id] = true
			_builder.selection[lower.id] = true
		else:
			_builder.selection[lower.id] = true
			_builder.selection[upper.id] = true
		var moved: int = _builder.move_selection_by(by)
		tried += 1
		if not _check("pair, %s first: both moved onto the top (%d)" % ["upper" if upper_first
				else "lower", moved], moved == 2):
			continue
		await _edited()
		var now: Dictionary = _on_model_at(_plan())
		var up_at: int = int(now.get(upper.id, -1))
		var low_at: int = int(now.get(lower.id, -1))
		var top_at: int = int(now.get(under.id, -1))
		print("  a %s (step %d) on a %s (step %d) moved onto the %s of step %d, %s first"
			% [upper.part_id, int(at[upper.id]) + 1, lower.part_id, int(at[lower.id]) + 1,
			under.part_id, int(at[under.id]) + 1, "the upper" if upper_first else "the lower"])
		_check("pair, %s first: the lower in step %d, on the top of step %d; the upper in step %d: never before what it rests on"
			% ["upper" if upper_first else "lower", low_at + 1, top_at + 1, up_at + 1],
			low_at >= top_at and up_at >= low_at and top_at == int(at[under.id]))
		_builder.undo()
		await _frames(2)
		_check("pair: undone, both back in their steps (%s)" % str([upper.step, lower.step]),
			[upper.step, lower.step] == steps_before)
	_check("pair: %d of 2 tried (the upper selected first, then the lower)" % tried, tried == 2)


# -- stack ---------------------------------------------------------------------


func _stack_up() -> void:
	print("\n== stack (station): ten bricks put one at a time, each on the last")
	await _open(STATION)
	var base: Array = _plan()
	var top: BrickWorld.Brick = _top_of(func(brick: BrickWorld.Brick) -> bool:
		return Assemblies.path_of(brick).is_empty())
	if not _check("stack: a top brick of the model's own", top != null):
		return
	var at: Dictionary = _on_model_at(base)
	var biggest_before: int = _biggest_step(base)
	var on: BrickWorld.Brick = top
	var ids: Array = []
	for _n: int in 10:
		var id: int = _put_on(on)
		if id == 0:
			break
		await _edited()
		ids.append(id)
		on = _world.get_brick(id)
	var held: Array = _plan()
	var now: Dictionary = _on_model_at(held)
	var steps: Dictionary = {}
	for id: int in ids:
		steps[int(now.get(id, -1))] = true
	var into: int = int(now.get(int(ids[0]), -1)) if not ids.is_empty() else -1
	print("  on the %s of step %d (%d parts); the biggest step had %d parts, now %d"
		% [top.part_id, int(at.get(top.id, -1)) + 1, ((base[int(at.get(top.id, 0))] as Array)[2] as Array).size(),
		biggest_before, _biggest_step(held)])
	var said: String = _shell.change_steps("plan", [], null)
	await _frames(4)
	var planned: Array = _plan()
	var then: Dictionary = _on_model_at(planned)
	var plan_steps: Dictionary = {}
	for id: int in ids:
		plan_steps[int(then.get(id, -1))] = true
	print("  Plan steps (%s): the ten in %d steps, the biggest step %d parts" % [said.left(60),
		plan_steps.size(), _biggest_step(planned)])
	_check("stack: the ten put one on another in %d step(s) of the held steps (all in step %d), where Plan steps puts them in %d"
		% [steps.size(), into + 1, plan_steps.size()], steps.size() > 1 or plan_steps.size() <= 1)
	_builder.undo()
	await _frames(2)


func _biggest_step(plan: Array) -> int:
	var most: int = 0
	for step: Array in plan:
		most = maxi(most, (step[2] as Array).size())
	return most


# -- an MPD and the castle, Plan steps then Save --------------------------------


func _mpd() -> void:
	print("\n== mpd: the owner's MPD of the app's own, Plan steps then Save")
	var path: String = "user://sk2r_house.ldr"
	_write(path, HOUSE)
	await _planned_and_saved("house", path, HOUSE)
	print("\n== mpd: the same file as someone else's")
	var foreign: String = HOUSE.replace("0 Author: Brickworks", "0 Author: Jane Builder")
	var foreign_path: String = "user://sk2r_house_jane.ldr"
	_write(foreign_path, foreign)
	await _reopen(foreign_path)
	var before: String = _store.to_text(_store.title, true)
	var depth: int = _builder.history_depth()
	var said: String = _shell.change_steps("plan", [], null)
	await _frames(4)
	_check("mpd, someone else's: Plan steps refused (\"%s\"), no undo, the save as before"
		% said.left(80), _builder.history_depth() == depth
		and _store.to_text(_store.title, true) == before)


func _castle() -> void:
	print("\n== castle: models/castle.ldr, Plan steps then Save")
	await _planned_and_saved("castle", CASTLE, FileAccess.get_file_as_string(CASTLE))


## [param path] opened, Plan steps, saved; its structure held to [param text]'s;
## opened again from the save: in the steps saved, and written whole the file.
func _planned_and_saved(label: String, path: String, text: String) -> void:
	if path.begins_with("res://"):
		await _open(path)
	else:
		await _reopen(path)
	_check("%s: opens in its saved steps (steps_own %s)" % [label, _own_steps()], _own_steps())
	var said: String = _shell.change_steps("plan", [], null)
	await _frames(4)
	print("  Plan steps: %s" % said.left(80))
	var called: String = "SK2R %s planned" % label
	_forget(called)
	_store.title = called
	var ok: bool = _store.save_as(called)
	var saved_path: String = ModelStore.saved_path(called)
	var saved: String = FileAccess.get_file_as_string(saved_path)
	_keep("%s_planned.ldr" % label, saved)
	var was: Dictionary = _structure(text)
	var now: Dictionary = _structure(saved)
	print("  the file: %s\n  saved:    %s" % [str(was), str(now)])
	_check("%s: Plan steps + Save (%s): sections %d -> %d, comments %d -> %d, IN lines %d -> %d, FLOOR %s -> %s"
		% [label, ok, int(was["files"]), int(now["files"]), int(was["comments"]), int(now["comments"]),
		int(was["in"]), int(now["in"]), was["floor"], now["floor"]],
		ok and int(now["files"]) == int(was["files"]) and int(now["comments"]) >= int(was["comments"])
		and int(now["in"]) == int(was["in"]))
	_check("%s: ...and every comment of the file still in it" % label,
		(was["comment_lines"] as Array).all(func(line: String) -> bool: return saved.contains(line)))
	var shown: Array = _plan()
	var sig: Dictionary = _signatures()
	await _reopen(saved_path)
	var reread: Array = _plan()
	var moved: int = _moved_between(shown, sig, reread, _signatures())
	_check("%s: opened again from the save, its steps held (%s), the plan as shown before the save (%d steps, were %d; parts in another step %d)"
		% [label, _own_steps(), reread.size(), shown.size(), moved],
		_own_steps() and moved == 0 and reread.size() == shown.size())
	var whole: String = _store.to_text(_store.title, true)
	_check("%s: ...and written whole, the file byte for byte (%d / %d bytes)" % [label, whole.length(),
		saved.length()], whole == saved)
	if whole != saved:
		_first_diff(saved, whole)
	_forget(called)


func _structure(text: String) -> Dictionary:
	var comments: Array = []
	var files: int = 0
	var ins: int = 0
	var built: int = 0
	var floor: bool = false
	for line: String in text.split("\n"):
		var bare: String = line.strip_edges()
		if bare.begins_with("0 FILE "):
			files += 1
		elif bare.begins_with("0 //"):
			comments.append(bare)
		elif bare.begins_with("0 !BRICKWORKS IN "):
			ins += 1
		elif bare.begins_with("0 !BRICKWORKS BUILT"):
			built += 1
		elif bare.begins_with("0 !BRICKWORKS FLOOR"):
			floor = true
	return {"files": files, "comments": comments.size(), "in": ins, "built": built,
		"floor": floor, "authored": text.contains(AUTHORED), "comment_lines": comments}


# -- hand ----------------------------------------------------------------------


func _hand() -> void:
	print("\n== hand (station): Plan steps over MCP while the person holds a part picked up")
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	for way: String in ["put down", "Escape"]:
		for asked: String in ["plan", "next"]:
			await _open(STATION)
			var total: int = _parts_on()
			var plan: Array = _plan()
			var at: Dictionary = _on_model_at(plan)
			var top: BrickWorld.Brick = _top_of(func(brick: BrickWorld.Brick) -> bool:
				return Assemblies.path_of(brick).is_empty())
			var other: BrickWorld.Brick = _lowest_of_own(top)
			if top == null or other == null:
				_check("hand: a top brick to pick up and another to step", false)
				return
			var from: Transform3D = top.transform
			var part: String = top.part_id
			var was_at: int = int(at[top.id])
			var other_id: int = other.id
			_builder.clear_selection()
			_builder.selection[top.id] = true
			if not _check("hand: picked up the %s of step %d" % [part, was_at + 1],
					_builder.lift_selection() > 0):
				return
			var input: Dictionary = {"op": asked}
			if asked == "next":
				input["bricks"] = [other_id]
			var said: String = str(await tools.run("edit_steps", input))
			await _frames(2)
			print("  %s, then %s: edit_steps %s said \"%s\"" % ["held", way, asked, said.left(90)])
			if way == "put down":
				var carry: Carry = _builder.carrying
				carry.stand_where_lifted(_builder.lattice, _builder)
				carry.pin()
				carry.show_moved(Transform3D.IDENTITY, _builder.lattice, _builder)
				var put: int = _builder.place()
				await _edited()
				var back: BrickWorld.Brick = _brick_at(part, from)
				var stepped: int = 0
				for brick: BrickWorld.Brick in _world.bricks():
					if not _store.scenery.has(brick.id) and brick.step >= 0:
						stepped += 1
				var after: Array = _plan()
				var now: Dictionary = _on_model_at(after)
				var text: String = _store.to_text(_store.title, true)
				var shown: int = int(now.get(back.id, -1)) if back != null else -1
				if asked == "plan":
					_check("hand, plan, put down (%d): parts with a step of their own %d of %d (none, or all), the part shown in step %d of %d (was %d of %d), AUTHORED_STEPS %s"
						% [put, stepped, _parts_on(), shown + 1, after.size(), was_at + 1, plan.size(),
						text.contains(AUTHORED)], put > 0 and back != null
						and (stepped == 0 or stepped == _parts_on()) and not text.contains(AUTHORED))
				else:
					print("  control, next, put down (%d): the part in step %d of %d (was %d of %d)"
						% [put, shown + 1, after.size(), was_at + 1, plan.size()])
			else:
				_builder.cancel_carry()
				await _frames(2)
				var back: BrickWorld.Brick = _brick_at(part, from)
				_check("hand, %s, Escape: the part back on the model where it was (%s; parts %d of %d)"
					% [asked, back != null, _parts_on(), total], back != null and _parts_on() == total)


## The lowest brick or plate of the model's own that is not [param but].
func _lowest_of_own(but: BrickWorld.Brick) -> BrickWorld.Brick:
	var best: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick == but or not _stack(brick) or not Assemblies.path_of(brick).is_empty():
			continue
		if best == null or brick.transform.origin.y < best.transform.origin.y:
			best = brick
	return best


# -- looks ---------------------------------------------------------------------


func _looks() -> void:
	print("\n== looks (station): a step named, then Plan steps")
	await _open(STATION)
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var named: String = str(await tools.run("edit_steps", {"op": "name", "step": 5,
		"name": "The platform's first course"}))
	await _frames(2)
	var looks_before: int = _world.step_looks.size()
	var text_named: String = _store.to_text(_store.title, true)
	print("  named: \"%s\" (looks %d, the name in the save %s)" % [named.left(90), looks_before,
		text_named.contains("The platform's first course")])
	var said: String = str(await tools.run("edit_steps", {"op": "plan"}))
	await _frames(2)
	var text: String = _store.to_text(_store.title, true)
	var kept: bool = text.contains("The platform's first course")
	_check("looks: Plan steps (\"%s\"): the step's name %s, and the words say so (%s)"
		% [said.left(110), "kept" if kept else "taken off", said.contains("name")],
		kept or said.contains("name"))
	_builder.undo()
	await _frames(2)
	_check("looks: undone, the name back (%s)" % _store.to_text(_store.title, true).contains(
		"The platform's first course"), _store.to_text(_store.title, true).contains(
		"The platform's first course"))


# -- into ----------------------------------------------------------------------


func _into() -> void:
	print("\n== into: the station put into a model whole")
	await _open(STATION)
	var own: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and brick.step >= 0:
			own += 1
	var text: String = FileAccess.get_file_as_string(STATION)
	_main.call("clear_model")
	await _frames(4)
	var held: Dictionary = await _store.held_from(text, "station.ldr")
	var items: Array = held.get("items", [])
	var stepped: int = items.filter(func(item: Dictionary) -> bool:
		return int(item.get("step", -1)) >= 0).size()
	_check("into: opened, %d parts in the steps saved; put in whole (Into this model), %d of %d (error \"%s\")"
		% [own, stepped, items.size(), str(held.get("error", ""))], stepped == items.size() and stepped > 0)


# -- sk2fix: undo and redo, the press that asks, a look while held, the time ----


## Two bricks side by side on the floor, each in a step of its own: a plan
## puts them in one.
const PAIR := """0 sk pair
0 Name: sk_pair.ldr
0 Author: Brickworks
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 1 80 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
"""
const ORTHANC := "res://models/orthanc.ldr"


## A drag followed, and ten bricks stacked: each undone, the save byte for
## byte as before; redone, byte for byte as done, the dragged part in the
## step it was followed into.
func _redo() -> void:
	print("\n== redo (yard, station): a drag and a stack undone and redone")
	var yard: Dictionary = await _yard()
	if not yard.is_empty():
		var yard_text0: String = _store.to_text(_store.title, true)
		var brick: BrickWorld.Brick = _world.get_brick(int(yard["lone"]))
		var under: BrickWorld.Brick = _world.get_brick(int(yard["top"]))
		var from: Transform3D = brick.transform
		var to := Vector3(under.transform.origin + Vector3(0.0, _rise(brick), 0.0))
		var part: String = brick.part_id
		var was_step: int = brick.step
		var under_step: int = under.step
		var put: Variant = await _dragged(brick.id, to - from.origin)
		if _check("redo: 1 tried, the brick dragged onto the top (%s)" % put, put is int):
			var moved: BrickWorld.Brick = _world.get_brick(int(put))
			var followed: int = moved.step
			var text1: String = _store.to_text(_store.title, true)
			_check("redo: dragged from step %d onto a part of step %d, in step %d" % [was_step,
				under_step, followed], followed == under_step)
			_builder.undo()
			await _frames(2)
			var back: BrickWorld.Brick = _brick_at(part, from)
			_check("redo: the drag undone, the part back in step %d (%s), the save byte for byte"
				% [was_step, back.step if back != null else -1], back != null and back.step == was_step
				and _store.to_text(_store.title, true) == yard_text0)
			_builder.redo()
			await _frames(2)
			var again: BrickWorld.Brick = _brick_at(part, Transform3D(from.basis, to))
			var text2: String = _store.to_text(_store.title, true)
			_check("redo: the drag redone, the part in step %d (%s), the save byte for byte"
				% [followed, again.step if again != null else -1], again != null
				and again.step == followed and text2 == text1)
			if text2 != text1:
				_first_diff(text1, text2)
			_builder.undo()
			await _frames(2)
	await _open(STATION)
	var text0: String = _store.to_text(_store.title, true)
	var top: BrickWorld.Brick = _top_of(func(brick: BrickWorld.Brick) -> bool:
		return Assemblies.path_of(brick).is_empty())
	var on: BrickWorld.Brick = top
	var put_count: int = 0
	for _n: int in 10:
		var id: int = _put_on(on)
		if id == 0:
			break
		await _edited()
		put_count += 1
		on = _world.get_brick(id)
	var stacked: String = _store.to_text(_store.title, true)
	for _n: int in put_count:
		_builder.undo()
	await _frames(2)
	_check("redo: %d stacked, each undone, the save byte for byte" % put_count,
		put_count == 10 and _store.to_text(_store.title, true) == text0)
	for _n: int in put_count:
		_builder.redo()
	await _frames(2)
	var restacked: String = _store.to_text(_store.title, true)
	_check("redo: ...each redone, the save byte for byte as stacked", restacked == stacked)
	if restacked != stacked:
		_first_diff(stacked, restacked)
	# Saved and opened again: the steps the stack was given, held.
	var called: String = "sk2fix stack"
	_forget(called)
	_store.title = called
	_store.save_as(called)
	await _reopen(ModelStore.saved_path(called))
	_check("redo: the stack saved and opened again, written the same (%s)" % _own_steps(),
		_own_steps() and _store.to_text(_store.title, true) == FileAccess.get_file_as_string(
			ModelStore.saved_path(called)))
	_forget(called)


## Plan steps pressed where two named steps' parts come to share one: asked
## first, with the count, and nothing changed; done on Plan steps, one name
## standing, and one undo giving both back. Over MCP: done, and said after.
func _ask() -> void:
	print("\n== ask: Plan steps where two named steps come to share one")
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var path: String = "user://sk2fix_pair.ldr"
	_write(path, PAIR)
	await _open(path)
	_check("ask: the pair opens in its saved steps, two (%d)" % _plan().size(),
		_own_steps() and _plan().size() == 2)
	for named: Array in [[1, "The left brick"], [2, "The right brick"]]:
		var said: String = str(await tools.run("edit_steps", {"op": "name", "step": named[0],
			"name": named[1]}))
		print("  named step %d: \"%s\"" % [named[0], said.left(80)])
	await _frames(2)
	var text_named: String = _store.to_text(_store.title, true)
	_check("ask: both names in the save", text_named.contains("The left brick")
		and text_named.contains("The right brick"))
	_shell.edit_steps("plan")
	await _frames(2)
	var asked: ConfirmationDialog = _shell.get("_plan_asked")
	var text_asked: String = _store.to_text(_store.title, true)
	_check("ask: the press asks first (%s: \"%s\"), and nothing changed"
		% [asked != null and asked.visible, asked.dialog_text.left(90) if asked != null else ""],
		asked != null and asked.visible and asked.dialog_text.contains("1 of the 2")
		and text_asked == text_named)
	if asked == null:
		return
	asked.hide()
	asked.confirmed.emit()
	await _frames(4)
	var text_planned: String = _store.to_text(_store.title, true)
	var names: int = int(text_planned.contains("The left brick")) \
		+ int(text_planned.contains("The right brick"))
	_check("ask: Plan steps, confirmed: one step (%d), one name standing (%d), said \"%s\""
		% [_plan().size(), names, _bar.get("_status").text.left(110)], _plan().size() == 1
		and names == 1 and str(_bar.get("_status").text).contains("1 of the 2"))
	_builder.undo()
	await _frames(2)
	_check("ask: undone, both steps and both names back, byte for byte",
		_store.to_text(_store.title, true) == text_named)
	_builder.redo()
	await _frames(2)
	_check("ask: redone, as planned, byte for byte", _store.to_text(_store.title, true) == text_planned)
	_builder.undo()
	await _frames(2)
	var said_mcp: String = str(await tools.run("edit_steps", {"op": "plan"}))
	await _frames(2)
	_check("ask: over MCP, planned and said after (\"%s\")" % said_mcp.left(140),
		said_mcp.contains("1 of the 2") and _plan().size() == 1)
	_builder.undo()
	await _frames(2)
	_check("ask: ...undone, byte for byte", _store.to_text(_store.title, true) == text_named)
	# A name the plan keeps on a step of its own: no question.
	_main.call("clear_model")
	await _frames(4)
	DirAccess.remove_absolute(path)


## A step's look asked for while a part is held (edit_steps name, the press
## of Plan steps): refused in words, nothing changed, and Escape puts the
## part back.
func _held_look() -> void:
	print("\n== heldlook (station): a step named and Plan steps pressed while a part is held")
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	await _open(STATION)
	var total: int = _parts_on()
	var text0: String = _store.to_text(_store.title, true)
	var top: BrickWorld.Brick = _top_of(func(brick: BrickWorld.Brick) -> bool:
		return Assemblies.path_of(brick).is_empty())
	var part: String = top.part_id
	var from: Transform3D = top.transform
	_builder.clear_selection()
	_builder.selection[top.id] = true
	_check("heldlook: picked up", _builder.lift_selection() > 0)
	var said: String = str(await tools.run("edit_steps", {"op": "name", "step": 3,
		"name": "Held"}))
	_shell.edit_steps("plan")
	await _frames(2)
	var bar_said: String = str(_bar.get("_status").text)
	_check("heldlook: refused in words (\"%s\"; the bar \"%s\")" % [said.left(80), bar_said.left(80)],
		said.contains("in hand") and bar_said.contains("in hand"))
	_builder.cancel_carry()
	await _frames(2)
	var back: BrickWorld.Brick = _brick_at(part, from)
	_check("heldlook: Escape, the part back (%s), parts %d of %d, the save byte for byte"
		% [back != null, _parts_on(), total], back != null and _parts_on() == total
		and _store.to_text(_store.title, true) == text0)


## The follow's own time on Orthanc as the app's own held steps, the biggest
## model whose edits are followed: a part put on its top, twelve stacked (a
## step filling and a new one started), and a part dragged; each the work of
## one frame (16 ms is the bar). And Plan steps with a named step, which
## works the whole plan out to keep the name (said, not checked).
func _fix_time() -> void:
	print("\n== fixtime (orthanc as its own): the follow's time")
	var own_path: String = "user://sk2fix_orthanc_own.ldr"
	_write(own_path, FileAccess.get_file_as_string(ORTHANC).replace(AUTHORED + "\n", ""))
	await _open(own_path)
	if not _check("fixtime: orthanc opens as the app's own steps", _own_steps()):
		return
	var top: BrickWorld.Brick = _top_of(func(_brick: BrickWorld.Brick) -> bool: return true)
	var on: BrickWorld.Brick = top
	var most: float = 0.0
	var times: PackedStringArray = []
	var steps: Dictionary = {}
	for _n: int in 12:
		var id: int = _put_on(on)
		if id == 0:
			break
		var began: int = Time.get_ticks_usec()
		_store._steps_follow_saved(_builder.last_step())
		var ms: float = float(Time.get_ticks_usec() - began) / 1000.0
		most = maxf(most, ms)
		times.append("%.1f" % ms)
		on = _world.get_brick(id)
		steps[on.step] = true
		await _edited()
	_check("fixtime: twelve stacked, in %d steps, each followed in at most %.1f ms (%s)"
		% [steps.size(), most, ", ".join(times)], most <= 16.0 and steps.size() > 1)
	var lifted: BrickWorld.Brick = _world.get_brick(on.id)
	_builder.clear_selection()
	_builder.selection[lifted.id] = true
	var drag_ms: float = -1.0
	if _builder.lift_selection() > 0:
		var carry: Carry = _builder.carrying
		carry.stand_where_lifted(_builder.lattice, _builder)
		carry.pin()
		carry.show_moved(Transform3D.IDENTITY, _builder.lattice, _builder)
		if _builder.place() != 0:
			var began: int = Time.get_ticks_usec()
			_store._steps_follow_saved(_builder.last_step())
			drag_ms = float(Time.get_ticks_usec() - began) / 1000.0
			await _edited()
		else:
			_builder.cancel_carry()
	_check("fixtime: a part dragged, followed in %.1f ms" % drag_ms, drag_ms >= 0.0
		and drag_ms <= 16.0)
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	await tools.run("edit_steps", {"op": "name", "step": 2, "name": "Orthanc's second"})
	await _frames(2)
	var began_plan: int = Time.get_ticks_usec()
	var said: String = _shell.change_steps("plan", [], null)
	print("  (said) Plan steps with a named step: %.0f ms (\"%s\")" % [
		float(Time.get_ticks_usec() - began_plan) / 1000.0, said.left(100)])
	_main.call("clear_model")
	await _frames(4)
	DirAccess.remove_absolute(own_path)


# -- reading ---------------------------------------------------------------------


func _plan() -> Array:
	var out: Array = []
	for step: Instructions.Step in Instructions.plan(_world, _world.library, _store.scenery, {}, true):
		var ids: Array = Array(step.brick_ids)
		for copy: PackedInt64Array in step.copies:
			ids.append_array(Array(copy))
		ids.sort()
		out.append([step.callout, step.callout_step, ids])
	return out


func _on_model_at(plan: Array) -> Dictionary:
	var out: Dictionary = {}
	for index: int in plan.size():
		var step: Array = plan[index]
		if int(step[1]) != 0:
			continue
		for id: Variant in step[2]:
			if not out.has(int(id)):
				out[int(id)] = index
	return out


func _signatures() -> Dictionary:
	var low: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			low = minf(low, brick.transform.origin.y)
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var at: Vector3 = brick.transform.origin
		out[brick.id] = "%s|%d|%d|%d|%d|%s" % [brick.part_id, brick.color_code, roundi(at.x),
			roundi(at.y - low), roundi(at.z), Assemblies.path_of(brick)]
	return out


func _moved_between(a: Array, sig_a: Dictionary, b: Array, sig_b: Dictionary) -> int:
	var at: Dictionary = {}
	for index: int in a.size():
		for id: Variant in (a[index] as Array)[2]:
			var key: String = "%s#%d" % [sig_a.get(int(id), "?"), index]
			at[key] = int(at.get(key, 0)) + 1
	var off: int = 0
	for index: int in b.size():
		for id: Variant in (b[index] as Array)[2]:
			var key: String = "%s#%d" % [sig_b.get(int(id), "?"), index]
			if int(at.get(key, 0)) > 0:
				at[key] = int(at[key]) - 1
			else:
				off += 1
	return off


## The share's steps test on [param text]: [in the air, other], as
## stepkeep_probe reads it.
func _air(text: String) -> Array:
	var tested: Dictionary = (await SharedPages.attach_tested(text, _world.library, _store))["tested"]
	var tests: Dictionary = tested.get("tests", {})
	if not tests.has("steps"):
		return [-1, -1]
	if bool((tests["steps"] as Dictionary).get("ok", false)):
		return [0, 0]
	var said: Array = Tested.said_all.get("steps", [])
	var air: int = said.filter(func(line: Variant) -> bool: return str(line).ends_with("in the air")).size()
	return [air, said.size() - air]


## The bricks a history step put down.
func _put_ids(step: Dictionary) -> Array:
	var out: Array = []
	for inner: Variant in step.get("steps", [step]):
		if inner is Dictionary and str((inner as Dictionary).get("undo", "")) == "remove":
			out.append(int((inner as Dictionary)["brick"]))
	return out


func _brick_at(part: String, at: Transform3D) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and brick.transform.origin.distance_to(at.origin) < 0.01:
			return brick
	return null


# -- parts -----------------------------------------------------------------------


func _stack(brick: BrickWorld.Brick) -> bool:
	if _store.scenery.has(brick.id) or not STACKS.has(brick.part_id.get_basename()):
		return false
	for turn: Basis in [Basis.IDENTITY, Basis(Vector3.UP, PI / 2.0), Basis(Vector3.UP, PI),
			Basis(Vector3.UP, -PI / 2.0)]:
		if brick.transform.basis.is_equal_approx(turn):
			return true
	return false


func _top_of(which: Callable) -> BrickWorld.Brick:
	var best: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if not _stack(brick) or not bool(which.call(brick)):
			continue
		if best == null or brick.transform.origin.y > best.transform.origin.y:
			best = brick
	return best


func _rise(brick: BrickWorld.Brick) -> float:
	var info: PartLibrary.PartInfo = _world.library.parts.get(brick.part_id)
	return 24.0 if info != null and info.bounds.size.y >= 24.0 else 8.0


func _put_on(on: BrickWorld.Brick) -> int:
	return _builder.put_part(on.part_id, 4, on.transform.translated(Vector3(0.0, _rise(on), 0.0)))


func _rests(id: int) -> Array:
	var lattice: BrickLattice = _builder.lattice
	var out: Array = []
	for other_id: int in lattice.blockers_boxes(BrickLattice.moved_by(lattice.boxes_of(id),
			Vector3i(0, -1, 0)), id, _store.scenery):
		if _world.get_brick(other_id) != null:
			out.append(_world.get_brick(other_id))
	return out


## The parts one layer over [param id]: what rests on it.
func _above(id: int) -> Array:
	var lattice: BrickLattice = _builder.lattice
	var out: Array = []
	for other_id: int in lattice.blockers_boxes(BrickLattice.moved_by(lattice.boxes_of(id),
			Vector3i(0, 1, 0)), id, _store.scenery):
		if _world.get_brick(other_id) != null:
			out.append(other_id)
	return out


# -- the rest --------------------------------------------------------------------


func _edited() -> void:
	_main.call("_on_model_edited")
	await _frames(2)


func _open(path: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	_store.open(path)
	_bar.opened.emit(_parts_on())
	await _frames(6)


func _reopen(path: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(10)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _first_diff(a: String, b: String) -> void:
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for n: int in maxi(la.size(), lb.size()):
		var x: String = la[n] if n < la.size() else "(none)"
		var y: String = lb[n] if n < lb.size() else "(none)"
		if x != y:
			print("      first difference at line %d of %d/%d:\n        < %s\n        > %s" % [n + 1,
				la.size(), lb.size(), x, y])
			return


func _keep(name: String, text: String) -> void:
	if _out.is_empty():
		return
	var file: FileAccess = FileAccess.open(_out.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _forget(name: String) -> void:
	DirAccess.remove_absolute(ModelStore.saved_path(name))
	var folder: String = ModelVersions.folder(ModelStore._safe_name(name))
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


func _own_steps() -> bool:
	return _world.get("steps_own") == true


func _parts_on() -> int:
	return _world.brick_count() - _store.scenery.size()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	if ok:
		print("  ok    %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s" % what)
	return ok
