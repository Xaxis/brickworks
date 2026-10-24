## Walk a whole sign-in from the app's side, against the real functions.
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790 &
##   BRICKWORKS_API=http://127.0.0.1:8790 \
##     godot --headless --path . --script src/dev/account_probe.gd
##
## The endpoints can be checked with curl, which proves the server and
## nothing about [Account]: the client has its own share of the work —
## renewing a kept session, forgetting one Supabase has ended, staying
## signed in offline, redeeming a code against the right endpoint with the
## right type. This drives that half, through api/account.js, api/otp.js
## and api/admin.js as they ship and Supabase as it is.
##
## It makes throwaway accounts at Resend's test addresses (mail to them is
## accepted and delivered nowhere) and deletes them at the end. Not in the
## suite: it needs the functions running and the project's keys. Exits
## non-zero on any failure.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# A file of its own, so the session this machine uses is untouched.
	Account.where = "user://probe_session.json"
	Account._clear()

	var account: Account = await _fresh()
	_check("the deployment has accounts, at %s" % Deployment.api_base(),
		account.deployment.accounts)
	if not account.deployment.accounts:
		quit(1)
		return
	_check("nobody kept, so it starts signed out and does not let anyone in",
		account.state == Account.State.SIGNED_OUT and not account.lets_in())

	print("\nasking for a code")
	var malformed: String = await account.request_code("not-an-address")
	_check("a malformed address is refused in words: '%s'" % malformed,
		malformed == "That is not an email address.")
	var email: String = SignInHelper.throwaway("probe")
	var asked: String = await account.request_code(email)
	_check("a code is asked for and sent: '%s'" % asked, asked.is_empty())

	print("\nredeeming one")
	var wrong: String = await account.verify_code(email, "000000")
	_check("a wrong code is refused in plain words: '%s'" % wrong,
		not wrong.is_empty() and not wrong.contains("_"))
	_check("...and nobody is signed in by it", not account.signed_in())
	# Minted here because a probe has no inbox; everything after the
	# minting is the path a person's typing takes.
	var problem: String = await SignInHelper.sign_in(account, email, get_root())
	_check("the code signs in: '%s'" % problem, problem.is_empty())
	_check("signed in, and let in", account.signed_in() and account.lets_in())
	_check("as the right person: %s" % account.email, account.email == email)
	_check("with an account id", account.user_id.length() == 36)
	var token: String = await account.access_token()
	_check("with a token to show the relay", token.count(".") == 2)
	var kept: Dictionary = Account._read()
	_check("the refresh token is kept, with the address, and not the access token",
		str(kept.get("refresh_token", "")).length() > 8
		and str(kept.get("email", "")) == email and not kept.has("access_token")
		and not FileAccess.get_file_as_string(Account.where).contains(token))

	print("\nwhat the deployment says about them")
	var who: Dictionary = await _answer_of("/api/account", token)
	_check("/api/account with the token: signed in as them, not the owner",
		bool(who.get("signed_in", false)) and str(who.get("email", "")) == email
		and not bool(who.get("master", true)))
	var anyone: Dictionary = await _answer_of("/api/account", "")
	_check("...and without one: where to sign in, and the parts",
		bool(anyone.get("enabled", false)) and str(anyone.get("url", "")).begins_with("https://")
		and not str(anyone.get("key", "")).is_empty() and anyone.has("parts_url")
		and not bool(anyone.get("signed_in", true)))
	# The desktop's Sign in with orangecheck (on since m167): offered
	# wherever orangecheck takes a token, which a deployment without the
	# project's keys (a local relay without them, a unit's preview) does not.
	var oc: Dictionary = anyone.get("orangecheck", {}) if anyone.get("orangecheck") is Dictionary else {}
	var offered: bool = not account.deployment.orangecheck_native.is_empty()
	_check("...and the desktop is offered orangecheck exactly where it takes a token: %s (ready %s)"
		% ["offered" if offered else "not offered", oc.get("ready")],
		offered == bool(oc.get("ready", false)) and offered == (oc.get("native") is Dictionary))
	var admin: int = await _status("/api/admin", token)
	_check("the admin page's data is not theirs: %d, as if it were not there" % admin,
		admin == 404)
	_check("...nor anyone's without a sign-in: %d" % await _status("/api/admin", ""),
		await _status("/api/admin", "") == 401)

	print("\nstaying signed in")
	var second: Account = await _fresh()
	_check("a restart renews the kept session: signed in as %s" % second.email,
		second.signed_in() and second.email == email and not second.offline)
	_check("...and the session it kept is the renewed one",
		str(Account._read().get("refresh_token", "")) != str(kept.get("refresh_token", "")))

	print("\noffline")
	# Nothing reachable: the deployment, and the place the session is renewed.
	var online: Dictionary = Account._read()
	var unreachable: Dictionary = online.duplicate()
	unreachable["url"] = "http://127.0.0.1:9"
	Account._write(unreachable)
	var api: String = OS.get_environment("BRICKWORKS_API")
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var away: Account = await _fresh()
	_check("with nothing reachable it stays signed in, as %s, and says so" % away.email,
		away.signed_in() and away.lets_in() and away.offline and away.email == email)
	OS.set_environment("BRICKWORKS_API", api)
	Account._write(online)
	var back: Account = await _fresh()
	_check("back online, it is confirmed again", back.signed_in() and not back.offline)

	print("\na session that has been ended elsewhere")
	var ended_token: String = str(Account._read().get("refresh_token", ""))
	var ended_copy: Dictionary = Account._read()
	await back.sign_out()
	_check("signing out signs out and forgets the session on this device",
		not back.signed_in() and Account._read().is_empty())
	# The token that was revoked, put back as though the sign-out had
	# happened on another device.
	_check("(the revoked token was the kept one)", not ended_token.is_empty())
	Account._write(ended_copy)
	var stale: Account = await _fresh()
	_check("a revoked session is not let in: '%s'" % stale.ended,
		stale.state == Account.State.SIGNED_OUT and not stale.ended.is_empty())
	_check("...and is forgotten", Account._read().is_empty())

	print("\nasking too often")
	var flood: String = SignInHelper.throwaway("flood")
	var refused: String = ""
	for attempt: int in 6:
		var said: String = await account.request_code(flood)
		if not said.is_empty():
			refused = said
			break
	_check("asking for codes over and over is refused: '%s'" % refused,
		refused.begins_with("Too many codes"))

	var gone: int = await SignInHelper.delete_accounts("delivered+bwprobe", get_root())
	gone += await SignInHelper.delete_accounts("delivered+bwflood", get_root())
	print("\n(removed %d throwaway account(s))" % gone)
	Account._clear()
	Account.where = "user://session.json"
	print("")
	print("%d FAILED" % _failures if _failures else "signing in works from the app's side")
	quit(1 if _failures else 0)


## A new Account and its own deployment question, as a fresh start makes
## them, once it has worked out who is here.
func _fresh() -> Account:
	var deployment := Deployment.new()
	get_root().add_child(deployment)
	var account := Account.new()
	account.deployment = deployment
	get_root().add_child(account)
	while account.state == Account.State.CHECKING:
		await account.changed
	return account


func _answer_of(path: String, token: String) -> Dictionary:
	var got: Array = await _call(path, token)
	var json := JSON.new()
	return json.data if json.parse(got[1]) == OK and json.data is Dictionary else {}


func _status(path: String, token: String) -> int:
	return int((await _call(path, token))[0])


func _call(path: String, token: String) -> Array:
	var http := HTTPRequest.new()
	get_root().add_child(http)
	var headers := PackedStringArray()
	if not token.is_empty():
		headers.append("authorization: Bearer " + token)
	http.request(Deployment.api_base() + path, headers)
	var done: Array = await http.request_completed
	http.queue_free()
	return [int(done[1]), (done[3] as PackedByteArray).get_string_from_utf8()]


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
