## m3review (independent review of mcpreach3): the attacks, each printed with
## what came back, so a fix unit can rerun them. m3fix made each a check:
##
##   python3 -I tools/collection_standin.py 10910   # /api/collection stand-in, kept going
##   BRICKWORKS_API=http://127.0.0.1:10910 godot --headless --path . \
##     --script src/dev/m3review_probe.gd -- --held-out=31058-1 --assistant=on
##
## The user args are realset's (tools/bench/realset.py starts each tab with
## --held-out=, never --brickbench): there a save with features unsettled is
## refused, written nowhere (H1). Run with --assistant=on alone, a person's
## tab: it is written, says what is not finished, and lays nothing, the file
## the model as it stood (M1). M3REV_ONLY=save,pose,coll,hinge,motor (or the
## user arg --only=, as tools/suite gives it) runs some; nothing set runs
## all, ~16 min at load: motor lists 42131-1's joints alone in 339 s, so the
## suite runs save,hinge,pose. Without the stand-in on 10910, coll is
## skipped (exit 3 when it is all that was asked).
##  save   H1 (a bench's run) or M1 (a person's), as the args make it.
##  pose   L2: pose_model joint= an assembly's joint on 42109-1, opened
##         fresh, never waits on the drag joints' read (the worker's read
##         stays not done), and is no slower than listing them.
##  coll   H2: every argument checked before the add (built= out of range,
##         an en dash, a set not owned); a reply lost after the add, or after
##         the Built marks, is told it may have been made; false as if not
##         sent. Each case's account compared after it.
extends SceneTree

const CHAT := "probe-m3review-chat"
## The stand-in: BRICKWORKS_API when it is one on this machine, else 10910.
var API: String = Deployment.api_base() if Deployment.api_base().begins_with("http://127.0.0.1") \
	else "http://127.0.0.1:10910"
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _written: PackedStringArray = PackedStringArray()
var _gap: Array = [0, 0]   # [last frame usec, longest gap usec]
var _failures: int = 0
var _checked: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	_checked += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_m3review_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_m3review_collection.json"
	DirAccess.remove_absolute(CollectionStore.where)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")) and _main.get("_shell") != null and _main.get("_bar") != null:
			break
	for _n: int in 30:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	print("INFO user args %s; Assistant.brickbench=%s DesignMemory.holding()=%s" % [
		OS.get_cmdline_user_args(), Assistant.brickbench, DesignMemory.holding()])
	process_frame.connect(_tick)
	var only: String = OS.get_environment("M3REV_ONLY")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	if only.is_empty() or only.contains("save"):
		await _save_on_bench_tab()
	if only.is_empty() or only.contains("hinge"):
		await _hinge_undo()
	if only.is_empty() or only.contains("pose"):
		await _pose_named()
	if only.is_empty() or only.contains("motor"):
		await _motors_real_sets()
	if only.contains("phases"):
		await _phases()
	var skipped: bool = false
	if only.is_empty() or only.contains("coll"):
		skipped = not await _collection()
	process_frame.disconnect(_tick)
	_socket.stop()
	for path: String in _written:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(CollectionStore.where)
	print("m3review_probe: %d of %d checks failed" % [_failures, _checked])
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 3 if skipped and _checked == 0 else 0)


func _tick() -> void:
	var now: int = Time.get_ticks_usec()
	if int(_gap[0]) > 0:
		_gap[1] = maxi(int(_gap[1]), now - int(_gap[0]))
	_gap[0] = now


func _longest_frame_ms() -> float:
	return float(_gap[1]) / 1000.0


func _reset_frames() -> void:
	_gap[0] = 0
	_gap[1] = 0


# -- save on a realset tab ---------------------------------------------------------------


func _owl() -> Dictionary:
	var bricks: Array = [{"part": "91405", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for level: int in 4:
		for x: int in [4, 8]:
			bricks.append({"part": "3001", "color": 19, "x": x, "y": 1 + level * 3, "z": 6, "rot": 0})
	return {"name": "barn owl", "description": "a body on a base", "bricks": bricks,
		"assemblies": [{"name": "owl", "x_from": 0, "x_to": 16, "z_from": 0, "z_to": 16}],
		"features": [{"name": "eyes", "x": 5, "y": 13, "z": 7, "facing": "+z"},
			{"name": "beak", "x": 8, "y": 1, "z": 13, "facing": "+z"}]}


func _save_on_bench_tab() -> void:
	print("")
	print("SAVE: a design with 2 features unsettled, saved on a tab started as realset starts one")
	await _say("clear_model", {})
	(_main.get("_assistant") as Assistant)._joints_refused = true
	var built: String = await _say("submit_design", _owl())
	print("  submit_design: %s" % built.left(120).replace("\n", " / "))
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var file: String = "realset-m3review-%d.ldr" % OS.get_process_id()
	var path: String = ModelStore.SAVE_DIR + file
	_written.append(path)
	var parts_before: int = world.brick_count()
	var saved: String = await _say("save_model", {"name": file})
	print("  save_model: %s" % saved.left(260).replace("\n", " / "))
	print("RESULT save written=%s refused=%s (Not saved yet)" % [FileAccess.file_exists(path),
		saved.begins_with("Not saved yet")])
	var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var lines: int = text.count("\n1 ") + (1 if text.begins_with("1 ") else 0)
	print("RESULT after the save: parts on the baseplate %d -> %d, file's part lines %d, unsaved work %s" % [
		parts_before, world.brick_count(), lines, store.has_unsaved_work()])
	if Assistant.brickbench or DesignMemory.holding():
		# H1: as pre261 refused it, a held-out session's unsettled save is
		# written nowhere, and its first feature is handed back.
		_check("H1: a bench run's save over 2 unsettled features is refused, as pre261 refused it",
			saved.begins_with("Not saved yet: 2 of its 2 features are not settled") and saved.contains("The eyes"))
		_check("H1: ...and no file is written", not FileAccess.file_exists(path))
		return
	# M1: a person's: written, what is not finished said, nothing laid.
	var scenery: int = store.scenery.size()
	_check("M1: a person's save over 2 unsettled features writes the file and says so",
		saved.begins_with("Written to %s" % file) and FileAccess.file_exists(path))
	_check("M1: ...says what is not finished: %s" % saved.get_slice("Not finished yet", 1).left(120),
		saved.contains("Not finished yet: 2 of its 2 features are not settled (eyes, beak)")
		and saved.contains("review_model {\"feature\": \"eyes\"}") and not saved.contains("Not saved yet"))
	_check("M1: ...lays nothing: %d parts on the baseplate before and %d after" % [parts_before, world.brick_count()],
		world.brick_count() == parts_before)
	_check("M1: ...the file is the model as it stood: %d part lines for %d parts" % [lines, parts_before - scenery],
		lines == parts_before - scenery)
	_check("M1: ...and nothing is left unsaved", not store.has_unsaved_work())
	# Every feature settled: the save goes through as before, nothing laid.
	var settled: String = await _say("settle_feature", {"feature": "all", "verdict": "built",
		"reason": "built from the bricks already there"})
	print("  settle_feature all built: %s" % settled.left(160).replace("\n", " / "))
	parts_before = world.brick_count()
	var again: String = await _say("save_model", {"name": file})
	print("  save_model again: %s" % again.left(200).replace("\n", " / "))
	_check("M1: settled, saved again: written over, nothing said unfinished, nothing laid (%d -> %d), nothing unsaved"
		% [parts_before, world.brick_count()], again.begins_with("Written to %s" % file)
		and not again.contains("Not finished yet: ") and world.brick_count() == parts_before
		and not store.has_unsaved_work())


# -- pose_model on a click hinge, undone ---------------------------------------------------


func _snapshot() -> Dictionary:
	var world: BrickWorld = _main.get("_world")
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		out[brick.id] = [brick.part_id, brick.colour if "colour" in brick else 0, var_to_bytes(brick.transform)]
	return out


func _hinge_undo() -> void:
	print("")
	print("HINGE: a click hinge arm, no assembly, posed and undone")
	await _say("clear_model", {})
	await _say("edit_model", {"add": [
		{"part": "3020", "color": 71, "x": 14, "y": 0, "z": 0},
		{"part": "30365", "color": 71, "name": "hb", "x": 16, "y": 1, "z": 0},
		{"part": "30364", "color": 0, "name": "arm", "attach": {"to": "hb.hinge[0]", "by": "hinge[0]",
			"flip": true, "yaw": 180}}], "picture": false})
	await _say("edit_model", {"add": [
		{"part": "3666", "color": 0, "x": 19, "y": 4, "z": 0},
		{"part": "3001", "color": 4, "x": 21, "y": 5, "z": 0}], "picture": false})
	var listed: String = await _say("pose_model", {})
	print("  pose_model: %s" % listed.left(300).replace("\n", " / "))
	var line: RegExMatch = RegEx.create_from_string("(?m)^\\s+(\\d+)\\. #(\\d+) [^\\n]*hinge").search(listed)
	if line == null:
		print("RESULT hinge not listed")
		return
	var before: Dictionary = _snapshot()
	var posed: String = await _say("pose_model", {"joint": line.get_string(1), "degrees": -45})
	print("  posed: %s" % posed.left(200).replace("\n", " / "))
	var moved: int = 0
	var after_pose: Dictionary = _snapshot()
	for id: Variant in before:
		if not after_pose.has(id) or after_pose[id] != before[id]:
			moved += 1
	var undone: String = await _say("undo", {})
	print("  undo: %s" % undone.left(160).replace("\n", " / "))
	var back: Dictionary = _snapshot()
	var off: int = 0
	for id: Variant in before:
		if not back.has(id) or back[id] != before[id]:
			off += 1
	print("RESULT hinge: %d of %d parts moved by the pose; after one undo %d differ from before (exact transforms), %d parts now" % [
		moved, before.size(), off, back.size()])


# -- pose_model by an assembly's joint, on a set opened fresh (L2) ---------------------------


func _pose_named() -> void:
	print("")
	print("POSE: pose_model joint= an assembly's joint, 42109-1 opened fresh, the drag joints not read yet")
	_main.call("clear_model")
	for _n: int in 4:
		await process_frame
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(
		FileAccess.get_file_as_string("res://vendor/omr/files/42109-1.mpd"), "model")
	bar.opened.emit(int(opened.get("placed", 0)))
	var grabbing: GrabDrag = _main.get("_grab_drag")
	# No reading while it is timed but one a call starts itself: the reading
	# a model standing still starts by itself (GrabDrag._ready_ahead) held.
	grabbing.hold_still(true)
	for _n: int in 4:
		await process_frame
	var going: bool = int(grabbing.get("_readying")) >= 0
	var began: int = grabbing.read_began
	_reset_frames()
	var started: int = Time.get_ticks_msec()
	var posed: String = await _say("pose_model", {"joint": "1", "degrees": 10})
	var took: int = Time.get_ticks_msec() - started
	var read: bool = grabbing.read_began != began
	print("  posed: %s" % posed.left(160).replace("\n", " / "))
	print("RESULT named pose in %d ms, longest frame %.1f ms; a reading going before %s, one begun by the call %s, %d parts" % [
		took, _longest_frame_ms(), going, read, (_main.get("_world") as BrickWorld).brick_count()])
	_check("L2: pose_model joint=1 posed it: %s" % posed.left(60), posed.contains(" at 10°") or posed.contains("stops at"))
	_check("L2: ...and began no reading of the drag joints (none going before: %s)" % (not going), not going and not read)
	# The list reads them, as it must.
	started = Time.get_ticks_msec()
	var listed: String = await _say("pose_model", {})
	var list_ms: int = Time.get_ticks_msec() - started
	print("RESULT the list in %d ms, a reading begun %s: %s" % [list_ms, grabbing.read_began != began,
		listed.left(120).replace("\n", " / ")])
	_check("L2: the list still reads them: begun %s" % (grabbing.read_began != began), grabbing.read_began != began
		and listed.begins_with("Joints:"))
	grabbing.hold_still(false)


# -- a motor's mount on real sets ------------------------------------------------------------


func _motors_real_sets() -> void:
	print("")
	print("MOTORS: the mount check on real Technic sets with motors (should name none)")
	var tools: AppTools = _socket._the_app_tools()
	for id: String in ["42124-1", "42109-1", "42099-1", "42131-1", "42114-1"]:
		_main.call("clear_model")
		for _n: int in 4:
			await process_frame
		var bar: ModelBar = _main.get("_bar")
		var opened: Dictionary = await bar.open_text_with_progress(
			FileAccess.get_file_as_string("res://vendor/omr/files/%s.mpd" % id), "model")
		bar.opened.emit(int(opened.get("placed", 0)))
		for _n: int in 10:
			await process_frame
		var world: BrickWorld = _main.get("_world")
		var library: PartLibrary = _main.get("_library")
		var motors: Dictionary = Simulation.motors_in(world.bricks(), library)
		for _n: int in 30:
			await process_frame
		_reset_frames()
		var started: int = Time.get_ticks_msec()
		var said: Variant = await tools.motor_mount_said("submit_design", "", {})
		var took: int = Time.get_ticks_msec() - started
		print("RESULT %s: %d parts, %d motors; said in %d ms, longest frame %.1f ms: %s" % [id,
			world.brick_count(), motors.size(), took, _longest_frame_ms(),
			str(said).left(600).replace("\n", " / ") if not str(said).is_empty() else "(nothing named)"])
		_reset_frames()
		started = Time.get_ticks_msec()
		var poses: String = await _say("pose_model", {})
		print("RESULT %s pose_model list in %d ms, longest frame %.1f ms: %s" % [id,
			Time.get_ticks_msec() - started, _longest_frame_ms(), poses.left(240).replace("\n", " / ")])


## Which part of pose_model and the mount check holds a frame: idle frames
## first, then each phase alone, on a model opened fresh.
func _phases() -> void:
	print("")
	print("PHASES: the longest frame of each phase, after idle frames")
	var tools: AppTools = _socket._the_app_tools()
	for id: String in ["42099-1", "42109-1"]:
		_main.call("clear_model")
		for _n: int in 4:
			await process_frame
		var bar: ModelBar = _main.get("_bar")
		var opened: Dictionary = await bar.open_text_with_progress(
			FileAccess.get_file_as_string("res://vendor/omr/files/%s.mpd" % id), "model")
		bar.opened.emit(int(opened.get("placed", 0)))
		for _n: int in 60:
			await process_frame
		var grabbing: GrabDrag = _main.get("_grab_drag")
		var panel: PosePanel = _main.get("_pose")
		_reset_frames()
		for _n: int in 120:
			await process_frame
		var idle: float = _longest_frame_ms()
		# The worker's reading, waited for, as _drag_joints waits for it.
		_reset_frames()
		var t0: int = Time.get_ticks_msec()
		if not grabbing.is_ready():
			await grabbing._ready_for_session()
		var ready_ms: int = Time.get_ticks_msec() - t0
		var ready_frame: float = _longest_frame_ms()
		_reset_frames()
		t0 = Time.get_ticks_msec()
		(_main.get("_assistant") as Assistant)._tag_assemblies()
		var joints: Array[Poser.Joint] = panel.joints_now()
		await process_frame
		var named_ms: int = Time.get_ticks_msec() - t0
		var named_frame: float = _longest_frame_ms()
		_reset_frames()
		t0 = Time.get_ticks_msec()
		var drags: Array = await tools._drag_joints(grabbing, joints)
		var words := PackedStringArray()
		for drag: Array in drags:
			words.append(tools._drag_joint_words(grabbing, drag))
		await process_frame
		var drag_ms: int = Time.get_ticks_msec() - t0
		var drag_frame: float = _longest_frame_ms()
		_reset_frames()
		t0 = Time.get_ticks_msec()
		var holds: String = await tools._pose_holds()
		await process_frame
		var holds_ms: int = Time.get_ticks_msec() - t0
		var holds_frame: float = _longest_frame_ms()
		_reset_frames()
		t0 = Time.get_ticks_msec()
		var said: Variant = await tools.motor_mount_said("submit_design", "", {})
		await process_frame
		print(("RESULT %s idle %.1f ms | worker read %d ms, frame %.1f | tag+named joints %d ms, frame %.1f "
			+ "(%d) | drag joints+words %d ms, frame %.1f (%d) | pose holds %d ms, frame %.1f | mount %d ms, frame %.1f") % [
			id, idle, ready_ms, ready_frame, named_ms, named_frame, joints.size(), drag_ms, drag_frame,
			drags.size(), holds_ms, holds_frame, Time.get_ticks_msec() - t0, _longest_frame_ms()])


# -- the collection, on a stand-in account ------------------------------------------------


func _collection() -> bool:
	print("")
	print("COLLECTION: edit_collection sets= against a stand-in /api/collection (%s)" % Deployment.api_base())
	if (await _account()).is_empty():
		print("  skip: no stand-in answers at %s (python3 -I standin.py 10910)" % API)
		return false
	await _ctl({"reset": true})
	var account: Account = _main.get("_account")
	account.user_id = "m3review-probe"
	account.email = "probe@example.invalid"
	account._access = "stand-in"
	account._expires_at = Time.get_unix_time_from_system() + 7200.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var dialog: CollectionDialog = (_main.get("_shell") as Shell).collection
	var store: CollectionStore = dialog.store
	await store.load_collection()
	# [what, arguments, the account after it as {set: [copies, built]}, and
	# what the answer must say and must not].
	var cases: Array = [
		["built= out of range, checked before the add", {"sets": ["31058-1"], "built": [{"set": "31058-1", "copies": 2}]},
			{}, ["Nothing was changed: built 1: copies is a whole number from 0 to 1"], ["Added to"]],
		["the session sends it again, built= mended: one copy, kept built",
			{"sets": ["31058-1"], "built": ["31058-1"]}, {"31058-1": [1, 1]},
			["31058-1 Mighty Dinosaurs: 1 copy now (was 0)", "kept built 1 of 1 (was 0)"], ["Nothing was changed"]],
		["en dash in both, read as a hyphen in built= too", {"sets": ["42124–1"], "built": ["42124–1"]},
			{"31058-1": [1, 1], "42124-1": [1, 1]}, ["42124-1 Off-Road Buggy: 1 copy now (was 0)",
				"kept built 1 of 1 (was 0)"], ["Nothing was changed", "42124–1"]],
		["built= on a set not owned, beside sets=: refused before the add", {"sets": ["6020-1"], "built": ["10179-1"]},
			{"31058-1": [1, 1], "42124-1": [1, 1]}, ["Nothing was changed: built 1: 10179-1 is not a set in the person's collection"],
			["Added to"]],
		["built=false is as if not sent", {"sets": ["10030-1"], "built": false},
			{"31058-1": [1, 1], "42124-1": [1, 1], "10030-1": [1, 0]}, ["10030-1", "1 copy now (was 0)",
				"Every part of it is theirs to build with"], ["Nothing was changed", "Marked at"]],
		["built=true is no list: refused before the add", {"sets": ["10040-1"], "built": true},
			{"31058-1": [1, 1], "42124-1": [1, 1], "10030-1": [1, 0]}, ["Nothing was changed: built is a list"],
			["Added to"]],
	]
	for one: Array in cases:
		await _collection_case(one)
	# A reply lost after the account made the add: told it may have been made.
	await _ctl({"drop_adds": 1})
	await _collection_case(["reply lost after the add", {"sets": ["8880-1"]},
		{"31058-1": [1, 1], "42124-1": [1, 1], "10030-1": [1, 0], "8880-1": [1, 0]},
		["may have been made", "read it before sending this again"], ["Nothing was changed"]])
	# The add made and answered, the Built marks' reply lost.
	await _ctl({"drop_builts": 1})
	await _collection_case(["reply lost after the Built marks, the sets added",
		{"sets": ["7140-1"], "built": ["7140-1"]},
		{"31058-1": [1, 1], "42124-1": [1, 1], "10030-1": [1, 0], "8880-1": [1, 0], "7140-1": [1, 1]},
		["7140-1", "1 copy now (was 0)", "Their Built marks: no answer came, so they may have been made",
			"Never send sets= again"], ["Nothing was changed"]])
	# built= alone, its reply lost (as mb2review F6 had it for the lots).
	await store.load_collection()
	await _ctl({"drop_builts": 1})
	await _collection_case(["built= alone, its reply lost", {"built": [{"set": "7140-1", "copies": 0}]},
		{"31058-1": [1, 1], "42124-1": [1, 1], "10030-1": [1, 0], "8880-1": [1, 0], "7140-1": [1, 0]},
		["No answer came, so it may have been made", "read it before sending this again"], ["Nothing was changed"]])
	return true


func _collection_case(one: Array) -> void:
	var said: String = await _say("edit_collection", one[1])
	print("  [%s] %s" % [one[0], JSON.stringify(one[1])])
	print("    -> %s" % said.left(420).replace("\n", " / "))
	var now: Dictionary = await _account()
	now.erase("ok")
	print("RESULT account now: %s" % JSON.stringify(now))
	var words: bool = true
	for must: String in one[3]:
		words = words and said.contains(must)
	for never: String in one[4]:
		words = words and not said.contains(never)
	_check("H2 %s: the answer says %s and never %s" % [one[0], one[3], one[4]], words)
	_check("H2 %s: ...and the account holds %s" % [one[0], JSON.stringify(one[2])],
		JSON.stringify(now) == JSON.stringify(_sorted(one[2])))


static func _sorted(rows: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = rows.keys()
	keys.sort()
	for key: Variant in keys:
		out[key] = rows[key]
	return out


func _ctl(body: Dictionary) -> void:
	var http := HTTPRequest.new()
	root.add_child(http)
	http.request(API + "/ctl", PackedStringArray(["content-type: application/json"]), HTTPClient.METHOD_POST,
		JSON.stringify(body))
	await http.request_completed
	http.queue_free()


## The stand-in's row as {set: [copies, kept built]}, sorted; {} with none,
## or when no stand-in answers (then without its "ok" key).
func _account() -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 5.0
	root.add_child(http)
	http.request(API + "/ctl")
	var got: Array = await http.request_completed
	http.queue_free()
	if int(got[0]) != HTTPRequest.RESULT_SUCCESS or int(got[1]) != 200:
		return {}
	var row: Dictionary = (JSON.parse_string((got[3] as PackedByteArray).get_string_from_utf8()) as Dictionary)["row"]
	var counts: Dictionary = {}
	for entry: Dictionary in row["sets"]:
		var was: Array = counts.get(str(entry["set"]), [0, 0])
		counts[str(entry["set"])] = [int(was[0]) + 1, int(was[1]) + int(entry.get("built", 0))]
	counts = _sorted(counts)
	counts["ok"] = true
	return counts


# -- helpers -----------------------------------------------------------------------------


func _say(tool: String, arguments: Dictionary) -> String:
	var said: String = await _one(tool, arguments)
	var job := RegEx.create_from_string("^Started job (\\d+)")
	var found: RegExMatch = job.search(said)
	var polls: int = 0
	while found != null and polls < 240:
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
