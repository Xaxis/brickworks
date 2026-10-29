## Can a design run reach anything but the bricks?
##
##   godot --headless --path . --script src/dev/claude_code_probe.gd
##
## The feature starts the Claude Code on this machine and points it back
## at the app, so a person designs on the subscription they already pay
## for rather than on an API key. What makes that safe is not the
## allowlist — --allowedTools only grants permission, it never takes any
## away. The first run inherited everything the person's own Claude Code
## has: a shell, a file writer, and whatever MCP servers they use, which
## on the machine this was written on was their email and their
## documents. It called Bash twice before anybody asked it to.
##
## So this checks the three flags that take away, by reading the command
## rather than running it. Running it spends somebody's subscription;
## the end-to-end run is src/dev/assistant_probe.gd's neighbour and is
## done by hand. And that an app started from a desktop icon, with no shell
## PATH, still finds it where its installer puts it (ClaudeCode.found).
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var allowed := PackedStringArray([
		"mcp__brickworks__search_parts", "mcp__brickworks__submit_design"])
	var args: PackedStringArray = ClaudeCode.arguments(
		"a lighthouse", "/tmp/mcp.json", allowed)
	var line: String = " ".join(args)

	print("  what the session is allowed")
	# Only the app's own MCP server, so no Gmail, no Drive, no Notion.
	_check("only the MCP server we name", args.has("--strict-mcp-config"))
	var server: Dictionary = (ClaudeCode.config_for(8787)["mcpServers"] as Dictionary).values()[0]
	_check("a big submit has time to be checked and built: %d ms per call"
		% int(server.get("timeout", 0)), int(server.get("timeout", 0)) >= 300000)
	# No shell, no file writer, no web fetch.
	_check("no built-in tools at all",
		args.has("--tools") and args[args.find("--tools") + 1].is_empty())
	# And the person's own settings files are ignored, which is where a
	# blanket permission would otherwise come from.
	_check("the person's settings are not loaded", args.has("--restricted"))
	_check("ours are allowed, so a headless run does not stall",
		line.contains("mcp__brickworks__search_parts"))
	_check("the brief is passed as a prompt, not interpreted",
		args.has("-p") and args[args.find("-p") + 1] == "a lighthouse")
	_check("progress can be read as it goes",
		line.contains("stream-json") and args.has("--verbose"))
	# Nothing here may ever turn permissions off wholesale.
	_check("permissions are never skipped",
		not line.contains("dangerously") and not line.contains("bypass"))

	print("")
	print("  and whether this machine can run it at all")
	var where: String = ClaudeCode.found()
	if where.is_empty():
		print("  ----  claude is not on PATH, so the app will offer the "
			+ "other two ways to design")
	else:
		print("  ok    claude is at %s" % where)

	print("")
	print("  and a session that has ended lets the app go")
	# The reader thread spun at 100% once the session's process had
	# exited — get_line() on a dead pipe comes back empty and never says
	# end of file — and closing the app waited on it for ever. Two lines
	# from a process that exits at once must arrive, and the reader stop.
	var piped: Dictionary = OS.execute_with_pipe("sh", ["-c", "echo one; echo two"])
	var session := ClaudeCode.new()
	var reader := Thread.new()
	reader.start(session._read.bind(piped["stdio"], int(piped["pid"])))
	var until: int = Time.get_ticks_msec() + 5000
	while reader.is_alive() and Time.get_ticks_msec() < until:
		OS.delay_msec(50)
	var ended: bool = not reader.is_alive()
	_check("the reader stops once the process has gone, in %d ms"
		% (5000 - maxi(until - Time.get_ticks_msec(), 0)), ended)
	if ended:
		reader.wait_to_finish()
		_check("...having read what it said: %s" % str(session._lines),
			session._lines.has("one") and session._lines.has("two"))
	session.free()

	print("")
	print("  and it bills the subscription, not an API key")
	# A session started from an app that has a key in its environment saw
	# the key and billed it. The child must not see one; the app must
	# still have it afterwards, for designing on a key.
	var before: Dictionary = {}
	for name: String in ClaudeCode.BILLING:
		before[name] = OS.get_environment(name) if OS.has_environment(name) else null
		OS.set_environment(name, "sk-ant-probe-not-a-key")
	var child: Dictionary = ClaudeCode.start_on_subscription("sh", ["-c",
		"echo key=${ANTHROPIC_API_KEY:-none} token=${ANTHROPIC_AUTH_TOKEN:-none}"])
	var said: String = ""
	var pipe: FileAccess = child.get("stdio")
	var wait_until: int = Time.get_ticks_msec() + 5000
	while said.is_empty() and Time.get_ticks_msec() < wait_until:
		said = pipe.get_line().strip_edges()
		if said.is_empty():
			OS.delay_msec(20)
	_check("the session sees no key and no token: %s" % said,
		said == "key=none token=none")
	_check("...and the app keeps its own for designing on a key",
		OS.get_environment("ANTHROPIC_API_KEY") == "sk-ant-probe-not-a-key")
	for name: String in before:
		if before[name] == null:
			OS.unset_environment(name)
		else:
			OS.set_environment(name, before[name])

	print("")
	print("  and an app started from a desktop icon still finds it")
	# No shell PATH there (PATH=/usr/bin:/bin), so `which` misses ~/.local/bin,
	# where the installer puts claude: found() looks there too. A stand-in in a
	# home of its own, which is never run.
	var path: String = OS.get_environment("PATH")
	var was_home: String = OS.get_environment("HOME")
	var home: String = ProjectSettings.globalize_path("user://icon-home")
	var stand_in: String = home.path_join(".local/bin/claude")
	DirAccess.make_dir_recursive_absolute(stand_in.get_base_dir())
	var file: FileAccess = FileAccess.open(stand_in, FileAccess.WRITE)
	file.store_string("#!/bin/sh\n")
	file.close()
	OS.execute("chmod", ["+x", stand_in])
	OS.set_environment("PATH", "/usr/bin:/bin")
	OS.set_environment("HOME", home)
	_check("`which` finds no claude on PATH=/usr/bin:/bin",
		OS.execute("which", ["claude"], [], false) != 0)
	_check("...and ClaudeCode.found() finds it in the home: %s" % ClaudeCode.found(),
		ClaudeCode.found() == stand_in)
	OS.set_environment("PATH", path)
	OS.set_environment("HOME", was_home)

	print("")
	if _failures == 0:
		print("a design run can reach the bricks and nothing else")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)
