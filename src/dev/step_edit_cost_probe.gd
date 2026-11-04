## How long a step edit holds the window on a big model with its own steps.
##
##   godot --headless --path . --script src/dev/step_edit_cost_probe.gd -- [--into=DIR]
##
## A part moved to the next step, to the previous and made a step of its own
## (Shell.change_steps, as the timeline's buttons and edit_steps over MCP
## do) on the Wizard's Tower, 10,101 parts and 607 steps of its author's,
## and on the gatehouse, 9 parts. Each held the tower's window 2.6 to 3.5 s
## (suite236, race244): the steps of every sub-model read a sub-model at a
## time, three passes of the whole model each (BookletLooks.items_by_step),
## and the timeline planned again from what each part rests on and is joined
## to, which a step edit does not change. Pass: each edit on the tower under
## BAR_MS of its own work at least of TRIES (the time it held the window,
## less what the main thread waited for a CPU; three times as long at a load
## past the box's cores, where the work itself slows), the
## timeline's plan after it the same as one read afresh, and the undo giving
## back the file to the byte. Each edit is of a part of the same step, the
## middle one or the next with more in it than the part, which the probe
## goes back to: the timeline goes with the part an edit moves, and stays
## there when it is undone (stepsto), and the gatehouse's third edit was
## made of a part alone in its step, which "made a new step" of it and
## recorded an undo, the file unchanged (suitesteps). Such an edit says the
## steps are as they were, with nothing to undo. With --into, each edit's
## saved file is written there (tower_next.ldr, ...), to hold against
## another checkout's.
extends SceneTree

const BAR_MS := 300.0
const TRIES := 3

var _failures: int = 0
var _into: String = ""
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _steps: StepsBar
var _library: PartLibrary


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
	if not _into.is_empty():
		DirAccess.make_dir_recursive_absolute(_into)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(60)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_steps = _main.get("_steps")
	_library = _main.get("_library")
	await _model("tower", "res://models/orthanc.ldr", true)
	await _model("gatehouse", "res://tests/fixtures/steps/gatehouse.mpd", false)
	print("")
	print("step edit cost: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _model(name: String, path: String, judged: bool) -> void:
	print("\n%s" % name)
	_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 3000:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(20)
	var own: bool = AuthorSteps.any(_world, _store.scenery)
	await _steps.start(_world, _library, _store.scenery)
	await _frames(10)
	var middle: Array[Instructions.Step] = []
	for step: Instructions.Step in _steps.steps():
		if step.callout_step == 0 and step.authored_step >= 0 and not step.brick_ids.is_empty():
			middle.append(step)
	_check("opened %s: %d parts, %s, %d steps on the timeline" % [path.get_file(),
		_world.brick_count(), "the author's steps" if own else "no steps of its own",
		_steps.steps().size()], own and middle.size() >= 3)
	if middle.size() < 3:
		return
	var number: int = middle[-1].number
	for step: Instructions.Step in middle.slice(middle.size() / 2):
		if step.brick_ids.size() > 1 or not step.copies.is_empty():
			number = step.number
			break
	for op: String in ["next", "prev", "new"]:
		_steps.refresh(number)
		var at: Instructions.Step = _steps.current_step()
		var before: String = _store.to_text("probe", true)
		var depth: int = _builder.history_depth()
		# The least of TRIES, each undone but the last: one try is at the
		# mercy of whatever else the box ran that moment.
		var tries := PackedStringArray()
		var least: float = INF
		var waited := PackedStringArray()
		var busy: float = 0.0
		var said: String = ""
		var part: int = at.brick_ids[0]
		for attempt: int in TRIES:
			if attempt > 0:
				_builder.undo()
				await _frames(3)
				_steps.refresh(number)
				at = _steps.current_step()
			var span := ProbeTime.Span.new()
			said = _shell.change_steps(op, [part], at)
			span.end()
			least = minf(least, span.own)
			tries.append("%.0f" % span.own)
			waited.append("%.0f" % span.waited)
			busy = maxf(busy, span.busy)
			await process_frame
		var after: String = _store.to_text("probe", true)
		if not _into.is_empty():
			var file := FileAccess.open(_into.path_join("%s_%s.ldr" % [name, op]), FileAccess.WRITE)
			file.store_string(after)
			file.close()
		var line: String = "%s, a part of step %d: %.0f ms of its own at least (%s ms; %s waiting for a CPU; %s) (%s)" \
			% [op, at.number, least, ", ".join(tries), ", ".join(waited),
				ProbeTime.load_said(busy), said]
		if judged:
			# A busy box slows the work itself, not only its turn at a CPU:
			# at a load past the cores (the suite runs near 30 on 24) the bar
			# is three times as long, which an edit gone whole-model again
			# (2.5 s and more) still fails.
			var bar: float = BAR_MS * ProbeTime.slack(busy)
			_check("%s, under %.0f ms" % [line, bar], least < bar)
		else:
			print("  ...   %s" % line)
		_check("  one undo, and the file changed", _builder.history_depth() == depth + 1
			and after != before)
		# What the timeline shows after it, against every batch written
		# again in the new order (BrickWorld._reranked's alternative).
		var drawn: String = _drawn()
		_world.show_only({})
		_steps._show(_steps._shown)
		var written: String = _drawn()
		await process_frame
		_check("  the timeline draws what writing every batch again draws (%d batches)"
			% _world._batches.size(), drawn == written and not drawn.is_empty())
		# The plan from what was kept of the model's shape, against one
		# read afresh.
		var kept: String = _said(Instructions.plan(_world, _library, _store.scenery, {}, true))
		Instructions._shaped = {}
		var fresh: String = _said(Instructions.plan(_world, _library, _store.scenery, {}, true))
		_check("  the timeline's plan after it is the plan read afresh (%d steps)"
			% _steps.steps().size(), kept == fresh and _said(_steps.steps()) == fresh)
		_builder.undo()
		await _frames(3)
		_check("  undone, the file is the file before it, to the byte",
			_store.to_text("probe", true) == before)
	for step: Instructions.Step in middle:
		if step.brick_ids.size() != 1 or not step.copies.is_empty():
			continue
		_steps.refresh(step.number)
		var before: String = _store.to_text("probe", true)
		var depth: int = _builder.history_depth()
		var said: String = _shell.change_steps("new", [step.brick_ids[0]], _steps.current_step())
		_check("new, the part alone in step %d: \"%s\", nothing to undo, the file as it was"
			% [step.number, said], said == "the steps are as they were"
			and _builder.history_depth() == depth and _store.to_text("probe", true) == before)
		break


## What the world draws of the timeline's step: each batch's parts in their
## slots and how many are drawn, and which parts are hidden.
func _drawn() -> String:
	var lines := PackedStringArray()
	var keys: Array = _world._batches.keys()
	keys.sort()
	for key: String in keys:
		var batch: BrickWorld.Batch = _world._batches[key]
		lines.append("%s %d %d %s" % [key, batch.shown, batch.multimesh.visible_instance_count,
			str(batch.brick_ids)])
	var hidden := PackedInt64Array()
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.hidden:
			hidden.append(brick.id)
	hidden.sort()
	lines.append(str(hidden))
	return "\n".join(lines)


## [param steps] in words, all that says what each is.
func _said(steps: Array) -> String:
	var lines := PackedStringArray()
	for step: Instructions.Step in steps:
		lines.append("%d %d %d %s %d %s %s" % [step.index, step.number, step.callout_step,
			step.authored_in, step.authored_step, str(step.brick_ids), str(step.copies)])
	return "\n".join(lines)
