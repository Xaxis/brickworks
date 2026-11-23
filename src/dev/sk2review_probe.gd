## sk2review (2026-11-23): repros for the review of stepkeep2 (a file's STEP
## lines are its steps) and of its merge with wholekeep. A FAIL is a finding
## reproduced; each case says what it holds.
##
##   drag    a brick of the station's first steps dragged (picked up and put
##           down, as the mouse moves a part) onto a brick of a later step:
##           in the step of what it now rests on, as a moved part is
##           (AuthorSteps.follow_saved), not in the air from its old step
##   pair    two stacked bricks moved together onto a later step's brick by a
##           typed move, the upper one selected first, then the lower first:
##           the upper never in a step before the one it rests on
##   stack   ten bricks put one at a time each on the last, on the station's
##           top: how many steps they are in, held and as Plan steps plans them
##   mpd     an MPD of the app's own (three sections, a sub-model placed twice
##           and one nested, comments in each), Plan steps then Save: its
##           sections and comments kept, reopened in the steps saved, the whole
##           write the file; the same file as someone else's: Plan steps refused
##   castle  models/castle.ldr, Plan steps then Save: the same
##   into    the station put into a model whole (held_from): its saved steps
##           kept, as an open keeps them
##
##   godot --headless --path . --script src/dev/sk2review_probe.gd
##   SK2R_ONLY=drag,pair,stack,mpd,castle,into   only those
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
	print("")
	print("%d FAILURE(S)" % _failures if _failures else "every case holds")
	quit(1 if _failures else 0)


func _asked(name: String) -> bool:
	return _only.is_empty() or _only.has(name)


# -- drag ----------------------------------------------------------------------


func _drag() -> void:
	print("\n== drag (station): a brick of the first steps dragged onto one of a later step")
	await _open(STATION)
	_check("drag: the station opens in its saved steps (steps_own)", _own_steps())
	var plan: Array = _plan()
	var at: Dictionary = _on_model_at(plan)
	var text_before: String = _store.to_text(_store.title, true)
	var air_before: Array = await _air(text_before)
	var tries: int = 0
	var done: bool = false
	for pair: Array in _early_onto_late(at):
		var brick: BrickWorld.Brick = _world.get_brick(int(pair[0]))
		var under: BrickWorld.Brick = _world.get_brick(int(pair[1]))
		if brick == null or under == null:
			continue
		tries += 1
		if tries > 60:
			break
		var from: Transform3D = brick.transform
		var to := Vector3(under.transform.origin + Vector3(0.0, _rise(brick), 0.0))
		var part: String = brick.part_id
		var was_shown: int = int(at[brick.id])
		var under_shown: int = int(at[under.id])
		var under_id: int = under.id
		_builder.clear_selection()
		_builder.selection[brick.id] = true
		if _builder.lift_selection() == 0:
			continue
		var carry: Carry = _builder.carrying
		carry.stand_where_lifted(_builder.lattice, _builder)
		carry.pin()
		if not carry.show_moved(Transform3D(Basis.IDENTITY, to - from.origin), _builder.lattice,
				_builder):
			_builder.cancel_carry()
			await _frames(1)
			continue
		if _builder.place() == 0:
			_builder.cancel_carry()
			await _frames(1)
			continue
		await _edited()
		var put: Array = _put_ids(_builder.last_step())
		if put.size() != 1:
			print("  (the drag put down %d parts)" % put.size())
			_builder.undo()
			await _frames(2)
			continue
		var after: Array = _plan()
		var now: Dictionary = _on_model_at(after)
		var put_id: int = int(put[0])
		var rests: Array = _rests(put_id).map(func(b: BrickWorld.Brick) -> int: return b.id)
		print("  dragged a %s of step %d onto the %s of step %d (it rests on %s)" % [part,
			was_shown + 1, _world.get_brick(under_id).part_id, under_shown + 1, str(rests)])
		var shown: int = int(now.get(put_id, -1))
		var support: int = int(now.get(under_id, -1))
		_check("drag: shown in step %d, on the model no earlier than what it rests on (step %d): not in the air from step %d to %d"
			% [shown + 1, support + 1, shown + 1, support], shown >= support and rests.has(under_id))
		var text_after: String = _store.to_text(_store.title, true)
		var air_after: Array = await _air(text_after)
		_check("drag: the share's steps test, parts put down in the air: %d before, %d after"
			% [int(air_before[0]), int(air_after[0])], int(air_after[0]) <= int(air_before[0]))
		_keep("drag_station.ldr", text_after)
		# The same act as a typed move: followed (stepkeep's C).
		_builder.undo()
		await _frames(2)
		var again: BrickWorld.Brick = _brick_at(part, from)
		if again != null:
			_builder.clear_selection()
			_builder.selection[again.id] = true
			if _builder.move_selection_by(to - from.origin) > 0:
				await _edited()
				var typed: Dictionary = _on_model_at(_plan())
				print("  control: the same move typed: shown in step %d (support %d)"
					% [int(typed.get(again.id, -1)) + 1, int(typed.get(under_id, -1)) + 1])
				_builder.undo()
				await _frames(2)
		done = true
		break
	_check("drag: a brick of the first steps that can be dragged onto one of a later step (%d tried)"
		% tries, done)


## [brick id, under id]: a brick or plate of the main model's own early steps,
## and a top one of a later step with nothing on it, latest first.
func _early_onto_late(at: Dictionary) -> Array:
	var stacks: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return _stack(brick) and at.has(brick.id) and Assemblies.path_of(brick).is_empty())
	var tops: Array = stacks.filter(func(brick: BrickWorld.Brick) -> bool:
		return _above(brick.id).is_empty())
	tops.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return int(at[a.id]) > int(at[b.id]))
	var early: Array = stacks.duplicate()
	early.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return int(at[a.id]) < int(at[b.id]))
	var out: Array = []
	for under: BrickWorld.Brick in tops.slice(0, 12):
		for brick: BrickWorld.Brick in early.slice(0, 12):
			if int(at[brick.id]) + 3 <= int(at[under.id]) and brick.id != under.id:
				out.append([brick.id, under.id])
	return out


# -- pair ----------------------------------------------------------------------


func _pair() -> void:
	print("\n== pair (station): two stacked bricks moved together onto a later step's brick")
	await _open(STATION)
	var plan: Array = _plan()
	var at: Dictionary = _on_model_at(plan)
	var stacks: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return _stack(brick) and at.has(brick.id) and Assemblies.path_of(brick).is_empty())
	stacks.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return int(at[a.id]) < int(at[b.id]))
	var tops: Array = stacks.filter(func(brick: BrickWorld.Brick) -> bool:
		return _above(brick.id).is_empty())
	tops.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return int(at[a.id]) > int(at[b.id]))
	var found: bool = false
	var tries: int = 0
	for lower: BrickWorld.Brick in stacks.slice(0, 60):
		for upper_id: int in _above(lower.id):
			var upper: BrickWorld.Brick = _world.get_brick(upper_id)
			if upper == null or not stacks.has(upper) or _rests(upper_id).size() != 1:
				continue
			if not _above(upper_id).is_empty():
				continue
			for under: BrickWorld.Brick in tops.slice(0, 10):
				if under == upper or int(at[under.id]) <= int(at[upper.id]) + 2:
					continue
				tries += 1
				if tries > 200:
					break
				var by: Vector3 = under.transform.origin + Vector3(0.0, _rise(lower), 0.0) \
					- lower.transform.origin
				var steps_before: Array = [upper.step, lower.step]
				for upper_first: bool in [true, false]:
					_builder.clear_selection()
					if upper_first:
						_builder.selection[upper.id] = true
						_builder.selection[lower.id] = true
					else:
						_builder.selection[lower.id] = true
						_builder.selection[upper.id] = true
					if _builder.move_selection_by(by) == 0:
						break
					await _edited()
					var now: Dictionary = _on_model_at(_plan())
					var up_at: int = int(now.get(upper.id, -1))
					var low_at: int = int(now.get(lower.id, -1))
					print("  a %s (step %d) on a %s (step %d) moved onto the %s of step %d, %s first"
						% [upper.part_id, int(at[upper.id]) + 1, lower.part_id, int(at[lower.id]) + 1,
						under.part_id, int(at[under.id]) + 1, "the upper" if upper_first else "the lower"])
					_check("pair, %s first: the upper in step %d, the lower it rests on in step %d: never before it"
						% ["upper" if upper_first else "lower", up_at + 1, low_at + 1], up_at >= low_at)
					found = true
					_builder.undo()
					await _frames(2)
					_check("pair: undone, both back in their steps (%s)" % str([upper.step, lower.step]),
						[upper.step, lower.step] == steps_before)
				if found:
					break
			if found or tries > 200:
				break
		if found or tries > 200:
			break
	_check("pair: two stacked bricks that move together onto a later step's top (%d tried)" % tries,
		found)


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
