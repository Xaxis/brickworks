## Whether this desktop build may run for the account signed in: the paid
## desktop's check at start (docs/PLANS.md §4, unit U6, 2026-10-29), built
## dark behind the deployment's BRICKWORKS_BILLING (api/_billing.js).
##
## Only an exported release build checks ([method wanted]): one
## tools/release.py stamped with its release day, on the desktop, holding
## at least one public key in [constant KEYS]. A run from source, every
## probe, the bench and the web never do, and nor does a build with no key
## compiled in, which is every build until the owner makes one
## (tools/desktop_key.mjs, docs/RELEASING.md).
##
## At start, once someone is signed in, the deployment is asked for a token
## (GET /api/plans?op=entitlement): a JWT the server signs RS256 with a key
## only it holds, saying the account's plan, whether it has the desktop now
## and [b]paid_through[/b], the last day it had it (api/_desktop.js). It is
## kept beside the session, with what the deployment said of billing, and
## checked here against the public half, offline. The build runs when a
## kept token of this account:
##
## - says the desktop with no end (a comp with none, the owner); or
## - has a paid_through on or after the day this build was released, so
##   every version released while somebody paid is theirs for good, a
##   lapsed account keeps its versions, and every build released before
##   billing began runs for everyone (DESKTOP_FREE_THROUGH on the server); or
## - says the desktop and is at most [constant GRACE_DAYS] days old: a
##   month's renewal and 14 days of grace, for a start offline after a
##   renewal this device has not heard of yet.
##
## Otherwise [PassGate] says the version comes with Pro, with the way to it,
## to the web app and to another account, and where the models on this
## computer are. Nothing is deleted or locked: the models stay where they
## are, and the web app opens them.
##
## Nothing is ever locked mid-session. While the deployment says billing is
## off, or has never said otherwise, the app opens at once as it always did
## and asks behind it, for the next start. Once open, it stays open until it
## quits, whatever an answer says. Only a start that the kept tokens do not
## cover waits for the deployment's answer; an answer it cannot give (the
## plan not known just now, nothing to sign with, a token this build cannot
## read) refuses nothing, since that could be somebody who pays.
##
## A token is not proof against a patched build: the cheap version, on
## purpose (PLANS.md §4, "Piracy, realistically").
class_name DesktopPass
extends Node

## The public keys a token may be signed with, by id (api/_desktop.js
## kidOf). tools/desktop_key.mjs prints the line to put here. Empty: no key
## made yet, and nothing is checked.
const KEYS: Dictionary = {}

## Days a token that says the desktop covers a newer build: 30, and 14 of
## grace (PLANS.md §4, step 3).
const GRACE_DAYS := 44

## Where the tokens are kept, beside the session ([member Account.where]).
## A probe points it elsewhere.
static var where: String = "user://desktop_pass.json"
## The keys a probe trusts, in place of [constant KEYS].
static var keys_for_probe: Dictionary = {}

## OPEN: the app may be used. ASKING: the kept tokens do not cover this
## build, and the deployment is being asked. CLOSED: this build is not the
## account's; [PassGate] says so.
enum Verdict { OPEN, ASKING, CLOSED }

var verdict: int = Verdict.OPEN
var account: Account
## Whether this run checks at all ([method wanted]). Set before this is
## added to the tree.
var checks: bool = false
## The day this build was released, "YYYY-MM-DD" (BuildInfo's stamp).
var released: String = ""
## A probe's stand-in for the deployment: (url, headers) -> {code, body}.
var fetcher: Callable
## A probe's clock, in Unix seconds; the system's when unset.
var now: float = 0.0
## What the last answer was ("off", "token", "unknown", "unreachable",
## "refused"), for a probe and the log.
var last: String = ""

## Open for the rest of the session: nothing is locked mid-session.
var _opened: bool = false
var _asking: bool = false

signal changed


## Whether this run is one that checks: an exported release build on the
## desktop, holding a key.
static func wanted() -> bool:
	return BuildInfo.is_release() and OS.has_feature("template") and not OS.has_feature("web") \
		and not _keys().is_empty()


static func _keys() -> Dictionary:
	return keys_for_probe if not keys_for_probe.is_empty() else KEYS


func _ready() -> void:
	if not checks or account == null:
		return
	account.changed.connect(_follow)
	# At once, before anything can be clicked: the kept tokens are read
	# offline, and only the deployment's answer is waited for.
	_follow()


## Whether [PassGate] is up.
func blocks() -> bool:
	return checks and verdict != Verdict.OPEN and account != null and account.signed_in()


## Ask the deployment again and decide on its answer: at a start the kept
## tokens do not cover, and from the screen (after a renewal, say).
func recheck() -> void:
	if _opened or _asking:
		return
	_asking = true
	verdict = Verdict.ASKING
	changed.emit()
	var said: String = await _ask()
	_asking = false
	_decide_with(said)


func _follow() -> void:
	if _opened or _asking or account.state != Account.State.SIGNED_IN:
		return
	var kept: Dictionary = _read()
	var on: bool = str(kept.get("billing", "off")) != "off"
	if on and not covers(kept.get("tokens", []), account.user_id, released, _now()).runs:
		await recheck()
		return
	_open()
	# Behind the open app, for the next start.
	await _ask()


func _decide_with(said: String) -> void:
	if _opened:
		return
	match said:
		"token":
			if covers(_read().get("tokens", []), account.user_id, released, _now()).runs:
				_open()
				return
		"off", "unknown":
			_open()
			return
	verdict = Verdict.CLOSED
	changed.emit()


func _open() -> void:
	_opened = true
	verdict = Verdict.OPEN
	changed.emit()


func _now() -> float:
	return now if now > 0.0 else Time.get_unix_time_from_system()


## Ask the deployment for this account's token and keep what it says:
## "off", "token", "unknown" (it cannot say just now, or signs nothing, or
## signed with a key this build does not hold), "refused" or "unreachable".
func _ask() -> String:
	var access: String = await account.access_token()
	if access.is_empty():
		last = "unreachable"
		return last
	var reply: Dictionary = await _fetch(Deployment.api_base() + "/api/plans?op=entitlement",
		PackedStringArray(["authorization: Bearer " + access]))
	var code: int = int(reply.get("code", 0))
	var body: Dictionary = reply.get("body") if reply.get("body") is Dictionary else {}
	var kept: Dictionary = _read()
	last = "unreachable"
	if code == 200 and str(body.get("billing", "")) == "off":
		kept["billing"] = "off"
		last = "off"
	elif code == 200 and body.has("token"):
		kept["billing"] = str(body.get("billing", "live"))
		var token: String = str(body.get("token", ""))
		var claims: Dictionary = claims_of(token)
		if claims.is_empty() or str(claims.get("sub", "")) != account.user_id:
			print("desktop pass: the deployment's token is not one this build can read")
			last = "unknown"
		else:
			kept["tokens"] = _pruned((kept.get("tokens", []) as Array) + [token])
			last = "token"
	elif code == 503:
		kept["billing"] = str(body.get("billing", kept.get("billing", "off")))
		last = "unknown"
	elif code == 401 or code == 403:
		last = "refused"
	if last != "unreachable" and last != "refused":
		_write(kept)
	return last


func _fetch(url: String, headers: PackedStringArray) -> Dictionary:
	if fetcher.is_valid():
		return await fetcher.call(url, headers)
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	if http.request(url, headers) != OK:
		http.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null}
	var json := JSON.new()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}


## Whether any of [tokens] lets the account [user_id] run a build released
## on [day] at [at] (Unix seconds): {runs, why}.
static func covers(tokens: Variant, user_id: String, day: String, at: float) -> Dictionary:
	var why: String = "no token of this account"
	if not tokens is Array or user_id.is_empty():
		return {"runs": false, "why": why}
	for token: Variant in tokens:
		var claims: Dictionary = claims_of(str(token))
		if claims.is_empty():
			why = "a token that does not check out"
			continue
		if str(claims.get("sub", "")) != user_id:
			continue
		var desktop: bool = claims.get("desktop") == true
		var through: Variant = claims.get("paid_through")
		if desktop and through == null:
			return {"runs": true, "why": "the desktop with no end"}
		if through is String and not day.is_empty() and str(through) >= day:
			return {"runs": true, "why": "released by %s, while paid" % through}
		if desktop and at - float(claims.get("iat", 0)) <= GRACE_DAYS * 86400.0:
			return {"runs": true, "why": "the desktop, %d days ago" % int((at - float(claims.get("iat", 0))) / 86400.0)}
		why = "paid through %s, before this build (%s)" % [through, day] if through is String \
			else "an account without the desktop"
	return {"runs": false, "why": why}


## The claims of [token] when one of the keys this build holds signed it,
## else empty. Never an engine error, whatever it is handed.
static func claims_of(token: String) -> Dictionary:
	var parts: PackedStringArray = token.split(".")
	if parts.size() != 3:
		return {}
	var b64url := RegEx.create_from_string("^[A-Za-z0-9_-]+$")
	for part: String in parts:
		# One character over a whole group of four is never base64.
		if b64url.search(part) == null or part.length() % 4 == 1:
			return {}
	var header: Dictionary = _json(_bytes(parts[0]).get_string_from_utf8())
	if str(header.get("alg", "")) != "RS256":
		return {}
	var pem: String = str(_keys().get(str(header.get("kid", "")), ""))
	if pem.is_empty():
		return {}
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:
		return {}
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(("%s.%s" % [parts[0], parts[1]]).to_utf8_buffer())
	var signature: PackedByteArray = _bytes(parts[2])
	# RS256 with a 2048-bit key or more: anything shorter is not one.
	if signature.size() < 256 or not Crypto.new().verify(HashingContext.HASH_SHA256, hashing.finish(),
			signature, key):
		return {}
	return _json(_bytes(parts[1]).get_string_from_utf8())


static func _bytes(part: String) -> PackedByteArray:
	var text: String = part.replace("-", "+").replace("_", "/")
	while text.length() % 4 != 0:
		text += "="
	return Marshalls.base64_to_raw(text)


static func _json(text: String) -> Dictionary:
	var json := JSON.new()
	return json.data if json.parse(text) == OK and json.data is Dictionary else {}


## [tokens], at most the newest and the one reaching furthest of each
## account: enough to decide, and a file that never grows.
static func _pruned(tokens: Array) -> Array:
	var best: Dictionary = {}
	for token: Variant in tokens:
		var claims: Dictionary = claims_of(str(token))
		if claims.is_empty():
			continue
		var sub: String = str(claims.get("sub", ""))
		var held: Dictionary = best.get(sub, {})
		var newest: Variant = held.get("newest")
		if newest == null or float(claims.get("iat", 0)) >= float(claims_of(str(newest)).get("iat", 0)):
			held["newest"] = token
		var far: Variant = held.get("furthest")
		if far == null or _reach(claims) > _reach(claims_of(str(far))):
			held["furthest"] = token
		best[sub] = held
	var out: Array = []
	for held: Dictionary in best.values():
		for token: Variant in [held.get("newest"), held.get("furthest")]:
			if token != null and not out.has(token):
				out.append(token)
	return out


## How far [claims] reach, as a sortable day: no end furthest of all.
static func _reach(claims: Dictionary) -> String:
	if claims.get("desktop") == true and claims.get("paid_through") == null:
		return "9999-12-31"
	return str(claims.get("paid_through", "")) if claims.get("paid_through") is String else ""


static func _read() -> Dictionary:
	if not FileAccess.file_exists(where):
		return {}
	return _json(FileAccess.get_file_as_string(where))


static func _write(kept: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(where, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(kept))
		file.close()
