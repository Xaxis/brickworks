## A joint locked holds (APP_UX10 jointlock): a joint the person locks in
## Build › Motions… (the Lock on its row) or over MCP (pose_model lock=true)
## keeps its angle and its slide, and every way of moving it is refused with
## the joint's name and how to unlock it; unlocked, each moves it again.
##
##   godot --path . --resolution 1400x900 --script src/dev/jointlock_probe.gd
##
## Three models, each opened from its file, the part that moves a sub-model
## of its own (so pose_model names its joint):
##   - a minifig's knee: a leg (3816) on its hips (3815), the other leg and
##     the torso beside it, locked by its row's Lock clicked;
##   - a Technic hinge: a beam 7 (32524) on a friction pin (2780) in a Technic
##     brick 1 x 4 (3701) on a tower, locked by pose_model lock=true;
##   - a slider: an axle 4 (3705) through the same brick's middle hole, which
##     slides along it as well as turning, locked by its row's Lock.
## On each, locked: a drag of the part and a drag of the part it is on
## (Builder's drag), a drag on its joint (Grab), R, a handle's ring, Simulate's
## driver, move_part (and along= on the slider) and pose_model are each
## refused, saying the joint and how to unlock it, nothing moved and nothing
## recorded. The lock is one step to undo, back byte for byte; saved it is
## one 0 !BRICKWORKS LOCK line and nothing else changed; reopened it holds
## and saves the same bytes; an edit elsewhere keeps the line byte for byte;
## a lock line it cannot read is named at the open and kept as it is.
## Unlocked (pose_model lock=false, the list's Unlock, the row again: one
## step, back byte for byte), each moves again.
##
## Then jlreview's findings, each a case of its own (jlfix; `-- together
## breakout motion_breakout chain copies dangling`, any of them, runs those
## alone): a lock made on either side of a Build together room holds on both
## (two sides in one process, the room's words put on each); a save while a
## section is broken out writes the lock, and a motion's joints, where they
## are built; move_part to= on a locked joint names the lock; a lock in one of
## three copies says which and that the others move; a lock of parts the
## model has not got is named at the open and kept byte for byte.
extends SceneTree

const MODELS := "user://models/"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _verbs: EditVerbs
var _pose: PosePanel
var _player: MotionPlayer
var _grabbing: GrabDrag
var _simulate: Node
var _socket: Variant
var _rpc_id: int = 0
var _said: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_shell") != null and _main.get("_world") != null:
			break
	await _frames(60)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_pose = _main.get("_pose")
	_player = _main.get("_motions")
	_grabbing = _main.get("_grab_drag")
	_simulate = _main.get("_simulate")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var account: Account = _main.get("_account")
	while account.state == Account.State.CHECKING:
		await account.changed
	account.email = "jointlock-probe@example.com"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELS))
	# Every line said to the person, as the status shows it.
	var said_before: Callable = _verbs.say
	var hear := func(words: String) -> void:
		_said = words
		said_before.call(words)
	_verbs.say = hear
	# Made the first time the Move or Rotate tool is chosen, as a person's are.
	_verbs.set_mode("rotate")
	_verbs.set_mode("select")
	(_verbs.handles as Handles).say = hear

	var only: PackedStringArray = OS.get_cmdline_user_args()
	if only.is_empty():
		await _model("knee", _knee_ldr(), "3816", "3815", "Leg", "row")
		await _model("hinge", _hinge_ldr(), "32524", "3701", "Beam", "mcp")
		await _model("slider", _slider_ldr(), "3705", "3701", "Axle", "row")
	# jlreview's findings, each its own case (jlfix); a name or more after
	# the probe's -- runs those alone.
	for step: String in (only if not only.is_empty() else PackedStringArray(["together", "breakout", "replace",
			"motion_breakout", "chain", "copies", "dangling"])):
		await call("_case_" + step)

	print("")
	if _failures == 0:
		print("jointlock: each joint locked held through a drag of either part, a drag on its joint, R, "
			+ "a handle, Simulate, move_part and pose_model, each refused by name; saved, reopened and "
			+ "kept byte for byte; one undo each way; unlocked, each moved again")
	else:
		print("jointlock: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- one model --------------------------------------------------------------------------


func _model(name: String, text: String, moving_part: String, base_part: String, sub: String,
		lock_by: String) -> void:
	print("\n══ %s: a %s on a %s, locked by %s ══" % [name, moving_part, base_part,
		"its row's Lock" if lock_by == "row" else "pose_model lock=true"])
	var path: String = MODELS + name + ".ldr"
	_write(path, text)
	await _open(path)
	var a: int = _id_of(moving_part)
	var b: int = _id_of(base_part)
	_check("opened: the %s (#%d) and the %s (#%d)" % [moving_part, a, base_part, b], a != 0 and b != 0)
	if a == 0 or b == 0:
		return
	var unlocked: String = await _save(name + ".ldr")
	var depth: int = _builder.history_depth()
	# Locked.
	var said: String = await _lock(sub, a, lock_by, true)
	_check("locked (%s): one step to undo (%s), \"%s\"" % [lock_by, _top_words(), said.left(110)],
		_builder.history_depth() == depth + 1 and _world.motions.locks.size() == 1
		and said.contains("Locked"))
	var locked: String = await _save(name + ".ldr")
	var lines: Array = _lines_with(locked, Motions.LOCK_META)
	_check("saved: one lock line (%s), the rest the file as it was, byte for byte" % (
		str(lines[0][1]) if lines.size() == 1 else "%d lines" % lines.size()),
		lines.size() == 1 and _without_line(locked, int(lines[0][0])) == unlocked)
	if lines.size() != 1:
		return
	# One undo takes it off, byte for byte; redo puts it back.
	_builder.undo()
	await _frames(3)
	var undone: String = await _save(name + ".ldr")
	_check("undo takes the lock off: saved byte for byte as before it (%s)" % (
		"same" if undone == unlocked else _first_difference(undone, unlocked)), undone == unlocked
		and _world.motions.locks.is_empty())
	_builder.redo()
	await _frames(3)
	var redone: String = await _save(name + ".ldr")
	_check("redo locks it again, byte for byte (%s)" % ("same" if redone == locked
		else _first_difference(redone, locked)), redone == locked and _world.motions.locks.size() == 1)

	await _refusals(name, sub, a, b, moving_part == "3705")

	# Reopened, it holds, and saves the same bytes.
	await _open(path)
	a = _id_of(moving_part)
	b = _id_of(base_part)
	var held: Variant = _grabbing.held_of([a])
	_check("reopened: the lock read (%d) and it holds (%s)" % [_world.motions.locks.size(),
		str(held).left(90) if held is String else "it moves"], _world.motions.locks.size() == 1
		and held is String and str(held).contains(Motions.UNLOCK_WORDS))
	var again: String = await _save(name + ".ldr")
	_check("saved again unedited: byte for byte (%s)" % ("same" if again == locked
		else _first_difference(again, locked)), again == locked)

	# An edit elsewhere keeps the line where it is, byte for byte.
	var far: int = _world.add_brick("3024", 1, Transform3D(Basis.IDENTITY, Vector3(400, 8, 400)))
	_builder.register(far, "3024", _world.get_brick(far).transform)
	_builder.record([{"undo": "remove", "brick": far}], "added a plate")
	var edited: String = await _save(name + ".ldr")
	var kept: Array = _lines_with(edited, Motions.LOCK_META)
	_check("an edit elsewhere keeps the lock line byte for byte, where it was (%s)" % (
		str(kept[0][1]) if kept.size() == 1 else "%d lines" % kept.size()), kept.size() == 1
		and str(kept[0][1]) == str(lines[0][1]) and int(kept[0][0]) == int(lines[0][0]))
	_builder.undo()
	await _frames(3)
	var back: String = await _save(name + ".ldr")
	_check("...undone, the file as it was locked, byte for byte", back == locked)

	# A lock line it cannot read is named at the open and kept as it is.
	var odd_line: String = "0 !BRICKWORKS LOCK PART 3001 4 1 2 3 NEAR nothing"
	var odd: String = locked.replace(str(lines[0][1]), str(lines[0][1]) + "\n" + odd_line)
	_write(MODELS + name + "_odd.ldr", odd)
	await _open(MODELS + name + "_odd.ldr")
	var named: String = _store.motions_unread_words
	var odd_saved: String = await _save(name + "_odd.ldr")
	_check("a lock line it cannot read is named at the open (\"%s\") and kept as it is" % named.left(100),
		named.contains("lock line not read") and odd_saved.contains(odd_line)
		and _lines_with(odd_saved, Motions.LOCK_META).size() == 2)

	# Unlocked: one step, back byte for byte; each moves again.
	await _open(path)
	a = _id_of(moving_part)
	b = _id_of(base_part)
	depth = _builder.history_depth()
	var how: String = {"knee": "mcp", "hinge": "list", "slider": "row"}[name]
	said = await _lock(sub, a, how, false)
	_check("unlocked (%s): one step (%s), \"%s\"" % [how, _top_words(), said.left(110)],
		_builder.history_depth() == depth + 1 and _world.motions.locks.is_empty()
		and said.contains("Unlocked"))
	var open_again: String = await _save(name + ".ldr")
	_check("...saved byte for byte as it was before it was locked (%s)" % ("same" if open_again == unlocked
		else _first_difference(open_again, unlocked)), open_again == unlocked)
	_builder.undo()
	await _frames(3)
	var relocked: String = await _save(name + ".ldr")
	_check("undo locks it again, byte for byte", relocked == locked and _world.motions.locks.size() == 1)
	_builder.redo()
	await _frames(3)
	await _moves_again(name, sub, a, b, moving_part == "3705")
	# lock=false with nothing locked is the same as no lock= at all.
	var plain: String = await _say("pose_model", {"joint": sub})
	var as_absent: String = await _say("pose_model", {"joint": sub, "lock": false})
	_check("pose_model lock=false with nothing locked answers as without it (%s)" % as_absent.left(60),
		plain == as_absent and _world.motions.locks.is_empty())


## Lock ([param on]) or unlock the joint of [param a] by [param how]: "row"
## (its Lock on New motion's row, clicked), "mcp" (pose_model lock=), "list"
## (the list's Unlock). What it said.
func _lock(sub: String, a: int, how: String, on: bool) -> String:
	if how == "mcp":
		return await _say("pose_model", {"joint": sub, "lock": on})
	_shell.run("pose")
	await _frames(5)
	if how == "list":
		var named: Dictionary = _pose.controls_by_name()
		var unlock: Button = named.get("motion_unlock_0")
		print("    the list's Unlocks: %d, locks %d, the panel's motions the world's: %s" % [
			_pose._unlock_buttons.size(), _world.motions.locks.size(), _pose._motions() == _world.motions])
		if unlock == null:
			_close_pose()
			return "no Unlock in the list"
		await _press(unlock, "the list's Unlock")
	else:
		_pose.new_motion()
		await _frames(5)
		var row: Dictionary = {}
		for part: Dictionary in _pose._joint_parts:
			if _player.parts_of(part["joint"]).has(a):
				row = part
		if row.is_empty():
			_close_pose()
			return "no row for #%d" % a
		var button: Button = row["lock"]
		var was: String = button.text
		var sides: Array = _pose._lock_sides(row["joint"])
		var joint: Motions.Joint = row["joint"]
		print("    its row's joint: by %s %s%s, moving %s, between %s" % [joint.by, joint.part, joint.assembly,
			(sides[0] as Dictionary).keys(), sides[1]])
		await _press(button, "the row's %s" % was)
		await _frames(3)
		var now_row: Dictionary = {}
		for part: Dictionary in _pose._joint_parts:
			if _player.parts_of(part["joint"]).has(a):
				now_row = part
		print("    its row's button: %s, then %s" % [was, (now_row["lock"] as Button).text
			if not now_row.is_empty() else "?"])
	await _frames(3)
	var said: String = _pose.status_words()
	_close_pose()
	return said


func _close_pose() -> void:
	if _pose.visible:
		_pose.back_to_list()
		_pose.close()
	await _frames(2)


## Each way of moving it, refused by name, nothing moved or recorded.
func _refusals(name: String, sub: String, a: int, b: int, slides: bool) -> void:
	var rest: Dictionary = _rest()
	var depth: int = _builder.history_depth()
	if _world.motions.locks.is_empty():
		_check("%s: locked before its refusals are tried" % name, false)
		return
	var name_words: String = Motions.lock_name(_world.motions.locks[0], _world, _main.get("_library"), _builder)
	print("    the joint is called: %s" % name_words)
	for one: int in [a, b]:
		_select(one)
		_builder.drag_begin()
		var fits: bool = _builder.drag_fits(Transform3D(Basis.IDENTITY, Vector3(20, 0, 0)))
		var words: String = _builder.refused_lock
		_builder.drag_end(Transform3D(Basis.IDENTITY, Vector3(20, 0, 0)))
		_check("a drag of #%d (%s) is refused: \"%s\"" % [one, "the part" if one == a else "what it is on",
			words.left(100)], not fits and words.contains(name_words.left(1).to_upper())
			and words.contains(Motions.UNLOCK_WORDS))
	var held: Variant = _grabbing.held_of([a])
	_check("a drag on its joint (Grab) is refused: \"%s\"" % str(held).left(100),
		held is String and str(held).contains(Motions.UNLOCK_WORDS))
	# R where it stands.
	_select(a)
	_said = ""
	var turned: int = _verbs.turn_by(90.0)
	_check("R is refused, said, nothing taken into hand: \"%s\"" % _said.left(100), turned == 0
		and _said.contains(Motions.UNLOCK_WORDS) and not _builder.is_carrying())
	# A handle's ring, dragged 30 degrees.
	_said = ""
	var handles: Handles = _verbs.handles
	if handles._start({"kind": "ring", "axis": 1, "way": Vector3.UP}, Vector2(700, 450)):
		handles.drag["want"] = 30.0
		handles.drag["value"] = 30.0
		handles._let_go()
	_check("a handle's ring turned 30° is refused, said: \"%s\"" % _said.left(100),
		_said.contains(Motions.UNLOCK_WORDS))
	_builder.clear_selection()
	# Simulate's driver.
	var drove: String = await _drive(a)
	_check("Simulate's driver stops at it: \"%s\"" % drove.left(100), drove.contains(Motions.UNLOCK_WORDS))
	var moved: String = await _say("move_part", {"part": "#%d" % a, "degrees": 30})
	_check("move_part degrees=30 is refused: \"%s\"" % moved.left(100), moved.contains(Motions.UNLOCK_WORDS))
	if slides:
		var along: String = await _say("move_part", {"part": "#%d" % a, "along": 1})
		_check("move_part along=1 is refused: \"%s\"" % along.left(100), along.contains(Motions.UNLOCK_WORDS))
	var posed: String = await _say("pose_model", {"joint": sub, "degrees": 30})
	_check("pose_model degrees=30 is refused, Nothing was changed: \"%s\"" % posed.left(100),
		posed.contains(Motions.UNLOCK_WORDS) and posed.contains("Nothing was changed"))
	var listed: String = await _say("pose_model", {})
	_check("pose_model's list says it is locked", listed.contains("locked"))
	_check("...and through all of it nothing moved (%d parts) and nothing was recorded (%d steps)" % [
		rest.size(), _builder.history_depth() - depth], _same(rest) and _builder.history_depth() == depth)


## Unlocked, each moves it: each undone.
func _moves_again(name: String, sub: String, a: int, b: int, slides: bool) -> void:
	var rest: Dictionary = _rest()
	_select(a)
	_builder.drag_begin()
	var fits: bool = _builder.drag_fits(Transform3D(Basis.IDENTITY, Vector3(0, 0, -400)))
	_builder.drag_end(Transform3D.IDENTITY)
	_check("unlocked, a drag of the part is not refused by a lock (%s)" % (_builder.refused_lock
		if not _builder.refused_lock.is_empty() else "fits" if fits else "no room"), _builder.refused_lock.is_empty())
	var held: Variant = _grabbing.held_of([a])
	_check("...a drag on its joint takes it (%s)" % (str(held).left(80) if held is String else "a Grab"),
		held is Grab)
	_select(a)
	var depth: int = _builder.history_depth()
	_said = ""
	var turned: int = _verbs.turn_by(90.0)
	_check("...R is not refused by a lock (%s)" % _said.left(80), not _said.contains(Motions.UNLOCK_WORDS))
	if _builder.is_carrying():
		_builder.cancel_carry()
	while _builder.history_depth() > depth:
		_builder.undo()
	_builder.clear_selection()
	var drove: String = await _drive(a)
	_check("...Simulate drives it (%s)" % drove.left(80), not drove.contains(Motions.UNLOCK_WORDS))
	depth = _builder.history_depth()
	var moved: String = await _say("move_part", {"part": "#%d" % a, "degrees": 30})
	_check("...move_part turns it: \"%s\"" % moved.left(90), not moved.contains(Motions.UNLOCK_WORDS)
		and _builder.history_depth() > depth)
	while _builder.history_depth() > depth:
		_builder.undo()
	var posed: String = await _say("pose_model", {"joint": sub, "degrees": 30})
	_check("...pose_model swings it: \"%s\"" % posed.left(90), not posed.contains(Motions.UNLOCK_WORDS)
		and _builder.history_depth() > depth)
	while _builder.history_depth() > depth:
		_builder.undo()
	await _frames(3)
	_check("...each undone, it stands as it did", _same(rest))


## Simulate opened, driven by [param a]'s body, closed: what it said.
func _drive(a: int) -> String:
	_shell.run("simulate")
	await _settled()
	var sim: Simulation = _simulate.get("sim")
	var said: String = ""
	if sim == null:
		said = "Simulate did not open"
	else:
		var body: int = -1
		for one: int in sim.model.bodies:
			if (sim.model.bodies[one] as Array).has(a):
				body = one
		if body < 0:
			said = "no body for #%d" % a
		else:
			await _simulate.call("drive", body)
			await _settled()
			said = str(sim.solved.get("said", "")) + " " + str(sim.solved.get("lock", ""))
	_simulate.call("close")
	await _frames(5)
	return said


# -- jlreview's findings (jlfix) --------------------------------------------------------


## Building together (H1): a lock made by either person holds for both. Two
## sides in one process, as the room carries the model's own state between
## them: this window, and a second copy of the model (its own world, builder,
## store and Together), each side's ~motions words put on the other as
## another person's are (Together._put_meta). Here locks: the words carry
## it, and there a drag on the joint and a move of its part are refused by
## the joint's name. There unlocks: here it turns again. There locks: here
## it is refused, and saved as one LOCK line, the line this side writes. A
## motion kept here while locked goes there with the lock, and back.
func _case_together() -> void:
	print("\n══ together: a lock made by either person holds for both ══")
	_write(MODELS + "together.ldr", _hinge_ldr())
	await _open(MODELS + "together.ldr")
	var here: Together = _main.get("_together")
	var library: PartLibrary = _main.get("_library")
	var other: Dictionary = _other_side(library, _hinge_ldr())
	var tw: BrickWorld = other["world"]
	var tb: Builder = other["builder"]
	var tt: Together = other["together"]
	var depth: int = _builder.history_depth()
	# A motion kept first, then the lock: another person's change to the
	# motions arriving later keeps the lock here (the review's case).
	await _say("define_motion", {"name": "Swing", "tracks": [{"joint": "Beam",
		"keys": [{"t": 0, "place": 0}, {"t": 1, "place": 45}]}]})
	await _say("pose_model", {"joint": "Beam", "lock": true})
	var own_line: Array = _lines_with(await _save("together_here.ldr"), Motions.LOCK_META)
	var words: String = here._motion_words()
	_check("here locked: the room's ~motions words carry the lock (%s)" % str(
		_lines_with(words, Motions.LOCK_META)), _lines_with(words, Motions.LOCK_META).size() == 1)
	tt._put_meta("~motions", words)
	var pin: int = _id_in(tw, "2780")
	var brick: int = _id_in(tw, "3701")
	_check("...there it is one lock, its two parts found (%s)" % (str(tw.motions.locks.size())
		if tw.motions != null else "no motions"), tw.motions != null and tw.motions.locks.size() == 1
		and tw.motions.lock_between(pin, brick, tw, tb) != null)
	var rest: Dictionary = _rest_in(tw)
	var held: Grab = _grab_in(tw, tb, library, pin)
	_check("...there a drag on the joint is refused by its name: \"%s\"" % held.why.left(110),
		held.state != "moves" and held.why.contains("Beam's joint") and held.why.contains(Motions.UNLOCK_WORDS))
	tb.clear_selection()
	tb.select_brick(pin, false)
	var moved: int = tb.move_selection(Vector3i(0, 0, 1))
	tb.clear_selection()
	_check("...and a move of its part by the keys, by name: \"%s\"" % tb.refused_lock.left(110),
		moved == 0 and tb.refused_lock.contains("Beam's joint") and tb.refused_lock.contains(Motions.UNLOCK_WORDS))
	_check("...nothing moved there", _same_in(tw, rest))
	_check("...and its motion with it (%d)" % tw.motions.list.size(), tw.motions.list.size() == 1)
	# There, the motion taken out (another person's change to the motions):
	# here the motion goes and the lock stays.
	var kept: Motions = tw.motions.copy()
	tw.motions.list.clear()
	tb.record([{"undo": "motions", "motions": kept}], "took out Swing")
	here._put_meta("~motions", tt._motion_words())
	_check("there took the motion out: here it is gone and the lock kept (%d motions, %d locks)" % [
		_world.motions.list.size() if _world.motions != null else -1, _locks_of(_world)],
		_world.motions != null and _world.motions.list.is_empty() and _locks_of(_world) == 1)
	var still: Variant = _grabbing.held_of([_id_of("2780")])
	_check("...and here it still holds: \"%s\"" % str(still).left(90), still is String
		and str(still).contains(Motions.UNLOCK_WORDS))
	# There unlocks, as its window's Unlock does: one step there.
	var had: Motions = tw.motions.copy()
	tw.motions.locks.clear()
	tb.record([{"undo": "motions", "motions": had}], "unlocked")
	here._put_meta("~motions", tt._motion_words())
	_check("there unlocked: here none is locked (%d)" % _locks_of(_world), _locks_of(_world) == 0)
	var turned: String = await _say("pose_model", {"joint": "Beam", "degrees": 30})
	_check("...and here it turns again: \"%s\"" % turned.left(80), not turned.contains(Motions.UNLOCK_WORDS)
		and turned.contains("30°"))
	_builder.undo()
	await _frames(3)
	here._put_meta("~motions", tt._motion_words())
	# There locks it again: here it is refused, and saved as here's own line.
	pin = _id_in(tw, "2780")
	brick = _id_in(tw, "3701")
	if tw.motions == null:
		tw.motions = Motions.new()
	had = tw.motions.copy()
	tw.motions.locks.append(Motions.lock_of(pin, brick, tw, (other["store"] as ModelStore).lift()))
	tb.record([{"undo": "motions", "motions": had}], "locked")
	here._put_meta("~motions", tt._motion_words())
	var refused: String = await _say("pose_model", {"joint": "Beam", "degrees": 30})
	_check("there locked: here a turn is refused by name: \"%s\"" % refused.left(90),
		refused.contains("Beam's joint") and refused.contains(Motions.UNLOCK_WORDS))
	var saved: String = await _save("together_there.ldr")
	_check("...and saved here as one LOCK line, the one this side writes (%s)" % str(
		_lines_with(saved, Motions.LOCK_META)), _texts(_lines_with(saved, Motions.LOCK_META)) == _texts(own_line))
	while _builder.history_depth() > depth:
		_builder.undo()
	for node: Node in [tt, tb, tw]:
		node.queue_free()
	await _frames(3)


## A second copy of the model, as another person's side has it: its own
## world, builder, store and Together, [param text] opened in it.
func _other_side(library: PartLibrary, text: String) -> Dictionary:
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	store.open_text(text, "Together")
	var together := Together.new()
	together.world = world
	together.builder = builder
	together.store = store
	together.keeps_place = false
	root.add_child(together)
	return {"world": world, "builder": builder, "store": store, "together": together}


func _grab_in(world: BrickWorld, builder: Builder, library: PartLibrary, id: int) -> Grab:
	var held := Grab.new()
	held.world = world
	held.builder = builder
	held.library = library
	held.begin(id, world.get_brick(id).transform.origin, {})
	return held


## The lines of [method _lines_with]'s [line, text] pairs, where a line's
## number moves with what was taken out above it.
static func _without_made(text: String) -> String:
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.begins_with(ModelStore.MADE_META):
			kept.append(line)
	return "\n".join(kept)


static func _texts(pairs: Array) -> Array:
	return pairs.map(func(pair: Array) -> String: return str(pair[1]))


static func _locks_of(world: BrickWorld) -> int:
	return world.motions.locks.size() if world.motions != null else 0


static func _id_in(world: BrickWorld, part: String) -> int:
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id == part:
			return brick.id
	return 0


static func _rest_in(world: BrickWorld) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		out[brick.id] = brick.transform
	return out


static func _same_in(world: BrickWorld, rest: Dictionary) -> bool:
	for id: int in rest:
		var brick: BrickWorld.Brick = world.get_brick(id)
		if brick == null or not brick.transform.is_equal_approx(rest[id]):
			return false
	return true


## A save while a section is broken out (H2): the LOCK line where the parts
## are built, the file byte for byte as saved in place, and reopened the
## lock holds.
func _case_breakout() -> void:
	print("\n══ breakout: a lock saved while its section is broken out ══")
	_write(MODELS + "knee_out.ldr", _knee_ldr())
	await _open(MODELS + "knee_out.ldr")
	await _say("pose_model", {"joint": "Leg", "lock": true})
	var in_place: String = await _save("knee_out.ldr")
	var said: String = await _say("break_out_section", {"section": "Leg"})
	await _frames(5)
	print("    %s" % said.left(100))
	# Broken out, the leg stands away from its hips: a turn of it is refused
	# for that, and the lock is named too (the review's putback step).
	var turned: String = await _say("move_part", {"part": "#%d" % _id_of("3816"), "degrees": 30})
	_check("broken out, a turn of the locked leg names the lock: \"%s\"" % turned.left(120),
		turned.contains(Motions.UNLOCK_WORDS) and turned.contains("Leg's joint"))
	var broken: String = await _save("knee_out_broken.ldr")
	_check("saved broken out: the LOCK line as saved in place (%s)" % str(_lines_with(broken, Motions.LOCK_META)),
		_lines_with(broken, Motions.LOCK_META) == _lines_with(in_place, Motions.LOCK_META))
	_check("...and the file byte for byte as saved in place (%s)" % ("same" if broken == in_place
		else _first_difference(in_place, broken)), broken == in_place)
	await _open(MODELS + "knee_out_broken.ldr")
	var held: Variant = _grabbing.held_of([_id_of("3816")])
	_check("reopened, the lock holds: \"%s\"" % str(held).left(80), held is String
		and str(held).contains(Motions.UNLOCK_WORDS))


## The live sibling of H2: a motion's joints saved while its section is
## broken out, where they are built. A joint kept by its sub-assembly's name
## (the knee's Leg, the slider's Axle) writes no place; one kept by its part
## (a leg of two in one sub-model, an axle under a brick of its own) writes
## where the part stands, and a slide its AT: those two were written at the
## broken-out place on pre261 (bench/results/jlfix-2026-11-19, sibling_*).
## Reopened, the motion finds its joint and plays it.
func _case_motion_breakout() -> void:
	for one: Array in [["knee", _knee_ldr(), "Leg", "Leg", false, 45.0],
			["slider", _slider_ldr(), "Axle", "Axle", true, 1.0],
			["legs", _legs_ldr(), "Legs", "3816", false, 45.0],
			["slide", _slide_ldr(), "Slide", "3705", true, 1.0]]:
		print("\n══ motion_breakout: %s's motion saved with %s broken out ══" % [one[0], one[2]])
		_write(MODELS + "mb_%s.ldr" % one[0], str(one[1]))
		await _open(MODELS + "mb_%s.ldr" % one[0])
		var joint: String = str(one[3]) if str(one[3]) == str(one[2]) else "#%d" % _id_of(str(one[3]))
		var track: Dictionary = {"joint": joint, "keys": [{"t": 0, "place": 0}, {"t": 1, "place": one[5]}]}
		if one[4]:
			track["slide"] = true
		await _say("define_motion", {"name": "Swing", "tracks": [track]})
		var in_place: String = await _save("mb_%s.ldr" % one[0])
		await _say("break_out_section", {"section": one[2]})
		await _frames(5)
		var broken: String = await _save("mb_%s_broken.ldr" % one[0])
		_check("%s: saved broken out, the motion's lines as in place (%s)" % [one[0],
			str(_lines_with(broken, "0 !BRICKWORKS MOTION_TRACK"))],
			_lines_with(broken, "0 !BRICKWORKS MOTION") == _lines_with(in_place, "0 !BRICKWORKS MOTION")
			and not _lines_with(in_place, "0 !BRICKWORKS MOTION_TRACK").is_empty())
		_check("...the file byte for byte as saved in place", broken == in_place)
		await _open(MODELS + "mb_%s_broken.ldr" % one[0])
		var played: String = await _say("play_motion", {"name": "Swing"})
		_check("...reopened, the motion finds its joint: \"%s\"" % played.replace("\n", " | ").left(110),
			played.contains("went from") and not played.contains("gone") and not played.contains("not found"))


## move_part to= on a locked joint (M1): nothing moved, and the lock named
## with its way out.
func _case_chain() -> void:
	print("\n══ chain: move_part to= on a locked joint ══")
	_write(MODELS + "chain.ldr", _hinge_ldr())
	await _open(MODELS + "chain.ldr")
	await _say("pose_model", {"joint": "Beam", "lock": true})
	var rest: Dictionary = _rest()
	var depth: int = _builder.history_depth()
	var said: String = await _say("move_part", {"part": "#%d" % _id_of("32524"), "to": [0, 20, 3]})
	_check("refused, nothing moved, the lock named: \"%s\"" % said.left(140), _same(rest)
		and _builder.history_depth() == depth and said.contains("Beam's joint") and said.contains(Motions.UNLOCK_WORDS))


## A lock in one copy of a sub-model placed three times (L1): the answer
## says which copy, and that the others still move.
func _case_copies() -> void:
	print("\n══ copies: a lock in one of three copies ══")
	var lines := PackedStringArray(["0 FILE knees.ldr", "0 Three knees", "0 Name: knees.ldr",
		"0 !BRICKWORKS FLOOR NONE"])
	for k: int in 3:
		lines.append("1 0 %d -32 1 1 0 0 0 1 0 0 0 1 3815.dat" % (10 + 60 * k))
		lines.append("1 4 %d -20 1 1 0 0 0 1 0 0 0 1 3817.dat" % (10 + 60 * k))
		lines.append("1 16 %d 0 0 1 0 0 0 1 0 0 0 1 leg.ldr" % (60 * k))
	lines.append_array(["0 NOFILE", "0 FILE leg.ldr", "0 Leg", "0 Name: leg.ldr",
		"1 4 10 -20 1 1 0 0 0 1 0 0 0 1 3816.dat", "0 NOFILE"])
	_write(MODELS + "knees.ldr", "\n".join(lines) + "\n")
	await _open(MODELS + "knees.ldr")
	var said: String = await _say("pose_model", {"joint": "1", "lock": true})
	print("    %s" % said.replace("\n", " | ").left(400))
	_check("the answer says which copy, and that the other two still move",
		said.contains("copy 1 of 3") and said.contains("other 2 copies") and said.contains("still moves"))


## A LOCK line naming parts the model has not got (L2): named once at the
## open, kept byte for byte.
func _case_dangling() -> void:
	print("\n══ dangling: a lock of parts the model has not got ══")
	var line: String = "0 !BRICKWORKS LOCK PART 3005 1 200 -24 200 ON PART 3001 4 200 0 200"
	var text: String = _hinge_ldr().replace("0 !BRICKWORKS FLOOR NONE\n", "0 !BRICKWORKS FLOOR NONE\n" + line + "\n")
	_write(MODELS + "dangling.ldr", text)
	await _open(MODELS + "dangling.ldr")
	var named: String = _store.motions_unread_words
	_check("named at the open: \"%s\"" % named.left(140), named.contains("parts the model has not got")
		and named.contains(line))
	var saved: String = await _save("dangling.ldr")
	_check("...and saved unedited byte for byte", saved == text)


## A locked part swapped for another by Find and Replace (the lead's ask):
## the lock goes to the part that took its place, is written so and holds
## after a reopen, and one undo puts the part and its lock back byte for
## byte. The first swap with room is the one tried: a part of another shape
## where a pin passes through has none on pre261 (find_replace.gd's room
## check counts the hole the pin sits in), so a printed part of the same
## mould goes first (3701's own twin, 370101, is read back as 3701 in White).
func _case_replace() -> void:
	var modern: String = _knee_ldr().replace("3815.dat", "3815b.dat").replace("3816.dat", "3816b.dat") \
		.replace("3817.dat", "3817b.dat")
	for one: Array in [["knee", modern, "Leg", "3815b", "3815bp04", "3816b", 0],
			["knee", modern, "Leg", "3816b", "3816bp30", "3816bp30", 4],
			["hinge", _hinge_ldr(), "Beam", "3701", "3700", "2780", 7]]:
		print("\n══ replace: %s's locked %s swapped for %s by Find and Replace ══" % [one[0], one[3], one[4]])
		_write(MODELS + "replace.ldr", str(one[1]))
		await _open(MODELS + "replace.ldr")
		await _say("pose_model", {"joint": one[2], "lock": true})
		var locked: String = await _save("replace.ldr")
		var depth: int = _builder.history_depth()
		var said: String = await _say("replace_parts", {"find": {"part": one[3]}, "replace": {"part": one[4]}})
		print("    %s" % said.replace("\n", " | ").left(240))
		if said.contains("no room"):
			continue
		var held: Variant = _grabbing.held_of([_id_of(str(one[5]))])
		_check("swapped, the lock is on the part that took its place: \"%s\"" % str(held).left(90),
			_id_of(str(one[4])) != 0 and _id_of(str(one[3])) == 0 and held is String
			and str(held).contains(Motions.UNLOCK_WORDS))
		var swapped: String = await _save("replace_swapped.ldr")
		var lines: Array = _texts(_lines_with(swapped, Motions.LOCK_META))
		_check("...saved as one LOCK line naming it (%s)" % str(lines), lines.size() == 1
			and str(lines[0]).contains("PART %s %d " % [one[4], one[6]])
			and not str(lines[0]).contains("PART %s " % one[3]))
		while _builder.history_depth() > depth:
			_builder.undo()
		# Undone, the model still says Claude worked on it (ModelStore.made_with
		# only goes up), so that line is left out of the comparison.
		var back: String = _without_made(await _save("replace_back.ldr"))
		locked = _without_made(locked)
		_check("...one undo puts the part and its lock back, byte for byte (%s)" % ("same" if back == locked
			else _first_difference(locked, back)), back == locked)
		await _open(MODELS + "replace_swapped.ldr")
		var again: Variant = _grabbing.held_of([_id_of(str(one[5]))])
		_check("...reopened swapped, the lock holds: \"%s\"" % str(again).left(80), again is String
			and str(again).contains(Motions.UNLOCK_WORDS))
		return
	_check("a locked part swapped with room for its new part", false)


# -- the models -------------------------------------------------------------------------


static func _knee_ldr() -> String:
	return "\n".join(PackedStringArray([
		"0 FILE knee.ldr", "0 A minifig's knee", "0 Name: knee.ldr", "0 !BRICKWORKS FLOOR NONE",
		"1 0 10 -32 1 1 0 0 0 1 0 0 0 1 3815.dat",
		"1 4 10 -64 1 1 0 0 0 1 0 0 0 1 973p42.dat",
		"1 4 10 -20 1 1 0 0 0 1 0 0 0 1 3817.dat",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 leg.ldr",
		"0 NOFILE",
		"0 FILE leg.ldr", "0 Leg", "0 Name: leg.ldr",
		"1 4 10 -20 1 1 0 0 0 1 0 0 0 1 3816.dat",
		"0 NOFILE"])) + "\n"


static func _tower() -> PackedStringArray:
	var lines := PackedStringArray()
	for k: int in range(1, 13):
		lines.append("1 4 0 %d -10 1 0 0 0 1 0 0 0 1 3001.dat" % (-24 * k))
	lines.append("1 7 0 -312 0 1 0 0 0 1 0 0 0 1 3701.dat")
	return lines


## A minifig's two legs in one sub-model: a turn of one leg is kept by its
## part, as the other does not move with it.
static func _legs_ldr() -> String:
	return "\n".join(PackedStringArray([
		"0 FILE legs.ldr", "0 A minifig's legs", "0 Name: legs.ldr", "0 !BRICKWORKS FLOOR NONE",
		"1 0 10 -32 1 1 0 0 0 1 0 0 0 1 3815.dat",
		"1 4 10 -64 1 1 0 0 0 1 0 0 0 1 973p42.dat",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 legs2.ldr",
		"0 NOFILE",
		"0 FILE legs2.ldr", "0 Legs", "0 Name: legs2.ldr",
		"1 4 10 -20 1 1 0 0 0 1 0 0 0 1 3816.dat",
		"1 4 10 -20 1 1 0 0 0 1 0 0 0 1 3817.dat",
		"0 NOFILE"])) + "\n"


## The slider's axle with a brick of its own in its sub-model: its slide is
## kept by its part.
static func _slide_ldr() -> String:
	var lines := PackedStringArray(["0 FILE slide.ldr", "0 An axle that slides", "0 Name: slide.ldr",
		"0 !BRICKWORKS FLOOR NONE"])
	for k: int in range(1, 13):
		lines.append("1 4 0 %d -10 1 0 0 0 1 0 0 0 1 3001.dat" % (-24 * k))
	lines.append("1 7 0 -312 0 1 0 0 0 1 0 0 0 1 3701.dat")
	lines.append_array(["1 16 0 0 0 1 0 0 0 1 0 0 0 1 slide2.ldr", "0 NOFILE",
		"0 FILE slide2.ldr", "0 Slide", "0 Name: slide2.ldr",
		"1 0 0 -302 0 0 0 -1 0 1 0 1 0 0 3705.dat",
		"1 1 0 -336 -10 1 0 0 0 1 0 0 0 1 3001.dat", "0 NOFILE"])
	return "\n".join(lines) + "\n"


static func _hinge_ldr() -> String:
	var lines := PackedStringArray(["0 FILE hinge.ldr", "0 A Technic hinge", "0 Name: hinge.ldr",
		"0 !BRICKWORKS FLOOR NONE"])
	lines.append_array(_tower())
	lines.append_array(["1 16 0 0 0 1 0 0 0 1 0 0 0 1 beam.ldr", "0 NOFILE",
		"0 FILE beam.ldr", "0 Beam", "0 Name: beam.ldr",
		"1 0 0 -302 10 0 0 -1 0 1 0 1 0 0 2780.dat",
		"1 14 0 -242 20 -1 0 0 0 0 1 0 1 0 32524.dat", "0 NOFILE"])
	return "\n".join(lines) + "\n"


static func _slider_ldr() -> String:
	var lines := PackedStringArray(["0 FILE slider.ldr", "0 An axle that slides", "0 Name: slider.ldr",
		"0 !BRICKWORKS FLOOR NONE"])
	lines.append_array(_tower())
	lines.append_array(["1 16 0 0 0 1 0 0 0 1 0 0 0 1 axle.ldr", "0 NOFILE",
		"0 FILE axle.ldr", "0 Axle", "0 Name: axle.ldr",
		"1 0 0 -302 0 0 0 -1 0 1 0 1 0 0 3705.dat", "0 NOFILE"])
	return "\n".join(lines) + "\n"


# -- helpers ----------------------------------------------------------------------------


func _select(id: int) -> void:
	_builder.clear_selection()
	_builder.select_brick(id, false)


func _id_of(part: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick.id
	return 0


func _rest() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


func _same(rest: Dictionary) -> bool:
	for id: int in rest:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		if brick == null or brick.transform.origin.distance_to((rest[id] as Transform3D).origin) > 0.01 \
				or not brick.transform.basis.is_equal_approx((rest[id] as Transform3D).basis):
			return false
	return rest.size() == _world.brick_count()


func _top_words() -> String:
	var words: Array = _builder.history_words(1)
	return str(words[0]) if not words.is_empty() else ""


func _save(file: String) -> String:
	if not bool(_main.call("save_model", MODELS + file)):
		print("    could not write %s" % file)
		return ""
	await _settled()
	return FileAccess.get_file_as_string(MODELS + file)


func _open(path: String) -> void:
	_main.call("_open", path)
	await _settled()


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _lines_with(text: String, start: String) -> Array:
	var out: Array = []
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		if lines[n].begins_with(start):
			out.append([n, lines[n].trim_suffix("\r")])
	return out


static func _without_line(text: String, index: int) -> String:
	var lines: PackedStringArray = text.split("\n")
	lines.remove_at(index)
	return "\n".join(lines)


static func _first_difference(a: String, b: String) -> String:
	var n: int = 0
	while n < mini(a.length(), b.length()) and a[n] == b[n]:
		n += 1
	return "differ at %d: %s | %s" % [n, a.substr(maxi(n - 20, 0), 60).c_escape(),
		b.substr(maxi(n - 20, 0), 60).c_escape()]


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	if text.is_empty() and (answer as Dictionary).has("error"):
		text = str((answer as Dictionary)["error"])
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return "\n".join(lines)


func _settled() -> void:
	for _n: int in 600:
		if _store == null or _store.awaited.is_empty():
			break
		await process_frame
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 120000:
		await process_frame
		if not Working.is_busy() and (_simulate == null or not _simulate.visible
				or (_simulate.get("sim") != null and not bool(_simulate.get("_reading"))
				and not bool(_simulate.get("_driving")))):
			break
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


## Press [param button] in the panel as a person does: scrolled into the
## panel's view first, then clicked at its middle. False (and said) when
## the press never reached it.
func _press(button: Button, what: String) -> bool:
	_pose._body.ensure_control_visible(button)
	await _frames(4)
	var heard: Array = [false]
	var hear := func() -> void: heard[0] = true
	button.pressed.connect(hear)
	var rect: Rect2 = button.get_global_rect()
	var shown: Rect2 = _pose._body.get_global_rect()
	var move := InputEventMouseMotion.new()
	move.position = _as_event(rect.get_center())
	move.global_position = move.position
	Input.parse_input_event(move)
	await _frames(3)
	var over: Control = root.gui_get_hovered_control()
	await _click(rect.get_center())
	await _frames(2)
	_check("%s pressed by the mouse (the pointer over %s)" % [what, _path_of(over)], heard[0])
	if not heard[0]:
		print("    ... at %s, the panel's view %s, disabled %s, shown %s; pressed as its signal, to go on" % [
			rect, shown, button.disabled, button.is_visible_in_tree()])
		if is_instance_valid(button):
			button.pressed.emit()
		await _frames(3)
	if is_instance_valid(button) and button.pressed.is_connected(hear):
		button.pressed.disconnect(hear)
	return heard[0]


func _path_of(control: Control) -> String:
	if control == null:
		return "nothing"
	var names := PackedStringArray()
	var node: Node = control
	while node != null and names.size() < 5:
		names.insert(0, "%s(%s)" % [node.name, node.get_class()])
		node = node.get_parent()
	return "/".join(names)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		if down:
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		await _frames(2)
