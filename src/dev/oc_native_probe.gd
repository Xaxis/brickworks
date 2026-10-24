## Sign in with orangecheck on the desktop, end to end (2026-10-24): the
## real sign-in form's button, the real listener on 127.0.0.1, the
## deployment's ?op=native, and the session the app keeps. The browser's
## half is tools/web/oc_native_flow.mjs, which runs this against
## tools/web/relay_server.mjs on orangecheck's test stack, signs a
## throwaway orangecheck account in, in Chromium, at the link this prints,
## and reads what it prints after.
##
##   BRICKWORKS_API=http://127.0.0.1:8790 \
##     godot --headless --path . --script src/dev/oc_native_probe.gd
##
## Prints "LINK <url>" once the button is pressed (the browser is never
## opened from here: Account.opens_browser), then a line a check, then
## "ACCOUNT <id> <address>" for the flow to delete. Exits non-zero on any
## failure. Not in the suite: it needs the test stack and a browser.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# A file of its own, so the session this machine uses is untouched.
	Account.where = "user://oc_native_probe_session.json"
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

	var offer: Dictionary = deployment.orangecheck_native
	_check("the deployment at %s offers the desktop's sign-in: %s" % [Deployment.api_base(), JSON.stringify(offer)],
		not offer.is_empty())
	var oc: Button = form.controls_by_name()["signin_orangecheck"]
	_check("signed out, the form offers Sign in with orangecheck",
		account.state == Account.State.SIGNED_OUT and oc.is_visible_in_tree() and oc.text == "Sign in with orangecheck")
	if offer.is_empty() or not oc.is_visible_in_tree():
		quit(1)
		return

	# Pressed twice, as somebody who closed the tab by mistake: the second
	# starts again, and only its link is any good.
	oc.pressed.emit()
	await process_frame
	var stale: String = account.orangecheck_link
	oc.pressed.emit()
	await process_frame
	var link: String = account.orangecheck_link
	_check("a press opens orangecheck's authorize page for this project, with a PKCE challenge and a loopback redirect",
		link.begins_with(str(offer["auth"]) + "/native/authorize?") and link.contains("project=" + str(offer["project"]))
		and link.contains("code_challenge_method=S256") and link.contains("redirect_uri=http%3A%2F%2F127.0.0.1%3A"))
	_check("a second press starts again, on a link of its own", not stale.is_empty() and stale != link)
	_check("...and says to finish in the browser", _text_of(form).contains("Finish signing in with orangecheck in your browser"))
	print("LINK " + link)

	var waited: int = 0
	while not account.signed_in() and waited < 240:
		await create_timer(0.5).timeout
		waited += 1
	_check("signed in once the browser came back: %s" % account.email, account.signed_in())
	_check("...as an orangecheck account, at its made-up address", account.email.ends_with("@oc.brickworks.diy")
		and account.user_id.length() == 36)
	_check("...and the listener is gone", account.orangecheck_link.is_empty()
		and account.get_children().filter(func(n: Node) -> bool: return n is OrangecheckSignIn).is_empty())
	var token: String = await account.access_token()
	var kept: Dictionary = Account._read()
	_check("the refresh token is kept, with the address, and not the access token",
		str(kept.get("refresh_token", "")).length() > 8 and str(kept.get("email", "")) == account.email
		and not FileAccess.get_file_as_string(Account.where).contains(token))
	var who: Dictionary = await _answer_of("/api/account", token)
	_check("/api/account with its token: signed in as that account",
		bool(who.get("signed_in", false)) and str(who.get("email", "")) == account.email)
	print("ACCOUNT %s %s" % [account.user_id, account.email])
	await account.sign_out()
	_check("and it signs out", not account.signed_in() and Account._read().is_empty())
	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _text_of(node: Node) -> String:
	var text: String = ""
	for child: Node in node.get_children():
		if child is Label and (child as Label).is_visible_in_tree():
			text += (child as Label).text + "\n"
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
