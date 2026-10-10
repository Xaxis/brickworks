## Can Claude, as the client, build in a Brickworks tab through the relay?
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790 &
##   godot --headless --path . --script src/dev/connector_probe.gd -- 8790
##
## Drives both ends of the connector through the real relay code and the
## real queue: this app's Connector answering as an open tab would, and
## this probe asking as Claude would — initialize, the tool list, a real
## tool call — then the tab switched off and the same call asked again.
##
## Not in the suite: it needs the relay running and the queue's key.
extends SceneTree

var _failures: int = 0
var _base: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_base = "http://127.0.0.1:%s" % (args[0] if not args.is_empty() else "8790")
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	var socket := CommandSocket.new()
	socket.assistant = assistant
	get_root().add_child(socket)

	var connector := ClaudeConnector.new()
	get_root().add_child(connector)
	connector.base_url = _base
	connector.rpc = socket
	var calls: Array = []
	connector.called.connect(func(tool: String) -> void: calls.append(tool))
	connector.start()
	var address: String = connector.address()
	_check(address.begins_with(_base + "/api/mcp?t=") and address.length() > 70,
		"the tab has a private address: %s…" % address.substr(0, 50))
	# Long enough for its first ask for work to reach the relay.
	await create_timer(2.0).timeout

	print("\nClaude, through the relay")
	var hello: Dictionary = await _claude(address, "initialize",
		{"protocolVersion": "2025-06-18", "capabilities": {},
			"clientInfo": {"name": "probe", "version": "1"}})
	var info: Dictionary = (hello.get("result", {}) as Dictionary)
	_check(str((info.get("serverInfo", {}) as Dictionary).get("name", "")) == "brickworks"
			and str(info.get("instructions", "")).length() > 1000,
		"initialize is answered by the tab, with the app's design guidance")
	var listed: Dictionary = await _claude(address, "tools/list", {})
	var names: Array = []
	for tool: Variant in ((listed.get("result", {}) as Dictionary).get("tools", []) as Array):
		names.append(str((tool as Dictionary).get("name", "")))
	_check("submit_design" in names and "search_parts" in names
			and "clear_model" in names,
		"the tool list is the app's own: %d tools" % names.size())
	var found: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick 2 x 4"}})
	var text: String = _text_of(found)
	_check(text.contains("3001") and not bool(
			(found.get("result", {}) as Dictionary).get("isError", true)),
		"a tool call is run in the tab and answered: %s" % text.substr(0, 60).replace("\n", " "))
	_check(calls.has("search_parts"), "...and the tab saw which tool it was")

	print("\nthe tab switched off")
	connector.stop()
	await create_timer(1.0).timeout
	var after: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick"}})
	_check(bool((after.get("result", {}) as Dictionary).get("isError", false))
			and _text_of(after).contains("not open"),
		"a call to a closed tab is told so at once, in words")
	_check(connector.address().is_empty(), "...and the old address is forgotten")

	print("")
	if _failures == 0:
		print("Claude can build in a tab through the connector")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


var _sent: int = 0


func _claude(address: String, method: String, params: Dictionary) -> Dictionary:
	_sent += 1
	var http := HTTPRequest.new()
	http.timeout = 60.0
	get_root().add_child(http)
	http.request(address, PackedStringArray(["content-type: application/json",
		"accept: application/json, text/event-stream"]), HTTPClient.METHOD_POST,
		JSON.stringify({"jsonrpc": "2.0", "id": _sent, "method": method,
			"params": params}))
	var done: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((done[3] as PackedByteArray)
		.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


func _text_of(answer: Dictionary) -> String:
	var text := PackedStringArray()
	for block: Variant in ((answer.get("result", {}) as Dictionary).get("content", []) as Array):
		text.append(str((block as Dictionary).get("text", "")))
	return "\n".join(text)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)
