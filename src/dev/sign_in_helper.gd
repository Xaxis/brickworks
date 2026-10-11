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


## A throwaway address for one run of a probe.
static func throwaway(label: String) -> String:
	return "delivered+bw%s%d@%s" % [label, Time.get_unix_time_from_system(), TEST_DOMAIN]


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
	var got: Dictionary = await admin(host, HTTPClient.METHOD_POST,
		"/auth/v1/admin/generate_link",
		JSON.stringify({"type": "magiclink", "email": email}))
	var body: Variant = got.get("body")
	if typeof(body) != TYPE_DICTIONARY:
		return "!Supabase did not answer with a code"
	var nested: Dictionary = (body as Dictionary).get("properties", {})
	var code: String = str((body as Dictionary).get("email_otp", nested.get("email_otp", "")))
	return code if not code.is_empty() else "!no code in the reply"


## The accounts a probe made, gone: every address that starts with
## [param prefix]. Returns how many.
static func delete_accounts(prefix: String, host: Node) -> int:
	if not prefix.begins_with("delivered+bw"):
		return 0
	var listed: Dictionary = await admin(host, HTTPClient.METHOD_GET,
		"/auth/v1/admin/users?page=1&per_page=1000", "")
	var body: Variant = listed.get("body")
	if typeof(body) != TYPE_DICTIONARY:
		return 0
	var gone: int = 0
	for user: Variant in (body as Dictionary).get("users", []) as Array:
		var address: String = str((user as Dictionary).get("email", ""))
		if address.begins_with(prefix):
			var done: Dictionary = await admin(host, HTTPClient.METHOD_DELETE,
				"/auth/v1/admin/users/" + str((user as Dictionary).get("id", "")), "")
			if int(done.get("code", 0)) == 200:
				gone += 1
	return gone


## A request to the project as the server: [code, parsed body].
static func admin(host: Node, method: int, path: String, body: String) -> Dictionary:
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
