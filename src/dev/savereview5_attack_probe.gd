## savereview5: the second review of actorstamp2 (whose a step is goes with the
## act). A call from outside that keeps no step of its own has its change measured
## (CommandSocket._one_step: the model as the call began, against the model as it
## ends): whatever changed in between with no step is the call's. Is a part laid
## by someone else meanwhile, with no step yet (the person's own design in the
## panel, another chat's design), ever kept as the call's? Run the same on pre261.
##
##   godot --headless --path . --script src/dev/savereview5_attack_probe.gd -- --sr5=pr,ps,pc,cr,cc
##
##   pr  the person's own design in the panel (600 red bricks, laid over frames)
##       while their Claude chat calls review_model again and again (not queued)
##   ps  the same with the chat's save_model
##   pc  the same with the chat's clear_model once, mid-design
##   cr  chat A's submit_design (600 yellow bricks) while chat B calls review_model
##   cc  chat A's submit_design while chat B calls clear_model once
## Judged by what the person keeps: which steps hold the designed parts, and what
## each undo (the chat's, the person's) takes.
extends SceneTree

const CHAT := "probe-savereview5-chat"
const OTHER := "probe-savereview5-other"
const SPACE := 40.0
const SIDE := 24

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _assistant: Assistant
var _api: _Api
var _bg_said: String = ""
var _bg_done: bool = true
var _fg_done: bool = true
var _fg_said: String = ""
var _ended: Array = []


## A stand-in for the Messages API (savereview4_panel_probe's): each POST
## answered with the next reply written here, and "Done." once they run out.
class _Api extends Node:
	var replies: Array = []
	var asked: int = 0
	var port: int = 0
	var _server := TCPServer.new()
	var _peers: Array = []

	func _init() -> void:
		for wanted: int in range(13080, 13089):
			if _server.listen(wanted, "127.0.0.1") == OK:
				port = wanted
				return

	func _process(_delta: float) -> void:
		while _server.is_connection_available():
			_peers.append([_server.take_connection(), PackedByteArray()])
		for held: Array in _peers.duplicate():
			var peer: StreamPeerTCP = held[0]
			peer.poll()
			if peer.get_available_bytes() > 0:
				held[1] = (held[1] as PackedByteArray) \
					+ (peer.get_data(peer.get_available_bytes())[1] as PackedByteArray)
			var got: PackedByteArray = held[1]
			var text: String = got.get_string_from_utf8()
			var cut: int = text.find("\r\n\r\n")
			if cut < 0:
				continue
			var length: RegExMatch = RegEx.create_from_string("(?i)content-length: *(\\d+)") \
				.search(text.left(cut))
			if length != null and got.size() < cut + 4 + int(length.get_string(1)):
				continue
			asked += 1
			var reply: Dictionary = replies.pop_front() if not replies.is_empty() \
				else {"content": [{"type": "text", "text": "Done."}], "stop_reason": "end_turn"}
			var bytes: PackedByteArray = JSON.stringify(reply).to_utf8_buffer()
			peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
				+ "Content-Length: %d\r\nConnection: close\r\n\r\n" % bytes.size()).to_utf8_buffer())
			peer.put_data(bytes)
			peer.disconnect_from_host()
			_peers.erase(held)

	func _exit_tree() -> void:
		_server.stop()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveTo.native = false
	Account.where = "user://probe_savereview5_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_savereview5_collection.json"
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
	_assistant = _main.get("_assistant")
	Assistant.brickbench = false
	print("tree: %s" % ("actorstamp" if _builder.has_method("by_wait") else "pre261"))
	_api = _Api.new()
	root.add_child(_api)
	_assistant.endpoint = "http://127.0.0.1:%d/v1/messages" % _api.port
	_assistant.stream_replies = false
	# A key for this run only, written nowhere, sent nowhere but the stand-in.
	OwnKey._this_visit = "sk-ant-probe-savereview5-000000000000000000000000000000"
	_assistant.finished.connect(func(ok: bool, summary: String) -> void: _ended.append([ok, summary]))
	var parts: PackedStringArray = PackedStringArray(["pr", "ps", "pc", "cr", "cc"])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sr5="):
			parts = arg.trim_prefix("--sr5=").split(",")
	for part: String in parts:
		match part:
			"pr":
				await _panel_beside("PR", "review_model", {})
			"ps":
				await _panel_beside("PS", "save_model", {"name": "sr5 panel save"})
			"pc":
				await _panel_beside("PC", "clear_model", {}, true)
			"cr":
				await _chats_beside("CR", "review_model", {})
			"cc":
				await _chats_beside("CC", "clear_model", {}, true)
			"bk":
				await _brickify_undo()
	_quit()


## savereview4's F5: the chat's brickify of the bunny beside the person's grid,
## then the chat's undo. Which parts differ from the model before, and whose are
## they: the person's grid (blue 3005s), or the bunny's?
func _brickify_undo() -> void:
	print("\nBK the chat's brickify of the bunny beside the person's 6 x 6 grid, then the chat's undo")
	await _person_grid(6)
	var was: PackedStringArray = _snap()
	var bunny: String = ProjectSettings.globalize_path("res://tests/fixtures/brickify/bunny.obj")
	var said: String = await _say("brickify", {"file": bunny, "studs": 10}, CHAT)
	await _frames(5)
	print("    SAID: " + said.left(160).replace("\n", " "))
	print("    parts after: %d (before %d)" % [_world.brick_count(), was.size()])
	var undo: String = await _say("undo", {}, CHAT)
	await _frames(10)
	print("    the chat's undo: " + undo.left(160).replace("\n", " "))
	var back: PackedStringArray = _snap()
	var gone := PackedStringArray()
	var extra := PackedStringArray()
	for line: String in was:
		if not back.has(line):
			gone.append(line)
	for line: String in back:
		if not was.has(line):
			extra.append(line)
	print("    MEASURE BK: before %d, after the undo %d; the person's own parts gone %d, parts left over %d" % [
		was.size(), back.size(), gone.size(), extra.size()])
	for line: String in gone:
		print("      gone: " + line)
	for line: String in extra:
		print("      left: " + line)
	_check("BK the chat's undo takes none of the person's own parts", gone.is_empty())
	_check("BK the chat's undo leaves nothing of the brickify", extra.is_empty())
	# And the person's Ctrl+Z after the chat's brickify, in place of the chat's undo.
	_main.call("clear_model")
	await _frames(3)
	await _person_grid(6)
	was = _snap()
	said = await _say("brickify", {"file": bunny, "studs": 10}, CHAT)
	await _frames(5)
	(_main.get("_verbs") as EditVerbs).own_undo()
	await _frames(15)
	back = _snap()
	gone = PackedStringArray()
	extra = PackedStringArray()
	for line: String in was:
		if not back.has(line):
			gone.append(line)
	for line: String in back:
		if not was.has(line):
			extra.append(line)
	print("    MEASURE BK2 (the person's Undo): before %d, after %d; the person's own parts gone %d, left over %d" % [
		was.size(), back.size(), gone.size(), extra.size()])
	for line: String in extra:
		print("      left: " + line)
	_check("BK2 the person's Undo of the brickify leaves nothing of it and takes none of theirs",
		gone.is_empty() and extra.is_empty())


## The model, part for part: part, colour and place of each, sorted.
func _snap() -> PackedStringArray:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		var o: Vector3 = brick.transform.origin
		out.append("%s|%d|%.1f,%.1f,%.1f|scenery %s" % [brick.part_id, brick.color_code, o.x, o.y, o.z,
			_store.scenery.has(brick.id)])
	out.sort()
	return out


## A flat lot of [param side] x [param side] bricks of [param colour], each on
## the baseplate: one design that holds together, laid over many frames.
func _lot(colour: int, part: String = "3001") -> Array:
	var bricks: Array = []
	for x: int in SIDE:
		for z: int in SIDE:
			bricks.append({"part": part, "color": colour, "x": x * 4 + 2, "y": 0, "z": z * 2 + 1})
	return bricks


## The person's own grid of blue 1x1s, laid by them (one step of theirs).
func _person_grid(side: int) -> void:
	_main.call("clear_model")
	await _frames(3)
	_builder.forget_history()
	_builder.clear_selection()
	var ids: Array = []
	for x: int in side:
		for z: int in side:
			ids.append(_world.add_brick("3005", 1, Transform3D(Basis(),
				Vector3(-800 - x * SPACE, 0, -800 - z * SPACE))))
	var steps: Array = []
	for brick_id: int in ids:
		steps.append({"undo": "remove", "brick": brick_id})
	_builder.record(steps, "laid %d bricks" % ids.size())
	await _frames(3)


## The person's panel design (red 3001s) while their chat calls [param tool]
## again and again ([param once]: one call, mid-design).
func _panel_beside(tag: String, tool: String, input: Dictionary, once: bool = false) -> void:
	print("\n%s the person asks the panel for a lot of 576 red bricks; their chat calls %s meanwhile%s" % [tag,
		tool, " once" if once else ""])
	await _person_grid(3)
	_assistant.forget_built()
	_assistant.forget_conversation()
	_main.set("_sample_untouched", false)
	_ended.clear()
	_api.replies = [{"content": [{"type": "tool_use", "id": "toolu_probe_sr5", "name": "submit_design",
		"input": {"name": "Lot", "description": "a flat red lot, a slab", "floor": "none",
			"bricks": _lot(4)}}], "stop_reason": "tool_use"}]
	var chat: ChatPanel = _main.get("_chat")
	chat._input.text = "a flat red lot"
	chat._sketch_first.button_pressed = false
	chat._on_send()
	print("    the panel's run began: %s" % _assistant.is_busy())
	var watch: Dictionary = {"landed_in_call": 0, "landed": 0, "calls": 0, "said": PackedStringArray()}
	var red_was: int = _count(4)
	var until: int = Time.get_ticks_msec() + 300000
	var sent_once: bool = false
	while _ended.is_empty() and Time.get_ticks_msec() < until:
		if _fg_done and (not once or not sent_once) and (not once or _count(4) > 40):
			sent_once = true
			watch["calls"] = int(watch["calls"]) + 1
			_spawn_fg(tool, input, CHAT)
		var before: int = _count(4)
		await process_frame
		var now: int = _count(4)
		if now != before:
			watch["landed"] = int(watch["landed"]) + absi(now - before)
			if not _fg_done:
				watch["landed_in_call"] = int(watch["landed_in_call"]) + absi(now - before)
	for _n: int in 3000:
		if _fg_done:
			break
		await process_frame
	await _frames(20)
	print("    the panel's run ended: %s; the chat called %s %d times; red landed %d, %d of them while its call was at work"
		% [str(_ended.back()) if not _ended.is_empty() else "never", tool, int(watch["calls"]),
		int(watch["landed"]), int(watch["landed_in_call"])])
	print("    the chat's last answer: %s" % _fg_said.left(160).replace("\n", " "))
	await _judge(tag, 4, "", "the person's own panel design", CHAT, red_was)


## Chat A's submit_design (yellow 3001s) beside the person's grid, while chat B
## calls [param tool] (again and again, or [param once]).
func _chats_beside(tag: String, tool: String, input: Dictionary, once: bool = false) -> void:
	print("\n%s chat A's submit_design of 576 yellow bricks; chat B calls %s meanwhile%s" % [tag, tool,
		" once" if once else ""])
	await _person_grid(3)
	var yellow_was: int = _count(14)
	_bg_done = false
	_spawn_bg("submit_design", {"name": "sr5 lot", "description": "a flat yellow lot, a slab", "floor": "none",
		"bricks": _lot(14)}, CHAT)
	for _n: int in 600:
		if _bg_done or CommandSocket.at_work():
			break
		await process_frame
	var watch: Dictionary = {"landed_in_call": 0, "landed": 0, "calls": 0}
	var sent_once: bool = false
	var until: int = Time.get_ticks_msec() + 300000
	while not _bg_done and Time.get_ticks_msec() < until:
		if _fg_done and (not once or not sent_once):
			sent_once = true
			watch["calls"] = int(watch["calls"]) + 1
			_spawn_fg(tool, input, OTHER)
		var before: int = _count(14)
		await process_frame
		var now: int = _count(14)
		if now != before:
			watch["landed"] = int(watch["landed"]) + absi(now - before)
			if not _fg_done:
				watch["landed_in_call"] = int(watch["landed_in_call"]) + absi(now - before)
	for _n: int in 3000:
		if _fg_done:
			break
		await process_frame
	await _frames(20)
	print("    chat A's design: %s" % _bg_said.left(120).replace("\n", " "))
	print("    chat B called %s %d times; yellow landed %d, %d of them while B's call was at work; B's last: %s" % [tool,
		int(watch["calls"]), int(watch["landed"]), int(watch["landed_in_call"]), _fg_said.left(120).replace("\n", " ")])
	await _judge(tag, 14, CHAT, "chat A's design", OTHER, yellow_was)


## Whose the steps holding the designed parts ([param colour]) are: each must be
## [param maker]'s ("" the person's). Then [param other]'s undo, as often as it
## undoes: it must never take a designed part. Then the maker's own undo.
func _judge(tag: String, colour: int, maker: String, what: String, other: String, was: int) -> void:
	var wrong := PackedStringArray()
	var holding: int = 0
	for step: Dictionary in _builder.steps_now()[0]:
		var by: String = str(step.get("by", ""))
		var laid: int = _lays(step, colour)
		print("    history: \"%s\" by %s%s" % [str(step.get("words", step.get("undo", "?"))).left(90),
			"\"%s\"" % by if not by.is_empty() else "the person", (", holds %d of the designed parts" % laid)
			if laid > 0 else ""])
		holding += laid
		if laid > 0 and by != maker:
			wrong.append("%d in \"%s\" by %s" % [laid, str(step.get("words", "?")).left(50),
				by if not by.is_empty() else "the person"])
	var standing: int = _count(colour)
	print("    MEASURE %s: %d designed parts stand, %d of them in some step" % [tag, standing - was, holding])
	_check("%s every step holding %s's parts is %s's (%s)" % [tag, what, "the person" if maker.is_empty()
		else maker, "; ".join(wrong)], wrong.is_empty())
	_check("%s every designed part standing is in a step, so some undo takes it (%d of %d)" % [tag, holding,
		standing - was], holding >= standing - was)
	var before: int = _count(colour)
	var told := PackedStringArray()
	for _n: int in 4:
		var said: String = await _say("undo", {}, other)
		await _frames(10)
		told.append(said.left(140).replace("\n", " "))
		if not said.begins_with("Undid") and not said.begins_with("Redid"):
			break
	print("    %s's undo, as often as it undoes: %s" % [other, " || ".join(told)])
	print("    MEASURE %s: designed parts %d before %s's undo, %d after" % [tag, before, other, _count(colour)])
	_check("%s %s's undo takes none of %s's parts" % [tag, other, what], _count(colour) == before)


## How many parts of [param colour] the step [param step] put down (its undo takes off).
func _lays(step: Dictionary, colour: int) -> int:
	var count: int = 0
	if str(step.get("undo", "")) == "remove":
		var brick: BrickWorld.Brick = _world.get_brick(int(step.get("brick", 0)))
		if brick != null and brick.color_code == colour:
			count += 1
	for inner: Variant in step.get("steps", []):
		if inner is Dictionary:
			count += _lays(inner, colour)
	return count


func _count(colour: int) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.color_code == colour:
			count += 1
	return count


# ---- the harness (savereview4_attack_probe's) ----------------------------------------


func _spawn_bg(tool: String, arguments: Dictionary, chat: String) -> void:
	_bg_done = false
	_bg_said = await _say(tool, arguments, chat)
	_bg_done = true


func _spawn_fg(tool: String, arguments: Dictionary, chat: String) -> void:
	_fg_done = false
	_fg_said = await _say(tool, arguments, chat)
	_fg_done = true


func _say(tool: String, arguments: Dictionary, chat: String) -> String:
	var said: String = await _one(tool, arguments, chat)
	var job := RegEx.create_from_string("^(Tab [^.]*\\. )?Started job (\\d+)")
	var found: RegExMatch = job.search(said)
	var polls: int = 0
	while found != null and polls < 240:
		said = await _one("job", {"id": int(found.get_string(2))}, chat)
		polls += 1
		if not said.contains("is still going"):
			break
		await _frames(30)
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
	print("savereview5_attack_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
