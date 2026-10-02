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
## done by hand.
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
