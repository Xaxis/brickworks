## Does a new design's first save hand back a fresh pair of eyes, once?
##
##   godot --path . --resolution 1400x900 --script src/dev/fresh_eyes_probe.gd
##
## FreshEyes (src/ai/fresh_eyes.gd): at a connector chat's first whole save of
## a new design, Claude Code is shown the subject and three pictures of the
## model, and the save's answer carries its three changes in place of the close
## looks, which come at the next save. Here Claude Code is a stand-in put first
## on PATH, which writes down what it was started with and sent, and answers
## as Claude Code does. With no Claude Code on PATH the save says what it says
## on main, and the eyes are never asked again for that subject; with it, the
## eyes are asked once and their changes said, never at a later save or a
## second design of the sitting; a new chat's new design is asked again, and
## so is one over the example car a tab opens on (the relay's); a chat that
## designs beside a model already standing, and an answer that failed, say
## what main says. The eyes see three pictures and the subject, nothing of
## the session. In a window, for the pictures.
##
## --dump=FILE writes the no-Claude-Code chat's answers there, and --baseline
## runs that chat alone, touching nothing of FreshEyes: run with both on main
## (the file copied in) and here, the two files are the same, byte for byte.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _connector: ClaudeConnector
var _assistant: Assistant
var _next: int = 0
var _fake: String = ""
var _path: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_connector = _main.get("_connector")
	_assistant = _main.get("_assistant")
	(_main.get("_store") as ModelStore).keeps = false
	_path = OS.get_environment("PATH")
	var baseline: bool = OS.get_cmdline_user_args().has("--baseline")

	await _no_claude_code(baseline)
	if not baseline:
		_fake = _stand_in()
		OS.set_environment("PATH", "%s:%s" % [_fake, _path])
		await _asked_once()
		await _asked_again_for_a_new_chat()
		await _over_the_example()
		await _beside_a_model()
		await _no_answer()
	OS.set_environment("PATH", _path)

	print("")
	print("fresh eyes: asked once at a new design's first save, its changes said; "
		+ "with no Claude Code, the save as before" if _failures == 0
		else "fresh eyes: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## No Claude Code on PATH: what the save says, kept for --dump.
func _no_claude_code(baseline: bool) -> void:
	print("── no Claude Code on this machine ──")
	var empty: String = ProjectSettings.globalize_path("user://no-claude")
	DirAccess.make_dir_recursive_absolute(empty)
	OS.set_environment("PATH", "%s:/usr/bin:/bin" % empty)
	_check("Claude Code is not found", ClaudeCode.found().is_empty())
	var dump := PackedStringArray()
	await _call_as("c0", "clear_model", {})
	var said: Array = await _call_as("c0", "submit_design", _tower())
	dump.append(_text(said))
	said = await _call_as("c0", "save_model", {"name": "tower0.ldr"})
	dump.append(_text(said))
	_check("the first save says nothing of fresh eyes", not _text(said).contains("fresh pair"))
	_check("...and hands back the close look at the tower, as main does: %s"
		% _line_with(_text(said), "Before it is finished"),
		_text(said).contains("Before it is finished") and _text(said).contains("the tower"))
	said = await _call_as("c0", "save_model", {"name": "tower0.ldr"})
	dump.append(_text(said))
	if not baseline:
		var eyes: Object = _assistant.call("fresh_eyes")
		_check("the eyes were looked for once, and not asked again for this subject",
			bool(eyes.get("asked")) and (eyes.get("last") as Dictionary).is_empty())
	OS.set_environment("PATH", _path)
	var dump_to: String = _argument("--dump")
	if not dump_to.is_empty():
		var file: FileAccess = FileAccess.open(dump_to, FileAccess.WRITE)
		file.store_string("\n\n=====\n\n".join(dump).replace(OS.get_user_data_dir(), "<user>"))
		file.close()
		print("  answers written to %s" % dump_to)


func _asked_once() -> void:
	print("\n── a new design's first save, with Claude Code ──")
	_check("the stand-in is the Claude Code found: %s" % ClaudeCode.found(),
		ClaudeCode.found() == _fake.path_join("claude"))
	await _call_as("c1", "clear_model", {})
	await _call_as("c1", "submit_design", _tower())
	var started: int = Time.get_ticks_msec()
	var said: Array = await _call_as("c1", "save_model", {"name": "tower1.ldr"})
	var text: String = _text(said)
	_check("the save is written, then the eyes' answer: %s" % _line_with(text, "fresh pair"),
		text.begins_with("Written to tower1.ldr") and text.contains("a fresh pair of eyes"))
	_check("...all three changes, in order, and to save after them",
		text.find("1. CHANGE-ONE") > 0 and text.find("2. CHANGE-TWO") > text.find("1. CHANGE-ONE")
		and text.find("3. CHANGE-THREE") > text.find("2. CHANGE-TWO")
		and text.contains("then save_model"))
	_check("...in place of the close looks: %d pictures" % _images(said),
		not text.contains("Before it is finished") and _images(said) == 0)
	_check("the eyes were asked once (%d), in %d ms" % [_calls(), Time.get_ticks_msec() - started],
		_calls() == 1)
	var args: PackedStringArray = FileAccess.get_file_as_string(
		_fake.path_join("args.txt")).split("\n")
	var tools_at: int = args.find("--tools")
	_check("...with no tools, none of the person's servers or settings, nothing kept",
		tools_at >= 0 and args[tools_at + 1] == "" and args.has("--strict-mcp-config")
		and args.has("--restricted") and args.has("--no-session-persistence")
		and args.has("--json-schema"))
	var sent: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		_fake.path_join("asked.json")))
	var content: Array = sent["message"]["content"]
	var pictures: int = 0
	var words := PackedStringArray()
	for block: Dictionary in content:
		if block["type"] == "image":
			pictures += 1
			_check("  a picture of the model, %d bytes of PNG" % Marshalls.base64_to_raw(
				block["source"]["data"]).size(),
				Marshalls.base64_to_raw(block["source"]["data"]).size() > 1000)
		else:
			words.append(str(block["text"]))
	_check("...shown three pictures, the corner, the front and one close: %s"
		% " | ".join(words.slice(1)), pictures == 3 and words.size() == 4
		and words[1] == "The corner view:" and words[3].begins_with("The close view"))
	_check("...and told the subject and nothing of the session's: %d characters" % words[0].length(),
		words[0].begins_with("A LEGO® model was built to this brief: \"A red tower. a slender "
			+ "red tower\"") and not words[0].contains("assembl")
		and not words[0].contains("omr") and not words[0].contains("real set"))

	said = await _call_as("c1", "save_model", {"name": "tower1.ldr"})
	text = _text(said)
	_check("the next save: the close looks, and no eyes: %s"
		% _line_with(text, "Before it is finished"),
		text.contains("Before it is finished") and not text.contains("fresh pair")
		and _calls() == 1)
	await _call_as("c1", "edit_model", {"recolor": [{"bricks": [_first_brick()], "color": 1}]})
	said = await _call_as("c1", "save_model", {"name": "tower1.ldr"})
	_check("an edit and a save: no eyes", not _text(said).contains("fresh pair") and _calls() == 1)
	await _call_as("c1", "clear_model", {})
	await _call_as("c1", "submit_design", _wall())
	said = await _call_as("c1", "save_model", {"name": "wall1.ldr"})
	_check("a second design in the same sitting: never again", not _text(said).contains(
		"fresh pair") and _calls() == 1)


func _asked_again_for_a_new_chat() -> void:
	print("\n── a new chat's new design ──")
	await _call_as("c2", "clear_model", {})
	await _call_as("c2", "submit_design", _wall())
	var said: Array = await _call_as("c2", "save_model", {"name": "wall2.ldr"})
	_check("is asked again (%d asks)" % _calls(),
		_text(said).contains("1. CHANGE-ONE") and _calls() == 2)
	var sent: String = FileAccess.get_file_as_string(_fake.path_join("asked.json"))
	_check("...of its own subject", sent.contains("A red tower wall. a long low red wall"))


## As the relay's tab opens: the example car on the baseplate as the chat
## begins its subject, taken off by its design (Assistant.make_room).
func _over_the_example() -> void:
	print("\n── a chat in a tab opened on the example car ──")
	await _call_as("c5", "clear_model", {})
	var placed: int = _main.call("_open",
		_main.get_script().get_script_constant_map()["SAMPLE_MODEL"])
	_main.set("_sample_untouched", true)
	(_main.get("_builder") as Builder).forget_history()
	await _call_as("c5", "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	_check("the example car stands as the chat begins its subject (%d parts)" % placed,
		placed > 0 and _parts() == placed)
	await _call_as("c5", "submit_design", _tower())
	_check("...and its design takes it off: %d parts stand" % _parts(), _parts() == 6)
	var said: Array = await _call_as("c5", "save_model", {"name": "tower5.ldr"})
	_check("the eyes are asked (%d asks)" % _calls(),
		_text(said).contains("1. CHANGE-ONE") and _calls() == 3)


func _beside_a_model() -> void:
	print("\n── a chat designing beside the person's own model ──")
	await _call_as("c3", "clear_model", {})
	var theirs: int = _main.call("_open",
		_main.get_script().get_script_constant_map()["SAMPLE_MODEL"])
	_main.set("_sample_untouched", false)
	var built: Array = await _call_as("c3", "submit_design", _wall())
	_check("the wall goes down beside their %d parts: %d stand" % [theirs, _parts()],
		_text(built).contains("Built") and _parts() == theirs + 9)
	var said: Array = await _call_as("c3", "save_model", {"name": "both.ldr"})
	_check("is never asked: %s" % _line_with(_text(said), "Before it is finished"),
		not _text(said).contains("fresh pair") and _calls() == 3)


func _no_answer() -> void:
	print("\n── the eyes fail to answer ──")
	var mode: FileAccess = FileAccess.open(_fake.path_join("fail"), FileAccess.WRITE)
	mode.store_string("1")
	mode.close()
	await _call_as("c4", "clear_model", {})
	await _call_as("c4", "submit_design", _tower())
	var said: Array = await _call_as("c4", "save_model", {"name": "tower4.ldr"})
	var eyes: Object = _assistant.call("fresh_eyes")
	_check("asked (%d), and the save says what it would have: %s" % [_calls(),
		str((eyes.get("last") as Dictionary).get("error", "")).left(40)],
		_calls() == 4 and not _text(said).contains("fresh pair")
		and _text(said).contains("Before it is finished"))


## A stand-in for Claude Code: it writes down its arguments and the message it
## is sent, answers as `claude -p --output-format stream-json` does (or with an
## error once its folder has a file called fail), and waits to be stopped.
func _stand_in() -> String:
	var dir: String = ProjectSettings.globalize_path("user://stand-in")
	DirAccess.make_dir_recursive_absolute(dir)
	var answer: Dictionary = {"type": "result", "is_error": false, "result": "",
		"structured_output": {"reads_as": "a red stack of bricks",
			"generic": "the tower is one straight column",
			"changes": ["CHANGE-ONE: step the top storey in one stud on each side",
				"CHANGE-TWO: a pointed roof of slopes", "CHANGE-THREE: a window in each storey"]},
		"usage": {"input_tokens": 1, "output_tokens": 1}}
	var failed: Dictionary = {"type": "result", "is_error": true, "result": "overloaded"}
	var script: String = "\n".join(PackedStringArray([
		"#!/bin/bash",
		"dir=\"$(dirname \"$0\")\"",
		"printf '%s\\n' \"$@\" > \"$dir/args.txt\"",
		"echo asked >> \"$dir/calls.txt\"",
		"IFS= read -r line",
		"printf '%s\\n' \"$line\" > \"$dir/asked.json\"",
		"echo '{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"stand-in\"}'",
		"if [ -f \"$dir/fail\" ]; then echo '%s'; else echo '%s'; fi" % [
			JSON.stringify(failed), JSON.stringify(answer)],
		"exec sleep 60",
		""]))
	var file: FileAccess = FileAccess.open(dir.path_join("claude"), FileAccess.WRITE)
	file.store_string(script)
	file.close()
	OS.execute("chmod", ["+x", dir.path_join("claude")])
	return dir


func _calls() -> int:
	return FileAccess.get_file_as_string(_fake.path_join("calls.txt")).count("asked")


## A call from the relay's chat [param chat], handed over as the tab's
## connector hands it (ClaudeConnector._answer): its sitting, its subject,
## and the method said once.
func _call_as(chat: String, tool: String, arguments: Dictionary) -> Array:
	_next += 1
	var request: Dictionary = {"jsonrpc": "2.0", "id": _next, "method": "tools/call",
		"params": {"name": tool, "arguments": arguments,
			"_meta": {"brickworks/chat": {"chat": chat, "since": "2026-10-27T06:00:00Z"}}}}
	var sitting: Dictionary = _connector._sitting(request)
	_connector._begin(sitting, tool, arguments)
	var answer: Variant = _connector._taught(sitting, tool,
		await _connector.rpc.answer_rpc(request))
	return ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []) as Array


func _tower() -> Dictionary:
	var bricks: Array = []
	for course: int in 6:
		bricks.append({"part": "3003", "color": 4, "x": 10, "y": 3 * course, "z": 10, "rot": 0})
	return {"name": "A red tower", "description": "a slender red tower", "floor": "none",
		"bricks": bricks, "assemblies": [{"name": "tower", "x_from": 10, "x_to": 12,
			"z_from": 10, "z_to": 12}]}


func _wall() -> Dictionary:
	var bricks: Array = []
	for course: int in 3:
		for n: int in 3:
			bricks.append({"part": "3001", "color": 4,
				"x": 4 * n + (2 if course % 2 else 0) + 4, "y": 3 * course, "z": 4, "rot": 0})
	return {"name": "A red tower wall", "description": "a long low red wall", "floor": "none",
		"bricks": bricks, "assemblies": [{"name": "wall", "x_from": 4, "x_to": 16,
			"z_from": 4, "z_to": 5}]}


func _parts() -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _assistant.scenery.has(brick.id):
			count += 1
	return count


func _first_brick() -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if not _assistant.scenery.has(brick.id):
			return brick.id
	return 0


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.substr(prefix.length() + 1)
	return ""


static func _text(blocks: Array) -> String:
	var out := PackedStringArray()
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "text":
			out.append(str(block.get("text", "")))
	return "\n".join(out)


static func _images(blocks: Array) -> int:
	return blocks.filter(func(block: Dictionary) -> bool:
		return str(block.get("type", "")) == "image").size()


static func _line_with(text: String, word: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(word):
			return line.left(90)
	return ""


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
