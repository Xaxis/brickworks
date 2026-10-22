## A part Undo takes off and Redo puts back is the same part, by the same number.
##
##   godot --headless --path . --script src/dev/undo_ids_probe.gd
##
## Redo put a part back as a new number, and everything that had named it
## by its old one went stale: the session's own numbers from its last answer
## ("No brick 14"), the assistant's record of what it built (read again only
## at Claude's next call, Assistant.follow_renumbering), and the surface
## pass's pieces, which a reject then said were off while they stood. Here a
## session edits, the person presses Undo and Redo, and each of those still
## names the part. The calls go through the connector's own path
## (CommandSocket.answer_rpc), as claude_undo_probe's do.
extends SceneTree

var _failures: int = 0
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _socket: CommandSocket
var _sent: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	_world = main.get("_world")
	_builder = main.get("_builder")
	_assistant = main.get("_assistant")
	_socket = (main.get("_connector") as ClaudeConnector).rpc
	_bare()

	print("\na session's part, undone and redone, keeps its number")
	var said: String = await _call("edit_model", {"add": [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0}]})
	var theirs: int = _built_ids()[0] if _built_ids().size() == 1 else 0
	_ok(said.begins_with("Done") and theirs != 0, "the session put a part down (%d): %s"
		% [theirs, said.left(30)])
	_builder.undo()
	_ok(_world.get_brick(theirs) == null, "Undo takes it off")
	_builder.redo()
	var back: Array[int] = _built_ids()
	_ok(back == [theirs] and _world.get_brick(theirs).part_id == "3001",
		"Redo puts it back as %d, the number the session was told (%s)" % [theirs, str(back)])
	said = await _call("edit_model", {"recolor": [{"bricks": [theirs], "color": 1}]})
	_ok(said.begins_with("Done") and _world.get_brick(theirs) != null
		and _world.get_brick(theirs).color_code == 1,
		"...so the session's next edit by that number lands: %s" % said.left(40).replace("\n", " "))

	print("\nwhat the assistant built, undone and redone, is what stands")
	_bare()
	said = await _call("submit_design", {"name": "A roof", "description": "a plate on bricks",
		"bricks": _roof()})
	_ok(said.begins_with("Built"), "a session's design is built: %s" % said.left(30))
	var placed: PackedInt64Array = _assistant.get("_placed_ids")
	_ok(placed.size() == _roof().size(), "the assistant holds its %d parts (%d)"
		% [_roof().size(), placed.size()])
	_builder.undo()
	_builder.redo()
	# No call between: in the app's own panel the numbers were read again
	# only at Claude's next tool call.
	_ok(_standing(_assistant.get("_placed_ids")) == _roof().size(),
		"after Undo and Redo, every part the assistant holds stands (%d of %d), before any call"
		% [_standing(_assistant.get("_placed_ids")), _roof().size()])

	print("\nthe surface pass's pieces, undone and redone, come off when rejected")
	var before: int = _built_ids().size()
	said = await _call("review_model", {"surface": true})
	var tiles: int = _built_ids().size() - before
	_ok(said.contains("S1") and tiles > 0, "the pass laid %d tiles on the roof: %s"
		% [tiles, said.left(40).replace("\n", " ")])
	_builder.undo()
	_ok(_built_ids().size() == before, "Undo takes the tiles off")
	_builder.redo()
	_ok(_built_ids().size() == before + tiles, "Redo lays them again")
	said = await _call("settle_surface", {"finding": "S1", "verdict": "reject",
		"reason": "the roof gets a terrace of its own"})
	_ok(_built_ids().size() == before,
		"a reject takes the app's pieces off (%d of %d left): %s" % [
			_built_ids().size() - before, tiles, said.left(60).replace("\n", " ")])

	print("")
	if _failures > 0:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	else:
		print("a part back from Undo or Redo is the part everything named")
	quit(1 if _failures > 0 else 0)


## On the bare ground, with no history: the probe's own model.
func _bare() -> void:
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	(_assistant.scenery as Dictionary).clear()
	_assistant.forget_built()


## A session's call, as the connector and the MCP port answer it.
func _call(tool: String, input: Dictionary) -> String:
	_sent += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _sent,
		"method": "tools/call", "params": {"name": tool, "arguments": input}})
	var out := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		out.append(str((block as Dictionary).get("text", "")))
	return " ".join(out)


## The model's parts by number, without the floor under it.
func _built_ids() -> Array[int]:
	var out: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not (_assistant.scenery as Dictionary).has(brick.id):
			out.append(brick.id)
	out.sort()
	return out


func _standing(ids: PackedInt64Array) -> int:
	var count: int = 0
	for brick_id: int in ids:
		if _world.get_brick(brick_id) != null:
			count += 1
	return count


## A 6 x 8 plate on twelve 2 x 2 bricks: 48 open studs (surface_probe's roof).
func _roof() -> Array:
	var out: Array = []
	for x: int in [0, 2, 4, 6]:
		for z: int in [0, 2, 4]:
			out.append({"part": "3003", "color": 15, "x": x, "y": 0, "z": z, "rot": 0})
	out.append({"part": "3036", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0})
	return out


func _ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_failures += 1
