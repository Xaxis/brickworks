## Can a session outside the app build in it?
##
##   godot --headless --path . --script src/dev/mcp_probe.gd
##
## The whole point of the command socket is that something which is not
## the design loop can use the design loop's tools. So this is the app
## talking to itself over a real TCP connection: the socket is opened for
## real, a client connects to 127.0.0.1 for real, and the answers come
## back as the relay will see them.
##
## What it does not cover: the MCP wrapping, which is
## tools/brickworks_mcp.py's half, which tools/mcp_check.py drives.
extends SceneTree

var _failures: int = 0
var _world: BrickWorld
var _socket: CommandSocket
var _client := StreamPeerTCP.new()
var _next_id: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	# The catalogue load, and then the opening animation, which places
	# bricks of its own and would be counted below.
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	_world = main.get("_world")
	var assistant: Assistant = main.get("_assistant")
	# From a bare baseplate, so the counts below are this probe's doing.
	_world.clear()
	var builder: Builder = main.get("_builder")
	builder.lattice.clear()
	var store: ModelStore = main.get("_store")
	store.scenery.clear()
	assistant.forget_built()
	await process_frame

	# A port of its own, so this can run beside an app with --mcp open.
	_socket = CommandSocket.new()
	_socket.assistant = assistant
	main.add_child(_socket)
	var port: int = 8791
	if not _socket.listen(port):
		_check("the socket listens on %d" % port, false)
		_done()
		return
	_check("the socket is listening", true)

	var error: Error = _client.connect_to_host("127.0.0.1", port)
	_check("a client can connect", error == OK)
	for _n: int in 120:
		_client.poll()
		if _client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		await process_frame
	_check("...and the connection comes up",
		_client.get_status() == StreamPeerTCP.STATUS_CONNECTED)

	# How to design well here, served rather than written down twice.
	var about: Dictionary = await _ask("__about__", {})
	var guidance: String = str(about.get("instructions", ""))
	_check("the socket serves the app's design guidance, %d characters"
		% guidance.length(), guidance.length() > 3000)
	_check("...and it is the same words the design loop is given",
		guidance.contains("COORDINATES") and guidance.contains("AT AN ANGLE"))

	# The tools, which the relay serves rather than carrying its own copy.
	var tools: Dictionary = await _ask("__tools__", {})
	var names: Array = []
	for tool: Variant in tools.get("tools", []):
		names.append(str((tool as Dictionary).get("name", "")))
	_check("the socket serves the tool list, %d tools" % names.size(),
		names.size() >= 7)
	for wanted: String in ["search_parts", "check_design", "look_at_model",
			"view_model", "submit_design", "edit_model",
			"attachment_points"]:
		_check("  %s is offered" % wanted, names.has(wanted))
	# Every tool must carry a schema, or a client has nothing to call it
	# with. A name alone reads as a working tool and fails on first use.
	var schemaless: Array = []
	for tool: Variant in tools.get("tools", []):
		var one: Dictionary = tool
		var schema: Dictionary = one.get("input_schema", {}) as Dictionary
		if schema.is_empty() or not schema.has("properties"):
			schemaless.append(one.get("name", "?"))
	_check("every tool carries an input schema, %d without"
		% schemaless.size(), schemaless.is_empty())

	# A real search, through the real catalogue.
	var found: Dictionary = await _ask("search_parts",
		{"query": "wedge", "limit": 5})
	_check("a search answers", bool(found.get("ok", false)))
	var text: String = _text_of(found)
	_check("...with part numbers in it, %d characters" % text.length(),
		text.length() > 20 and text.contains("."))

	# And a design, which has to land on the baseplate — the step the
	# design loop does after submit_design and nothing else would.
	var before: int = _world.brick_count()
	var built: Dictionary = await _ask("submit_design", {
		"bricks": [
			{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0},
			{"part": "3001", "color": 14, "x": 0, "y": 6, "z": 0, "rot": 0},
		],
	})
	_check("a submitted design answers", bool(built.get("ok", false)))
	var said: String = _text_of(built)
	_check("...and says it was built: %s" % said.substr(0, 60),
		said.begins_with("Built."))
	_check("...and the bricks are in the world, %d more"
		% (_world.brick_count() - before),
		_world.brick_count() - before == 3)

	# A design that cannot stand must come back as a refusal, not as a
	# silent success — this is the whole reason the app holds the lattice.
	var floating: Dictionary = await _ask("submit_design", {
		"bricks": [
			{"part": "3001", "color": 4, "x": 40, "y": 30, "z": 40, "rot": 0},
		],
	})
	_check("a design that cannot stand is refused",
		_text_of(floating).begins_with("Not applied"))

	# Checking a design has to come back with something to read.
	#
	# It did not, and nothing here noticed: every tool that answers with
	# a picture went through a guard meant for a cancelled design run —
	# "if not _busy, say nothing" — and a session driving from outside is
	# never busy. check_design, view_model and edit_model all answered
	# with an empty string. Three of the nine tools, silent, and the only
	# way it surfaced was somebody trying to build with them.
	var checked: Dictionary = await _ask("check_design", {
		"bricks": [
			{"part": "3031", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3031", "color": 71, "x": 4, "y": 0, "z": 0, "rot": 0},
		],
	})
	var verdict: String = _text_of(checked)
	_check("checking a design says something, %d characters"
		% verdict.length(), verdict.length() > 20)

	# A look at the model, which comes back as a picture in a headless
	# run only if there is something to draw with — so here it is enough
	# that the tool answers rather than hangs.
	var looked: Dictionary = await _ask("look_at_model", {})
	_check("the model can be read back", bool(looked.get("ok", false))
		and not _text_of(looked).is_empty())

	# An answer has to reach the client that asked for it, even when
	# another one leaves while it is being worked out.
	#
	# Clients used to be parallel arrays indexed by position, and a
	# client leaving shifted every index after it. A request already in
	# flight then had its answer written to whoever moved into its slot:
	# a picture arriving on a connection that asked for a search, and
	# nothing at all on the one that was waiting. It cost three minutes
	# of waiting and a timeout to notice, with the app running fine.
	# Two more, in order: the one that leaves has to be the *earlier* of
	# them, because what shifts is every index after the one removed.
	var leaver: StreamPeerTCP = await _another(port)
	var waiting: StreamPeerTCP = await _another(port)
	_check("two more clients can connect",
		leaver.get_status() == StreamPeerTCP.STATUS_CONNECTED
		and waiting.get_status() == StreamPeerTCP.STATUS_CONNECTED)
	# Big enough that it is certainly still being checked when the other
	# client goes. With two bricks it finished first and the race the
	# check exists for never happened.
	var slab: Array = []
	for x: int in 16:
		for z: int in 16:
			slab.append({"part": "3024", "color": 71,
				"x": x, "y": 0, "z": z, "rot": 0})
	var mine: int = 4242
	waiting.put_data((JSON.stringify({"id": mine, "tool": "check_design",
		"input": {"bricks": slab}}) + "\n").to_utf8_buffer())
	# Gone while that tool is still running, from in front of it — and
	# waited for, so the list has really shifted before the answer is due.
	await process_frame
	leaver.disconnect_from_host()
	for _n: int in 600:
		await process_frame
		if _socket._clients.size() <= 2:
			break
	_check("the client in front of it has really gone, %d left"
		% _socket._clients.size(), _socket._clients.size() == 2)
	var still: Dictionary = await _read_from(waiting)
	_check("...and an answer reaches the client that asked for it, id %d"
		% int(still.get("id", -1)), int(still.get("id", -1)) == mine)
	_check("...with its content intact", not _text_of(still).is_empty())
	waiting.disconnect_from_host()

	await _one_at_a_time(port)

	# An unknown tool is an answer, not a dropped connection.
	var nonsense: Dictionary = await _ask("no_such_tool", {})
	_check("an unknown tool is answered, not dropped",
		_text_of(nonsense).contains("No tool called"))

	_client.disconnect_from_host()
	_socket.stop()
	_done()


## Does the app do one call at a time?
##
## It has to. A session may open several connections and send a call
## down each in the same breath — Claude Code does — and there is one
## baseplate, one lattice and one thing that takes pictures here. Two
## picture takers sharing a viewport interleave their waits and at least
## one never gets the frame it is waiting for; the call then sits until
## the relay gives up three minutes later. A real design run of the USS
## Voyager said so out loud: "the renderer keeps timing out", and it
## spent its last ten minutes unable to look at what it had built.
##
## Checked on the turnstile itself rather than by racing three clients,
## because a race that passes tells you nothing about the next run.
func _one_at_a_time(port: int) -> void:
	print("")
	print("  one call at a time")
	var first: bool = await _socket._take_a_turn()
	_check("the first call takes the app", first)

	# A second one waits. Watched through a flag, because what is being
	# checked is that the coroutine has *not* finished.
	var second: Dictionary = {"through": false}
	_waiting_turn(second)
	for _n: int in 20:
		await process_frame
	_check("a second call waits its turn", not bool(second["through"]))

	_socket._hand_back()
	for _n: int in 20:
		await process_frame
	_check("...and goes through when the first is done",
		bool(second["through"]))
	_socket._hand_back()
	_check("the app is free again", _socket._in_hand == 0)

	# And a wait that never ends gives up and says so, rather than
	# joining the queue for ever. The first version waited on a signal
	# alone, which reads as a deadline and is not one: if whoever holds
	# the app never finishes, the signal never comes and the line that
	# checks the clock is never reached.
	_socket.queued_for = 1.0
	await _socket._take_a_turn()
	var stuck: Dictionary = {"through": false, "got": true}
	_gave_up(stuck)
	var waited: float = Time.get_unix_time_from_system()
	for _n: int in 400:
		await process_frame
		if bool(stuck["through"]):
			break
	var how_long: float = Time.get_unix_time_from_system() - waited
	if not bool(stuck["through"]):
		_failures += 1
		print("  FAIL  a call behind one that never finishes waited for "
			+ "ever instead of giving up")
	elif bool(stuck["got"]):
		_failures += 1
		print("  FAIL  it gave up and took the app anyway")
	else:
		print("  ok    ...and one behind a call that never finishes "
			+ "gives up after %.1f s and says so" % how_long)
	_socket._hand_back()
	_socket._hand_back()
	_socket.queued_for = 100.0

	# And end to end: three clients, three calls sent in the same frame,
	# three answers, each to the client that asked.
	var peers: Array[StreamPeerTCP] = []
	for _n: int in 3:
		peers.append(await _another(port))
	var ids: Array[int] = []
	for n: int in peers.size():
		_next_id += 1
		ids.append(_next_id)
		peers[n].put_data(JSON.stringify({"id": _next_id,
			"tool": "look_at_model", "input": {}}).to_utf8_buffer()
			+ "\n".to_utf8_buffer())
	var answered: int = 0
	for n: int in peers.size():
		var back: Dictionary = await _read_from(peers[n])
		if int(back.get("id", -1)) == ids[n] and not _text_of(back).is_empty():
			answered += 1
		peers[n].disconnect_from_host()
	_check("three clients asking at once all get their own answer, %d of 3"
		% answered, answered == 3)


## Take a turn in the background, and say so when it comes.
func _waiting_turn(flag: Dictionary) -> void:
	await _socket._take_a_turn()
	flag["through"] = true


## Wait for a turn that will not come, and record how it ended.
func _gave_up(flag: Dictionary) -> void:
	flag["got"] = await _socket._take_a_turn()
	flag["through"] = true


## One request, and the line that comes back.
func _ask(tool: String, input: Dictionary) -> Dictionary:
	_next_id += 1
	var line: String = JSON.stringify(
		{"id": _next_id, "tool": tool, "input": input}) + "\n"
	_client.put_data(line.to_utf8_buffer())
	return await _read()


## One more client, connected.
func _another(port: int) -> StreamPeerTCP:
	var peer := StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", port)
	for _n: int in 120:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		await process_frame
	return peer


## The next whole line from this probe's own client.
func _read() -> Dictionary:
	return await _read_from(_client)


## The next whole line from any client.
func _read_from(peer: StreamPeerTCP) -> Dictionary:
	var buffer := PackedByteArray()
	# Generous: a tool may fetch geometry over the wire before answering.
	for _n: int in 7200:
		peer.poll()
		var ready: int = peer.get_available_bytes()
		if ready > 0:
			var got: Array = peer.get_data(ready)
			if got[0] == OK:
				buffer.append_array(got[1])
		var newline: int = buffer.find(10)
		if newline >= 0:
			var answer: Variant = JSON.parse_string(
				buffer.slice(0, newline).get_string_from_utf8())
			return answer as Dictionary if answer is Dictionary else {}
		await process_frame
	return {}


## The text in an answer, with any picture left out.
func _text_of(answer: Dictionary) -> String:
	if answer.has("error"):
		return str(answer["error"])
	var said: String = ""
	for block: Variant in answer.get("content", []):
		var one: Dictionary = block
		if str(one.get("type", "")) == "text":
			said += str(one.get("text", ""))
	return said


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("a session outside the app can use the app's own tools")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
