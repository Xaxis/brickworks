## Two desktop windows, two Claude chats: does each chat build only in its
## own window, and does each window know which chat drives it?
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790 &
##   godot --headless --path . --script src/dev/tabpair_probe.gd -- 8790
##
## A desktop window is a tab to the relay: its connector registers under the
## window's own id (TabSession), the way a browser tab's does. So two
## windows, played here as two connectors in one process, each with its own
## model and its own CommandSocket, signed in to one throwaway account; and
## three chats, as Claude makes them (three Mcp-Session-Ids), through the
## real relay (api/mcp.js, "Two chats, two tabs"):
##
##   - a chat that names no window is stopped before its first change;
##   - one chooses the castle window by its model's name and builds there,
##     another the truck by its id, each in its own model and not the other;
##   - each window's connector hears its chat (chats_changed) and the
##     toolbar's line says so (ClaudeTabView.badge);
##   - a third chat in the castle: the window hears two, keeps one
##     (keep_chat), and the other's next call is told it was moved off;
##   - New chat for this tab names the window, for claude.ai, the Claude
##     app and Claude Code.
##
## Not in the suite: it needs the relay running and the project's keys.
extends SceneTree

var _failures: int = 0
var _base: String = ""
var _sent: int = 0


class Desk:
	var name: String
	var world: BrickWorld
	var connector: ClaudeConnector
	var heard: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_base = "http://127.0.0.1:%s" % (args[0] if not args.is_empty() else "8790")
	OS.set_environment("BRICKWORKS_API", _base)
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var account: Account = await _account()
	var email: String = SignInHelper.throwaway("tabpair")
	var signed: String = await SignInHelper.sign_in(account, email, get_root())
	_check(signed.is_empty() and account.signed_in(), "signed in as %s %s" % [email, signed])

	var windows: Array[Desk] = []
	for name: String in ["Desk Castle", "Desk Truck"]:
		windows.append(_window(name, library, account))
	var castle: Desk = windows[0]
	var truck: Desk = windows[1]
	for window: Desk in windows:
		window.connector.start()
	await create_timer(4.0).timeout
	_check(castle.connector.is_on() and truck.connector.is_on()
			and castle.connector.tab() != truck.connector.tab(),
		"two windows switch on, each its own tab: %s, %s" % [castle.connector.tab(), truck.connector.tab()])
	_check(ClaudeTabView.badge(castle.connector)[0] == "Tab " + castle.connector.tab(),
		"the castle's toolbar names its window, no chat in it: %s" % ClaudeTabView.badge(castle.connector)[0])

	print("\nNew chat for this tab")
	castle.connector.open_links = false
	for where: String in ["claude.ai", "app", "code"]:
		castle.connector.start_chat(where)
		var link: String = castle.connector.last_opened
		var start: String = {"claude.ai": "https://claude.ai/new?q=", "app": "claude://claude.ai/new?q=",
			"code": "claude-cli://open?q="}[where]
		_check(link.begins_with(start) and link.get_slice("?q=", 1).uri_decode()
				== "Use my Brickworks tab %s (“Desk Castle”) for this chat." % castle.connector.tab(),
			"%s: %s…" % [where, link.left(70)])
	_check(castle.connector.new_chat_command() == "claude \"Use my Brickworks tab %s (“Desk Castle”) for this chat.\""
			% castle.connector.tab(), "Claude Code's command line: %s" % castle.connector.new_chat_command())

	print("\nthree chats")
	var token: String = await _oauth_token(account)
	_check(token.begins_with("bwa_"), "Claude signs in to the account")
	var a: String = await _session(token)
	var b: String = await _session(token)
	var c: String = await _session(token)
	var counts: Array = windows.map(func(w: Desk) -> int: return w.world.brick_count())
	var stopped: Dictionary = await _call(token, a, "edit_model", {"add": [_brick(4)]})
	_check(stopped["error"] and str(stopped["words"]).begins_with("Nothing was done"),
		"a chat that names no window is stopped before its first change: %s" % _first(stopped))
	_check(windows.map(func(w: Desk) -> int: return w.world.brick_count()) == counts,
		"...and neither model changed")
	var chose: Dictionary = await _call(token, a, "select_tab", {"tab": "desk castle"})
	_check(str(chose["words"]).contains("go to tab %s now" % castle.connector.tab()),
		"chat A chooses the castle by its model's name")
	var built: Dictionary = await _call(token, a, "edit_model", {"add": [_brick(4)]})
	_check(not built["error"] and str(built["words"]).begins_with("Tab %s" % castle.connector.tab())
			and castle.world.brick_count() == counts[0] + 1 and truck.world.brick_count() == counts[1],
		"...and its change lands in the castle's model alone: %s" % _first(built))
	var into: Dictionary = await _call(token, b, "edit_model", {"add": [_brick(1)], "target": truck.connector.tab()})
	_check(not into["error"] and truck.world.brick_count() == counts[1] + 1
			and castle.world.brick_count() == counts[0] + 1,
		"chat B's change, targeted at the truck's id, lands in the truck alone: %s" % _first(into))
	await create_timer(2.0).timeout
	_check(castle.connector.working().size() == 1 and truck.connector.working().size() == 1,
		"each window hears one chat working in it")
	_check(ClaudeTabView.badge(castle.connector)[0] == "Claude working · tab " + castle.connector.tab(),
		"...and its toolbar says so: %s" % ClaudeTabView.badge(castle.connector)[0])

	print("\na second chat in the castle")
	await _call(token, c, "select_tab", {"tab": castle.connector.tab()})
	await create_timer(3.0).timeout
	var two: Array = castle.connector.working()
	_check(two.size() == 2 and ClaudeTabView.badge(castle.connector)[0].begins_with("2 Claude chats"),
		"the castle hears two chats: %s" % ClaudeTabView.badge(castle.connector)[0])
	var chat_a: String = _chat_of(a)
	var moved: int = await castle.connector.keep_chat(chat_a)
	_check(moved == 1 and castle.connector.working().size() == 1
			and str((castle.connector.working()[0] as Dictionary).get("chat", "")) == chat_a,
		"Keep this one beside chat A moves the other off")
	var before: int = castle.world.brick_count()
	var refused: Dictionary = await _call(token, c, "edit_model", {"add": [_brick(14)]})
	_check(refused["error"] and str(refused["words"]).contains("moved this chat off")
			and castle.world.brick_count() == before,
		"the other's next call is told it was moved off, and nothing changes")
	var on: Dictionary = await _call(token, a, "edit_model", {"add": [_brick(2)]})
	_check(not on["error"] and castle.world.brick_count() == before + 1,
		"chat A builds on in the castle")

	for window: Desk in windows:
		window.connector.stop()
	await create_timer(1.0).timeout
	var gone: int = await SignInHelper.delete_accounts("delivered+bwtabpair", get_root())
	print("  (throwaway accounts deleted: %d)" % gone)
	print("\n%s" % ("all checks passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures > 0 else 0)


## A window: its own model, its own answering socket, its own connector.
func _window(name: String, library: PartLibrary, account: Account) -> Desk:
	var window := Desk.new()
	window.name = name
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
	connector.tab_id = TabSession.fresh_id()
	connector.kept_in = "user://sessions/probe/tabpair_%s.json" % connector.tab_id
	connector.model_name = func() -> String: return name
	get_root().add_child(connector)
	connector.base_url = _base
	connector.rpc = socket
	connector.account = account
	window.world = world
	window.connector = connector
	return window


func _brick(colour: int) -> Dictionary:
	_sent += 1
	return {"part": "3003", "color": colour, "x": 4 * (_sent % 9), "y": 0, "z": 40 + 4 * (_sent / 9), "rot": 0}


## A chat as Claude opens one: initialize, and the session id it is given.
func _session(token: String) -> String:
	var said: Array = await _mcp(token, "", "initialize", {"protocolVersion": "2025-06-18",
		"capabilities": {}, "clientInfo": {"name": "tabpair-probe", "version": "1"}})
	return str(said[2])


## A chat's name as its tab is shown it (api/mcp.js chatOf).
func _chat_of(session: String) -> String:
	return ("session:" + session).sha256_text().left(8)


func _call(token: String, session: String, tool: String, input: Dictionary) -> Dictionary:
	var said: Array = await _mcp(token, session, "tools/call", {"name": tool, "arguments": input})
	var result: Dictionary = (said[1] as Dictionary).get("result", {}) as Dictionary
	var words := PackedStringArray()
	for block: Variant in result.get("content", []) as Array:
		if block is Dictionary:
			words.append(str((block as Dictionary).get("text", "")))
	return {"words": "\n".join(words), "error": bool(result.get("isError", false))}


func _first(said: Dictionary) -> String:
	return str(said["words"]).get_slice("\n", 0).left(120)


## One MCP request at the shared address: [status, body, session id given].
func _mcp(token: String, session: String, method: String, params: Dictionary) -> Array:
	_sent += 1
	var http := HTTPRequest.new()
	http.timeout = 240.0
	get_root().add_child(http)
	var headers := PackedStringArray(["content-type: application/json",
		"accept: application/json", "authorization: Bearer " + token])
	if not session.is_empty():
		headers.append("mcp-session-id: " + session)
	http.request(_base + "/api/mcp", headers, HTTPClient.METHOD_POST, JSON.stringify(
		{"jsonrpc": "2.0", "id": _sent, "method": method, "params": params}))
	var done: Array = await http.request_completed
	http.queue_free()
	var given: String = ""
	for header: String in done[2] as PackedStringArray:
		if header.to_lower().begins_with("mcp-session-id:"):
			given = header.get_slice(":", 1).strip_edges()
	var parsed: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	return [int(done[1]), parsed if parsed is Dictionary else {}, given]


## Claude's sign-in, as claude.ai does it (connector_probe.gd).
func _oauth_token(signed_in: Account) -> String:
	var client: String = "https://claude.ai/oauth/mcp-oauth-client-metadata"
	var back: String = "https://claude.ai/api/mcp/auth_callback"
	var verifier: String = ClaudeConnector._new_token()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(verifier.to_utf8_buffer())
	var challenge: String = Marshalls.raw_to_base64(hashing.finish()).replace(
		"+", "-").replace("/", "_").replace("=", "")
	var yes: Array = await _send(_base + "/api/oauth?op=approve", JSON.stringify({
		"response_type": "code", "client_id": client, "redirect_uri": back,
		"code_challenge": challenge, "code_challenge_method": "S256", "state": "probe",
		"resource": _base + "/api/mcp"}), await signed_in.access_token())
	var said: Variant = JSON.parse_string((yes[3] as PackedByteArray).get_string_from_utf8())
	var redirect: String = str((said as Dictionary).get("redirect", "")) if said is Dictionary else ""
	if not redirect.contains("code="):
		print("  (no code: %s)" % str(said))
		return ""
	var code: String = redirect.get_slice("code=", 1).get_slice("&", 0)
	var http := HTTPRequest.new()
	http.timeout = 30.0
	get_root().add_child(http)
	http.request(_base + "/oauth/token", PackedStringArray([
		"content-type: application/x-www-form-urlencoded"]), HTTPClient.METHOD_POST,
		"grant_type=authorization_code&code=%s&redirect_uri=%s&client_id=%s&code_verifier=%s&resource=%s"
		% [code, back.uri_encode(), client.uri_encode(), verifier, (_base + "/api/mcp").uri_encode()])
	var done: Array = await http.request_completed
	http.queue_free()
	var tokens: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	return str((tokens as Dictionary).get("access_token", "")) if tokens is Dictionary else ""


func _send(url: String, body: String, token: String) -> Array:
	var http := HTTPRequest.new()
	http.timeout = 60.0
	get_root().add_child(http)
	var headers := PackedStringArray(["content-type: application/json"])
	if not token.is_empty():
		headers.append("authorization: Bearer " + token)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	var done: Array = await http.request_completed
	http.queue_free()
	return done


func _account() -> Account:
	var deployment := Deployment.new()
	get_root().add_child(deployment)
	var account := Account.new()
	account.deployment = deployment
	account.keeps = false
	get_root().add_child(account)
	while account.state == Account.State.CHECKING:
		await account.changed
	return account


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
