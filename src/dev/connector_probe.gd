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
## And that only a signed-in tab can switch a connector on (2026-10-11):
## refused signed out, by the app and by the relay; on, once signed in,
## with the account recorded as the connector's owner; no work for a tab
## that never said hello signed in; and an address one account owns
## refused to another. The accounts are throwaway ones at Resend's test
## addresses, signed in with codes minted on this side (SignInHelper), and
## deleted at the end.
##
## And Claude signed in to the account with OAuth (2026-10-11), at the one
## address for everybody: its calls answered by this tab, which never gave
## Claude its own address; told no tab is open once it is off; refused
## after Disconnect.
##
## Not in the suite: it needs the relay running and the project's keys.
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

	print("\nsigned out")
	# Where to sign in comes from the same functions, as on the web.
	OS.set_environment("BRICKWORKS_API", _base)
	var account: Account = await _account()
	connector.account = account
	var said: Array = []
	connector.trouble.connect(func(why: String) -> void: said.append(why))
	connector.start()
	_check(not connector.is_on() and said.has("Sign in to Brickworks to connect Claude."),
		"a tab nobody is signed in to will not switch on, and says why")
	var stray: String = "%s/api/mcp?t=%s&i=%s" % [_base, ClaudeConnector._new_token(),
		"probe0000"]
	_check(await _status(stray + "&op=hello", _hello_body(), "") == 401,
		"the relay refuses a hello with no sign-in: 401")
	_check(await _status(stray + "&op=hello", _hello_body(), "not.a.token") == 401,
		"...and one with a made-up sign-in: 401")
	_check(await _status(stray + "&op=next", "", "") == 401,
		"...and hands no work to a tab that never said hello signed in: 401")

	print("\nsigned in")
	var email: String = SignInHelper.throwaway("conn")
	var signed: String = await SignInHelper.sign_in(account, email, get_root())
	_check(signed.is_empty() and account.signed_in(), "signed in as %s %s" % [email, signed])
	connector.start()
	var address: String = connector.address()
	_check(address.begins_with(_base + "/api/mcp?t=") and address.length() > 70,
		"the tab has a private address: %s…" % address.substr(0, 50))
	# Long enough for its hello and its first ask for work to reach the relay.
	await create_timer(3.0).timeout
	_check(connector.is_on(), "signed in, it switches on")
	var owner: String = await _owner_of(address.get_slice("?t=", 1))
	_check(owner == account.user_id and not owner.is_empty(),
		"the relay records the account as the connector's owner")

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
	# All of them, not three: the relay keeps no list of its own (api/mcp.js
	# answers with what the tab sent when it switched on), so a tool the app
	# gains reaches Claude with nothing to change here.
	var served: Array = []
	for tool: Variant in connector.rpc.assistant.tool_catalogue() + connector.rpc._own_tools():
		served.append(str((tool as Dictionary).get("name", "")))
	# And the relay's own two, about the tabs (api/mcp.js, 2026-10-13).
	served.append_array(["tabs", "select_tab"])
	names.sort()
	served.sort()
	_check(names == served and names.has("set_floor") and names.has("export_model"),
		"the tool list is the app's own, every one of its %d tools, and the relay's tabs and select_tab"
			% (names.size() - 2))
	await create_timer(1.5).timeout
	_check(calls.has(""), "...and the tab hears that Claude has connected")
	var found: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick 2 x 4"}})
	var text: String = _text_of(found)
	_check(text.contains("3001") and not bool(
			(found.get("result", {}) as Dictionary).get("isError", true)),
		"a tool call is run in the tab and answered: %s" % text.substr(0, 60).replace("\n", " "))
	_check(calls.has("search_parts"), "...and the tab saw which tool it was")
	# One of the window's commands (AppTools), as Claude asks for it: run in
	# the tab, which here has no window to set a floor in, and says so.
	var floor_said: String = _text_of(await _claude(address, "tools/call",
		{"name": "set_floor", "arguments": {}}))
	_check(calls.has("set_floor") and not floor_said.is_empty(),
		"...and so is one of the window's commands: %s" % floor_said)

	print("\nClaude signed in to the account, at the one address for everybody")
	# The way since 2026-10-11: Claude is never given this tab's address. It
	# signs in with OAuth as claude.ai does — Claude's published identity,
	# PKCE, the person's yes as the signed-in account — and its calls go to
	# whichever tab of that account is open: this one.
	var shared: String = _base + "/api/mcp"
	var bare: Array = await _claude_as("", "initialize", {})
	_check(int(bare[0]) == 401, "the shared address asked with no token: 401, sign in first")
	var signed_token: String = await _oauth_token(account)
	_check(signed_token.begins_with("bwa_"), "Claude signed in as the account and holds a token")
	var before: int = calls.size()
	var greeted: Array = await _claude_as(signed_token, "initialize", {"protocolVersion": "2025-06-18",
		"capabilities": {}, "clientInfo": {"name": "claude-ai", "version": "0.1.0"}})
	_check(int(greeted[0]) == 200 and str((((greeted[1] as Dictionary).get("result", {}) as Dictionary)
			.get("serverInfo", {}) as Dictionary).get("name", "")) == "brickworks",
		"initialize at %s with the token is answered" % shared)
	var by_account: Array = await _claude_as(signed_token, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick 2 x 2"}})
	_check(_text_of(by_account[1] as Dictionary).contains("3003"),
		"a call is run in this account's tab, which never gave Claude its address: %s"
			% _text_of(by_account[1] as Dictionary).substr(0, 40).replace("\n", " "))
	_check(calls.size() > before and calls.has("search_parts"), "...and the tab saw it")
	connector.stop()
	# Until its word that it has closed has reached the relay (a third of a
	# second here, and longer than a second on a loaded machine): the relay's
	# own tabs tool says when.
	for _wait: int in 20:
		await create_timer(1.0).timeout
		if _text_of((await _claude_as(signed_token, "tools/call", {"name": "tabs",
				"arguments": {}}))[1] as Dictionary).contains("No Brickworks tab is open"):
			break
	var none_open: Array = await _claude_as(signed_token, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick"}})
	_check(_text_of(none_open[1] as Dictionary).contains("No Brickworks tab is open for the account"),
		"with the tab switched off, Claude is told no tab of the account is open")
	connector.start()
	await create_timer(3.0).timeout
	var back_on: Array = await _claude_as(signed_token, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick 1 x 1"}})
	_check(_text_of(back_on[1] as Dictionary).contains("3005"), "switched on again, it answers again")
	var listed_for: Dictionary = await _get_with(_base + "/api/oauth?op=connections",
		await account.access_token())
	var labels: Array = []
	for one: Variant in listed_for.get("connections", []) as Array:
		labels.append(str((one as Dictionary).get("client", "")))
	_check(labels.has("Claude"), "the account lists its connection: %s" % ", ".join(labels))
	await _send(_base + "/api/oauth?op=disconnect", "", await account.access_token())
	var after_disconnect: Array = await _claude_as(signed_token, "tools/list", {})
	_check(int(after_disconnect[0]) == 401, "after Disconnect, Claude's token is refused: 401")

	print("\nanother page switches the same address on")
	var replaced: Array = []
	connector.replaced.connect(func() -> void: replaced.append(true))
	var other := ClaudeConnector.new()
	get_root().add_child(other)
	other.base_url = _base
	other.rpc = socket
	other.account = account
	_check(other.address() == address, "a second page load finds the same address")
	other.start()
	await create_timer(30.0).timeout
	_check(not replaced.is_empty() and not connector.is_on(),
		"the first lets go, told it was taken over")
	var again: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick 1 x 2"}})
	_check(_text_of(again).contains("3004"), "...and the newer one answers")

	print("\nsomebody else's account, with the same address")
	var stranger: Account = await _account()
	var their_email: String = SignInHelper.throwaway("conn")
	await SignInHelper.sign_in(stranger, their_email, get_root())
	var theirs: String = await stranger.access_token()
	var theirs_hello: String = "%s&i=%s&op=hello" % [address, "probe1111"]
	_check(not theirs.is_empty() and await _status(theirs_hello, _hello_body(), theirs) == 403,
		"an address one account switched on is refused to another: 403")
	_check(await _owner_of(address.get_slice("?t=", 1)) == account.user_id,
		"...and stays its owner's")

	print("\nout of view, with its page alive")
	# The page keeps the app running out of view now, and says it is alive,
	# so a tab out of view answers like any other. Played here by a tab that
	# goes on asking for work while its page says it is out of view.
	await _post("%s/api/mcp?t=%s&i=%s&op=state&visible=0" % [_base,
		address.get_slice("?t=", 1), other._instance], "")
	var out_of_view: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick 1 x 2"}})
	_check(_text_of(out_of_view).contains("3004"),
		"a tab out of view whose page is alive answers the call")

	print("\nbusy longer than the relay waits for a request for work")
	# The bug the owner hit: Claude told Brickworks was not connected while
	# it plainly was. A tab building a large design asks for no work for
	# minutes, and was judged by that alone. Its page says it is alive.
	var instance: String = other._instance
	other.stop()
	await create_timer(1.0).timeout
	var token: String = address.get_slice("?t=", 1)
	var tab_url: String = "%s/api/mcp?t=%s&i=%s" % [_base, token, instance]
	await _post(tab_url + "&op=hello", _hello_body(), await account.access_token())
	for beat: int in 6:
		await _post(tab_url + "&op=state&visible=1", "")
		await create_timer(10.0).timeout
	var busy: Dictionary = {}
	_claude_into(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick 1 x 2"}}, busy)
	var taken: Dictionary = await _take_call(tab_url)
	if not taken.is_empty():
		await _post(tab_url + "&op=answer&id=%d" % int(taken.get("id", 0)),
			JSON.stringify(await socket.answer_rpc(taken.get("request", {}) as Dictionary)))
	while busy.is_empty():
		await create_timer(0.3).timeout
	_check(_text_of(busy).contains("3004") and not _text_of(busy).contains("not open"),
		"after a minute with no request for work but its page alive, it is not called closed")

	print("\na page the browser froze out of view")
	# Some browsers may still freeze a page out of view: no word from it
	# at all. Claude is told it is paused and to bring it back, not that
	# it is closed, and not after four minutes of waiting.
	await _post(tab_url + "&op=state&visible=0", "")
	var while_asleep: Dictionary = await _claude(address, "tools/list", {})
	_check(((while_asleep.get("result", {}) as Dictionary).get("tools", []) as Array).size() == 3,
		"the tool list is answered while the page is frozen, from what it sent (and tabs, select_tab)")
	var t0: int = Time.get_ticks_msec()
	var hidden: Dictionary = await _claude(address, "tools/call",
		{"name": "search_parts", "arguments": {"query": "brick"}})
	var waited: int = (Time.get_ticks_msec() - t0) / 1000
	_check(_text_of(hidden).contains("paused it out of view") and waited < 90,
		"a frozen page out of view is said to be paused, after %ds" % waited)

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
	ClaudeConnector.where = ""

	print("\nsigning out")
	other.start()
	await create_timer(3.0).timeout
	# As the app does on Sign out (Main): the connector off, then the account.
	other.stop()
	await account.sign_out()
	_check(not other.is_on() and not account.signed_in(), "signed out, it is off")
	var after_out: Array = []
	other.trouble.connect(func(why: String) -> void: after_out.append(why))
	other.start()
	_check(not other.is_on() and after_out.has("Sign in to Brickworks to connect Claude."),
		"...and will not switch on again until somebody signs in")
	var gone: int = await SignInHelper.delete_accounts("delivered+bwconn", get_root())
	print("  (removed %d throwaway account(s))" % gone)

	print("")
	if _failures == 0:
		print("Claude can build in a tab through the connector")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## A POST as a tab would send it, awaited: the parsed body, or {}.
func _post(url: String, body: String, token: String = "") -> Dictionary:
	var done: Array = await _send(url, body, token)
	var text: String = (done[3] as PackedByteArray).get_string_from_utf8()
	if text.is_empty():
		return {}
	var json := JSON.new()
	return json.data if json.parse(text) == OK and json.data is Dictionary else {}


## The same, for its status alone.
func _status(url: String, body: String, token: String) -> int:
	return int((await _send(url, body, token))[1])


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


## Claude's request at the shared address, with a token or none: [status,
## the parsed body].
func _claude_as(token: String, method: String, params: Dictionary) -> Array:
	_sent += 1
	var http := HTTPRequest.new()
	http.timeout = 60.0
	get_root().add_child(http)
	var headers := PackedStringArray(["content-type: application/json",
		"accept: application/json, text/event-stream"])
	if not token.is_empty():
		headers.append("authorization: Bearer " + token)
	http.request(_base + "/api/mcp", headers, HTTPClient.METHOD_POST, JSON.stringify(
		{"jsonrpc": "2.0", "id": _sent, "method": method, "params": params}))
	var done: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	return [int(done[1]), parsed if parsed is Dictionary else {}]


## Claude's sign-in, as claude.ai does it: its published identity, a PKCE
## challenge, the person's yes as [param signed_in] (the call the sign-in
## page makes), and the code traded for a token. "" if any step failed.
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


## A GET with a session, parsed.
func _get_with(url: String, session: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 30.0
	get_root().add_child(http)
	http.request(url, PackedStringArray(["authorization: Bearer " + session]))
	var done: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


## What a tab says when it switches on.
func _hello_body() -> String:
	return JSON.stringify({"instructions": "x".repeat(1200),
		"tools": [{"name": "search_parts", "description": "", "inputSchema": {}}]})


## An account that keeps nothing on this machine, asked of the functions
## under test, once it has worked out who is here (nobody, at first).
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


## Whose connector the relay says this token's is, read as the server.
func _owner_of(token: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(token.to_utf8_buffer())
	var channel: String = hashing.finish().hex_encode()
	var got: Dictionary = await SignInHelper.admin(get_root(), HTTPClient.METHOD_GET,
		"/rest/v1/relay_tabs?channel=eq.%s&select=owner" % channel, "")
	var rows: Variant = got.get("body")
	if rows is Array and not (rows as Array).is_empty():
		var owner: Variant = ((rows as Array)[0] as Dictionary).get("owner")
		return str(owner) if owner != null else ""
	return ""


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
	var body: String = (done[3] as PackedByteArray).get_string_from_utf8()
	# An event stream when the relay has something of its own to say first
	# (the tools changed, api/mcp.js): the answer is the message with an id.
	if body.begins_with("event:") or body.begins_with("data:"):
		for line: String in body.split("\n"):
			if line.begins_with("data:"):
				var message: Variant = JSON.parse_string(line.substr(5).strip_edges())
				if message is Dictionary and (message as Dictionary).has("id"):
					return message
		return {}
	var parsed: Variant = JSON.parse_string(body)
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
