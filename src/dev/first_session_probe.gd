## The first design on the example a first visit opens on is a model of its own.
##
##   godot --headless --path . --script src/dev/first_session_probe.gd
##
## walk256 (M15, 2026-10-25): a new account opens on the example Car, and
## the first design a Claude session made over MCP was built into it: the
## lighthouse stood round the car, Claude called the car's 64 parts "placed
## by hand", left them be, and saved them with the design. The assistant's
## panel took the car off only when its brief began a conversation; a design
## asked for after a question went in beside it too. And the baseplate the
## lighthouse said it stands on, made part of the build, was "placed by hand"
## as well.
##
## On the real scene, as a probe starts (the example, untouched), each call
## as the connector and the MCP port make it (CommandSocket.answer_rpc):
##
## - a session's first submit_design, on a blue baseplate part of the build:
##   none of the car is left, the model is the design's parts on its plate,
##   called by the design's name and no example; look_at_model calls the
##   plate the baseplate, and nothing placed by hand; the panel says the car
##   was taken off;
## - its next submit_design replaces only its own design, and Undo takes
##   each back, as one step each: the first to the empty model it began;
## - the assistant's own design, after a question rather than as a brief
##   (no conversation begun): the car comes off the same way;
## - a person's own part, on a bare baseplate: a session's design goes in
##   beside it and it is placed by hand, as it is.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _store: ModelStore
var _builder: Builder
var _verbs: EditVerbs
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
	_store = _main.get("_store")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var assistant: Assistant = _main.get("_assistant")
	var chat: ChatPanel = _main.get("_chat")

	print("\na session's first design, on the example")
	var car: Dictionary = _parts()
	_ok(_store.title == "Car" and car.size() > 0 and bool(_main.get("_sample_untouched")),
		"a first visit opens the example, untouched: \"%s\", %d kinds of part" % [_store.title, car.size()])
	var said: String = await _call("submit_design", _design("Probe Lighthouse", 0))
	await _frames(10)
	var after: Dictionary = _parts()
	_ok(_left_of(car, after) == 0, "none of the car is left (%d of its parts): %s"
		% [_left_of(car, after), said.left(70).replace("\n", " ")])
	_ok(_count(after) == 8 + 1 and _floor_plates() == 1,
		"the model is the design's 8 parts on its baseplate: %d parts, %d plate"
		% [_count(after), _floor_plates()])
	_ok(_store.title == "Probe Lighthouse" and not _store.example,
		"...called by the design's name, and no example: \"%s\"" % _store.title)
	var look: String = await _call("look_at_model", {})
	_ok(not look.contains("placed by hand"), "look_at_model says nothing is placed by hand")
	_ok(look.contains("(the baseplate, part of the model)"),
		"...and calls the design's plate the baseplate")
	_ok(_said_in(chat).contains("Took the example car off the baseplate"),
		"the panel says the car was taken off")

	print("\nits next design, and Undo")
	var designed: Dictionary = _parts()
	await _call("submit_design", _design("Probe Lighthouse", 4))
	await _frames(10)
	var second: Dictionary = _parts()
	_ok(_count(second) == 8 + 1 and second != designed,
		"the next design replaces the first, on its plate: %d parts" % _count(second))
	await _verbs.press("undo")
	await _frames(5)
	_ok(_parts() == designed, "Undo takes the second back to the first: %d parts" % _count(_parts()))
	await _verbs.press("undo")
	await _frames(5)
	_ok(_count(_parts()) == 0 and _left_of(car, _parts()) == 0,
		"...and the first back to the empty model it began, not the car: %d parts" % _count(_parts()))

	print("\nthe assistant's design, asked after a question")
	_first_visit()
	_ok(bool(_main.get("_sample_untouched")) and _parts() == car, "the example again, untouched")
	await assistant.use_tool("submit_design", _design("Probe Tower", 8))
	await _frames(10)
	_ok(_left_of(car, _parts()) == 0 and _count(_parts()) == 8 + 1,
		"the car comes off for it too: %d of the car left, %d parts"
		% [_left_of(car, _parts()), _count(_parts())])
	_ok(_store.title == "Probe Tower", "...and it is called by its name: \"%s\"" % _store.title)

	print("\na person's own part")
	_main.call("clear_model")
	await _frames(5)
	var mine := Transform3D(Basis.IDENTITY, Vector3(-200, -24, -200))
	_builder.register(_world.add_brick("3003", 14, mine), "3003", mine)
	_main.set("_sample_untouched", false)
	await _call("submit_design", _design("Probe Hut", 0))
	await _frames(10)
	var kept: Dictionary = _parts()
	_ok(_of(kept, "3003", 14) == 1, "a session's design goes in beside it")
	look = await _call("look_at_model", {"part": "3003"})
	_ok(look.contains("(placed by hand)"), "...and it is placed by hand, as it is")

	print("")
	print("%d failed" % _failures if _failures > 0
		else "the first design on the example is a model of its own")
	quit(1 if _failures > 0 else 0)


## A small design on a blue baseplate part of the build: two courses of
## bricks, [param x] studs along.
func _design(name: String, x: int) -> Dictionary:
	var bricks: Array = []
	for course: int in 2:
		for n: int in 4:
			bricks.append({"part": "3001", "color": 15 if course == 0 else 4,
				"x": 4 * n + (2 if course % 2 else 0) + x, "y": 3 * course, "z": 4, "rot": 0})
	return {"name": name, "description": "a probe's lighthouse", "floor": "baseplate",
		"floor_colour": "Blue", "bricks": bricks}


## The example as a first visit has it.
func _first_visit() -> void:
	_main.call("_open", _main.get("SAMPLE_MODEL"))
	_main.call("_lay_baseplate")
	_main.set("_sample_untouched", true)


func _call(tool: String, input: Dictionary) -> String:
	_sent += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _sent,
		"method": "tools/call", "params": {"name": tool, "arguments": input}})
	var out := PackedStringArray()
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		out.append(str((block as Dictionary).get("text", "")))
	return " ".join(out)


## The model's parts (scenery apart) as "part colour x z" -> how many.
func _parts() -> Dictionary:
	var counted: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var key: String = "%s %d %d %d" % [brick.part_id, brick.color_code,
			roundi(brick.transform.origin.x), roundi(brick.transform.origin.z)]
		counted[key] = int(counted.get(key, 0)) + 1
	return counted


## How many of the parts counted are [param part] in [param colour].
func _of(parts: Dictionary, part: String, colour: int) -> int:
	var total: int = 0
	for key: String in parts:
		if key.begins_with("%s %d " % [part, colour]):
			total += int(parts[key])
	return total


func _count(parts: Dictionary) -> int:
	var total: int = 0
	for key: String in parts:
		total += int(parts[key])
	return total


## How many of [param was]'s parts, kind by kind, [param now] still has
## beyond what the design itself is made of (3001s and its plate).
func _left_of(was: Dictionary, now: Dictionary) -> int:
	var left: int = 0
	for key: String in was:
		if key.begins_with("3001 "):
			continue
		left += mini(int(was[key]), int(now.get(key, 0)))
	return left


func _floor_plates() -> int:
	return (_main.get("_floor") as FloorLayer).own_plates().size()


func _said_in(chat: ChatPanel) -> String:
	var words := PackedStringArray()
	for label: Node in chat.find_children("*", "Label", true, false):
		words.append((label as Label).text)
	for text: Node in chat.find_children("*", "RichTextLabel", true, false):
		words.append((text as RichTextLabel).get_parsed_text())
	return " ".join(words)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		print("  FAIL ", what)
