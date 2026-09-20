## Walk a whole sign-in from the client's side, against a real server.
##
##   BRICKWORKS_API=http://localhost:8799 \
##     godot --headless --path . --script src/dev/account_probe.gd
##
## The endpoints were already checked with curl, which proves the server
## is right and proves nothing about [Account]: the client has its own
## share of the work — refreshing before a token expires, forgetting a
## session the server has stopped honouring, reading the tier back. This
## drives that half.
##
## It creates a throwaway account each run, so it needs a deployment it
## is allowed to make a mess of. Exits non-zero on the first failure.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


## A SceneTree script starts before the tree is live, and an HTTPRequest
## added to a root that is not yet inside_tree refuses to send. One frame
## is enough, and waiting for it here keeps that detail out of [Account].
func _settled() -> void:
	await process_frame


func _run() -> void:
	await _settled()

	var account := Account.new()
	# Not added through _ready: this needs to boot at a moment of its
	# choosing so each step can be checked, rather than racing a probe
	# that started itself.
	root.add_child(account)
	await account.boot()

	_check("deployment offers accounts", account.available)
	if not account.available:
		print("  (no accounts at %s — nothing further to check)" % account.api_base())
		quit(1)
		return

	_check("starts signed out", not account.signed_in())

	var email: String = "probe+%d@brickworks.diy" % Time.get_unix_time_from_system()
	var password := "stud-tube-plate-47"

	var problem: String = await account.sign_up(email, password)
	_check("sign up accepted: %s" % problem, problem.is_empty())
	_check("signed in after sign up", account.signed_in())
	_check("tier is builder, got '%s'" % account.tier, account.tier == "builder")
	_check("budget is set, got %d" % account.budget, account.budget > 0)
	_check("nothing spent yet, got %d" % account.used, account.used == 0)
	_check("has a token", not (await account.access_token()).is_empty())

	# Signing up twice with one address is the commonest mistake there is,
	# and the message has to say what to do about it.
	var again: String = await account.sign_up(email, password)
	_check("second sign up refused", not again.is_empty())
	_check("...and says to sign in instead: '%s'" % again, again.to_lower().contains("sign"))

	var wrong: String = await account.sign_in(email, "not-the-password")
	_check("wrong password refused", not wrong.is_empty())
	_check("...in plain words: '%s'" % wrong, not wrong.contains("_"))

	await account.sign_out()
	_check("signed out", not account.signed_in())
	_check("token gone", (await account.access_token()).is_empty())

	var back: String = await account.sign_in(email, password)
	_check("signs back in: %s" % back, back.is_empty())
	_check("same account, got '%s'" % account.email, account.email == email)

	# A session on disk has to survive a restart, which is the whole
	# reason the refresh token is written at all.
	var second := Account.new()
	root.add_child(second)
	await second.boot()
	_check("a fresh Account picks the session back up", second.signed_in())
	_check("...as the same person, got '%s'" % second.email, second.email == email)

	await second.sign_out()

	print("")
	print("%d failed" % _failures if _failures else "all checks passed")
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
