## A brief designed twice through the panel, on the subscription, end to end.
##
##   godot --path . --resolution 1400x900 --script src/dev/best_of_two_walk_probe.gd -- \
##     --brief="a small red post box" [--port=8953] [--most-min=40] [--record=FILE.json]
##
## Run as `env -u ANTHROPIC_API_KEY tools/probe.sh best_of_two_walk_probe
## --brief=...`: it spends two design sessions and one pick of the
## subscription. The app is opened as a person opens it, My Claude ticked in
## the panel, the brief typed and sent, as a person sends it. Checked: a
## second design started beside the first, in an app of its own with no
## window, and ended with a design of its own; the pick was asked and
## answered; the kept design is the model on the baseplate, the panel's card
## closed on it; Undo brings the other back where the second was kept, and
## undoing every step leaves the bare baseplate the design began on, and
## Redo puts it all back; nothing of the second is left running. The wait
## until the kept design stands is printed against the first design's own
## time. --record writes what was decided and timed, as JSON.
extends SceneTree

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run()


func _arg(prefix: String, otherwise: String = "") -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.substr(prefix.length() + 1)
	return otherwise


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var brief: String = _arg("--brief", "a small red post box")
	if ClaudeCode.found().is_empty():
		print("best_of_two_walk_probe: SKIPPED, no Claude Code on this machine")
		quit(0)
		return
	Engine.max_fps = 60
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var world: BrickWorld = _main.get("_world")
	var builder: Builder = _main.get("_builder")
	var store: ModelStore = _main.get("_store")
	var chat: ChatPanel = _main.get("_chat")
	_main.call("_open_commands", int(_arg("--port", "8953")))
	_check("the app listens for its own session on %s" % _arg("--port", "8953"),
		_main.get("_commands") != null)
	_check("the panel offers My Claude", chat.claude_code_here and chat._use_claude_code != null)
	if _failures > 0:
		quit(1)
		return

	# A bare baseplate, as File, New leaves it: a model to change is one session.
	_main.call("clear_model")
	await process_frame
	if chat._sketch_first != null:
		chat._sketch_first.button_pressed = false
	print("\nsent: \"%s\" to a bare baseplate (%d parts)" % [brief,
		world.brick_count() - store.scenery.size()])
	chat._use_claude_code.button_pressed = true
	chat._input.text = brief
	var started: int = Time.get_ticks_msec()
	chat._on_send()
	await process_frame
	var pair: BestOfTwo = _main.get("_best_of_two")
	_check("a second design started beside the first", pair != null and pair.second_running())
	if pair == null:
		quit(1)
		return
	var dir: String = pair._dir
	var port: int = pair._port
	var pid: int = pair._pid
	var first_ms: Array = [0]
	(_main.call("claude_code") as ClaudeCode).finished.connect(func(_ok: bool, _s: String) -> void:
		first_ms[0] = Time.get_ticks_msec() - started, CONNECT_ONE_SHOT)
	var ended: Array = []
	pair.finished.connect(func(ok: bool, summary: String) -> void:
		ended.append({"ok": ok, "summary": summary, "record": pair.record.duplicate(true),
			"ms": Time.get_ticks_msec() - started}))
	var most_ms: int = int(float(_arg("--most-min", "40")) * 60000.0)
	var said: int = 0
	while ended.is_empty() and Time.get_ticks_msec() - started < most_ms:
		await create_timer(1.0).timeout
		var minutes: int = (Time.get_ticks_msec() - started) / 60000
		if minutes > said:
			said = minutes
			print("  [%d min] parts on the baseplate %d, the second %s" % [minutes,
				world.brick_count() - store.scenery.size(),
				"running" if OS.is_process_running(pid) else "ended"])
	_check("the pair ended within %s minutes" % _arg("--most-min", "40"), not ended.is_empty())
	if ended.is_empty():
		pair.stop()
		quit(1)
		return
	for _n: int in 30:
		await process_frame
	var end: Dictionary = ended[0]
	var record: Dictionary = end["record"]
	var first: Dictionary = record.get("first", {})
	var second: Dictionary = record.get("second", {})
	var pick: Dictionary = record.get("pick", {})
	var log: String = FileAccess.get_file_as_string(dir.path_join("app.log"))

	print("\ntwo sessions")
	_check("the first, in this app, built %d parts in %.0f s" % [int(first.get("parts", 0)),
		float(first.get("seconds", 0))], bool(first.get("ok", false)) and int(first.get("parts", 0)) > 0)
	_check("the second, in its own app, had its own session (%s)" % _line(log, "connected ("),
		log.contains("connected (") and log.contains("subscription"))
	_check("...and built %d parts in %.0f s: %s" % [int(second.get("parts", 0)),
		float(second.get("seconds", 0)), _line(log, "claude code ok=")],
		bool(second.get("ok", false)) and int(second.get("parts", 0)) > 0)
	var drawn: int = log.count("leased shots")
	_check("...its pictures drawn by this app, none given up (%d warnings)" % drawn, drawn == 0)

	print("\nthe pick")
	_check("asked and answered: kept %s in %.1f s on %s, %d tokens in, %d out" % [
		pick.get("keep", "nothing"), float(pick.get("seconds", 0)), pick.get("model", "?"),
		_tokens_in(pick), int((pick.get("usage", {}) as Dictionary).get("output_tokens", 0))],
		str(pick.get("keep", "")) in ["A", "B"])
	print("        A: %s\n        B: %s\n        why: %s" % [pick.get("a", ""), pick.get("b", ""),
		pick.get("why", pick.get("error", ""))])
	var kept: String = str(record.get("kept", ""))
	_check("the %s kept, as the pick said" % kept,
		kept == ("second" if str(pick.get("keep", "")) == "B" else "first"))

	print("\nthe person's model")
	var parts: int = world.brick_count() - store.scenery.size()
	var kept_parts: int = int((second if kept == "second" else first).get("parts", -1))
	_check("the kept design stands on the baseplate: %d parts, %d kept" % [parts, kept_parts],
		parts == kept_parts)
	_check("the panel's card closed on it: \"%s\"" % chat._status.text.left(120).replace("\n", " "),
		not chat._working and bool(end["ok"]))
	_check("the model is called \"%s\"" % store.title, store.title != ModelStore.UNTITLED)
	var depth: int = builder.history_depth()
	builder.undo()
	var undone: int = world.brick_count() - store.scenery.size()
	if kept == "second":
		_check("Undo brings the first back (%d parts, the first had %d)" % [undone,
			int(first.get("parts", 0))], undone == int(first.get("parts", 0)))
	else:
		_check("Undo takes back the first's last step (%d parts)" % undone, depth > 0)
	builder.redo()
	_check("Redo puts the kept one back (%d parts)" % (world.brick_count() - store.scenery.size()),
		world.brick_count() - store.scenery.size() == parts)
	var undos: int = 0
	while builder.undo():
		undos += 1
	var bare: int = world.brick_count() - store.scenery.size()
	_check("every step undone, %d of them, leaves the bare baseplate it began on (%d parts)"
		% [undos, bare], bare == 0)
	for _n: int in undos:
		builder.redo()
	_check("and redone, the kept design again (%d parts)" % (world.brick_count()
		- store.scenery.size()), world.brick_count() - store.scenery.size() == parts)

	print("\nnothing left running")
	_check("the second app has ended", not OS.is_process_running(pid))
	var left: Array = _sessions_on(port)
	_check("no Claude Code session of the second's left (%s)" % str(left), left.is_empty())

	var wait_s: float = float(end["ms"]) / 1000.0
	var one_s: float = float(first_ms[0]) / 1000.0
	print("\nthe wait: %.0f s until the kept design stood, the first design alone %.0f s, %.2fx;"
		% [wait_s, one_s, wait_s / maxf(one_s, 1.0)]
		+ " the second %.0f s" % float(second.get("seconds", 0)))
	var out: String = _arg("--record")
	if not out.is_empty():
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify({"brief": brief, "record": record, "wait_s": wait_s,
			"first_s": one_s, "ratio": wait_s / maxf(one_s, 1.0), "summary": end["summary"],
			"title": store.title, "parts": parts, "failures": _failures}, " "))
		file.close()
		# And the six pictures the pick was shown, beside it.
		for name: String in DirAccess.get_files_at(dir):
			if name.ends_with(".png") or name == "app.log" or name == "second.ldr":
				DirAccess.copy_absolute(dir.path_join(name),
					out.get_basename() + "_" + name)
	print("\n%s" % ("best_of_two_walk_probe: %d FAIL" % _failures if _failures > 0
		else "best_of_two_walk_probe: passed"))
	quit(1 if _failures > 0 else 0)


static func _line(text: String, starting: String) -> String:
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(starting) or line.contains(starting):
			return line.strip_edges().left(160)
	return ""


static func _tokens_in(pick: Dictionary) -> int:
	var usage: Dictionary = pick.get("usage", {})
	return int(usage.get("input_tokens", 0)) + int(usage.get("cache_creation_input_tokens", 0)) \
		+ int(usage.get("cache_read_input_tokens", 0))


## Claude Code sessions still running against the second's port: their
## command lines name its connection file.
static func _sessions_on(port: int) -> Array:
	var found: Array = []
	var named: String = "claude-code-mcp-%d.json" % port
	for entry: String in DirAccess.get_directories_at("/proc"):
		if not entry.is_valid_int():
			continue
		var command: PackedByteArray = FileAccess.get_file_as_bytes("/proc/%s/cmdline" % entry)
		# Its words are kept apart by nothing at all, which ends a string.
		for n: int in command.size():
			if command[n] == 0:
				command[n] = 32
		if command.get_string_from_utf8().contains(named):
			found.append(int(entry))
	return found
