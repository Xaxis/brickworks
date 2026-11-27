## savereview4: the person's own design in the app's panel lands its floor while a
## Claude chat's call is at work. Whose is the floor's step, and does the chat's undo
## take it? (actorstamp: the floor's step is kept inside Builder.by(Assistant.call_by),
## a member each call from outside sets for its length.) Run the same on pre261.
##
##   godot --headless --path . --script src/dev/savereview4_panel_probe.gd
##
## The panel's loop runs whole, its requests answered by a stand-in for the
## Messages API on this machine (as design_undo_probe's): no key is spent and
## nothing leaves the machine. The chat's calls go through the app's own
## CommandSocket: booklet_layout, which only looks, again and again while the
## panel's design is worked out.
extends SceneTree

const CHAT := "probe-savereview4-panel-chat"

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _world: BrickWorld
var _builder: Builder
var _api: _Api


## A stand-in for the Messages API (design_undo_probe's): each POST answered
## with the next reply written here, and "Done." once they run out.
class _Api extends Node:
	var replies: Array = []
	var asked: int = 0
	var port: int = 0
	var _server := TCPServer.new()
	var _peers: Array = []

	func _init() -> void:
		for wanted: int in range(12990, 12999):
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
	Account.where = "user://probe_savereview4_panel_session.json"
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
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	var store: ModelStore = _main.get("_store")
	var assistant: Assistant = _main.get("_assistant")
	var chat: ChatPanel = _main.get("_chat")
	print("tree: %s" % ("actorstamp" if _builder.has_method("by_wait") else "pre261"))
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	store.scenery.clear()
	assistant.forget_built()
	assistant.forget_conversation()
	_main.set("_sample_untouched", false)
	_api = _Api.new()
	root.add_child(_api)
	assistant.endpoint = "http://127.0.0.1:%d/v1/messages" % _api.port
	assistant.stream_replies = false
	# A key for this run only, written nowhere, sent nowhere but the stand-in.
	OwnKey._this_visit = "sk-ant-probe-savereview4-000000000000000000000000000000"
	var ended: Array = []
	assistant.finished.connect(func(ok: bool, summary: String) -> void: ended.append([ok, summary]))

	print("\nPN the person asks the panel for a hut on its lot; their Claude chat looks at the booklet meanwhile")
	var hut: Array = []
	for x: int in 4:
		for z: int in 3:
			hut.append({"part": "3001", "color": 4, "x": x * 4, "y": 0, "z": z * 2})
	_api.replies = [{"content": [{"type": "tool_use", "id": "toolu_probe_sr4", "name": "submit_design",
		"input": {"name": "Hut", "description": "a small red hut on its lot, a scene", "floor": "baseplate",
			"floor_colour": "Green", "bricks": hut}}], "stop_reason": "tool_use"}]
	chat._input.text = "a small red hut on its lot"
	chat._sketch_first.button_pressed = false
	chat._on_send()
	print("    the panel's run began: %s" % assistant.is_busy())
	var calls: int = 0
	var at_work_when_floor: Array = []
	var depth_seen: int = _builder.history_depth()
	var until: int = Time.get_ticks_msec() + 240000
	while ended.is_empty() and Time.get_ticks_msec() < until:
		_spawned_look()
		calls += 1
		for _n: int in 400:
			await process_frame
			if _builder.history_depth() != depth_seen:
				depth_seen = _builder.history_depth()
				at_work_when_floor.append("%s at depth %d (chat's call at work %s)" % [_newest(), depth_seen,
					CommandSocket.at_work()])
			if _look_done or not ended.is_empty():
				break
	for _n: int in 600:
		if _look_done:
			break
		await process_frame
	await _frames(20)
	print("    the panel's run ended: %s; the chat looked %d times; its last look: %s" % [str(ended.back()) if not ended.is_empty()
		else "never", calls, _look_said.left(100).replace("\n", " ")])
	for line: String in at_work_when_floor:
		print("    kept: " + line)
	var wrong: PackedStringArray = PackedStringArray()
	for step: Dictionary in _builder.steps_now()[0]:
		var by: String = str(step.get("by", ""))
		print("    history: \"%s\" by %s" % [str(step.get("words", step.get("undo", "?"))).left(80),
			"\"%s\"" % by if not by.is_empty() else "the person"])
		if by == CHAT:
			wrong.append(str(step.get("words", "?")).left(60))
	_check("PN no step of the person's own panel design is the chat's (%s)" % ", ".join(wrong), wrong.is_empty())
	var parts: int = _world.brick_count()
	var said: String = await _say("undo", {}, CHAT)
	await _frames(10)
	print("    the chat's undo: " + said.left(240).replace("\n", " "))
	print("    MEASURE PN: parts %d before the chat's undo, %d after" % [parts, _world.brick_count()])
	_check("PN the chat's undo takes nothing of the person's panel design", _world.brick_count() == parts
		and not said.begins_with("Undid"))
	print("\nPN2 the person's own Undo, twice (their design, then their baseplate made part of it); then the chat's undo")
	_builder.undo()
	_builder.undo()
	await _frames(10)
	var left: int = _world.brick_count()
	print("    after the person's two Undos: %d parts; newest %s" % [left, _newest()])
	said = await _say("undo", {}, CHAT)
	await _frames(10)
	print("    the chat's undo: " + said.left(240).replace("\n", " "))
	print("    MEASURE PN2: parts %d before the chat's undo, %d after" % [left, _world.brick_count()])
	_check("PN2 the chat's undo leaves the person's baseplate (the floor of their own design)",
		_world.brick_count() == left and not said.begins_with("Undid"))
	_quit()


var _look_done: bool = true


var _look_said: String = ""


## The chat's look: a check of 400 bricks, worked on a worker a frame at a
## time, so the call is at work for many frames; booklet_layout when the
## check is refused while the panel's designer works.
func _spawned_look() -> void:
	_look_done = false
	if not _look_said.contains("designer"):
		var look: Array = []
		for x: int in 20:
			for z: int in 20:
				look.append({"part": "3005", "color": 1, "x": x + 40, "y": 0, "z": z + 40})
		_look_said = await _say("check_design", {"name": "look", "bricks": look}, CHAT)
	else:
		await _say("booklet_layout", {}, CHAT)
	_look_done = true


func _newest() -> String:
	var step: Dictionary = _builder.last_step()
	var by: String = str(step.get("by", ""))
	return "\"%s\" by %s" % [str(step.get("words", step.get("undo", "?"))).left(70),
		"\"%s\"" % by if not by.is_empty() else "the person"]


func _say(tool: String, arguments: Dictionary, chat: String) -> String:
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
	print("savereview4_panel_probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(0 if _failures == 0 else 1)
