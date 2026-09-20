## Signing in, and what being signed in is worth.
##
## Brickworks works without an account. The whole builder — every part in
## the catalogue, placing, removing, saving, loading, the stability check
## — runs for a visitor who has never typed an email address, and none of
## it asks this class anything. That is the point of the free tier, and
## it is enforced by the fact that nothing in [Builder], [BrickWorld] or
## [PartsBin] imports this file.
##
## One thing is behind an account: the design assistant. Not to withhold
## it, but because it spends real money per request, and an endpoint
## holding an API key that anyone may call is a bill waiting to happen.
## An account is the smallest thing that makes a monthly budget mean
## something.
##
## Accounts live in Supabase, which issues a short-lived access token and
## a long-lived refresh token. Only the refresh token is kept on disk; the
## password never is. On desktop that file is plain text in the user data
## directory, which is what it is — Godot has no keychain, and anyone who
## can read that file can already read the saved models beside it. It
## holds nothing but a token for this one service, and signing out
## revokes it.
class_name Account
extends Node

## Where the account and assistant endpoints live when the app is not
## itself being served from there. The web build talks to its own origin.
const HOSTED := "https://brickworks.diy"

const SESSION_PATH := "user://session.json"

## Refresh this far before the access token actually expires, so a design
## that starts just under the wire does not fail halfway through.
const REFRESH_MARGIN := 120.0

enum State { UNKNOWN, SIGNED_OUT, SIGNED_IN }

var state: int = State.UNKNOWN
var email: String = ""
var tier: String = ""
var used: int = 0
var budget: int = 0

## False when the deployment has no accounts configured at all. The app
## then says the assistant is unavailable rather than offering a sign-in
## form that cannot work.
var available: bool = false

## Where the geometry this build did not ship is served from, as the
## deployment reports it. Empty means beside the app.
var parts_url: String = ""

## "included" when this deployment spends its own key for this account,
## "own_key" otherwise. The server decides; the app only reports it.
var _assistant_mode: String = "own_key"

var _project_url: String = ""
var _project_key: String = ""
var _access: String = ""
var _refresh: String = ""
var _expires_at: float = 0.0
var _booting: bool = false

## Emitted whenever any of the above changes, so the UI can redraw
## without polling.
signal changed


func _ready() -> void:
	_load_session()
	boot()


func signed_in() -> bool:
	return state == State.SIGNED_IN


## Whether this deployment runs the assistant on its own key for this
## account. It does that for one, and everybody else brings their own —
## there is no payment system yet and no free tier on our spend.
func assistant_included() -> bool:
	return _assistant_mode == "included"


func designs_left() -> int:
	return maxi(budget - used, 0)


## The base every endpoint hangs off. Relative on the web so a preview
## deployment talks to itself rather than to production; on desktop the
## hosted functions, unless pointed somewhere else — which is how a local
## `vercel dev` gets exercised by the real client rather than by curl.
func api_base() -> String:
	if OS.has_feature("web"):
		# Absolute, not "/api/…". HTTPRequest refuses a relative URL, and
		# the refusal here read as "this deployment has no accounts".
		return Origin.here()
	var override: String = OS.get_environment("BRICKWORKS_API")
	return override.rstrip("/") if not override.is_empty() else HOSTED


## Ask the server what it knows, with whatever token we have. This is the
## only call that has to happen before the UI can be drawn, and it
## answers both questions at once: does this deployment have accounts,
## and are we signed in to it.
func boot() -> void:
	if _booting:
		# Not a no-op: a caller that awaits this expects the answer to be
		# in place when it returns. Returning early because another probe
		# was already in flight would hand back a half-filled Account
		# that looks signed out, which is exactly what it looks like when
		# the probe has genuinely finished.
		await changed
		return
	_booting = true

	if not _refresh.is_empty() and _expires_at - Time.get_unix_time_from_system() < REFRESH_MARGIN:
		await _do_refresh()

	var body: Variant = await _probe()
	if typeof(body) != TYPE_DICTIONARY:
		# Offline, or a build with no functions behind it. Not an error
		# worth showing: everything except the assistant still works.
		# `changed` is emitted on this path too — anyone awaiting a boot
		# that failed is still waiting for it to be over.
		_booting = false
		available = false
		state = State.SIGNED_OUT
		changed.emit()
		return

	available = bool(body.get("enabled", false))
	_project_url = str(body.get("url", ""))
	_project_key = str(body.get("key", ""))
	parts_url = str(body.get("parts_url", "")) if body.get("parts_url") != null else ""

	# A cold start has the refresh token from disk and nothing else — not
	# even the address to redeem it at, which arrives in the reply above.
	# So the first probe necessarily goes out unauthenticated and comes
	# back "signed out", and treating that as the answer would throw away
	# a perfectly good session on every launch. Redeem the token now that
	# there is somewhere to redeem it, and ask again.
	var stale: bool = (not bool(body.get("signed_in", false))
		and not _refresh.is_empty() and _access.is_empty() and available)
	if stale:
		await _do_refresh()
		if not _access.is_empty():
			var second: Variant = await _probe()
			if typeof(second) == TYPE_DICTIONARY:
				body = second

	_booting = false
	_adopt_status(body)


func _probe() -> Variant:
	var headers: PackedStringArray = ["content-type: application/json"]
	if not _access.is_empty():
		headers.append("authorization: Bearer " + _access)
	var reply: Dictionary = await _fetch(
		api_base() + "/api/account", headers, HTTPClient.METHOD_GET, "")
	if reply.get("code", 0) != 200:
		return null
	return reply.get("body")


func _adopt_status(body: Dictionary) -> void:
	_assistant_mode = str(body.get("assistant", "own_key"))
	if bool(body.get("signed_in", false)):
		state = State.SIGNED_IN
		email = str(body.get("email", ""))
		tier = str(body.get("tier", "builder"))
		used = int(body.get("used", 0))
		budget = int(body.get("budget", 0))
	else:
		# The server is the authority on whether a token still counts. If
		# it says no, the one on disk is spent, and keeping it would mean
		# retrying a dead token on every request.
		if state == State.SIGNED_IN or not _refresh.is_empty():
			_clear_session()
		state = State.SIGNED_OUT
		email = ""
		tier = ""
		used = 0
		budget = 0
	changed.emit()


## Ask for a code by email. Returns an empty string when the request was
## accepted, or something to show on failure.
##
## "Accepted" is not "an email was sent" and cannot be. The server
## answers the same way whether or not the address has an account,
## because a sign-in form that distinguishes them is a way of asking
## whether somebody is a member.
##
## There is no separate sign-up. A code for an address nobody has used
## before creates the account when it is redeemed, so there is only one
## path here and only one to keep working.
func request_code(with_email: String) -> String:
	var reply: Dictionary = await _fetch(
		api_base() + "/api/otp",
		PackedStringArray(["content-type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"email": with_email.strip_edges().to_lower()}))

	var body: Variant = reply.get("body")
	var code: int = int(reply.get("code", 0))
	if code == 200:
		return ""
	if typeof(body) == TYPE_DICTIONARY and body.has("error"):
		return str(body["error"])
	if code == 0:
		return "Could not reach the sign-in service."
	return "Could not send a code (HTTP %d)." % code


## Redeem a code. Empty on success.
##
## Sent straight to Supabase rather than through our own server, so the
## session and the token it mints are between the person and Supabase
## and pass through nothing of ours.
func verify_code(with_email: String, code: String) -> String:
	if not available or _project_url.is_empty():
		return "Accounts are not available on this build."

	var tidy: String = code.strip_edges().replace(" ", "")
	if tidy.is_empty():
		return "Enter the code from the email."

	var reply: Dictionary = await _fetch(_project_url + "/auth/v1/verify",
		PackedStringArray([
			"content-type: application/json",
			"apikey: " + _project_key,
		]), HTTPClient.METHOD_POST,
		# type is "email", not "magiclink" and not "signup" — even when
		# the link was minted as a magiclink and its own
		# verification_type says signup. The other two are accepted as
		# well-formed and answer "Token has expired or is invalid",
		# which reads as a wrong code rather than as a wrong request.
		JSON.stringify({
			"type": "email",
			"email": with_email.strip_edges().to_lower(),
			"token": tidy,
		}))

	var body: Variant = reply.get("body")
	if typeof(body) != TYPE_DICTIONARY:
		return "Could not reach the sign-in service."
	if reply.get("code", 0) >= 400 or not body.has("access_token"):
		return _readable(body)

	_keep_session(body)
	await boot()
	return ""


func sign_out() -> void:
	# Tell Supabase first, so the refresh token stops working everywhere
	# rather than only on this machine — then forget it locally whatever
	# the server said, because a sign-out that leaves the token on disk
	# because the network was down is not a sign-out.
	if not _access.is_empty() and not _project_url.is_empty():
		await _fetch(_project_url + "/auth/v1/logout", PackedStringArray([
			"content-type: application/json",
			"apikey: " + _project_key,
			"authorization: Bearer " + _access,
		]), HTTPClient.METHOD_POST, "{}")
	_clear_session()
	state = State.SIGNED_OUT
	email = ""
	tier = ""
	used = 0
	budget = 0
	changed.emit()


## The token to put on an assistant request, refreshed if it is close to
## running out. Empty means "not signed in", and the caller should not
## send the request at all.
func access_token() -> String:
	if state != State.SIGNED_IN:
		return ""
	if _expires_at - Time.get_unix_time_from_system() < REFRESH_MARGIN:
		await _do_refresh()
	return _access


## Record that a design was spent, from the headers the proxy sends back,
## so the remaining count is right without another round trip.
func note_usage(spent: int, of_budget: int) -> void:
	if spent <= 0:
		return
	used = spent
	if of_budget > 0:
		budget = of_budget
	changed.emit()


func _do_refresh() -> void:
	if _refresh.is_empty() or _project_url.is_empty():
		return
	var reply: Dictionary = await _fetch(
		_project_url + "/auth/v1/token?grant_type=refresh_token",
		PackedStringArray(["content-type: application/json", "apikey: " + _project_key]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"refresh_token": _refresh}))

	var body: Variant = reply.get("body")
	if reply.get("code", 0) != 200 or typeof(body) != TYPE_DICTIONARY:
		return
	_keep_session(body)


func _keep_session(body: Dictionary) -> void:
	_access = str(body.get("access_token", ""))
	_refresh = str(body.get("refresh_token", _refresh))
	var lifetime: float = float(body.get("expires_in", 3600))
	_expires_at = Time.get_unix_time_from_system() + lifetime

	# Only the refresh token is written. The access token expires within
	# the hour and would be stale by the next launch anyway, so storing
	# it would add a secret to disk and buy nothing.
	var file: FileAccess = FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"refresh_token": _refresh}))
		file.close()


func _load_session() -> void:
	var file: FileAccess = FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_refresh = str(parsed.get("refresh_token", ""))


func _clear_session() -> void:
	_access = ""
	_refresh = ""
	_expires_at = 0.0
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


## Supabase reports failures under three different keys depending on
## which part of it refused, and the raw ones read like stack traces
## ("invalid_grant"). Turn the ones people actually hit into sentences.
static func _readable(body: Dictionary) -> String:
	var raw: String = str(body.get("msg",
		body.get("error_description", body.get("message", body.get("error", "")))))
	var code: String = str(body.get("error_code", ""))
	match code:
		"otp_expired", "invalid_credentials":
			return "That code is wrong or has expired. Ask for another."
		"over_email_send_rate_limit", "over_request_rate_limit":
			return "Too many attempts just now. Give it a minute."
		"validation_failed":
			return "That does not look like an email address."
	if raw.is_empty():
		return "Sign-in failed."
	return raw.substr(0, 1).to_upper() + raw.substr(1)


## One request, one throwaway node. HTTPRequest handles a single call at a
## time, and a shared one would mean a refresh landing in the middle of a
## sign-in and one of them getting the other's answer.
func _fetch(url: String, headers: PackedStringArray, method: int, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	if http.request(url, headers, method, body) != OK:
		http.queue_free()
		return {}
	var result: Array = await http.request_completed
	http.queue_free()

	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	# Parsed through an instance rather than JSON.parse_string, which
	# pushes an engine error when the body is not JSON. It often is not:
	# a logout replies 204 with nothing in it, and a deployment with no
	# functions behind it answers every path with the page. Neither is a
	# fault worth a red line in the log.
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(text) == OK else null
	return {"code": int(result[1]), "body": parsed}
