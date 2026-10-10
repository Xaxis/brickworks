## Can Claude, as the client, build in a Brickworks tab through the relay?
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790 &
##   godot --headless --path . --script src/dev/connector_probe.gd -- 8790
##
## Drives both ends of the connector through the real relay code and the
## real queue: this app's connector answering as an open tab would, and
## this probe asking as Claude would — initialize, the tool list, a real
## tool call; a second page taking the address over; the tab asleep in the
## background, as it is while the person is in claude.ai; a call dropped by
## a sleeping tab and handed out again; and the page gone.
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

	# A file of its own, so the address this machine keeps is untouched.
	ClaudeConnector.where = "user://probe_connector_relay.json"
	if FileAccess.file_exists(ClaudeConnector.where):
		DirAccess.remove_absolute(ClaudeConnector.where)
	var connector := ClaudeConnector.new()
	get_root().add_child(connector)
	connector.base_url = _base
	connector.rpc = socket
	var calls: Array = []
	connector.called.connect(func(tool: String, _args: Dictionary) -> void:
		calls.append(tool))
	connector.start()
	var address: String = connector.address()
	_check(address.begins_with(_base + "/api/mcp?t=") and address.length() > 70,
		"the tab has a private address: %s…" % address.substr(0, 50))
	# Long enough for its hello and its first ask for work to reach the relay.
	await create_timer(3.0).timeout

	print("\nClaude, through the relay")
	var hello: Dictionary = await _claude(address, "initialize",
		{"protocolVersion": "2025-06-18", "capabilities": {},
			"clientInfo": {"name": "probe", "version": "1"}})
	var info: Dictionary = (hello.get("result", {}) as Dictionary)
	_check(str((info.get("serverInfo", {}) as Dictionary).get("name", "")) == "brickworks"
			and str(info.get("instructions", "")).length() > 1000,
		"initialize is answered with the app's design guidance")
	var listed: Dictionary = await _claude(address, "tools/list", {})
	var names: Array = []
	for tool: Variant in ((listed.get("result", {}) as Dictionary).get("tools", []) as Array):
		names.append(str((tool as Dictionary).get("name", "")))
	_check("submit_design" in names and "search_parts" in names
			and "clear_model" in names,
		"the tool list is the app's own: %d tools" % names.size())
	await create_timer(1.5).timeout
	_check(calls.has(""), "...and the tab hears that Claude has connected")
	var found: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick 2 x 4"}})
	var text: String = _text_of(found)
	_check(text.contains("3001") and not bool(
			(found.get("result", {}) as Dictionary).get("isError", true)),
		"a tool call is run in the tab and answered: %s" % text.substr(0, 60).replace("\n", " "))
	_check(calls.has("search_parts"), "...and the tab saw which tool it was")

	print("\nanother page switches the same address on")
	var replaced: Array = []
	connector.replaced.connect(func() -> void: replaced.append(true))
	var other := ClaudeConnector.new()
	get_root().add_child(other)
	other.base_url = _base
	other.rpc = socket
	_check(other.address() == address, "a second page load finds the same address")
	other.start()
	await create_timer(30.0).timeout
	_check(not replaced.is_empty() and not connector.is_on(),
		"the first lets go, told it was taken over")
	var again: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick 1 x 2"}})
	_check(_text_of(again).contains("3004"), "...and the newer one answers")

	print("\nthe tab asleep in the background")
	# A browser pauses a tab it is not showing; the page says so with a
	# beacon. Played here by sending what the page would.
	var instance: String = other._instance
	other.stop()
	await create_timer(1.0).timeout
	var token: String = address.get_slice("?t=", 1)
	var tab_url: String = "%s/api/mcp?t=%s&i=%s" % [_base, token, instance]
	# Back on, as a page whose engine is paused: hello, then nothing.
	await _post(tab_url + "&op=hello", JSON.stringify({"instructions": "x".repeat(1200),
		"tools": [{"name": "search_parts", "description": "", "inputSchema": {}}]}))
	await _post(tab_url + "&op=state&visible=0", "")
	var while_asleep: Dictionary = await _claude(address, "tools/list", {})
	_check(((while_asleep.get("result", {}) as Dictionary).get("tools", []) as Array).size() == 1,
		"the tool list is answered while the tab sleeps, from what it sent")
	var t0: int = Time.get_ticks_msec()
	var hidden: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick"}})
	_check(_text_of(hidden).contains("out of view")
			and Time.get_ticks_msec() - t0 > 15000,
		"a call to a tab out of view waits a little, then asks for it to be brought back")

	print("\na call taken just as the tab fell asleep")
	await _post(tab_url + "&op=state&visible=1", "")
	var pending: Dictionary = {}
	_claude_into(address, "tools/call",
		{"name": "plan_scale", "arguments": {"longest_metres": 150}}, pending)
	var first_take: Dictionary = await _take_call(tab_url)
	_check(str((first_take.get("request", {}) as Dictionary).get("method", "")) == "tools/call",
		"the sleeping tab takes the call, and drops it")
	await create_timer(2.5).timeout
	var second_take: Dictionary = await _take_call(tab_url)
	_check(int(second_take.get("id", -1)) == int(first_take.get("id", -2)),
		"waking and asking again, it is handed the same call")
	var request: Dictionary = second_take.get("request", {}) as Dictionary
	await _post(tab_url + "&op=answer&id=%d" % int(second_take.get("id", 0)),
		JSON.stringify(await socket.answer_rpc(request)))
	while pending.is_empty():
		await create_timer(0.3).timeout
	_check(_text_of(pending).contains("studs"), "...and Claude gets the answer")

	print("\nthe page goes")
	await _post(tab_url + "&op=close", "")
	var after: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick"}})
	_check(bool((after.get("result", {}) as Dictionary).get("isError", false))
			and _text_of(after).contains("not open"),
		"a call to a closed tab is told so at once, in words")
	var still: Dictionary = await _claude(address, "tools/list", {})
	_check(((still.get("result", {}) as Dictionary).get("tools", []) as Array).size() > 0,
		"...while Claude can still list the tools, to tell the person to open it")
	other.forget()
	_check(other.address().is_empty(), "Make a new address forgets the old one")
	ClaudeConnector.where = "user://claude_connector.json"

	print("")
	if _failures == 0:
		print("Claude can build in a tab through the connector")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## A POST as a tab would send it, awaited: the parsed body, or {}.
func _post(url: String, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 60.0
	get_root().add_child(http)
	http.request(url, PackedStringArray(["content-type: application/json"]),
		HTTPClient.METHOD_POST, body)
	var done: Array = await http.request_completed
	http.queue_free()
	var text: String = (done[3] as PackedByteArray).get_string_from_utf8()
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Asks for work as a tab does until it is handed a tool call, passing
## over the relay's notes that Claude has connected.
func _take_call(tab_url: String) -> Dictionary:
	for tries: int in 6:
		var got: Dictionary = await _post(tab_url + "&op=next", "")
		if str((got.get("request", {}) as Dictionary).get("method", "")) == "tools/call":
			return got
	return {}


## Claude's request, left running: the answer lands in [param into].
func _claude_into(address: String, method: String, params: Dictionary,
		into: Dictionary) -> void:
	var answer: Dictionary = await _claude(address, method, params)
	into.merge(answer if not answer.is_empty() else {"empty": true})


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
