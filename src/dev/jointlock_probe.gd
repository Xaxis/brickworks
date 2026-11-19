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

	await _model("knee", _knee_ldr(), "3816", "3815", "Leg", "row")
	await _model("hinge", _hinge_ldr(), "32524", "3701", "Beam", "mcp")
	await _model("slider", _slider_ldr(), "3705", "3701", "Axle", "row")

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
