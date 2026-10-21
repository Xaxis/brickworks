## A design session's calls made again on the real scene, in order, each
## answer printed with how long it took: through the desktop's MCP port
## (CommandSocket.answer_rpc, tools/call), as the session made them.
##
##   godot --headless --path . --script src/dev/replay_session.gd -- --calls=FILE [--only=0,63,65,81,86]
##
## FILE is one JSON line a call, {n, name, input}: from the session's
## transcript (~/.claude/projects/<its folder>/<session>.jsonl), each
## tool_use's name without its mcp__brickworks__ prefix and its input,
## numbered in order. The app opens on its example, as a bench run's does;
## a run's design begins on a bare baseplate, so put clear_model first, as
## n 0. A call that never answers is the last one printed: give the run a
## timeout. The Ducati's move_part that hung 600 s (technic lever,
## 2026-10-20) was found this way. A tool for seeing a session again, not a
## check: it passes or fails nothing.
extends SceneTree

var _main: Node
var _socket: CommandSocket
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var calls_path: String = ""
	var only: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--calls="):
			calls_path = argument.trim_prefix("--calls=")
		elif argument.begins_with("--only="):
			for n: String in argument.trim_prefix("--only=").split(","):
				only[int(n)] = true
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	for line: String in FileAccess.get_file_as_string(calls_path).split("\n"):
		var call: Variant = JSON.parse_string(line) if not line.is_empty() else null
		if not call is Dictionary:
			continue
		var n: int = int(call.get("n", 0))
		if not only.is_empty() and not only.has(n):
			continue
		var name: String = str(call["name"])
		print("call %d %s %s" % [n, name, JSON.stringify(call.get("input", {})).left(160)])
		var began: int = Time.get_ticks_msec()
		var said: String = await _say(name, call.get("input", {}))
		print("  %d ms: %s" % [Time.get_ticks_msec() - began, said.replace("\n", "\n    ")])
	_main.queue_free()
	await process_frame
	quit(0)


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text
