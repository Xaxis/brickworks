## Signing a probe in, without an inbox.
##
## The app's own path is: ask the server for a code, read the email,
## type it. A probe has no email, so it mints the code the way the
## server does — Supabase admin generate_link, which returns the code
## and sends nothing — and then redeems it through exactly the client
## call a person's typing would reach.
##
## Only the minting is shortcut. The redemption, the session, the token
## and everything after are the real thing, which is the half that has
## broken before.
##
## Needs SUPABASE_SECRET_KEY, so it only ever runs from a machine that
## has .env. Nothing here ships.
class_name SignInHelper
extends RefCounted


## Sign [param account] in as [param email], creating it if new.
## Returns an empty string on success.
static func sign_in(account: Account, email: String, host: Node) -> String:
	var url: String = _env("SUPABASE_URL")
	var secret: String = _env("SUPABASE_SECRET_KEY")
	if url.is_empty() or secret.is_empty():
		return "no SUPABASE_URL / SUPABASE_SECRET_KEY in .env"

	var request := HTTPRequest.new()
	request.timeout = 30.0
	host.add_child(request)
	var started: int = request.request(
		url.rstrip("/") + "/auth/v1/admin/generate_link",
		PackedStringArray([
			"content-type: application/json",
			"apikey: " + secret,
			"authorization: Bearer " + secret,
		]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"type": "magiclink", "email": email}))
	if started != OK:
		request.queue_free()
		return "could not reach Supabase to mint a code"

	var result: Array = await request.request_completed
	request.queue_free()
	var parsed: Variant = JSON.parse_string(
		(result[3] as PackedByteArray).get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return "Supabase did not answer with a code"

	var body: Dictionary = parsed
	var nested: Dictionary = body.get("properties", {})
	var code: String = str(body.get("email_otp", nested.get("email_otp", "")))
	if code.is_empty():
		return "no code in the reply: %s" % str(body).substr(0, 120)

	return await account.verify_code(email, code)


static func _env(name: String) -> String:
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
