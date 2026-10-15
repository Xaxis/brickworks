## What Claude's design loop in the app changes is one undo step, its own.
##
##   godot --headless --path . --script src/dev/design_undo_probe.gd
##
## A session from outside gets one step a call (CommandSocket._one_step,
## src/dev/claude_undo_probe.gd). The loop inside the app, asked in the
## assistant's panel, was reported to leave its work off the history, so the
## person's Undo after a Claude build took back their own last part, or
## nothing. Here the real app is asked as a person asks, in the panel, and the
## loop runs whole, its requests answered by a stand-in for Anthropic's API on
## this machine with replies written here: no key is spent and nothing leaves
## the machine. The person places a part, asks for a wall, and Undo must take
## the wall back and keep their part. A revision is a step of its own. And a
## part the person places while Claude works stays theirs: Undo takes back
## Claude's work, then theirs, each by itself.
extends SceneTree

var _failures: int = 0
var _world: BrickWorld
var _builder: Builder
var _api: _Api
var _main: Node
var _store: ModelStore
## What the run said as it went, shown when one does not end.
var _notes: PackedStringArray = []


## A stand-in for the Messages API: each POST answered with the next reply
## written here, and "Done." once they run out; a reply of {"status": 500}
## is that error. [member open_to] holds back the replies after it, so the
## probe can act while the loop waits.
class _Api extends Node:
	var replies: Array = []
	var asked: int = 0
	var open_to: int = 1 << 30
	var port: int = 0
	var _server := TCPServer.new()
	var _peers: Array = []

	func _init() -> void:
		for wanted: int in range(8851, 8930):
			if _server.listen(wanted, "127.0.0.1") == OK:
				port = wanted
				return

	func _process(_delta: float) -> void:
		while _server.is_connection_available():
			_peers.append([_server.take_connection(), PackedByteArray(), 0])
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
			if int(held[2]) == 0:
				asked += 1
				held[2] = asked
			if int(held[2]) > open_to:
				continue
			var reply: Dictionary = replies.pop_front() if not replies.is_empty() \
				else {"content": [{"type": "text", "text": "Done."}], "stop_reason": "end_turn"}
			var status: int = int(reply.get("status", 200))
			if status != 200:
				reply = {"type": "error", "error": {"type": "api_error", "message": "probe"}}
			var bytes: PackedByteArray = JSON.stringify(reply).to_utf8_buffer()
			peer.put_data(("HTTP/1.1 %d %s\r\nContent-Type: application/json\r\n" % [status,
				"OK" if status == 200 else "Error"] + "Content-Length: %d\r\nConnection: close\r\n\r\n"
				% bytes.size()).to_utf8_buffer())
			peer.put_data(bytes)
			peer.disconnect_from_host()
			_peers.erase(held)

	func _exit_tree() -> void:
		_server.stop()


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	_main = main
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	_world = main.get("_world")
	_builder = main.get("_builder")
	var assistant: Assistant = main.get("_assistant")
	var store: ModelStore = main.get("_store")
	_store = store
	var chat: ChatPanel = main.get("_chat")
	assistant.progress.connect(func(note: String) -> void: _notes.append(note))
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	store.scenery.clear()
	assistant.forget_built()
	assistant.forget_conversation()
	main.set("_sample_untouched", false)

	_api = _Api.new()
	root.add_child(_api)
	assistant.endpoint = "http://127.0.0.1:%d/v1/messages" % _api.port
	assistant.stream_replies = false
	# A key for this run only, written nowhere, and sent nowhere but the
	# stand-in above.
	OwnKey._this_visit = "sk-ant-probe-design-undo-000000000000000000000000000000"
	var ended: Array = []
	assistant.finished.connect(func(ok: bool, summary: String) -> void:
		ended.append([ok, summary]))

	print("\nthe person places a part, then asks Claude for a wall in the panel")
	var theirs: int = _place_by_hand(Vector3(40.0, 400.0, 40.0))
	_ok(theirs != 0 and _builder.history_depth() == 1,
		"the person's brick is down, one step to undo (%d)" % _builder.history_depth())
	var wall: Array = []
	for course: int in 4:
		for n: int in 3:
			wall.append({"part": "3010", "color": 0,
				"x": 4 * n + (2 if course % 2 else 0) + 20, "y": 3 * course, "z": 20, "rot": 0})
	_api.replies = [_reply([_tool("submit_design", {"name": "A wall",
		"description": "a black wall", "bricks": wall})])]
	await _ask(chat, "a small black wall", ended)
	_ok(not ended.is_empty() and bool(ended.back()[0]),
		"the run ends well: %s" % (str(ended.back()[1]) if not ended.is_empty() else "never"))
	# The loop's own passes may add to what was submitted.
	var designed: int = _parts()
	_ok(designed >= 1 + wall.size(), "the wall stands beside the person's brick (%d parts)"
		% designed)
	_ok(_builder.history_depth() == 2, "...as one step of its own (%d): %s" % [
		_builder.history_depth(), _newest()])
	_ok(_newest().begins_with("Claude's"), "...named as Claude's")
	_builder.undo()
	_ok(_parts() == 1 and _world.get_brick(theirs) != null,
		"Undo takes the wall back and keeps the person's brick (%d parts)" % _parts())
	_builder.redo()
	_ok(_parts() == designed, "...and Redo puts it up again (%d parts)" % _parts())

	print("\na revision is a step of its own")
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.id != theirs and not _store.scenery.has(brick.id):
			ids.append(brick.id)
	var depth: int = _builder.history_depth()
	var colours: Dictionary = _colours(ids)
	_api.replies = [_reply([_tool("edit_model", {"recolor": [{"bricks": ids, "color": 4}]})])]
	await _ask(chat, "make it red", ended)
	_ok(_colour_of(ids) == 4, "the wall is red (%d)" % _colour_of(ids))
	_ok(_builder.history_depth() == depth + 1 and _newest().begins_with("Claude's"),
		"...one more step, Claude's (%d to %d): %s" % [depth, _builder.history_depth(), _newest()])
	_builder.undo()
	_ok(_colours(ids) == colours and _parts() == designed,
		"Undo puts back the colours it had, the wall still up (%d parts)" % _parts())
	_builder.undo()
	_ok(_parts() == 1 and _world.get_brick(theirs) != null,
		"...and the next Undo takes the wall, and keeps the person's brick")
	_builder.undo()
	_ok(_parts() == 0, "...and the next, the person's brick")

	print("\na part the person places while Claude works stays theirs")
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_store.scenery.clear()
	assistant.forget_built()
	assistant.forget_conversation()
	theirs = _place_by_hand(Vector3(40.0, 400.0, 40.0))
	_api.replies = [_reply([_tool("submit_design", {"name": "A wall",
		"description": "a black wall", "bricks": wall})])]
	# The wall goes up with the first reply; the next request waits while
	# the person puts a part down.
	var first: int = _api.asked + 1
	_api.open_to = first
	var running: Signal = _ask(chat, "a small black wall", ended)
	var until: int = Time.get_ticks_msec() + 120000
	while _api.asked <= first and Time.get_ticks_msec() < until:
		await process_frame
	var meanwhile: int = _place_by_hand(Vector3(-120.0, 400.0, -120.0))
	_ok(meanwhile != 0 and _parts() >= 2 + wall.size(),
		"the person puts a part down while the wall is looked at (%d parts)" % _parts())
	_api.open_to = 1 << 30
	await running
	_ok(_builder.history_depth() == 3, "three steps: theirs, theirs, Claude's (%d): %s" % [
		_builder.history_depth(), ", ".join(_builder.history_words(3))])
	_builder.undo()
	_ok(_parts() == 2 and _world.get_brick(theirs) != null
		and _world.get_brick(meanwhile) != null,
		"Undo takes Claude's wall and keeps both of the person's parts (%d)" % _parts())
	_builder.undo()
	_ok(_parts() == 1 and _world.get_brick(meanwhile) == null,
		"...the next takes the part they put down meanwhile")
	_builder.undo()
	_ok(_parts() == 0, "...and the next, their first")

	# A design that fails puts the model back as it found it (restore_probe):
	# nothing changed is nothing to undo.
	print("\na request that fails and puts the model back makes no step")
	assistant.forget_conversation()
	theirs = _place_by_hand(Vector3(40.0, 400.0, 40.0))
	depth = _builder.history_depth()
	_api.replies = [_reply([_tool("submit_design", {"name": "A wall",
		"description": "a black wall", "bricks": wall})]), {"status": 500}]
	await _ask(chat, "a small black wall", ended)
	_ok(not ended.is_empty() and not bool(ended.back()[0]),
		"the run fails: %s" % (str(ended.back()[1]).left(60) if not ended.is_empty() else "never"))
	_ok(_parts() == 1 and _world.get_brick(theirs) != null,
		"...and the person's brick is all there is (%d parts)" % _parts())
	_ok(_builder.history_depth() == depth, "...and no step was made (%d): %s" % [
		_builder.history_depth(), _newest()])

	OwnKey._this_visit = ""
	print("")
	if _failures > 0:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	else:
		print("what Claude's design loop changes, Undo takes back, and only that")
	quit(1 if _failures > 0 else 0)


## Ask in the panel as a person does, and wait for the run to end. A signal
## to await, so a check can act while it runs.
func _ask(chat: ChatPanel, words: String, ended: Array) -> Signal:
	var was: int = ended.size()
	chat._input.text = words
	# A design, not three sketches to choose from first.
	chat._sketch_first.button_pressed = false
	_notes = []
	chat._on_send()
	if not chat.assistant.is_busy():
		print("  (the run did not start: %s)" % chat._status.text)
	var done := _Done.new()
	_wait_for(was, ended, done)
	return done.over


class _Done extends RefCounted:
	signal over


func _wait_for(was: int, ended: Array, done: _Done) -> void:
	var until: int = Time.get_ticks_msec() + 300000
	while ended.size() == was and Time.get_ticks_msec() < until:
		await process_frame
	if ended.size() == was:
		print("  (no end after %d requests: %s)" % [_api.asked, " / ".join(_notes.slice(-12))])
	var playback: BuildPlayback = _main.get("_playback")
	for _n: int in 10:
		await process_frame
	if playback != null:
		playback.stop()
	done.over.emit()


## The model's parts, not the plate under it.
func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


func _place_by_hand(at: Vector3) -> int:
	_builder.held_part = "3001"
	_builder.held_color = 4
	_builder.update_preview(at, Vector3.DOWN)
	return _builder.place()


func _newest() -> String:
	return _builder.history_words(1)[0] if _builder.history_depth() > 0 else ""


## Each brick's colour, by its number.
func _colours(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		out[brick_id] = brick.color_code if brick != null else -1
	return out


func _colour_of(ids: Array) -> int:
	var colours: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		colours[brick.color_code if brick != null else -1] = true
	return int(colours.keys()[0]) if colours.size() == 1 else -2


func _reply(content: Array) -> Dictionary:
	return {"content": content, "stop_reason": "tool_use"}


func _tool(name: String, input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "toolu_probe_%d" % randi(), "name": name, "input": input}


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
