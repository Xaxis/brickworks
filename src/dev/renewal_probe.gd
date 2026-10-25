## A returning person is let in at once, and signed in behind their model.
##
##   godot --headless --path . --script src/dev/renewal_probe.gd
##
## walk256 (A17, 2026-10-25): on every web load a person signed in last
## time waited on "Signing you in…" for about 18 s before seeing anything,
## while the deployment was asked where to sign in and Supabase renewed the
## session this browser kept. Everyone has an account (2026-10-11), and a
## signed-out person still meets the sign-in screen; but a session kept on
## this device is theirs already, and only what needs the account itself
## should wait on its renewal.
##
## A host on 127.0.0.1 (the first port free from 9244) stands in for the
## deployment and for Supabase: /api/account is held unanswered until the
## probe lets it go, as a slow start holds it, then says where to sign in
## (this host); the renewal is answered as each case plans; a sign-out is
## heard with the token it revokes. The session is kept in a file of the
## probe's own (Account.where), never this machine's.
##
## - kept, renewed: let in at once, the sign-in screen not up; the access
##   token waits for the renewal and is the renewed one; the new session is
##   kept;
## - kept, refused: let in at once, then signed out when Supabase refuses
##   it, the screen up with the form and why, the kept session gone;
## - signed out while it is renewed: the sign-out waits for the renewal and
##   revokes the renewed session, which is not kept;
## - nothing kept: the sign-in screen, as a first visit meets it.
extends SceneTree

var _failures: int = 0
var _server := TCPServer.new()
var _port: int = 9244
var _peers: Array[Dictionary] = []
## /api/account asks held until [member _release].
var _held: Array[StreamPeerTCP] = []
var _release: bool = false
## How the next renewal is answered: 200 or 400.
var _renewal: int = 200
var _renewals: int = 0
## The bearer token each sign-out revoked.
var _revoked: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	_serve()
	return false


func _run() -> void:
	await process_frame
	while _server.listen(_port, "127.0.0.1") != OK:
		_port += 1
		if _port > 9249:
			_ok(false, "a port to stand in for the deployment on")
			_finish()
			return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:%d" % _port)
	Account.where = "user://renewal_probe/session.json"
	DirAccess.make_dir_recursive_absolute("user://renewal_probe")

	print("\nkept, renewed")
	_keep("kept-1")
	var one: Array = await _start()
	var account: Account = one[0]
	var gate: SignInGate = one[1]
	_ok(account.lets_in() and not gate.visible,
		"a returning person is let in at once, the sign-in screen not up (state %d)" % account.state)
	_ok(account.get("renewing") == true, "...while the session kept here is renewed")
	_ok(account.email == "probe@example.com", "...as whom this device kept: %s" % account.email)
	var got: Array = [null]
	var wait_token: Callable = func() -> void: got[0] = await account.access_token()
	wait_token.call()
	await _frames(30)
	_ok(got[0] == null, "what needs the account waits for the renewal: no token yet")
	_release = true
	await _until(func() -> bool: return got[0] != null)
	_ok(str(got[0]) == "access-1", "...then has the renewed one: %s" % str(got[0]))
	_ok(account.signed_in() and account.get("renewing") == false and not gate.visible,
		"signed in, renewed, and no screen came up")
	_ok(str(_read().get("refresh_token", "")) == "refresh-1", "the renewed session is kept")
	_ok(_renewals == 1, "renewed once: %d" % _renewals)
	await _stop(one)

	print("\nkept, refused")
	_keep("kept-2")
	_renewal = 400
	var two: Array = await _start()
	account = two[0]
	gate = two[1]
	_ok(account.lets_in() and not gate.visible, "let in at once again")
	_release = true
	await _until(func() -> bool: return account.state != Account.State.SIGNED_IN)
	await _frames(5)
	_ok(account.state == Account.State.SIGNED_OUT and gate.visible,
		"Supabase refusing it signs them out, and the screen comes up")
	_ok(gate.controls_by_name().has("signin_email"), "...with the form")
	_ok(_text_on(gate).contains("Your sign-in has ended"), "...saying why")
	_ok(_read().is_empty(), "...and the session kept here is gone")
	await _stop(two)

	print("\nsigned out while it is renewed")
	_keep("kept-3")
	_renewal = 200
	var three: Array = await _start()
	account = three[0]
	gate = three[1]
	var out: Array = [false]
	var sign_out: Callable = func() -> void:
		await account.sign_out()
		out[0] = true
	sign_out.call()
	await _frames(10)
	_ok(not out[0], "Sign out waits for the renewal")
	_release = true
	await _until(func() -> bool: return out[0])
	await _frames(5)
	_ok(account.state == Account.State.SIGNED_OUT and gate.visible, "then signs out")
	_ok(_revoked.has("access-%d" % _renewals),
		"...revoking the renewed session: %s" % ", ".join(_revoked))
	_ok(_read().is_empty(), "...which is not kept")
	await _stop(three)

	print("\nnothing kept")
	_forget()
	var four: Array = await _start()
	account = four[0]
	gate = four[1]
	_ok(gate.visible, "a first visit meets the sign-in screen")
	_release = true
	await _until(func() -> bool: return account.state != Account.State.CHECKING)
	await _frames(5)
	_ok(account.state == Account.State.SIGNED_OUT and gate.visible
		and gate.controls_by_name().has("signin_email"), "...with the form")
	await _stop(four)
	_finish()


## An account, its deployment and a sign-in screen, as Main makes them.
func _start() -> Array:
	_release = false
	var deployment := Deployment.new()
	root.add_child(deployment)
	var account := Account.new()
	account.deployment = deployment
	account.keeps = true
	root.add_child(account)
	var gate := SignInGate.new()
	gate.setup(account)
	root.add_child(gate)
	await _frames(5)
	return [account, gate, deployment]


func _stop(made: Array) -> void:
	for node: Node in made:
		node.queue_free()
	_held.clear()
	await _frames(5)


func _keep(refresh: String) -> void:
	var file: FileAccess = FileAccess.open(Account.where, FileAccess.WRITE)
	file.store_string(JSON.stringify({"refresh_token": refresh, "email": "probe@example.com",
		"user_id": "00000000-0000-0000-0000-000000000001",
		"url": "http://127.0.0.1:%d" % _port, "key": "probe-key"}))
	file.close()


func _forget() -> void:
	if FileAccess.file_exists(Account.where):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Account.where))


func _read() -> Dictionary:
	if not FileAccess.file_exists(Account.where):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Account.where))
	return parsed if parsed is Dictionary else {}


# -- the host ----------------------------------------------------------------

func _serve() -> void:
	while _server.is_listening() and _server.is_connection_available():
		_peers.append({"peer": _server.take_connection(), "got": PackedByteArray()})
	for client: Dictionary in _peers.duplicate():
		var peer: StreamPeerTCP = client["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peers.erase(client)
			continue
		var available: int = peer.get_available_bytes()
		if available > 0:
			client["got"] = (client["got"] as PackedByteArray) + (peer.get_data(available)[1] as PackedByteArray)
		var text: String = (client["got"] as PackedByteArray).get_string_from_ascii()
		if not text.contains("\r\n\r\n"):
			continue
		_peers.erase(client)
		_answer(peer, text)
	if _release:
		for peer: StreamPeerTCP in _held:
			_account_answer(peer)
		_held.clear()


func _answer(peer: StreamPeerTCP, text: String) -> void:
	var path: String = text.get_slice(" ", 1)
	var bearer: String = ""
	for line: String in text.split("\r\n"):
		if line.to_lower().begins_with("authorization: bearer "):
			bearer = line.substr("authorization: bearer ".length()).strip_edges()
	if path.begins_with("/api/account"):
		if bearer.is_empty() and not _release:
			_held.append(peer)
			return
		if not bearer.is_empty():
			_send(peer, 200, {"signed_in": true, "master": false, "age": {"ask": false, "over_13": true}})
			return
		_account_answer(peer)
	elif path.begins_with("/auth/v1/token"):
		if _renewal != 200:
			_send(peer, _renewal, {"error_code": "refresh_token_not_found", "msg": "Invalid Refresh Token"})
			return
		_renewals += 1
		_send(peer, 200, {"access_token": "access-%d" % _renewals,
			"refresh_token": "refresh-%d" % _renewals, "expires_in": 3600,
			"user": {"email": "probe@example.com", "id": "00000000-0000-0000-0000-000000000001"}})
	elif path.begins_with("/auth/v1/logout"):
		_revoked.append(bearer)
		_send(peer, 204, null)
	else:
		_send(peer, 404, {})


func _account_answer(peer: StreamPeerTCP) -> void:
	_send(peer, 200, {"enabled": true, "url": "http://127.0.0.1:%d" % _port, "key": "probe-key"})


func _send(peer: StreamPeerTCP, status: int, body: Variant) -> void:
	var bytes: PackedByteArray = JSON.stringify(body).to_utf8_buffer() if body != null else PackedByteArray()
	var head: String = "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [status, {200: "OK", 204: "No Content", 400: "Bad Request", 404: "Not Found"}.get(status, "?"), bytes.size()]
	peer.put_data(head.to_ascii_buffer())
	if not bytes.is_empty():
		peer.put_data(bytes)
	peer.disconnect_from_host()


# -- reading -----------------------------------------------------------------

func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## Frames until [param test] holds, at most 20 s.
func _until(test: Callable) -> void:
	var until: int = Time.get_ticks_msec() + 20000
	while not test.call() and Time.get_ticks_msec() < until:
		await process_frame


func _text_on(node: Node) -> String:
	var words := PackedStringArray()
	for child: Node in node.find_children("*", "Label", true, false):
		if (child as Label).is_visible_in_tree():
			words.append((child as Label).text)
	return " ".join(words)


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		print("  FAIL ", what)


func _finish() -> void:
	_forget()
	_server.stop()
	print("\nrenewal probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures > 0 else 0)
