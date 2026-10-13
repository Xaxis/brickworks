## A design works its features one at a time, from how real sets built them.
##
##   godot --headless --path . --script src/dev/features_probe.gd
##
## The last held-out owl called find_techniques once, before building, and
## laid nothing from it: the rules said to look features up, and nothing in
## the loop asked. Now a submission lists what the subject is known by, the
## whole look is for the silhouette, and each feature comes back on its own
## with three real pieces and the worked technique that builds one; what
## the design used for each is recorded and said as the run ends. A session
## from outside gets the same through review_model's feature=, and saving
## hands back a feature never worked.
##
## Driven through the loop's own _on_response with replies written here, as
## detail_probe is, so it runs without the network. Needs the real-set index
## (tools/snippets.py build); says SKIP without it.
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
	if not RealSnippets.available():
		print("SKIP no real-set index at %s (tools/snippets.py build)" % RealSnippets.INDEX)
		quit(0)
		return
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

	print("\nthe worked technique for a feature is found by its words")
	_ok(str(Techniques.for_feature("eyes").get("name", "")) == "eye with a highlight",
		"eyes: the eye with a highlight")
	_ok(str(Techniques.for_feature("ear tufts").get("name", "")) == "ears or tufts",
		"ear tufts: ears or tufts")
	_ok(str(Techniques.for_feature("headlamps").get("name", "")) == "headlamps and grille",
		"headlamps: headlamps and grille")
	_ok(Techniques.for_feature("spoiler").is_empty(), "a spoiler has none, and none is made up")
	_ok(Assistant._subject_words("A barn owl as a detailed LEGO display model") == "owl",
		"a brief's subject is the word the index knows: \"%s\""
			% Assistant._subject_words("A barn owl as a detailed LEGO display model"))

	print("\nfind_techniques answers short, with a small picture")
	var answer: Variant = await assistant._find_techniques("owl eye", 0.0, [])
	var answer_text: String = str(answer if answer is String else (answer as Array)[0]["text"])
	var lines: int = answer_text.split("\n").size()
	print("    %d lines, %d characters" % [lines, answer_text.length()])
	_ok(answer_text.contains("1. ") and answer_text.contains("3. ")
		and not answer_text.contains("4. "), "three pieces, not five")
	_ok(answer_text.length() < 1600, "...in under 1,600 characters (%d)" % answer_text.length())

	# What _start does, without the request it ends in.
	assistant._busy = true
	assistant._brief = "A barn owl as a detailed LEGO display model"
	assistant._messages = [{"role": "user", "content": "a barn owl"}]

	print("\nthe silhouette is submitted, with the features it is known by")
	await _reply(assistant, [_tool("submit_design", {
		"name": "barn owl", "description": "a body on a base",
		"bricks": [{"part": "91405", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
			+ _stack(0, 3),
		"assemblies": [{"name": "owl", "x_from": 0, "x_to": 16, "z_from": 0, "z_to": 16}],
		"features": ["eyes", "beak", "Eyes"],
	})])
	var look: String = _text_of(assistant._messages.back())
	_ok(assistant._looked_back, "it holds, so it is looked at whole first")
	_ok(look.contains("silhouette and the proportions"), "...for its silhouette and proportions")
	_ok(look.contains("each feature you listed — eyes, beak —"),
		"...told each feature comes back on its own, a name said twice once")

	print("\nit approves the silhouette, and the eyes come back with real pieces")
	await _reply(assistant, [{"type": "text", "text": "The silhouette reads."}])
	var eyes: String = _text_of(assistant._messages.back())
	print("    " + eyes.substr(0, 900).replace("\n", "\n    "))
	_ok(eyes.contains("The eyes — feature 1 of 2"), "the eyes, as feature 1 of 2")
	_ok(eyes.contains("find_techniques \"owl eyes\""),
		"...looked up among sets about owls, under the subject's own word")
	_ok(eyes.contains("show_technique(\"eye with a highlight\")"),
		"...with the worked technique that builds one")
	_ok(_said("working the eyes (feature 1 of 2)"), "the progress line says which feature")
	var shown: Array = (assistant._messages.back() as Dictionary)["content"]
	var pictured: bool = false
	for block: Variant in shown:
		pictured = pictured or str((block as Dictionary).get("type", "")) == "image"
	print("    a picture of the pieces: %s (none where nothing can be drawn)" % pictured)
	var laid_id: String = ""
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^\\d\\. (\\S+) \"[^\"]*\", [^\\n]*lays as it stands").search(eyes)
	if found != null:
		laid_id = found.get_string(1)
	_ok(not laid_id.is_empty(), "one of them lays as it stands: %s" % laid_id)

	print("\nit lays that real piece on the base")
	var before: int = world.brick_count()
	await _reply(assistant, [_tool("place_technique", {"id": laid_id, "x": 6, "y": 1, "z": 6})])
	_ok(world.brick_count() > before, "the piece is built (%d parts to %d)"
		% [before, world.brick_count()])
	_ok(assistant._feature_said("eyes") == "real piece %s laid" % laid_id,
		"the eyes are recorded as that real piece: %s" % assistant._feature_said("eyes"))
	await _reply(assistant, [{"type": "text", "text": "Used the real eye %s." % laid_id}])
	_ok(_said("the eyes: real piece %s laid" % laid_id), "...and said when the eyes are done")
	var beak: String = _text_of(assistant._messages.back())
	_ok(beak.contains("The beak — feature 2 of 2"), "the beak comes next")
	_ok(beak.contains("show_technique(\"beak or snout\")"), "...with its worked technique")

	print("\nit builds the beak from the worked technique")
	await _reply(assistant, [_tool("show_technique", {"name": "beak or snout"})])
	await _reply(assistant, [_tool("edit_model", {"add": [
		{"part": "3794b", "color": 15, "x": 2, "y": 1, "z": 2, "rot": 0},
		{"part": "54200", "color": 19, "x": 2.5, "y": 2, "z": 2, "rot": 0}]})])
	await _reply(assistant, [{"type": "text", "text": "Built the beak from the technique."}])
	_ok(_said("the beak: built from the worked technique beak or snout"),
		"the beak is recorded as built from the technique")
	_ok(not ended.is_empty() and bool(ended[0][0]), "with nothing left to work, the run ends well")
	_ok(_said("features:\n  eyes: real piece %s laid\n  beak: built from the worked technique"
		% laid_id), "...saying what each feature came to")

	print("\nfrom outside: the features come with the build, and review_model works each")
	assistant._busy = false
	world.clear()
	builder.lattice.clear()
	var built: Variant = await assistant.use_tool("submit_design", {
		"name": "barn owl", "description": "a body on a base",
		"bricks": [{"part": "91405", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
			+ _stack(0, 3),
		"assemblies": [{"name": "owl", "x_from": 0, "x_to": 16, "z_from": 0, "z_to": 16}],
		"features": ["eyes", "beak"]})
	_ok(str(built).contains("each feature, one at a time (eyes, beak)"),
		"the build's answer says to work each feature, by name")
	var reviewed: String = await assistant.review("", "eyes")
	_ok(reviewed.contains("The eyes — feature 1 of 2") and reviewed.contains("place_technique"),
		"review_model feature=eyes: real pieces and what to do")
	_ok(reviewed.contains("Then review_model {\"feature\": \"beak\"}"), "...and which is next")
	await assistant.use_tool("place_technique", {"id": laid_id, "x": 6, "y": 1, "z": 6})
	_ok(assistant._feature_said("eyes") == "real piece %s laid" % laid_id,
		"a piece laid after it is the eyes' (%s)" % assistant._feature_said("eyes"))
	var handed: String = await assistant.next_review()
	_ok(handed.contains("The next is the beak") and handed.contains("The beak — feature 2 of 2"),
		"saving with the beak never worked hands the beak back")
	assistant._feature_now = ""
	await assistant.use_tool("find_techniques", {"query": "owl eyes"})
	_ok(assistant._feature_now == "eyes", "a lookup naming a listed feature is put down to it")
	var whole: String = await assistant.review("")
	_ok(whole.contains("Its features, each to work in turn") and whole.contains(
		"eyes: real piece %s laid" % laid_id), "the whole review lists what each feature came to")

	print("")
	if _failures == 0:
		print("OK features_probe")
	else:
		print("FAILED features_probe: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func _reply(assistant: Assistant, content: Array) -> void:
	var body: String = JSON.stringify({"content": content,
		"stop_reason": "end_turn"})
	await assistant._on_response([HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), body.to_utf8_buffer()])


func _tool(name: String, input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "t%d" % randi(), "name": name,
		"input": input}


## A column of 2x4 bricks standing on the base at x.
func _stack(x: int, high: int) -> Array:
	var out: Array = []
	for level: int in high:
		out.append({"part": "3001", "color": 71, "x": x, "y": 1 + level * 3,
			"z": 0, "rot": 0})
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
