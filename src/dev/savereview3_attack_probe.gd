## savereview3: third review of d43save (each step written as whose it is as it
## is kept: the person's while one of their input events is heard, else the
## chat of the call at work). Run the same on pre261 to compare.
##
##   godot --headless --path . --script src/dev/savereview3_attack_probe.gd
##
## Every act of the person's here is a real key, through Input, heard by the
## app's own handlers (Main._unhandled_key_input, Shell.attend, Working): a
## Delete of a selection, C (paint the selection), Ctrl+Z, Ctrl+Y. The app
## puts a big one off a frame or more to say "Taking off…" first
## (EditVerbs._say_first, Working.attend's SLOW_FROM and remembered costs),
## so it is kept after the input frame ends. The chat's calls go through
## the app's own command socket, as the connector's do. Each MEASURE line is
## what the person keeps; trees are compared by those lines.
##   D  the person's act while the chat's call is at work, then the chat's undo
##   E  the person's act with no call at work, then a session's undo or redo
##   N  no chat at all: the person's own Ctrl+Z and Ctrl+Y, and the bytes saved
extends SceneTree

const CHAT := "probe-savereview3-chat"
const GRID := 26          ## 26 x 26 = 676 bricks of the person's
const SPACE := 40.0       ## LDU between them

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _written: PackedStringArray = PackedStringArray()
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _bg_said: String = ""
var _bg_done: bool = false
var _pid: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_savereview3_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_savereview3_collection.json"
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
	var account: Account = _main.get("_account")
	while account.state == Account.State.CHECKING:
		await account.changed
	await process_frame
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_pid = OS.get_process_id()
	Assistant.brickbench = false

	await _while_a_call_works()
	await _with_no_call()
	await _no_chat_at_all()
	_quit()


# ---- D: the person's act while a call of the chat's is at work ------------------


func _while_a_call_works() -> void:
	for arm: Array in [
			["D1 Delete, 5 selected, while the chat's view_model looks", 5, "delete", "view_model"],
			["D2 Delete, 320 selected, while the chat's view_model looks", 320, "delete", "view_model"],
			["D3 C (paint), 620 selected, while the chat's view_model looks", 620, "paint", "view_model"],
			["D4 Delete, 320 selected, while the chat's check_design checks", 320, "delete", "check_design"]]:
		var tag: String = str(arm[0]).left(2)
		print("\n%s; then the chat asks undo" % arm[0])
		await _person_grid()
		var ids: Array = _select(int(arm[1]))
		var before: int = _world.brick_count()
		var colours_before: int = _count_colour(ids, 4)
		var input: Dictionary = {} if arm[3] == "view_model" else {"name": "grid", "bricks": [
			{"part": "3005", "color": 1, "x": 0, "y": 0, "z": 0}]}
		var mid: bool = await _act_during(str(arm[3]), input, str(arm[2]), ids)
		var after: int = _world.brick_count()
		var painted: int = _count_colour(ids, 4)
		print("    the person's %s landed while the call was at work: %s; parts %d -> %d; painted red %d -> %d; top %s" % [
			arm[2], mid, before, after, colours_before, painted, _top()])
		var said: String = await _say("undo", {}, CHAT)
		print("    SAID: " + said.left(300).replace("\n", " "))
		var undone_count: int = _world.brick_count()
		var undone_red: int = _count_colour(ids, 4)
		print("    MEASURE %s: mid %s; after the chat's undo parts %d (the person left %d), red %d (the person left %d)" % [
			tag, mid, undone_count, after, undone_red, painted])
		_check("%s the person's act was kept while the call was at work" % tag, mid)
		if arm[2] == "delete":
			_check("%s the person's delete was made" % tag, after == before - int(arm[1]))
			_check("%s the chat's undo leaves the person's delete" % tag, undone_count == after)
		else:
			_check("%s the person's paint was made" % tag, painted == ids.size())
			_check("%s the chat's undo leaves the person's paint" % tag, undone_red == painted)


## The person's [param verb] by its key while the chat's [param tool] is at
## work; whether the act's step was kept while the call was still at work.
func _act_during(tool: String, input: Dictionary, verb: String, ids: Array) -> bool:
	_bg_done = false
	_spawned(tool, input, CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	if _bg_done:
		print("    the call ended before the person could act")
		return false
	var depth: int = _builder.history_depth()
	_key(KEY_DELETE if verb == "delete" else KEY_C)
	var mid: bool = false
	for _n: int in 600:
		await process_frame
		if _builder.history_depth() != depth or _bg_done:
			mid = CommandSocket.at_work() and _builder.history_depth() != depth
			break
	for _n: int in 3000:
		if _bg_done:
			break
		await process_frame
	await _frames(3)
	return mid


# ---- E: the person's act with no call at work -----------------------------------


func _with_no_call() -> void:
	print("\nE1 the person deletes 320 by Delete; a session with no chat asks undo")
	await _person_grid()
	_select(320)
	var before: int = _world.brick_count()
	_key(KEY_DELETE)
	await _frames(8)
	var after: int = _world.brick_count()
	print("    parts %d -> %d; top %s" % [before, after, _top()])
	var said: String = await _say("undo", {}, "")
	print("    SAID: " + said.left(300).replace("\n", " "))
	print("    MEASURE E1: after the chat-less undo parts %d (the person left %d)" % [_world.brick_count(), after])
	_check("E1 a chat-less session's undo leaves the person's delete", _world.brick_count() == after)

	print("\nE2 the person deletes 320 and takes it back with Ctrl+Z; the chat asks redo")
	await _person_grid()
	_select(320)
	before = _world.brick_count()
	_key(KEY_DELETE)
	await _frames(8)
	_key(KEY_Z, true)
	await _frames(8)
	var back: int = _world.brick_count()
	print("    parts %d -> deleted -> %d after the person's own Ctrl+Z" % [before, back])
	said = await _say("undo", {"redo": true}, CHAT)
	print("    SAID: " + said.left(300).replace("\n", " "))
	print("    MEASURE E2: after the chat's redo parts %d (the person left %d)" % [_world.brick_count(), back])
	_check("E2 the chat's redo leaves the delete the person took back", _world.brick_count() == back)


# ---- N: no chat at all -----------------------------------------------------------


func _no_chat_at_all() -> void:
	print("\nN1 no chat: the person's Delete 5, Delete 320, C 300; Ctrl+Z x3, Ctrl+Y x3")
	await _person_grid()
	var counts := PackedInt32Array()
	counts.append(_world.brick_count())
	_select(5)
	_key(KEY_DELETE)
	await _frames(8)
	counts.append(_world.brick_count())
	var painted: Array = _select(320)
	_key(KEY_DELETE)
	await _frames(8)
	counts.append(_world.brick_count())
	painted = _select(300)
	_key(KEY_C)
	await _frames(8)
	var red: int = _count_colour(painted, 4)
	for _n: int in 3:
		_key(KEY_Z, true)
		await _frames(8)
	var undone: int = _world.brick_count()
	var undone_red: int = _count_colour(painted, 4)
	for _n: int in 3:
		_key(KEY_Y, true)
		await _frames(8)
	print("    MEASURE N1: parts %s; red %d; after Ctrl+Z x3 parts %d red %d; after Ctrl+Y x3 parts %d red %d; depth %d" % [
		counts, red, undone, undone_red, _world.brick_count(), _count_colour(painted, 4),
		_builder.history_depth()])
	_check("N1 Ctrl+Z x3 puts every part back", undone == counts[0] and undone_red == 0)
	_check("N1 Ctrl+Y x3 does all three again", _world.brick_count() == counts[2]
		and _count_colour(painted, 4) == red)
	var path: String = ModelStore.SAVE_DIR + "sr3-n1-%d.ldr" % _pid
	_written.append(path)
	var saved: bool = _store.save_file(path, "sr3 n1")
	if saved and FileAccess.file_exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		var lines: int = 0
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("1 "):
				lines += 1
		print("    MEASURE N1 bytes: %d, part lines %d, md5 %s" % [text.to_utf8_buffer().size(),
			lines, FileAccess.get_md5(path)])
	else:
		print("    MEASURE N1 bytes: not saved")


# ---- the person's model and hands ----------------------------------------------


## The person lays GRID x GRID 1x1 bricks as one step of theirs, on a bare
## baseplate the chat cleared.
func _person_grid() -> void:
	await _say("clear_model", {}, CHAT)
	await _frames(2)
	_builder.clear_selection()
	var ids: Array = []
	for x: int in GRID:
		for z: int in GRID:
			ids.append(_world.add_brick("3005", 1, Transform3D(Basis(),
				Vector3(x * SPACE, 0, z * SPACE))))
	var steps: Array = []
	for brick_id: int in ids:
		steps.append({"undo": "remove", "brick": brick_id})
	_builder.record(steps, "laid %d bricks" % ids.size())
	await _frames(2)


## [param count] of the person's bricks selected, as a drag box selects.
func _select(count: int) -> Array:
	_builder.clear_selection()
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if ids.size() >= count:
			break
		if brick.part_id == "3005":
			ids.append(brick.id)
			_builder.selection[brick.id] = true
	_builder.selection_changed.emit(_builder.selection.size())
	_builder.held_color = 4
	return ids


func _count_colour(ids: Array, colour: int) -> int:
	var count: int = 0
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(int(brick_id))
		if brick != null and brick.color_code == colour:
			count += 1
	return count


## A key pressed and let go by the person, through Input as the window's.
func _key(code: Key, ctrl: bool = false) -> void:
	root.gui_release_focus()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		Input.parse_input_event(event)


func _top() -> String:
	if _builder.history_depth() == 0:
		return "(none)"
	var step: Dictionary = _builder.last_step()
	return "\"%s\" by %s" % [_builder.history_words(1, false)[0], "the person"
		if bool(step.get("person", false)) else "\"%s\"" % str(step.get("by", "(unmarked)"))]


# ---- the harness (as savereview2_attack_probe's) ------------------------------


func _spawned(tool: String, arguments: Dictionary, chat: String) -> void:
	_bg_said = await _say(tool, arguments, chat)
	_bg_done = true


func _say(tool: String, arguments: Dictionary, chat: String) -> String:
	var said: String = await _one(tool, arguments, chat)
	var job := RegEx.create_from_string("^(Tab [^.]*\\. )?Started job (\\d+)")
	var found: RegExMatch = job.search(said)
	var polls: int = 0
	while found != null and polls < 120:
		said = await _one("job", {"id": int(found.get_string(2))}, chat)
		polls += 1
		if not said.contains("is still going"):
			break
	return said


func _one(tool: String, arguments: Dictionary, chat: String) -> String:
	_next += 1
	var params: Dictionary = {"name": tool, "arguments": arguments}
	if not chat.is_empty():
		params["_meta"] = {CommandSocket.CHAT_KEY: {"chat": chat}}
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": params})
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
	print("savereview3_attack_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
