## Sign in with orangecheck on the desktop, through the person's own browser
## (2026-10-24, orangecheck's "Sign in from an app or a game",
## ochk.io/docs/integration/native-sign-in, whose Godot script this is).
##
## The app cannot open orangecheck's sign-in window, and cannot keep a
## secret: anybody can read what ships in it. So it listens on 127.0.0.1, at
## any free port, and opens orangecheck's authorize page in the browser with
## a PKCE challenge (RFC 7636) and that address to come back to. The person
## signs in there, and orangecheck asks them every time whether to sign in
## to Brickworks in an app on this device. The browser comes back here with
## a one-time code, which [Account] posts to the deployment with the
## verifier only this run knows (api/orangecheck.js ?op=native); the
## deployment trades it for the token and a Brickworks session. Nothing
## secret is in the app.
class_name OrangecheckSignIn
extends Node

## Over: {code, code_verifier, redirect_uri} for the deployment, or
## {reason}: "access_denied" (the person said no), "timeout" or
## "cancelled" (a newer sign-in, or one by email).
signal answered(answer: Dictionary)

## Where orangecheck is, as the deployment says (Deployment.orangecheck_native).
var project_key: String = ""
## One of the addresses the project proves, the deployment's own.
var audience: String = ""
var auth_host: String = "https://ochk.io"
var timeout_seconds: float = 300.0
## False to open nothing: a probe opens the link in a browser of its own.
var open_browser: bool = true

const CALLBACK_PATH := "/oc/callback"

## Past this, a request is no browser's coming back: answered 404, and closed.
const MOST_BYTES := 16384

var _server: TCPServer
var _peers: Array[StreamPeerTCP] = []
## What each peer has sent so far: a browser's request arrives in as many
## pieces as it likes, and is answered once its headers have ended.
var _heads: Dictionary = {}
var _verifier: String = ""
var _state: String = ""
var _redirect_uri: String = ""
var _deadline_ms: int = 0


func _ready() -> void:
	set_process(_server != null)


## Listen, and open orangecheck in the browser: the link it opened, or ""
## when nothing could listen, and nothing is answered.
func start() -> String:
	_stop()
	_server = TCPServer.new()
	# 127.0.0.1 only, any free port: never "localhost", which a hosts file
	# can point anywhere.
	if _server.listen(0, "127.0.0.1") != OK:
		_server = null
		return ""
	_redirect_uri = "http://127.0.0.1:%d%s" % [_server.get_local_port(), CALLBACK_PATH]
	var crypto := Crypto.new()
	_verifier = _b64url(crypto.generate_random_bytes(32))
	_state = _b64url(crypto.generate_random_bytes(16))
	var sha := HashingContext.new()
	sha.start(HashingContext.HASH_SHA256)
	sha.update(_verifier.to_ascii_buffer())
	var query := {
		"project": project_key,
		"redirect_uri": _redirect_uri,
		"state": _state,
		"code_challenge": _b64url(sha.finish()),
		"code_challenge_method": "S256",
	}
	if not audience.is_empty():
		query["audience"] = audience
	_deadline_ms = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	set_process(true)
	var url: String = auth_host.rstrip("/") + "/native/authorize?" + _encode(query)
	if open_browser:
		OS.shell_open(url)
	return url


## Stop listening, answered as cancelled when it was.
func cancel() -> void:
	if _server != null:
		_finish({"reason": "cancelled"})


func _exit_tree() -> void:
	_stop()


func _process(_delta: float) -> void:
	if _server == null:
		return
	if Time.get_ticks_msec() > _deadline_ms:
		_finish({"reason": "timeout"})
		return
	while _server != null and _server.is_connection_available():
		_peers.append(_server.take_connection())
	for peer: StreamPeerTCP in _peers.duplicate():
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peers.erase(peer)
			_heads.erase(peer)
			continue
		var available: int = peer.get_available_bytes()
		if available <= 0:
			continue
		var head: PackedByteArray = _heads.get(peer, PackedByteArray())
		head.append_array(peer.get_data(available)[1])
		var text: String = head.get_string_from_utf8()
		if not text.contains("\r\n\r\n") and head.size() < MOST_BYTES:
			_heads[peer] = head
			continue
		_peers.erase(peer)
		_heads.erase(peer)
		_answer(peer, text)
		if _server == null:
			return


func _answer(peer: StreamPeerTCP, head: String) -> void:
	# The request line: GET /oc/callback?code=…&state=… HTTP/1.1
	var target: String = head.get_slice("\r\n", 0).get_slice(" ", 1)
	var path: String = target.get_slice("?", 0)
	var params: Dictionary = _decode(target.get_slice("?", 1) if target.contains("?") else "")
	# Anything else on this port, or another state, is not this sign-in:
	# keep waiting.
	if path != CALLBACK_PATH or str(params.get("state", "")) != _state:
		_reply(peer, 404, "Not found.")
		return
	if params.has("code"):
		_reply(peer, 200, "Back to Brickworks to finish signing in. You can close this tab.")
		_finish({"code": str(params["code"]), "code_verifier": _verifier, "redirect_uri": _redirect_uri})
	else:
		_reply(peer, 200, "Signing in with orangecheck was cancelled. You can close this tab.")
		_finish({"reason": str(params.get("error", "access_denied"))})


func _finish(answer: Dictionary) -> void:
	_stop()
	answered.emit(answer)


func _stop() -> void:
	set_process(false)
	for peer: StreamPeerTCP in _peers:
		peer.disconnect_from_host()
	_peers.clear()
	_heads.clear()
	if _server != null:
		_server.stop()
		_server = null


func _reply(peer: StreamPeerTCP, status: int, text: String) -> void:
	var body: String = ("<!doctype html><meta charset=utf-8><title>Brickworks</title>"
		+ "<p style=\"font:16px system-ui;margin:2em\">%s</p>" % text.xml_escape())
	var bytes: PackedByteArray = body.to_utf8_buffer()
	var head: String = ("HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\n"
		+ "Content-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n") % [
		status, "OK" if status == 200 else "Not Found", bytes.size()]
	peer.put_data(head.to_utf8_buffer())
	peer.put_data(bytes)
	peer.disconnect_from_host()


static func _b64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


static func _encode(query: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in query:
		parts.append("%s=%s" % [key, str(query[key]).uri_encode()])
	return "&".join(parts)


static func _decode(query: String) -> Dictionary:
	var out := {}
	for pair: String in query.split("&", false):
		out[pair.get_slice("=", 0).uri_decode()] = pair.get_slice("=", 1).uri_decode() if pair.contains("=") else ""
	return out
