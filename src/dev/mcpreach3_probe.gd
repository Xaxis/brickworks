## Where the person's Claude stalled or guessed in APP_UX10's MCP walk, each in
## the answer that would have spared it (mcpreach3, docs/APP_UX10.md).
##
##   godot --path . --resolution 1280x720 --script src/dev/mcpreach3_probe.gd
##   tools/relay_probe.sh mcpreach3      # r5 too, on a relay of its own
##
## Every call is a session's, through CommandSocket's tools/call, and counted.
## The sixth, the other chats' line once a chat, is the relay's (api/mcp.js),
## checked by tests/test_relay_chats.py and tabpair_probe.
##
##  g1  A design with two features unsettled on the baseplate, and a set to
##      open: open_model is refused, its refusal names save_first=, and
##      open_model save_first= saves it and opens, 2 calls, the design kept
##      in the person's models. save_model over unsettled features writes
##      the file and says what is not finished.
##  r5  edit_collection sets=["31058-1"] built=["31058-1"]: added and kept
##      built in 1 call, "0 loose parts" said; the account holds one copy,
##      built. A throwaway account, deleted after: only on a relay of this
##      machine (BRICKWORKS_API), as tools/relay_probe.sh runs it.
##  r2  An arm on a click hinge, no assembly named: pose_model lists the
##      hinge and swings it, 2 calls.
##  y6  attachment_points on the SPIKE Prime motor says how real sets mount
##      it; r1's motor on two 1 x 1 bricks is named as swivelling at
##      check_design and again as built, before Simulate; mcpreach2's
##      pinned motor is not.
##  t9  edit_steps: step= past the last makes a new last step; next and new
##      on a part alone in the last step, and to its own step, each say why
##      nothing changed.
extends SceneTree

const CHAT := "probe-mcpreach3-chat"
const SET := "31058-1"
## r1's build, as the walk's session gave it to submit_design: the motor on
## two 1 x 1 bricks, one stud each.
const R1_BUILD: Array = [
	{"part": "41539", "color": 72, "x": -1, "y": 0, "z": -2},
	{"part": "3005", "color": 0, "x": 0, "y": 1, "z": 1},
	{"part": "3005", "color": 0, "x": 4, "y": 1, "z": 1},
	{"part": "54675", "color": 322, "name": "motor", "x": 0, "y": 4, "z": 0, "face": "+z", "rot": 2},
	{"part": "2780", "color": 0, "name": "pa", "attach": {"to": "motor.socket[3]", "by": "pin[1]"}},
	{"part": "2780", "color": 0, "name": "pb", "attach": {"to": "motor.socket[1]", "by": "pin[1]"}},
	{"part": "40490", "color": 4, "name": "arm", "attach": {"to": "pa.pin[0]", "by": "socket[0]",
		"align": ["+x", "+x"]}},
]
## mcpreach2's y6 build: the motor pinned into two beams by four pins.
const Y6_BUILD: Array = [
	{"part": "54675", "color": 322, "x": 20, "y": 0, "z": 0, "face": "+z", "rot": 2},
	{"part": "32524", "color": 72, "axis": "x", "x": 19.5, "y": 1.25, "z": 3.5},
	{"part": "32524", "color": 72, "axis": "x", "x": 25.5, "y": 1.25, "z": 3.5},
	{"part": "2780", "color": 0, "axis": "x", "x": 20, "y": 1.25, "z": 0.5},
	{"part": "2780", "color": 0, "axis": "x", "x": 20, "y": 1.25, "z": 2.5},
	{"part": "2780", "color": 0, "axis": "x", "x": 25, "y": 1.25, "z": 0.5},
	{"part": "2780", "color": 0, "axis": "x", "x": 25, "y": 1.25, "z": 2.5},
]
## r2's arm as the walk's session built it: a plate, the hinge's two halves,
## a 1 x 6 plate and a 2 x 4 brick on its far end.
const R2_BUILD: Array = [
	{"part": "3020", "color": 71, "x": 14, "y": 0, "z": 0},
	{"part": "30365", "color": 71, "x": 16, "y": 1, "z": 0},
	{"part": "30364", "color": 0, "x": 18, "y": 1, "z": 0, "rot": 2},
	{"part": "3666", "color": 0, "x": 19, "y": 4, "z": 0},
	{"part": "3001", "color": 4, "x": 21, "y": 5, "z": 0},
]

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _calls: int = 0
var _account: Account
var _email: String = ""
var _password: String = ""
var _written: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_mcpreach3_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_mcpreach3_collection.json"
	DirAccess.remove_absolute(CollectionStore.where)
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
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_account = _main.get("_account")
	while _account.state == Account.State.CHECKING:
		await _account.changed
	await process_frame
	await _save_and_open()
	await _steps()
	await _hinge()
	await _motor()
	await _set_added()
	_quit()


# -- g1: a save never refused, and an open that keeps the design -------------------------


func _owl() -> Dictionary:
	var bricks: Array = [{"part": "91405", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for level: int in 4:
		for x: int in [4, 8]:
			bricks.append({"part": "3001", "color": 19, "x": x, "y": 1 + level * 3, "z": 6, "rot": 0})
	return {"name": "barn owl", "description": "a body on a base", "bricks": bricks,
		"assemblies": [{"name": "owl", "x_from": 0, "x_to": 16, "z_from": 0, "z_to": 16}],
		"features": [{"name": "eyes", "x": 5, "y": 13, "z": 7, "facing": "+z"},
			{"name": "beak", "x": 8, "y": 1, "z": 13, "facing": "+z"}]}


func _save_and_open() -> void:
	print("")
	print("g1: a save is never refused, and an open keeps the model it replaces")
	await _say("clear_model", {})
	var assistant: Assistant = _main.get("_assistant")
	assistant._joints_refused = true
	var built: String = await _say("submit_design", _owl())
	_check("the owl is built, its two features handed over: %s" % built.left(80),
		built.contains("the app lays the best real set's piece"))
	var store: ModelStore = _main.get("_store")
	var file: String = "probe-mcpreach3-owl-%d.ldr" % OS.get_process_id()
	var path: String = ModelStore.SAVE_DIR + file
	_written.append(path)
	var saved: String = await _say("save_model", {"name": file})
	print("    " + saved.left(300).replace("\n", "\n    "))
	_check("save_model with 2 features unsettled writes the file", FileAccess.file_exists(path)
		and saved.begins_with("Written to %s" % file))
	_check("...and says what is not finished, the first feature handed back",
		saved.contains("Not finished yet: 2 of its 2 features are not settled")
		and saved.contains("The eyes") and not saved.contains("Not saved yet"))
	# A change since, then a set's model to open over it.
	await _say("edit_model", {"add": [{"part": "3024", "color": 15, "x": 0, "y": 13, "z": 6}],
		"picture": false})
	var other: String = (store.list_examples()[0] as ModelStore.Entry).name
	var kept: String = "probe-mcpreach3-kept-%d.ldr" % OS.get_process_id()
	_written.append(ModelStore.SAVE_DIR + kept)
	_calls = 0
	var refused: String = await _say("open_model", {"name": other})
	print("    " + refused.left(300))
	_check("open over unsaved changes is refused, and names save_first=",
		refused.begins_with("Not opened") and refused.contains("save_first="))
	var parts_before: int = (_main.get("_world") as BrickWorld).brick_count()
	var opened: String = await _say("open_model", {"name": other, "save_first": kept})
	print("    " + opened.left(300))
	_check("open_model save_first= saves it and opens %s in %d calls" % [other, _calls],
		_calls == 2 and opened.begins_with("Saved ") and opened.contains("Opened %s" % other))
	var text: String = FileAccess.get_file_as_string(ModelStore.SAVE_DIR + kept)
	_check("...the design kept in the person's models, its new tile too (%d parts before)" % parts_before,
		text.count("\n1 ") + (1 if text.begins_with("1 ") else 0) >= 10 and text.contains("3024.dat"))
	var again: String = await _say("open_model", {"name": other, "save_first": kept})
	_check("...and save_first= over no changes opens without saving: %s" % again.left(80),
		again.begins_with("Opened %s" % other))


# -- t9: edit_steps says why nothing changed ------------------------------------------------


func _steps() -> void:
	print("")
	print("t9: edit_steps says why nothing changed, and step= past the last makes a step")
	await _say("clear_model", {})
	var wall: Array = []
	for row: int in 3:
		for x: int in [0, 4]:
			wall.append({"part": "3001", "color": 4, "x": x, "y": row * 3, "z": 0, "rot": 0})
	var built: String = await _say("submit_design", {"name": "Small red wall", "description": "a wall",
		"floor": "none", "bricks": wall})
	_check("the wall is built: %s" % built.left(60), built.begins_with("Built"))
	var listed: String = await _say("edit_steps", {"op": "list"})
	var rows: Array = _step_rows(listed)
	print("    steps: %s" % str(rows))
	if rows.size() < 2:
		_check("the wall has steps to move between", false)
		return
	var last: int = rows.size()
	var top: Array = rows[last - 1]
	_calls = 0
	var past: String = await _say("edit_steps", {"op": "to", "bricks": top, "step": last + 2})
	print("    " + past)
	var after: Array = _step_rows(await _say("edit_steps", {"op": "list"}))
	_check("step= past the last: a new step after the last, said why not further",
		past.contains("There are %d steps, so step %d is a new one after the last" % [last, last + 1])
		or past.contains("the steps are as they were"))
	var alone: int = int((after[after.size() - 1] as Array)[0])
	var next: String = await _say("edit_steps", {"op": "next", "bricks": [alone]})
	print("    " + next)
	_check("next on the last step's only part says why nothing changed",
		next.begins_with("the steps are as they were: #%d is all of step %d, the last step" % [alone,
			after.size()]) and next.contains("an empty step is taken out"))
	var new: String = await _say("edit_steps", {"op": "new", "bricks": [alone]})
	print("    " + new)
	_check("new on a part alone in its step says why", new.contains("is all of step %d already" % after.size()))
	var to: String = await _say("edit_steps", {"op": "to", "bricks": [alone], "step": after.size()})
	_check("to its own step says it is there already: %s" % to, to.contains("in step %d already" % after.size()))
	# The whole top row three steps later, from a model whose top row is two
	# steps from the end: list, to, to.
	await _say("clear_model", {})
	var four: Array = []
	for row: int in 4:
		for x: int in [0, 4]:
			four.append({"part": "3001", "color": 4, "x": x, "y": row * 3, "z": 0, "rot": 0})
	await _say("submit_design", {"name": "Small red wall", "description": "a wall", "floor": "none",
		"bricks": four})
	_calls = 0
	var steps: Array = _step_rows(await _say("edit_steps", {"op": "list"}))
	print("    steps: %s" % str(steps))
	var first_row: Array = steps[0]
	var moved: String = await _say("edit_steps", {"op": "to", "bricks": first_row, "step": 4})
	print("    " + moved + " (%d calls)" % _calls)
	var now: Array = _step_rows(await _say("edit_steps", {"op": "list"}))
	var where: int = -1
	for n: int in now.size():
		if (now[n] as Array).has(int(first_row[0])):
			where = n + 1
	_check("a row three steps later in 2 calls: step 1 to step %d" % where, where == 4)


## edit_steps list's rows: each step's part numbers.
static func _step_rows(listed: String) -> Array:
	var out: Array = []
	var row := RegEx.create_from_string("^\\s+(\\d+)[^:]*: (.*)$")
	var number := RegEx.create_from_string("#(\\d+)")
	for line: String in listed.split("\n"):
		var found: RegExMatch = row.search(line)
		if found == null:
			continue
		var ids: Array = []
		for one: RegExMatch in number.search_all(found.get_string(2)):
			ids.append(int(one.get_string(1)))
		out.append(ids)
	return out


# -- r2: a click hinge is a joint without an assembly -------------------------------------


func _hinge() -> void:
	print("")
	print("r2: a click hinge's arm posed with no assembly named")
	await _say("clear_model", {})
	var built: String = await _say("submit_design", {"name": "Click arm", "description": "an arm on a hinge",
		"floor": "none", "bricks": R2_BUILD})
	_check("the arm is built: %s" % built.left(60), built.begins_with("Built"))
	_calls = 0
	var listed: String = await _say("pose_model", {})
	print("    " + listed.left(400).replace("\n", "\n    "))
	var line: RegExMatch = RegEx.create_from_string("(?m)^\\s+(\\d+)\\. #(\\d+) [^\\n]*on its click hinge").search(listed)
	_check("pose_model lists the click hinge, no assembly named", line != null
		and not listed.begins_with("Nothing here turns"))
	if line == null:
		return
	var world: BrickWorld = _main.get("_world")
	var arm: int = int(line.get_string(2))
	var was: Transform3D = world.get_brick(arm).transform
	var posed: String = await _say("pose_model", {"joint": line.get_string(1), "degrees": -45})
	print("    " + posed.left(400).replace("\n", "\n    "))
	var turned: float = rad_to_deg(was.basis.get_rotation_quaternion().angle_to(
		world.get_brick(arm).transform.basis.get_rotation_quaternion()))
	_check("...and swings it in %d calls: #%d turned %d°" % [_calls, arm, roundi(turned)],
		_calls == 2 and posed.contains("Moved") and absf(turned - 45.0) < 12.0)
	await _say("undo", {})
	_check("...one undo puts it back", world.get_brick(arm) != null
		and world.get_brick(arm).transform.origin.distance_to(was.origin) < 0.5)


# -- y6, r1: a motor's mount said before Simulate --------------------------------------------


func _motor() -> void:
	print("")
	print("y6, r1: a motor's mount said before Simulate")
	await _say("clear_model", {})
	var points: String = await _say("attachment_points", {"part": "54675", "x": 0, "y": 0, "z": 0})
	_check("attachment_points on the motor says how real sets mount it",
		points.contains("How real sets mount a motor's case: pins through two or more"))
	var beam: String = await _say("attachment_points", {"part": "40490", "x": 0, "y": 0, "z": 0})
	_check("...and on a beam, nothing of motors", not beam.contains("How real sets mount"))
	var checked: String = await _say("check_design", {"name": "SPIKE motor arm", "description": "a test",
		"floor": "none", "bricks": R1_BUILD})
	print("    " + _line_with(checked, "Before Simulate").left(300))
	_check("check_design names r1's motor on single studs as swivelling",
		checked.contains("Before Simulate, its mount: brick 3, the SPIKE Prime large angular motor, swivels on its stud"))
	var built: String = await _say("submit_design", {"name": "SPIKE motor arm", "description": "a test",
		"floor": "none", "bricks": R1_BUILD})
	print("    " + _line_with(built, "Before Simulate").left(300))
	_check("...and built, it is said again, by its number", RegEx.create_from_string(
		"Before Simulate, its mount: #\\d+, the SPIKE Prime large angular motor, swivels on its stud").search(built) != null)
	var pinned: String = await _say("submit_design", {"name": "Pinned motor", "description": "a test",
		"floor": "none", "bricks": Y6_BUILD})
	_check("mcpreach2's motor pinned into two beams is not named: %s" % pinned.left(60),
		pinned.begins_with("Built") and not pinned.contains("Before Simulate, its mount"))
	var pinned_check: String = await _say("check_design", {"name": "Pinned motor", "description": "a test",
		"floor": "none", "bricks": Y6_BUILD})
	_check("...nor at its check", not pinned_check.contains("Before Simulate, its mount"))


# -- r5: a set added by number, kept built, in one call -------------------------------------


func _set_added() -> void:
	print("")
	print("r5: a set added by its number and kept built in one call")
	var api: String = Deployment.api_base()
	if not api.begins_with("http://127.0.0.1"):
		# The suite's run has no relay: an account is made in production
		# Supabase, so this part runs under the live database's lock.
		print("  skip r5: it makes an account; tools/relay_probe.sh mcpreach3 runs it on a relay of its own")
		return
	_email = SignInHelper.throwaway("mcpreach3")
	var problem: String = await _sign_in(_account, _email)
	_check("signed in a throwaway account: %s" % (problem if not problem.is_empty() else _account.email),
		problem.is_empty())
	if problem.is_empty():
		var store: CollectionStore = ((_main.get("_shell") as Shell).collection as CollectionDialog).store
		await store.load_collection()
		var bad: String = await _say("edit_collection", {"sets": ["not a set"]})
		_check("a word that is no set's number changes nothing: %s" % bad, bad.begins_with("Nothing was changed"))
		var mixed: String = await _say("edit_collection", {"sets": [SET], "add": [{"part": "3001", "color": 4, "count": 1}]})
		_check("sets= with add= changes nothing: %s" % mixed.left(90), mixed.begins_with("Nothing was changed"))
		_calls = 0
		var added: String = await _say("edit_collection", {"sets": [SET], "built": [SET]})
		print("    " + added.replace("\n", "\n    "))
		_check("added and kept built in %d call" % _calls, _calls == 1
			and added.contains("Added to the person's collection") and added.contains("1 copy now (was 0)")
			and added.contains("kept built 1 of 1 (was 0)"))
		_check("...\"0 loose parts\" said", added.contains("0 loose parts in 0 lots"))
		await store.load_collection()
		var built: int = 0
		for entry: Dictionary in store.collection.entries_of(SET):
			built += Collection.built_of(entry)
		_check("the account holds %s, kept built: %d" % [SET, built],
			store.collection.copies_of(SET) == 1 and built == 1)
	var gone: int = await SignInHelper.delete_accounts(_email, root)
	_check("the throwaway account deleted, its collection with it: %d" % gone, gone == 1)


func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password, "email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._signed_in_with(reply["body"])
	var waited: int = Time.get_ticks_msec()
	while account.asking_who and Time.get_ticks_msec() - waited < 15000:
		await process_frame
	if account.age_ask:
		var answered: String = await account.answer_age(3, int(Time.get_datetime_dict_from_system()["year"]) - 30)
		if not answered.is_empty():
			return "the age question: " + answered
	return "" if account.signed_in() else "signed out again"


# -- helpers -----------------------------------------------------------------------------


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return "-"


## A session's call, its job followed to the end as a session follows it.
func _say(tool: String, arguments: Dictionary) -> String:
	_calls += 1
	var said: String = await _one(tool, arguments)
	var job := RegEx.create_from_string("^Started job (\\d+)")
	var found: RegExMatch = job.search(said)
	var polls: int = 0
	while found != null and polls < 120:
		said = await _one("job", {"id": int(found.get_string(1))})
		polls += 1
		if not said.contains("is still going"):
			break
	return said


func _one(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments,
			"_meta": {CommandSocket.CHAT_KEY: {"chat": CHAT}}}})
	var text := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		if str((block as Dictionary).get("type", "")) == "text":
			text.append(str((block as Dictionary).get("text", "")))
	return "\n".join(text)


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
	for path: String in _written:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(CollectionStore.where)
	print("mcpreach3_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
