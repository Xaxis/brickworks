## Does a new design's first save hand back a fresh pair of eyes, once?
##
##   godot --path . --resolution 1400x900 --script src/dev/fresh_eyes_probe.gd
##
## FreshEyes (src/ai/fresh_eyes.gd): at a connector chat's first whole save of
## a new design, Claude Code is shown the subject and three pictures of the
## model, and the save's answer carries its three changes in place of the close
## looks, which come at the next save. Here Claude Code is a stand-in put first
## on PATH, which writes down what it was started with and sent, and answers
## as Claude Code does. With it, the eyes are asked once and their changes
## said, never at a later save or a second design of the sitting; a new
## chat's new design is asked again, and so is one over the example car a tab
## opens on (the relay's); a chat that designs beside a model already
## standing, a chat about a selection, and an answer that failed, say what
## main says. The eyes see three pictures and the subject, nothing of the
## session. An app started from a desktop icon (PATH=/usr/bin:/bin, the
## stand-in where the installer puts it, ~/.local/bin) still asks it, through
## ClaudeCode.found(). In a window, for the pictures.
##
## The subject the eyes are told is the person's request, whole, in their own
## words: a brief of 1,500 characters reaches their message entire, from a
## connector chat that passes it as submit_design's brief after naming its
## subject in a few words of its own, and from Claude Code started on it here
## (Main.design_with_claude_code), whose session's own brief never replaces
## the app's copy. A chat that passes none is judged by its own subject, never
## by the chat's before. Told the session's "taco food truck", the eyes once
## said to take off the surfboard the brief asked for (critic315).
##
## With no Claude Code (a browser tab, design317) the eyes are the session's
## own: the first whole save hands it the three pictures and the eyes'
## question, every other call but a save is refused until it answers with
## fresh_eyes (twice at most), the answer is kept, and it is asked once a
## subject, never in a chat about a selection.
##
## And once more, last, where the first look was the session's own: at the
## first whole save after the creative pass, never at one before it nor at
## the save that hands the pass over, the save's answer is what it would have
## been, the pass's line and any close look first, then the pictures and the
## final question, answered with fresh_eyes_final before anything else goes
## ahead: what landed of the first look's changes, then done or one change.
## Once a subject; "done" adds nothing; a pass that added nothing waits for
## the next save; no creative pass, no final look; with Claude Code (the
## eyes' first look) none at all.
##
## --dump=FILE writes the Claude Code chat's answers and the tool list there,
## and --baseline runs that chat alone: run with both on main (the file
## copied in) and here, the two files are the same, byte for byte.
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
	var baseline: bool = OS.get_cmdline_user_args().has("--baseline")

	_fake = _stand_in()
	OS.set_environment("PATH", "%s:%s" % [_fake, _path])
	await _asked_once()
	if not baseline:
		await _asked_again_for_a_new_chat()
		await _over_the_example()
		await _beside_a_model()
		await _about_a_selection("c7", 0)
		await _no_answer()
		await _from_a_desktop_icon()
		await _whole_brief_from_a_chat()
		await _whole_brief_on_the_port()
		await _none_from_the_eyes("c14")
		_no_claude_code()
		await _own_look()
		await _own_look_unanswered()
		await _own_final("c16")
		await _own_final_done("c17")
		await _about_a_selection("c10", 1)
	OS.set_environment("PATH", _path)
	OS.set_environment("HOME", _home)

	print("")
	print("fresh eyes: asked once at a new design's first save, its changes said, of the "
		+ "person's whole brief; with no Claude Code, the session's own look asked and answered; "
		+ "and once more after the creative pass" if _failures == 0
		else "fresh eyes: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## No Claude Code on PATH, nor where its installers put it (a home of
## nothing), as in a browser tab.
func _no_claude_code() -> void:
	var empty: String = ProjectSettings.globalize_path("user://no-claude")
	DirAccess.make_dir_recursive_absolute(empty)
	OS.set_environment("PATH", "%s:/usr/bin:/bin" % empty)
	OS.set_environment("HOME", empty)


## With no Claude Code, a new design's first save hands the session the three
## pictures and the eyes' question; nothing else goes ahead until it answers
## in the eyes' shape; then once a subject, as the eyes are.
func _own_look() -> void:
	print("\n── no Claude Code (a browser tab): the session's own look ──")
	_check("Claude Code is not found", ClaudeCode.found().is_empty())
	var asks: int = _calls()
	var listed: Dictionary = _listed("fresh_eyes")
	_check("fresh_eyes is served, read-only, in the eyes' shape: %s"
		% JSON.stringify(listed.get("inputSchema", {}).get("required", [])),
		not listed.is_empty() and bool(listed["annotations"].get("readOnlyHint", false))
		and listed["inputSchema"]["required"] == ["reads_as", "generic", "changes"])
	await _call_as("c8", "clear_model", {})
	await _call_as("c8", "submit_design", _tower())
	var said: Array = await _call_as("c8", "save_model", {"name": "tower8.ldr"})
	var text: String = _text(said)
	_check("the save is written, then the fresh look asked: %s" % _line_with(text, "fresh pair"),
		text.begins_with("Written to tower8.ldr") and text.contains("a fresh pair of eyes")
		and text.contains("never what you meant it to be"))
	_check("...in place of the close looks, as the eyes' answer is",
		not text.contains("Before it is finished"))
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
	_check("...the three pictures the eyes see, the corner, the front and one close: %s"
		% " | ".join(words.slice(2, 5)), pictures == 3 and words.size() >= 6
		and words[2] == "The corner view:" and words[4].begins_with("The close view"))
	_check("...the eyes' own question, of the subject and nothing of the session: %d characters"
		% words[1].length(), words[1] == FreshEyes.prompt(
			"A red tower. a slender red tower") and not words[1].contains("assembl"))
	_check("...and to answer with fresh_eyes before any other call, then make the changes",
		words[5].begins_with("Answer before any other call: fresh_eyes") and words[5].contains(
			"reads_as") and words[5].contains("generic") and words[5].contains("then save_model"))
	_check("no Claude Code was started", _calls() == asks)

	var parts: int = _parts()
	said = await _call_as("c8", "edit_model", {"recolor": [{"bricks": [_first_brick()],
		"color": 1}]})
	_check("an edit before the answer is refused: %s" % _text(said).left(60),
		_text(said).begins_with("Not yet: first answer the fresh look") and _parts() == parts
		and _first_colour() == 4)
	said = await _call_as("c8", "fresh_eyes", {"reads_as": "a red column", "generic": "all of it",
		"changes": ["one"]})
	_check("an answer short of three changes is asked again: %s" % _text(said).left(50),
		_text(said).begins_with("Answer in full") and bool(_eyes().call("waiting")))
	said = await _call_as("c8", "fresh_eyes", {"reads_as": "a red column of six bricks",
		"generic": "one straight stack, no roof", "changes": ["OWN-ONE: step the top in",
			"OWN-TWO: a pointed roof", "OWN-THREE: windows"]})
	var last: Dictionary = _eyes().get("last")
	_check("the answer in the eyes' shape is kept, and the changes to be made: %s"
		% _text(said).left(50), _text(said).begins_with("Now make them")
		and last.get("changes", []) == ["OWN-ONE: step the top in", "OWN-TWO: a pointed roof",
			"OWN-THREE: windows"] and last["reads_as"] == "a red column of six bricks"
		and int(last["refused"]) == 1 and not bool(_eyes().call("waiting")))
	said = await _call_as("c8", "edit_model", {"recolor": [{"bricks": [_first_brick()],
		"color": 1}]})
	_check("then the edit goes ahead", not _text(said).begins_with("Not yet")
		and _first_colour() == 1)
	said = await _call_as("c8", "save_model", {"name": "tower8.ldr"})
	_check("the next save: the close looks, and no fresh look: %s"
		% _line_with(_text(said), "Before it is finished"),
		_text(said).contains("Before it is finished") and not _text(said).contains("fresh pair"))
	await _call_as("c8", "clear_model", {})
	await _call_as("c8", "submit_design", _wall())
	said = await _call_as("c8", "save_model", {"name": "wall8.ldr"})
	_check("a second design in the same sitting: never again",
		not _text(said).contains("fresh pair") and not bool(_eyes().call("waiting")))


## Never answered: two calls refused, then the session builds on; a save goes
## ahead throughout, so what stands is never lost.
func _own_look_unanswered() -> void:
	print("\n── no Claude Code, a new chat that never answers ──")
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


## A chat about a selection is never asked: the person's request is about
## those parts, not a new design. [param own] 1 with no Claude Code.
func _about_a_selection(chat: String, own: int) -> void:
	print("\n── a chat about a selection%s ──" % (", no Claude Code" if own else ""))
	var asks: int = _calls()
	await _call_as(chat, "clear_model", {})
	await _call_as(chat, "submit_design", _tower())
	_check("the person's selection is asked about",
		_assistant.focus_on([_first_brick()], true).is_empty() and _assistant.asked_about_selection())
	var said: Array = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	_check("is never asked: %s" % _text(said).left(60), not _text(said).contains("fresh pair")
		and _images(said) == 0 and _calls() == asks and not bool(_eyes().call("waiting")))
	said = await _call_as(chat, "edit_selection", {"recolor": [{"bricks": [_first_brick()],
		"color": 1}]})
	_check("...and nothing it does is held: %s" % _text(said).left(50),
		not _text(said).begins_with("Not yet"))
	_assistant.unfocus()


func _asked_once() -> void:
	print("── a new design's first save, with Claude Code ──")
	_check("the stand-in is the Claude Code found: %s" % ClaudeCode.found(),
		ClaudeCode.found() == _fake.path_join("claude"))
	var dump := PackedStringArray([JSON.stringify(_connector.rpc.served_tools())])
	await _call_as("c1", "clear_model", {})
	dump.append(_text(await _call_as("c1", "submit_design", _tower())))
	var started: int = Time.get_ticks_msec()
	var said: Array = await _call_as("c1", "save_model", {"name": "tower1.ldr"})
	var text: String = _text(said)
	dump.append(text)
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
	dump.append(text)
	_dump(dump)
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


## [param answers] to --dump's file, the app's data folder said as <user>.
func _dump(answers: PackedStringArray) -> void:
	var dump_to: String = _argument("--dump")
	if dump_to.is_empty():
		return
	var file: FileAccess = FileAccess.open(dump_to, FileAccess.WRITE)
	file.store_string("\n\n=====\n\n".join(answers).replace(OS.get_user_data_dir(), "<user>"))
	file.close()
	print("  answers written to %s" % dump_to)


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


## Started from a desktop icon: no shell PATH, so `which` cannot find the
## stand-in, which is where the installer puts it (the home's .local/bin).
## The eyes find it as the app's own designer does (ClaudeCode.found).
func _from_a_desktop_icon() -> void:
	print("\n── an app started from a desktop icon ──")
	DirAccess.remove_absolute(_fake.path_join("fail"))
	OS.set_environment("PATH", "/usr/bin:/bin")
	OS.set_environment("HOME", _fake.get_base_dir().get_base_dir())
	_check("`which` finds no claude on PATH=%s" % OS.get_environment("PATH"),
		OS.execute("which", ["claude"], [], false) != 0)
	_check("...and ClaudeCode.found() finds the stand-in in the home: %s" % ClaudeCode.found(),
		ClaudeCode.found() == _fake.path_join("claude"))
	await _call_as("c6", "clear_model", {})
	await _call_as("c6", "submit_design", _tower())
	var said: Array = await _call_as("c6", "save_model", {"name": "tower6.ldr"})
	_check("the eyes are asked (%d asks) and their changes said: %s"
		% [_calls(), _line_with(_text(said), "1. CHANGE")],
		_calls() == 5 and _text(said).contains("1. CHANGE-ONE"))
	OS.set_environment("PATH", "%s:%s" % [_fake, _path])
	OS.set_environment("HOME", _home)


## A connector chat names its subject in a few words of its own (plan_scale's
## "a red tower"), and passes the person's request as submit_design's brief.
func _whole_brief_from_a_chat() -> void:
	print("\n── a chat that passes the person's whole brief ──")
	var brief: String = _long_brief("A red tower")
	var before: int = _calls()
	await _call_as("c11", "clear_model", {})
	await _call_as("c11", "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	await _call_as("c11", "submit_design", _with_brief(_tower(), brief))
	var said: Array = await _call_as("c11", "save_model", {"name": "tower11.ldr"})
	var told: String = _told()
	_check("the eyes are asked (%d asks) and their changes said" % (_calls() - before),
		_calls() == before + 1 and _text(said).contains("1. CHANGE-ONE"))
	_check("...told the person's brief of %d characters whole, last words and all"
		% brief.length(), brief.length() >= 1500
		and told.contains("built to this brief: \"%s\"" % brief))
	_check("...never the chat's own name for it (\"a red tower\", \"A red tower. a slender "
		+ "red tower\")", not told.contains("brief: \"a red tower") and not told.contains(
		"brief: \"A red tower. a slender") and not told.contains("a slender red tower"))
	_check("...and that everything the brief asks for stays: %s"
		% _line_with(told, "Everything the brief"),
		told.contains("Everything the brief asks for stays")
		and told.contains("no change takes one away"))
	await _call_as("c12", "clear_model", {})
	await _call_as("c12", "submit_design", _wall())
	said = await _call_as("c12", "save_model", {"name": "wall12.ldr"})
	told = _told()
	_check("the next chat, passing none, is judged by its own subject, not the last brief",
		_calls() == before + 2 and told.contains("brief: \"A red tower wall. a long low red wall\"")
		and not told.contains(brief.left(60)))


## Claude Code started here on the person's request (Main.design_with_claude_code),
## on the port: its session passes a few words of its own as the brief, and the
## eyes are told the app's copy of the person's words.
func _whole_brief_on_the_port() -> void:
	print("\n── Claude Code started here on the person's whole brief ──")
	var brief: String = _long_brief("A red tower by the harbour")
	var before: int = _calls()
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
	var told: String = _told()
	_check("the eyes are asked (%d asks) and their changes said" % (_calls() - before),
		_calls() == before + 1 and _text(said).contains("1. CHANGE-ONE"))
	_check("...told the person's brief whole, last words and all",
		told.contains("built to this brief: \"%s\"" % brief))
	_check("...not the session's \"a red tower\" passed as its brief, nor its name",
		not told.contains("brief: \"a red tower") and not told.contains("a slender red tower"))
	_main.set("_commands", null)


## A touch the creative pass adds: a red 1 x 1 round plate on the tower's foot.
const TOUCH := {"part": "4073", "color": 14, "x": 12, "y": 0, "z": 10}


## A chat's new tower from outside, up to its creative pass: the first look at
## its first save (with no Claude Code, [param own], answered as the session
## would), the close look the next save hands back, and the surface pass,
## settled. No save of these has the final look.
func _to_the_creative_pass(chat: String, own: bool) -> void:
	await _call_as(chat, "clear_model", {})
	await _call_as(chat, "submit_design", _tower())
	var said: Array = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	_check("the first save, the first look: %s" % _line_with(_text(said), "fresh pair"),
		_text(said).contains("a fresh pair of eyes") and not _final_in(said))
	if own:
		said = await _call_as(chat, "fresh_eyes", {"reads_as": "a red column of six bricks",
			"generic": "one straight stack, no roof", "changes": ["OWN-ONE: step the top in",
				"OWN-TWO: a pointed roof", "OWN-THREE: windows"]})
		_check("...answered as the eyes would: %s" % _text(said).left(40),
			_text(said).begins_with("Now make them"))
	said = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	_check("the next save, the close look and no final look: %s"
		% _line_with(_text(said), "Before it is finished"),
		_text(said).contains("Before it is finished") and not _final_in(said))
	said = await _call_as(chat, "review_model", {"surface": true})
	print("  (the surface pass: %s)" % _text(said).left(160).replace("\n", " "))
	said = await _call_as(chat, "settle_surface", {"finding": "all", "verdict": "accept"})
	print("  (settled: %s)" % _text(said).left(160).replace("\n", " "))


## With Claude Code the first look is the eyes', and the final look is the
## session's own alone: through the creative pass every save says what it
## would have, and the eyes are asked once.
func _none_from_the_eyes(chat: String) -> void:
	print("\n── with Claude Code, a design through its creative pass ──")
	var asks: int = _calls()
	await _to_the_creative_pass(chat, false)
	var said: Array = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	var text: String = _text(said)
	_check("the next save hands over the creative pass: %s" % _line_with(text, "creative pass"),
		text.contains("the creative pass, which this app's own designer makes last")
		and not _final_in(said))
	await _call_as(chat, "edit_model", {"add": [TOUCH]})
	said = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	text = _text(said)
	_check("the first save after the pass says what it added, and no final look: %s"
		% _line_with(text, "The creative pass:"), text.contains(
			"The creative pass: 1 part added") and not _final_in(said) and _images(said) == 0)
	await _call_as(chat, "edit_model", {"recolor": [{"bricks": [_first_brick()], "color": 1}]})
	said = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	_check("an edit and a save: the eyes were asked once, at the first (%d asks)"
		% (_calls() - asks), not _final_in(said) and _calls() == asks + 1)


## With no Claude Code: the session asks for the creative pass itself, and
## saves before it adds a touch, then after. The save that says the pass
## added nothing asks for a touch first; the next hands the session the
## pictures and the final question; nothing else goes ahead until it
## answers with fresh_eyes_final, and its one change is to be made. Once.
func _own_final(chat: String) -> void:
	print("\n── no Claude Code, a design through its creative pass: the session's own final look ──")
	var asks: int = _calls()
	var listed: Dictionary = _listed("fresh_eyes_final")
	_check("fresh_eyes_final is served, read-only, in the final look's shape: %s"
		% JSON.stringify(listed.get("inputSchema", {}).get("required", [])),
		not listed.is_empty() and bool(listed["annotations"].get("readOnlyHint", false))
		and listed["inputSchema"]["required"] == ["landed", "reads_as", "generic", "done", "change"])
	await _to_the_creative_pass(chat, true)
	var said: Array = await _call_as(chat, "review_model", {"creative": true})
	_check("the creative pass, asked for: %s" % _text(said).left(40),
		_text(said).begins_with("The creative pass") and not _final_in(said))
	said = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	_check("a save before a touch: the pass added nothing, and no final look yet: %s"
		% _text(said).get_slice("\n\n", 1).left(60),
		_text(said).contains("The creative pass added nothing") and not _final_in(said)
		and _images(said) == 0 and not bool(_eyes().call("final_waiting")))
	await _call_as(chat, "edit_model", {"add": [TOUCH]})
	said = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	var words := PackedStringArray()
	for block: Dictionary in said:
		if block["type"] == "text":
			words.append(str(block["text"]))
	_check("the next save, with the touch: the final look, the session's own: %s"
		% _line_with(_text(said), "one last look"), _text(said).begins_with("Written to %s.ldr" % chat)
		and words[0].contains("one last look with the fresh pair of eyes, now the creative pass is in"))
	_check("...the three pictures, captioned as the first look's: %s" % " | ".join(words.slice(2, 5)),
		_images(said) == 3 and words.size() >= 6 and words[2] == "The corner view:")
	_check("...the final question, of the subject and the first look's own changes: %d characters"
		% words[1].length(), words[1] == _eyes().call("final_prompt",
			"A red tower. a slender red tower", ["OWN-ONE: step the top in",
				"OWN-TWO: a pointed roof", "OWN-THREE: windows"]))
	_check("...and to answer with fresh_eyes_final first, then make the one change",
		words[words.size() - 1].begins_with("Answer before any other call: fresh_eyes_final")
		and words[words.size() - 1].contains("keeping what the creative pass added")
		and bool(_eyes().call("final_waiting")))
	_check("no Claude Code was started", _calls() == asks)
	said = await _call_as(chat, "edit_model", {"recolor": [{"bricks": [_first_brick()],
		"color": 1}]})
	_check("an edit before the answer is refused: %s" % _text(said).left(60),
		_text(said).begins_with("Not yet: first answer the final fresh look")
		and _first_colour() == 4)
	said = await _call_as(chat, "fresh_eyes_final", {"landed": "the top stepped in",
		"reads_as": "a red tower", "generic": "the flat top", "done": false, "change": ""})
	_check("not done and no change is asked again: %s" % _text(said).left(40),
		_text(said).begins_with("Answer in full") and bool(_eyes().call("final_waiting")))
	said = await _call_as(chat, "fresh_eyes_final", {"landed": "OWN-ONE shows; no roof",
		"reads_as": "a red tower with a stepped top", "generic": "the flat top", "done": false,
		"change": "OWN-FINAL: a pointed roof of four slopes"})
	var final: Dictionary = _eyes().get("final")
	_check("the answer is kept, and its one change to be made: %s" % _text(said).left(50),
		_text(said).begins_with("Now make it: edit_model") and final.get("change", "")
		== "OWN-FINAL: a pointed roof of four slopes" and int(final["refused"]) == 1
		and not bool(_eyes().call("final_waiting")))
	said = await _call_as(chat, "edit_model", {"recolor": [{"bricks": [_first_brick()],
		"color": 1}]})
	_check("then the edit goes ahead", not _text(said).begins_with("Not yet")
		and _first_colour() == 1)
	said = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	_check("the next save: never again", not _final_in(said) and _images(said) == 0)
	said = await _call_as(chat, "fresh_eyes_final", {"landed": "x", "reads_as": "x",
		"generic": "x", "done": true, "change": ""})
	_check("...nor answered again: %s" % _text(said).left(40),
		_text(said).begins_with("Nothing to answer"))


## With no Claude Code, as most relay sessions work: the creative pass and its
## touch before the first save, so its line comes at the save after the first
## look, with a close look. The final look comes there, after both, which
## stay word for word (sessions end at that save whatever it hands, 30 of 44
## on design317t); done ends it, and the saves after hand what they would.
func _own_final_done(chat: String) -> void:
	print("\n── no Claude Code, the pass before the first look, then done ──")
	await _call_as(chat, "clear_model", {})
	await _call_as(chat, "submit_design", _tower())
	await _call_as(chat, "review_model", {"creative": true})
	await _call_as(chat, "edit_model", {"add": [TOUCH]})
	var said: Array = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	_check("the first save, the first look and nothing of the pass",
		_text(said).contains("a fresh pair of eyes") and not _text(said).contains(
			"The creative pass:") and not _final_in(said))
	await _call_as(chat, "fresh_eyes", {"reads_as": "a red column", "generic": "one stack",
		"changes": ["OWN-ONE: step the top in", "OWN-TWO: a pointed roof", "OWN-THREE: windows"]})
	said = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	var text: String = _text(said)
	var line: int = text.find("The creative pass: 1 part added")
	var close: int = text.find("Before it is finished: 1 of its 1 assemblies has not had a close look")
	_check("the next save: the pass's line, the close look, then the final look: %d pictures"
		% _images(said), line > 0 and close > line and text.find("one last look") > close
		and _images(said) == 3 and bool(_eyes().call("final_waiting")))
	said = await _call_as(chat, "fresh_eyes_final", {"landed": "all three show",
		"reads_as": "a red tower", "generic": "nothing", "done": true, "change": ""})
	_check("done: %s" % _text(said), _text(said).begins_with("Then it is finished")
		and not bool(_eyes().call("final_waiting")))
	said = await _call_as(chat, "save_model", {"name": "%s.ldr" % chat})
	_check("the next save hands what it would, the surface pass never run, and no look: %s"
		% _line_with(_text(said), "surface pass"), _text(said).contains(
			"The surface pass has not been run") and not _final_in(said) and _images(said) == 0)


## Whether an answer carries the final look, the eyes' or the session's own.
static func _final_in(blocks: Array) -> bool:
	var text: String = _text(blocks)
	return text.contains("looked once more") or text.contains("one last look")


## A stand-in for Claude Code: it writes down its arguments and the message it
## is sent, answers as `claude -p --output-format stream-json` does (or with an
## error once its folder has a file called fail), and waits to be stopped. It
## sits in a home of its own's .local/bin, where the installer puts claude.
func _stand_in() -> String:
	var dir: String = ProjectSettings.globalize_path("user://home/.local/bin")
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
		# A design session (Main.design_with_claude_code): its brief, and done.
		"case \" $* \" in *' --json-schema '*) ;; *) printf '%s' \"$2\" > \"$dir/designed.txt\"; exit 0;; esac",
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


## The words the eyes were last sent, ahead of the pictures.
func _told() -> String:
	var sent: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		_fake.path_join("asked.json")))
	if not sent is Dictionary:
		return ""
	return str(((sent as Dictionary)["message"]["content"] as Array)[0].get("text", ""))


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
