## A design ends with a creative pass: touches proposed for its subject, the
## best added, small and joined.
##
##   godot --headless --path . --script src/dev/creative_probe.gd
##
## The bench's first batch scored creativity 4.0 of 10: a figure standing
## about, a blank nameplate, "nothing goes beyond the expected". The rules
## had asked for touches for weeks and no run acted on them, so the loop
## now hands the design a pass of its own once its features and assemblies
## have had theirs, and says what it added. A session from outside gets the
## same through review_model creative= and from saving.
##
## Driven through the loop's own _on_response with replies written here, as
## features_probe is, so it runs without the network.
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

	print("\na fresh design is owed a creative pass; a revision is not")
	_ok(assistant.design("A frog pond as a LEGO display model"), "the design starts")
	_ok(assistant._creative_wanted, "a fresh design: the pass is to come")
	assistant.cancel()
	await process_frame
	ended.clear()
	_ok(assistant.revise("make the water bluer"), "a revision starts")
	_ok(not assistant._creative_wanted, "a revision carries on: no pass of its own")
	assistant.cancel()
	await process_frame
	ended.clear()

	print("\nthe build stands and is looked at; then the creative pass comes back")
	_ok(assistant.design("A frog pond as a LEGO display model"), "the design starts again")
	await _reply(assistant, [_tool("submit_design", {
		"name": "frog pond", "description": "a pond on a base",
		"bricks": [{"part": "3001", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 2, "x": 0, "y": 3, "z": 0, "rot": 0}],
		"features": []})])
	_ok(assistant._looked_back, "it holds, so it is looked at whole first")
	var standing: int = world.brick_count()
	await _reply(assistant, [{"type": "text", "text": "It reads as a pond."}])
	var brief: String = _text_of(assistant._messages.back())
	print("    " + brief.substr(0, 700).replace("\n", "\n    "))
	_ok(ended.is_empty(), "the run has not ended: the pass is its last turn")
	_ok(brief.begins_with("The creative pass") and brief.contains("Propose three touches"),
		"the pass asks for three touches proposed")
	_ok(brief.contains("A story") and brief.contains("A play or display feature")
		and brief.contains("A nod"), "...of three kinds: a story, a play or display feature, a nod")
	_ok(brief.contains("\"A frog pond as a LEGO display model\""), "...for this subject, by its brief")
	_ok(brief.contains("joined to the model") and brief.contains("never changing its silhouette"),
		"...small and joined, never at the likeness's cost")
	_ok(brief.contains("What it has now: no figure, no creature, no printed part, "
		+ "nothing that hinges or turns."), "...with what the model has of touches already")
	_ok(brief.contains("\"lid or hatch raised on hinges\"") and brief.contains("\"small creature\"")
		and brief.contains("\"display stand with a nameplate\""),
		"...and the creative touches group's worked techniques by name")
	_ok(_said("the creative pass: proposing touches for it"), "the progress line says so")

	print("\nit proposes three and adds the best: a frog on a jumper, on the bank")
	await _reply(assistant, [
		{"type": "text", "text": "Story: a frog on the bank. Play: a lid on hinges over "
			+ "a fish hide. Nod: a printed lily pad. Adding the frog."},
		_tool("edit_model", {"add": [
			{"part": "3794b", "color": 2, "x": 0, "y": 6, "z": 0, "rot": 0},
			{"part": "33320", "color": 10, "x": 0.5, "y": 7, "z": 0, "rot": 0}]})])
	_ok(world.brick_count() == standing + 2, "the frog and its jumper are built (%d to %d)"
		% [standing, world.brick_count()])
	var report: Dictionary = await assistant._check(assistant._model_from_world())
	_ok(bool(report["ok"]), "...and the model with them holds as one: %s" % report["summary"])
	await _reply(assistant, [{"type": "text", "text": "Added a frog: a pond's own story."}])
	_ok(not ended.is_empty() and bool(ended[0][0]), "the pass said, the run ends well")
	_ok(_said("the creative pass: 2 parts added, new to the model: 3794b")
		and _said_with("33320 Animal Frog"), "...saying what the pass added: %s"
		% assistant._creative_record)

	print("\na pass that keeps calling tools gets its turns, and the run ends")
	ended.clear()
	world.clear()
	builder.lattice.clear()
	_ok(assistant.design("A small red house"), "a new design")
	await _reply(assistant, [_tool("submit_design", {
		"name": "house", "description": "a box",
		"bricks": [{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0}],
		"features": []})])
	await _reply(assistant, [{"type": "text", "text": "It reads."}])
	var calls: int = 0
	while ended.is_empty() and calls < Assistant.TURNS_FOR_TOUCHES + 2:
		calls += 1
		await _reply(assistant, [_tool("search_parts", {"query": "animal frog"})])
	_ok(calls == Assistant.TURNS_FOR_TOUCHES, "it ends after %d calls (%d allowed)"
		% [calls, Assistant.TURNS_FOR_TOUCHES])
	_ok(not ended.is_empty() and bool(ended[0][0]), "...as a finished design")
	_ok(_said("out of turns for the creative touches") and _said("the creative pass: nothing added"),
		"...saying the pass ran out of turns and added nothing")

	print("\nfrom outside: the build's answer, review_model creative=, and saving")
	assistant._busy = false
	ended.clear()
	world.clear()
	builder.lattice.clear()
	var built: Variant = await assistant.use_tool("submit_design", {
		"name": "frog pond", "description": "a pond on a base",
		"bricks": [{"part": "3001", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 2, "x": 0, "y": 3, "z": 0, "rot": 0}],
		"features": []})
	_ok(str(built).contains("the creative pass, last: review_model {\"creative\": true}"),
		"the build's answer names the creative pass as the last step")
	var whole: String = await assistant.review("")
	_ok(whole.contains("Last, the creative pass"), "the whole review ends on it")
	var handed: String = await assistant.next_review()
	_ok(handed.begins_with("Before it is finished: the creative pass")
		and handed.contains("Propose three touches"),
		"saving with nothing else left hands the creative pass")
	await assistant.use_tool("edit_model", {"add": [
		{"part": "3794b", "color": 2, "x": 0, "y": 6, "z": 0, "rot": 0},
		{"part": "33320", "color": 10, "x": 0.5, "y": 7, "z": 0, "rot": 0}]})
	var after: String = await assistant.next_review()
	_ok(after.begins_with("The creative pass: 2 parts added"),
		"saving after it says what the pass added: %s" % after)
	_ok((await assistant.next_review()).is_empty(), "...and then saving only saves")
	var asked: String = await assistant.review("", "", true)
	_ok(asked.begins_with("The creative pass") and asked.contains("1 creature"),
		"review_model creative= hands it again, seeing the frog now")

	print("\nfrom outside, the pass worked before the features is still said")
	# Three of four bench sessions called it before their features; the save
	# that handed the next feature never said what the pass had added.
	world.clear()
	builder.lattice.clear()
	await assistant.use_tool("submit_design", {
		"name": "frog pond", "description": "a pond on a base",
		"bricks": [{"part": "3001", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 2, "x": 0, "y": 3, "z": 0, "rot": 0}],
		"features": ["lily pads"]})
	await assistant.review("", "", true)
	await assistant.use_tool("edit_model", {"add": [
		{"part": "3794b", "color": 2, "x": 0, "y": 6, "z": 0, "rot": 0},
		{"part": "33320", "color": 10, "x": 0.5, "y": 7, "z": 0, "rot": 0}]})
	var early: String = await assistant.next_review()
	_ok(early.begins_with("The creative pass: 2 parts added")
		and early.contains("The next is the lily pads"),
		"saving says what the pass added, then hands the feature still waiting")

	print("")
	if _failures == 0:
		print("OK creative_probe")
	else:
		print("FAILED creative_probe: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func _reply(assistant: Assistant, content: Array) -> void:
	var body: String = JSON.stringify({"content": content,
		"stop_reason": "end_turn"})
	await assistant._on_response([HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), body.to_utf8_buffer()])


func _tool(name: String, input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "t%d" % randi(), "name": name,
		"input": input}


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


func _said_with(part: String) -> bool:
	for note: String in _notes:
		if note.begins_with("the creative pass") and note.contains(part):
			return true
	return false


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
