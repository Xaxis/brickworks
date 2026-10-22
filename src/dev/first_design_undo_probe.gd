## Undo takes back all of a session's first design, the floor it chose too.
##
##   godot --headless --path . --script src/dev/first_design_undo_probe.gd
##
## A session's first submit_design chooses a floor: the floor is kept as a
## step of the history (FloorLayer.choose, and adopt for a baseplate that is
## part of the build), and the parts the design laid went into no step. One
## call is one step (CommandSocket._one_step), and that step was only the
## floor's, so undoing everything after two small designs left 55 and 8 parts
## on the bare baseplate (best2app, 2026-10-22). And kept as the newest of
## the call's steps, it was redone before the floor, which was then laid
## round the person's part alone and a baseplate part of the build came back
## as scenery. Here, twice from the bare baseplate, the person places a part
## and a session goes to work, each call as the connector makes it
## (CommandSocket.answer_rpc): a first design on a tan baseplate part of the
## build and the calls that change it after, then a design on no floor and
## another on the baseplate. Each call is one step that Undo takes back
## exactly and Redo puts back. The session's own undo takes back its work
## and keeps the person's part, and the person's Undo, pressed until there
## is nothing left, leaves the bare baseplate the model stood on; Redo,
## pressed as often, every part.
extends SceneTree

var _failures: int = 0
var _world: BrickWorld
var _builder: Builder
var _socket: CommandSocket
var _store: ModelStore
var _floor: FloorLayer
var _verbs: EditVerbs
var _main: Node
var _sent: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	_main = main
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	_world = main.get("_world")
	_builder = main.get("_builder")
	_store = main.get("_store")
	_floor = main.get("_floor")
	_verbs = main.get("_verbs")
	_socket = (main.get("_connector") as ClaudeConnector).rpc
	var cart: Array = []
	for course: int in 3:
		for n: int in 2:
			cart.append({"part": "3010", "color": 0,
				"x": 4 * n + (2 if course % 2 else 0) + 20, "y": 3 * course, "z": 20, "rot": 0})
	var garden: Array = []
	for course: int in 2:
		for n: int in 3:
			garden.append({"part": "3001", "color": 2,
				"x": 4 * n + (2 if course % 2 else 0) + 4, "y": 3 * course, "z": 4, "rot": 0})
	var on_tan: Dictionary = {"name": "A garden", "description": "a green hedge on a tan plate",
		"floor": "baseplate", "floor_colour": "Tan", "bricks": garden}

	var first: Array = await _session("a session's first design stands on a tan baseplate, part of the build, "
		+ "and it goes on", [
		["submit_design", on_tan.merged({"features": ["eyes"]})],
		["review_model", {"feature": "eyes"}],
		["settle_feature", {"feature": "eyes", "verdict": "reject",
			"reason": "a hedge has no eyes"}],
		["edit_model", {"add": [{"part": "3001", "color": 1, "x": 12, "y": 0, "z": 8, "rot": 0}]}],
		["place_technique", {"id": "hinged wing", "x": 4, "y": 6, "z": 4, "turn": 0}],
		["set_floor", {"kind": "baseplate", "colour": 288}],
	], 4)
	var made: Array = await _session("a session designs twice, each on its own floor", [
		["submit_design", {"name": "A cart", "description": "a black cart, picked up and played with",
			"floor": "none", "bricks": cart}],
		["submit_design", on_tan],
	], 2)
	# The cart was undone and redone, so it stands under new numbers, and
	# the garden was laid beside it; in its place, it is the first session's.
	var carts: int = 0
	for key: String in (made.back() as Dictionary)["standing"]:
		if key.begins_with("3010 0 "):
			carts += int(made.back()["standing"][key])
	_ok(carts == 0 and made.back() == first[0],
		"...the garden stands in the cart's place, not beside it (%d of its parts left, %d parts)"
		% [carts, int(made.back()["parts"])])

	print("")
	if _failures > 0:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	else:
		print("a session's first design, floor and parts, is undone and redone whole")
	quit(1 if _failures > 0 else 0)


## On the bare baseplate, the person places a part and a session makes
## [param calls], at least [param changing] of which change the model.
## Returns the model after each that did.
func _session(title: String, calls: Array, changing: int) -> Array:
	var assistant: Assistant = _main.get("_assistant")
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_store.scenery.clear()
	assistant.forget_built()
	assistant.forget_conversation()
	_store.model_floor = ModelFloor.make(ModelFloor.BASEPLATE, 32, 32, 2)
	_main.call("_lay_baseplate")
	await process_frame
	var bare: Dictionary = _state()
	print("\n%s" % title)
	_ok(int(bare["parts"]) == 0 and str(bare["floor"]).begins_with("BASEPLATE")
		and _store.scenery.size() > 0, "the model is the bare baseplate (%s)" % bare["floor"])
	_builder.held_part = "3001"
	_builder.held_color = 4
	_builder.update_preview(Vector3(-200.0, 400.0, -200.0), Vector3.DOWN)
	var theirs: int = _builder.place()
	_ok(theirs != 0 and _builder.history_depth() == 1,
		"the person's brick is down, one step to undo (%d)" % _builder.history_depth())
	var placed: Dictionary = _state()
	var made: int = 0
	var after: Array = []
	for call: Array in calls:
		var was: Dictionary = _state()
		var depth: int = _builder.history_depth()
		await process_frame
		var said: String = await _call(str(call[0]), call[1])
		var now: Dictionary = _state()
		if now == was:
			_ok(_builder.history_depth() == depth, "%s changed nothing, and made no step: %s"
				% [call[0], said.right(400).replace("\n", " ")])
			continue
		made += 1
		_ok(_builder.history_depth() == depth + 1, "%s is one step (%d to %d), %s: %s" % [call[0],
			depth, _builder.history_depth(), _differs(was, now), said.left(40).replace("\n", " ")])
		await _verbs.press("undo")
		var back: Dictionary = _state()
		_ok(back == was, "...Undo puts back the model it changed: %s" % _differs(was, back))
		await _verbs.press("redo")
		var again: Dictionary = _state()
		_ok(again == now, "...and Redo all it did: %s" % _differs(now, again))
		after.append(now)
	_ok(made >= changing, "%d of the session's calls changed the model" % made)

	var whole: Dictionary = _state()
	var said: String = await _call("undo", {"steps": made})
	var left: Dictionary = _state()
	_ok(left == placed, "the session's undo of %d steps leaves only the person's part, "
		% made + "on the baseplate: %s (%s)" % [_differs(placed, left), said.left(80)])
	said = await _call("undo", {"steps": made, "redo": true})
	_ok(_state() == whole, "...and its redo puts back everything: %s" % _differs(whole, _state()))

	var presses: int = 0
	while _builder.history_depth() > 0 and presses < 50:
		await _verbs.press("undo")
		presses += 1
	_ok(_state() == bare, "the person's %d Undos leave the bare baseplate it was: %s" % [presses,
		_differs(bare, _state())])
	for _n: int in presses:
		await _verbs.press("redo")
	_ok(_state() == whole, "...and %d Redos every part again: %s" % [presses,
		_differs(whole, _state())])
	return after


## A session's call, as the connector and the MCP port answer it.
func _call(tool: String, input: Dictionary) -> String:
	_sent += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _sent,
		"method": "tools/call", "params": {"name": tool, "arguments": input}})
	var out := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		out.append(str((block as Dictionary).get("text", "")))
	return " ".join(out)


## The model as a person would see it: each part (scenery apart) by part,
## colour and place, whatever its number, and what it stands on.
func _state() -> Dictionary:
	var standing: Dictionary = {}
	var parts: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		parts += 1
		var key: String = "%s %d %s" % [brick.part_id, brick.color_code, brick.transform]
		standing[key] = int(standing.get(key, 0)) + 1
	return {"parts": parts, "standing": standing, "floor": _store.model_floor.whole_words(),
		"own_plate": _floor.has_own_plate()}


func _differs(want: Dictionary, got: Dictionary) -> String:
	if want == got:
		return "the same (%d parts, %s)" % [int(got["parts"]), got["floor"]]
	var extra: int = 0
	var missing: int = 0
	for key: String in got["standing"]:
		extra += maxi(0, int(got["standing"][key]) - int(want["standing"].get(key, 0)))
	for key: String in want["standing"]:
		missing += maxi(0, int(want["standing"][key]) - int(got["standing"].get(key, 0)))
	return "%d parts not %d (%d too many, %d missing), floor %s not %s%s" % [int(got["parts"]),
		int(want["parts"]), extra, missing, got["floor"], want["floor"],
		", own plate" if bool(got["own_plate"]) != bool(want["own_plate"]) else ""]


func _ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_failures += 1
