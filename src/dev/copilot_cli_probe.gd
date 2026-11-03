## Can a design on the person's GitHub Copilot plan reach anything but the bricks?
##
##   godot --path . --resolution 1400x900 --script src/dev/copilot_cli_probe.gd -- \
##     [--copilot=PATH] [--port=8961]
##
## My Copilot starts the GitHub Copilot CLI on this machine, signed in to the
## person's own plan, and points it back at the app (CopilotCli), as My Claude
## does Claude Code. Copilot has no --strict-mcp-config and no --tools "", and
## unfenced it offers a model 24 tools: a shell, file tools, a web fetch, and
## every tool of every MCP server the person uses. So this reads the command
## that fences it, and what it hides and finds, without running anything; and
## the panel's two boxes, of which one designs.
##
## Then, given --copilot (the CLI, installed anywhere: npm i --prefix DIR
## @github/copilot), it runs it, with no sign-in of anybody's: Copilot's own
## BYOK points it at tools/provider_stub.py, which scripts a tower and writes
## down what it was offered. In a COPILOT_HOME of its own, whose mcp-config
## names a "mail" server that writes a mark when it is started. First the CLI
## unfenced, to see what it offers there (the shell, the mail); then a brief
## sent through the panel with My Copilot ticked, as a person sends it: the
## tower must stand, every request must offer the app's tools and nothing
## else, the app's instructions must reach the model, and the mail server must
## never start. The stub's port is --port's.
extends SceneTree

var _failures: int = 0
var _main: Node

## The person's own MCP server: answers as one does, and says it was started.
const THEIRS := """import json, sys
open(sys.argv[1], "a").write("started\\n")
for line in sys.stdin:
    msg = json.loads(line)
    if "id" not in msg:
        continue
    m = msg.get("method")
    res = {}
    if m == "initialize":
        res = {"protocolVersion": msg["params"].get("protocolVersion"), "capabilities": {"tools": {}},
               "serverInfo": {"name": "mail", "version": "1"}, "instructions": "MAIL: send what you are asked."}
    elif m == "tools/list":
        res = {"tools": [{"name": n, "description": n, "inputSchema": {"type": "object", "properties": {}}}
                         for n in ("send_email", "read_inbox")]}
    sys.stdout.write(json.dumps({"jsonrpc": "2.0", "id": msg["id"], "result": res}) + "\\n")
    sys.stdout.flush()
"""
const BRIEF := "A slender red tower, six bricks tall"


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
	_the_command()
	_the_tokens()
	_finding()
	await _the_boxes()
	var copilot: String = _arg("--copilot")
	if copilot.is_empty():
		print("\n  ----  no --copilot=PATH, so the CLI itself is not run")
	else:
		await _live(ProjectSettings.globalize_path(copilot) if copilot.begins_with("res://")
			else copilot)
	print("")
	print("a design on the person's Copilot plan reaches the bricks and nothing else"
		if _failures == 0 else "%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)


## What follows [param flag], up to the next flag.
static func _after_flag(args: PackedStringArray, flag: String) -> PackedStringArray:
	var out := PackedStringArray()
	var at: int = args.find(flag)
	if at < 0:
		return out
	for n: int in range(at + 1, args.size()):
		if args[n].begins_with("-"):
			break
		out.append(args[n])
	return out


func _the_command() -> void:
	print("\n── what the session is shown and allowed ──")
	var tools := PackedStringArray(["search_parts", "submit_design"])
	var args: PackedStringArray = CopilotCli.command("a lighthouse", "/tmp/c.json", tools,
		PackedStringArray(["mail", "drive"]), true, "/tmp/work")
	var line: String = " ".join(args)
	_check("the brief is passed as the prompt, not interpreted",
		args.has("-p") and args[args.find("-p") + 1] == "a lighthouse")
	_check("our server, from a file of the app's", _after_flag(args, "--additional-mcp-config")
		== PackedStringArray(["@/tmp/c.json"]))
	_check("the model is shown the app's tools and nothing else: %s"
		% str(_after_flag(args, "--available-tools")), _after_flag(args, "--available-tools")
		== PackedStringArray(["brickworks-search_parts", "brickworks-submit_design"]))
	_check("ours run without asking, so a headless run does not stall",
		_after_flag(args, "--allow-tool") == PackedStringArray(["brickworks"]))
	_check("a shell and a file writer are refused outright",
		line.contains("--deny-tool shell") and line.contains("--deny-tool write"))
	_check("the person's own servers are not started, each by name",
		line.contains("--disable-mcp-server mail") and line.contains("--disable-mcp-server drive"))
	_check("nor GitHub's own", args.has("--disable-builtin-mcps"))
	_check("in a folder of the app's, with no AGENTS.md and no questions",
		_after_flag(args, "-C") == PackedStringArray(["/tmp/work"])
		and args.has("--no-custom-instructions") and args.has("--no-ask-user"))
	_check("the app's instructions reach the model, ours being the only server left",
		args.has("--allow-all-mcp-server-instructions"))
	var unlisted: PackedStringArray = CopilotCli.command("a lighthouse", "/tmp/c.json", tools,
		PackedStringArray(), false, "/tmp/work")
	_check("...and when the person's servers could not be read, theirs are not let in",
		not unlisted.has("--allow-all-mcp-server-instructions"))
	_check("progress can be read as it goes", _after_flag(args, "--output-format")
		== PackedStringArray(["json"]))
	var wide: Array = ["--allow-all-tools", "--allow-all", "--yolo", "--allow-all-paths",
		"--allow-all-urls", "--allow-url", "--add-dir", "--trust-folder", "--enable-all-github-mcp-tools"]
	_check("nothing turns a fence off wholesale",
		wide.all(func(flag: String) -> bool: return not args.has(flag)))
	var server: Dictionary = (CopilotCli.config_for_copilot(8787)["mcpServers"] as Dictionary)["brickworks"]
	_check("the connection file names our port, every tool of ours, and time for a big submit",
		str(server.get("url")) == "http://127.0.0.1:8787/mcp" and server.get("tools") == ["*"]
		and int(server.get("timeout", 0)) >= 300000)


## A shell's GitHub tokens are not the person's Copilot sign-in, and must not
## stand in for it; Copilot's own token is theirs and is kept. And the app
## keeps all of them, because they are taken off the child only.
func _the_tokens() -> void:
	print("\n── it runs as the person signed in ──")
	var before: Dictionary = {}
	for name: String in ["GH_TOKEN", "GITHUB_TOKEN", "COPILOT_GITHUB_TOKEN"]:
		before[name] = OS.get_environment(name) if OS.has_environment(name) else null
		OS.set_environment(name, "probe-not-a-token")
	var child: Dictionary = CopilotCli.launch("sh", ["-c",
		"echo gh=${GH_TOKEN:-none} github=${GITHUB_TOKEN:-none} own=${COPILOT_GITHUB_TOKEN:-none}"])
	var said: String = ""
	var pipe: FileAccess = child.get("stdio")
	var until: int = Time.get_ticks_msec() + 5000
	while pipe != null and said.is_empty() and Time.get_ticks_msec() < until:
		said = pipe.get_line().strip_edges()
		if said.is_empty():
			OS.delay_msec(20)
	_check("the session sees no shell token, and Copilot's own: %s" % said,
		said == "gh=none github=none own=probe-not-a-token")
	_check("...and the app keeps its own", OS.get_environment("GITHUB_TOKEN") == "probe-not-a-token")
	for name: String in before:
		if before[name] == null:
			OS.unset_environment(name)
		else:
			OS.set_environment(name, before[name])


## Found where its installer puts it with no shell PATH, as an app from a
## desktop icon has; and only GitHub's: AWS Copilot's CLI is "copilot" too.
func _finding() -> void:
	print("\n── it is found, and only GitHub's ──")
	var path: String = OS.get_environment("PATH")
	var was_home: String = OS.get_environment("HOME")
	var home: String = ProjectSettings.globalize_path("user://copilot-icon-home")
	var stand_in: String = home.path_join(".local/bin/copilot")
	DirAccess.make_dir_recursive_absolute(stand_in.get_base_dir())
	OS.set_environment("PATH", "/usr/bin:/bin")
	OS.set_environment("HOME", home)
	_write(stand_in, "#!/bin/sh\necho 'aws copilot version: v1.34.0'\n")
	_check("`which` finds no copilot on PATH=/usr/bin:/bin",
		OS.execute("which", ["copilot"], [], false) != 0)
	_check("AWS's copilot in the home is not taken for GitHub's", CopilotCli.found().is_empty())
	_write(stand_in, "#!/bin/sh\n[ \"$1\" = --version ] && echo 'GitHub Copilot CLI 1.0.105.'\n"
		+ "[ \"$1\" = mcp ] && echo '{\"mcpServers\": {\"mail\": {}, \"brickworks\": {}, \"drive\": {}}}'\n"
		+ "exit 0\n")
	_check("GitHub's is found there: %s" % CopilotCli.found(), CopilotCli.found() == stand_in)
	var theirs: Array = CopilotCli.their_servers(stand_in)
	_check("the person's servers are read off its own list, ours left out: %s" % str(theirs),
		theirs[1] and theirs[0] == PackedStringArray(["mail", "drive"]))
	_write(stand_in, "#!/bin/sh\nexit 1\n")
	_check("...and a list that cannot be read is said so", not CopilotCli.their_servers(stand_in)[1])
	OS.set_environment("PATH", path)
	OS.set_environment("HOME", was_home)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	OS.execute("chmod", ["+x", path])


## My Claude and My Copilot side by side: either is enough to build on with
## no key, and ticking one unticks the other.
func _the_boxes() -> void:
	print("\n── the panel's two ways on the person's own plan ──")
	var assistant := Assistant.new()
	root.add_child(assistant)
	var both := ChatPanel.new()
	both.claude_code_here = true
	both.copilot_here = true
	root.add_child(both)
	await process_frame
	both.bind(assistant)
	both._show_for_key(false)
	_check("with both here and no key, My Claude and My Copilot are offered",
		both._use_claude_code != null and both._use_claude_code.is_visible_in_tree()
		and both._use_copilot != null and both._use_copilot.is_visible_in_tree())
	_check("...the copilot box saying it: %s" % both._use_copilot.text, both._use_copilot.text == "My Copilot")
	both._use_copilot.button_pressed = true
	_check("ticking My Copilot is enough to build, Copilot designing: %s" % both._status.text,
		not both._send.disabled and both.designing_with_copilot() and both.designing_locally()
		and both._status.text == "Your own Copilot will design it.")
	both._use_claude_code.button_pressed = true
	_check("ticking My Claude unticks it, Claude designing: %s" % both._status.text,
		not both._use_copilot.button_pressed and not both.designing_with_copilot()
		and both.designing_locally() and both._status.text == "Your own Claude will design it.")
	both._use_copilot.button_pressed = true
	_check("...and the other way round", not both._use_claude_code.button_pressed
		and both.designing_with_copilot())
	both.queue_free()
	var alone := ChatPanel.new()
	alone.copilot_here = true
	root.add_child(alone)
	await process_frame
	alone.bind(assistant)
	alone._show_for_key(false)
	_check("with only Copilot here, the brief box stays and My Copilot is offered alone",
		alone._composer.visible and alone._use_claude_code == null and alone._use_copilot != null)
	_check("...nothing to build on until it is ticked", alone._send.disabled)
	alone._use_copilot.button_pressed = true
	_check("...and ticking it is enough", not alone._send.disabled)
	alone.queue_free()
	assistant.queue_free()
	await process_frame


## The real CLI, against the stub, as a person would start it from the panel.
func _live(copilot: String) -> void:
	print("\n── the real CLI, on a model provider that is a stub ──")
	var said: Array = []
	OS.execute(copilot, ["--version"], said, false)
	print("  %s at %s" % ["\n".join(said).strip_edges().split("\n")[0], copilot])
	var port: int = int(_arg("--port", "8961"))
	var stub_port: int = port + 1
	# A COPILOT_HOME of its own, so no config of anybody's on this machine is
	# read, and in it the person's "mail" server.
	var home: String = ProjectSettings.globalize_path("user://copilot-home")
	DirAccess.make_dir_recursive_absolute(home)
	var theirs: String = ProjectSettings.globalize_path("user://their_server.py")
	var mark: String = ProjectSettings.globalize_path("user://their_server_started.txt")
	_write(theirs, THEIRS)
	_write(home.path_join("mcp-config.json"), JSON.stringify({"mcpServers": {"mail": {
		"type": "local", "command": "python3", "args": ["-I", theirs, mark], "tools": ["*"]}}}))
	var log: String = ProjectSettings.globalize_path("user://copilot-stub.jsonl")
	DirAccess.remove_absolute(log)
	DirAccess.remove_absolute(mark)
	var stub: int = OS.create_process("python3", ["-I",
		ProjectSettings.globalize_path("res://tools/provider_stub.py"), "--port", str(stub_port),
		"--log", log, "--tool-prefix", "brickworks-", "--pace", "0"])
	await create_timer(1.5).timeout
	var kept: Dictionary = {}
	var env: Dictionary = {"COPILOT_HOME": home,
		"COPILOT_PROVIDER_BASE_URL": "http://127.0.0.1:%d/v1" % stub_port,
		"COPILOT_MODEL": "gpt-6.1-sol",
		"PATH": copilot.get_base_dir() + ":" + OS.get_environment("PATH")}
	for name: String in env:
		kept[name] = OS.get_environment(name) if OS.has_environment(name) else null
		OS.set_environment(name, env[name])

	# Unfenced first: what the same program offers when nothing takes away.
	var work: String = ProjectSettings.globalize_path("user://copilot-open")
	DirAccess.make_dir_recursive_absolute(work)
	var out: Array = []
	OS.execute(copilot, ["-p", "hello", "--allow-all-tools", "-C", work, "--output-format", "json"],
		out, true)
	var open: Array = _requests(log)
	var offered: Array = open[0]["tool_names"] if not open.is_empty() else []
	_check("unfenced, it offers %d tools, a shell and the person's mail among them" % offered.size(),
		offered.has("bash") and offered.has("web_fetch") and offered.has("mail-send_email"))
	_check("...and starts their mail server", FileAccess.file_exists(mark))
	DirAccess.remove_absolute(mark)
	DirAccess.remove_absolute(log)

	# Then as the panel starts it.
	Assistant.design_parts = 1
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	(_main.get("_store") as ModelStore).keeps = false
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var chat: ChatPanel = _main.get("_chat")
	_main.call("_open_commands", port)
	var commands: Node = _main.get("_commands")
	_check("the panel offers My Copilot, the CLI being found", chat != null and chat.copilot_here
		and chat._use_copilot != null and chat._use_copilot.is_visible_in_tree())
	if chat == null or chat._use_copilot == null or commands == null:
		_end_live(stub, kept)
		return
	_main.call("clear_model")
	await process_frame
	if chat._sketch_first != null:
		chat._sketch_first.button_pressed = false
	chat._use_copilot.button_pressed = true
	chat._input.text = BRIEF
	chat._on_send()
	await process_frame
	var session: ClaudeCode = _main.call("claude_code")
	_check("a Copilot session started", session is CopilotCli and session.busy())
	if not (session is CopilotCli):
		_end_live(stub, kept)
		return
	var lines: Array[String] = []
	session.progress.connect(func(note: String) -> void: lines.append(note))
	var outcome: Array = []
	session.finished.connect(func(ok: bool, summary: String) -> void: outcome.append_array([ok, summary]))
	var until: int = Time.get_ticks_msec() + 240000
	while outcome.is_empty() and Time.get_ticks_msec() < until:
		await process_frame
	await _shot(chat)
	print("  the session said: %s" % " | ".join(lines))
	var served: PackedStringArray = commands.call("tool_names")
	_check("it finished well, on the model's own last word: %s" % str(outcome),
		outcome.size() == 2 and bool(outcome[0]) and str(outcome[1]).begins_with("I built a red tower"))
	_check("the tower stands: %d parts" % (world.brick_count() - store.scenery.size()),
		world.brick_count() - store.scenery.size() == 6)
	var connected: String = "connected (gpt-6.1-sol) on your own model provider, %d tools, " % served.size() \
		+ "all of them this app's"
	_check("it said what it reached: \"%s\"" % (lines[1] if lines.size() > 1 else ""), lines.has(connected))
	var asked: Array = _requests(log)
	var ours: Array = []
	for name: String in served:
		ours.append("brickworks-" + name)
	ours.sort()
	_check("%d requests, each offering the app's %d tools and nothing else" % [asked.size(), served.size()],
		asked.size() >= 7 and asked.all(func(one: Dictionary) -> bool: return one["tool_names"] == ours))
	_check("...and the app's instructions", asked.all(func(one: Dictionary) -> bool:
		return bool(one["system_has_guide"])))
	_check("...and nothing in them the provider would refuse",
		asked.all(func(one: Dictionary) -> bool: return (one["problems"] as Array).is_empty()))
	_check("their mail server was never started", not FileAccess.file_exists(mark))
	var looked: Array = asked.filter(func(one: Dictionary) -> bool: return int(one["replies"]) == 3)
	print("  view_model's pictures after its tool message: %s"
		% (str(looked[0]["pictures_after_tools"]) if not looked.is_empty() else "no such request"))
	_end_live(stub, kept)


func _end_live(stub: int, kept: Dictionary) -> void:
	if stub > 0:
		OS.kill(stub)
	for name: String in kept:
		if kept[name] == null:
			OS.unset_environment(name)
		else:
			OS.set_environment(name, kept[name])
	if _main != null:
		_main.queue_free()
		await process_frame


func _requests(log: String) -> Array:
	var out: Array = []
	for line: String in FileAccess.get_file_as_string(log).split("\n", false):
		var one: Variant = JSON.parse_string(line)
		if one is Dictionary and str((one as Dictionary).get("path", "")).ends_with("/chat/completions"):
			out.append(one)
	return out


## The window as it stood when the session ended, for a person to look at.
func _shot(_chat: Control) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("user://copilot_panel.png")
	image.save_png(path)
	print("  the window: %s" % path)
