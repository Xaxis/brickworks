## A finished model is detailed one assembly at a time.
##
##   godot --headless --path . --script src/dev/detail_probe.gd
##
## The one detailing pass a design got was the whole-model look, and that
## pass moved a castle from 20 shapes to 30 — but it framed a gatehouse,
## four towers and four walls in one picture and asked one question about
## all of them. Now each assembly the design names comes back to it close
## up, measured, with the parts real sets of its kind use that it lacks.
##
## Driven through the loop's own _on_response with replies written here,
## so the whole sequence runs without the network: a submission naming
## two assemblies, the whole look, each assembly in turn, and the end.
extends SceneTree


## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	var sent: int = 0

	func _send() -> void:
		sent += 1


var _failures: int = 0
var _notes: PackedStringArray = PackedStringArray()


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
	assistant.progress.connect(func(note: String) -> void: _notes.append(note))
	var ended: Array = []
	assistant.finished.connect(func(ok: bool, summary: String) -> void:
		ended.append([ok, summary]))
	await process_frame

	# What _start does, without the request it ends in.
	assistant._busy = true
	assistant._brief = "a medieval castle with a gatehouse and a tower"
	assistant._messages = [{"role": "user", "content": "a castle"}]

	print("\na castle is submitted, naming its gatehouse and its tower")
	await _reply(assistant, [_tool("submit_design", {
		"name": "castle", "description": "a gatehouse and a tower",
		"bricks": _stack(0, 4) + _stack(20, 6),
		"assemblies": [
			{"name": "gatehouse", "x_from": 0, "x_to": 8, "z_from": 0, "z_to": 4},
			{"name": "tower", "x_from": 18, "x_to": 26, "z_from": 0, "z_to": 4},
		],
	})])
	var look: String = _text_of(assistant._messages.back())
	_ok(assistant._looked_back, "it holds, so it is looked at whole first")
	_ok(look.contains("each of the 2 assemblies you named — gatehouse, tower"),
		"...and told both assemblies will come back to it on their own")
	_ok(assistant._to_detail.size() == 2, "two assemblies are waiting")

	print("\nit approves the whole, and the gatehouse comes back to it")
	# Forty of its forty-five turns gone, as a big design's are by now.
	assistant._turns = 40
	await _reply(assistant, [{"type": "text", "text": "The whole is right."}])
	var gatehouse: String = _text_of(assistant._messages.back())
	_ok(ended.is_empty(), "the run is not over")
	_ok(gatehouse.contains("The gatehouse: 4 parts, 1 shapes"),
		"the gatehouse is measured on its own, not the whole model")
	_ok(not gatehouse.contains("The tower"), "...and only the gatehouse")
	_ok(gatehouse.contains("Real tower and castle sets reach for these"),
		"it is told the parts of every kind the brief named that it lacks")
	_ok(gatehouse.contains("does it read as a gatehouse"),
		"and asked whether it reads as a gatehouse")
	_ok(_said("detailing the gatehouse (1 of 2): 4 parts"),
		"the progress line says where it is and what it is made of")
	_ok(assistant._turn_cap >= 40 + 2 * Assistant.TURNS_PER_ASSEMBLY,
		"a design forty turns in still has the turns both need (%d)"
			% assistant._turn_cap)

	print("\nit adds an arch to the gatehouse")
	var before: int = world.brick_count()
	await _reply(assistant, [_tool("edit_model", {"add": [
		{"part": "3659", "color": 71, "x": 0, "y": 12, "z": 0}]})])
	_ok(world.brick_count() == before + 1, "the edit is built")
	await _reply(assistant, [{"type": "text", "text": "Added an arch."}])
	_ok(_said("the gatehouse, detailed: 5 parts, 2 shapes"),
		"what the gatehouse came to is said when it is done")
	var tower: String = _text_of(assistant._messages.back())
	_ok(tower.contains("The tower: 6 parts"), "and the tower comes next")
	# Four towers were given "the same crown, so they match", and the
	# model's count of shapes barely moved for four passes.
	_ok(tower.contains("the gatehouse: 3659"),
		"told what the gatehouse brought, so it need not bring it again")
	_ok(tower.contains("nowhere in the model yet"),
		"...and which of the kind's parts the whole model still lacks")
	_ok(_said("detailing the tower (2 of 2)"), "...as the second of two")

	print("\na pass that keeps calling tools is moved on")
	for n: int in Assistant.TURNS_PER_ASSEMBLY:
		if assistant._detailing.is_empty():
			break
		await _reply(assistant, [_tool("search_parts", {"query": "arch"})])
	_ok(_said("out of turns for the tower"), "the tower runs out of turns")
	_ok(not ended.is_empty() and bool(ended[0][0]),
		"and with nothing left to detail the run ends well")
	_ok(_said("detailed 2 assemblies: from 10 parts"),
		"saying what the passes came to, from first to last")

	print("\na model that is one thing gets one look")
	_ok(Assistant._queue_assemblies([{"name": "lighthouse", "where": {}}]).is_empty(),
		"a single assembly is not looked at twice")
	var many: Array[Dictionary] = []
	for n: int in 20:
		many.append({"name": "bay %d" % n, "where": {}})
	_ok(Assistant._queue_assemblies(many).size() == Assistant.MOST_ASSEMBLIES,
		"and twenty are cut to %d" % Assistant.MOST_ASSEMBLIES)

	print("")
	if _failures == 0:
		print("a model is detailed one assembly at a time")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


## A reply from the model, put through the loop as one would arrive.
func _reply(assistant: Assistant, content: Array) -> void:
	var body: String = JSON.stringify({"content": content,
		"stop_reason": "end_turn"})
	await assistant._on_response([HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), body.to_utf8_buffer()])


func _tool(name: String, input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "t%d" % randi(), "name": name,
		"input": input}


## A column of 2x4 bricks standing on the ground at x.
func _stack(x: int, high: int) -> Array:
	var out: Array = []
	for level: int in high:
		out.append({"part": "3001", "color": 71, "x": x, "y": level * 3,
			"z": 0})
	return out


## All the words in a message, wherever they sit in it.
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
	return "\n".join(said)


func _said(start: String) -> bool:
	for note: String in _notes:
		if note.begins_with(start):
			return true
	return false


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
