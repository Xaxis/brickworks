## Is the MCP in step with the app?
##
##   godot --headless --path . --script src/dev/mcp_sync_probe.gd
##   godot --headless --path . --script src/dev/mcp_sync_probe.gd -- --write
##
## MCP is this app's AI interface, and it falls behind quietly: a command
## added to the menus, a tool given a new argument, a tool nobody's
## guidance mentions. Nothing fails when it does — a session just cannot do
## what the person can, or never hears that it could. So three things, each
## of which drifted before this existed:
##
##   tools/mcp_tools.json is what the app serves. The relay answers
##     tools/list from it while the app is closed; it was two tools and an
##     argument behind. --write writes it again from the app.
##   The instructions' head fits in what Claude Code reads (about 3,800
##     characters), and every tool is named in the head or in a section
##     read_guide serves, so a session can find out it exists.
##   Every one of the window's commands (Shell) is either done by a tool
##     (AppTools.COMMANDS) or is the window's alone, with why
##     (AppTools.WINDOW_ONLY).
extends SceneTree

const CACHED := "res://tools/mcp_tools.json"
## Claude Code shows about 3,800 characters of a server's instructions.
const HEAD_MOST := 3500

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var write: bool = "--write" in OS.get_cmdline_user_args()
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 60:
		await process_frame
	var assistant: Assistant = main.get("_assistant")
	var socket := CommandSocket.new()
	socket.assistant = assistant
	socket.app = main
	main.add_child(socket)
	await process_frame

	# What __tools__ answers, which is what the relay writes to the file.
	var served: Array = assistant.tool_catalogue() + socket._own_tools()
	var names: Array[String] = []
	for tool: Dictionary in served:
		names.append(str(tool["name"]))
	_check("the app serves %d tools" % served.size(), served.size() >= 30)

	# 1. The cached list is the served one.
	var path: String = ProjectSettings.globalize_path(CACHED)
	if write:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(served, "  ") + "\n")
		file.close()
		print("  wrote %s" % path)
	var cached: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var stale := PackedStringArray()
	var by_name: Dictionary = {}
	for tool: Variant in (cached if cached is Array else []):
		by_name[str((tool as Dictionary).get("name", ""))] = tool
	for tool: Dictionary in served:
		var name: String = str(tool["name"])
		if not by_name.has(name):
			stale.append("%s is missing" % name)
		elif _canonical(by_name[name]) != _canonical(tool):
			stale.append("%s has changed" % name)
	for name: String in by_name.keys():
		if not names.has(name):
			stale.append("%s is no longer served" % name)
	_check("tools/mcp_tools.json is what the app serves%s" % (
		"" if stale.is_empty() else ": " + ", ".join(stale)
			+ " — write it again with: godot --headless --path . --script "
			+ "src/dev/mcp_sync_probe.gd -- --write"), stale.is_empty())
	if not stale.is_empty() and not write:
		print("        (the relay writes it too, whenever a session lists the tools of a running app)")

	# 2. The head fits, and every tool can be found.
	var head: String = Assistant.GUIDE_HEAD
	var guidance: String = assistant.guidance()
	_check("the instructions' head is %d characters, under %d" % [head.length(), HEAD_MOST],
		head.length() < HEAD_MOST and guidance.begins_with(head))
	# And as the connector serves it, with its own note first (the tabs, and
	# where the tab is): 3,537 characters before that note was cut down.
	var served_head: int = ClaudeConnector.CONNECTED_NOTE.length() + head.length()
	_check("...and %d with the connector's note before it, under %d" % [served_head, HEAD_MOST],
		served_head < HEAD_MOST)
	var served_sections := ""
	var headings: Array[String] = []
	var heading := RegEx.create_from_string("(?m)^[A-Z][A-Z ,'-]{4,}$")
	for found: RegExMatch in heading.search_all(assistant._guide_text()):
		headings.append(found.get_string())
	for name: String in headings:
		served_sections += assistant.read_guide(name) + "\n"
	_check("read_guide serves %d sections, the app's own among them" % headings.size(),
		assistant.read_guide("app").begins_with("THE REST OF THE APP"))
	var unmentioned := PackedStringArray()
	var word := RegEx.new()
	for name: String in names:
		word.compile("(?<![A-Za-z_])%s(?![A-Za-z_])" % name)
		if word.search(head) == null and word.search(served_sections) == null:
			unmentioned.append(name)
	_check("every tool is named in the head or a read_guide section%s" % (
		"" if unmentioned.is_empty() else ": not " + ", ".join(unmentioned)),
		unmentioned.is_empty())

	# 3. Every command of the window is a tool's, or the window's alone.
	var shell: Shell = main.get("_shell")
	var commands: Array = shell._commands.keys()
	var unplaced := PackedStringArray()
	var no_tool := PackedStringArray()
	var by_tool: int = 0
	for id: String in commands:
		var tool: String = _entry(AppTools.COMMANDS, id)
		if not tool.is_empty():
			by_tool += 1
			if not names.has(tool):
				no_tool.append("%s -> %s" % [id, tool])
		elif _entry(AppTools.WINDOW_ONLY, id).is_empty():
			unplaced.append(id)
	_check("%d of the window's %d commands are done by a tool, the rest the window's own"
		% [by_tool, commands.size()] + ("" if unplaced.is_empty()
			else ": %s in neither AppTools.COMMANDS nor WINDOW_ONLY" % ", ".join(unplaced)),
		unplaced.is_empty() and commands.size() > 100)
	_check("...and each of those tools is served%s" % (
		"" if no_tool.is_empty() else ": not " + ", ".join(no_tool)), no_tool.is_empty())
	var dead := PackedStringArray()
	for table: Dictionary in [AppTools.COMMANDS, AppTools.WINDOW_ONLY]:
		for key: String in table.keys():
			var matched: bool = false
			for id: String in commands:
				matched = matched or _matches(key, id)
			if not matched:
				dead.append(key)
	_check("...and neither names a command that is gone%s" % (
		"" if dead.is_empty() else ": " + ", ".join(dead)), dead.is_empty())

	_done()


## What [param table] says for a command: its own entry, else the longest
## prefix ending in "*" that takes it.
static func _entry(table: Dictionary, id: String) -> String:
	if table.has(id):
		return str(table[id])
	var best: String = ""
	var said: String = ""
	for key: String in table.keys():
		if _matches(key, id) and key.length() > best.length():
			best = key
			said = str(table[key])
	return said


static func _matches(key: String, id: String) -> bool:
	return key == id or (key.ends_with("*") and id.begins_with(key.trim_suffix("*")))


## The same JSON whatever its key order or number spelling.
static func _canonical(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("the MCP is in step with the app")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
