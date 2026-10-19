## Who is using Brickworks: signing in, staying signed in, signing out.
##
## Everyone who uses Brickworks has an account (2026-10-11), and the app
## is not usable until they are signed in ([SignInGate]). An account is an
## email address and nothing else. There is no password: the person asks
## for a code ([method request_code], api/otp.js emails it) and types it
## in ([method verify_code], redeemed with Supabase directly, so the
## session is between them and Supabase and passes through nothing of
## ours). There is no separate sign-up either: a code for an address
## nobody has used makes the account when it is redeemed.
##
## Supabase issues a short-lived access token and a long-lived refresh
## token. Only the refresh token is kept, with the address it belongs to
## and where to redeem it: in the browser's storage for this site on the
## web (localStorage, so it is there the moment the page reloads), and in
## the app's data directory on the desktop. Either is readable by anything
## else running as the person, which is what it is — the models saved
## beside it are too. It holds nothing but a token for this one service,
## and signing out revokes it.
##
## Signed in stays signed in. A reload, or a restart of the desktop app,
## renews the kept session with Supabase. And the desktop works offline
## once signed in: if Supabase cannot be reached at all, the person kept on
## this device is trusted until it can be, and the account panel says so.
## Only Supabase saying no — the session was revoked, or ran out — signs
## anyone out.
##
## What the account is for, so far: the platform asks for one, and a Claude
## connector belongs to one (api/mcp.js records the owner when a signed-in
## tab switches it on). The assistant still runs on the person's own key or
## their own Claude plan; nothing here is billed.
class_name Account
extends Node

## Where the session is kept on the desktop, and under what name in the
## browser's storage. A probe points these elsewhere so it never touches
## the session this machine uses.
static var where: String = "user://session.json"
static var web_key: String = "brickworks.session"

## Renew this far before the access token runs out, so a request that
## starts just under the wire does not fail halfway through.
const REFRESH_MARGIN := 120.0

## CHECKING: the deployment, or a kept session, is still being asked.
## SIGNED_OUT: nobody; the gate asks for an address. SIGNED_IN: somebody,
## confirmed by Supabase or, offline, kept on this device. UNREACHABLE:
## nobody, and nowhere to sign in either — offline on a first run.
## NOT_NEEDED: this deployment has no accounts, so nobody is asked.
enum State { CHECKING, SIGNED_OUT, SIGNED_IN, UNREACHABLE, NOT_NEEDED }

var state: int = State.CHECKING
var email: String = ""
var user_id: String = ""
## Whether this is the owner's account (MASTER_EMAIL on the deployment),
## which can open the admin page. The deployment says; the app only shows.
var master: bool = false
## Signed in from what this device kept, because Supabase could not be
## reached to confirm it.
var offline: bool = false
## Why the last session ended, in words, for the gate to say. Empty when
## nothing ended — a first visit, or a sign-out the person asked for.
var ended: String = ""
## The age question (2026-10-18, supabase/trust.sql), asked once: whether
## the deployment wants it answered, and the answer as it keeps it — true
## for 13 or over, false for under 13, null when not said or not known.
## Only the deployment decides; the app asks and shows.
var age_ask: bool = false
var over_13: Variant = null
## Asking the deployment who this is, just after a sign-in: the sign-in
## screen stays up for that one request, so the age question, when there
## is one, comes before the builder rather than over it.
var asking_who: bool = false

## What the deployment said about itself: whether it has accounts, and
## where to sign in. Set before this is added to the tree.
var deployment: Deployment
## Whether the session kept on this device is read and written. Off for a
## run nobody is sitting at — a probe, a headless or command-line run —
## which starts signed out and leaves the person's own session alone:
## renewing it replaces it, and two runs renewing the same one at once can
## end it. Set before this is added to the tree.
var keeps: bool = true

var _url: String = ""
var _key: String = ""
var _access: String = ""
var _refresh: String = ""
var _expires_at: float = 0.0
var _renewing: bool = false
## How the last renewal went, for a caller that waited on one in flight.
var _last_renewal: String = "unreachable"

## Emitted whenever any of the above changes, so the UI can redraw
## without polling.
signal changed
## A renewal finished, so anyone waiting on one can go on.
signal _renewed


func _ready() -> void:
	if keeps:
		_load()
	boot()


func signed_in() -> bool:
	return state == State.SIGNED_IN


## Whether the app may be used: somebody is signed in, or this deployment
## has no accounts to sign in to.
func lets_in() -> bool:
	return state == State.SIGNED_IN or state == State.NOT_NEEDED


## Work out who is here: wait for the deployment's answer, then renew any
## session kept on this device. Run at start-up and by "Try again".
func boot() -> void:
	state = State.CHECKING
	changed.emit()
	if deployment != null:
		await deployment.wait()
		if deployment.answered:
			if not deployment.accounts:
				state = State.NOT_NEEDED
				changed.emit()
				return
			_url = deployment.accounts_url
			_key = deployment.accounts_key

	if _refresh.is_empty():
		# Nothing kept. Whether there is somewhere to sign in decides
		# between the form and "cannot reach Brickworks".
		state = State.SIGNED_OUT if not _url.is_empty() \
			and (deployment == null or deployment.answered) else State.UNREACHABLE
		changed.emit()
		return

	var outcome: String = await _renew()
	match outcome:
		"ok":
			state = State.SIGNED_IN
			offline = false
		"refused":
			_forget("Your sign-in has ended. Sign in again to carry on.")
			state = State.SIGNED_OUT
		_:
			# Kept on this device and not refused: trusted until Supabase
			# can be asked. This is what lets the desktop work offline.
			state = State.SIGNED_IN if not email.is_empty() else State.UNREACHABLE
			offline = state == State.SIGNED_IN
	changed.emit()
	if state == State.SIGNED_IN and not offline:
		_ask_who()


## Ask for a code by email. Empty when the request was accepted, or
## something to show.
##
## "Accepted" is not "an email was sent" and cannot be: the server answers
## the same way whether or not the address has an account, because a
## sign-in form that tells them apart is a way of asking whether somebody
## is a member. It does say when the email could not be sent.
func request_code(with_email: String) -> String:
	var reply: Dictionary = await _fetch(Deployment.api_base() + "/api/otp",
		PackedStringArray(["content-type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"email": with_email.strip_edges().to_lower()}))
	var body: Variant = reply.get("body")
	var code: int = int(reply.get("code", 0))
	if code == 200:
		return ""
	if typeof(body) == TYPE_DICTIONARY and (body as Dictionary).has("error"):
		return str((body as Dictionary)["error"])
	if code == 0:
		return "Could not reach Brickworks to send a code. Check your connection."
	return "Could not send a code just now (%d). Try again in a minute." % code


## Redeem a code. Empty on success.
##
## Sent straight to Supabase rather than through our own server, so the
## session and the token it mints are between the person and Supabase.
func verify_code(with_email: String, code: String) -> String:
	if _url.is_empty() or _key.is_empty():
		return "Could not reach Brickworks to sign in. Try again in a moment."
	var tidy: String = code.strip_edges().replace(" ", "").replace("-", "")
	if tidy.is_empty():
		return "Enter the code from the email."

	var reply: Dictionary = await _fetch(_url + "/auth/v1/verify",
		PackedStringArray(["content-type: application/json", "apikey: " + _key]),
		HTTPClient.METHOD_POST,
		# type is "email", not "magiclink" and not "signup" — even when the
		# code was minted as a magiclink. The other two are accepted as
		# well-formed and answer "Token has expired or is invalid", which
		# reads as a wrong code rather than as a wrong request.
		JSON.stringify({
			"type": "email",
			"email": with_email.strip_edges().to_lower(),
			"token": tidy,
		}))
	var body: Variant = reply.get("body")
	if int(reply.get("code", 0)) == 0 or typeof(body) != TYPE_DICTIONARY:
		return "Could not reach Brickworks to sign in. Check your connection."
	if int(reply.get("code", 0)) >= 400 or not (body as Dictionary).has("access_token"):
		return _readable(body as Dictionary)

	_keep(body as Dictionary)
	ended = ""
	offline = false
	state = State.SIGNED_IN
	changed.emit()
	_ask_who()
	return ""


## Sign out of this device. This session is revoked with Supabase (other
## devices stay signed in), then forgotten here whatever Supabase said:
## a sign-out that leaves the token behind because the network was down
## is not a sign-out.
func sign_out() -> void:
	if not _access.is_empty() and not _url.is_empty():
		await _fetch(_url + "/auth/v1/logout?scope=local", PackedStringArray([
			"content-type: application/json",
			"apikey: " + _key,
			"authorization: Bearer " + _access,
		]), HTTPClient.METHOD_POST, "{}")
	_forget("")
	state = State.SIGNED_OUT if not _url.is_empty() else State.UNREACHABLE
	changed.emit()


## The access token, renewed if it is close to running out, for a request
## that has to say who is making it (the connector's switching on). Empty
## means nobody is signed in, or the session could not be renewed: the
## caller should not send the request as anyone.
func access_token() -> String:
	if state != State.SIGNED_IN:
		return ""
	if _access.is_empty() or _expires_at - Time.get_unix_time_from_system() < REFRESH_MARGIN:
		var outcome: String = await _renew()
		if outcome == "refused":
			_forget("Your sign-in has ended. Sign in again to carry on.")
			state = State.SIGNED_OUT
			changed.emit()
			return ""
		if outcome == "ok" and offline:
			offline = false
			changed.emit()
	return _access


## Renew the session with Supabase: "ok", "refused" (Supabase says the
## session is over) or "unreachable" (nothing was settled either way).
##
## Another tab or window on this device may have renewed it since this one
## read it: renewing replaces the refresh token, and the old one stops
## working. So the kept one is read again first, and a session another tab
## has signed out of is over here too.
func _renew() -> String:
	if _renewing:
		await _renewed
		return _last_renewal
	var kept: Dictionary = _read() if keeps else {"refresh_token": _refresh}
	var kept_token: String = str(kept.get("refresh_token", ""))
	if kept_token.is_empty() and not _refresh.is_empty() and state == State.SIGNED_IN:
		return "refused"
	if not kept_token.is_empty():
		_refresh = kept_token
	if _refresh.is_empty():
		return "refused"
	if _url.is_empty():
		return "unreachable"
	_renewing = true
	var reply: Dictionary = await _fetch(_url + "/auth/v1/token?grant_type=refresh_token",
		PackedStringArray(["content-type: application/json", "apikey: " + _key]),
		HTTPClient.METHOD_POST, JSON.stringify({"refresh_token": _refresh}))
	_renewing = false
	var code: int = int(reply.get("code", 0))
	var body: Variant = reply.get("body")
	var outcome: String = "unreachable"
	if code == 200 and typeof(body) == TYPE_DICTIONARY \
			and (body as Dictionary).has("access_token"):
		_keep(body as Dictionary)
		outcome = "ok"
	elif code >= 400 and code < 500 and code != 429:
		outcome = "refused"
	_last_renewal = outcome
	_renewed.emit()
	return outcome


## Who this is, asked of the deployment, which checks the token the way
## the relay does: whether it is the owner's account (the account panel's
## admin link) and whether to ask the age question. A failure leaves both
## as they were and lets them in: an offline start, or a deployment from
## before the question, asks nothing.
func _ask_who() -> void:
	if _access.is_empty():
		return
	asking_who = true
	changed.emit()
	var reply: Dictionary = await _fetch(Deployment.api_base() + "/api/account",
		PackedStringArray(["authorization: Bearer " + _access]),
		HTTPClient.METHOD_GET, "")
	asking_who = false
	var body: Variant = reply.get("body")
	if int(reply.get("code", 0)) == 200 and typeof(body) == TYPE_DICTIONARY \
			and bool((body as Dictionary).get("signed_in", false)):
		var said: Dictionary = body
		master = bool(said.get("master", false))
		_take_age(said.get("age"))
	changed.emit()


## The age as the deployment said it: {ask, over_13}, or nothing.
func _take_age(age: Variant) -> void:
	if not age is Dictionary:
		return
	age_ask = bool((age as Dictionary).get("ask", false))
	var said: Variant = (age as Dictionary).get("over_13")
	over_13 = bool(said) if said is bool else null


## Answer the age question: the month (1 to 12) and the year of birth, sent
## once to the deployment, which keeps only whether that is 13 or over
## (api/account.js) and never the date. Empty when it took the answer, or
## something to show.
func answer_age(month: int, year: int) -> String:
	var token: String = await access_token()
	if token.is_empty():
		return "Sign in again to carry on."
	var reply: Dictionary = await _fetch(Deployment.api_base() + "/api/account?op=age",
		PackedStringArray(["content-type: application/json", "authorization: Bearer " + token]),
		HTTPClient.METHOD_POST, JSON.stringify({"month": month, "year": year}))
	var body: Variant = reply.get("body")
	var code: int = int(reply.get("code", 0))
	if code == 200 and body is Dictionary:
		_take_age((body as Dictionary).get("age"))
		changed.emit()
		return ""
	if body is Dictionary and (body as Dictionary).has("error"):
		return str((body as Dictionary)["error"])
	if code == 0:
		return "Could not reach Brickworks. Check your connection and try again."
	return "Brickworks could not take that just now (%d). Try again in a minute." % code


func _keep(body: Dictionary) -> void:
	_access = str(body.get("access_token", ""))
	_refresh = str(body.get("refresh_token", _refresh))
	_expires_at = Time.get_unix_time_from_system() + float(body.get("expires_in", 3600))
	var user: Variant = body.get("user")
	if user is Dictionary:
		email = str((user as Dictionary).get("email", email))
		user_id = str((user as Dictionary).get("id", user_id))
	# The refresh token, whose it is and where to redeem it — enough to
	# renew on the next start and to say who is signed in offline. Not the
	# access token, which is stale within the hour.
	if keeps:
		_write({"refresh_token": _refresh, "email": email, "user_id": user_id,
			"url": _url, "key": _key})


func _load() -> void:
	var kept: Dictionary = _read()
	_refresh = str(kept.get("refresh_token", ""))
	email = str(kept.get("email", ""))
	user_id = str(kept.get("user_id", ""))
	# Where to redeem it, for a start with the deployment out of reach.
	# The deployment's own answer replaces these when it comes.
	_url = str(kept.get("url", ""))
	_key = str(kept.get("key", ""))


func _forget(why: String) -> void:
	_access = ""
	_refresh = ""
	_expires_at = 0.0
	email = ""
	user_id = ""
	master = false
	offline = false
	age_ask = false
	over_13 = null
	asking_who = false
	ended = why
	if keeps:
		_clear()


## The kept session, from the browser's storage or the data directory.
static func _read() -> Dictionary:
	var text: String = ""
	if OS.has_feature("web"):
		var got: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem(%s)||''}catch(e){return ''}})()"
			% JSON.stringify(web_key), true)
		text = str(got) if got != null else ""
	elif FileAccess.file_exists(where):
		text = FileAccess.get_file_as_string(where)
	if text.is_empty():
		return {}
	var json := JSON.new()
	return json.data if json.parse(text) == OK and json.data is Dictionary else {}


static func _write(kept: Dictionary) -> void:
	var text: String = JSON.stringify(kept)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"(function(){try{localStorage.setItem(%s,%s)}catch(e){}})()"
			% [JSON.stringify(web_key), JSON.stringify(text)], true)
		return
	var file: FileAccess = FileAccess.open(where, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


static func _clear() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"(function(){try{localStorage.removeItem(%s)}catch(e){}})()"
			% JSON.stringify(web_key), true)
		return
	if FileAccess.file_exists(where):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(where))


## Supabase reports failures under several keys depending on which part of
## it refused, and the raw ones read like stack traces ("otp_expired").
## The ones people actually meet, as sentences.
static func _readable(body: Dictionary) -> String:
	var raw: String = str(body.get("msg",
		body.get("error_description", body.get("message", body.get("error", "")))))
	match str(body.get("error_code", "")):
		"otp_expired", "invalid_credentials", "otp_disabled":
			return "That code is wrong or has expired. Check it, or ask for a new one."
		"over_email_send_rate_limit", "over_request_rate_limit":
			return "Too many attempts just now. Wait a minute and try again."
		"validation_failed", "email_address_invalid":
			return "That does not look like an email address."
	if raw.is_empty():
		return "Could not sign in. Try again."
	return raw.substr(0, 1).to_upper() + raw.substr(1)


## One request, one throwaway node. An HTTPRequest takes one call at a
## time, and a shared one would let a renewal land in the middle of a
## sign-in and one of them get the other's answer.
func _fetch(url: String, headers: PackedStringArray, method: int, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	if http.request(url, headers, method, body) != OK:
		http.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null}
	# Parsed through an instance rather than JSON.parse_string, which
	# pushes an engine error when the body is not JSON. It often is not:
	# a sign-out replies 204 with nothing in it.
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}
