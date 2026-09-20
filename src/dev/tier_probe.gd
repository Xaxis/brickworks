## Who is allowed to use the assistant, and on whose money.
##
##   BRICKWORKS_API=... ANTHROPIC_API_KEY=... \
##     godot --headless --path . --script src/dev/tier_probe.gd
##
## Two rules, and getting either wrong costs somebody money.
##
## Our key answers for one account and refuses everybody else. If that
## refusal breaks open, this deployment is paying for every stranger who
## signs up.
##
## A key belonging to the person goes straight from their machine to
## Anthropic. If that ever routes through our proxy instead, we are
## holding a credential we promised never to see.
extends SceneTree

var _failures: int = 0
var _finished: bool = false
var _ok: bool = false
var _summary: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	OwnKey.forget()
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 140:
		await process_frame

	var account: Account = main.get("_account")
	var assistant: Assistant = main.get("_assistant")
	assistant.direct_key = ""

	# An ordinary account, which is to say not the master one.
	var email: String = "tier+%d@brickworks.diy" % Time.get_unix_time_from_system()
	var problem: String = await SignInHelper.sign_in(account, email, main)
	if not problem.is_empty():
		print("FAIL sign up: %s" % problem)
		quit(1)
		return
	_check("signed in as somebody ordinary", account.signed_in())
	_check("the assistant is not included for them",
		not account.assistant_included())
	_check("no key of their own yet", not OwnKey.has_key())

	# The proxy has to refuse, and say what to do about it.
	assistant.finished.connect(func(good: bool, said: String) -> void:
		_finished = true
		_ok = good
		_summary = said)

	_finished = false
	assistant.design("a red 2 x 4 brick")
	var deadline: int = Time.get_ticks_msec() + 90_000
	while not _finished and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("our key refuses them: %s" % _summary, not _ok)
	_check("...and the refusal says to bring a key",
		_summary.to_lower().contains("own anthropic key"))

	# Now with a key of their own, which must go somewhere else entirely.
	var real: String = OS.get_environment("ANTHROPIC_API_KEY")
	if real.is_empty():
		print("  (no ANTHROPIC_API_KEY — skipping the half that spends money)")
	else:
		_check("a key is accepted: %s" % OwnKey.remember(real),
			OwnKey.remember(real).is_empty())
		_check("the assistant picks it up", assistant.key_in_use() == real)
		_check("...and the fingerprint hides most of it",
			not OwnKey.fingerprint().contains(real.substr(20, 10)))

		_finished = false
		assistant.design("a single red 2 x 4 brick on the ground, one piece")
		deadline = Time.get_ticks_msec() + 300_000
		while not _finished and Time.get_ticks_msec() < deadline:
			await process_frame
		_check("their own key designs: %s" % _summary, _ok)

		OwnKey.forget()
		_check("forgetting leaves nothing", not OwnKey.has_key())
		_check("...and the assistant falls back to the proxy",
			assistant.key_in_use().is_empty())

	await account.sign_out()
	print("")
	print("%d failed" % _failures if _failures else "the tiers hold")
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
