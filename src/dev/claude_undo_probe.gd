## What a session changes is one undo step, its own.
##
##   godot --headless --path . --script src/dev/claude_undo_probe.gd
##
## An edit_model from a Claude session went into no history at all: the
## window's commands had their undo, an edit about a selection had its own,
## and everything else the assistant did from outside changed the world
## behind the builder's back. So the person's Undo after Claude's edit took
## back the person's own last part and left Claude's edit standing. Here the
## person places a part by hand, a session edits over the connector's own
## path (CommandSocket.answer_rpc), and Undo takes back the session's edit
## and keeps the person's part; a second Undo takes the person's part. Then
## every tool that changes the model, each called as a session calls it: one
## step more to undo, and undoing it puts back the model exactly as it was.
## Last, a session's design is on show whole as its call answers, where the
## app's own goes up a step at a time (BuildPlayback).
##
## And each of those changes reaches the autosave. A minifigure stood up
## over the connector raised nothing the store heard, so the autosave kept
## the model without it and a reload took it away (tabwalk, 2026-10-19).
## So the calls go through the app's own socket for the connector, wired as
## the app wires it (CommandSocket.model_changed).
extends SceneTree

var _failures: int = 0
var _world: BrickWorld
var _builder: Builder
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
	var assistant: Assistant = main.get("_assistant")
	var store: ModelStore = main.get("_store")
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	store.scenery.clear()
	assistant.forget_built()
	_socket = (main.get("_connector") as ClaudeConnector).rpc
	await process_frame

	print("\nthe person places a part, then a session edits")
	_builder.held_part = "3001"
	_builder.held_color = 4
	_builder.update_preview(Vector3(40.0, 400.0, 40.0), Vector3.DOWN)
	var theirs: int = _builder.place()
	_ok(theirs != 0 and _builder.history_depth() == 1,
		"the person's brick is down, one step to undo (%d)" % _builder.history_depth())
	var said: String = await _call("edit_model", {"add": [
		{"part": "3001", "color": 1, "x": 10, "y": 0, "z": 10, "rot": 0}]})
	_ok(said.begins_with("Done") and _world.brick_count() == 2,
		"the session's edit lands: %s" % said.left(40))
	_ok(_builder.history_depth() == 2, "...as a step of its own (%d): %s" % [
		_builder.history_depth(), _builder.history_words(1)[0] if _builder.history_depth() > 0 else ""])
	_builder.undo()
	_ok(_world.brick_count() == 1 and _world.get_brick(theirs) != null,
		"Undo takes back the session's edit and keeps the person's brick")
	_builder.undo()
	_ok(_world.brick_count() == 0, "a second Undo takes the person's brick")

	print("\nevery tool that changes the model is one step, and Undo puts it back")
	_builder.update_preview(Vector3(40.0, 400.0, 40.0), Vector3.DOWN)
	theirs = _builder.place()
	var wall: Array = []
	for course: int in 4:
		for n: int in 3:
			wall.append({"part": "3010", "color": 0,
				"x": 4 * n + (2 if course % 2 else 0) + 20, "y": 3 * course, "z": 20, "rot": 0})
	var calls: Array = [
		["submit_design", {"name": "A wall", "description": "a black wall", "bricks": wall,
			"features": ["eyes"]}],
		["review_model", {"feature": "eyes"}],
		["edit_model", {"recolor": [{"bricks": ["first"], "color": 72}]}],
		["edit_model", {"move": [{"bricks": ["theirs"], "dx": 0, "dy": 0, "dz": 4}]}],
		["edit_model", {"remove": ["first"]}],
		["restyle_model", {"sideways": 0.3, "masonry": 0.3}],
		["add_minifig", {"x": 2, "z": 8, "facing": "+z"}],
		["clear_model", {}],
	]
	for call: Array in calls:
		var input: Dictionary = call[1]
		var first: int = _first_of_theirs(theirs)
		var asked: String = JSON.stringify(input).replace("\"first\"", str(first)) \
			.replace("\"theirs\"", str(theirs))
		input = JSON.parse_string(asked)
		var was: Dictionary = _standing()
		var depth: int = _builder.history_depth()
		# The last call's redo is told to the store at the end of a frame
		# (Main._edited_soon): heard before this call, not during it.
		await process_frame
		await process_frame
		store.set("_pending", false)
		said = await _call(str(call[0]), input)
		var changed: bool = _standing() != was
		_ok(not changed or bool(store.get("_pending")),
			"%s's change is told to the autosave" % call[0])
		# A feature's review lays a piece only where one fits: nothing laid is
		# nothing to undo.
		if str(call[0]) == "review_model" and not changed:
			_ok(_builder.history_depth() == depth, "review_model laid nothing, and made no step: %s"
				% said.left(50).replace("\n", " "))
			continue
		# Clearing begins a new model, as New does: its one step is all there is.
		var steps: int = 1 if str(call[0]) == "clear_model" else depth + 1
		_ok(changed and _builder.history_depth() == steps,
			"%s changes the model in one step (%d to %d): %s" % [call[0], depth,
				_builder.history_depth(), said.left(50).replace("\n", " ")])
		_builder.undo()
		_ok(_standing() == was, "...and Undo puts back the %d parts it was" % _world.brick_count())
		# Done again, so the next call has what this one made to work on.
		_builder.redo()

	# Claude is told a design is built as its call answers. In view it then
	# went on going up for 2.5 s (BuildPlayback): 150 frames on a graphics
	# card of a model that was not yet what the answer said.
	print("\nwhat a session puts down is on show, whole, as its call answers")
	var design: Dictionary = {"name": "A wall", "description": "a black wall", "bricks": wall}
	# On the bare ground again, as above: clear_model laid a baseplate.
	_world.clear()
	_builder.lattice.clear()
	store.scenery.clear()
	assistant.forget_built()
	said = await _call("submit_design", design)
	_ok(said.contains("Built. %d bricks" % wall.size()) and not playback.is_playing()
		and _hidden() == 0, "a session's design is drawn whole, not assembled (%d of %d hidden, %s): %s"
		% [_hidden(), _world.brick_count(), "playing" if playback.is_playing() else "not playing",
			said.left(30)])
	_world.clear()
	_builder.lattice.clear()
	assistant.forget_built()
	said = str(await assistant.use_tool("submit_design", design))
	_ok(said.contains("Built. %d bricks" % wall.size()), "the app puts the same design down itself: %s"
		% said.left(30))
	_ok(playback.is_playing() and _hidden() > 0,
		"...and the same design put down by the app itself goes up a step at a time (%d hidden)"
		% _hidden())
	playback.stop()

	print("")
	if _failures > 0:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	else:
		print("what a session changes, Undo takes back, and only that")
	quit(1 if _failures > 0 else 0)


## A session's call, as the connector and the MCP port answer it.
func _call(tool: String, input: Dictionary) -> String:
	_sent += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _sent,
		"method": "tools/call", "params": {"name": tool, "arguments": input}})
	var out := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		out.append(str((block as Dictionary).get("text", "")))
	return " ".join(out)


## A brick that is not the person's, to change: the first the session laid.
func _first_of_theirs(theirs: int) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.id != theirs and not (_socket.assistant.scenery as Dictionary).has(brick.id):
			return brick.id
	return 0


## Bricks standing but not drawn: the build animation's still to come.
func _hidden() -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.hidden:
			count += 1
	return count


## What stands, as "part colour transform" -> how many: the same model,
## whatever numbers its parts came back under.
func _standing() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if (_socket.assistant.scenery as Dictionary).has(brick.id):
			continue
		var key: String = "%s %d %s" % [brick.part_id, brick.color_code, brick.transform]
		out[key] = int(out.get(key, 0)) + 1
	return out


func _ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_failures += 1
