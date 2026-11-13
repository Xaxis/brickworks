## Signing a probe in, without an inbox.
##
## The app's own path is: ask the server for a code, read the email,
## type it. A probe has no email, so it mints the code the way the
## server does — Supabase admin generate_link, which returns the code
## and sends nothing — and then redeems it through exactly the client
## call a person's typing reaches ([method Account.verify_code]).
##
## Only the minting is shortcut. The redemption, the session, the token
## and everything after are the real thing, which is the half that has
## broken before.
##
## Needs SUPABASE_URL and SUPABASE_SECRET_KEY, so it only ever runs from a
## machine that has .env. Nothing here ships.
class_name SignInHelper
extends RefCounted

## Probes sign in at Resend's test addresses: mail to them is accepted and
## delivered nowhere, so a code that is really sent costs nobody an inbox
## and the sender no bounce.
const TEST_DOMAIN := "resend.dev"
## No run of a probe lasts a day: an account at a probe's address made longer
## ago than this is one a run stopped before its end left behind.
const LEFT_BEHIND_S := 24 * 60 * 60

## The addresses this run was given ([method throwaway]), made accounts at
## or minted codes for ([method admin], [method mint]), lower case: the only
## fresh ones [method delete_accounts] may take.
static var _made: PackedStringArray = PackedStringArray()


## A throwaway address for one run of a probe, this run's to delete.
static func throwaway(label: String) -> String:
	var email: String = "delivered+bw%s%d@%s" % [label, Time.get_unix_time_from_system(), TEST_DOMAIN]
	_mine(email)
	return email


## Sign [param account] in as [param email], creating it if new.
## Returns an empty string on success.
static func sign_in(account: Account, email: String, host: Node) -> String:
	var code: String = await mint(email, host)
	if code.begins_with("!"):
		return code.substr(1)
	return await account.verify_code(email, code)


## A code for [param email], made as api/otp.js makes one and sent nowhere;
## or "!" and why not.
static func mint(email: String, host: Node) -> String:
	var url: String = env("SUPABASE_URL")
	var secret: String = env("SUPABASE_SECRET_KEY")
	if url.is_empty() or secret.is_empty():
		return "!no SUPABASE_URL / SUPABASE_SECRET_KEY in .env"
	# The link makes the account if there is none.
	_mine(email)
	var got: Dictionary = await admin(host, HTTPClient.METHOD_POST,
		"/auth/v1/admin/generate_link",
		JSON.stringify({"type": "magiclink", "email": email}))
	var body: Variant = got.get("body")
	if typeof(body) != TYPE_DICTIONARY:
		return "!Supabase did not answer with a code"
	var nested: Dictionary = (body as Dictionary).get("properties", {})
	var code: String = str((body as Dictionary).get("email_otp", nested.get("email_otp", "")))
	return code if not code.is_empty() else "!no code in the reply"


## The accounts a probe made, gone: those at an address that starts with
## [param prefix] and that this run made ([member _made]), and any made over
## a day ago (a run stopped before its end left them). Returns how many.
##
## Never another run's that is still going, though its address starts the
## same: other units run the same probe, and a flow's addresses can begin
## with a probe's prefix. together_probe's cleanup of delivered+bwtogether
## took together_flow.mjs's desktop, delivered+bwtogetherd…, in the middle of
## its session; the cascade took its place in the session with it, and the
## flow failed every check of the desktop after (2026-11-12).
static func delete_accounts(prefix: String, host: Node) -> int:
	if not prefix.begins_with("delivered+bw"):
		return 0
	var listed: Dictionary = await admin(host, HTTPClient.METHOD_GET,
		"/auth/v1/admin/users?page=1&per_page=1000&filter=" + prefix.uri_encode(), "")
	var body: Variant = listed.get("body")
	if typeof(body) != TYPE_DICTIONARY:
		return 0
	var now: float = Time.get_unix_time_from_system()
	var gone: int = 0
	for user: Variant in (body as Dictionary).get("users", []) as Array:
		var address: String = str((user as Dictionary).get("email", "")).to_lower()
		if not address.begins_with(prefix.to_lower()):
			continue
		# "2026-11-12T19:15:16.587226Z": the seconds, in UTC.
		var made_at: String = str((user as Dictionary).get("created_at", "")).left(19)
		var left_behind: bool = made_at.length() == 19 \
			and now - Time.get_unix_time_from_datetime_string(made_at) > LEFT_BEHIND_S
		if not _made.has(address) and not left_behind:
			continue
		var done: Dictionary = await admin(host, HTTPClient.METHOD_DELETE,
			"/auth/v1/admin/users/" + str((user as Dictionary).get("id", "")), "")
		if int(done.get("code", 0)) == 200:
			gone += 1
	return gone


static func _mine(email: String) -> void:
	if not _made.has(email.to_lower()):
		_made.append(email.to_lower())


## A request to the project as the server: [code, parsed body]. An account
## made through it is this run's ([method delete_accounts]).
static func admin(host: Node, method: int, path: String, body: String) -> Dictionary:
	if method == HTTPClient.METHOD_POST and path == "/auth/v1/admin/users":
		var asked: Variant = JSON.parse_string(body)
		if asked is Dictionary and (asked as Dictionary).has("email"):
			_mine(str((asked as Dictionary)["email"]))
	var secret: String = env("SUPABASE_SECRET_KEY")
	var request := HTTPRequest.new()
	request.timeout = 30.0
	host.add_child(request)
	var started: int = request.request(env("SUPABASE_URL").rstrip("/") + path,
		PackedStringArray([
			"content-type: application/json",
			"apikey: " + secret,
			"authorization: Bearer " + secret,
		]), method, body)
	if started != OK:
		request.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await request.request_completed
	request.queue_free()
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}


static func env(name: String) -> String:
	var from_env: String = OS.get_environment(name)
	if not from_env.is_empty():
		return from_env
	var file: FileAccess = FileAccess.open("res://.env", FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with(name + "="):
			# Values may be quoted: EMAIL_FROM has angle brackets in it
			# and has to be, for any shell that sources the file.
			return line.substr(name.length() + 1).strip_edges() \
				.lstrip("\"'").rstrip("\"'")
	return ""
