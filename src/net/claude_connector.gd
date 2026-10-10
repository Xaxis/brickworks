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
## random. It is kept on this device, like a key, because the address is
## added to Claude once: a new one every visit made the connector someone
## had added dead by the next. Switching off keeps it; "New address" is
## what forgets it.
##
## A browser stops drawing a tab it is not showing, and the app runs on
## drawing — so while the person is over in claude.ai this tab answers
## nothing. Three things follow. The handshake and the tool list are sent
## to the relay when it switches on, so Claude can add and list the
## connector while the tab sleeps. The page itself, which keeps running,
## tells the relay when it goes out of view, so Claude is told to ask for
## it rather than left waiting. And a call taken just as the tab went to
## sleep is handed out again when it wakes (supabase/relay.sql).
class_name ClaudeConnector
extends Node

## Where the address and whether it was on are kept. A probe points this
## elsewhere so it never touches the one this machine uses.
static var where: String = "user://claude_connector.json"

## Where the relay is. The site the page came from on the web; the live
## site from the desktop.
var base_url: String = "https://brickworks.diy"
## Answers the requests. Needs its assistant and app set.
var rpc: CommandSocket

## Listening for Claude, or not; and the address to give it while it is.
signal listening(on: bool, address: String)
## Claude asked for something: a tool by name, with what it passed, or ""
## for the protocol's own requests; and it was answered — whether the tool
## did what was asked, and what it said.
signal called(tool: String, arguments: Dictionary)
signal answered(tool: String, ok: bool, text: String)
## The relay could not be reached, in words.
signal trouble(why: String)
## Another page switched this connector on, and this one has let go.
signal replaced()
## The relay answered again after [signal trouble].
signal relay_ok()

var _token: String = ""
var _on: bool = false
## Whether Claude has ever reached this address, so the steps for adding
## it can be folded away once it has.
var _used: bool = false
## This page load, so the relay can tell two of them apart. The newest one
## to switch on listens; an older one is told so and lets go.
var _instance: String = ""
## Bumped on every switch on and off. The address outlives both now, so it
## can no longer tell an old listening loop that it has been superseded:
## a cancelled request never completes, and the loop waiting on it would
## wake on the next one's answer and answer it twice.
var _generation: int = 0
var _troubled: bool = false
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
	_instance = _new_token().substr(0, 16)
	_load()


func is_on() -> bool:
	return _on


## True once Claude has reached this address.
func used() -> bool:
	return _used


## The address to add to Claude, or "" when there is none yet.
func address() -> String:
	return "" if _token.is_empty() else "%s/api/mcp?t=%s" % [base_url, _token]


## On again if it was on when the page was last open, with the same
## address, so the connector added to Claude keeps working.
func resume() -> void:
	var saved: Dictionary = _read()
	if bool(saved.get("on", false)) and not _token.is_empty():
		start()


## Start listening, on the address this device keeps, or a new one.
func start() -> void:
	if _on:
		return
	if _token.is_empty():
		_token = _new_token()
		_used = false
	_on = true
	_generation += 1
	_save()
	_watch_the_page()
	listening.emit(true, address())
	_listen()


## Stop listening. The address is kept, so switching on again needs no
## change in Claude; until then a call is told the tab is not listening.
func stop() -> void:
	if not _on:
		return
	_on = false
	_generation += 1
	_save()
	_http.cancel_request()
	listening.emit(false, address())
	_watch_the_page()
	# Told so the relay can say "not open" at once, rather than after the
	# tab has been silent long enough to count as gone.
	_tell("close")


## Use an address already added to Claude — from another browser, or
## before this one's storage was cleared — so nothing changes in Claude.
## Takes the whole address or just its token. Returns "" or why not.
func adopt(given: String) -> String:
	var token: String = given.strip_edges()
	if token.contains("t="):
		token = token.get_slice("t=", 1).get_slice("&", 0)
	var shape := RegEx.create_from_string("^[A-Za-z0-9_-]{40,96}$")
	if shape.search(token) == null:
		return "That is not a Brickworks connector address."
	stop()
	_token = token
	# Claude has it already; that is the point.
	_used = true
	_save()
	start()
	return ""


## Forget the address altogether: anyone who had it can no longer reach
## this tab, and the next one is new. For an address that got out.
func forget() -> void:
	var was_on: bool = _on
	stop()
	_token = ""
	_used = false
	_save()
	if was_on:
		start()
	else:
		listening.emit(false, "")


func _tell(op: String) -> void:
	if _token.is_empty():
		return
	var note := HTTPRequest.new()
	add_child(note)
	note.request_completed.connect(func(_a: int, _b: int,
			_c: PackedStringArray, _d: PackedByteArray) -> void:
		note.queue_free())
	note.request("%s/api/mcp?t=%s&i=%s&op=%s" % [base_url, _token, _instance, op],
		PackedStringArray(), HTTPClient.METHOD_POST, "")


## The page, not the app, says when it goes out of view or away: the app
## is paused then and could not. sendBeacon is made for exactly this, and
## is let through at the moment a page is being closed.
func _watch_the_page() -> void:
	if not OS.has_feature("web"):
		return
	var url: String = ("%s/api/mcp?t=%s&i=%s" % [base_url, _token, _instance]
		if _on else "")
	JavaScriptBridge.eval("""
		window.brickworksConnector = %s;
		if (!window.brickworksConnectorWatched) {
			window.brickworksConnectorWatched = true;
			document.addEventListener("visibilitychange", function () {
				var url = window.brickworksConnector;
				if (url) navigator.sendBeacon(url + "&op=state&visible="
					+ (document.hidden ? "0" : "1"));
			});
			window.addEventListener("pagehide", function () {
				var url = window.brickworksConnector;
				if (url) navigator.sendBeacon(url + "&op=close");
			});
		}
	""" % JSON.stringify(url), true)


func _read() -> Dictionary:
	if not FileAccess.file_exists(where):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(where))
	return parsed if parsed is Dictionary else {}


func _load() -> void:
	var saved: Dictionary = _read()
	var token: String = str(saved.get("token", ""))
	_token = token if token.length() >= 40 else ""
	_used = bool(saved.get("used", false)) and not _token.is_empty()


func _save() -> void:
	if _token.is_empty():
		if FileAccess.file_exists(where):
			DirAccess.remove_absolute(where)
		return
	var file: FileAccess = FileAccess.open(where, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"token": _token, "on": _on, "used": _used}))
	file.close()


## Said to Claude first, so it can set the person up rather than find out
## from a failed call.
const CONNECTED_NOTE := ("These tools build in Brickworks, open in a tab of "
	+ "the person's browser; the model appears there as you work, and each "
	+ "step shows in its panel. A browser pauses a tab it is not showing, so "
	+ "before a long build tell them to keep the Brickworks tab in view, side "
	+ "by side with this chat, and if a call says the tab is out of view, ask "
	+ "them to bring it back and call again.\n\n")


## What this tab would answer to the handshake and the tool list, for the
## relay to answer with while the tab cannot.
func _hello() -> bool:
	if rpc == null:
		return false
	var greeted: Variant = await rpc.answer_rpc({"jsonrpc": "2.0", "id": 1,
		"method": "initialize", "params": {}})
	var listed: Variant = await rpc.answer_rpc({"jsonrpc": "2.0", "id": 2,
		"method": "tools/list", "params": {}})
	var body: Dictionary = {
		"instructions": CONNECTED_NOTE + str(((greeted as Dictionary)
			.get("result", {}) as Dictionary).get("instructions", "")),
		"tools": ((listed as Dictionary).get("result", {}) as Dictionary).get("tools", []),
	}
	var got: Array = await _ask(_http, "%s/api/mcp?t=%s&i=%s&op=hello" % [
		base_url, _token, _instance], JSON.stringify(body))
	return got[0] == HTTPRequest.RESULT_SUCCESS and int(got[1]) == 204


## 32 random bytes, URL-safe. Crypto rather than randi(): this is a
## credential, and a guessable one would let anyone build in someone
## else's tab.
static func _new_token() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(32)
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace(
		"/", "_").replace("=", "")


func _listen() -> void:
	var token: String = _token
	var mine: int = _generation
	while true:
		var greeted: bool = await _hello()
		if mine != _generation:
			return
		if greeted:
			relay_ok.emit()
			break
		trouble.emit("Could not reach Brickworks' relay; trying again.")
		await get_tree().create_timer(3.0).timeout
	while mine == _generation:
		var got: Array = await _ask(_http, "%s/api/mcp?t=%s&i=%s&op=next" % [
			base_url, token, _instance], "")
		if mine != _generation:
			return
		var result: int = got[0]
		var code: int = got[1]
		if code == 409:
			# Another page switched it on since; that one has it now.
			_on = false
			_generation += 1
			_watch_the_page()
			listening.emit(false, address())
			replaced.emit()
			return
		if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code == 0:
			trouble.emit("Could not reach Brickworks' relay; trying again.")
			_troubled = true
			await get_tree().create_timer(3.0).timeout
			continue
		if _troubled:
			_troubled = false
			relay_ok.emit()
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
	var arguments: Dictionary = {}
	if str(request.get("method", "")) == "tools/call":
		var params: Dictionary = request.get("params", {}) as Dictionary
		tool = str(params.get("name", ""))
		var given: Variant = params.get("arguments", {})
		arguments = given if given is Dictionary else {}
	if not _used:
		_used = true
		_save()
	called.emit(tool, arguments)
	# A notification — the relay saying Claude reached it, or one of the
	# protocol's own — wants no answer, and the relay has already let it go.
	if request.get("id") == null:
		return
	var answer: Variant = null
	if rpc != null:
		answer = await rpc.answer_rpc(request)
	if answer == null:
		answer = {"jsonrpc": "2.0", "id": request.get("id"),
			"error": {"code": -32603, "message": "this tab cannot answer"}}
	await _ask(_reply, "%s/api/mcp?t=%s&op=answer&id=%d" % [base_url, token,
		int(work.get("id", 0))], JSON.stringify(answer))
	var result: Dictionary = (answer as Dictionary).get("result", {}) as Dictionary
	var said := PackedStringArray()
	for block: Variant in result.get("content", []) as Array:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
			said.append(str((block as Dictionary).get("text", "")))
	answered.emit(tool, not bool(result.get("isError", false))
		and not (answer as Dictionary).has("error"), "\n".join(said))


## A POST, awaited: [result, code, body].
func _ask(http: HTTPRequest, url: String, body: String) -> Array:
	if http.request(url, PackedStringArray(["content-type: application/json"]),
			HTTPClient.METHOD_POST, body) != OK:
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray()]
	var done: Array = await http.request_completed
	return [done[0], done[1], done[3]]
