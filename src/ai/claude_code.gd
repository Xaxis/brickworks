## Designing on the subscription you already pay for.
##
## The app's own loop talks to Anthropic and needs an API key or an
## account to do it. This does the opposite: it starts Claude Code on
## this machine — which is signed in to the person's Claude subscription
## — and points it back at the app over MCP. The model proposes, the app
## disposes, exactly as the inside loop does, and nothing is billed here
## because nothing here is calling the API.
##
##   claude -p "<brief>" --mcp-config <a file naming our port>
##
## Desktop only: a browser cannot start a process. The web build goes on
## using an account, which is what accounts are for.
##
## Deliberately not: a proxy that borrows subscription credentials and
## serves them as an API endpoint. Those exist, they violate the terms
## the subscription is granted under, and pointing a shipped app at one
## would put the person's account at risk. This runs the program they
## installed, as them, on their machine.
class_name ClaudeCode
extends Node

## Said as it works, for the chat panel.
signal progress(note: String)
## What the session wrote back in words.
signal said(text: String)
## ok, and a sentence about how it went.
signal finished(ok: bool, summary: String)

## What a session is allowed to touch. Only the app's own tools: with
## nothing else permitted, a headless run cannot read or write a file,
## and a design run has no reason to.
const SERVER := "brickworks"

var _thread: Thread = null
var _lock := Mutex.new()
var _lines: Array[String] = []
var _running: bool = false
var _pid: int = -1
var _turns: int = 0
var _tools_used: int = 0


## Exactly how the session is started, so what it is allowed to touch
## can be checked without starting one.
##
## The first run of this feature inherited every tool the person's own
## Claude Code has: a shell, a file writer, and whatever MCP servers
## they happen to use — on the machine this was written on, their email
## and their documents. --allowedTools only grants; it does not take
## away. These three flags are what take away.
static func arguments(brief: String, config: String,
		allowed: PackedStringArray) -> PackedStringArray:
	return PackedStringArray([
			"-p", brief,
			"--mcp-config", config,
			# Only the server named in that file. Without this the session
			# inherits every MCP server the person has configured — on the
			# machine this was written on that was Gmail, Google Drive,
			# Notion and a calendar, all of them handed to a run whose job
			# is to stack bricks.
			"--strict-mcp-config",
			# And none of the built-in ones. "Design me a post box" must not
			# come with a shell, a file writer and a web fetcher attached;
			# the first run of this feature used Bash twice before anybody
			# asked it to. --restricted drops the code-running tools and
			# ignores the person's settings files as well.
			"--tools", "",
			"--restricted",
			# What is left is ours, allowed so that a headless run does not
			# stall waiting for a permission it has no way to ask for.
			"--allowedTools", ",".join(allowed),
			"--output-format", "stream-json",
			# Without this, stream-json prints the result and nothing else,
			# so there is no sign of life for however many minutes it takes.
			"--verbose",
		])


## Where the command is, or "" if this machine has not got it.
static func found() -> String:
	# A browser cannot start a program, and asking it to is not a quiet
	# no: the engine prints "OS::execute() must be implemented in Web"
	# into the console of every visitor. The file said "desktop only"
	# from the first line and nothing enforced it, which the deploy's
	# browser check found on the first run after it shipped.
	if OS.has_feature("web"):
		return ""
	# `which` rather than a guess at the path: it is installed by a
	# script that picks its own directory, and ~/.local/bin is only the
	# usual answer.
	var out: Array = []
	if OS.execute("which", ["claude"], out, false) != 0:
		return ""
	var path: String = ("\n".join(out) if out is Array else "").strip_edges()
	return path.split("\n")[0].strip_edges() if not path.is_empty() else ""


## True when a design is running.
func busy() -> bool:
	return _running


## Start one. [param port] is the app's MCP port; [param tools] the names
## it serves, so the session is allowed those and nothing else.
func design(brief: String, port: int, tools: PackedStringArray) -> void:
	if _running:
		return
	var claude: String = found()
	if claude.is_empty():
		finished.emit(false, "Claude Code is not installed on this machine.")
		return

	var config: String = _write_config(port)
	if config.is_empty():
		finished.emit(false, "Could not write the connection file.")
		return

	var allowed := PackedStringArray()
	for tool: String in tools:
		allowed.append("mcp__%s__%s" % [SERVER, tool])

	var args: PackedStringArray = arguments(brief, config, allowed)
	var started: Dictionary = OS.execute_with_pipe(claude, args)
	if started.is_empty() or not started.has("stdio"):
		finished.emit(false, "Could not start %s." % claude)
		return
	_running = true
	_turns = 0
	_tools_used = 0
	_pid = int(started.get("pid", -1))
	progress.emit("Claude Code is reading the brief")
	# On its own thread, because a pipe with nothing in it blocks until
	# there is, and the window has to keep drawing while a design that
	# takes minutes is running.
	_thread = Thread.new()
	_thread.start(_read.bind(started["stdio"]))


## Stop the run, if one is going.
func stop() -> void:
	if _pid > 0:
		OS.kill(_pid)
		_pid = -1


## Nothing left running when the app closes. The reader sits on a pipe
## that only ends when the process does, so the process goes first.
func _exit_tree() -> void:
	stop()
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null


func _read(pipe: FileAccess) -> void:
	while pipe.is_open() and not pipe.eof_reached():
		var line: String = pipe.get_line()
		if line.is_empty():
			continue
		_lock.lock()
		_lines.append(line)
		_lock.unlock()
	_lock.lock()
	_lines.append("")   # the end, said in band
	_lock.unlock()


func _process(_delta: float) -> void:
	if not _running:
		return
	_lock.lock()
	var ready: Array[String] = _lines.duplicate()
	_lines.clear()
	_lock.unlock()
	for line: String in ready:
		if line.is_empty():
			_ended()
			return
		_saw(line)


func _saw(line: String) -> void:
	var parsed: Variant = JSON.parse_string(line)
	if not (parsed is Dictionary):
		return
	var event: Dictionary = parsed
	match str(event.get("type", "")):
		"system":
			if str(event.get("subtype", "")) == "init":
				# Which credentials it is using, said out loud: the whole
				# point of this path is that it is not an API key. And
				# what it can reach, because a session that can do more
				# than place bricks is a bug in this file.
				var source: String = str(event.get("apiKeySource", ""))
				var offered: Array = event.get("tools", [])
				var outside: int = 0
				for name: Variant in offered:
					if not str(name).begins_with("mcp__%s__" % SERVER):
						outside += 1
				if outside > 0:
					push_warning("claude code: %d tools outside Brickworks "
						% outside + "were offered to the session")
				progress.emit("connected (%s) on your %s, %d tools, "
					% [str(event.get("model", "claude")),
						"subscription" if source in ["none", ""] else source,
						offered.size()]
					+ "all of them this app's" if outside == 0
					else "%d of them outside this app" % outside)
		"assistant":
			var message: Dictionary = event.get("message", {}) as Dictionary
			for block: Variant in message.get("content", []):
				var one: Dictionary = block
				match str(one.get("type", "")):
					"text":
						var text: String = str(one.get("text", "")).strip_edges()
						if not text.is_empty():
							said.emit(text)
					"tool_use":
						_tools_used += 1
						progress.emit(_in_words(str(one.get("name", ""))))
			_turns += 1
		"result":
			var ok: bool = not bool(event.get("is_error", false))
			var summary: String = str(event.get("result", "")).strip_edges()
			if summary.is_empty():
				summary = "finished" if ok else "stopped"
			_running = false
			finished.emit(ok, summary)


## A tool name as a person would say it.
func _in_words(name: String) -> String:
	var plain: String = name.trim_prefix("mcp__%s__" % SERVER)
	return {
		"search_parts": "looking for a part",
		"check_design": "checking what it has",
		"attachment_points": "working out where things attach",
		"look_at_model": "reading the baseplate",
		"view_model": "looking at the model",
		"submit_design": "building it",
		"edit_model": "changing it",
		"clear_model": "clearing the baseplate",
		"save_model": "saving",
	}.get(plain, plain.replace("_", " "))


func _ended() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	_pid = -1
	if _running:
		# The pipe closed without a result line, which is what a crash
		# or a kill looks like from here.
		_running = false
		finished.emit(false, "Claude Code stopped after %d turn%s."
			% [_turns, "" if _turns == 1 else "s"])


## The file that tells Claude Code where the app is listening.
func _write_config(port: int) -> String:
	var path: String = "user://claude-code-mcp.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify({"mcpServers": {SERVER: {
		"type": "http",
		"url": "http://127.0.0.1:%d/mcp" % port,
	}}}))
	file.close()
	return ProjectSettings.globalize_path(path)
