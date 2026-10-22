## A design session's calls made again on the real scene, in order, each
## answer printed with how long it took: through the desktop's MCP port
## (CommandSocket.answer_rpc, tools/call), as the session made them.
##
##   godot --headless --path . --script src/dev/replay_session.gd -- --calls=FILE [--only=0,63,65,81,86] [--idle=MS]
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
##
## Each call is printed with its longest frame: the longest the main thread
## went without a frame while it ran, which is how long the window drew
## nothing. A call that answers as a job is followed as a session follows
## it, job {"id": N} until it is done, its frames counted with the call's.
## The calls whose longest frame passed 100 ms are listed again at the end.
## --idle=MS waits that long between calls, as a session thinks between
## them, with its own longest frame: without it the app's work after a
## change (its weigh, its joints read ahead) falls in the next call's frames.
extends SceneTree

const HELD_MS := 100

var _main: Node
var _socket: CommandSocket
var _next: int = 0
var _last_frame_us: int = 0
var _longest_us: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var calls_path: String = ""
	var only: Dictionary = {}
	var idle_ms: int = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--calls="):
			calls_path = argument.trim_prefix("--calls=")
		elif argument.begins_with("--only="):
			for n: String in argument.trim_prefix("--only=").split(","):
				only[int(n)] = true
		elif argument.begins_with("--idle="):
			idle_ms = argument.trim_prefix("--idle=").to_int()
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
	process_frame.connect(_frame)
	var held := PackedStringArray()
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
		_longest_us = 0
		_last_frame_us = Time.get_ticks_usec()
		var said: String = await _say(name, call.get("input", {}))
		while said.begins_with("Started job "):
			print("  %d ms, longest frame %d ms: %s" % [Time.get_ticks_msec() - began,
				_longest_ms(), said.replace("\n", "\n    ")])
			said = await _say(ToolJobs.TOOL, {"id": said.get_slice(" ", 2).to_int()})
			while said.contains(") is still going, "):
				said = await _say(ToolJobs.TOOL, {"id": said.get_slice(" ", 1).to_int()})
		var longest: int = _longest_ms()
		print("  %d ms, longest frame %d ms: %s" % [Time.get_ticks_msec() - began, longest,
			said.replace("\n", "\n    ")])
		if longest > HELD_MS:
			held.append("call %d %s: %d ms, longest frame %d ms" % [n, name,
				Time.get_ticks_msec() - began, longest])
		if idle_ms > 0:
			_longest_us = 0
			_last_frame_us = Time.get_ticks_usec()
			var idle_until: int = Time.get_ticks_msec() + idle_ms
			while Time.get_ticks_msec() < idle_until:
				await process_frame
			print("  then %d ms idle, longest frame %d ms" % [idle_ms, _longest_ms()])
	print("calls with a frame over %d ms: %d" % [HELD_MS, held.size()])
	for one: String in held:
		print("  " + one)
	_main.queue_free()
	await process_frame
	quit(0)


func _frame() -> void:
	var now: int = Time.get_ticks_usec()
	_longest_us = maxi(_longest_us, now - _last_frame_us)
	_last_frame_us = now


## The longest frame of the call so far, the stretch since the last frame
## taken in.
func _longest_ms() -> int:
	return roundi(maxi(_longest_us, Time.get_ticks_usec() - _last_frame_us) / 1000.0)


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text
