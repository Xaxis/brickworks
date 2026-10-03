## Do the settings change anything worth changing?
##
##   ANTHROPIC_API_KEY=... godot --path . --resolution 1200x800 \
##     --script src/dev/bakeoff_probe.gd
##
## Not in the offline suite: it runs real designs against a real key and
## costs real money, a couple of dollars a go. Run it when the choices
## change.
##
## A settings row is easy to add and worthless if the settings do not
## do anything, so this builds the same thing with each of them and
## prints what came of it: whether it finished, how many bricks, how
## long, what it cost, and whether the result stands up. Two minutes of
## reading that table is the difference between offering a choice and
## offering a decoration.
##
## Needs a window. The assistant is shown a rendering of its own work
## and a headless run falls back to letters, which is a different
## assistant from the one anybody uses.
extends SceneTree

const BRIEF := ("a red post box: a tall narrow box on a base, with a "
	+ "slot near the top and a small roof")

## Model and effort, and one of each that matters. Haiku takes no
## effort setting at all, which is the entry that proves the table is
## being honoured rather than the parameter being sent regardless.
const RUNS: Array[Dictionary] = [
	{"model": "claude-opus-5-5", "effort": "high"},
	{"model": "claude-sonnet-5-5", "effort": "low"},
	{"model": "claude-sonnet-5-5", "effort": "high"},
	{"model": "claude-sonnet-5-5", "effort": "max"},
	{"model": "claude-haiku-4-5-20251001", "effort": "high"},
]

var _done := false
var _ok := false
var _summary := ""
var _spend: Brain.Spend = null
var _spent_on := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	var assistant: Assistant = main.get("_assistant")
	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var stability: Stability = main.get("_stability")
	if assistant == null:
		print("no assistant")
		quit(1)
		return
	assistant.direct_key = OS.get_environment("ANTHROPIC_API_KEY")
	if assistant.direct_key.is_empty():
		print("no ANTHROPIC_API_KEY — this one talks to the model directly")
		quit(1)
		return

	assistant.finished.connect(func(good: bool, said: String) -> void:
		_done = true
		_ok = good
		_summary = said)
	assistant.spent.connect(func(model_id: String, tokens: Brain.Spend) -> void:
		_spent_on = model_id
		_spend = tokens)

	var was: String = Brain.chosen()
	var was_effort: String = Brain.effort()
	var rows: Array[String] = []

	for run: Dictionary in RUNS:
		var choice: Brain.Choice = Brain.find(str(run["model"]))
		Brain.choose(choice.id)
		if choice.effort:
			Brain.set_effort(str(run["effort"]))
		var label: String = "%s%s" % [choice.name,
			" · %s" % run["effort"] if choice.effort else ""]
		print("")
		print("  %s" % label)

		world.clear()
		builder.lattice.clear()
		assistant.forget_built()
		_done = false
		_spend = null

		var began: int = Time.get_ticks_msec()
		assistant.design(BRIEF)
		var deadline: int = began + 900_000
		while not _done and Time.get_ticks_msec() < deadline:
			await process_frame
		var took: float = (Time.get_ticks_msec() - began) / 1000.0

		var bricks: int = world.brick_count()
		var standing: String = "—"
		if bricks > 0 and stability != null:
			standing = stability.check(world).summary()
		var money: String = "—"
		var tokens: String = "—"
		if _spend != null:
			money = Brain.in_money(Brain.cost(_spent_on, _spend))
			tokens = "%s/%s" % [Brain.in_tokens(_spend.total_in()),
				Brain.in_tokens(_spend.made)]
		rows.append("  %-22s %-5s %6.0fs %7s %8s %6d  %s" % [
			label, "yes" if _ok else "NO", took, tokens, money, bricks,
			standing])
		print("    %s · %d bricks · %s · %s"
			% [_summary, bricks, tokens, money])

	Brain.choose(was)
	if not was_effort.is_empty():
		Brain.set_effort(was_effort)

	print("")
	print("  %-22s %-5s %7s %7s %8s %6s  %s" % [
		"setting", "done", "took", "in/out", "cost", "bricks", "holds up"])
	for row: String in rows:
		print(row)
	print("")
	print("A setting earns its place by changing a column.")
	quit(0)
