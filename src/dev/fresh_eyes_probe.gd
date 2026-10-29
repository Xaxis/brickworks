## Does a new design's first save hand back a fresh look, once?
##
##   godot --path . --resolution 1400x900 --script src/dev/fresh_eyes_probe.gd
##
## FreshEyes (src/ai/fresh_eyes.gd): at a connector chat's first whole save
## of a new design, the save hands the session the design's three pictures and
## the judge's question, in place of the close looks, which come at the next
## save. Every call but a save and fresh_eyes is refused until it answers in
## the judge's shape (twice at most), and the answer is kept. Once a subject:
## never at a later save or a second design of the sitting; a new chat's new
## design is asked again, and so is one over the example car a tab opens on
## (the relay's); a chat that designs beside a model already standing, and a
## chat about a selection, say what main says.
##
## The eyes are the session's own whether Claude Code is on the machine or
## not (design330: a separate Claude Code critic did no better, design328).
## A stand-in claude first on PATH writes down every start, and the look
## never starts it; then with no Claude Code anywhere, as in a browser tab,
## the look is the same. In a window, for the pictures.
##
## The subject the eyes are told is the person's request, whole, in their own
## words: a brief of 1,500 characters reaches their question entire, from a
## connector chat that passes it as submit_design's brief after naming its
## subject in a few words of its own, and from Claude Code started on it here
## (Main.design_with_claude_code), whose session's own brief never replaces
## the app's copy. A chat that passes none is judged by its own subject, never
## by the chat's before. Told the session's "taco food truck", the eyes once
## said to take off the surfboard the brief asked for (critic315).
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _connector: ClaudeConnector
var _assistant: Assistant
var _next: int = 0
var _fake: String = ""
var _path: String = ""
var _home: String = ""


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
	_home = OS.get_environment("HOME")

	_fake = _stand_in()
	OS.set_environment("PATH", "%s:%s" % [_fake, _path])
	await _asked_once()
	await _unanswered()
	await _over_the_example()
	await _beside_a_model()
	await _about_a_selection("c7")
	await _whole_brief_from_a_chat()
	await _whole_brief_on_the_port()
	_no_claude_code()
	await _without_claude_code()
	await _about_a_selection("c10")
	OS.set_environment("PATH", _path)
	OS.set_environment("HOME", _home)

	print("")
	print("fresh eyes: the session's own look asked once at a new design's first save, of "
		+ "the person's whole brief, with Claude Code or without, and Claude Code never "
		+ "started for it" if _failures == 0 else "fresh eyes: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## Claude Code here (the stand-in): the first whole save hands the session the
## three pictures and the judge's question; nothing else goes ahead until it
## answers in the judge's shape; then once a subject. Claude Code never starts.
func _asked_once() -> void:
	print("── a new design's first save, with Claude Code here ──")
	_check("the stand-in is the Claude Code found: %s" % ClaudeCode.found(),
		ClaudeCode.found() == _fake.path_join("claude"))
	var listed: Dictionary = _listed("fresh_eyes")
	_check("fresh_eyes is served, read-only, in the judge's shape: %s"
		% JSON.stringify(listed.get("inputSchema", {}).get("required", [])),
		not listed.is_empty() and bool(listed["annotations"].get("readOnlyHint", false))
		and listed["inputSchema"]["required"] == ["reads_as", "generic", "changes"])
	var starts: int = _starts()
	await _call_as("c1", "clear_model", {})
	await _call_as("c1", "submit_design", _tower())
	var said: Array = await _call_as("c1", "save_model", {"name": "tower1.ldr"})
	var text: String = _text(said)
	_check("the save is written, then the fresh look asked: %s" % _line_with(text, "fresh pair"),
		text.begins_with("Written to tower1.ldr") and text.contains("a fresh pair of eyes")
		and text.contains("never what you meant it to be"))
	_check("...in place of the close looks", not text.contains("Before it is finished"))
	var words := PackedStringArray()
	var pictures: int = 0
	for block: Dictionary in said:
		if block["type"] == "image":
			pictures += 1
			_check("  a picture of the model, %d bytes of PNG" % Marshalls.base64_to_raw(
				block["data"]).size(), Marshalls.base64_to_raw(block["data"]).size() > 1000
				and block["mimeType"] == "image/png")
		else:
			words.append(str(block["text"]))
	_check("...the three pictures the judge sees, the corner, the front and one close: %s"
		% " | ".join(words.slice(2, 5)), pictures == 3 and words.size() >= 6
		and words[2] == "The corner view:" and words[4].begins_with("The close view"))
	_check("...the judge's own question, of the subject and nothing of the session: %d "
		% words[1].length() + "characters", words[1] == FreshEyes.prompt(
			"A red tower. a slender red tower") and not words[1].contains("assembl")
		and not words[1].contains("omr") and not words[1].contains("real set"))
	_check("...and to answer with fresh_eyes before any other call, then make the changes",
		words[5].begins_with("Answer before any other call: fresh_eyes") and words[5].contains(
			"reads_as") and words[5].contains("generic") and words[5].contains("then save_model"))
	_check("Claude Code was never started for it (%d starts)" % (_starts() - starts),
		_starts() == starts)

	var parts: int = _parts()
	said = await _call_as("c1", "edit_model", {"recolor": [{"bricks": [_first_brick()],
		"color": 1}]})
	_check("an edit before the answer is refused: %s" % _text(said).left(60),
		_text(said).begins_with("Not yet: first answer the fresh look") and _parts() == parts
		and _first_colour() == 4)
	said = await _call_as("c1", "fresh_eyes", {"reads_as": "a red column", "generic": "all of it",
		"changes": ["one"]})
	_check("an answer short of three changes is asked again: %s" % _text(said).left(50),
		_text(said).begins_with("Answer in full") and bool(_eyes().call("waiting")))
	said = await _call_as("c1", "fresh_eyes", {"reads_as": "a red column of six bricks",
		"generic": "one straight stack, no roof", "changes": ["OWN-ONE: step the top in",
			"OWN-TWO: a pointed roof", "OWN-THREE: windows"]})
	var last: Dictionary = _eyes().get("last")
	_check("the answer in the judge's shape is kept, and the changes to be made: %s"
		% _text(said).left(50), _text(said).begins_with("Now make them")
		and last.get("changes", []) == ["OWN-ONE: step the top in", "OWN-TWO: a pointed roof",
			"OWN-THREE: windows"] and last["reads_as"] == "a red column of six bricks"
		and int(last["refused"]) == 1 and not bool(_eyes().call("waiting")))
	said = await _call_as("c1", "edit_model", {"recolor": [{"bricks": [_first_brick()],
		"color": 1}]})
	_check("then the edit goes ahead", not _text(said).begins_with("Not yet")
		and _first_colour() == 1)
	said = await _call_as("c1", "save_model", {"name": "tower1.ldr"})
	_check("the next save: the close looks, and no fresh look: %s"
		% _line_with(_text(said), "Before it is finished"),
		_text(said).contains("Before it is finished") and not _text(said).contains("fresh pair"))
	await _call_as("c1", "clear_model", {})
	await _call_as("c1", "submit_design", _wall())
	said = await _call_as("c1", "save_model", {"name": "wall1.ldr"})
	_check("a second design in the same sitting: never again",
		not _text(said).contains("fresh pair") and not bool(_eyes().call("waiting")))
	_check("...and Claude Code never started (%d starts)" % (_starts() - starts),
		_starts() == starts)


## Never answered: two calls refused, then the session builds on; a save goes
## ahead throughout, so what stands is never lost.
func _unanswered() -> void:
	print("\n── a new chat that never answers ──")
	await _call_as("c9", "clear_model", {})
	await _call_as("c9", "submit_design", _tower())
	var said: Array = await _call_as("c9", "save_model", {"name": "tower9.ldr"})
	_check("a new chat's new design is asked again: %d pictures" % _images(said),
		_images(said) == 3 and _text(said).contains("fresh pair") and bool(_eyes().call("waiting")))
	said = await _call_as("c9", "save_model", {"name": "tower9.ldr"})
	_check("a save before the answer goes ahead: %s" % _text(said).left(40),
		_text(said).begins_with("Written to tower9.ldr") and bool(_eyes().call("waiting")))
	var refused: int = 0
	for n: int in 2:
		said = await _call_as("c9", "view_model", {})
		refused += 1 if _text(said).begins_with("Not yet") else 0
	_check("two more calls refused (%d)" % refused, refused == 2)
	said = await _call_as("c9", "view_model", {})
	_check("...and the third goes ahead, and the look is let go of: %d pictures" % _images(said),
		not _text(said).begins_with("Not yet") and _images(said) > 0
		and not bool(_eyes().call("waiting")))


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
	_check("the fresh look is asked: %d pictures" % _images(said),
		_images(said) == 3 and bool(_eyes().call("waiting")))
	await _answer("c5")


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
		not _text(said).contains("fresh pair") and _images(said) == 0
		and not bool(_eyes().call("waiting")))


## A chat about a selection is never asked: the person's request is about
## those parts, not a new design.
func _about_a_selection(chat: String) -> void:
	print("\n── a chat about a selection%s ──" % (
		"" if not ClaudeCode.found().is_empty() else ", no Claude Code"))
	await _call_as(chat, "clear_model", {})
	await _call_as(chat, "submit_design", _tower())
	_check("the person's selection is asked about",
		_assistant.focus_on([_first_brick()], true).is_empty() and _assistant.asked_about_selection())
	var said: Array = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	_check("is never asked: %s" % _text(said).left(60), not _text(said).contains("fresh pair")
		and _images(said) == 0 and not bool(_eyes().call("waiting")))
	said = await _call_as(chat, "edit_selection", {"recolor": [{"bricks": [_first_brick()],
		"color": 1}]})
	_check("...and nothing it does is held: %s" % _text(said).left(50),
		not _text(said).begins_with("Not yet"))
	_assistant.unfocus()


## A connector chat names its subject in a few words of its own (plan_scale's
## "a red tower"), and passes the person's request as submit_design's brief.
func _whole_brief_from_a_chat() -> void:
	print("\n── a chat that passes the person's whole brief ──")
	var brief: String = _long_brief("A red tower")
	await _call_as("c11", "clear_model", {})
	await _call_as("c11", "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	await _call_as("c11", "submit_design", _with_brief(_tower(), brief))
	var told: String = _question(await _call_as("c11", "save_model", {"name": "tower11.ldr"}))
	_check("the fresh look is asked, told the person's brief of %d characters whole, last "
		% brief.length() + "words and all", brief.length() >= 1500
		and told.contains("built to this brief: \"%s\"" % brief))
	_check("...never the chat's own name for it (\"a red tower\", \"A red tower. a slender "
		+ "red tower\")", not told.contains("brief: \"a red tower") and not told.contains(
		"brief: \"A red tower. a slender") and not told.contains("a slender red tower"))
	_check("...and that everything the brief asks for stays: %s"
		% _line_with(told, "Everything the brief"),
		told.contains("Everything the brief asks for stays")
		and told.contains("no change takes one away"))
	await _answer("c11")
	await _call_as("c12", "clear_model", {})
	await _call_as("c12", "submit_design", _wall())
	told = _question(await _call_as("c12", "save_model", {"name": "wall12.ldr"}))
	_check("the next chat, passing none, is judged by its own subject, not the last brief",
		told.contains("brief: \"A red tower wall. a long low red wall\"")
		and not told.contains(brief.left(60)))
	await _answer("c12")


## Claude Code started here on the person's request (Main.design_with_claude_code),
## on the port: its session passes a few words of its own as the brief, and the
## eyes are told the app's copy of the person's words. That start is the
## designer's, the only one.
func _whole_brief_on_the_port() -> void:
	print("\n── Claude Code started here on the person's whole brief ──")
	var brief: String = _long_brief("A red tower by the harbour")
	var starts: int = _starts()
	var designed: String = _fake.path_join("designed.txt")
	DirAccess.remove_absolute(designed)
	_main.set("_commands", _connector.rpc)
	var started: bool = _main.call("design_with_claude_code", brief)
	var until: int = Time.get_ticks_msec() + 20000
	while not FileAccess.file_exists(designed) and Time.get_ticks_msec() < until:
		await process_frame
	for _n: int in 10:
		await process_frame
	_check("Claude Code is started on the brief of %d characters, whole" % brief.length(),
		started and FileAccess.get_file_as_string(designed) == brief)
	await _port_call("clear_model", {})
	await _port_call("submit_design", _with_brief(_tower(), "a red tower"))
	var said: Array = await _port_call("save_model", {"name": "tower13.ldr"})
	var told: String = _question(said)
	_check("the fresh look is asked: %d pictures" % _images(said),
		_images(said) == 3 and bool(_eyes().call("waiting")))
	_check("...told the person's brief whole, last words and all",
		told.contains("built to this brief: \"%s\"" % brief))
	_check("...not the session's \"a red tower\" passed as its brief, nor its name",
		not told.contains("brief: \"a red tower") and not told.contains("a slender red tower"))
	await _port_call("fresh_eyes", _full_answer())
	_check("...answered, and Claude Code started once, as the designer (%d starts)"
		% (_starts() - starts), not bool(_eyes().call("waiting")) and _starts() == starts + 1)
	_main.set("_commands", null)


## No Claude Code on PATH, nor where its installers put it (a home of
## nothing), as in a browser tab.
func _no_claude_code() -> void:
	var empty: String = ProjectSettings.globalize_path("user://no-claude")
	DirAccess.make_dir_recursive_absolute(empty)
	OS.set_environment("PATH", "%s:/usr/bin:/bin" % empty)
	OS.set_environment("HOME", empty)


## With no Claude Code, the same look: the three pictures and the same
## question, and nothing else ahead of the answer.
func _without_claude_code() -> void:
	print("\n── no Claude Code (a browser tab) ──")
	_check("Claude Code is not found", ClaudeCode.found().is_empty())
	_check("...and fresh_eyes is served as before", not _listed("fresh_eyes").is_empty())
	await _call_as("c8", "clear_model", {})
	await _call_as("c8", "submit_design", _tower())
	var said: Array = await _call_as("c8", "save_model", {"name": "tower8.ldr"})
	_check("the save asks the same fresh look: %d pictures" % _images(said),
		_images(said) == 3 and _question(said) == FreshEyes.prompt(
			"A red tower. a slender red tower") and bool(_eyes().call("waiting")))
	said = await _call_as("c8", "view_model", {})
	_check("...and a call before the answer is refused: %s" % _text(said).left(50),
		_text(said).begins_with("Not yet"))
	said = await _call_as("c8", "fresh_eyes", _full_answer())
	_check("...then answered: %s" % _text(said).left(40),
		_text(said).begins_with("Now make them") and not bool(_eyes().call("waiting")))


## A stand-in for Claude Code, in a home of its own's .local/bin, where the
## installer puts claude. It writes down every start; started as the
## designer (Main.design_with_claude_code), it writes down its brief too.
func _stand_in() -> String:
	var dir: String = ProjectSettings.globalize_path("user://home/.local/bin")
	DirAccess.make_dir_recursive_absolute(dir)
	var script: String = "\n".join(PackedStringArray([
		"#!/bin/bash",
		"dir=\"$(dirname \"$0\")\"",
		"echo started >> \"$dir/started.txt\"",
		"case \" $* \" in *' --json-schema '*) ;; *) printf '%s' \"$2\" > \"$dir/designed.txt\";; esac",
		""]))
	var file: FileAccess = FileAccess.open(dir.path_join("claude"), FileAccess.WRITE)
	file.store_string(script)
	file.close()
	OS.execute("chmod", ["+x", dir.path_join("claude")])
	return dir


func _starts() -> int:
	return FileAccess.get_file_as_string(_fake.path_join("started.txt")).count("started")


## The judge's question a save handed back, ahead of the pictures: "" for none.
func _question(said: Array) -> String:
	for block: Dictionary in said:
		if str(block.get("text", "")).begins_with("A LEGO® model was built to this brief"):
			return str(block["text"])
	return ""


static func _full_answer() -> Dictionary:
	return {"reads_as": "a red column", "generic": "one straight stack",
		"changes": ["ONE", "TWO", "THREE"]}


## [param chat]'s answer to the look its save asked for.
func _answer(chat: String) -> void:
	var said: Array = await _call_as(chat, "fresh_eyes", _full_answer())
	_check("  answered: %s" % _text(said).left(30), _text(said).begins_with("Now make them"))


## A call on the MCP port, as Claude Code started here makes it: no chat, no
## sitting (CommandSocket.answer_rpc, which the connector's calls go through too).
func _port_call(tool: String, arguments: Dictionary) -> Array:
	_next += 1
	var answer: Variant = await _connector.rpc.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	return ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []) as Array


## A request of the owner's kind, long: past 1,500 characters, one thing named
## after another, its last words far past where the eyes once cut it (400).
static func _long_brief(subject: String) -> String:
	var said: String = "%s, as I picture it:" % subject
	var n: int = 0
	while said.length() < 1480:
		n += 1
		said += " detail %d stands where I put it," % n
	return said + " and the surfboard strapped to its roof."


static func _with_brief(design: Dictionary, brief: String) -> Dictionary:
	var given: Dictionary = design.duplicate()
	given["brief"] = brief
	return given


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


func _first_colour() -> int:
	return _world.get_brick(_first_brick()).color_code


func _eyes() -> Object:
	return _assistant.call("fresh_eyes")


## [param name]'s entry in the tool list, as a session is given it, or {}.
func _listed(name: String) -> Dictionary:
	for tool: Dictionary in _connector.rpc.served_tools():
		if tool["name"] == name:
			return tool
	return {}


func _first_brick() -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if not _assistant.scenery.has(brick.id):
			return brick.id
	return 0


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
