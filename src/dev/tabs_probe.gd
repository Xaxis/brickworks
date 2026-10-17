## Can Claude tell several Brickworks tabs apart, and build in the one it
## means?
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790 &
##   godot --headless --path . --script src/dev/tabs_probe.gd -- 8790
##
## One account with three tabs open, each on a model of its own, as the
## owner works: "multiple tabs of brickworks studio in the same browser
## should be able to support and work on separate projects both in terms
## of the file that is open and the MCP with accurate targeting." Played by
## three of the app's own connectors in this process, each with its own
## world, assistant and answering socket, its own tab id and its own model's
## name, through the real relay code and the real queue (api/mcp.js), with
## Claude signed in to the account with OAuth as claude.ai is.
##
## What it proves: every tab that switches on is a target of its own, with
## its id and its model's name; tabs lists them; a session's first call
## goes to the tab the person used last and the session stays there when
## they click into another; target does one call in a named tab and an edit
## lands in that tab's model alone, read back from every tab; select_tab
## moves the session; a second session keeps its own choice; every answer
## begins by naming the tab and model; and a tab that closes mid-session is
## reported on the next call, with nothing done anywhere else.
##
## Before 2026-10-13 the relay had no tabs, select_tab or target, named no
## tab in its answers, and sent every call to whichever tab it scored best,
## so this fails on that code at its first check of a listing.
##
## Not in the suite: it needs the relay running and the project's keys.
extends SceneTree

var _failures: int = 0
var _base: String = ""
var _sent: int = 0
var _library: PartLibrary


class Tab extends RefCounted:
	var id: String
	var name: String
	var world: BrickWorld
	var socket: CommandSocket
	var connector: ClaudeConnector


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_base = "http://127.0.0.1:%s" % (args[0] if not args.is_empty() else "8790")
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", _base)
	var account: Account = await _account()
	var email: String = SignInHelper.throwaway("tabs")
	var signed: String = await SignInHelper.sign_in(account, email, get_root())
	_check(signed.is_empty() and account.signed_in(), "signed in as %s %s" % [email, signed])

	print("\nthree tabs, each its own connector")
	var house: Tab = _tab("hse" + TabSession.fresh_id().left(3), "House", account)
	var castle: Tab = _tab("cst" + TabSession.fresh_id().left(3), "Castle", account)
	var light: Tab = _tab("lgt" + TabSession.fresh_id().left(3), "Lighthouse", account)
	var all: Array[Tab] = [house, castle, light]
	for tab: Tab in all:
		tab.connector.start()
	await create_timer(4.0).timeout
	var addresses: Dictionary = {}
	for tab: Tab in all:
		addresses[tab.connector.address()] = true
	_check(house.connector.is_on() and castle.connector.is_on() and light.connector.is_on(),
		"all three switch on, none taking another's place")
	_check(addresses.size() == 3, "...each with an address of its own, so the relay knows three tabs")
	# A model on each, different in size, built through each tab's own tools.
	await _design(house, 3)
	await _design(castle, 5)
	await _design(light, 1)
	_check(house.world.brick_count() == 3 and castle.world.brick_count() == 5
		and light.world.brick_count() == 1, "three models: 3, 5 and 1 parts")

	print("\nClaude signed in to the account")
	var token: String = await _oauth_token(account)
	_check(token.begins_with("bwa_"), "Claude holds a token for the account")
	var greeted: Array = await _mcp(token, "", "initialize", {"protocolVersion": "2025-06-18",
		"capabilities": {}, "clientInfo": {"name": "probe", "version": "1"}})
	var session: String = str(greeted[2])
	_check(int(greeted[0]) == 200 and session.length() >= 16,
		"initialize hands Claude a session id: %s…" % session.left(8))
	var listed: Array = await _mcp(token, session, "tools/list", {})
	var names: Array = []
	var targeted: int = 0
	var tools: Array = (((listed[1] as Dictionary).get("result", {}) as Dictionary)
		.get("tools", []) as Array)
	for tool: Variant in tools:
		names.append(str((tool as Dictionary).get("name", "")))
		var props: Variant = ((tool as Dictionary).get("inputSchema", {}) as Dictionary).get("properties", {})
		if props is Dictionary and (props as Dictionary).has("target"):
			targeted += 1
	_check(names.has("tabs") and names.has("select_tab"),
		"the tool list has tabs and select_tab beside the app's own")
	_check(targeted == tools.size() - 2 and targeted > 20,
		"...and every one of the app's %d tools takes a target" % targeted)

	print("\nthe tabs, listed")
	# The person used the castle last: its page says so, as it does every
	# ten seconds and the moment it is focused.
	await _used(castle, 0)
	await _used(house, 300)
	await _used(light, 900)
	var tabs_said: String = _text(await _call(token, session, "tabs", {}))
	_check(tabs_said.contains("3 Brickworks tabs are open"), "tabs: %s" % tabs_said.get_slice("\n", 0))
	for tab: Tab in all:
		_check(tabs_said.contains("%s: “%s”" % [tab.id, tab.name]),
			"...listing %s with its model, %s" % [tab.id, tab.name])
	_check(tabs_said.contains("This chat has not chosen a tab: its first change waits for one"),
		"...and saying this chat has chosen none, so its first change waits for one")

	# Since 2026-10-17 ("Two chats, two tabs", api/mcp.js): with several tabs
	# open, a look goes ahead in the tab used last and binds nothing, and a
	# change waits for a choice; once chosen, the session stays there.
	print("\nwithout a choice: a look in the tab used last, a change stopped")
	var first: String = _text(await _call(token, session, "look_at_model", {}))
	_check(first.begins_with("Tab %s, “Castle”." % castle.id) and first.contains("this look was made in %s" % castle.id),
		"a first look goes to the castle and says so: %s" % first.get_slice("\n", 0))
	_check(first.contains("2 other tabs are open"), "...and says there are two others")
	var unchosen: Array = _counts(all)
	var waits: Dictionary = await _call(token, session, "edit_model", {
		"add": [{"part": "3003", "color": 4, "x": 16, "y": 0, "z": 0, "rot": 0}]})
	_check(_is_error(waits) and _text(waits).begins_with("Nothing was done") and _counts(all) == unchosen,
		"a first change waits for a choice, nothing done anywhere: %s" % _text(waits).get_slice(":", 0))
	var by_name: String = _text(await _call(token, session, "select_tab", {"tab": "the castle tab"}))
	_check(by_name.contains("go to tab %s now" % castle.id), "select_tab by the model's name: %s" % by_name.get_slice("\n", 0))
	await _used(house, 0)
	var second: String = _text(await _call(token, session, "look_at_model", {}))
	_check(second.begins_with("Tab %s, “Castle”." % castle.id),
		"the person clicks into the house; the session's next call stays in the castle")

	print("\ntarget: one call, in the tab named")
	var counts: Array = _counts(all)
	var added: String = _text(await _call(token, session, "edit_model", {"target": house.id,
		"add": [{"part": "3003", "color": 1, "x": 8, "y": 0, "z": 0, "rot": 0}]}))
	_check(added.begins_with("Tab %s, “House”." % house.id),
		"an edit with target %s says it acted on the house: %s" % [house.id, added.get_slice("\n", 0)])
	_check(house.world.brick_count() == int(counts[0]) + 1
		and castle.world.brick_count() == int(counts[1])
		and light.world.brick_count() == int(counts[2]),
		"...and lands in the house alone: %s → %s" % [str(counts), str(_counts(all))])
	var house_look: String = _text(await _call(token, session, "look_at_model", {"target": house.id}))
	var castle_look: String = _text(await _call(token, session, "look_at_model", {"target": castle.id}))
	_check(house_look.contains("4 parts") or house_look.contains("4 bricks"),
		"read back from the house over the relay: %s" % _first_count(house_look))
	_check(castle_look.contains("5 parts") or castle_look.contains("5 bricks"),
		"...and from the castle, unchanged: %s" % _first_count(castle_look))
	var after_target: String = _text(await _call(token, session, "look_at_model", {}))
	_check(after_target.begins_with("Tab %s" % castle.id),
		"after the targeted call, the session is still in the castle")
	var wrong: Dictionary = await _call(token, session, "look_at_model", {"target": "zzzz9"})
	_check(_is_error(wrong) and _text(wrong).contains("No open tab is called “zzzz9”"),
		"a target no tab has is refused, nothing done: %s" % _text(wrong).get_slice(",", 0))

	print("\nselect_tab moves the session")
	var moved: String = _text(await _call(token, session, "select_tab", {"tab": light.id}))
	_check(moved.contains("go to tab %s now" % light.id), "select_tab %s: %s" % [light.id, moved])
	var in_light: String = _text(await _call(token, session, "edit_model", {
		"add": [{"part": "3005", "color": 14, "x": 0, "y": 3, "z": 0, "rot": 0}]}))
	_check(in_light.begins_with("Tab %s, “Lighthouse”." % light.id)
		and light.world.brick_count() == 2 and house.world.brick_count() == 4
		and castle.world.brick_count() == 5,
		"...and the next edit lands in the lighthouse alone: %s" % str(_counts(all)))

	print("\nanother session keeps its own choice")
	var other: Array = await _mcp(token, "", "initialize", {"protocolVersion": "2025-06-18",
		"capabilities": {}, "clientInfo": {"name": "probe-two", "version": "1"}})
	var session_two: String = str(other[2])
	_check(session_two.length() >= 16 and session_two != session, "a second session, its own id")
	var two_first: String = _text(await _call(token, session_two, "look_at_model", {}))
	_check(two_first.begins_with("Tab %s" % house.id),
		"its first call goes to the house, the tab used last: %s" % two_first.get_slice("\n", 0))
	var one_still: String = _text(await _call(token, session, "look_at_model", {}))
	_check(one_still.begins_with("Tab %s" % light.id), "...and the first session is still in the lighthouse")

	print("\na tab closes mid-session")
	var before_close: Array = _counts(all)
	light.connector.stop()
	# Until its word that it has closed has reached the relay: on a loaded
	# machine that took longer than a second and a half, and the call then
	# went to the closing tab (answered too, in other words: see api/mcp.js).
	for _wait: int in 20:
		await create_timer(1.0).timeout
		if not _text(await _call(token, session_two, "tabs", {})).contains(light.id):
			break
	var t0: int = Time.get_ticks_msec()
	var asked: Array = await _mcp(token, session, "tools/call", {"name": "edit_model", "arguments": {
		"add": [{"part": "3005", "color": 4, "x": 0, "y": 6, "z": 0, "rot": 0}]}})
	var closed: Dictionary = asked[1]
	if _text(closed).is_empty():
		print("        (answered %d after %d ms: %s)" % [int(asked[0]), Time.get_ticks_msec() - t0,
			str(asked[3]).left(200)])
	_check(_is_error(closed) and _text(closed).contains("The tab this chat was working in, %s"
			% light.id) and _text(closed).contains("has closed, so nothing was done"),
		"the next call says the lighthouse's tab has closed: %s" % _text(closed).get_slice(".", 0))
	_check(_counts(all) == before_close, "...and nothing was done in any tab: %s" % str(_counts(all)))
	var then: String = _text(await _call(token, session, "look_at_model", {}))
	_check(then.begins_with("Tab %s" % house.id),
		"told once, its next look goes to the tab used last, and names it: %s" % then.get_slice("\n", 0))
	var still_listed: String = _text(await _call(token, session, "tabs", {}))
	_check(still_listed.contains("2 Brickworks tabs are open") and not still_listed.contains(light.id),
		"tabs no longer lists the closed one")

	for tab: Tab in all:
		tab.connector.stop()
	await account.sign_out()
	var gone: int = await SignInHelper.delete_accounts("delivered+bwtabs", get_root())
	print("  (removed %d throwaway account(s))" % gone)
	print("")
	if _failures == 0:
		print("Claude can tell the tabs apart and build in the one it means")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## A tab of its own: a world, a builder, an assistant and the socket that
## answers for it, and a connector with its own id, file and model name.
func _tab(id: String, name: String, account: Account) -> Tab:
	var tab := Tab.new()
	tab.id = id
	tab.name = name
	tab.world = BrickWorld.new()
	tab.world.library = _library
	get_root().add_child(tab.world)
	var builder := Builder.new()
	builder.world = tab.world
	builder.library = _library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = _library
	assistant.world = tab.world
	assistant.builder = builder
	get_root().add_child(assistant)
	tab.socket = CommandSocket.new()
	tab.socket.assistant = assistant
	get_root().add_child(tab.socket)
	tab.connector = ClaudeConnector.new()
	tab.connector.tab_id = id
	tab.connector.kept_in = "user://probe_tabs_%s.json" % id
	if FileAccess.file_exists(tab.connector.kept_in):
		DirAccess.remove_absolute(tab.connector.kept_in)
	tab.connector.model_name = func() -> String: return name
	get_root().add_child(tab.connector)
	tab.connector.base_url = _base
	tab.connector.rpc = tab.socket
	tab.connector.account = account
	return tab


func _design(tab: Tab, count: int) -> void:
	var bricks: Array = []
	for n: int in count:
		bricks.append({"part": "3001", "color": 4, "x": 0, "y": 3 * n, "z": 0, "rot": 0})
	await tab.socket.answer_rpc({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
		"params": {"name": "submit_design", "arguments": {"bricks": bricks}}})


func _counts(tabs: Array[Tab]) -> Array:
	var counts: Array = []
	for tab: Tab in tabs:
		counts.append(tab.world.brick_count())
	return counts


## What the page says with every word that it is alive: how long since the
## person used the tab.
func _used(tab: Tab, seconds: int) -> void:
	var token: String = tab.connector.address().get_slice("?t=", 1)
	await _send("%s/api/mcp?t=%s&i=%s&op=state&visible=1&used=%d" % [_base, token,
		tab.connector._instance, seconds], "", "")


func _call(token: String, session: String, tool: String, arguments: Dictionary) -> Dictionary:
	return (await _mcp(token, session, "tools/call", {"name": tool, "arguments": arguments}))[1]


## Claude's request at the account's address: [status, parsed body, the
## session id the answer hands out, if any].
func _mcp(token: String, session: String, method: String, params: Dictionary) -> Array:
	_sent += 1
	var http := HTTPRequest.new()
	http.timeout = 90.0
	get_root().add_child(http)
	var headers := PackedStringArray(["content-type: application/json",
		"accept: application/json, text/event-stream", "authorization: Bearer " + token])
	if not session.is_empty():
		headers.append("mcp-session-id: " + session)
	http.request(_base + "/api/mcp", headers, HTTPClient.METHOD_POST, JSON.stringify(
		{"jsonrpc": "2.0", "id": _sent, "method": method, "params": params}))
	var done: Array = await http.request_completed
	http.queue_free()
	var given: String = ""
	for line: String in done[2] as PackedStringArray:
		if line.to_lower().begins_with("mcp-session-id:"):
			given = line.substr(line.find(":") + 1).strip_edges()
	var parsed: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	return [int(done[1]), parsed if parsed is Dictionary else {}, given,
		"result %d: %s" % [int(done[0]), (done[3] as PackedByteArray).get_string_from_utf8()]]


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


func _text(answer: Dictionary) -> String:
	var text := PackedStringArray()
	for block: Variant in ((answer.get("result", {}) as Dictionary).get("content", []) as Array):
		if block is Dictionary and (block as Dictionary).has("text"):
			text.append(str((block as Dictionary).get("text", "")))
	return "\n".join(text)


func _is_error(answer: Dictionary) -> bool:
	return bool((answer.get("result", {}) as Dictionary).get("isError", false))


## The first line of a look that counts the parts, for the report.
func _first_count(look: String) -> String:
	for line: String in look.split("\n"):
		if line.contains("parts") or line.contains("bricks"):
			return line.strip_edges().left(80)
	return look.left(80)


## Claude's sign-in, as connector_probe does it: its published identity,
## PKCE, the person's yes as [param signed_in], and the code traded.
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
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)
