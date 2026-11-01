## How long Suggest sections takes on a big model, and what it suggests.
##
##   godot --headless --path . --script src/dev/sections_cost_probe.gd -- [--into=DIR] [--tries=3]
##       [--models=tower,10179-1]
##
## Suggest sections (SectionsUi.suggest, as the command and suggest_sections
## over MCP run it) on the Wizard's Tower, 10,105 parts, from a fresh reading
## of the model each try (Instructions.read_shape's kept reading let go, as
## after an edit), and on three sets of vendor/omr/files: 10179-1 (5,266
## parts), 42093-1 (712, Technic) and 31025-1 (543, read on the window's
## thread). On the tower it took about 5 s (rel-m231), most of it the
## planner's order and the joint graph. Pass: the tower's under BAR_MS of
## its own at least of TRIES (the time it took, less what the main thread
## waited for a CPU; three times as long at a load past the box's cores),
## and every try of a model suggesting what its first did, section for
## section and part for part. With --into, each model's suggestion is
## written there (tower.json, ...), to hold against another checkout's: a
## change made only to be quicker suggests the same.
extends SceneTree

const BAR_MS := 3000.0
const MODELS: Array = [["tower", "res://models/orthanc.ldr", true],
	["10179-1", "res://vendor/omr/files/10179-1.mpd", false],
	["42093-1", "res://vendor/omr/files/42093-1.mpd", false],
	["31025-1", "res://vendor/omr/files/31025-1.mpd", false]]

var _failures: int = 0
var _into: String = ""
var _tries: int = 3
var _models: PackedStringArray = []
var _main: Node
var _world: BrickWorld
var _store: ModelStore
var _ui: SectionsUi


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_into = arg.substr(7)
		elif arg.begins_with("--tries="):
			_tries = maxi(1, int(arg.substr(8)))
		elif arg.begins_with("--models="):
			_models = arg.substr(9).split(",", false)
	if not _into.is_empty():
		DirAccess.make_dir_recursive_absolute(_into)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(60)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_store = _main.get("_store")
	_ui = (_main.get("_shell") as Shell).sections
	for model: Array in MODELS:
		if _models.is_empty() or model[0] in _models:
			await _model(model[0], model[1], model[2])
	print("")
	print("sections cost: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	# A big model left standing at the quit can take the engine down with it.
	_world.clear()
	await _frames(10)
	quit(1 if _failures > 0 else 0)


func _model(name: String, path: String, judged: bool) -> void:
	print("\n%s" % name)
	if not FileAccess.file_exists(path):
		print("  (no %s here; skipped)" % path)
		return
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 3000:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(20)
	var first: String = ""
	var same: bool = true
	var least: float = INF
	var tries := PackedStringArray()
	var waited := PackedStringArray()
	var busy: float = 0.0
	var made: int = 0
	for attempt: int in _tries:
		# From a fresh reading each time, as after an edit.
		Instructions._shaped_lock.lock()
		Instructions._shaped = {}
		Instructions._shaped_lock.unlock()
		await _frames(3)
		var span := ProbeTime.Span.new()
		await _ui.suggest()
		span.end()
		least = minf(least, span.own)
		tries.append("%.0f" % span.own)
		waited.append("%.0f" % span.waited)
		busy = maxf(busy, span.busy)
		var said: String = _said()
		var laps := PackedStringArray()
		for lap: Array in _ui.sections.laps:
			laps.append("%s %.0f" % [lap[0], lap[1]])
		print("  try %d, %.0f ms; on the window's thread: %s" % [attempt + 1, span.own,
			", ".join(laps)])
		made = _ui.sections.suggested.size()
		if attempt == 0:
			first = said
		else:
			same = same and said == first
		await _frames(3)
	if not _into.is_empty():
		var file := FileAccess.open(_into.path_join("%s.json" % name), FileAccess.WRITE)
		file.store_string(first)
		file.close()
		# And the planner's own order, which the timeline and the booklet
		# show: the sections are read from it.
		file = FileAccess.open(_into.path_join("%s_plan.txt" % name), FileAccess.WRITE)
		file.store_string(_plan_said())
		file.close()
	var line: String = "%s (%d parts): %d sections in %.0f ms of its own at least (%s ms; %s waiting for a CPU; %s)" \
		% [name, _world.brick_count(), made, least, ", ".join(tries), ", ".join(waited),
			ProbeTime.load_said(busy)]
	if judged:
		var bar: float = BAR_MS * ProbeTime.slack(busy)
		_check("%s, the bar %.0f ms" % [line, bar], least <= bar and made >= 2)
	else:
		print("  %s" % line)
	_check("%s: each of %d tries suggested what the first did" % [name, _tries], same and made >= 2)


## Each step of the planner's order for the model as it stands: its
## number, its box, its parts and copies.
func _plan_said() -> String:
	var out := PackedStringArray()
	for step: Instructions.Step in Instructions.plan(_world, _main.get("_library"), _store.scenery):
		out.append("%d %d.%d %s %s %s | %s | %s" % [step.number, step.callout, step.callout_step,
			step.section, step.assembly, step.unsupported, str(step.brick_ids), str(step.copies)])
	return "\n".join(out)


## The suggestion as it stands, every section's parts in order with its
## name, joints, what it is built onto and the way it comes off.
func _said() -> String:
	var out: Array = []
	for made: Sections.Suggestion in _ui.sections.suggested:
		var row: Dictionary = made.to_dict()
		row["ids"] = Array(made.ids)
		row["way"] = [made.way.x, made.way.y, made.way.z]
		row["level"] = made.level
		out.append(row)
	return JSON.stringify({"why_none": _ui.sections.why_none, "sections": out}, " ")
