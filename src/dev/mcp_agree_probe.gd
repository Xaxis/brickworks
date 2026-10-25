## A session's answers agree with each other, with what the person sees, and
## with the brief.
##
##   godot --headless --path . --script src/dev/mcp_agree_probe.gd
##
## walk256 (bench/results/walk256-2026-10-25, findings M18): review_model said
## "64 problems (overlap 64)" of a model check_design called buildable, the
## person's own parts each running into itself; "It still stands" stood
## beside the status bar's "2 weak joints (tips)", a mooring rope hanging
## through the baseplate taken for what the model stands on; a brief of about
## 250 parts came out at 464; and the edit asked for a part's number it had
## just put down. Here, over the MCP port on the app's own scene: the house
## (the person's parts) reviewed whole says what check_design says; a string
## laid slack between two stacks on the baseplate leaves the status bar,
## check_design and an edit's answer all saying it stands; an edit names the
## parts it put down; and a design given the brief's count is told where it
## stands against it, and the surface pass keeps inside it. Exits non-zero
## when an answer disagrees.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _store: ModelStore
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 60:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_store = _main.get("_store")
	_store.keeps = false
	_world = _main.get("_world")
	await _review_agrees()
	await _stands_agrees()
	await _edit_names_its_parts()
	await _budget_held()
	print("")
	print("agree: review and check, the status bar and the answers, and the brief's count "
		+ "say the same" if _failures == 0 else "agree: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _review_agrees() -> void:
	print("── review_model and check_design, on the person's own model ──")
	var parts: int = _store.open("res://models/house.ldr")
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	await process_frame
	_check("the house opened: %d parts" % parts, parts > 20)
	var checked: String = _line_with(_text(await _call("check_design", {"edit": {}})), "bricks, buildable")
	var reviewed: String = _text(await _call("review_model", {})).get_slice("\n", 0)
	_check("check_design: %s" % checked, not checked.is_empty())
	_check("review_model says the same: %s" % reviewed.left(120),
		reviewed.contains("%d bricks, buildable" % parts) and not reviewed.contains("problem"))


func _stands_agrees() -> void:
	print("── a slack string through the baseplate: the status bar and the answers ──")
	await _call("clear_model", {})
	_check("the baseplate is the floor: %d part%s" % [_store.scenery.size(),
		"" if _store.scenery.size() == 1 else "s"], not _store.scenery.is_empty())
	await _call("edit_model", {"add": [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0},
		{"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0},
		{"part": "3062b", "color": 0, "x": 0, "y": 6, "z": 0},
		{"part": "3062b", "color": 0, "x": 7, "y": 0, "z": 0}], "picture": false})
	var posts: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3062b":
			posts.append(brick.id)
	var laid: String = _text(await _call("lay_flex", {"kind": "string",
		"from": {"brick": posts[0]}, "to": {"brick": posts[1]}, "color": 19}))
	var lowest: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			lowest = minf(lowest, brick.transform.origin.y)
	_check("the string hangs through the baseplate: %s, lowest at %.1f LDU" % [laid.left(60),
		lowest], laid.begins_with("Laid") and lowest < 0.0)
	var report: Stability.Report = await _main.weigh_joints(true)
	_check("the status bar: %s" % report.summary(), report.is_stable())
	var balance: String = _line_with(_text(await _call("check_design", {"edit": {}})), "Balance:")
	_check("check_design: %s" % balance.left(90), balance.begins_with("Balance: stands"))
	var edited: String = _text(await _call("edit_model", {"recolor": [{"bricks": [posts[1]],
		"color": 4}], "picture": false}))
	_check("an edit's answer: %s" % edited.get_slice("\n", 2),
		edited.get_slice("\n", 2).begins_with("It stands"))


func _edit_names_its_parts() -> void:
	print("── an edit names the parts it put down ──")
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		before[brick.id] = true
	var said: String = _text(await _call("edit_model", {"add": [
		{"part": "3024", "color": 15, "x": 0, "y": 6, "z": 1},
		{"part": "3024", "color": 15, "x": 1, "y": 6, "z": 1}], "picture": false}))
	var fresh: PackedStringArray = PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id):
			fresh.append("#%d" % brick.id)
	_check("it says them: %s / %s" % [said.get_slice("\n", 1), ", ".join(fresh)],
		fresh.size() == 2 and said.get_slice("\n", 1).contains("(%s)" % ", ".join(fresh)))


func _budget_held() -> void:
	print("── the brief's count: said against, and kept inside ──")
	await _call("clear_model", {})
	var bricks: Array = []
	for x: int in [0, 4, 8]:
		for z: int in [0, 2, 4, 6]:
			for y: int in [0, 3]:
				bricks.append({"part": "3001", "color": 4, "x": x, "y": y, "z": z})
	var built: String = _text(await _call("submit_design", {"name": "Block", "description":
		"a block", "parts": 20, "bricks": bricks}))
	_check("a design over the count is told so: %s" % _line_with(built, "asked").left(120),
		built.begins_with("Built.") and built.contains("24 parts, past the about 20 asked"))
	var surface: String = _text(await _call("review_model", {"surface": true}))
	var count: int = _world.brick_count() - _store.scenery.size()
	_check("the surface pass lays nothing past it: %d parts; %s" % [count,
		_line_with(surface, "the brief").left(120)],
		count <= 24 and _line_with(surface, "the brief").contains("about 20"))


func _call(tool: String, arguments: Dictionary) -> Array:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	return ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []) as Array


static func _text(blocks: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "text":
			out.append(str(block.get("text", "")))
	return "\n".join(out)


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
