## The desktop's orangecheck listener on its own (OrangecheckSignIn,
## 2026-10-24), headless: no browser and nothing beyond 127.0.0.1.
##
##   godot --headless --path . --script src/dev/oc_listener_probe.gd
##
## A browser's request arrives in as many pieces as it likes, so the
## listener reads until the end of the headers before it answers
## (site-attest's nit): a request line split across two writes signs in,
## where reading the first piece alone answered it 404 and kept waiting.
## Also another path, or another state, answered 404 while it waits on;
## the person saying no; and a newer sign-in cancelling this one.
## Exits non-zero on any failure.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("a request line split in two")
	var first := _listener()
	var answers: Array[Dictionary] = []
	first.answered.connect(func(answer: Dictionary) -> void: answers.append(answer))
	var link: String = first.start()
	var query: Dictionary = OrangecheckSignIn._decode(link.get_slice("?", 1))
	var redirect: String = str(query.get("redirect_uri", ""))
	var state: String = str(query.get("state", ""))
	var port: int = int(redirect.get_slice(":", 2).get_slice("/", 0))
	_check("it listens at 127.0.0.1, at %d, with a state of its own" % port,
		redirect.begins_with("http://127.0.0.1:") and redirect.ends_with("/oc/callback") and port > 0
		and state.length() >= 20 and str(query.get("code_challenge_method", "")) == "S256")

	var stray: String = await _ask(port, ["GET /favicon.ico HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"])
	_check("another path is answered 404, and it waits on", stray.begins_with("HTTP/1.1 404") and answers.is_empty())
	var other: String = await _ask(port, ["GET /oc/callback?code=nope&state=someone-else HTTP/1.1\r\n\r\n"])
	_check("another state is answered 404, and it waits on", other.begins_with("HTTP/1.1 404") and answers.is_empty())

	var split: String = await _ask(port, ["GET /oc/callback?code=abc123&st",
		"ate=%s HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n" % state.uri_encode()])
	_check("the request line split across two writes is read whole: 200, back to Brickworks",
		split.begins_with("HTTP/1.1 200") and split.contains("Back to Brickworks"))
	var got: Dictionary = answers[0] if answers.size() == 1 else {}
	_check("...and answers the code, the verifier and the redirect: %s" % JSON.stringify(got.keys()),
		str(got.get("code", "")) == "abc123" and str(got.get("code_verifier", "")).length() == 43
		and str(got.get("redirect_uri", "")) == redirect)
	first.queue_free()

	print("\nthe headers split, and the person saying no")
	var second := _listener()
	answers.clear()
	second.answered.connect(func(answer: Dictionary) -> void: answers.append(answer))
	query = OrangecheckSignIn._decode(second.start().get_slice("?", 1))
	port = int(str(query["redirect_uri"]).get_slice(":", 2).get_slice("/", 0))
	var denied: String = await _ask(port, ["GET /oc/callback?error=access_denied&state=%s HTTP/1.1\r\nHo"
		% str(query["state"]).uri_encode(), "st: 127.0.0.1\r\n\r\n"])
	_check("headers split across two writes are read whole, and a no is a no",
		denied.begins_with("HTTP/1.1 200") and answers.size() == 1 and str(answers[0].get("reason", "")) == "access_denied")
	second.queue_free()

	print("\na newer sign-in")
	var third := _listener()
	answers.clear()
	third.answered.connect(func(answer: Dictionary) -> void: answers.append(answer))
	third.start()
	third.cancel()
	_check("cancelled, it answers so, once", answers.size() == 1 and str(answers[0].get("reason", "")) == "cancelled")
	third.cancel()
	_check("...and a second cancel answers nothing more", answers.size() == 1)
	third.queue_free()

	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _listener() -> OrangecheckSignIn:
	var listener := OrangecheckSignIn.new()
	listener.project_key = "pk_test_oc_listener_probe"
	listener.open_browser = false
	get_root().add_child(listener)
	return listener


## What the listener answers [pieces], written one at a time a little apart,
## as a browser may send them.
func _ask(port: int, pieces: Array) -> String:
	var peer := StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", port)
	for _n: int in 200:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		await process_frame
	for piece: String in pieces:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		peer.put_data(piece.to_utf8_buffer())
		for _n: int in 10:
			await process_frame
		await create_timer(0.2).timeout
	var reply: PackedByteArray = PackedByteArray()
	for _n: int in 300:
		peer.poll()
		var connected: bool = peer.get_status() == StreamPeerTCP.STATUS_CONNECTED
		var available: int = peer.get_available_bytes() if connected else 0
		if available > 0:
			reply.append_array(peer.get_data(available)[1])
		elif not connected:
			break
		await process_frame
	peer.disconnect_from_host()
	return reply.get_string_from_utf8()


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["pass" if ok else "FAIL", what])
