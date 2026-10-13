## Sketch first: three cheap massings, one chosen, the design built from it.
##
##   godot --headless --path . --script src/dev/sketch_probe.gd
##   xvfb-run godot --path . --script src/dev/sketch_probe.gd -- --pictures=DIR
##
## A person learnt whether the brief was understood only after paying for a
## full design. Now a first design can begin with three sketches under 150
## parts, asked for in one turn on the cheaper model, each checked and
## pictured off the baseplate and shown as a card; the one chosen is put
## down and the whole model designed from it at the person's own model and
## effort, in a fresh conversation. Three that are one idea are sent back.
##
## Driven with a recorded brain (tests/fixtures/sketches/lighthouse.json,
## which the browser check answers with too): the loop's own _on_response
## fed replies written there, the request taken out, the panel's cards
## pressed as a person presses them. Then the same over MCP, through the
## command socket's tools/call: submit_design with sketch: true three
## times, the third answering with all three, and choose_sketch.
## With a display, --pictures=DIR keeps each sketch's picture.
extends SceneTree


## The loop with the request taken out, each request's body kept.
class Offline extends Assistant:
	var sent: int = 0
	var bodies: Array = []

	func _send() -> void:
		sent += 1
		_turns += 1
		bodies.append(request_body())


const FIXTURE := "res://tests/fixtures/sketches/lighthouse.json"

var _failures: int = 0
var _ready_with: Array = []
var _chosen: Array = []


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
	var panel := ChatPanel.new()
	root.add_child(panel)
	panel.bind(assistant)
	assistant.sketches_ready.connect(func(sketches: Array, model_id: String,
			tokens: Brain.Spend, ours: bool) -> void:
		_ready_with.append([sketches, model_id, tokens, ours]))
	assistant.sketch_chosen.connect(func(number: int) -> void: _chosen.append(number))
	await process_frame
	Brain.choose(Brain.DEFAULT_MODEL)
	Brain.set_effort("high")

	var recorded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var sketches: Array = recorded["sketches"]
	var brief: String = str(recorded["brief"])

	print("\nBuild it with Sketch first ticked asks for three, on the cheaper model")
	var kept_key: String = OwnKey._this_visit
	OwnKey._this_visit = "sk-ant-api03-probe-not-a-real-key-and-never-sent-anywhere"
	panel._show_for_key(true)
	_check(panel._sketch_first.visible and panel._sketch_first.button_pressed,
		"Sketch first is beside Build it, ticked, for a first design")
	panel._input.text = brief
	panel._on_send()
	OwnKey._this_visit = kept_key
	_check(assistant.sent == 1 and assistant._sketch_round, "Build it starts a sketch round")
	_check(panel._run != null and panel._run_title.text == "Sketching three ideas",
		"...on a card of its own")
	var first: Dictionary = assistant.bodies.back()
	_check(str(first["model"]) == Brain.SKETCH_MODEL
		and str((first.get("output_config", {}) as Dictionary).get("effort", "")) == "medium",
		"the sketches are asked of %s at %s, though Opus at high is chosen" % [
			first["model"], (first.get("output_config", {}) as Dictionary).get("effort", "")])
	var opening: String = _words(first["messages"][0])
	_check(opening.contains("call submit_design three times in this one reply")
		and opening.contains("under 150 parts") and opening.contains("different silhouette"),
		"the opening asks for three massings in one reply, and how they should differ")
	_check(_schema_has_sketch(first["tools"]), "submit_design takes sketch: true")
	_check(not _named(first["tools"], "choose_sketch"),
		"the loop is not offered choose_sketch: the person chooses")

	print("\na reply of three where two are one idea: the third is sent back")
	var before: int = world.brick_count()
	await _reply(assistant, [_tool(sketches[0]), _tool(sketches[1]),
		_tool(recorded["same_as_first"])], {"input_tokens": 3000,
			"cache_creation_input_tokens": 30000, "output_tokens": 2400})
	var asked: String = _words(assistant._messages.back())
	_check(assistant.sent == 2 and asked.contains("Sketches 1 and 3 are nearly the same idea"),
		"sketches 1 and 3 named as one idea, and another asked for")
	_check(_ready_with.is_empty(), "...and none is shown yet")
	_check(world.brick_count() == before, "nothing put on the baseplate (%d bricks)"
		% world.brick_count())

	print("\nthe third again, a different idea: three to choose from")
	await _reply(assistant, [_tool(sketches[2])], {"input_tokens": 2000,
		"cache_read_input_tokens": 30000, "output_tokens": 900})
	_check(_ready_with.size() == 1, "sketches_ready, once")
	if _ready_with.is_empty():
		_done()
		return
	var shown: Array = _ready_with[0][0]
	var spent: Brain.Spend = _ready_with[0][2]
	_check(shown.size() == 3 and bool(_ready_with[0][3]), "three, the app's own")
	_check(str(_ready_with[0][1]) == Brain.SKETCH_MODEL and spent.made == 3300
		and spent.total_in() == 65000, "what they cost is said: %s, %d in, %d out, %s" % [
			_ready_with[0][1], spent.total_in(), spent.made,
			Brain.in_money(Brain.cost(str(_ready_with[0][1]), spent))])
	var names := PackedStringArray()
	for one: Sketches.Sketch in shown:
		names.append("%d %s: %d parts, %s, %s" % [one.number, one.name, one.parts,
			one.measures(), "holds" if one.holds() else str(one.report.get("summary", ""))])
	print("    " + "\n    ".join(names))
	var all_hold: bool = true
	for one: Sketches.Sketch in shown:
		all_hold = all_hold and one.holds() and one.parts < Sketches.MOST_PARTS
	_check(all_hold, "each was checked, and holds, under 150 parts")
	_check(Sketches.alike_pairs(shown).is_empty(), "no two of them are one idea")
	_check(world.brick_count() == before and assistant.built_count() == 0,
		"none of them is on the baseplate")
	_check(not assistant.is_busy() and not assistant.has_conversation(),
		"the run is over and its conversation gone: choosing begins the design")
	if ModelShot.possible():
		var pictured: int = 0
		for one: Sketches.Sketch in shown:
			if one.picture != null and not ModelShot._is_blank(one.picture):
				pictured += 1
				_keep(one)
		_check(pictured == 3, "each pictured off the baseplate (%d)" % pictured)

	print("\nthe panel shows three cards, and says what the sketches cost")
	var cards: Node = panel._sketch_cards
	var card_count: int = 0
	if cards != null:
		for child: Node in cards.get_children():
			if child is PanelContainer:
				card_count += 1
	_check(card_count == 3 and panel._sketch_buttons.size() == 3,
		"three cards, each with its button (%d)" % card_count)
	_check(panel.controls_by_name().has("sketch_2"), "...named for a browser to press")
	_check(panel._log.get_children().any(func(n: Node) -> bool:
		return n is PanelContainer and _all_words(n).contains("The sketches cost")),
		"the run's card says what the sketches cost")
	_check(panel._sketch_first.visible and panel._sketch_first.button_pressed,
		"Sketch first stays on offer, ticked, for a fresh brief instead")

	print("\nchoosing the second puts it down and designs from it at the chosen model")
	var sent_before: int = assistant.sent
	panel._sketch_buttons[1].pressed.emit()
	for _n: int in 600:
		if assistant.sent > sent_before:
			break
		await process_frame
	var cottage: int = (sketches[1]["bricks"] as Array).size()
	_check(_chosen == [2], "sketch 2 chosen")
	_check(world.brick_count() - before == cottage and assistant.built_count() == cottage,
		"its %d parts stand on the baseplate (%d)" % [cottage, world.brick_count() - before])
	_check(assistant.held_sketches().is_empty(), "the other two are dropped")
	var next: Dictionary = assistant.bodies.back()
	_check(str(next["model"]) == Brain.DEFAULT_MODEL
		and str((next.get("output_config", {}) as Dictionary).get("effort", "")) == "high",
		"the design goes on at %s, %s" % [next["model"],
			(next.get("output_config", {}) as Dictionary).get("effort", "")])
	var from: String = _words(next["messages"][0])
	_check((next["messages"] as Array).size() == 1 and from.contains("the person chose sketch 2")
		and from.contains("Design the whole model from it now") and from.contains("3036"),
		"...in a fresh conversation, opening on the chosen sketch and its parts")
	_check(_all_words(cards.get_node("sketch_2")).contains("Chosen")
		and (cards.get_node("sketch_1") as Control).modulate.a < 0.9,
		"its card says Chosen, the others fade")
	_check(panel._run != null and panel._run_title.text == "Designing from sketch 2",
		"a run card for the design from it")

	print("\nthe whole model comes back, and the loop goes on as any design does")
	await _reply(assistant, [{"type": "tool_use", "id": "full", "name": "submit_design",
		"input": recorded["full"]}], {"input_tokens": 9000, "output_tokens": 4000})
	_check(assistant._looked_back and world.brick_count() - before
		== (recorded["full"]["bricks"] as Array).size(),
		"built, replacing the sketch, and looked at whole (%d bricks)"
			% (world.brick_count() - before))
	assistant.cancel()
	await process_frame

	print("\nover MCP: three sketches, the third answering with all three")
	world.clear()
	builder.lattice.clear()
	assistant.forget_built()
	_ready_with = []
	_chosen = []
	var socket := CommandSocket.new()
	socket.assistant = assistant
	root.add_child(socket)
	var listed: Dictionary = await socket.answer_rpc({"jsonrpc": "2.0", "id": 1,
		"method": "tools/list"})
	var tools: Array = listed["result"]["tools"]
	_check(_named(tools, "choose_sketch") and _schema_has_sketch(tools, "inputSchema"),
		"tools/list serves choose_sketch, and submit_design with sketch")
	var answers: Array = []
	for n: int in 3:
		answers.append(await _call(socket, "submit_design", sketches[n]))
	_check(_text(answers[0]).contains("Sketch 1 of 3 held, not built")
		and _text(answers[0]).contains("Now sketch 2"), "the first is held, and the second asked for")
	var third: String = _text(answers[2])
	_check(third.contains("Sketch 1, \"A slender tower on a rock\"")
		and third.contains("Sketch 3, \"A stepped tower on a wide pier\"")
		and third.contains("choose_sketch"), "the third answers with all three and how to choose")
	var images: int = 0
	for block: Dictionary in answers[2]:
		images += 1 if str(block.get("type", "")) == "image" else 0
	_check(images == 4 if ModelShot.possible() else third.count("Sketch ") >= 4,
		"...each as a picture (%d), or drawn in letters where nothing can draw" % images)
	_check(world.brick_count() == 0, "nothing on the baseplate yet")
	_check(_ready_with.size() == 1 and not bool(_ready_with[0][3]),
		"the panel is shown them as Claude's, to watch it choose")
	var big: Dictionary = (sketches[0] as Dictionary).duplicate(true)
	for k: int in 150:
		(big["bricks"] as Array).append({"part": "3005", "color": 4, "x": 40 + k % 10,
			"y": 1 + 3 * (k / 10), "z": 40, "rot": 0})
	_check(_text(await _call(socket, "submit_design", big)).begins_with("Not held — a sketch is massing only"),
		"a sketch of %d parts is refused" % (big["bricks"] as Array).size())
	var picked: String = _text(await _call(socket, "choose_sketch", {"sketch": 2}))
	_check(picked.contains("stands on the baseplate") and picked.contains("submit_design the whole model"),
		"choose_sketch puts the second down and says to design the whole from it")
	_check(world.brick_count() == cottage and _chosen == [2],
		"...and it stands, %d parts" % world.brick_count())
	_check(_text(await _call(socket, "choose_sketch", {"sketch": 1})).begins_with("There are no sketches"),
		"the other two are gone")
	_done()


func _reply(assistant: Assistant, content: Array, usage: Dictionary = {}) -> void:
	var body: String = JSON.stringify({"content": content, "stop_reason": "tool_use",
		"usage": usage})
	await assistant._on_response([HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), body.to_utf8_buffer()])


func _tool(input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "t%d" % randi(), "name": "submit_design",
		"input": input}


func _call(socket: CommandSocket, name: String, input: Dictionary) -> Array:
	var answer: Dictionary = await socket.answer_rpc({"jsonrpc": "2.0", "id": 2,
		"method": "tools/call", "params": {"name": name, "arguments": input}})
	return answer["result"]["content"]


func _text(content: Array) -> String:
	var said := PackedStringArray()
	for block: Dictionary in content:
		if str(block.get("type", "")) == "text":
			said.append(str(block.get("text", "")))
	return "\n".join(said)


func _named(tools: Array, name: String) -> bool:
	return tools.any(func(tool: Dictionary) -> bool: return str(tool.get("name", "")) == name)


func _schema_has_sketch(tools: Array, key: String = "input_schema") -> bool:
	for tool: Dictionary in tools:
		if str(tool.get("name", "")) == "submit_design":
			return ((tool[key] as Dictionary)["properties"] as Dictionary).has("sketch")
	return false


## All the words in a message, wherever they sit in it.
func _words(message: Variant) -> String:
	var content: Variant = (message as Dictionary).get("content")
	if typeof(content) == TYPE_STRING:
		return content
	var said := PackedStringArray()
	for block: Variant in content:
		var one: Dictionary = block
		if one.get("type", "") == "text":
			said.append(str(one.get("text", "")))
		elif one.get("type", "") == "tool_result":
			var inner: Variant = one.get("content")
			if typeof(inner) == TYPE_STRING:
				said.append(inner)
			elif inner is Array:
				for part: Variant in inner:
					said.append(str((part as Dictionary).get("text", "")))
	return "\n".join(said)


## Every label's words under a node.
func _all_words(node: Node) -> String:
	var said := PackedStringArray()
	for label: Node in node.find_children("*", "Label", true, false):
		said.append((label as Label).text)
	return "\n".join(said)


func _keep(one: Sketches.Sketch) -> void:
	var into: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pictures="):
			into = argument.substr(11)
	if not into.is_empty():
		DirAccess.make_dir_recursive_absolute(into)
		one.picture.save_png("%s/sketch_%d.png" % [into, one.number])


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("three sketches, the second chosen and designed from, in the app and over MCP")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
