## Whatever path stands a minifigure up, a reload brings it back.
##
##   godot --headless --path . --script src/dev/autosave_paths_probe.gd
##
## The autosave writes the working model a couple of seconds after it is
## told the model changed (ModelStore.touch). A minifigure goes down past
## the builder's signals (Builder.put_figure), so whoever stood one up had
## to tell the store themselves. A Claude session's figure went unsaved and
## a reload took it away (tabwalk, 2026-10-19); the fix then told the store
## for outside calls only, so the in-app assistant's figure (its own API
## key) still went the same way. Now the store hears every change to the
## model itself (ModelStore.listen).
##
## Here a figure is stood up by each path in turn, on top of a model already
## kept: the in-app assistant's tool, a Claude session over the connector,
## and a session over the desktop's MCP port. Each time the autosave is
## written as a reload would find it (ModelStore.write_now writes only what
## the store has heard of), the baseplate is cleared, and the working model
## is opened again from it (ModelStore.restore, what start-up does). What
## comes back must be what stood: every figure, each a figure of its own.
## Last, a change that moves only the history (a session's undo of its
## figure) is kept too. No API key: the assistant's tools are called as its
## design loop calls them.
extends SceneTree

## The desktop's MCP port for this probe (tools/release's range for it).
const PORT := 8943

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _assistant: Assistant
var _sent: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_assistant = _main.get("_assistant")
	# A probe keeps no working model unless it turns that on (Main).
	_store.keeps = true
	DirAccess.remove_absolute(ModelStore.autosave())
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_store.scenery.clear()
	_assistant.forget_built()
	var connector: CommandSocket = (_main.get("_connector") as ClaudeConnector).rpc
	_main.call("_open_commands", PORT)
	var port: CommandSocket = _main.get("_commands")
	_ok(port != null, "the desktop's MCP port is open on %d" % PORT)

	print("\na model already kept")
	_builder.held_part = "3001"
	_builder.held_color = 4
	_builder.update_preview(Vector3(40.0, 400.0, 40.0), Vector3.DOWN)
	_ok(_builder.place() != 0, "the person puts a brick down")
	var back: Dictionary = await _reload()
	_ok(back == _standing_was, "a reload brings back the brick (%d part)" % _count(back))

	var paths: Array = [
		["the in-app assistant (its own API key)", func(input: Dictionary) -> String:
			return str(await _assistant.use_tool("add_minifig", input))],
		["a Claude session over the connector", func(input: Dictionary) -> String:
			return await _call(connector, "add_minifig", input)],
		["a Claude session over the desktop's MCP port", func(input: Dictionary) -> String:
			return await _call(port, "add_minifig", input)],
	]
	var x: int = 6
	for path: Array in paths:
		print("\n%s stands a minifigure up" % path[0])
		var figures: int = _figures(_standing()).size()
		var said: String = await (path[1] as Callable).call(
			{"x": x, "z": 2, "facing": "+z", "name": "Walker %d" % x})
		x += 4
		var now: Dictionary = _standing()
		_ok(said.begins_with("Placed") and _figures(now).size() == figures + 1,
			"it stands: %s" % said.left(60))
		back = await _reload()
		_ok(back == now, "a reload brings back all %d parts as they stood (%d came back)"
			% [_count(now), _count(back)])
		_ok(_figures(back).size() == figures + 1, "...with %d figure%s, each one figure: %s"
			% [figures + 1, "" if figures == 0 else "s", ", ".join(_figures(back).keys())])

	print("\na session undoes its figure")
	var said: String = await _call(connector, "add_minifig",
		{"x": x, "z": 2, "facing": "+z", "name": "Undone"})
	var with_it: Dictionary = _standing()
	await process_frame
	await process_frame
	_store.write_now()
	said = await _call(connector, "undo", {})
	var now: Dictionary = _standing()
	_ok(said.begins_with("Undid") and now != with_it, "undone: %s" % said.left(60))
	back = await _reload()
	_ok(back == now and not _figures(back).has("Undone"),
		"a reload brings back the model without it (%d parts, %d came back)"
		% [_count(now), _count(back)])

	# A sub-model or a step changes no part's place or colour, so the world's
	# revision stays; the history says it. Named here by the builder alone,
	# with nobody telling the store, as a path that forgot to would.
	print("\na change only the history says: a part made a sub-model")
	var brick: int = 0
	for one: BrickWorld.Brick in _world.bricks():
		if one.group.is_empty() and not _store.scenery.has(one.id):
			brick = one.id
	_builder.clear_selection()
	_builder.select_brick(brick, false)
	var revision: int = _world.revision
	_ok(_builder.name_group("Base") == 1 and _world.revision == revision,
		"the person's brick is the sub-model Base, the revision as it was (%d)" % revision)
	now = _standing()
	back = await _reload()
	_ok(back == now and _figures(back).get("Base", 0) == 1,
		"a reload brings it back in Base (%d parts, %d came back)" % [_count(now), _count(back)])

	if port != null:
		port.queue_free()
	print("")
	if _failures > 0:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	else:
		print("whatever path changed the model, a reload brings it back")
	quit(1 if _failures > 0 else 0)


## What stood when [method _reload] began.
var _standing_was: Dictionary = {}


## Reload as a tab does: the working model written as the store has heard
## it (nothing written when it heard of no change), the baseplate cleared,
## and the working model opened again. What stands after.
func _reload() -> Dictionary:
	# Heard at the end of a frame (ModelStore.tick).
	await process_frame
	_standing_was = _standing()
	_store.write_now()
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_store.scenery.clear()
	_assistant.forget_built()
	_store.restore()
	await process_frame
	await process_frame
	# The restore is not a change of anybody's: flushed, so the next path's
	# change is the only one the store has heard of.
	_store.write_now()
	return _standing()


## A session's call, as the connector and the MCP port answer it.
func _call(socket: CommandSocket, tool: String, input: Dictionary) -> String:
	_sent += 1
	var answer: Variant = await socket.answer_rpc({"jsonrpc": "2.0", "id": _sent,
		"method": "tools/call", "params": {"name": tool, "arguments": input}})
	var out := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		out.append(str((block as Dictionary).get("text", "")))
	return " ".join(out)


## What stands, as "part|colour|where|group" -> how many: the same model,
## whatever numbers its parts came back under and to the precision a file
## keeps.
func _standing() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var at: Transform3D = brick.transform
		var key: String = "%s|%d|%s|%s|%s|%s|%s" % [brick.part_id, brick.color_code,
			at.origin.snapped(Vector3.ONE * 0.1), at.basis.x.snapped(Vector3.ONE * 0.001),
			at.basis.y.snapped(Vector3.ONE * 0.001), at.basis.z.snapped(Vector3.ONE * 0.001),
			brick.group]
		out[key] = int(out.get(key, 0)) + 1
	return out


func _count(standing: Dictionary) -> int:
	var total: int = 0
	for key: String in standing:
		total += int(standing[key])
	return total


## The figures in [param standing]: group -> parts.
func _figures(standing: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in standing:
		var group: String = key.get_slice("|", 6)
		if not group.is_empty():
			out[group] = int(out.get(group, 0)) + int(standing[key])
	return out


func _ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_failures += 1
