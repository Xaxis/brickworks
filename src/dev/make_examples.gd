## Design the models that ship with the app.
##
##   ANTHROPIC_API_KEY=... godot --headless --path . \
##     --script src/dev/make_examples.gd -- tree boat
##
## Names after the -- redo just those; no names redoes the lot. Most
## runs are one model: seven of the first eight were worth keeping and
## rebuilding all of them to replace one is money spent on nothing.
##
## Run deliberately, not as part of a build: it costs real money and the
## output is committed, so there is no reason to make it again unless
## the examples want changing.
##
## The Open menu needs something in it the first time somebody looks.
## Two models shipped, one of which was a test fixture, and "nothing
## saved yet" is a poor answer to "show me what this can do".
##
## Each design is checked before it is kept. A worked example that does
## not stand up teaches the wrong thing, and it would be the first thing
## anyone sees.
extends SceneTree

const BRIEFS: Array[Dictionary] = [
	{"file": "house", "brief": "a small house with a pitched red roof, a "
		+ "door and two windows, standing on a low green lawn. About 90 pieces."},
	{"file": "tree", "brief": "a broad leafy tree. A brown trunk two or "
		+ "three studs thick going up four or five bricks, then a canopy "
		+ "of green that gets wider and then narrower again as it rises "
		+ "— four layers at least, so the outline is round rather than a "
		+ "slab. No lawn, no mound: let it stand on the bare baseplate. "
		+ "About 60 pieces."},
	{"file": "bench", "brief": "a park bench in dark brown with a lamp post "
		+ "beside it. About 45 pieces."},
	{"file": "tower", "brief": "a round castle tower with battlements at "
		+ "the top and a small arched doorway. About 95 pieces."},
	{"file": "boat", "brief": "a small sailing boat with a white hull, a "
		+ "mast and a sail. About 60 pieces."},
	{"file": "rocket", "brief": "a rocket standing on a launch pad, with "
		+ "fins at the base and a red nose cone. About 70 pieces."},
]

var _finished: bool = false
var _ok: bool = false
var _summary: String = ""
var _main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame

	var assistant: Assistant = _main.get("_assistant")
	if assistant.direct_key.is_empty():
		print("no ANTHROPIC_API_KEY — this one talks to the model directly")
		quit(1)
		return

	var world: BrickWorld = _main.get("_world")
	var builder: Builder = _main.get("_builder")
	var store: ModelStore = _main.get("_store")
	var stability: Stability = _main.get("_stability")

	assistant.finished.connect(func(good: bool, said: String) -> void:
		_finished = true
		_ok = good
		_summary = said)
	assistant.progress.connect(func(note: String) -> void:
		print("      · %s" % note))

	var wanted: PackedStringArray = PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		wanted.append(argument)

	for job: Dictionary in BRIEFS:
		var name: String = str(job["file"])
		if not wanted.is_empty() and not wanted.has(name):
			continue
		print("")
		print("  %s" % name)
		world.clear()
		builder.lattice.clear()
		assistant.clear_built()
		_finished = false

		assistant.design(str(job["brief"]))
		var deadline: int = Time.get_ticks_msec() + 900_000
		while not _finished and Time.get_ticks_msec() < deadline:
			await process_frame

		if not _ok or world.brick_count() == 0:
			print("    skipped: %s" % _summary)
			continue

		var verdict: Stability.Report = stability.check(world)
		var path := "res://models/%s.ldr" % name
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			print("    could not write %s" % path)
			continue
		file.store_string(store.to_text(name.capitalize()))
		file.close()
		print("    kept %d bricks — %s" % [world.brick_count(), verdict.summary()])

	print("")
	print("done")
	quit()
