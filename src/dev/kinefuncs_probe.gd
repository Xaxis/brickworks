## Simulate measured on real sets' functions (docs/APP_UX8.md #7, kinefuncs).
##
##   godot --headless --path . --script src/dev/kinefuncs_probe.gd
##   godot --headless --path . --script src/dev/kinefuncs_probe.gd -- --functions=LISTING --rows=ROWS
##
## With nothing given, the MCP walk's n4 case, through the way in as a person
## comes: the sign-in screen up over the app (gate_for_probe), a throwaway
## account signed in (made with the admin key and a password, so no code is
## spent at the per-IP limit), the account deleted at the end; needs .env
## (SUPABASE_URL, SUPABASE_SECRET_KEY). Then, over MCP as the session did:
##   - the walk's bridge opened, and its gear train built beside it with the
##     walk's own edit_model: a 24 tooth gear and an 8 tooth on axles 4 in a
##     frame of Technic bricks 1 x 8 on a plate, joined to the bridge by
##     nothing;
##   - simulate_mechanism with the 24 as the driver turns it: the 8 makes 3
##     turns to its 1, the other way, and the base is said with the piece
##     apart from it (the walk was told "it is floating", twice);
##   - move_part turns the 24 by 30 degrees and the 8 goes 90 the other way,
##     as the gear reading has it; undone;
##   - a 24 tooth gear lying loose on the ground beside it, on no axle, still
##     floats: simulate_mechanism refuses it as floating, and drives the
##     train when asked for no driver.
##
## With --functions, the bench tools/kinefuncs.py runs: each model in LISTING
## (its jobs.json's shape, {"sets": [{set, file, functions}]}) opened as File,
## Open opens it, each function's controls found where Kinebrick names them,
## and each driven in Simulate as a person drives it there: the control's
## part chosen as the driver (a motor's, its output), Simulate's reading of
## the model (Simulation.read, held with the joints a drag reads), the
## driver turned 1.5 radians each way (Kinebrick's REACH), every part in
## `moves` checked moving and every part in `stays` still, against the frame
## or the part each names (Kinebrick's MOVED, 1 LDU or 1 degree). A control
## to work first is worked as a drag works it (Grab), and undone after.
## One JSON row a function in ROWS, and a row as each model begins and ends,
## so the bench can stop a model that takes too long and go on. With
## --dump=DIR, each model's gear reading is written to DIR/SET.json as well:
## its parts' bodies, joints, gears and meshes, the joints a drag reads, and
## for each control driven what turned (tools/kinefuncs.py why reads them).
extends SceneTree

const FIXTURE := "res://src/dev/fixtures/n4_bridge.ldr"
## The walk's own edit_model, n4 (bench/results/mcpwalk8), unchanged.
const TRAIN := {"add": [
	{"part": "3035", "color": 72, "x": 14, "y": 0, "z": 0},
	{"part": "3008", "color": 71, "x": 14, "y": 1, "z": 0},
	{"part": "3008", "color": 71, "x": 14, "y": 1, "z": 3},
	{"part": "3702", "color": 0, "x": 14, "y": 4, "z": 0},
	{"part": "3702", "color": 0, "x": 14, "y": 4, "z": 3},
	{"part": "3705", "color": 0, "axis": "z", "x": 16, "y": 5.75, "z": 2},
	{"part": "3705", "color": 0, "axis": "z", "x": 18, "y": 5.75, "z": 2},
	{"part": "3648", "color": 72, "axis": "z", "x": 16, "y": 5.75, "z": 2},
	{"part": "3647", "color": 72, "axis": "z", "x": 18, "y": 5.75, "z": 2}],
	"assemblies": [{"name": "gear train", "x_from": 13, "x_to": 23, "z_from": -1, "z_to": 5}]}

## Kinebrick's drag on a control: radians each way, LDU a push, and how far
## a part goes to have moved (scripts/check-functions.ts).
const REACH := 1.5
const PUSH := 20.0
const MOVED := 1.0
## How near the place Kinebrick reads a part at a brick must stand, LDU.
const NEAR := 1.5

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _socket: CommandSocket
var _next: int = 0
var _email: String = ""
var _password: String = ""
var _rows: FileAccess = null
## Rounded LDU cell -> brick ids standing there, for finding Kinebrick's parts.
var _cells: Dictionary = {}
## --dump's folder, "" for none, and what the model's controls turned.
var _dump_dir: String = ""
var _dumped: Array = []
## --drag: each control driven by the drag move_part makes as well (Grab,
## its collisions and all), its result beside Simulate's in "drag".
var _drag_too: bool = false


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var listing: String = ""
	var rows: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--functions="):
			listing = arg.trim_prefix("--functions=")
		elif arg.begins_with("--rows="):
			rows = arg.trim_prefix("--rows=")
		elif arg.begins_with("--dump="):
			_dump_dir = arg.trim_prefix("--dump=")
		elif arg == "--drag":
			_drag_too = true
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	if listing.is_empty():
		# The sign-in screen over the app, as a person opening it meets it.
		_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	for _n: int in 30:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	if not listing.is_empty():
		await _bench(listing, rows)
		return
	if await _way_in():
		await _n4()
	await _finish()


# -- the way in ---------------------------------------------------------------


func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("kinefuncs")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify.
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("\n%s: %d failed" % ["FAIL" if _failures > 0 else "PASS", _failures])
	if _world != null:
		_world.clear()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- n4: a gear train beside a bridge --------------------------------------------


func _n4() -> void:
	print("\nn4: the walk's gear train built beside its bridge, over MCP")
	var name: String = "probe n4 bridge"
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE),
		ProjectSettings.globalize_path(ModelStore.SAVE_DIR + name + ".ldr"))
	var opened: String = await _say("open_model", {"name": name, "discard_changes": true})
	for _n: int in 600:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	_check("the walk's bridge opens: %s" % opened.get_slice("\n", 0),
		opened.begins_with("Opened") and _world.brick_count() > 20)
	if _world.brick_count() == 0:
		return
	var before: int = _world.brick_count()
	var built: String = await _say("edit_model", TRAIN)
	await _frames(10)
	var big: int = _part("3648")
	var small: int = _part("3647")
	_check("the walk's edit_model builds the train beside it: 9 parts, the 24 #%d and the 8 #%d (%s)"
		% [big, small, built.get_slice("\n", 0)], _world.brick_count() == before + 9 and big > 0 and small > 0)
	if big <= 0 or small <= 0:
		return
	_builder.forget_history()

	var said: String = await _say("simulate_mechanism", {"driver": "#%d" % big})
	print("    simulate_mechanism driver=#%d:\n      %s" % [big, said.replace("\n", "\n      ")])
	var rate: RegExMatch = RegEx.create_from_string(
		"#%d[^\\n]*: (\\S+) turns? for each turn of [^\\n]*#%d([^\\n]*)" % [small, big]).search(said)
	_check("simulate_mechanism turns the train from the 24: no refusal, nothing floating",
		not said.contains("does not turn on anything") and not said.contains("floating")
		and said.begins_with("Driven by"))
	_check("the 8 makes 3 turns to the 24's 1, the other way (%s)" % (rate.get_string(0) if rate != null
		else "no rate for the 8"), rate != null and is_equal_approx(rate.get_string(1).to_float(), 3.0)
		and rate.get_string(2).contains("the other way"))
	_check("the base is said with the train apart from it: %s" % _between(said, "the base is ", "."),
		said.contains("apart from it, held by its largest part"))

	var small_was: Transform3D = _world.get_brick(small).transform
	var big_was: Transform3D = _world.get_brick(big).transform
	var moved: String = await _say("move_part", {"part": "#%d" % big, "degrees": 30})
	await _frames(5)
	var big_turn: float = _signed_turn(big_was, _world.get_brick(big).transform, Vector3.BACK)
	var small_turn: float = _signed_turn(small_was, _world.get_brick(small).transform, Vector3.BACK)
	print("    move_part #%d degrees=30: %s" % [big, moved.get_slice("\n", 0)])
	_check("move_part turns the 24 by 30 degrees and the 8 by 90 the other way, as Simulate says (%.1f, %.1f)"
		% [big_turn, small_turn], absf(absf(big_turn) - 30.0) < 0.5 and absf(absf(small_turn) - 90.0) < 0.5
		and signf(big_turn) != signf(small_turn))
	var undone: String = await _say("undo", {})
	await _frames(5)
	_check("one undo puts both back: %s" % undone.get_slice(".", 0),
		_world.get_brick(big).transform.is_equal_approx(big_was)
		and _world.get_brick(small).transform.is_equal_approx(small_was))

	# A gear on nothing still floats: a piece is a frame only by its joints.
	var loose: String = await _say("edit_model", {"add": [
		{"part": "3648", "color": 4, "x": 30, "y": 0, "z": 0}]})
	await _frames(10)
	var lone: int = -1
	for brick: BrickWorld.Brick in _world.bricks():
		if _stem(brick.part_id) == "3648" and brick.id != big:
			lone = brick.id
	_check("a loose 24 tooth gear lies beside it, #%d (%s)" % [lone, loose.get_slice("\n", 0)], lone > 0)
	if lone > 0:
		var refused: String = await _say("simulate_mechanism", {"driver": "#%d" % lone})
		print("    simulate_mechanism driver=#%d: %s" % [lone, refused.get_slice("\n", 0)])
		_check("simulate_mechanism refuses the loose gear as floating",
			refused.contains("does not turn on anything") and refused.contains("floating"))
		var picked: String = await _say("simulate_mechanism", {})
		print("    simulate_mechanism (its own pick): %s" % picked.get_slice("\n", 0))
		_check("asked for no driver, it drives the train: the 8 turns from the 24 or the 24 from the 8",
			picked.begins_with("Driven by") and (picked.contains("#%d" % big) and picked.contains("#%d" % small)))


## The first brick of the part [param id], whatever letter the library gives
## its number now (3648 is 3648b).
func _part(id: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if _stem(brick.part_id) == id:
			return brick.id
	return -1


## Degrees [param to] stands turned from [param from] about [param way].
static func _signed_turn(from: Transform3D, to: Transform3D, way: Vector3) -> float:
	var q := Quaternion((to.basis.orthonormalized() * from.basis.orthonormalized().inverse()))
	return rad_to_deg(2.0 * atan2(Vector3(q.x, q.y, q.z).dot(way.normalized()), q.w))


static func _between(text: String, after: String, before: String) -> String:
	var at: int = text.find(after)
	if at < 0:
		return "(not said)"
	var rest: String = text.substr(at + after.length())
	return rest.substr(0, rest.find(before)) if rest.contains(before) else rest


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	# A long call is a job: followed to its answer, as a session follows it.
	var job: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(text)
	if job != null and tool != "job":
		for _n: int in 600:
			var polled: String = await _say("job", {"id": int(job.get_string(1))})
			if not polled.contains(" is still going"):
				return polled
	return text


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


# -- the bench: each set's functions driven in Simulate --------------------------------


func _bench(listing: String, rows_path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(listing))
	if not parsed is Dictionary or rows_path.is_empty():
		printerr("kinefuncs: --functions=%s is no listing, or no --rows" % listing)
		quit(2)
		return
	if FileAccess.file_exists(rows_path):
		_rows = FileAccess.open(rows_path, FileAccess.READ_WRITE)
		_rows.seek_end()
	else:
		_rows = FileAccess.open(rows_path, FileAccess.WRITE)
	for model: Dictionary in (parsed as Dictionary).get("sets", []):
		var file: String = str(model.get("file", ""))
		_row({"file": file, "begin": true})
		var began: int = Time.get_ticks_msec()
		var problem: String = await _open_file(file)
		var opened_ms: int = Time.get_ticks_msec() - began
		var sim: Simulation = null
		if problem.is_empty():
			_index()
			sim = _read_sim()
		print("%s: %d parts, opened in %d ms%s" % [file.get_file(), _world.brick_count(), opened_ms,
			"" if problem.is_empty() else ", " + problem])
		_dumped.clear()
		for fn: Dictionary in model.get("functions", []):
			var row: Dictionary = {"set": str(fn.get("set", model.get("set", ""))), "n": int(fn.get("n", 0))}
			if fn.has("skip"):
				row["result"] = "skipped"
			elif fn.has("error"):
				row.merge({"result": "error", "why": [str(fn["error"])]})
			elif (fn.get("control", []) as Array).is_empty():
				row["result"] = "not checked"
			elif not problem.is_empty():
				row.merge({"result": "error", "why": [problem]})
			else:
				var at: int = Time.get_ticks_msec()
				var measured: Dictionary = await _function(fn, sim)
				row.merge(measured)
				row["ms"] = Time.get_ticks_msec() - at
				if bool(measured.get("worked_first", false)):
					sim = _read_sim()
				row.erase("worked_first")
			_row(row)
		if not _dump_dir.is_empty() and sim != null:
			_dump("%s/%s.json" % [_dump_dir, str(model.get("set", file.get_file()))], sim)
		_row({"file": file, "end": true, "parts": _world.brick_count(), "ms": Time.get_ticks_msec() - began})
	_rows.close()
	_world.clear()
	await process_frame
	quit(0)


func _row(row: Dictionary) -> void:
	_rows.store_line(JSON.stringify(row))
	_rows.flush()


## Open [param path] as File, Open opens it: "" when it did, else why not.
func _open_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "no file %s" % path
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", path)
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 300000:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(5)
	if _world.brick_count() == 0:
		return "it opened with no parts"
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	var playback: Variant = _main.get("_playback")
	if playback != null and (playback as BuildPlayback).is_playing():
		(playback as BuildPlayback).stop()
		await _frames(3)
	_builder.forget_history()
	return ""


## Simulate's reading of the model as it stands: the gear reading, held with
## the joints a drag reads, as the panel holds it (SimulatePanel._held).
func _read_sim() -> Simulation:
	var sim: Simulation = Simulation.read(_world.bricks(), _library, _store.scenery)
	sim.hold_with(_world, _builder, null)
	return sim


func _index() -> void:
	_cells.clear()
	for brick: BrickWorld.Brick in _world.bricks():
		var cell := Vector3i(brick.transform.origin.round())
		if not _cells.has(cell):
			_cells[cell] = []
		(_cells[cell] as Array).append(brick.id)


## The brick standing where Kinebrick reads [param ref] ({ref, name, at, of}):
## its own part there, else the part it is a piece of where that stands (a
## turntable's top, which the app reads as the one part the file places),
## else any part there; -1 when none stands there.
func _brick_for(ref: Dictionary) -> int:
	var stem: String = _stem(str(ref.get("name", "")))
	var found: int = _standing(ref.get("at", []), stem)
	if found < 0 and ref.get("of") is Dictionary:
		var of: Dictionary = ref["of"]
		found = _standing(of.get("at", []), _stem(str(of.get("name", ""))))
	if found < 0:
		found = _standing(ref.get("at", []), "")
	return found


## The nearest brick within [constant NEAR] of where LDraw's [param at] (4 x 4,
## row by row) stands in the app, of the part [param stem] ("" any); or -1.
func _standing(at: Array, stem: String) -> int:
	if at.size() != 16:
		return -1
	var place: Vector3 = Vector3(float(at[3]), float(at[7]), float(at[11])) * LdrModel.FLIP + _store.lift()
	var best: int = -1
	var nearest: float = NEAR
	var cell := Vector3i(place.round())
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			for dz: int in [-1, 0, 1]:
				for key: int in _cells.get(cell + Vector3i(dx, dy, dz), []):
					var brick: BrickWorld.Brick = _world.get_brick(key)
					if brick == null or (not stem.is_empty() and _stem(brick.part_id) != stem):
						continue
					var off: float = brick.transform.origin.distance_to(place)
					if off <= nearest:
						nearest = off
						best = key
	return best


## A part's number without its letters after the digits or its pattern: 4185a
## is 4185, 3403c01 is 3403.
static func _stem(part: String) -> String:
	var name: String = part.to_lower().trim_suffix(".dat").get_file()
	var digits: String = ""
	for c: String in name:
		if c >= "0" and c <= "9":
			digits += c
		elif not digits.is_empty():
			break
		else:
			return name
	return digits


func _is_frame(sim: Simulation, body: int) -> bool:
	if sim.model.has_method("is_frame"):
		return bool(sim.model.call("is_frame", body))
	return body == sim.model.ground


## One function measured: each control driven from the model as opened (and
## worked first), Kinebrick's way, its rules for works, partly and no.
func _function(fn: Dictionary, sim: Simulation) -> Dictionary:
	var why: Array = []
	var worked: int = 0
	for first: Dictionary in fn.get("first", []):
		var ref: Dictionary = first.get("control", {})
		var key: int = _brick_for(ref)
		if key < 0:
			why.append("%s, worked first, is not where Kinebrick reads it" % ref.get("ref", "?"))
			continue
		var by: float = float(first.get("by", 0.0))
		var went: Array = _work_first(key, by)
		worked += int(went[1])
		if absf(float(went[0])) < 0.9 * absf(by):
			why.append("%s, worked first, went %s of %s" % [ref.get("ref", "?"),
				snappedf(float(went[0]), 0.01), by])
	if worked > 0:
		sim = _read_sim()
	var moves: Array = []
	var stays: Array = []
	for item: Dictionary in fn.get("moves", []):
		moves.append(_against(item, why))
	for item: Dictionary in fn.get("stays", []):
		stays.append(_against(item, why))
	var ways: Array = []
	var hows := PackedStringArray()
	for control: Dictionary in fn.get("control", []):
		var way: Dictionary = _drive(sim, control, moves, stays, why)
		ways.append(way)
		if not str(way.get("how", "")).is_empty() and not hows.has(str(way["how"])):
			hows.append(str(way["how"]))
	for _n: int in worked:
		_builder.undo()
	var by_drag: Dictionary = {}
	if _drag_too:
		var drag: String = "works"
		for way: Dictionary in ways:
			if not bool((way.get("drag", {}) as Dictionary).get("works", false)):
				drag = "no"
		if drag != "works":
			for way: Dictionary in ways:
				if bool((way.get("drag", {}) as Dictionary).get("something", false)):
					drag = "partly"
		var drag_still: Array = []
		for way: Dictionary in ways:
			for ref: Variant in (way.get("drag", {}) as Dictionary).get("still", []):
				if not drag_still.has(ref):
					drag_still.append(ref)
		by_drag = {"result": drag, "still": drag_still}
	var result: String = "works"
	for way: Dictionary in ways:
		if not bool(way["works"]):
			result = "no"
	if result != "works":
		for way: Dictionary in ways:
			if bool(way["something"]):
				result = "partly"
	var still: Array = []
	var wrong: Array = []
	var turned: Array = []
	var seen: Dictionary = {}
	var notes := PackedStringArray()
	for way: Dictionary in ways:
		seen.merge(way.get("seen", {}))
		var note: String = str(way.get("note", ""))
		if not note.is_empty() and not notes.has(note):
			notes.append(note)
		for ref: String in way["still"]:
			if not still.has(ref):
				still.append(ref)
		for ref: String in way["moved"]:
			if not wrong.has(ref):
				wrong.append(ref)
		turned.append(way["turned"])
	var unique: Array = []
	for line: String in why:
		if not unique.has(line):
			unique.append(line)
	var out: Dictionary = {"result": result, "how": "; ".join(hows), "turned": turned,
		"worked_first": worked > 0}
	if not still.is_empty():
		out["still"] = still
	if not wrong.is_empty():
		out["moved"] = wrong
	if not unique.is_empty():
		out["why"] = unique
	if not seen.is_empty():
		out["seen"] = seen
	if not notes.is_empty():
		out["notes"] = notes
	if not by_drag.is_empty():
		out["drag"] = by_drag
	return out


## [param item] ({part, against?}) as [ref, its brick, the brick it is
## measured against or -1 for the frame].
func _against(item: Dictionary, why: Array) -> Array:
	var part: Dictionary = item.get("part", {})
	var key: int = _brick_for(part)
	if key < 0:
		why.append("%s is not where Kinebrick reads it" % part.get("ref", "?"))
	var against: int = -1
	if item.get("against") is Dictionary:
		against = _brick_for(item["against"])
	return [str(part.get("ref", "?")), key, against]


## Work [param key]'s joint as a drag works it, [param by] radians, or LDU
## along its line for a ring slid on its axle (Kinebrick's slides are given
## in LDU, its turns in radians, never more than a turn): [how far it went,
## 1 when it was kept as a step to undo].
func _work_first(key: int, by: float) -> Array:
	var bodies: Bodies = Bodies.read(_world, _library, _builder.lattice, _store.scenery,
		_builder.locked.duplicate())
	bodies.racks()
	var grab := Grab.new()
	grab.world = _world
	grab.builder = _builder
	grab.library = _library
	grab.bodies = bodies
	grab.begin(key, _world.get_brick(key).transform.origin)
	if grab.state != "moves":
		return [0.0, 0]
	var went: float = 0.0
	if absf(by) > TAU:
		if grab.mode != "slide" and grab.can_slide():
			grab.use_slide()
		if grab.mode != "slide":
			return [0.0, 0]
		went = grab.slide_to(by)
	else:
		if grab.mode != "turn":
			return [0.0, 0]
		went = deg_to_rad(grab.turn_to(rad_to_deg(by)))
	if grab.commit("worked first") == 0:
		return [went, 0]
	return [went, 1]


## One control driven both ways in Simulate: {works, something, turned
## [one way, the other], still, moved, how}.
func _drive(sim: Simulation, control: Dictionary, moves: Array, stays: Array, why: Array) -> Dictionary:
	var ref: String = str(control.get("ref", "?"))
	var none: Dictionary = {"works": false, "something": false, "turned": [0.0, 0.0],
		"still": moves.map(func(m: Array) -> String: return str(m[0])), "moved": [], "how": ""}
	var key: int = _brick_for(control)
	if key < 0:
		why.append("%s is not where Kinebrick reads it" % ref)
		return none
	var body: int = sim.model.body_of(key)
	if sim.motors.has(key):
		for turned: int in sim.motored:
			if int(sim.motored[turned]) == key:
				body = turned
	if not sim.model.bodies.has(body):
		why.append("%s is not in Simulate's reading (no shape)" % ref)
		return _with_drag(none, sim, key, moves, stays)
	if _is_frame(sim, body):
		var held: String = str(sim.model.call("why_held", key)) if sim.model.has_method("why_held") else ""
		why.append("%s is part of the frame%s" % [ref, "" if held.is_empty() else " (%s)" % held.left(400)])
		return _with_drag(none, sim, key, moves, stays)
	if not sim.can_drive(body):
		why.append("%s: Simulate has no joint it turns on (%s)" % [ref,
			"floating" if sim.model.floating.has(body) else "held still by the frame"])
		return _with_drag(none, sim, key, moves, stays)
	sim.drive(body)
	if not _dump_dir.is_empty():
		var turned_bodies: Array = []
		for one: int in sim.model.bodies:
			if sim.model.omega(one).length() > Simulation.STILL:
				turned_bodies.append(one)
		_dumped.append({"control": ref, "key": key, "body": body, "said": str(sim.solved.get("said", "")),
			"grab": sim.grab != null, "note": sim.grab_note, "turning": turned_bodies,
			"moving": sim.moving.size(), "moves": moves.map(func(m: Array) -> Array: return [m[0], m[1]]),
			"stays": stays.map(func(m: Array) -> Array: return [m[0], m[1]])})
	# How Simulate turned it: by its gear reading, by a drag holding the loop
	# that reading cannot close, or by a drag on a joint it has no equation
	# for (a hinge, a clip).
	var how: String = "the gear reading" if sim.grab == null else ("a drag's loop"
		if sim.model.joint_of(body) != null else "a drag on its joint")
	var holds: int = (sim.get("holds") as Array).size() if sim.get("holds") is Array else 0
	if holds > 0:
		how += " and %d loop%s it turns" % [holds, "" if holds == 1 else "s"]
	if not bool(sim.solved.get("ok", false)) and sim.grab == null:
		why.append("%s: %s" % [ref, sim.solved.get("said", "")])
	var each: Array = []
	for way: float in [1.0, -1.0]:
		var at: Dictionary = sim.placed(way * REACH / TAU)
		var turned: float = _turn(sim, body, at)
		var still: Array = []
		for m: Array in moves:
			if int(m[1]) < 0 or not _moved(sim, int(m[1]), int(m[2]), at):
				still.append(str(m[0]))
		var wrong: Array = []
		for s: Array in stays:
			if int(s[1]) >= 0 and _moved(sim, int(s[1]), int(s[2]), at):
				wrong.append(str(s[0]))
		each.append({"turned": turned, "still": still, "moved": wrong,
			"works": absf(turned) >= REACH / 2.0 and still.is_empty() and wrong.is_empty()})
	var turned_both: Array = [snappedf(float(each[0]["turned"]), 0.01), snappedf(float(each[1]["turned"]), 0.01)]
	# The better way: one that works, else the one with fewer wrong parts
	# that went further (Kinebrick's).
	each.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if bool(x["works"]) != bool(y["works"]):
			return bool(x["works"])
		var xs: int = (x["still"] as Array).size() + (x["moved"] as Array).size()
		var ys: int = (y["still"] as Array).size() + (y["moved"] as Array).size()
		if xs != ys:
			return xs < ys
		return absf(float(x["turned"])) > absf(float(y["turned"])))
	var best: Dictionary = each[0]
	var something: bool = false
	for one: Dictionary in each:
		if absf(float(one["turned"])) >= 0.01 or (one["still"] as Array).size() < moves.size():
			something = true
	# Why each part that should have moved did not, and each that should
	# have stayed did not, as the gear reading has it: for the table's causes.
	var seen: Dictionary = {}
	for m: Array in moves + stays:
		if seen.size() < 6 and int(m[1]) >= 0 and ((best["still"] as Array).has(m[0])
				or (best["moved"] as Array).has(m[0])):
			seen[m[0]] = _state(sim, int(m[1]), body)
	var out: Dictionary = {"works": bool(best["works"]), "something": something,
		"turned": turned_both, "still": best["still"], "moved": best["moved"], "how": how,
		"seen": seen, "note": sim.grab_note}
	if _drag_too:
		out["drag"] = _by_drag(sim, key, moves, stays)
	return out


func _with_drag(out: Dictionary, sim: Simulation, key: int, moves: Array, stays: Array) -> Dictionary:
	if _drag_too:
		out["drag"] = _by_drag(sim, key, moves, stays)
	return out


## [param key] driven both ways by the drag move_part makes (Grab: its
## reading of the joints, its loops and gear trains, stopping where parts
## meet), Kinebrick's way, as [method _drive] drives Simulate: {works,
## something, still}.
func _by_drag(sim: Simulation, key: int, moves: Array, stays: Array) -> Dictionary:
	var held := Grab.new()
	held.world = _world
	held.builder = _builder
	held.library = _library
	held.bodies = sim.bodies
	held.begin(key, _world.get_brick(key).transform.origin)
	if held.state != "moves" or not held.mode in ["turn", "slide"]:
		return {"works": false, "something": false, "still": moves.map(func(m: Array) -> String: return str(m[0])),
			"why": "%s %s" % [held.state, held.why.left(120)]}
	var each: Array = []
	for way: float in [1.0, -1.0]:
		var went: float = 0.0
		if held.mode == "turn":
			went = absf(deg_to_rad(held.turn_to(rad_to_deg(way * REACH)))) / REACH
		else:
			went = absf(held.slide_to(way * PUSH)) / PUSH
		var at: Dictionary = held.placed.duplicate()
		var still: Array = []
		for m: Array in moves:
			if int(m[1]) < 0 or not _moved(sim, int(m[1]), int(m[2]), at):
				still.append(str(m[0]))
		var wrong: Array = []
		for st: Array in stays:
			if int(st[1]) >= 0 and _moved(sim, int(st[1]), int(st[2]), at):
				wrong.append(str(st[0]))
		each.append({"went": went, "still": still, "works": went >= 0.5 and still.is_empty() and wrong.is_empty()})
		if held.mode == "turn":
			held.turn_to(0.0)
		else:
			held.slide_to(0.0)
	var works: bool = bool(each[0]["works"]) or bool(each[1]["works"])
	var something: bool = false
	for one: Dictionary in each:
		if float(one["went"]) > 0.01 or (one["still"] as Array).size() < moves.size():
			something = true
	var still: Array = each[0]["still"] if (each[0]["still"] as Array).size() <= (each[1]["still"] as Array).size() \
		else each[1]["still"]
	return {"works": works, "something": something, "still": still}


## The gear reading of the model open, for reading why a function failed
## away from the app: each part's body, each joint, gear and mesh, the joints
## a drag reads, and what each control's drive turned.
func _dump(path: String, sim: Simulation) -> void:
	var model: Mechanism = sim.model
	var v := func(at: Vector3) -> Array: return [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)]
	var parts: Dictionary = {}
	for key: int in model.parts:
		parts[str(key)] = [(model.parts[key] as Mechanism.Piece).part, model.body_of(key),
			v.call((model.rest[key] as Transform3D).origin)]
	var joints: Array = []
	for joint: Mechanism.Joint in model.joints:
		joints.append({"a": joint.a, "b": joint.b, "what": joint.what, "at": v.call(joint.point),
			"way": v.call(joint.way), "tree": model.tree.has(joint)})
	var gears: Array = []
	for gear: Mechanism.Gear in model.gears:
		gears.append([gear.key, gear.part, gear.kind, gear.teeth, snappedf(gear.radius, 0.01),
			snappedf(gear.face, 0.01), v.call(gear.centre), v.call(gear.axis), gear.body])
	var meshes: Array = []
	for coupling: Mechanism.Coupling in model.couplings:
		meshes.append([coupling.one.key, coupling.other.key, coupling.how, snappedf(coupling.apart, 0.01),
			snappedf(coupling.ideal, 0.01)])
	var joined: Array = []
	for join: Array in model.joined_by:
		joined.append([int(join[0]), int(join[1]), str(join[2])])
	var links: Array = []
	if sim.bodies != null:
		for link: Bodies.Link in sim.bodies.links:
			links.append({"kind": link.kind, "turns": link.turns, "pairs": link.pairs.slice(0, 4),
				"at": v.call(link.point), "way": v.call(link.axis)})
	var out: Dictionary = {"ground": model.ground, "roots": model.roots, "floating": model.floating,
		"universals": model.universals.size(), "parts": parts, "joints": joints, "gears": gears,
		"meshes": meshes, "joined": joined, "links": links, "unseated": model.unseated,
		"drives": _dumped.duplicate()}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(out))
		file.close()


## How the gear reading reads [param key] against a drive of [param driven]:
## "floating", "a frame", "on another piece", "on the driver's piece" with its
## joint, and for a gear what it meshes and the nearest gear it does not.
func _state(sim: Simulation, key: int, driven: int) -> String:
	var model: Mechanism = sim.model
	if not model.parts.has(key):
		return "not in the reading (no shape)"
	var body: int = model.body_of(key)
	var said: String = ""
	if body == driven:
		said = "the driver's body"
	elif model.floating.has(body):
		said = "floating"
	elif _is_frame(sim, body):
		said = "a frame"
	elif model.has_method("frame_under") and int(model.call("frame_under", body)) \
			!= int(model.call("frame_under", driven)):
		said = "on another piece"
	else:
		var joint: Mechanism.Joint = model.joint_of(body)
		said = "on the driver's piece, %s, %s" % [joint.what if joint != null else "?",
			"turning" if model.omega(body).length() > 1e-6 else "still"]
	if sim.get("followers") is Dictionary and (sim.get("followers") as Dictionary).has(key):
		said += ", following"
	var gear: Mechanism.Gear = model.gear_at(key)
	if gear == null:
		return said
	var meshed: int = 0
	for coupling: Mechanism.Coupling in model.couplings:
		if coupling.one == gear or coupling.other == gear:
			meshed += 1
	var nearest: Mechanism.Gear = null
	for other: Mechanism.Gear in model.gears:
		if other == gear or other.body == gear.body:
			continue
		var coupled: bool = false
		for coupling: Mechanism.Coupling in model.couplings:
			if (coupling.one == gear and coupling.other == other) or (coupling.one == other and coupling.other == gear):
				coupled = true
		if coupled:
			continue
		if nearest == null or other.centre.distance_to(gear.centre) < nearest.centre.distance_to(gear.centre):
			nearest = other
	said += "; a %s %d meshing %d" % [gear.kind, gear.teeth, meshed]
	if nearest != null:
		var gap: Vector3 = nearest.centre - gear.centre
		var along: float = gap.dot(gear.axis)
		said += "; nearest unmeshed: #%d %s %s %d, %s LDU off (%s along, %s across, ideal %s), axes %d°" % [
			nearest.key, nearest.part, nearest.kind, nearest.teeth, snappedf(gap.length(), 0.1),
			snappedf(along, 0.1), snappedf((gap - gear.axis * along).length(), 0.1),
			snappedf(gear.radius + nearest.radius, 0.1),
			roundi(rad_to_deg(gear.axis.angle_to(nearest.axis)))]
	return said


## Radians the driver's body stands turned in [param at], from where it was.
func _turn(sim: Simulation, body: int, at: Dictionary) -> float:
	for key: int in sim.model.bodies[body]:
		if at.has(key):
			var move: Transform3D = (at[key] as Transform3D) * _rest(sim, key).affine_inverse()
			return _angle(move.basis)
	return 0.0


## How far round [param basis] turns, radians, 0 to PI.
static func _angle(basis: Basis) -> float:
	return 2.0 * acos(minf(1.0, absf(Quaternion(basis.orthonormalized()).w)))


func _rest(sim: Simulation, key: int) -> Transform3D:
	if sim.model.rest.has(key):
		return sim.model.rest[key]
	var brick: BrickWorld.Brick = _world.get_brick(key)
	return brick.transform if brick != null else Transform3D.IDENTITY


## Whether [param key] moved against [param against] (-1: the frame) in
## [param at]: its place 1 LDU, or its turn 1 degree (Kinebrick's MOVED).
func _moved(sim: Simulation, key: int, against: int, at: Dictionary) -> bool:
	var rest: Transform3D = _rest(sim, key)
	var mine: Transform3D = (at.get(key, rest) as Transform3D) * rest.affine_inverse()
	if against >= 0:
		var theirs_rest: Transform3D = _rest(sim, against)
		var theirs: Transform3D = (at.get(against, theirs_rest) as Transform3D) * theirs_rest.affine_inverse()
		mine = theirs.affine_inverse() * mine
	var went: float = (mine * rest.origin).distance_to(rest.origin)
	return went >= MOVED or rad_to_deg(_angle(mine.basis)) >= MOVED
