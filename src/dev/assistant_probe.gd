## Ask the assistant for a real design, through the real gate.
##
##   BRICKWORKS_API=http://localhost:8799 \
##     godot --headless --path . --script src/dev/assistant_probe.gd
##
## Every piece of this has been checked on its own: the endpoint refuses
## without a token, the client signs in, the budget counts down. What
## none of that proves is that a design actually completes with the gate
## in the way — that the token is attached, still valid several minutes
## later, and that the headers coming back are read.
##
## It spends a real design against a real account and costs real money,
## which is why it is a probe you run rather than part of any build.
##
## The state below lives on the object rather than in _run. A GDScript
## lambda captures a local by value, so `finished = true` inside the
## signal handler set the lambda's own copy and the outer loop waited out
## its whole deadline — reporting a design that had in fact placed forty
## bricks as a failure.
extends SceneTree

var _finished: bool = false
var _ok: bool = false
var _summary: String = ""


func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 90:
		await process_frame

	var account: Account = main.get("_account")
	var assistant: Assistant = main.get("_assistant")
	if not assistant.direct_key.is_empty():
		print("FAIL a local key is set, so the gate is bypassed — unset ANTHROPIC_API_KEY")
		quit(1)
		return

	var email: String = "assistant+%d@brickworks.diy" % Time.get_unix_time_from_system()
	var problem: String = await account.sign_up(email, "stud-tube-plate-47")
	if not problem.is_empty():
		print("FAIL could not sign up: %s" % problem)
		quit(1)
		return
	print("  signed in as %s, %d designs" % [account.email, account.budget])

	var world: BrickWorld = main.get("_world")
	world.clear()
	main.get("_builder").lattice.clear()

	assistant.finished.connect(func(good: bool, said: String) -> void:
		_finished = true
		_ok = good
		_summary = said)
	assistant.progress.connect(func(note: String) -> void: print("    · %s" % note))

	assistant.design("a small red and white lighthouse, about 40 pieces")
	# Real milliseconds, not frames. Counting frames and calling them
	# sixtieths of a second is only true when something is pacing them;
	# headless runs uncapped, so a 420-second budget expired in about
	# four and reported a design that was still running as a failure.
	var deadline: int = Time.get_ticks_msec() + 600_000
	while not _finished and Time.get_ticks_msec() < deadline:
		await process_frame

	print("")
	print("  %s design finished: %s" % ["ok  " if _ok else "FAIL", _summary])
	print("  %s bricks placed: %d" % ["ok  " if world.brick_count() > 0 else "FAIL", world.brick_count()])
	# The proxy reports the spend in headers; the client is supposed to
	# read them rather than ask again.
	# The whole point of the conversation id: a design is a dozen round
	# trips and must still cost exactly one.
	print("  %s one design cost one: %d used of %d"
		% ["ok  " if account.used == 1 else "FAIL", account.used, account.budget])
	await account.sign_out()
	quit(0 if (_ok and world.brick_count() > 0 and account.used == 1) else 1)
