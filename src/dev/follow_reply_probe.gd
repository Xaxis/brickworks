## A session's edit to one copy of a sub-assembly is answered of the model
## as it stands once every other copy followed it: its count, whether it
## stands, and its sizes.
##
##   godot --headless --path . --script src/dev/follow_reply_probe.gd
##
## cffix2 (2026-11-12): edit_model's "Took off 1. / As it stands now: it tips
## over, 1.8 studs past the front edge" weighed the model before the other
## copy took the same part off (CommandSocket._one_step follows after the
## reply is made), so it spoke of a model that no longer stood there; the
## count was made right after the follow (dd369b5e9), the rest was not. Here:
## a 2 x 2 brick on no floor, and on it two copies of an arm, a 1 x 8 plate
## with a 2 x 4 brick at its far end, one turned to the other side; it
## stands, balanced (check_design with edit={}, the model as it is). Over
## MCP, edit_model takes the brick off one arm, and
## the other arm's goes too: three parts, balanced again. The reply counts 3,
## says nothing tips, and gives the sizes measured as it stands; check_design
## after it says the same. Exits non-zero on a failure.
extends SceneTree

const MODEL := """0 FILE balance.ldr
0 Balance
0 Name: balance.ldr
0 Author: Brickworks
0 !BRICKWORKS FLOOR NONE
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
1 16 0 -32 0 1 0 0 0 1 0 0 0 1 arm.ldr
1 16 0 -32 0 -1 0 0 0 1 0 0 0 -1 arm.ldr
0 NOFILE
0 FILE arm.ldr
0 Arm
0 Name: arm.ldr
1 2 80 0 -10 1 0 0 0 1 0 0 0 1 3460.dat
1 1 120 -24 -10 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
"""

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _rpc_id: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(900.0).timeout.connect(func() -> void:
		print("follow_reply probe: not finished in time")
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	(_main.get("_store") as ModelStore).keeps = false
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var assistant: Assistant = _socket.assistant

	for how: String in ["edit_model"]:
		print("\n── %s takes the brick off one arm ──" % how)
		await _open(MODEL)
		var weight: BrickWorld.Brick = null
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.part_id == "3001" and brick.transform.origin.x > 0.0:
				weight = brick
		_check("opened: 5 parts, two arms with a brick each (%d)" % _world.brick_count(),
			_world.brick_count() == 5 and weight != null)
		if weight == null:
			continue
		var before: String = await _say("check_design", {"edit": {}})
		_check("check_design: it stands as it is (%s)" % _balance_of(before), _balance_of(before).begins_with("stands"))
		var said: String = await _say(how, {"remove": [weight.id], "picture": false})
		print("  %s:\n%s" % [how, _indented(said)])
		_check("the other arm's brick went too: 3 parts (%d)" % _world.brick_count(), _world.brick_count() == 3)
		_check("its reply counts the 3 left", said.contains("3 bricks now"))
		_check("its reply says nothing tips over: the model as it stands is balanced",
			not said.contains("tips over") and not said.contains("tips "))
		var after: String = await _say("check_design", {"edit": {}})
		_check("check_design after it: it stands (%s)" % _balance_of(after), _balance_of(after).begins_with("stands"))
		var sizes: String = assistant._measured()
		_check("its reply's sizes are the model's as it stands (%s)" % sizes.replace("\n", " / ").left(160),
			not sizes.is_empty() and said.contains(sizes))
	print("\nfollow_reply: %s" % ("%d FAILED" % _failures if _failures > 0 else "all passed"))
	quit(1 if _failures > 0 else 0)


## check_design's balance, after "Balance: ".
static func _balance_of(said: String) -> String:
	var at: int = said.find("Balance: ")
	return said.substr(at + 9).get_slice("\n", 0) if at >= 0 else ""


func _open(text: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, "model")
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		if str(block.get("type", "")) == "text":
			text += str(block.get("text", "")) + "\n"
	if text.is_empty() and (answer as Dictionary).has("error"):
		text = str((answer as Dictionary)["error"])
	await _frames(4)
	return text.strip_edges()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


static func _indented(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		out.append("      " + line)
	return "\n".join(out)
