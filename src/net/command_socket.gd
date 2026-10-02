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
## [code]{"tool": "__tools__"}[/code] answers with the tool list, so the
## relay never carries a copy of the schemas that could go stale.
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

var _server := TCPServer.new()
var _clients: Array[StreamPeerTCP] = []
var _buffers: Array[PackedByteArray] = []
## Clients whose current request is still being answered. A tool may
## await — fetching geometry, drawing a picture — and a second request
## arriving meanwhile must not be answered out of order.
var _busy: Array[bool] = []
var _port := PORT


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
	for client: StreamPeerTCP in _clients:
		client.disconnect_from_host()
	_clients.clear()
	_buffers.clear()
	_busy.clear()
	_server.stop()


func port() -> int:
	return _port


func _process(_delta: float) -> void:
	if not _server.is_listening():
		return
	while _server.is_connection_available():
		var client: StreamPeerTCP = _server.take_connection()
		# Nagle's algorithm batches small writes, which for a protocol
		# of one small line per answer means the answer sits in a buffer
		# until something else is sent.
		client.set_no_delay(true)
		_clients.append(client)
		_buffers.append(PackedByteArray())
		_busy.append(false)
		attached.emit(_clients.size())
	for i in range(_clients.size() - 1, -1, -1):
		if not _pump(i):
			_clients.remove_at(i)
			_buffers.remove_at(i)
			_busy.remove_at(i)
			attached.emit(_clients.size())


## Read what a client sent and answer any whole line in it. Returns
## false when the client has gone.
func _pump(i: int) -> bool:
	var client: StreamPeerTCP = _clients[i]
	client.poll()
	if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var waiting: int = client.get_available_bytes()
	if waiting > 0:
		var got: Array = client.get_data(waiting)
		if got[0] != OK:
			return false
		_buffers[i].append_array(got[1])
	if _buffers[i].size() > LONGEST_LINE:
		push_error("command socket: a client sent %d bytes with no newline"
			% _buffers[i].size())
		return false
	# One at a time, in order. The rest of the buffer waits.
	if _busy[i]:
		return true
	var newline: int = _buffers[i].find(10)
	if newline < 0:
		return true
	var line: String = _buffers[i].slice(0, newline).get_string_from_utf8()
	_buffers[i] = _buffers[i].slice(newline + 1)
	if line.strip_edges().is_empty():
		return true
	_busy[i] = true
	_answer(i, line)
	return true


func _answer(i: int, line: String) -> void:
	var asked_for: Variant = JSON.parse_string(line)
	if not (asked_for is Dictionary):
		_reply(i, -1, false, "that line is not a JSON object")
		return
	var request: Dictionary = asked_for
	var id: int = int(request.get("id", -1))
	var tool: String = str(request.get("tool", ""))
	var input: Dictionary = request.get("input", {}) as Dictionary

	if tool == "__tools__":
		if assistant == null:
			_reply(i, id, false, "the app has no assistant")
			return
		_send(i, {"id": id, "ok": true,
			"tools": assistant.tool_catalogue() + _own_tools()})
		return
	if tool == "__ping__":
		_send(i, {"id": id, "ok": true, "app": "brickworks",
			"port": _port, "clients": _clients.size()})
		return
	if assistant == null:
		_reply(i, id, false, "the app has no assistant")
		return
	if tool.is_empty():
		_reply(i, id, false, "no tool named")
		return

	asked.emit(tool)
	if _own_tools_have(tool):
		_send(i, {"id": id, "ok": true,
			"content": _as_content(_run_own(tool, input))})
		return
	var answer: Variant = await assistant.use_tool(tool, input)
	# The client may have gone while a tool was drawing a picture.
	if i >= _clients.size():
		return
	_send(i, {"id": id, "ok": true, "content": _as_content(answer)})


## Tools an outside session needs and the design loop does not.
##
## The loop clears the baseplate itself when a design begins, and never
## saves — the person does that from the window. A session driving from
## outside has neither moment, so without these it would build into
## whatever was already standing and leave no file behind.
func _own_tools() -> Array:
	return [
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


func _own_tools_have(tool: String) -> bool:
	return tool in ["clear_model", "save_model"]


func _run_own(tool: String, input: Dictionary) -> String:
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


func _reply(i: int, id: int, ok: bool, message: String) -> void:
	_send(i, {"id": id, "ok": ok, "error": message})


func _send(i: int, answer: Dictionary) -> void:
	if i < _clients.size():
		var line: PackedByteArray = (JSON.stringify(answer) + "\n").to_utf8_buffer()
		_clients[i].put_data(line)
	if i < _busy.size():
		_busy[i] = false
