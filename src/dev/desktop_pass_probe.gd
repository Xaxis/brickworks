## The paid desktop's check at start (DesktopPass, PassGate; docs/PLANS.md
## §4, unit U6) against tokens the server's own code signs.
##
##   godot --headless --path . --script src/dev/desktop_pass_probe.gd
##
## Two RSA keys are made here, and each token is signed by api/_desktop.js
## (node tools/desktop_key.mjs sign), so what is proven is that a token the
## deployment signs verifies in the app, and one changed by a byte does not.
## Then the rules, both ways: a build released while paid opens and a later
## one asks; a token that says the desktop covers a newer build for 44 days
## and not after; a lapsed account keeps its older builds; a comp with no
## end opens anything; another account's token, another key's, a changed
## one and garbage open nothing, and are refused calmly. And the start
## itself, against a stand-in deployment: billing off opens at once as
## today and asks nothing more than once behind it; a run from source never
## checks and never asks; a start the kept tokens cover opens at once; one
## they do not waits for the answer, opens on a renewal and an answer it
## cannot have, and otherwise shows the screen, whose words and buttons are
## the plan's; and once open nothing closes it. Needs node.
extends SceneTree

const DAY := 86400.0

var _failures: int = 0
var _keys: Dictionary = {}
var _asked: Array = []
var _answer: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DesktopPass.where = "user://probe_desktop_pass.json"
	if OS.execute("node", ["--version"]) != 0:
		print("desktop_pass_probe: SKIPPED, no node to sign with")
		quit(3)
		return

	_check("a run from source never checks (DesktopPass.wanted)", not DesktopPass.wanted())
	var key: Dictionary = _make_key("one")
	var other: Dictionary = _make_key("two")
	DesktopPass.keys_for_probe = {key.kid: key.public}
	_check("each key made, with its id as the server reckons it",
		not key.kid.is_empty() and not other.kid.is_empty() and key.kid != other.kid)

	var now: float = Time.get_unix_time_from_system()
	var paid: String = _sign(key, {"sub": "u1", "plan": "pro", "desktop": true,
		"paid_through": "2026-12-01", "iat": int(now)})
	var claims: Dictionary = DesktopPass.claims_of(paid)
	_check("a token the server's code signs verifies in the app", claims.get("sub") == "u1"
		and claims.get("paid_through") == "2026-12-01" and claims.get("desktop") == true)

	# The rules, both ways.
	_covers("a build released while paid opens", [paid], "2026-11-15", now, true)
	_covers("a build released on the last paid day opens", [paid], "2026-12-01", now, true)
	var lapsed: String = _sign(key, {"sub": "u1", "plan": "free", "desktop": false,
		"paid_through": "2026-12-01", "iat": int(now)})
	_covers("a lapsed account keeps a build released while it paid", [lapsed], "2026-11-01", now, true)
	_covers("a lapsed account is asked about a build released after", [lapsed], "2027-01-10", now, false)
	var month: String = _sign(key, {"sub": "u1", "plan": "pro", "desktop": true,
		"paid_through": "2026-12-01", "iat": int(now - 30.0 * DAY)})
	var long_ago: String = _sign(key, {"sub": "u1", "plan": "pro", "desktop": true,
		"paid_through": "2026-12-01", "iat": int(now - 50.0 * DAY)})
	_covers("a newer build, offline, within 44 days of a token that says the desktop: opens",
		[month], "2027-01-10", now, true)
	_covers("the same after 44 days: asks", [long_ago], "2027-01-10", now, false)
	var comp: String = _sign(key, {"sub": "u1", "plan": "pro", "desktop": true, "paid_through": null,
		"iat": int(now - 400.0 * DAY)})
	_covers("a comp with no end opens any build", [comp], "2030-01-01", now, true)
	var free: String = _sign(key, {"sub": "u1", "plan": "free", "desktop": false, "paid_through": null,
		"iat": int(now)})
	_covers("an account that never had the desktop is asked", [free], "2026-11-01", now, false)
	_covers("another account's token opens nothing", [paid], "2026-11-15", now, false, "u2")

	# Refused, calmly: changed, another key's, garbage.
	var parts: PackedStringArray = paid.split(".")
	var forged: String = Marshalls.utf8_to_base64(JSON.stringify({"sub": "u1", "plan": "pro",
		"desktop": true, "paid_through": "2099-12-31", "iat": int(now)})) \
		.replace("+", "-").replace("/", "_").replace("=", "")
	var tampered: String = "%s.%s.%s" % [parts[0], forged, parts[2]]
	_check("a token changed after signing is refused", DesktopPass.claims_of(tampered).is_empty())
	_covers("and opens nothing", [tampered], "2026-11-15", now, false)
	var theirs: String = _sign(other, {"sub": "u1", "plan": "pro", "desktop": true,
		"paid_through": "2099-12-31", "iat": int(now)})
	_check("a token signed with a key this build does not hold is refused",
		DesktopPass.claims_of(theirs).is_empty())
	var swapped: String = "%s.%s.%s" % [parts[0], parts[1], theirs.split(".")[2]]
	_check("and another key's signature under this key's id", DesktopPass.claims_of(swapped).is_empty())
	var garbage: Array = ["", "a.b", "a.b.c", "!!.??.%%", "e30.e30.e30", paid + "x", ".."]
	var none: bool = true
	for g: String in garbage:
		none = none and DesktopPass.claims_of(g).is_empty()
	_check("garbage is refused, with no error", none)

	# The start itself.
	await _start_checks()

	print("desktop_pass_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(0 if _failures == 0 else 1)


func _covers(what: String, tokens: Array, day: String, at: float, want: bool, who: String = "u1") -> void:
	var got: Dictionary = DesktopPass.covers(tokens, who, day, at)
	_check("%s (%s)" % [what, got.why], bool(got.runs) == want)


func _start_checks() -> void:
	var now: float = Time.get_unix_time_from_system()
	var paid: String = _sign(_keys.one, {"sub": "u1", "plan": "pro", "desktop": true,
		"paid_through": "2026-12-01", "iat": int(now)})
	var renewed: String = _sign(_keys.one, {"sub": "u1", "plan": "pro", "desktop": true,
		"paid_through": "2027-02-01", "iat": int(now)})
	var lapsed: String = _sign(_keys.one, {"sub": "u1", "plan": "free", "desktop": false,
		"paid_through": "2026-12-01", "iat": int(now)})

	# A run from source, a probe, the bench: never checks, never asks.
	_reset({})
	var source: DesktopPass = await _pass(false, "2027-01-10")
	await process_frame
	_check("from source: open, and nothing asked", source.verdict == DesktopPass.Verdict.OPEN
		and _asked.is_empty() and not source.blocks())
	source.queue_free()

	# Billing off: open at once, as today, and asked once behind it.
	_reset({"code": 200, "body": {"billing": "off"}})
	var off: DesktopPass = await _pass(true, "2027-01-10", false)
	_check("billing off: open at once, before any answer", off.verdict == DesktopPass.Verdict.OPEN
		and not off.blocks())
	await _settle()
	_check("and asked once, behind it; nothing else kept", _asked.size() == 1 and off.last == "off"
		and DesktopPass._read().get("billing") == "off" and DesktopPass._read().get("tokens", []).is_empty())
	off.queue_free()
	_reset({"code": 200, "body": {"billing": "off"}})
	off = await _pass(true, "2027-01-10")
	_check("and the next start the same", off.verdict == DesktopPass.Verdict.OPEN)
	off.queue_free()

	# Billing on, a build released while paid: open at once, the token renewed behind.
	_reset({"code": 200, "body": {"billing": "test", "token": renewed}}, {"billing": "test", "tokens": [paid]})
	var covered: DesktopPass = await _pass(true, "2026-11-15", false)
	_check("billing on, a paid build: open at once", covered.verdict == DesktopPass.Verdict.OPEN)
	await _settle()
	_check("and the new token kept beside the old", covered.last == "token"
		and (DesktopPass._read().get("tokens", []) as Array).has(renewed))
	covered.queue_free()

	# A later build, the kept token lapsed: asks, and opens on a renewal.
	_reset({"code": 200, "body": {"billing": "test", "token": renewed}}, {"billing": "test", "tokens": [lapsed]})
	var later: DesktopPass = await _pass(true, "2027-01-10", false)
	_check("a later build waits for the deployment, the screen saying so",
		later.verdict == DesktopPass.Verdict.ASKING and later.blocks())
	await _settle()
	_check("and opens on a renewal", later.verdict == DesktopPass.Verdict.OPEN)
	later.queue_free()

	# A later build, Free now: the screen, with the plan's words.
	_reset({"code": 200, "body": {"billing": "test", "token": lapsed}}, {"billing": "test", "tokens": [lapsed]})
	var asks: DesktopPass = await _pass(true, "2027-01-10")
	var gate := PassGate.new()
	gate.setup(asks)
	root.add_child(gate)
	await process_frame
	var buttons: Dictionary = gate.controls_by_name()
	_check("a later build on a lapsed account: the screen", asks.verdict == DesktopPass.Verdict.CLOSED
		and gate.visible)
	_check("saying it comes with Pro, with See Pro, the web app and another account",
		gate._title.text == "This version of the desktop app comes with Pro."
		and (buttons.get("pass_see_pro") as Button).text == "See Pro"
		and (buttons.get("pass_web") as Button).text == "Open the web app"
		and (buttons.get("pass_other") as Button).text == "Sign in with another account"
		and buttons.has("pass_again"))
	_check("and where the models on this computer stay", PassGate.models_words().contains(
		ProjectSettings.globalize_path(ModelStore.SAVE_DIR)))
	# Renewed meanwhile: Check again opens it.
	_answer = {"code": 200, "body": {"billing": "test", "token": renewed}}
	await asks.recheck()
	await process_frame
	_check("Check again, after a renewal: open, the screen gone", asks.verdict == DesktopPass.Verdict.OPEN
		and not gate.visible)
	gate.queue_free()
	asks.queue_free()

	# The deployment cannot say: nothing refused. Unreachable: the screen.
	_reset({"code": 503, "body": {"billing": "test", "standing": "unknown"}}, {"billing": "test", "tokens": [lapsed]})
	var unknown: DesktopPass = await _pass(true, "2027-01-10")
	_check("the plan not known just now: open", unknown.verdict == DesktopPass.Verdict.OPEN)
	unknown.queue_free()
	_reset({"code": 0, "body": null}, {"billing": "test", "tokens": [lapsed]})
	var offline: DesktopPass = await _pass(true, "2027-01-10")
	_check("offline, nothing covering this build: the screen", offline.verdict == DesktopPass.Verdict.CLOSED)
	offline.queue_free()

	# A changed token kept: refused calmly, the screen, nothing kept of it.
	var parts: PackedStringArray = paid.split(".")
	var tampered: String = "%s.%s.%s" % [parts[0], Marshalls.utf8_to_base64(JSON.stringify({"sub": "u1",
		"plan": "pro", "desktop": true, "paid_through": "2099-12-31", "iat": int(now)})).replace("+", "-")
		.replace("/", "_").replace("=", ""), parts[2]]
	_reset({"code": 0, "body": null}, {"billing": "test", "tokens": [tampered]})
	var changed: DesktopPass = await _pass(true, "2026-11-15")
	_check("a changed token kept, offline: the screen, calmly", changed.verdict == DesktopPass.Verdict.CLOSED)
	changed.queue_free()
	_reset({"code": 200, "body": {"billing": "test", "token": tampered}}, {"billing": "test", "tokens": []})
	changed = await _pass(true, "2026-11-15")
	_check("a changed token from the deployment: never kept, and nothing refused on it",
		changed.last == "unknown" and DesktopPass._read().get("tokens", []).is_empty()
		and changed.verdict == DesktopPass.Verdict.OPEN)
	changed.queue_free()

	# Never locked mid-session: open, then an answer that would close it.
	_reset({"code": 200, "body": {"billing": "test", "token": lapsed}}, {"billing": "test", "tokens": [paid]})
	var open: DesktopPass = await _pass(true, "2026-11-15")
	_check("open on a paid build", open.verdict == DesktopPass.Verdict.OPEN)
	DesktopPass._write({"billing": "test", "tokens": [lapsed]})
	open._decide_with("token")
	await open.recheck()
	_check("an answer that would not cover it later in the session closes nothing",
		open.verdict == DesktopPass.Verdict.OPEN and not open.blocks())
	open.queue_free()


## A fresh start: [answer] is what the stand-in deployment says, [kept]
## what this device holds.
func _reset(answer: Dictionary, kept: Dictionary = {}) -> void:
	_asked.clear()
	_answer = answer
	if FileAccess.file_exists(DesktopPass.where):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DesktopPass.where))
	if not kept.is_empty():
		DesktopPass._write(kept)


## A start of [day]'s build for u1, signed in; settled first unless not [settle].
func _pass(checks: bool, day: String, settle: bool = true) -> DesktopPass:
	var account := Account.new()
	account.keeps = false
	account.state = Account.State.SIGNED_IN
	account.user_id = "u1"
	account._access = "session"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	var check := DesktopPass.new()
	check.account = account
	check.checks = checks
	check.released = day
	check.fetcher = _fetch
	# Out of the tree: in it, its own start would sign it out (no session kept).
	check.tree_exited.connect(account.free)
	root.add_child(check)
	if settle:
		await _settle()
	return check


func _settle() -> void:
	for i: int in 4:
		await process_frame


func _fetch(url: String, headers: PackedStringArray) -> Dictionary:
	_asked.append([url, headers])
	await process_frame
	return _answer


## An RSA key made here: its private half for node to sign with, its public
## half for the app, and its id reckoned as api/_desktop.js kidOf does.
func _make_key(label: String) -> Dictionary:
	var key: CryptoKey = Crypto.new().generate_rsa(2048)
	var path: String = "user://probe_key_%s.pem" % label
	key.save(path)
	var public: String = key.save_to_string(true)
	var der: PackedByteArray = Marshalls.base64_to_raw("".join(PackedStringArray(Array(public.split("\n")).filter(
		func(line: String) -> bool: return not line.begins_with("-----") and not line.is_empty()))))
	var made := {"path": ProjectSettings.globalize_path(path), "public": public,
		"kid": _sha256_hex(der).substr(0, 16)}
	_keys[label] = made
	return made


func _sha256_hex(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


## [claims] signed by the server's own code with [key]'s private half.
func _sign(key: Dictionary, claims: Dictionary) -> String:
	var out: Array = []
	OS.execute("node", [ProjectSettings.globalize_path("res://tools/desktop_key.mjs"), "sign", key.path,
		Marshalls.utf8_to_base64(JSON.stringify(claims))], out, true)
	return str(out[0]).strip_edges() if not out.is_empty() else ""
