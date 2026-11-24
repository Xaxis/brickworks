## Sign in with Google and GitHub on the desktop (signin3, 2026-11-24): the
## real sign-in form's buttons, the real listener on 127.0.0.1, the
## deployment's /auth/<name>?app= and ?op=way_app, and the session the app
## keeps. Run against tools/web/relay_server.mjs --ways-stand-in, which
## answers Google's and GitHub's token and address calls itself; this probe
## plays the browser and the provider's sign-in page: it follows the link
## the button made, makes the code the provider would hand back (as
## tools/web/ways_stand_in.mjs codeFor does) and goes to the callback with
## the deployment's cookie, which sends the browser to the app's listener.
##
##   BRICKWORKS_API=http://127.0.0.1:11703 WAYS_APP_EMAIL=delivered+x@resend.dev \
##     godot --headless --path . --script src/dev/ways_app_probe.gd
##
## Prints "ACCOUNT <id> <address>" for its runner to delete, then a line a
## check. Exits non-zero on any failure. Not in the suite: it needs the
## relay with its stand-in.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var address: String = OS.get_environment("WAYS_APP_EMAIL")
	if address.is_empty():
		print("ways_app_probe: WAYS_APP_EMAIL names the throwaway address to sign in as")
		quit(2)
		return
	# A file of its own, so the session this machine uses is untouched.
	Account.where = "user://ways_app_probe_session.json"
	Account._clear()
	Account.opens_browser = false
	var deployment := Deployment.new()
	get_root().add_child(deployment)
	var account := Account.new()
	account.deployment = deployment
	get_root().add_child(account)
	while account.state == Account.State.CHECKING:
		await account.changed
	var form := SignInForm.new()
	form.setup(account)
	get_root().add_child(form)
	form.focus_first()
	await process_frame

	var named: Dictionary = form.controls_by_name()
	var google: Button = named["signin_google"]
	var github: Button = named["signin_github"]
	var made: Control = named["signin_made"]
	_check("the deployment at %s offers Google and GitHub: %s" % [Deployment.api_base(), JSON.stringify(deployment.ways_offered)],
		bool(deployment.ways_offered.get("google", false)) and bool(deployment.ways_offered.get("github", false)))
	_check("signed out, the form offers Sign in with Google and with GitHub, each with its mark",
		account.state == Account.State.SIGNED_OUT and google.is_visible_in_tree() and github.is_visible_in_tree()
		and google.text == "Sign in with Google" and github.text == "Sign in with GitHub"
		and google.icon != null and github.icon != null)
	_check("...and one line that signing in without orangecheck also makes the orangecheck account, with what that is",
		made.is_visible_in_tree() and _text_of(made).contains("Signing in without orangecheck also makes your orangecheck account."))
	if not google.is_visible_in_tree():
		quit(1)
		return

	google.pressed.emit()
	await process_frame
	var link: String = account.orangecheck_link
	var start := link.split("?")[0]
	var query: Dictionary = _query_of(link)
	_check("a press opens the deployment's /auth/google with a loopback, a state and a PKCE challenge: %s" % link.left(90),
		start == Deployment.api_base() + "/auth/google" and str(query.get("app", "")).begins_with("http://127.0.0.1:")
		and str(query.get("state", "")).length() >= 16 and str(query.get("code_challenge", "")).length() == 43)

	# The browser: the deployment sends it to Google with its cookie.
	var first: Dictionary = await _hop(link, "")
	var authorize: String = str(first["headers"].get("location", ""))
	var cookie: String = _cookie_named(first["cookies"], "bw_way_google")
	_check("the deployment sends the browser to Google, with its own sealed cookie (%d)" % int(first["code"]),
		int(first["code"]) == 302 and authorize.begins_with("https://accounts.google.com/") and not cookie.is_empty())
	# Google's sign-in page: the code it would hand back for this address,
	# as a Workspace account of its domain (Google vouches for no other).
	var asked: Dictionary = _query_of(authorize)
	var code: String = Marshalls.utf8_to_base64(JSON.stringify({"email": address, "verified": true,
		"hd": address.get_slice("@", 1),
		"client": asked.get("client_id", ""), "challenge": asked.get("code_challenge", ""),
		"nonce": asked.get("nonce", ""), "redirect": asked.get("redirect_uri", "")})) \
		.replace("+", "-").replace("/", "_").replace("=", "")
	var back: Dictionary = await _hop(str(asked.get("redirect_uri", "")) + "?code=%s&state=%s" % [code.uri_encode(),
		str(asked.get("state", "")).uri_encode()], cookie)
	var home: String = str(back["headers"].get("location", ""))
	_check("the callback sends the browser back to the app's own listener, with its state (%d)" % int(back["code"]),
		int(back["code"]) == 302 and home.begins_with(str(query.get("app", "")))
		and str(_query_of(home).get("state", "")) == str(query.get("state", "")))
	# The browser lands on the listener: the app takes it from there.
	var landed: Dictionary = await _hop(home, "")
	_check("the listener answers the browser with a page (%d)" % int(landed["code"]), int(landed["code"]) == 200)

	var waited: int = 0
	while not account.signed_in() and waited < 60:
		await create_timer(0.5).timeout
		waited += 1
	_check("signed in once the browser came back: %s" % account.email, account.signed_in()
		and account.email == address.to_lower())
	_check("...and the listener is gone", account.orangecheck_link.is_empty()
		and account.get_children().filter(func(n: Node) -> bool: return n is OrangecheckSignIn).is_empty())
	print("ACCOUNT %s %s" % [account.user_id, account.email])
	var token: String = await account.access_token()
	var who: Dictionary = await _answer_of("/api/account", token)
	_check("/api/account with its token: signed in as that account",
		bool(who.get("signed_in", false)) and str(who.get("email", "")) == account.email)
	var kept: Dictionary = Account._read()
	_check("the refresh token is kept, with the address, and not the access token",
		str(kept.get("refresh_token", "")).length() > 8 and str(kept.get("email", "")) == account.email
		and not FileAccess.get_file_as_string(Account.where).contains(token))
	await account.sign_out()
	_check("and it signs out", not account.signed_in() and Account._read().is_empty())
	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _query_of(url: String) -> Dictionary:
	var out: Dictionary = {}
	var at: int = url.find("?")
	if at < 0:
		return out
	for pair: String in url.substr(at + 1).split("&", false):
		var parts: PackedStringArray = pair.split("=", true, 1)
		out[parts[0].uri_decode()] = parts[1].uri_decode() if parts.size() > 1 else ""
	return out


func _cookie_named(cookies: PackedStringArray, name: String) -> String:
	for line: String in cookies:
		if line.begins_with(name + "="):
			return line.split(";")[0]
	return ""


## [url] fetched as a browser would, one hop: no redirect followed.
func _hop(url: String, cookie: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.max_redirects = 0
	get_root().add_child(http)
	var headers := PackedStringArray()
	if not cookie.is_empty():
		headers.append("cookie: " + cookie)
	http.request(url, headers)
	var got: Array = await http.request_completed
	http.queue_free()
	var named: Dictionary = {}
	var cookies := PackedStringArray()
	for line: String in got[2] as PackedStringArray:
		var at: int = line.find(":")
		if at < 0:
			continue
		var key: String = line.left(at).strip_edges().to_lower()
		var value: String = line.substr(at + 1).strip_edges()
		if key == "set-cookie":
			cookies.append(value)
		else:
			named[key] = value
	return {"code": got[1], "headers": named, "cookies": cookies}


func _text_of(node: Node) -> String:
	var text: String = ""
	if node is Label:
		text += (node as Label).text + "\n"
	for child: Node in node.get_children():
		text += _text_of(child)
	return text


func _answer_of(path: String, token: String) -> Dictionary:
	var http := HTTPRequest.new()
	get_root().add_child(http)
	http.request(Deployment.api_base() + path, PackedStringArray(["authorization: Bearer " + token]))
	var got: Array = await http.request_completed
	http.queue_free()
	var json := JSON.new()
	var text: String = (got[3] as PackedByteArray).get_string_from_utf8()
	return json.data if json.parse(text) == OK and json.data is Dictionary else {}


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["pass" if ok else "FAIL", what])
