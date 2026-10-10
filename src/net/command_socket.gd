## A way in for a session that is not the one inside the app.
##
## The app already holds a design loop: a model proposes placements, the
## real catalogue and the real collision lattice answer, and what holds
## together goes on the baseplate. All of that is reachable through
## [method Assistant.use_tool]. The only thing tying it to Anthropic is
## who is calling.
##
## So this listens on a local port and hands the same tools to whoever
## connects — in practice a Claude Code session, through
## [code]tools/brickworks_mcp.py[/code], which speaks MCP on its stdin
## and relays to here. A person with a session already open then builds
## in Brickworks without pasting an API key into it, and watches the
## bricks land in the window while they do.
##
## Deliberately small: one JSON object per line, in and out.
##
##   in   {"id": 7, "tool": "search_parts", "input": {"query": "wedge"}}
##   out  {"id": 7, "ok": true, "content": [{"type": "text", ...}]}
##   out  {"id": 7, "ok": false, "error": "..."}
##
## [code]{"tool": "__tools__"}[/code] answers with the tool list and
## [code]{"tool": "__about__"}[/code] with how to design well here, so
## the relay never carries a copy of either that could go stale.
##
## 127.0.0.1 only, and off unless asked for. An open port that drives the
## app is not something to have running by default, and binding the
## wildcard address would offer it to the network.
class_name CommandSocket
extends Node

## Where it listens when no port is given. Chosen high and odd enough to
## be nobody else's default; parallel sessions should pass their own.
const PORT := 8787

## A line longer than this is a client that is not speaking the protocol.
## Without a ceiling, a stray stream of bytes with no newline in it grows
## the buffer until the app dies.
const LONGEST_LINE := 1 << 22

## Raised when a client connects or leaves, so the window can say so.
signal attached(how_many: int)

## What a client asked for, for the status line. Not the answer: an
## answer can be a megabyte of PNG.
signal asked(tool: String)

var assistant: Assistant
## The app itself, for the two things only it can do.
var app: Node = null

## One connection, with everything about it in one place.
##
## Held as objects rather than as parallel arrays indexed by position.
## Position is not stable: a client that goes while another is mid-tool
## shifts every index after it, and the answer to the request in flight
## is then written to whoever moved into that slot — a picture of the
## model arriving on a connection that asked for a search, and nothing
## at all arriving on the one that is waiting.
class Client extends RefCounted:
	var peer: StreamPeerTCP
	var buffer := PackedByteArray()
	## Decided from the first bytes and never revisited: a line of JSON
	## begins with a brace, an HTTP request with a verb. One port serves
	## both, so a shipped app needs no helper process to be an MCP
	## server and the shell tools keep the protocol they had.
	var speaks_http: bool = false
	var decided: bool = false
	## True while a tool is still being awaited for this client. A tool
	## may take seconds — fetching geometry, drawing a picture — and a
	## second request arriving meanwhile must not be answered first.
	var busy: bool = false
	## Set when the connection has gone, so a tool that finishes after
	## that has something to check rather than writing into nothing.
	var gone: bool = false


var _server := TCPServer.new()
var _clients: Array[Client] = []
var _port := PORT

## One tool at a time, across every client.
##
## Each client already answers its own requests in order. That is not
## enough: a session may open several connections and send a call down
## each at the same moment — Claude Code does, three look_at_model in
## one breath — and the app is one app. One baseplate, one lattice, one
## thing that takes pictures. Two picture takers sharing a viewport
## interleave their waits and at least one never gets the frame it was
## waiting for, so its call sits there until the relay gives up three
## minutes later. That is not a hypothetical: a real design run of the
## USS Voyager reported "the renderer keeps timing out" and spent its
## last ten minutes unable to look at what it had built.
var _in_hand: int = 0
## How long a queued call will wait before saying so. The relay gives up
## at three minutes, and a message is better than its silence. A
## variable rather than a constant so that a probe can shorten it:
## waiting a hundred seconds to watch a deadline fire is not a check
## anybody will run.
var queued_for: float = 100.0


## Start listening. Returns false, and says why, when the port is taken —
## which on this machine usually means another session got there first.
func listen(port: int = PORT) -> bool:
	_port = port
	var error: Error = _server.listen(port, "127.0.0.1")
	if error != OK:
		push_error("command socket: port %d is not available (%s). " % [
			port, error_string(error)]
			+ "Another Brickworks is probably listening; pass --mcp=PORT.")
		return false
	print("command socket: listening on 127.0.0.1:%d" % port)
	return true


func stop() -> void:
	for client: Client in _clients:
		client.gone = true
		client.peer.disconnect_from_host()
	_clients.clear()
	_server.stop()


func port() -> int:
	return _port


func _process(_delta: float) -> void:
	if not _server.is_listening():
		return
	while _server.is_connection_available():
		var client := Client.new()
		client.peer = _server.take_connection()
		# Nagle's algorithm batches small writes, which for a protocol
		# of one small line per answer means the answer sits in a buffer
		# until something else is sent.
		client.peer.set_no_delay(true)
		_clients.append(client)
		attached.emit(_clients.size())
	for i in range(_clients.size() - 1, -1, -1):
		var client: Client = _clients[i]
		if not _pump(client):
			client.gone = true
			_clients.remove_at(i)
			attached.emit(_clients.size())


## Read what a client sent and answer any whole line in it. Returns
## false when the client has gone.
func _pump(client: Client) -> bool:
	client.peer.poll()
	if client.peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var waiting: int = client.peer.get_available_bytes()
	if waiting > 0:
		var got: Array = client.peer.get_data(waiting)
		if got[0] != OK:
			return false
		client.buffer.append_array(got[1])
	if client.buffer.size() > LONGEST_LINE:
		push_error("command socket: a client sent %d bytes with no newline"
			% client.buffer.size())
		return false
	# One at a time, in order. The rest of the buffer waits.
	if client.busy:
		return true

	if not client.decided and client.buffer.size() >= 4:
		var opening: String = client.buffer.slice(0, 8).get_string_from_utf8()
		client.speaks_http = (opening.begins_with("POST ")
			or opening.begins_with("GET ") or opening.begins_with("OPTIONS ")
			or opening.begins_with("HEAD ") or opening.begins_with("DELETE "))
		client.decided = true
	if client.speaks_http:
		return _pump_http(client)

	var newline: int = client.buffer.find(10)
	if newline < 0:
		return true
	var line: String = client.buffer.slice(0, newline).get_string_from_utf8()
	client.buffer = client.buffer.slice(newline + 1)
	if line.strip_edges().is_empty():
		return true
	client.busy = true
	_answer(client, line)
	return true


# -- MCP over HTTP -------------------------------------------------------
#
# The same tools, spoken the way an MCP client expects, so Claude Code
# attaches to the app directly:
#
#   claude --mcp-config '{"mcpServers":{"brickworks":
#     {"type":"http","url":"http://127.0.0.1:8787/mcp"}}}'
#
# One request, one response, no stream: every tool here answers once and
# nothing is ever pushed the other way, which is the shape the spec calls
# a plain JSON response rather than an event stream.


## A whole request, or nothing yet. Returns false when the client has gone.
func _pump_http(client: Client) -> bool:
	var text: String = client.buffer.get_string_from_utf8()
	var blank: int = text.find("\r\n\r\n")
	var gap: int = 4
	if blank < 0:
		blank = text.find("\n\n")
		gap = 2
	if blank < 0:
		return true
	var head: String = text.substr(0, blank)
	var wanted: int = 0
	for line: String in head.split("\n"):
		var at: String = line.strip_edges().to_lower()
		if at.begins_with("content-length:"):
			wanted = at.split(":")[1].strip_edges().to_int()
	var body_from: int = blank + gap
	var body: String = text.substr(body_from)
	if body.length() < wanted:
		return true
	client.buffer = PackedByteArray()
	client.busy = true
	_serve_http(client, head, body.substr(0, wanted))
	return true


func _serve_http(client: Client, head: String, body: String) -> void:
	var first: String = head.split("\n")[0].strip_edges()
	if first.begins_with("OPTIONS"):
		_http(client, 204, "")
		return
	if not first.begins_with("POST"):
		# A browser pointed at the port, or a health check.
		_http(client, 200, JSON.stringify({"app": "brickworks",
			"mcp": "post JSON-RPC here"}))
		return

	var parsed: Variant = JSON.parse_string(body)
	if not (parsed is Dictionary):
		_http(client, 400, JSON.stringify({"jsonrpc": "2.0", "id": null,
			"error": {"code": -32700, "message": "not JSON"}}))
		return
	var request: Dictionary = parsed
	var answer: Variant = await answer_rpc(request)
	if answer == null:
		# A notification has no id and wants no answer.
		_http(client, 202, "")
		return
	if client.gone:
		return
	_http(client, 200, JSON.stringify(answer))


## One JSON-RPC request answered, or null for a notification, which wants
## none. The desktop's HTTP port and the web's connector relay
## (src/net/claude_connector.gd) both come here, so the two cannot answer the
## protocol differently.
func answer_rpc(request: Dictionary) -> Variant:
	var method: String = str(request.get("method", ""))
	var sent_id: Variant = request.get("id")
	var params: Dictionary = request.get("params", {}) as Dictionary
	if sent_id == null:
		return null

	if method == "initialize":
		var wanted: Variant = params.get("protocolVersion")
		return _result(sent_id, {
			"protocolVersion": wanted if wanted is String else PROTOCOL,
			"capabilities": {"tools": {"listChanged": false}},
			"serverInfo": {"name": "brickworks", "version": "1"},
			"instructions": assistant.guidance() if assistant != null else "",
		})
	if method == "ping":
		return _result(sent_id, {})
	if method == "tools/list":
		var listed: Array = []
		if assistant != null:
			for tool: Variant in assistant.tool_catalogue() + _own_tools():
				var one: Dictionary = tool
				listed.append({
					"name": one.get("name", ""),
					"description": one.get("description", ""),
					"inputSchema": one.get("input_schema", {}),
				})
		return _result(sent_id, {"tools": listed})
	if method == "tools/call":
		var name: String = str(params.get("name", ""))
		var input: Dictionary = params.get("arguments", {}) as Dictionary
		if name.is_empty() or assistant == null:
			return _result(sent_id, {"isError": true, "content": [
				{"type": "text", "text": "no tool named"}]})
		asked.emit(name)
		var answer: Variant
		if _own_tools_have(name):
			answer = _run_own(name, input)
		else:
			if not await _take_a_turn():
				return _result(sent_id, {"isError": true, "content": [
					{"type": "text", "text": "Another call is still "
						+ "running — the app does one at a time. Send "
						+ "them one after another."}]})
			answer = await assistant.use_tool(name, input)
			_hand_back()
		return _result(sent_id, {"content": _as_content(answer),
			"isError": false})
	if method in ["resources/list", "prompts/list"]:
		return _result(sent_id, {"resources": [], "prompts": []})
	return {"jsonrpc": "2.0", "id": sent_id,
		"error": {"code": -32601, "message": "no method %s" % method}}


static func _result(sent_id: Variant, result: Dictionary) -> Dictionary:
	return {"jsonrpc": "2.0", "id": sent_id, "result": result}


func _http(client: Client, code: int, body: String) -> void:
	var reason: String = {200: "OK", 202: "Accepted", 204: "No Content",
		400: "Bad Request"}.get(code, "OK")
	var bytes: PackedByteArray = body.to_utf8_buffer()
	var head: String = ("HTTP/1.1 %d %s\r\n" % [code, reason]
		+ "Content-Type: application/json\r\n"
		+ "Content-Length: %d\r\n" % bytes.size()
		+ "Access-Control-Allow-Origin: *\r\n"
		+ "Access-Control-Allow-Headers: *\r\n"
		+ "Connection: keep-alive\r\n\r\n")
	if not client.gone:
		client.peer.put_data(head.to_utf8_buffer())
		if bytes.size() > 0:
			client.peer.put_data(bytes)
	client.busy = false


## The MCP version this speaks when a client does not name one.
const PROTOCOL := "2025-06-18"


# -- the line protocol ---------------------------------------------------


func _answer(client: Client, line: String) -> void:
	var asked_for: Variant = JSON.parse_string(line)
	if not (asked_for is Dictionary):
		_reply(client, -1, false, "that line is not a JSON object")
		return
	var request: Dictionary = asked_for
	var id: int = int(request.get("id", -1))
	var tool: String = str(request.get("tool", ""))
	var input: Dictionary = request.get("input", {}) as Dictionary

	if tool == "__tools__":
		if assistant == null:
			_reply(client, id, false, "the app has no assistant")
			return
		_send(client, {"id": id, "ok": true,
			"tools": assistant.tool_catalogue() + _own_tools()})
		return
	if tool == "__about__":
		if assistant == null:
			_reply(client, id, false, "the app has no assistant")
			return
		_send(client, {"id": id, "ok": true,
			"instructions": assistant.guidance()})
		return
	if tool == "__ping__":
		_send(client, {"id": id, "ok": true, "app": "brickworks",
			"port": _port, "clients": _clients.size()})
		return
	if assistant == null:
		_reply(client, id, false, "the app has no assistant")
		return
	if tool.is_empty():
		_reply(client, id, false, "no tool named")
		return

	asked.emit(tool)
	if _own_tools_have(tool):
		_send(client, {"id": id, "ok": true,
			"content": _as_content(_run_own(tool, input))})
		return
	if not await _take_a_turn():
		_reply(client, id, false, "another call is still running — the "
			+ "app does one at a time. Send them one after another.")
		return
	var answer: Variant = await assistant.use_tool(tool, input)
	_hand_back()
	# The client may have gone while a tool was drawing a picture.
	if client.gone:
		return
	_send(client, {"id": id, "ok": true, "content": _as_content(answer)})


## Wait until no other tool is running, then take the app.
##
## Returns false if the wait ran out, in which case nothing was taken
## and the caller must answer rather than carry on.
##
## Measured in seconds and not in frames. A headless app runs frames in
## microseconds, so a frame count is no wait at all there and a long one
## in a window — the same mistake cost a day on the reference finder.
func _take_a_turn() -> bool:
	if _in_hand == 0:
		_in_hand += 1
		return true
	var until: float = Time.get_unix_time_from_system() + queued_for
	# Frames, not the signal. Waiting on _handed_back alone looks
	# tidier and silently drops the deadline: if whoever holds the app
	# never finishes, the signal never comes, the line above is never
	# reached again and the queue waits for ever — which is the hang
	# this was written to stop, moved one layer down. A frame always
	# comes.
	while _in_hand > 0:
		if Time.get_unix_time_from_system() > until:
			return false
		await get_tree().process_frame
	_in_hand += 1
	return true


func _hand_back() -> void:
	_in_hand = maxi(0, _in_hand - 1)


## Tools an outside session needs and the design loop does not.
##
## The loop clears the baseplate itself when a design begins, and never
## saves — the person does that from the window. A session driving from
## outside has neither moment, so without these it would build into
## whatever was already standing and leave no file behind.
func _own_tools() -> Array:
	return [
		{
			"name": "review_model",
			"description": ("Look a built model over the way Brickworks' own "
				+ "designer does after a design stands: with no assembly, the "
				+ "whole model measured against real LEGO sets of its size and "
				+ "kind — shapes, colours, the one-off pieces, how coarse — and "
				+ "what to check it for; with an assembly named in "
				+ "submit_design, that one close up, measured, with the parts "
				+ "real sets of the kind use that it has none of. Call it after "
				+ "submit_design, then once per assembly, detailing each with "
				+ "edit_model before the next."),
			"input_schema": {
				"type": "object",
				"properties": {
					"assembly": {"type": "string", "description":
						"an assembly's name as given in submit_design; omit "
						+ "for the whole model"},
				},
				"additionalProperties": false,
			},
		},
		{
			"name": "clear_model",
			"description": ("Take everything off the baseplate and start "
				+ "from bare ground. Do this before building something "
				+ "new, or the new thing is built into the old one."),
			"input_schema": {
				"type": "object", "properties": {},
				"additionalProperties": false,
			},
		},
		{
			"name": "save_model",
			"description": ("Write what is on the baseplate to an LDraw "
				+ ".ldr file, which this app and other LDraw tools can "
				+ "both open."),
			"input_schema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description":
						"where to write it, ending .ldr"},
				},
				"required": ["path"],
				"additionalProperties": false,
			},
		},
	]


## Every tool name this port serves, the assistant's and its own.
##
## Used to tell Claude Code what it may call: a headless session is
## allowed exactly these and nothing else, so it cannot read or write a
## file, and a design run has no reason to.
func tool_names() -> PackedStringArray:
	var names := PackedStringArray()
	if assistant != null:
		for tool: Variant in assistant.tool_catalogue():
			names.append(str((tool as Dictionary).get("name", "")))
	for tool: Variant in _own_tools():
		names.append(str((tool as Dictionary).get("name", "")))
	return names


func _own_tools_have(tool: String) -> bool:
	return tool in ["clear_model", "save_model", "review_model"]


func _run_own(tool: String, input: Dictionary) -> String:
	if tool == "review_model" and assistant != null:
		return assistant.review(str(input.get("assembly", "")))
	if app == null:
		return "This app cannot do that from outside."
	match tool:
		"clear_model":
			app.clear_model()
			return "The baseplate is bare."
		"save_model":
			var path: String = str(input.get("path", ""))
			if path.is_empty():
				return "No path given."
			if not app.save_model(path):
				return "Could not write %s." % path
			return "Written to %s." % path
	return "No tool called %s." % tool


## What a tool handed back, as content blocks.
##
## Tools answer with a String, or with the array of blocks Anthropic
## accepts in a tool result — which carries a picture as
## [code]{"type": "image", "source": {"data": ...}}[/code]. MCP wants
## [code]{"type": "image", "data": ..., "mimeType": ...}[/code], so the
## shapes are translated here rather than in the relay: the relay should
## not have to know how this app happens to talk to Anthropic.
func _as_content(answer: Variant) -> Array:
	if answer is String:
		return [{"type": "text", "text": answer}]
	if not (answer is Array):
		return [{"type": "text", "text": str(answer)}]
	var blocks: Array = []
	for block: Variant in answer as Array:
		if not (block is Dictionary):
			blocks.append({"type": "text", "text": str(block)})
			continue
		var one: Dictionary = block
		if str(one.get("type", "")) == "image":
			var source: Dictionary = one.get("source", {}) as Dictionary
			blocks.append({
				"type": "image",
				"data": str(source.get("data", "")),
				"mimeType": str(source.get("media_type", "image/png")),
			})
		else:
			blocks.append({"type": "text", "text": str(one.get("text", ""))})
	return blocks


func _reply(client: Client, id: int, ok: bool, message: String) -> void:
	_send(client, {"id": id, "ok": ok, "error": message})


func _send(client: Client, answer: Dictionary) -> void:
	if not client.gone:
		var line: PackedByteArray = (
			JSON.stringify(answer) + "\n").to_utf8_buffer()
		# Said, not swallowed. A client that cannot be written to is one
		# whose request is never answered, and the only sign of it from
		# the other end is a session that waits for three minutes.
		var sent: Error = client.peer.put_data(line)
		if sent != OK:
			push_error("command socket: could not answer (%s)"
				% error_string(sent))
	client.busy = false
