## Where the person's Claude stalled or guessed in mcpreach3's MCP walk of
## 19 November, each in its tool's own answer (mcpreach4, docs/APP_UX11.md,
## "mcpreach4, in full").
##
##   godot --path . --resolution 1280x720 --script src/dev/mcpreach4_probe.gd
##
## Every call is a session's, through CommandSocket's tools/call, and counted.
##
##  1  attachment_points on a part with no studs, asked before it is put down
##     (the SPIKE Prime large motor 54675, a Technic beam 9): every face it can
##     stand on in one answer, the motor's output on each said where a call
##     with that face= says it, and how real sets mount it; a brick with studs
##     has no such table; a click hinge's brick says how real sets build on a
##     hinge so it turns.
##  2  move_part on a click hinge's own brick (the half on the plate) moves the
##     hinge's other half, as a drag on it does, and says which half moved and
##     which way degrees= swings it; the arm raised as told, not refused. Both
##     halves laid on one plate: move_part with no part= names that hinge as
##     held still and the plate gripping it, and so does the refusal.
##  3  submit_design names the numbers of the bricks it laid against the
##     "brick N" a check counts them by, and edit_model takes the last one.
##  4  simulate_mechanism at= pictures the model's program at that moment,
##     each motor's angle and the line running, and nothing is written: the
##     program, the history and every part as they were. With program=, set
##     and pictured at at= in one call.
##  5  check_design with edit= says first what the copy showed, then that the
##     model itself is as it was, and names no part numbers it did not lay.
extends SceneTree

const CHAT := "probe-mcpreach4-chat"
const WATCHDOG := 1200.0
## hubprogram_probe's motor stand: the SPIKE Prime motor's output along z.
const SPIKE_STANDS := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
const FACES: Array[String] = ["up", "down", "+x", "-x", "+z", "-z"]
var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _next: int = 0
var _calls: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("mcpreach4_probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	SaveTo.native = false
	Account.where = "user://probe_mcpreach4_session.json"
	Account._clear()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")) and _main.get("_shell") != null and _main.get("_bar") != null:
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var account: Account = _main.get("_account")
	while account.state == Account.State.CHECKING:
		await account.changed
	await process_frame
	await _every_face()
	await _hinge_moves()
	await _hinge_held()
	await _numbers()
	await _program_at()
	await _what_if()
	_quit()


# -- 1. attachment_points: every face of a part with no studs in one answer --------------


func _every_face() -> void:
	print("")
	print("1. attachment_points on a part with no studs: every face it can stand on, in one call")
	await _say("clear_model", {})
	_calls = 0
	var motor: String = await _say("attachment_points", {"part": "54675", "x": 0, "y": 0, "z": 0})
	var table: Dictionary = _face_lines(motor)
	print("    " + motor.substr(motor.find("Every way")).left(1400).replace("\n", "\n    "))
	_check("the motor: every face in 1 call (%d calls, %d faces)" % [_calls, table.size()],
		_calls == 1 and table.size() == 6)
	var outputs: int = 0
	for face: String in table:
		outputs += 1 if str(table[face]).contains("its output") else 0
	_check("...its output said on each face (%d of 6)" % outputs, outputs == 6)
	_check("...level on +z and -z, upright on up: %s / %s" % [str(table.get("+z", "")).get_slice(";", 1),
		str(table.get("up", "")).get_slice(";", 1)], str(table.get("+z", "")).contains("its output along z")
		and str(table.get("-z", "")).contains("its output along z")
		and str(table.get("up", "")).contains("its output up and down"))
	_check("...and how real sets mount it", motor.contains("How real sets mount a motor's case"))
	# Each face's line against the answer a call with that face= gives, as
	# r1's and y6's sessions asked it, a face a call.
	var agreed: int = 0
	for face: String in FACES:
		var one: String = await _say("attachment_points", {"part": "54675", "x": 0, "y": 0, "z": 0,
			"face": face})
		var line_through: RegExMatch = RegEx.create_from_string(
			"about the line through (x=\\S+ y=\\S+ z=\\S+) running").search(one)
		var in_table: RegExMatch = RegEx.create_from_string("about (x=\\S+ y=\\S+ z=\\S+)").search(
			str(table.get(face, "")))
		var same: bool = line_through != null and in_table != null \
			and line_through.get_string(1) == in_table.get_string(1).trim_suffix(";")
		if not same:
			print("    face=%s: a call says %s, the table %s" % [face,
				line_through.get_string(1) if line_through != null else "-",
				in_table.get_string(1) if in_table != null else "-"])
		agreed += 1 if same else 0
	_check("...each face's output where a call with that face= puts it (%d of 6)" % agreed, agreed == 6)
	var beam: String = await _say("attachment_points", {"part": "40490", "x": 0, "y": 0, "z": 0})
	var beam_table: Dictionary = _face_lines(beam)
	print("    " + str(beam_table.get("up", "-")))
	_check("a Technic beam 9: every face, its 9 pin holes on each, no output (%d faces)" % beam_table.size(),
		beam_table.size() == 6 and str(beam_table.get("up", "")).contains("9 pin holes")
		and not beam.contains("its output"))
	_check("...and how real sets join it", beam.contains("How real sets join a part with no studs"))
	var brick: String = await _say("attachment_points", {"part": "3001", "x": 0, "y": 0, "z": 0})
	_check("a 2 x 4 brick, with studs: no table", not brick.contains("Every way it can stand"))
	var hinge: String = await _say("attachment_points", {"part": "30365", "x": 0, "y": 1, "z": 0})
	_check("a click hinge's brick says how real sets build on a hinge",
		hinge.contains("A hinge turns only while no one part grips both its halves"))


## The table's lines by face: face -> its line.
static func _face_lines(text: String) -> Dictionary:
	var out: Dictionary = {}
	var at: int = text.find("Every way it can stand")
	if at < 0:
		return out
	for line: String in text.substr(at).split("\n"):
		var found: RegExMatch = RegEx.create_from_string("^  face=(\\S+): ").search(line)
		if found != null:
			out[found.get_string(1)] = line
	return out


# -- 2. move_part on a click hinge's own brick ------------------------------------------


func _hinge_moves() -> void:
	print("")
	print("2. move_part on a click hinge's own brick moves the hinge's other half")
	await _say("clear_model", {})
	# mcpreach3's r2 arm: the hinge's brick at the plate's edge, its other
	# half out past it with the arm on it.
	await _say("edit_model", {"add": [
		{"part": "3020", "color": 71, "x": 14, "y": 0, "z": 0},
		{"part": "30365", "color": 71, "name": "hb", "x": 16, "y": 1, "z": 0},
		{"part": "30364", "color": 0, "name": "arm", "attach": {"to": "hb.hinge[0]", "by": "hinge[0]",
			"flip": true, "yaw": 180}}], "picture": false})
	await _say("edit_model", {"add": [
		{"part": "3666", "color": 0, "x": 19, "y": 4, "z": 0},
		{"part": "3001", "color": 4, "x": 21, "y": 5, "z": 0}], "picture": false})
	var hb: int = _one_of("30365")
	var arm: int = _one_of("30364")
	var far: int = _one_of("3001")
	_check("the arm is built: %d parts, the hinge #%d and #%d" % [_world.brick_count() - _store.scenery.size(),
		hb, arm], hb > 0 and arm > 0 and far > 0)
	if hb <= 0 or arm <= 0 or far <= 0:
		return
	_calls = 0
	var asked: String = await _say("move_part", {"part": str(hb)})
	print("    " + asked.replace("\n", "\n    "))
	_check("move_part on the hinge's brick on the plate: #%d's half is the one that moves, #%d's stays" % [arm, hb],
		asked.contains("On its hinge, #%d's half is the one that moves" % arm)
		and asked.contains("#%d's half stays" % hb) and not asked.contains("will not move"))
	var sense: RegExMatch = RegEx.create_from_string("(above|below) 0 swings it up").search(asked)
	_check("...and which way degrees= raises it: %s" % _line_with(asked, "degrees= above 0").get_slice(". ", 1),
		sense != null)
	var up: float = 45.0 if sense == null or sense.get_string(1) == "above" else -45.0
	var was: Transform3D = _world.get_brick(arm).transform
	var far_was: float = _world.get_brick(far).transform.origin.y
	var moved: String = await _say("move_part", {"part": str(hb), "degrees": up})
	print("    " + moved.replace("\n", "\n    "))
	var turned: float = rad_to_deg(was.basis.get_rotation_quaternion().angle_to(
		_world.get_brick(arm).transform.basis.get_rotation_quaternion()))
	var rose: float = _world.get_brick(far).transform.origin.y - far_was
	_check("...degrees=%d on the same brick raises the arm: #%d turned %d°, its far brick %s LDU up, said so (%d calls)"
		% [roundi(up), arm, roundi(turned), str(snappedf(rose, 0.1)), _calls],
		moved.contains("#%d's half moved" % arm) and absf(turned - 45.0) < 12.0 and rose > 4.0
		and _calls == 2)
	await _say("undo", {})
	_check("...one undo puts it back", _world.get_brick(arm) != null
		and _world.get_brick(arm).transform.origin.distance_to(was.origin) < 0.5)
	var direct: String = await _say("move_part", {"part": str(arm), "degrees": up})
	_check("move_part on the moving half itself moves it and says so",
		direct.contains("#%d's half moved" % arm) and not direct.contains("will not move"))
	await _say("undo", {})


## Both halves of the click hinge laid on one 2 x 4 plate, as r2's session
## first laid them: held still, and said so before and at the refusal.
func _hinge_held() -> void:
	print("")
	print("2b. both halves of a click hinge on one plate: held still, and the plate named")
	await _say("clear_model", {})
	await _say("edit_model", {"add": [
		{"part": "3020", "color": 71, "x": 14, "y": 0, "z": 0},
		{"part": "30365", "color": 71, "name": "hb", "x": 14, "y": 1, "z": 0},
		{"part": "30364", "color": 0, "name": "arm", "attach": {"to": "hb.hinge[0]", "by": "hinge[0]",
			"flip": true, "yaw": 180}}], "picture": false})
	var plate: int = _one_of("3020")
	var arm: int = _one_of("30364")
	var listed: String = await _say("move_part", {})
	print("    " + listed.replace("\n", "\n    "))
	_check("move_part with no part= names the hinge held still and the plate #%d gripping it" % plate,
		listed.contains("Hinges held still as built") and listed.contains("(#%d) grips both its halves" % plate))
	var refused: String = await _say("move_part", {"part": str(arm), "degrees": 45})
	print("    " + refused.replace("\n", "\n    "))
	_check("...and the refusal says why and what to move",
		refused.contains("As built, its hinge cannot turn") and refused.contains("(#%d) grips both its halves" % plate)
		and refused.contains("move it so it holds one half only"))


# -- 3. submit_design names the numbers it laid ----------------------------------------


func _numbers() -> void:
	print("")
	print("3. submit_design names its parts' numbers, as edit_model's answer does")
	await _say("clear_model", {})
	var assistant: Assistant = _main.get("_assistant")
	assistant._joints_refused = true
	var design: Dictionary = _owl()
	var built: String = await _say("submit_design", design)
	var line: String = _line_with(built, "Its parts by number")
	print("    " + line)
	var run: RegExMatch = RegEx.create_from_string("bricks 0-(\\d+) are #(\\d+)-#(\\d+)").search(line)
	_check("the answer names every brick's number against the check's brick N",
		built.begins_with("Built") and run != null
		and int(run.get_string(1)) == (design["bricks"] as Array).size() - 1)
	if run == null:
		return
	var first: int = int(run.get_string(2))
	var same: int = 0
	for n: int in (design["bricks"] as Array).size():
		var brick: BrickWorld.Brick = _world.get_brick(first + n)
		var asked: String = str((design["bricks"] as Array)[n]["part"])
		if brick != null and _library.resolve(brick.part_id) == _library.resolve(asked):
			same += 1
	_check("...each number the part given at its place (%d of %d)" % [same, (design["bricks"] as Array).size()],
		same == (design["bricks"] as Array).size())
	var last: int = int(run.get_string(3))
	var moved: String = await _say("edit_model", {"move": [{"bricks": [last], "dz": 1}], "picture": false})
	_check("edit_model takes the last one's number: %s" % moved.get_slice("\n", 0).left(60),
		moved.begins_with("Done") and not moved.contains("No brick has number"))


func _owl() -> Dictionary:
	var bricks: Array = [{"part": "91405", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for level: int in 4:
		for x: int in [4, 8]:
			bricks.append({"part": "3001", "color": 19, "x": x, "y": 1 + level * 3, "z": 6, "rot": 0})
	return {"name": "barn owl", "description": "a body on a base", "bricks": bricks,
		"assemblies": [{"name": "owl", "x_from": 0, "x_to": 16, "z_from": 0, "z_to": 16}],
		"features": [{"name": "eyes", "x": 5, "y": 13, "z": 7, "facing": "+z"}]}


# -- 4. simulate_mechanism at= ---------------------------------------------------------


func _program_at() -> void:
	print("")
	print("4. simulate_mechanism at=: the program pictured at a moment, nothing written")
	await _say("clear_model", {})
	var none: String = await _say("simulate_mechanism", {"at": 1})
	_check("with no program, at= says so: %s" % none.left(60), none.begins_with("The model has no program"))
	_spike_beam()
	await _frames(10)
	var program: String = "to 90° at 50%\nwait 1 s\nto 0° at 50%"
	var ran: String = await _say("simulate_mechanism", {"program": program})
	_check("the program set and run: %s" % _line_with(ran, "Ran to its end").left(90),
		ran.contains("Ran to its end in 1.34 s"))
	var depth: int = _builder.history_depth()
	var rest: Dictionary = _rest()
	var unsaved: bool = _store.has_unsaved_work()
	_calls = 0
	var at: Array = await _say_all("simulate_mechanism", {"at": 0.5})
	print("    " + str(at[0]).replace("\n", "\n    "))
	_check("at=0.5: A at 90° on line 2, read not run again, pictured (%d call)" % _calls,
		str(at[0]).contains("At 0.5 s of the program's 1.34 s: A 90°, on line 2.")
		and str(at[0]).contains("Read, not run again") and int(at[1]) == 1 and _calls == 1)
	_check("...and nothing written: the program, the history and every part as they were",
		_program_now() == program and _builder.history_depth() == depth and _same_as(rest)
		and _store.has_unsaved_work() == unsaved)
	var rising: String = await _say("simulate_mechanism", {"at": 0.1})
	var angle: RegExMatch = RegEx.create_from_string("A (-?[\\d.]+)°").search(rising)
	_check("at=0.1: on its way up, between 0° and 90° (%s)" % (angle.get_string(1) if angle != null else "-"),
		angle != null and float(angle.get_string(1)) > 5.0 and float(angle.get_string(1)) < 85.0
		and rising.contains("on line 1"))
	var after: String = await _say("simulate_mechanism", {"at": 30})
	_check("at= past its end: where it ended, A 0°", after.contains("(it ends sooner, so where it ended): A 0°"))
	var both: Array = await _say_all("simulate_mechanism", {"program": "to 45° at 50%", "at": 5})
	print("    " + str(both[0]).replace("\n", "\n    "))
	_check("program= with at=: set, run and pictured at at= in 1 call, 1 picture",
		str(both[0]).begins_with("Set as the model's program") and str(both[0]).contains(": A 45°.")
		and int(both[1]) == 1 and _program_now() == "to 45° at 50%"
		and _builder.history_depth() == depth + 1)
	await _say("undo", {})
	_check("...one undo takes it back to the first program", _program_now() == program)


## hubprogram_probe's SPIKE beam: the motor on a stand of 1 x 2 bricks, a
## Technic beam pinned into its output.
func _spike_beam() -> void:
	var t: float = _top_of_floor()
	var h: float = t + 326.0
	var x: float = 0.0
	for n: int in 7:
		_place("3003", Transform3D(Basis.IDENTITY, Vector3(x, t + 24.0 * (n + 1), -50)), 71)
	_place("3738", Transform3D(Basis.IDENTITY, Vector3(x, h - 150, -50)), 71)
	for dx: float in [-40.0, 40.0]:
		_place("2780", Transform3D(Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)),
			Vector3(x + dx, h - 150, -50)), 0)
	_place("54675", Transform3D(SPIKE_STANDS, Vector3(x, h, -50)), 71)
	_place("32316", Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)),
		Vector3(x, h, 10)), 14)
	for y: float in [20.0, -20.0]:
		_place("2780", Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)),
			Vector3(x, h + y, 0)), 0)


func _top_of_floor() -> float:
	var top: float = -INF
	for id: Variant in _store.scenery:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick == null:
			continue
		var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		var studs: float = 4.0 if _library.parts[brick.part_id].stud_count > 0 else 0.0
		top = maxf(top, box.end.y - studs)
	return top if top > -INF else 0.0


func _place(part_id: String, at: Transform3D, colour: int) -> int:
	var id: int = _world.add_brick(part_id, colour, at)
	_builder.register(id, part_id, at)
	return id


func _program_now() -> String:
	return str(_world.get("program")) if _world.get("program") != null else ""


func _rest() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = brick.transform
	return out


func _same_as(rest: Dictionary) -> bool:
	for id: Variant in rest:
		var brick: BrickWorld.Brick = _world.get_brick(int(id))
		if brick == null or not brick.transform.is_equal_approx(rest[id]):
			return false
	return _world.bricks().size() == rest.size()


# -- 5. a what-if says what the copy showed first ---------------------------------------


func _what_if() -> void:
	print("")
	print("5. check_design edit=: what the copy showed first, then that the model is as it was")
	await _say("clear_model", {})
	await _say("edit_model", {"add": [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0},
		{"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0}], "picture": false})
	var rest: Dictionary = _rest()
	var top: int = _one_of_at("3001", 3)
	var said: String = await _say("check_design", {"edit": {"remove": [top]}})
	print("    " + said.left(500).replace("\n", "\n    "))
	var copy_at: int = said.find("the copy showed this")
	var model_at: int = said.find("That was the copy. The model itself is as it was")
	var findings_at: int = said.find("buildable")
	_check("it begins with what the copy showed, the model as it was said after the findings",
		said.begins_with("What if, on a copy of the model as it stands (took off 1): the copy showed this.")
		and copy_at >= 0 and findings_at > copy_at and model_at > findings_at
		and said.find("nothing on the baseplate changed") > findings_at)
	_check("...and the model is as it was", _same_as(rest))
	var added: String = await _say("check_design", {"edit": {"add": [
		{"part": "3001", "color": 1, "x": 0, "y": 6, "z": 0}]}})
	_check("a what-if names no part numbers for what it would put down: %s" % added.get_slice("\n", 0),
		added.get_slice("\n", 0).contains("(put down 1)") and not added.get_slice("\n", 0).contains("#"))


# -- helpers ----------------------------------------------------------------------------


## The one part of [param part_id] in the model, -1 for none.
func _one_of(part_id: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id and not _store.scenery.has(brick.id):
			return brick.id
	return -1


## The part of [param part_id] standing [param plates] plates up, -1 for none.
func _one_of_at(part_id: String, plates: int) -> int:
	var best: int = -1
	var highest: float = -INF
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id and not _store.scenery.has(brick.id) \
				and brick.transform.origin.y > highest:
			highest = brick.transform.origin.y
			best = brick.id
	return best if plates > 0 else _one_of(part_id)


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return "-"


## A session's call, its job followed to the end as a session follows it.
func _say(tool: String, arguments: Dictionary) -> String:
	return str((await _say_all(tool, arguments))[0])


## A session's call: [its text, how many pictures].
func _say_all(tool: String, arguments: Dictionary) -> Array:
	_calls += 1
	var said: Array = await _one(tool, arguments)
	var job := RegEx.create_from_string("^Started job (\\d+)")
	var found: RegExMatch = job.search(str(said[0]))
	var polls: int = 0
	while found != null and polls < 120:
		said = await _one("job", {"id": int(found.get_string(1))})
		polls += 1
		if not str(said[0]).contains("is still going"):
			break
	return said


func _one(tool: String, arguments: Dictionary) -> Array:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments,
			"_meta": {CommandSocket.CHAT_KEY: {"chat": CHAT}}}})
	var text := PackedStringArray()
	var pictures: int = 0
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		var kind: String = str((block as Dictionary).get("type", ""))
		if kind == "text":
			text.append(str((block as Dictionary).get("text", "")))
		elif kind == "image":
			pictures += 1
	return ["\n".join(text), pictures]


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _quit() -> void:
	if _socket != null:
		_socket.stop()
	print("mcpreach4_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
