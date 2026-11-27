## actorstamp: a step a session's tool keeps after it has waited frames is
## still the session's, and the person's act in those frames is still theirs.
## A tool's first stretch runs as its session's (CommandSocket._by); one that
## waits carries the session to the step it keeps (Builder.by, AppTools._mine).
##
##   godot --headless --path . --script src/dev/actorstamp_probe.gd
##
## The person's act is a real key (C paints the selection), through Input,
## heard by the app's own handlers, pressed while the chat's call waits. The
## chat's calls go through the app's own command socket, as the connector's
## do. On pre261 (a2a22a188, 11-27) the paint was folded into the chat's
## step, its undo took the paint and its next undo the person's 676 bricks:
## 8 fail of 14.
##   S1 edit_steps names a step of 676 parts: its plan is worked out a slice
##      a frame first (AppTools._edit_steps, STEPS_PACED_FROM)
##   S2 edit_booklet puts words on step 1's page: the page is laid out first,
##      a frame at least (AppTools._edit_page, BookletMaker)
extends SceneTree

const CHAT := "probe-actorstamp-chat"
const GRID := 26          ## 26 x 26 = 676 bricks of the person's
const SPACE := 40.0       ## LDU between them
const PAINTED := 5        ## the person's selection, painted red (4)

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _world: BrickWorld
var _builder: Builder
var _bg_said: String = ""
var _bg_done: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_actorstamp_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_actorstamp_collection.json"
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
	Assistant.brickbench = false
	print("tree: %s" % ("actorstamp (a session's code keeps its own)" if _builder.has_method("by_wait")
		else "pre261"))

	await _paint_during("S1", "edit_steps names step 1 of 676 parts",
		"edit_steps", {"op": "name", "step": 1, "name": "The grid"})
	await _paint_during("S2", "edit_booklet puts words on step 1's page",
		"edit_booklet", {"step": 1, "text": {"words": "Actor probe", "x": 20.0, "y": 150.0,
			"w": 120.0, "h": 12.0, "size": 6.0}})
	_quit()


## The person paints [constant PAINTED] bricks red by C while the chat's
## [param tool] works; then the chat's undo, twice, and the person's Ctrl+Z.
func _paint_during(tag: String, what: String, tool: String, input: Dictionary) -> void:
	print("\n%s %s while the person paints %d bricks red by C; then the chat's undo twice, then Ctrl+Z" % [
		tag, what, PAINTED])
	await _person_grid()
	var ids: Array = _select(PAINTED)
	var depth: int = _builder.history_depth()
	_bg_done = false
	_spawned(tool, input, CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	var mid: bool = false
	if not _bg_done:
		_key(KEY_C)
		for _n: int in 600:
			await process_frame
			if _count_colour(ids, 4) == ids.size() or _bg_done:
				mid = CommandSocket.at_work() and _count_colour(ids, 4) == ids.size()
				break
	for _n: int in 3000:
		if _bg_done:
			break
		await process_frame
	await _frames(3)
	print("    SAID: " + _bg_said.left(240).replace("\n", " "))
	var history: Array = _builder.steps_now()[0]
	var kept: Array = history.slice(depth)
	var newest_first: PackedStringArray = _builder.history_words(kept.size(), false)
	var told := PackedStringArray()
	var paint_at: int = -1
	var chat_at: int = -1
	var chats: int = 0
	var persons: int = 0
	for n: int in kept.size():
		var step: Dictionary = kept[n]
		var words: String = newest_first[kept.size() - 1 - n] if kept.size() - 1 - n < newest_first.size() else "?"
		told.append("\"%s\" by %s" % [words.left(60), str(step.get("by", "the person"))])
		if paint_at < 0 and words.contains("painted %d parts" % PAINTED):
			paint_at = n
		if str(step.get("by", "")) == CHAT:
			chats += 1
			chat_at = n if chat_at < 0 else chat_at
		elif not step.has("by"):
			persons += 1
	# The call keeps its own step before it ends: the paint kept before it
	# (or folded into it) landed while the call worked, even when the call
	# ends in the frame the paint lands, as a one-frame layout does.
	var before_the_call: bool = paint_at >= 0 and chat_at >= 0 and paint_at <= chat_at
	print("    MEASURE %s: painted while at work %s, kept before the call's own step %s; %d steps kept since: %s" % [
		tag, mid, before_the_call, kept.size(), ", ".join(told)])
	_check("%s the person's paint landed while the chat's call worked" % tag, mid or before_the_call)
	_check("%s the chat's change is one step, the chat's" % tag, chats == 1)
	_check("%s the person's paint is a step of their own" % tag, persons == 1)
	var said: String = await _say("undo", {}, CHAT)
	print("    SAID (undo): " + said.left(240).replace("\n", " "))
	var red_after_chat: int = _count_colour(ids, 4)
	var redo: Array = _builder.steps_now()[1]
	var redo_by: String = str((redo.back() as Dictionary).get("by", "")) if not redo.is_empty() else ""
	_check("%s the chat's undo took its own change" % tag, said.begins_with("Undid") and redo_by == CHAT)
	_check("%s the chat's undo left the person's paint" % tag, red_after_chat == ids.size())
	var again: String = await _say("undo", {}, CHAT)
	print("    SAID (undo again): " + again.left(240).replace("\n", " "))
	_check("%s the chat's next undo refuses the person's paint, saying so" % tag,
		again.contains("is the person's own") and _count_colour(ids, 4) == ids.size())
	_key(KEY_Z, true)
	await _frames(8)
	var red_after_person: int = _count_colour(ids, 4)
	print("    MEASURE %s: red after the chat's undo %d, after its second %d, after the person's Ctrl+Z %d (of %d)" % [
		tag, red_after_chat, ids.size() if again.contains("is the person's own") else -1,
		red_after_person, ids.size()])
	_check("%s the person's Ctrl+Z takes back their paint" % tag, red_after_person == 0)


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


## [param count] of the person's bricks selected, as a drag box selects, red
## in hand.
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


# ---- the harness (as savereview3_attack_probe's) ------------------------------


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
	DirAccess.remove_absolute(CollectionStore.where)
	print("actorstamp_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(1 if _failures > 0 else 0)
