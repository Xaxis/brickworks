## Does a connector chat that opens on changing the model in its tab hear how
## to change it, and one that opens on designing hear the method as before?
##
##   godot --headless --path . --script src/dev/cad_sitting_probe.gd
##
## ClaudeConnector._taught put the working method (Assistant.METHOD: plan_scale,
## then submit_design the silhouette) ahead of a chat's first answer whatever
## the call, so a chat come to measure or recolour a model already built was
## told to plan a scale and submit a silhouette: to rebuild the person's model.
## Now a chat whose first call reads or changes the parts standing
## (ClaudeConnector.CHANGING_CALLS), on a model to change, is told the guide's
## CHANGING SOMETHING THAT IS ALREADY BUILT instead, once, and the method at its
## first design call. A chat that opens on designing hears the method on the
## same call as before: on the example car a tab opens on, untouched, a look
## first is a design's opening (four of the bench's relay sessions of
## 2026-10-31 began so), and so is any first call on an empty baseplate.
##
## Through the connector as the relay's calls reach it (_sitting, _begin,
## answer_rpc, _taught), in Main. On the code before, a chat changing a model
## was told the method, and this fails there.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _connector: ClaudeConnector
var _assistant: Assistant
var _changing: String = ""
var _next: int = 0


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
	_connector = _main.get("_connector")
	_assistant = _main.get("_assistant")
	(_main.get("_store") as ModelStore).keeps = false
	_changing = _assistant.read_guide("changing")

	print("\n── the example car a tab opens on, untouched ──")
	_check(bool(_main.get("_sample_untouched")) and _parts() > 0,
		"the tab opens on the example car: %d parts" % _parts())
	var said: Array = await _call_as("e1", "look_at_model", {})
	_check(_first(said) == Assistant.METHOD and said.size() > 1,
		"a chat that looks first hears the method on that call, as the bench's did: %s"
			% _first(said).left(40))
	said = await _call_as("e2", "how_real_sets_build_this", {"subject": "a red tower"})
	_check(_first(said) == Assistant.METHOD,
		"...and one that opens on how_real_sets_build_this, on that call")

	print("\n── a chat designs a tower, and the tab holds it ──")
	said = await _call_as("d1", "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	_check(_first(said) == Assistant.METHOD, "a chat that opens on plan_scale hears the method on it")
	said = await _call_as("d1", "submit_design", _tower())
	_check(_parts() == 6 and _told(said).is_empty(),
		"its tower stands in the car's place (%d parts), and it is not told again" % _parts())

	print("\n── a chat that opens on changing it ──")
	said = await _call_as("c1", "look_at_model", {})
	_check(_first(said) == _changing and not _told(said).has(Assistant.METHOD),
		"a chat that looks first hears how to change what is built, not the method: %s"
			% _first(said).get_slice("\n", 0))
	said = await _call_as("c1", "edit_model", {"recolor": [{"bricks": [_first_brick()], "color": 1}]})
	_check(_told(said).is_empty() and _text(said).length() > 0,
		"...and nothing more as it edits: %s" % _text(said).left(50).replace("\n", " "))
	said = await _call_as("c1", "plan_scale", {"subject": "a lighthouse", "longest_metres": 20})
	_check(_first(said) == Assistant.METHOD, "...and the method at its first design call")
	said = await _call_as("c1", "look_at_model", {})
	_check(_told(said).is_empty(), "...and neither again after it")
	said = await _call_as("c2", "edit_model", {"recolor": [{"bricks": [_first_brick()], "color": 4}]})
	_check(_first(said) == _changing and _told(said).size() == 1,
		"a chat that opens on an edit is told how to change it, once")
	said = await _call_as("c3", "measure", {"from": "0 0 0", "to": "4 0 0"})
	_check(_first(said) == _changing, "...and one that opens on measure: %s"
		% _text(said).right(60).replace("\n", " "))

	print("\n── a chat that opens on designing beside it ──")
	said = await _call_as("d2", "how_real_sets_build_this", {"subject": "a lighthouse"})
	_check(_first(said) == Assistant.METHOD, "how_real_sets_build_this first hears the method on that call")
	said = await _call_as("d3", "read_guide", {"section": "shapes"})
	_check(_first(said) == Assistant.METHOD, "...and so does read_guide first")
	said = await _call_as("d4", "search_parts", {"query": "slope"})
	_check(_first(said) == Assistant.METHOD, "...and search_parts first")

	print("\n── an empty baseplate ──")
	await _call_as("d4", "clear_model", {})
	said = await _call_as("e3", "look_at_model", {})
	_check(_parts() == 0 and _first(said) == Assistant.METHOD,
		"a chat that looks first at nothing hears the method: there is nothing to change")

	print("\n%s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures > 0 else 0)


## A call from [param chat] as the relay hands it to the tab, answered as the
## tab answers it (ClaudeConnector._answer): what the chat is sent.
func _call_as(chat: String, tool: String, arguments: Dictionary) -> Array:
	_next += 1
	var request: Dictionary = {"jsonrpc": "2.0", "id": _next, "method": "tools/call",
		"params": {"name": tool, "arguments": arguments,
			"_meta": {"brickworks/chat": {"chat": chat, "since": "2026-10-31T06:00:00Z"}}}}
	var sitting: Dictionary = _connector._sitting(request)
	_connector._begin(sitting, tool, arguments)
	var answer: Variant = _connector._taught(sitting, tool,
		await _connector.rpc.answer_rpc(request))
	return ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []) as Array


## The guidance an answer carries ahead of the tool's words: the method, how
## to change what is built, or neither.
func _told(blocks: Array) -> Array:
	var out: Array = []
	for block: Variant in blocks:
		var text: String = str((block as Dictionary).get("text", ""))
		if text == Assistant.METHOD or text == _changing:
			out.append(text)
	return out


static func _first(blocks: Array) -> String:
	return str((blocks[0] as Dictionary).get("text", "")) if not blocks.is_empty() else ""


static func _text(blocks: Array) -> String:
	var out := PackedStringArray()
	for block: Variant in blocks:
		out.append(str((block as Dictionary).get("text", "")))
	return "\n".join(out).strip_edges()


func _tower() -> Dictionary:
	var bricks: Array = []
	for course: int in 6:
		bricks.append({"part": "3003", "color": 4, "x": 10, "y": 3 * course, "z": 10, "rot": 0})
	return {"name": "A red tower", "description": "a slender red tower", "floor": "none",
		"bricks": bricks}


func _parts() -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _assistant.scenery.has(brick.id):
			count += 1
	return count


func _first_brick() -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if not _assistant.scenery.has(brick.id):
			return brick.id
	return 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)
