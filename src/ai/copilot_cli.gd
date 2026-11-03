## Designing on a GitHub Copilot plan, as ClaudeCode designs on a Claude one.
##
## The GitHub Copilot CLI on this machine, signed in by the person to their
## own plan (every plan has it, Free included), started headless and pointed
## back at the app over MCP. GitHub means this to be done: its SDK runs this
## same program "in your application", with Copilot usage "billed to each
## user's subscription", and the program's licence lets an application ship
## it. The app never sees the sign-in: it starts what the person installed and
## signed in to themselves. docs/ANY_ASSISTANT.md G has the terms quoted.
##
##   copilot -p "<brief>" --additional-mcp-config @<a file naming our port> ...
##
## Copilot has neither --strict-mcp-config nor --tools "". What takes away
## here is --available-tools, which hides from the model every tool it does
## not name: the shell, the file tools, the web fetch, and the tools of every
## server the person uses. Their servers are not even started
## (--disable-mcp-server, each by name), nor GitHub's (--disable-builtin-mcps).
## src/dev/copilot_cli_probe.gd reads the command, and runs it against a
## stand-in model that writes down what it was offered.
class_name CopilotCli
extends ClaudeCode

## What makes Copilot run as somebody other than the person signed in: it
## takes these before its own stored sign-in, and a shell's are usually for
## something else (gh, CI), or another account's (this repo's .env has one).
## COPILOT_GITHUB_TOKEN is Copilot's own and is left alone. Taken off by
## env(1) rather than out of the app's environment, as ClaudeCode does: the
## session starts on the reader's thread, and the environment is not a thing
## to change under the main thread's feet.
const HIDDEN: Array[String] = ["GH_TOKEN", "GITHUB_TOKEN"]


## Start [param copilot] with [param args] and without the tokens in HIDDEN.
static func launch(copilot: String, args: PackedStringArray) -> Dictionary:
	var with := PackedStringArray()
	for name: String in HIDDEN:
		with.append_array(["-u", name])
	with.append(copilot)
	with.append_array(args)
	return OS.execute_with_pipe("/usr/bin/env", with)

## Lines the session wrote that were not its JSON: why it would not start.
var _errors: String = ""
## Said by the last error event, or the stand-in for a result's words.
var _last_words: String = ""
## Stop pressed while the session was still being started.
var _stopping: bool = false


## Exactly how the session is started, so what it can reach can be checked
## without starting one. [param tools] are the app's own tool names,
## [param theirs] the person's own servers to leave off, [param listed]
## whether those could be read at all.
static func command(brief: String, config: String, tools: PackedStringArray,
		theirs: PackedStringArray, listed: bool, work: String) -> PackedStringArray:
	var args := PackedStringArray(["-p", brief,
		"--additional-mcp-config", "@" + config,
		# The only tools the model is shown. Not an allowlist that grants: a
		# filter, and everything it does not name is gone, built-in or not.
		# Unfiltered, a stand-in model was offered 24 tools, bash and
		# web_fetch among them and the person's own mail server's two.
		"--available-tools"])
	for tool: String in tools:
		args.append("%s-%s" % [SERVER, tool])
	args.append_array([
		# Ours run without asking, so a headless run does not stall...
		"--allow-tool", SERVER,
		# ...and a shell or a file writer is refused, should one ever be shown.
		"--deny-tool", "shell", "--deny-tool", "write",
		# GitHub's own servers, which would also be handed the sign-in.
		"--disable-builtin-mcps",
		# Not the person's AGENTS.md, and no question it cannot be asked.
		"--no-custom-instructions", "--no-ask-user", "--disallow-temp-dir",
		# A folder of the app's own, so no project's .mcp.json or skills come in.
		"-C", work,
		"--output-format", "json",
	])
	for name: String in theirs:
		args.append_array(["--disable-mcp-server", name])
	# Copilot shows the model only some servers' instructions, and ours are
	# how a session learns the design method. With the person's servers all
	# left off, "all" is ours alone; when they could not be read it is not.
	if listed:
		args.append("--allow-all-mcp-server-instructions")
	return args


## Where the program is, or "" if this machine has not got it. "copilot" is
## also AWS Copilot's name, so it must say it is GitHub's.
static func found() -> String:
	if OS.has_feature("web"):
		return ""
	var home: String = OS.get_environment("HOME")
	var out: Array = []
	var candidates: Array[String] = []
	if OS.execute("which", ["copilot"], out, false) == 0:
		var path: String = ("\n".join(out) if out is Array else "").strip_edges()
		if not path.is_empty():
			candidates.append(path.split("\n")[0].strip_edges())
	# Where its installers put it, for an app started with no shell PATH: the
	# install script's ~/.local/bin, Homebrew's, and npm's own prefix.
	for candidate: String in [home.path_join(".local/bin/copilot"),
			"/opt/homebrew/bin/copilot", "/usr/local/bin/copilot",
			home.path_join(".npm-global/bin/copilot")]:
		if candidate.is_absolute_path() and FileAccess.file_exists(candidate):
			candidates.append(candidate)
	for candidate: String in candidates:
		var version: Array = []
		if OS.execute(candidate, ["--version"], version, false) == 0 \
				and "\n".join(version).contains("GitHub Copilot CLI"):
			return candidate
	return ""


## The person's own MCP servers, by name, as Copilot itself lists them (its
## user file, its plugins'), with whether they could be read.
static func their_servers(copilot: String) -> Array:
	var out: Array = []
	if OS.execute(copilot, ["mcp", "list", "--json"], out, false) != 0:
		return [PackedStringArray(), false]
	var parsed: Variant = JSON.parse_string("\n".join(out))
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("mcpServers") is Dictionary):
		return [PackedStringArray(), false]
	var names := PackedStringArray()
	for name: Variant in (parsed as Dictionary)["mcpServers"]:
		if str(name) != SERVER:
			names.append(str(name))
	return [names, true]


## Start one, as ClaudeCode.design does, except that listing the person's
## servers takes the program most of a second, which the window must not
## wait on: it is done on the reader's thread, before the session starts.
func design(brief: String, port: int, tools: PackedStringArray) -> void:
	if _running:
		return
	var copilot: String = found()
	if copilot.is_empty():
		finished.emit(false, "GitHub Copilot CLI is not installed on this machine.")
		return
	var config: String = _write_config(port)
	var work: String = ProjectSettings.globalize_path("user://copilot-work")
	DirAccess.make_dir_recursive_absolute(work)
	if config.is_empty():
		finished.emit(false, "Could not write the connection file.")
		return
	_running = true
	_turns = 0
	_tools_used = 0
	_usage = {}
	_whole = {}
	_errors = ""
	_last_words = ""
	_stopping = false
	_outside = []
	_ours = 0
	_said_connected = false
	progress.emit("Copilot is reading the brief")
	_thread = Thread.new()
	_thread.start(_start.bind(copilot, brief, config, tools, work))


## On the reader's thread: the person's servers, the session, its lines,
## and then whatever it said that was not JSON.
func _start(copilot: String, brief: String, config: String,
		tools: PackedStringArray, work: String) -> void:
	var theirs: Array = their_servers(copilot)
	var started: Dictionary = launch(copilot,
		command(brief, config, tools, theirs[0], theirs[1], work))
	if started.is_empty() or not started.has("stdio"):
		_errors = "Could not start %s." % copilot
		_read_end()
		return
	_lock.lock()
	_pid = int(started.get("pid", -1))
	var stopped: bool = _stopping
	_lock.unlock()
	if stopped:
		OS.kill(int(started["pid"]))
	var errors: FileAccess = started.get("stderr")
	_read_lines(started["stdio"], int(started["pid"]))
	if errors != null:
		var heard: PackedStringArray = []
		while errors.is_open() and not errors.eof_reached() and heard.size() < 20:
			var line: String = errors.get_line().strip_edges()
			if line.is_empty():
				break
			heard.append(line)
		_errors = "\n".join(heard)
	_read_end()


## Every line until the process has gone, as ClaudeCode._read reads them,
## without the end: that is said once what went to stderr has been read.
func _read_lines(pipe: FileAccess, pid: int) -> void:
	while pipe.is_open() and not pipe.eof_reached():
		var line: String = pipe.get_line()
		if line.is_empty():
			if pid > 0 and not OS.is_process_running(pid):
				break
			continue
		_lock.lock()
		_lines.append(line)
		_lock.unlock()


func _read_end() -> void:
	_lock.lock()
	_lines.append("")   # the end, said in band
	_lock.unlock()


func stop() -> void:
	_lock.lock()
	_stopping = true
	var pid: int = _pid
	_pid = -1
	_lock.unlock()
	if pid > 0:
		OS.kill(pid)


func _saw(line: String) -> void:
	var parsed: Variant = JSON.parse_string(line)
	if not (parsed is Dictionary):
		return
	var event: Dictionary = parsed
	var data: Dictionary = event.get("data", {}) if event.get("data") is Dictionary else {}
	match str(event.get("type", "")):
		"session.mcp_servers_loaded":
			# What it can reach, said out loud, as ClaudeCode says it: a
			# session connected to any server but ours is a bug in this file.
			var outside: PackedStringArray = []
			for server: Variant in data.get("servers", []):
				var one: Dictionary = server if server is Dictionary else {}
				if str(one.get("status", "")) == "connected" and str(one.get("name", "")) != SERVER:
					outside.append(str(one.get("name", "")))
			if not outside.is_empty():
				push_warning("copilot: servers outside Brickworks connected: %s" % ", ".join(outside))
			_outside = outside
		"session.mcp_server_tools_loaded":
			if str(data.get("serverName", "")) == SERVER:
				_ours = int(data.get("toolCount", 0))
		"session.tools_updated":
			if _said_connected:
				return
			_said_connected = true
			# Which plan, by what Copilot was started with: a model provider of
			# the person's own (BYOK) in place of Copilot's when one is set.
			var whose: String = ("your own model provider" if OS.has_environment("COPILOT_PROVIDER_BASE_URL")
				else "your Copilot plan")
			progress.emit("connected (%s) on %s, %d tools, " % [str(data.get("model", "copilot")),
					whose, _ours]
				+ ("all of them this app's" if _outside.is_empty()
				else "and %s outside this app" % ", ".join(_outside)))
		"assistant.message":
			_turns += 1
			var text: String = str(data.get("content", "")).strip_edges()
			if not text.is_empty():
				_last_words = text
				said.emit(text)
			for asked: Variant in data.get("toolRequests", []):
				var one: Dictionary = asked if asked is Dictionary else {}
				_tools_used += 1
				var input: Variant = one.get("arguments", {})
				progress.emit(_in_words(str(one.get("name", "")),
					input if input is Dictionary else {}))
		"session.error":
			_last_words = str(data.get("message", "")).strip_edges()
		"result":
			var ok: bool = event.has("exitCode") and int(event["exitCode"]) == 0
			_running = false
			finished.emit(ok, _last_words if not _last_words.is_empty()
				else "finished" if ok else "stopped")


var _outside: PackedStringArray = []
var _ours: int = 0
var _said_connected: bool = false


## How many replies the session has made: Copilot's lines carry no tokens.
func replies() -> int:
	return _turns


func _prefix() -> String:
	return "%s-" % SERVER


## Why it ended with no result: not signed in, mostly, which is the person's
## to do in Copilot's own sign-in, never here.
func _stopped() -> String:
	if _errors.contains("No authentication information"):
		return ("Copilot is not signed in on this machine. Run `copilot login` "
			+ "in a terminal, then build it again.")
	if not _last_words.is_empty():
		return _last_words
	if not _errors.is_empty():
		return "Copilot stopped: %s" % _errors.split("\n")[0]
	return "Copilot stopped after %d turn%s." % [_turns, "" if _turns == 1 else "s"]


## The connection file, in Copilot's own words for it: "tools" says which of
## the server's tools it may load, and a server without it loads none.
func _write_config(port: int) -> String:
	var path: String = "user://copilot-mcp-%d.json" % port
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(config_for_copilot(port)))
	file.close()
	return ProjectSettings.globalize_path(path)


static func config_for_copilot(port: int) -> Dictionary:
	return {"mcpServers": {SERVER: {
		"type": "http",
		"url": "http://127.0.0.1:%d/mcp" % port,
		"tools": ["*"],
		"timeout": TOOL_TIMEOUT_MS,
	}}}
