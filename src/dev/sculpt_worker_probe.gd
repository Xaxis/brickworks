## Is a design's sculpt laid off the main thread, the same as on it, with the
## window drawing meanwhile?
##
##   godot --path . --resolution 1400x900 --script src/dev/sculpt_worker_probe.gd
##
## A sculpt (Sculpt) is laid by Brickify. Laid on the main thread as the
## design was read, the first of each held the window 0.3 to 0.7 s on this
## desktop (the bench's potato and fat rabbit) and several times that in a
## browser. Assistant._sculpt_ready now lays it on a worker before the read.
## In the app's own scene:
##
##   the same     each sculpt here, sculpt_probe's six bodies and the bench
##                sessions' own (src/dev/fixtures/sculpt_designs.json: the
##                potato, the fat rabbit with its belly and head, a balloon
##                dog, a toilet's head, a statue), is laid on the main thread
##                as the read laid it, then on the worker, and must be byte
##                for byte the same: its parts, where each is, what it said;
##   the window   those sessions' check_design and submit_design calls, made
##                through the connector as a session makes them, each round's
##                sculpts new (another colour), with edits between, until
##                twenty and more are laid back to back. Every frame's own
##                work is timed (OwnFrames): the longest while one is laid
##                must be under 100 ms on a graphics card (said, not judged,
##                drawn in software);
##   said         the Working bar says "Laying a sculpt…" while it goes;
##   the panel    the Brickify panel laying a model at the same time as a
##                sculpt: one waits for the other (Brickify.begin_laying), and
##                both come out whole.
extends SceneTree

const SculptProbe := preload("res://src/dev/sculpt_probe.gd")
const BUDGET_MS := 100.0
## Sculpts laid back to back, at least.
const LAID_AT_LEAST := 20
const COLOURS: Array[int] = [4, 1, 14, 2, 25]

var _failures: int = 0
var _software: bool = false
## While a call runs: the longest frame's own work, ms, and whether the bar
## said a sculpt was being laid.
var _own_ms: float = 0.0
var _laying_said: bool = false
var _watching: bool = false
var _main: Node
var _assistant: Assistant
var _rpc: CommandSocket


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	if _watching and Working.is_busy() and Working.current().words.begins_with("Laying"):
		_laying_said = true
	return false


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	(_main.get("_playback") as BuildPlayback).stop()
	_assistant = _main.get("_assistant")
	_rpc = (_main.get("_connector") as ClaudeConnector).rpc
	var adapter: String = RenderingServer.get_video_adapter_name().to_lower()
	_software = adapter.contains("llvmpipe") or adapter.contains("lavapipe") \
		or adapter.contains("swiftshader")
	var frames := OwnFrames.new()
	root.add_child(frames)
	frames.timed.connect(func(spent_us: int) -> void:
		if _watching:
			_own_ms = maxf(_own_ms, spent_us / 1000.0))
	var calls: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://src/dev/fixtures/sculpt_designs.json"))
	print("")
	print("  the same on the worker as on the main thread")
	await _same(calls)
	print("")
	print("  laid back to back through the connector, edits between")
	await _back_to_back(calls)
	print("")
	print("  with the Brickify panel laying a model at the same time")
	await _beside_the_panel()
	print("")
	print("sculpt_worker_probe: %s" % ("all passed" if _failures == 0
		else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## Every sculpt here laid on the main thread first, as the read laid it
## before (Assistant._with_sculpts, nothing laid ahead of it), then each
## again on the worker (_sculpt_ready), and compared.
func _same(calls: Array) -> void:
	var designs: Array = []
	for body: Array in SculptProbe.BODIES:
		designs.append([str(body[0]), {"name": body[0], "patterns": [body[1]], "bricks": []}])
	for call: Dictionary in calls:
		designs.append(["%s's %s" % [call["subject"], call["name"]], call["input"]])
	var on_main: Array = []
	for design: Array in designs:
		_assistant._sculpts_laid.clear()
		_assistant._with_sculpts(_read_as(design[1]), [], [])
		on_main.append(_assistant._sculpts_laid.duplicate(true))
	var compared: int = 0
	for n: int in designs.size():
		_assistant._sculpts_laid.clear()
		var began: int = Time.get_ticks_msec()
		_watching = true
		_own_ms = 0.0
		await _assistant._sculpt_ready(designs[n][1])
		_watching = false
		var main_laid: Dictionary = on_main[n]
		var worker_laid: Dictionary = _assistant._sculpts_laid.duplicate(true)
		var same: bool = main_laid.keys() == worker_laid.keys()
		var parts: Array = []
		for key: String in main_laid:
			same = same and worker_laid.has(key) \
				and var_to_str(main_laid[key]) == var_to_str(worker_laid[key])
			parts.append(int((main_laid[key] as Dictionary).get("parts", 0)))
			compared += 1
		_check("%s: %s, %s parts, on the worker in %d ms, its longest frame %.0f ms" % [
			designs[n][0], "byte for byte the same" if same else "NOT the same",
			", ".join(PackedStringArray(parts.map(func(v: Variant) -> String: return str(v)))),
			Time.get_ticks_msec() - began, _own_ms], same and not main_laid.is_empty())
	_check("%d sculpts compared, at least 6" % compared, compared >= 6)


## What _read_model hands _with_sculpts: the design with its shells and
## figures laid.
func _read_as(args: Dictionary) -> Dictionary:
	return _assistant._with_figures(_assistant._with_shells(args, [], []), [], [])


## The sessions' calls, a round at a time, each round's sculpts in another
## colour so each is laid anew, edits between, until enough are laid.
func _back_to_back(calls: Array) -> void:
	_assistant._sculpts_laid.clear()
	var laid: int = 0
	var worst: float = 0.0
	var round: int = 0
	while laid < LAID_AT_LEAST and round < COLOURS.size():
		var subject: String = ""
		for call: Dictionary in calls:
			if call["subject"] != subject:
				subject = call["subject"]
				await _call("clear_model", {})
			var input: Dictionary = (call["input"] as Dictionary).duplicate(true)
			for raw: Variant in input.get("patterns", []):
				if raw is Dictionary and str(raw.get("pattern")) == "sculpt":
					raw["color"] = COLOURS[round]
			var answer: Array = await _call(str(call["name"]), input)
			if answer[2]:
				laid += 1
				worst = maxf(worst, float(answer[1]))
			# Answered, whatever the check made of the design: some of the
			# sessions' first tries float, as they did on the bench.
			_check("%s's %s, round %d: %s; its longest frame %.0f ms%s: %s" % [subject,
				call["name"], round + 1, "a sculpt laid" if answer[2] else "laid already",
				float(answer[1]), "" if float(answer[1]) <= BUDGET_MS or _software
				else " (over %.0f)" % BUDGET_MS, str(answer[0]).left(90)],
				(_software or float(answer[1]) <= BUDGET_MS) and not answer[3])
			if call["name"] == "submit_design":
				await _edits_between()
		round += 1
	_check("%d sculpts laid back to back, the longest frame while one was %.0f ms%s" % [laid,
		worst, " (drawn in software, so not judged)" if _software else ""],
		laid >= LAID_AT_LEAST and (_software or worst <= BUDGET_MS))


## [the answer's text, the longest frame's own work in ms while it ran,
## whether the bar said a sculpt was being laid, whether it was an error].
func _call(name: String, input: Dictionary) -> Array:
	_own_ms = 0.0
	_laying_said = false
	_watching = true
	var answer: Variant = await _rpc.answer_rpc({"jsonrpc": "2.0", "id": 1,
		"method": "tools/call", "params": {"name": name, "arguments": input}})
	await process_frame
	_watching = false
	var result: Dictionary = (answer as Dictionary).get("result", {}) if answer is Dictionary else {}
	var text: String = ""
	for block: Variant in result.get("content", []):
		if block is Dictionary and str(block.get("type")) == "text":
			text += str(block.get("text", "")).replace("\n", " ")
	return [text, _own_ms, _laying_said, answer == null or bool(result.get("isError", false))
		or (answer as Dictionary).has("error")]


## A session's edits after a submit, and the person's undo: a brick added, a
## part recoloured, the last change undone.
func _edits_between() -> void:
	await _call("edit_model", {"add": [{"part": "3001", "color": 4, "x": 30, "y": 0, "z": 0}]})
	var world: BrickWorld = _main.get("_world")
	var bricks: Array = world.bricks()
	if not bricks.is_empty():
		await _call("edit_model", {"recolor": [{"bricks": [(bricks[0] as BrickWorld.Brick).id],
			"color": 14}]})
	await _call("undo", {})


## The panel brickifying a 20-stud pig while a session's check lays a sculpt.
func _beside_the_panel() -> void:
	await _call("clear_model", {})
	var dialog: BrickifyDialog = _main.get("_brickify")
	var pig: Dictionary = SculptProbe.BODIES[1][1]
	var mesh: MeshFile = Sculpt.mesh_of(Sculpt.solids_of(pig, []), func(_code: int) -> Color:
		return Color(0.9, 0.6, 0.6))
	mesh.name = "pig"
	dialog.show_for(mesh)
	dialog.set_studs(20)
	var before: int = (_main.get("_world") as BrickWorld).brick_count()
	var done: Array = [false]
	var panel: Callable = func() -> void:
		await dialog.brickify()
		done[0] = true
	panel.call()
	var egg: Dictionary = (SculptProbe.BODIES[0][1] as Dictionary).duplicate(true)
	egg["color"] = 10
	var answer: Array = await _call("check_design", {"name": "egg", "patterns": [egg]})
	var waited: int = Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - waited < 120000:
		await process_frame
	var after: int = (_main.get("_world") as BrickWorld).brick_count()
	_check("the check laid its sculpt: %s" % str(answer[0]).left(90),
		str(answer[0]).contains("The sculpt is") and answer[2] and not answer[3])
	_check("the panel laid its pig too, %d parts" % (after - before),
		done[0] and after - before > 50)
	_check("nothing is left laying", Brickify._laying == null)
	dialog.visible = false


func _check(what: String, ok: bool) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
