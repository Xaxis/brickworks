## Does the app name who designs: Claude for Claude, the model for a model on
## the person's key?
##
##   godot --headless --path . --script src/dev/designer_words_probe.gd
##
## docs/PROVIDERS.md, P8. A call from Claude (any client that names no one)
## and a design by GPT-6.1 Sol on the person's OpenAI key (DesignerLoop, here
## against tools/provider_stub.py's strict Responses API on 127.0.0.1:9681),
## and the words each leaves: the history's steps, a call's job, a change to
## the selection, the toolbar while it works, and the words that ask whoever
## designs (Ask … about this… on the menus, the panel's Ask button and its
## brief, Brick Art's Design with …). Claude's stay Claude's word for word.
## The stub's port is 9681, or -- --port=N.
extends SceneTree

const BRIEF := "A slender red tower, six bricks tall"
const MODEL := "gpt-6.1-sol"
const NAMED := "GPT-6.1 Sol"

var _stub_port: int = _port()
var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _socket: CommandSocket
var _sent: int = 0
var _stub: int = -1


func _initialize() -> void:
	_run()


static func _port() -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			return int(argument.trim_prefix("--port="))
	return 9681


func _run() -> void:
	await process_frame
	_names()
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_assistant = _main.get("_assistant")
	(_main.get("_store") as ModelStore).keeps = false
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	await _claude()
	await _model_on_a_key()
	if _stub > 0:
		OS.kill(_stub)
	print("")
	print("designer words: Claude's say Claude, %s's say %s" % [NAMED, NAMED] if _failures == 0
		else "designer words: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## A model's id said as its maker says it.
func _names() -> void:
	print("── a model's name, from its id ──")
	var said: Dictionary = {}
	for id: String in ["gpt-6.1-sol", "openai/gpt-6.1-sol", "claude-sonnet-5-5",
			"claude-haiku-4-5-20251001", "gemini-4-argon", "gpt-4.1-2025-04-14", "o4-mini",
			"mistral-large-4-0", "glm-5.3"]:
		said[id] = ProviderSettings.model_name(id)
	_check("each as its maker says it: %s" % str(said.values()), said.values() == ["GPT-6.1 Sol",
		"GPT-6.1 Sol", "Claude Sonnet 5.5", "Claude Haiku 4.5", "Gemini 4 Argon", "GPT-4.1",
		"o4-mini", "Mistral Large 4.0", "GLM-5.3"])


## Claude's: a call that names no one, as every Claude client's does.
func _claude() -> void:
	print("\n── Claude designs ──")
	_check("who designs is Claude, by default", ProviderSettings.designer_name() == "Claude")
	_clear()
	await _rpc("submit_design", _tower(4))
	var steps: PackedStringArray = _builder.history_words(3)
	_check("the history's step is Claude's: %s" % str(steps),
		not steps.is_empty() and steps[0].begins_with("Claude's submit design"))
	var job: String = await _job_words({})
	_check("a call of Claude's that becomes a job is Claude's: %s" % job.left(90),
		job.contains("Working on Claude's clear_model"))
	await _rpc("submit_design", _tower(4))
	await _asked_about("Claude")
	var changed: String = await _recolour({})
	_check("the change to the selection is Claude's: %s" % changed,
		changed.contains("Claude's change to the selection"))
	var shell: Shell = _main.get("_shell")
	_check("the menus ask Claude: %s; %s" % [shell.command("ask_claude").words,
		shell.command("brace").words], shell.command("ask_claude").words == "Ask Claude about this…"
		and shell.command("brace").words == "Ask Claude to brace this…")
	var art: Dictionary = _art_words()
	_check("Brick Art designs with Claude: %s" % str(art), art["ask"] == "Design with Claude"
		and str(art["brief"]).begins_with("Tell Claude:"))
	_check("the toolbar says nothing of a model on a key: \"%s\""
		% (_main.get("_bar") as ModelBar).claude_tab_words(),
		not (_main.get("_bar") as ModelBar).claude_tab_words().contains("working"))


## GPT-6.1 Sol on the person's OpenAI key, through the loop in the app.
func _model_on_a_key() -> void:
	print("\n── %s designs, on the person's key ──" % NAMED)
	ProviderSettings.choose("openai", MODEL)
	ProviderSettings.set_who(ProviderSettings.WHO_KEY)
	(_main.get("_controls") as ControlsDialog).ai_changed.emit()
	_check("who designs is %s: %s" % [NAMED, ProviderSettings.designer_name()],
		ProviderSettings.designer_name() == NAMED)
	var shell: Shell = _main.get("_shell")
	_check("the menus ask it: %s; %s" % [shell.command("ask_claude").words,
		shell.command("brace").words], shell.command("ask_claude").words
		== "Ask %s about this…" % NAMED and shell.command("brace").words
		== "Ask %s to brace this…" % NAMED and shell.command("ask_claude").tip.begins_with(
			"Ask %s to change" % NAMED))
	var art: Dictionary = _art_words()
	_check("Brick Art designs with it: %s" % str(art), art["ask"] == "Design with %s" % NAMED
		and str(art["brief"]).begins_with("Tell %s:" % NAMED)
		and str(art["tip"]).contains("on your own key"))

	var key: String = "sk-stub-" + Crypto.new().generate_random_bytes(16).hex_encode()
	var log_path: String = ProjectSettings.globalize_path("user://words-stub.jsonl")
	OS.set_environment("STUB_KEY", key)
	_stub = OS.create_process("python3", ["-I",
		ProjectSettings.globalize_path("res://tools/provider_stub.py"), "--port", str(_stub_port),
		"--log", log_path, "--delay", "0.3"])
	OS.unset_environment("STUB_KEY")
	await _seconds(2.0)
	_clear()
	var provider: Provider = ProviderSettings.provider_for("openai", MODEL, key,
		"http://127.0.0.1:%d/v1" % _stub_port, {"reasoning_effort": "high"})
	var notes: Array[String] = []
	var outcome: Array = []
	var started: bool = _main.call("design_with_provider", BRIEF, provider)
	var loop: DesignerLoop = _main.call("designer")
	loop.progress.connect(func(note: String) -> void: notes.append(note))
	loop.finished.connect(func(ok: bool, summary: String) -> void: outcome.append_array([ok, summary]))
	var bar: ModelBar = _main.get("_bar")
	var working: String = bar.claude_tab_words()
	_check("the toolbar, while it works: \"%s\"" % working, started and working == "%s working" % NAMED)
	await _until(func() -> bool: return not outcome.is_empty(), 240.0)
	_check("it designed, through Responses: %s" % str(outcome), outcome.size() == 2
		and bool(outcome[0]) and _parts() == 6)
	_check("and once done the toolbar's line is Claude's again: \"%s\"" % bar.claude_tab_words(),
		not bar.claude_tab_words().contains("working"))
	var steps: PackedStringArray = _builder.history_words(10)
	var claudes: Array = Array(steps).filter(func(one: String) -> bool: return one.contains("Claude"))
	_check("the history's steps are %s's, none Claude's: %s" % [NAMED, str(steps)],
		Array(steps).any(func(one: String) -> bool: return one.begins_with(
			"%s's submit design" % NAMED)) and claudes.is_empty())
	_check("its first word names it: \"%s\"" % (notes[0] if not notes.is_empty() else ""),
		not notes.is_empty() and notes[0] == "%s is reading the brief" % NAMED)
	var who: Dictionary = {CommandSocket.WHO_KEY: NAMED}
	var job: String = await _job_words(who)
	_check("a call of its that becomes a job is its: %s" % job.left(90),
		job.contains("Working on %s's clear_model" % NAMED))
	await _rpc("submit_design", _tower(4), who)
	await _asked_about(NAMED)
	var changed: String = await _recolour(who)
	_check("its change to the selection is its: %s" % changed,
		changed.contains("%s's change to the selection" % NAMED) and not changed.contains("Claude"))
	_check("the key in no line the stub kept", not FileAccess.get_file_as_string(log_path).contains(key))
	# Back to Claude: every word Claude's again.
	ProviderSettings.set_who(ProviderSettings.WHO_CLAUDE)
	(_main.get("_controls") as ControlsDialog).ai_changed.emit()
	_check("chosen Claude again, the menus ask Claude", shell.command("ask_claude").words
		== "Ask Claude about this…")


## The selection asked about in the panel: the button and the box name who.
func _asked_about(who: String) -> void:
	var chat: ChatPanel = _main.get("_chat")
	var ids: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return not _assistant.scenery.has(brick.id)).map(func(brick: BrickWorld.Brick) -> int:
			return brick.id)
	ids.sort()
	_builder.selection.clear()
	for id: int in ids.slice(ids.size() - 2):
		_builder.selection[id] = true
	chat.ask_about(_builder.selection.keys())
	var button: String = (chat.get("_send") as Button).text
	var box: String = (chat.get("_input") as TextEdit).placeholder_text
	_check("the panel asks %s: \"%s\", \"%s\"" % [who, button, box.left(40)],
		button == "Ask %s" % who and box.begins_with("What should %s do with them?" % who))


## The top part of the selection painted blue, over the socket as [param who]
## calls: the newest step's words.
func _recolour(who: Dictionary) -> String:
	var top: int = 0
	for id: Variant in _builder.selection:
		top = maxi(top, int(id))
	var said: String = await _rpc("edit_selection", {"recolor": [{"bricks": [top], "color": 1}]}, who)
	var words: String = _builder.history_words(1)[0] if _builder.history_depth() > 0 else ""
	if not words.contains("change to the selection"):
		print("    edit_selection said: %s" % said.left(300))
	var chat: ChatPanel = _main.get("_chat")
	chat.stop_asking_about()
	_assistant.unfocus()
	return words


## A call of [param who]'s made a job at once (ToolJobs.after_s 0): its words.
func _job_words(who: Dictionary) -> String:
	var jobs: ToolJobs = _socket.jobs
	var was: float = jobs.after_s
	jobs.after_s = 0.0
	var said: String = await _rpc("clear_model", {}, who)
	jobs.after_s = was
	await _until(func() -> bool: return jobs.running() == null, 30.0)
	return said


func _art_words() -> Dictionary:
	var art: MosaicDialog = _main.get("_mosaic")
	var picture := Image.create(8, 8, false, Image.FORMAT_RGB8)
	picture.fill(Color.RED)
	art.show_for(picture)
	var out: Dictionary = {"ask": (art.get("_ask") as Button).text,
		"brief": (art.get("_brief") as LineEdit).placeholder_text,
		"tip": (art.get("_ask") as Button).tooltip_text}
	art.visible = false
	return out


func _tower(height: int) -> Dictionary:
	var bricks: Array = []
	for n: int in height:
		bricks.append({"part": "3003", "color": 4, "x": 10, "y": 3 * n, "z": 10, "rot": 0})
	return {"name": "A red tower", "description": "a red tower", "floor": "none", "bricks": bricks}


func _clear() -> void:
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	(_main.get("_store") as ModelStore).scenery.clear()
	_assistant.forget_built()


## One call over the connector's own socket, as a session makes it, with
## [param meta] as the call's _meta: its words.
func _rpc(tool: String, arguments: Dictionary, meta: Dictionary = {}) -> String:
	_sent += 1
	var params: Dictionary = {"name": tool, "arguments": arguments}
	if not meta.is_empty():
		params["_meta"] = meta
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _sent,
		"method": "tools/call", "params": params})
	var result: Dictionary = (answer as Dictionary).get("result", {}) if answer is Dictionary else {}
	return Provider.text_of(result.get("content", []))


func _parts() -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _assistant.scenery.has(brick.id):
			count += 1
	return count


func _until(done: Callable, seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while not bool(done.call()) and Time.get_ticks_msec() < until:
		await process_frame


func _seconds(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
