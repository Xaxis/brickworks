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

	# A look at the model, which comes back as a picture in a headless
	# run only if there is something to draw with — so here it is enough
	# that the tool answers rather than hangs.
	var looked: Dictionary = await _ask("look_at_model", {})
	_check("the model can be read back", bool(looked.get("ok", false))
		and not _text_of(looked).is_empty())

	# An unknown tool is an answer, not a dropped connection.
	var nonsense: Dictionary = await _ask("no_such_tool", {})
	_check("an unknown tool is answered, not dropped",
		_text_of(nonsense).contains("No tool called"))

	_client.disconnect_from_host()
	_socket.stop()
	_done()


## One request, and the line that comes back.
func _ask(tool: String, input: Dictionary) -> Dictionary:
	_next_id += 1
	var line: String = JSON.stringify(
		{"id": _next_id, "tool": tool, "input": input}) + "\n"
	_client.put_data(line.to_utf8_buffer())
	var buffer := PackedByteArray()
	# Generous: a tool may fetch geometry over the wire before answering.
	for _n: int in 7200:
		_client.poll()
		var waiting: int = _client.get_available_bytes()
		if waiting > 0:
			var got: Array = _client.get_data(waiting)
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
