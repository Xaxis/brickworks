## Ask the assistant to add to a model it did not build.
##
##   BRICKWORKS_API=http://localhost:8799 \
##     godot --headless --path . --script src/dev/revise_probe.gd
##
## This is the scenario look_at_model exists for. Someone builds
## something by hand and asks for an addition; the assistant has no
## memory of it and no way to see it, so before that tool the only
## possible outcome was a second, unrelated model built beside the
## first — and since submitting replaces what the assistant placed, a
## revision that ignored the existing model quietly discarded it.
##
## Spends one design against a real account.
extends SceneTree

var _finished: bool = false
var _ok: bool = false
var _summary: String = ""
var _looked: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 120:
		await process_frame

	var account: Account = main.get("_account")
	var assistant: Assistant = main.get("_assistant")
	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	if not assistant.direct_key.is_empty():
		print("FAIL a local key bypasses the gate — unset ANTHROPIC_API_KEY")
		quit(1)
		return

	var problem: String = await SignInHelper.sign_in(account,
		"revise+%d@brickworks.diy" % Time.get_unix_time_from_system(), main)
	if not problem.is_empty():
		print("FAIL sign up: %s" % problem)
		quit(1)
		return

	# A hut, by hand: four walls two bricks high on a 4 x 4 footprint.
	world.clear()
	builder.lattice.clear()
	var mine: PackedInt64Array = PackedInt64Array()
	for level: int in 2:
		for step: int in 4:
			for wall: int in 4:
				var x: float = 0.0
				var z: float = 0.0
				match wall:
					0: x = step * 20.0; z = 0.0
					1: x = 60.0; z = step * 20.0
					2: x = step * 20.0; z = 60.0
					3: x = 0.0; z = step * 20.0
				var at := Transform3D(Basis.IDENTITY,
					Vector3(x + 10.0, level * 24.0 + 24.0, z + 10.0))
				var id: int = world.add_brick("3005", 14, at)
				if id != 0:
					builder.register(id, "3005", at)
					mine.append(id)
	print("  built %d bricks by hand" % mine.size())

	assistant.progress.connect(func(note: String) -> void:
		if note.contains("already built"):
			_looked = true
		print("    · %s" % note))
	assistant.finished.connect(func(good: bool, said: String) -> void:
		_finished = true
		_ok = good
		_summary = said)

	assistant.design("There is already a small hut here. Add a chimney to "
		+ "it, standing on one corner of the wall. Keep the hut exactly "
		+ "as it is.")

	var deadline: int = Time.get_ticks_msec() + 600_000
	while not _finished and Time.get_ticks_msec() < deadline:
		await process_frame

	var survived: int = 0
	for brick_id: int in mine:
		if world.get_brick(brick_id) != null:
			survived += 1

	print("")
	_say("the assistant looked at the model first", _looked)
	_say("the design finished: %s" % _summary, _ok)
	_say("the hut survived: %d of %d bricks" % [survived, mine.size()],
		survived == mine.size())
	_say("something was added: %d bricks now, was %d"
		% [world.brick_count(), mine.size()], world.brick_count() > mine.size())

	await account.sign_out()
	quit(0 if (_looked and _ok and survived == mine.size()) else 1)


func _say(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
