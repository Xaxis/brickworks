## This tab, offered to Claude as a connector.
##
## Someone on a Claude plan who wants to design without an API key turns
## this on, and gets a private address to add to Claude: claude.ai or the
## Claude app as a custom connector, or Claude Code with `claude mcp add
## --transport http`. Claude, signed in their own way on their own plan,
## then calls this app's tools while they talk to it; this tab answers each
## call and the model is built here, where they can watch it.
##
## The address goes to api/mcp.js, which queues Claude's requests until
## this tab asks for them, and hands the answers back. The answers come
## from [method CommandSocket.answer_rpc] — the code that serves the
## desktop's MCP port — so a tool works the same over either.
##
## The token in the address is the only credential and is made here, at
## random, for this tab. It is never shown in full anywhere but the box the
## person copies it from, and turning the connector off forgets it: the
## next address is a new one.
class_name ClaudeConnector
extends Node

## Where the relay is. The site the page came from on the web; the live
## site from the desktop.
var base_url: String = "https://brickworks.diy"
## Answers the requests. Needs its assistant and app set.
var rpc: CommandSocket

## Listening for Claude, or not; and the address to give it while it is.
signal listening(on: bool, address: String)
## Claude asked for something, by tool name, or "" for the protocol's own
## requests; and it was answered.
signal called(tool: String)
signal answered(tool: String)
## The relay could not be reached, in words.
signal trouble(why: String)

var _token: String = ""
var _on: bool = false
var _http: HTTPRequest
var _reply: HTTPRequest


func _ready() -> void:
	if OS.has_feature("web"):
		var here: Variant = JavaScriptBridge.eval("location.origin", true)
		if typeof(here) == TYPE_STRING and str(here).begins_with("http"):
			base_url = str(here)
	_http = HTTPRequest.new()
	# The relay holds a request for work for 25 s; wait a little longer.
	_http.timeout = 40.0
	add_child(_http)
	_reply = HTTPRequest.new()
	_reply.timeout = 30.0
	add_child(_reply)


func is_on() -> bool:
	return _on


## The address to add to Claude, or "" while off.
func address() -> String:
	return "" if _token.is_empty() else "%s/api/mcp?t=%s" % [base_url, _token]


## Start listening, with a new address.
func start() -> void:
	if _on:
		return
	_token = _new_token()
	_on = true
	listening.emit(true, address())
	_listen()


## Stop, and forget the address: anyone who had it can no longer reach
## this tab.
func stop() -> void:
	if not _on:
		return
	_on = false
	var was: String = _token
	_token = ""
	_http.cancel_request()
	listening.emit(false, "")
	# Told so the relay can say "not open" at once, rather than after the
	# tab has been silent long enough to count as gone.
	var bye := HTTPRequest.new()
	add_child(bye)
	bye.request_completed.connect(func(_a: int, _b: int,
			_c: PackedStringArray, _d: PackedByteArray) -> void:
		bye.queue_free())
	bye.request("%s/api/mcp?t=%s&op=close" % [base_url, was],
		PackedStringArray(), HTTPClient.METHOD_POST, "")


## 32 random bytes, URL-safe. Crypto rather than randi(): this is a
## credential, and a guessable one would let anyone build in someone
## else's tab.
static func _new_token() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(32)
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace(
		"/", "_").replace("=", "")


func _listen() -> void:
	while _on:
		var token: String = _token
		var got: Array = await _ask(_http, "%s/api/mcp?t=%s&op=next" % [
			base_url, token], "")
		if not _on or token != _token:
			return
		var result: int = got[0]
		var code: int = got[1]
		if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code == 0:
			trouble.emit("Could not reach Brickworks' relay; trying again.")
			await get_tree().create_timer(3.0).timeout
			continue
		if code == 204:
			continue
		if code != 200:
			trouble.emit("The relay refused this tab (%d)." % code)
			await get_tree().create_timer(5.0).timeout
			continue
		var work: Variant = JSON.parse_string((got[2] as PackedByteArray)
			.get_string_from_utf8())
		if typeof(work) != TYPE_DICTIONARY:
			continue
		await _answer(token, work as Dictionary)


func _answer(token: String, work: Dictionary) -> void:
	var request: Dictionary = work.get("request", {}) as Dictionary
	var tool: String = ""
	if str(request.get("method", "")) == "tools/call":
		tool = str((request.get("params", {}) as Dictionary).get("name", ""))
	called.emit(tool)
	var answer: Variant = null
	if rpc != null:
		answer = await rpc.answer_rpc(request)
	if answer == null:
		answer = {"jsonrpc": "2.0", "id": request.get("id"),
			"error": {"code": -32603, "message": "this tab cannot answer"}}
	await _ask(_reply, "%s/api/mcp?t=%s&op=answer&id=%d" % [base_url, token,
		int(work.get("id", 0))], JSON.stringify(answer))
	answered.emit(tool)


## A POST, awaited: [result, code, body].
func _ask(http: HTTPRequest, url: String, body: String) -> Array:
	if http.request(url, PackedStringArray(["content-type: application/json"]),
			HTTPClient.METHOD_POST, body) != OK:
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray()]
	var done: Array = await http.request_completed
	return [done[0], done[1], done[3]]
