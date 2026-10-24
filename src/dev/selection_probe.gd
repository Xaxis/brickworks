## Asking Claude about a selection changes that selection and nothing else.
##
##   godot --headless --path . --script src/dev/selection_probe.gd
##
## The example car, opened as a file opens. Its roof is selected and the
## assistant's own loop is asked to make it blue, with replies written here
## rather than fetched, so the whole run is offline: the selection read into
## the opening, a recolour and a part put down inside the room, a recolour of
## a wheel outside it refused whole, a move that would leave the roof in the
## air refused by the joints check, a submit_design refused, and the run
## ending as one undo step. Then the way a session outside the app uses it:
## the selection tool, and edit_selection asking the person for more room.
extends SceneTree


## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	var sent: int = 0

	func _send() -> void:
		sent += 1


var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Offline.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	var ended: Array = []
	assistant.finished.connect(func(ok: bool, summary: String) -> void:
		ended.append([ok, summary]))
	var edited: Array = []
	assistant.focus_edited.connect(func(words: String, _before: Image, _after: Image) -> void:
		edited.append(words))
	await process_frame

	# The car, as opening it puts it down: nobody's design.
	var ldr: LdrModel = LdrModel.load_file("res://models/car.ldr")
	for piece: LdrModel.Placement in ldr.flatten():
		var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(part_id) == null:
			continue
		var id: int = world.add_brick(part_id, piece.color_code, piece.transform)
		if id != 0:
			builder.register(id, part_id, piece.transform)
	var start: Dictionary = _shape(world)
	_ok(start.size() > 40, "the car is %d parts" % start.size())

	print("\nnothing selected")
	var none: Variant = await assistant.use_tool("selection", {})
	_ok(str(none) == Assistant.NOTHING_SELECTED, "selection says so, and how to select")

	# Its roof: everything whose top is the car's top, within a plate.
	var top: float = -INF
	for brick: BrickWorld.Brick in world.bricks():
		top = maxf(top, SelectionScope.box_of(brick.part_id, brick.transform, library).end.y)
	var roof: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if SelectionScope.box_of(brick.part_id, brick.transform, library).end.y > top - 8.0:
			roof.append(brick.id)
	roof.sort()
	for brick_id: int in roof:
		builder.selection[brick_id] = true
	_ok(roof.size() >= 2 and roof.size() < 6, "the roof is %d parts: %s" % [
		roof.size(), _named(world, roof)])

	print("\nthe roof is asked about")
	_ok(assistant.focus_on(builder.selection.keys(), true).is_empty(), "it can be")
	var said: String = str(await assistant.use_tool("selection", {}))
	var every: bool = true
	for brick_id: int in roof:
		every = every and said.contains("#%d " % brick_id)
	_ok(every, "selection names each roof part by number")
	_ok(said.contains("The room a change may use: x "), "...and the room a change may use")
	_ok(said.contains("edit_selection"), "...and how to change it")
	# A wheel's rim, made in blue: its tyre, 3641, is made only in black, and
	# since 101c4e40 (2026-10-24) a part asked for in a colour it was never
	# made in is put in the nearest it was, so a tyre painted blue stayed
	# black, an edit of nothing, neither refused nor painted.
	var wheel: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id == "4624" and wheel == 0:
			wheel = brick.id
	_ok(not said.contains("#%d " % wheel), "...and not a wheel (#%d)" % wheel)

	# Where a 1 x 1 plate sits on the roof's back plate: on its low corner.
	var back: int = 0
	for brick_id: int in roof:
		if world.get_brick(brick_id).part_id == "3020":
			back = brick_id
	var corners: Array = assistant._corners_in_studs(world.get_brick(back))
	var low: Vector3 = corners[0]
	var high: Vector3 = corners[1]

	print("\nmake the roof blue, asked in the panel, through the loop with written replies")
	var depth: int = builder.history_depth()
	# A key for this visit only, written nowhere; this machine's is untouched.
	var kept: String = OwnKey._this_visit
	OwnKey._this_visit = "sk-ant-probe-selection-0000000000000000000000000000"
	var panel := ChatPanel.new()
	root.add_child(panel)
	await process_frame
	panel.bind(assistant)
	var fresh_designs: Array = []
	panel.designing.connect(func(brief: String) -> void: fresh_designs.append(brief))
	panel.ask_about(builder.selection.keys())
	_ok(panel._chip.visible and panel._chip_words.text == "About %d selected parts"
		% roof.size() and panel._send.text == "Ask Claude",
		"the panel says what the request is about: \"%s\"" % panel._chip_words.text)
	panel._input.text = "make the roof blue"
	panel._on_send()
	_ok(panel._working and assistant.is_busy(), "the run starts")
	_ok(fresh_designs.is_empty(), "...never as a fresh design, which would clear the model")
	_ok(_text_of_panel(panel).contains("About %d selected parts: make the roof blue"
		% roof.size()) and panel._run_title.text == "Changing the selection",
		"...said in the conversation, on a card \"%s\"" % panel._run_title.text)
	while assistant.sent < 1:
		await process_frame
	var opening: String = _text_of(assistant._messages[0])
	_ok(opening.contains("#%d " % roof[0]) and opening.contains("make the roof blue")
		and opening.contains("never submit_design"),
		"it opens with the selection, the rules and the request")
	var offered: PackedStringArray = []
	for tool: Dictionary in assistant.request_body()["tools"]:
		offered.append(str(tool["name"]))
	_ok(offered.has("edit_selection") and offered.has("selection"),
		"...and is offered selection and edit_selection")

	await _reply(assistant, [_tool("edit_selection", {
		"recolor": [{"bricks": roof, "color": 1}]})])
	_ok(_colours(world, roof) == [1], "the roof is blue")
	_ok(_same_but(world, start, roof), "...and nothing else changed")

	await _reply(assistant, [_tool("edit_model", {"add": [{"part": "3024", "color": 1,
		"x": low.x, "y": high.y, "z": low.z}]})])
	var answer: String = _last_result(assistant)
	_ok(world.brick_count() == start.size() + 1, "a plate is put down on the roof: %s"
		% answer.get_slice("\n", 0))

	var before: Dictionary = _shape(world)
	await _reply(assistant, [_tool("edit_model", {
		"recolor": [{"bricks": [wheel], "color": 1}]})])
	answer = _last_result(assistant)
	_ok(answer.begins_with("Not applied — that reaches outside")
		and answer.contains("#%d" % wheel), "a wheel painted too is refused, naming it")
	_ok(_shape(world) == before, "...and the model is as it was")

	await _reply(assistant, [_tool("edit_selection", {
		"move": [{"bricks": [back], "dy": 2}]})])
	answer = _last_result(assistant)
	_ok(answer.begins_with("Not applied — the model would not hold together"),
		"lifting the roof's back plate off its studs is refused by the joints check: %s"
		% answer.substr(answer.find(":") + 2, 70))
	_ok(_shape(world) == before, "...and the model is as it was")

	# Taken out from under the plate put on it: the plate the edit never
	# named would hang in the air. The check excuses what already stood,
	# so this is asked as how the model held before against after.
	await _reply(assistant, [_tool("edit_selection", {"remove": [back]})])
	answer = _last_result(assistant)
	var plate: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if not start.has(brick.id):
			plate = brick.id
	_ok(answer.begins_with("Not applied — the model would not hold together: it leaves #%d"
		% plate), "taking the plate it stands on out from under it is refused, naming it: %s"
		% answer.substr(answer.find(":") + 2, 60))
	_ok(_shape(world) == before, "...and the model is as it was")

	await _reply(assistant, [_tool("submit_design", {"name": "car",
		"description": "a car", "bricks": [], "assemblies": []})])
	_ok(_last_result(assistant).begins_with("Not applied — the person asked about"),
		"submit_design is refused: it would replace the model")

	await _reply(assistant, [{"type": "text", "text": "The roof is blue."}])
	_ok(not ended.is_empty() and bool(ended.back()[0]), "the run ends well: %s"
		% (str(ended.back()[1]) if not ended.is_empty() else "it did not end"))
	_ok(edited.size() == 2, "the panel was told of each change (%d)" % edited.size())
	var cards: int = 0
	for child: Node in panel._log.get_children():
		if child.name.begins_with("changed"):
			cards += 1
	_ok(cards == 2 and _text_of_panel(panel).contains("Changed the selection: 3 painted")
		and not panel._working and panel._chip.visible,
		"...and showed each, the run done and the chip still up for the next")
	OwnKey._this_visit = kept
	_ok(builder.history_depth() == depth + 1, "the run is one undo step (%d, was %d): %s"
		% [builder.history_depth(), depth, builder.history_words(1)])
	_ok(builder.selection.size() == roof.size() + 1,
		"the selection is the roof as it now is, %d parts" % builder.selection.size())

	# The person's request about the roof stands (the panel's chip): a
	# session's plain edit_model keeps to it too, and so does its submit.
	before = _shape(world)
	answer = str(await assistant.use_tool("edit_model", {
		"recolor": [{"bricks": [wheel], "color": 1}]}))
	_ok(answer.begins_with("Not applied — that reaches outside") and _shape(world) == before,
		"while the request about the roof stands, edit_model keeps to it too")
	answer = str(await assistant.use_tool("submit_design", {"name": "car",
		"description": "a car", "bricks": [], "assemblies": []}))
	_ok(answer.begins_with("Not applied — the person asked about"),
		"...and submit_design is refused")

	builder.undo()
	_ok(_shape(world).values() == start.values() or _same_values(world, start),
		"one undo puts the car back as it was opened")
	builder.redo()
	_ok(_colours(world, roof).size() == 1 and world.brick_count() == start.size() + 1,
		"...and redo brings the blue roof back")
	builder.undo()

	print("\na session outside the app asks for more room")
	builder.selection.clear()
	for brick_id: int in roof:
		if world.get_brick(brick_id) != null:
			builder.selection[brick_id] = true
	assistant.unfocus()
	said = str(await assistant.use_tool("selection", {}))
	_ok(said.contains("#%d " % roof[0]), "selection reads what is selected now")
	var wheel_box: AABB = SelectionScope.box_of(world.get_brick(wheel).part_id,
		world.get_brick(wheel).transform, library)
	var room: Dictionary = {"x_from": wheel_box.position.x / 20.0 - 1,
		"x_to": wheel_box.end.x / 20.0 + 1, "y_from": wheel_box.position.y / 8.0 - 1,
		"y_to": top / 8.0,
		"z_from": wheel_box.position.z / 20.0 - 1, "z_to": wheel_box.end.z / 20.0 + 1}
	var paint_wheel: Dictionary = {"recolor": [{"bricks": [wheel], "color": 1}],
		"room": room, "why": "the wheels should match the roof"}
	before = _shape(world)
	answer = str(await assistant.use_tool("edit_selection", paint_wheel))
	_ok(answer.begins_with("Not applied — the person did not give that room")
		and _shape(world) == before, "with nobody at the window to ask, it is refused")
	var asked: Array = []
	var answering: Array = [false]
	assistant.room_asked.connect(func(why: String, where: String) -> void:
		asked.append([why, where])
		assistant.answer_room.call_deferred(answering[0]))
	answer = str(await assistant.use_tool("edit_selection", paint_wheel))
	_ok(asked.size() == 1 and str(asked[0][0]) == "the wheels should match the roof",
		"the person is asked, with why")
	_ok(answer.begins_with("Not applied — the person did not give that room")
		and _shape(world) == before, "...says no, and nothing changes")
	answering[0] = true
	depth = builder.history_depth()
	answer = str(await assistant.use_tool("edit_selection", paint_wheel))
	_ok(world.get_brick(wheel).color_code == 1, "...says yes, and the wheel is painted: %s"
		% answer.get_slice("\n", 0).substr(0, 100))
	_ok(builder.history_depth() == depth + 1, "...as one undo step")

	print("")
	if _failures == 0:
		print("a change asked about a selection keeps to it")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


## A reply from the model, put through the loop as one would arrive.
func _reply(assistant: Assistant, content: Array) -> void:
	var body: String = JSON.stringify({"content": content, "stop_reason": "end_turn"})
	await assistant._on_response([HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), body.to_utf8_buffer()])


func _tool(name: String, input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "t%d" % randi(), "name": name, "input": input}


## What the last tool said, in words.
func _last_result(assistant: Assistant) -> String:
	return _text_of(assistant._messages.back())


func _text_of(message: Variant) -> String:
	var said := PackedStringArray()
	var content: Variant = (message as Dictionary).get("content")
	if typeof(content) == TYPE_STRING:
		return content
	for block: Variant in content:
		var one: Dictionary = block
		if one.get("type", "") == "text":
			said.append(str(one.get("text", "")))
		elif one.get("type", "") == "tool_result":
			var inner: Variant = one.get("content")
			if typeof(inner) == TYPE_STRING:
				said.append(inner)
			elif inner is Array:
				for piece: Variant in inner:
					if piece is Dictionary and (piece as Dictionary).get("type", "") == "text":
						said.append(str((piece as Dictionary).get("text", "")))
	return "\n".join(said)


## Every word in the panel's conversation.
func _text_of_panel(panel: ChatPanel) -> String:
	var said := PackedStringArray()
	for label: Node in panel._log.find_children("*", "Label", true, false):
		said.append((label as Label).text)
	return "\n".join(said)


## Every part: id -> part, colour and where it stands.
func _shape(world: BrickWorld) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		out[brick.id] = [brick.part_id, brick.color_code, brick.transform]
	return out


## Whether everything but [param except] is as it was in [param start].
func _same_but(world: BrickWorld, start: Dictionary, except: Array) -> bool:
	var now: Dictionary = _shape(world)
	for brick_id: int in start:
		if except.has(brick_id):
			continue
		if not now.has(brick_id) or str(now[brick_id]) != str(start[brick_id]):
			return false
	return now.size() == start.size()


## The same parts, colours and places as [param start], whatever their
## numbers: an undo puts a part taken off back under a new one.
func _same_values(world: BrickWorld, start: Dictionary) -> bool:
	var want: Array = []
	for value: Variant in start.values():
		want.append(str(value))
	var have: Array = []
	for value: Variant in _shape(world).values():
		have.append(str(value))
	want.sort()
	have.sort()
	return want == have


func _colours(world: BrickWorld, ids: Array) -> Array:
	var seen: Dictionary = {}
	for brick_id: int in ids:
		seen[world.get_brick(brick_id).color_code] = true
	return seen.keys()


func _named(world: BrickWorld, ids: Array) -> String:
	var said := PackedStringArray()
	for brick_id: int in ids:
		said.append("#%d %s" % [brick_id, world.get_brick(brick_id).part_id])
	return ", ".join(said)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
