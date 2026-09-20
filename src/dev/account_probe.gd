## Walk a whole sign-in from the client's side, against a real server.
##
##   BRICKWORKS_API=http://localhost:8799 \
##     godot --headless --path . --script src/dev/account_probe.gd
##
## The endpoints were already checked with curl, which proves the server
## is right and proves nothing about [Account]: the client has its own
## share of the work — refreshing before a token expires, forgetting a
## session the server has stopped honouring, redeeming a code against
## the right endpoint with the right type. This drives that half.
##
## It creates a throwaway account each run, so it needs a deployment it
## is allowed to make a mess of. Exits non-zero on the first failure.
extends SceneTree

var _failures: int = 0
var _host: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var account := Account.new()
	# Not added through _ready: this needs to boot at a moment of its
	# choosing so each step can be checked, rather than racing a probe
	# that started itself.
	root.add_child(account)
	_host = account
	await account.boot()

	_check("deployment offers accounts", account.available)
	if not account.available:
		print("  (no accounts at %s — nothing further to check)" % account.api_base())
		quit(1)
		return

	_check("starts signed out", not account.signed_in())

	var email: String = "probe+%d@brickworks.diy" % Time.get_unix_time_from_system()

	# Asking for a code must be accepted for an address nobody has used.
	var asked: String = await account.request_code(email)
	_check("a code can be asked for: %s" % asked, asked.is_empty())

	# A wrong code has to be refused, and say so in words.
	var wrong: String = await account.verify_code(email, "00000000")
	_check("a wrong code is refused", not wrong.is_empty())
	_check("...in plain words: '%s'" % wrong, not wrong.contains("_"))
	_check("...and nobody is signed in by it", not account.signed_in())

	# And the real one works. Minted here because a probe has no inbox;
	# everything after the minting is the path a person takes.
	var problem: String = await SignInHelper.sign_in(account, email, _host)
	_check("the code signs in: %s" % problem, problem.is_empty())
	_check("signed in", account.signed_in())
	_check("as the right person, got '%s'" % account.email, account.email == email)
	_check("tier is builder, got '%s'" % account.tier, account.tier == "builder")
	_check("has a token", not (await account.access_token()).is_empty())
	_check("the assistant is not included for them",
		not account.assistant_included())

	await account.sign_out()
	_check("signed out", not account.signed_in())
	_check("token gone", (await account.access_token()).is_empty())

	var back: String = await SignInHelper.sign_in(account, email, _host)
	_check("signs back in: %s" % back, back.is_empty())

	# A session on disk has to survive a restart, which is the whole
	# reason the refresh token is written at all.
	var second := Account.new()
	root.add_child(second)
	await second.boot()
	_check("a fresh Account picks the session back up", second.signed_in())
	_check("...as the same person, got '%s'" % second.email, second.email == email)
	await second.sign_out()

	# Asking over and over has to stop, or this is a way to bury
	# somebody's inbox on our bill.
	var refused: bool = false
	var fresh: String = "flood+%d@brickworks.diy" % Time.get_unix_time_from_system()
	for attempt: int in 6:
		if not (await account.request_code(fresh)).is_empty():
			refused = true
			break
	_check("asking for codes over and over is refused", refused)

	print("")
	print("%d failed" % _failures if _failures else "all checks passed")
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
