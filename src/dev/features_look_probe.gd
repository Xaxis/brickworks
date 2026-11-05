## Are a design's defining features planned before it is built, and looked
## at in its own front and side at its first whole review?
##
##   godot --path . --resolution 1400x900 --script src/dev/features_look_probe.gd
##
## FeaturesLook (src/ai/features_look.gd): plan_features names the two or
## three features a subject is known by, each with its proportion against
## the whole and the technique its form needs, and how_real_sets_build_this
## asks for it until it is called. A connector chat's first whole review
## (review_model with no assembly) of a new design then leads with the look:
## the model from the front and the side, what was planned, and the question,
## in place of the rest of the review. Every change but the answer, a save
## and a look at the model is refused until features_look answers (twice at
## most), and the answer is kept; one most off is to be rebuilt, and the
## next whole review is the review. Clearing the model lets the look go.
## Once a subject: never at a second design
## of the sitting; a chat that planned nothing is asked to name them in the
## look, and one whose build had none of them yet is asked again at the
## next. A chat that designs beside a model already standing, and one about
## a selection, are reviewed as before. In a window, for the pictures.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _connector: ClaudeConnector
var _assistant: Assistant
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Its tower, six parts, stands for a design (Assistant.is_design).
	Assistant.design_parts = 1
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

	_served()
	await _planned_then_looked("c1")
	await _named_in_the_look("c2")
	await _unanswered("c3")
	await _beside_a_model("c4")
	await _about_a_selection("c5")

	print("")
	print("features look: planned before the first brick, looked at front and side at the "
		+ "first whole review, once a subject" if _failures == 0
		else "features look: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _served() -> void:
	print("── the two tools, as a session is served them ──")
	var plan: Dictionary = _listed(FeaturesLook.PLAN_TOOL)
	_check("plan_features is served, read-only, with each feature's proportion and "
		+ "technique: %s" % JSON.stringify(plan.get("inputSchema", {}).get("required", [])),
		not plan.is_empty() and bool(plan["annotations"].get("readOnlyHint", false))
		and plan["inputSchema"]["properties"]["features"]["items"]["required"]
			== ["name", "proportion", "technique"])
	var look: Dictionary = _listed(FeaturesLook.TOOL)
	_check("features_look is served, read-only, each feature real against seen: %s"
		% JSON.stringify(look.get("inputSchema", {}).get("required", [])),
		not look.is_empty() and bool(look["annotations"].get("readOnlyHint", false))
		and look["inputSchema"]["properties"]["features"]["items"]["required"]
			== ["name", "real", "seen", "off"])


## Planned after how_real_sets_build_this asks for it; the first whole review
## leads with the look, in place of the rest; nothing but the answer, a save
## and a look goes ahead until it answers; the answer is kept, and the next
## whole review is the review. Once a subject.
func _planned_then_looked(chat: String) -> void:
	print("\n── planned, then looked at, at the first whole review ──")
	await _call_as(chat, "clear_model", {})
	var how: String = _text(await _call_as(chat, "how_real_sets_build_this",
		{"subject": "lighthouse"}))
	_check("how_real_sets_build_this asks for the features next: %s"
		% _line_with(how, "plan_features"), how.ends_with(Assistant.PLAN_FEATURES_NEXT))
	var empty: String = _text(await _call_as(chat, "plan_features",
		{"subject": "a lighthouse", "features": [{"name": "lantern"}]}))
	_check("a feature with no proportion is not a plan: %s" % empty.left(70),
		empty.begins_with("Name the two or three") and _look().planned.is_empty())
	var planned: String = _text(await _call_as(chat, "plan_features", {"subject": "a lighthouse",
		"features": [{"name": "the lantern", "proportion": "as wide as the tower's top, a fifth "
			+ "of its height", "technique": "a body of revolution in trans-clear"},
			{"name": "the gallery", "proportion": "a stud wider than the tower all round",
				"technique": "plates with a rail"}]}))
	_check("plan_features says them back, each with its proportion and technique: %s"
		% _line_with(planned, "1."), planned.contains("1. the lantern: as wide as the tower's top")
		and planned.contains("built as a body of revolution") and planned.contains("2. the gallery")
		and planned.contains("front and its side") and _look().planned.size() == 2)
	how = _text(await _call_as(chat, "how_real_sets_build_this", {"subject": "lighthouse"}))
	_check("...and how_real_sets_build_this no longer asks", not how.contains("plan_features"))
	await _call_as(chat, "submit_design", _tower())
	var said: Array = await _call_as(chat, "review_model", {})
	var text: String = _text(said)
	_check("the first whole review leads with the look: %s" % text.left(80).replace("\n", " "),
		text.begins_with(FeaturesLook.OPENING) and bool(_look().waiting()))
	_check("...in place of the rest of the review", not text.contains("The whole model:"))
	_check("...with the whole's size and what was planned: %s" % _line_with(text, "Measured"),
		text.contains("Measured, in studs: the whole model is")
		and text.contains("What you planned, from the real thing:\n  1. the lantern"))
	var words := PackedStringArray()
	var pictures: int = 0
	for block: Dictionary in said:
		if block["type"] == "image":
			pictures += 1
			_check("  a picture of the model, %d bytes of PNG" % Marshalls.base64_to_raw(
				block["data"]).size(), Marshalls.base64_to_raw(block["data"]).size() > 1000
				and block["mimeType"] == "image/png")
		else:
			words.append(str(block["text"]))
	_check("...the front and the side: %s" % " | ".join(words.slice(1, 3)), pictures == 2
		and words.size() == 4 and words[1] == "The model from the front (from +z):"
		and words[2] == "The model from the side (from +x):")
	_check("...and the question last, to answer with features_look", words[3] == FeaturesLook.ASK
		% FeaturesLook.TOOL)
	_check("...no real set shown or named", not text.contains("omr")
		and not text.contains("real set"))
	var refused: String = _text(await _call_as(chat, "edit_model", {"remove": [_first_brick()]}))
	_check("an edit waits for the answer: %s" % refused.left(60), refused.begins_with("Not yet")
		and _parts() == 6)
	var looked: Array = await _call_as(chat, "view_model", {"from": "front"})
	_check("...a look at the model goes ahead: %d picture" % _images(looked), _images(looked) == 1)
	var half: String = _text(await _call_as(chat, "features_look", {"features": [{"name":
		"the lantern", "real": "a fifth of its height"}], "rebuild": ""}))
	_check("an answer with no seen is asked in full: %s" % half.left(50),
		half.begins_with("Answer in full") and bool(_look().waiting()))
	var answer: String = _text(await _call_as(chat, "features_look", {"features": [
		{"name": "the lantern", "real": "a fifth of its height, as wide as the top",
			"seen": "the top 2 of 18 plates, no wider than the tower", "off": true},
		{"name": "the gallery", "real": "a stud wider all round", "seen": "none", "off": true,
			"built": true}],
		"rebuild": "the lantern: 4 plates of trans-clear round bricks under a dome"}))
	_check("the answer is kept, and the one most off is to be rebuilt: %s" % answer.left(60),
		answer.begins_with("Now rebuild it") and not bool(_look().waiting())
		and (_look().last["features"] as Array).size() == 2
		and str(_look().last["rebuild"]).begins_with("the lantern"))
	var rest: String = _text(await _call_as(chat, "review_model", {}))
	_check("the next whole review is the review: %s" % rest.left(40),
		rest.begins_with("The whole model:") and not rest.contains(FeaturesLook.OPENING))
	await _call_as(chat, "submit_design", _tower())
	rest = _text(await _call_as(chat, "review_model", {}))
	_check("...and a second design of the sitting is never looked at again",
		rest.begins_with("The whole model:"))


## Nothing planned: the look asks for the features in its answer; a build
## with none of them yet is asked again at the next whole review.
func _named_in_the_look(chat: String) -> void:
	print("\n── a chat that planned nothing ──")
	await _call_as(chat, "clear_model", {})
	await _call_as(chat, "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	await _call_as(chat, "submit_design", _tower())
	var text: String = _text(await _call_as(chat, "review_model", {}))
	_check("the look asks it to name them now: %s" % _line_with(text, "planned none"),
		text.contains("You planned none with plan_features") and bool(_look().waiting()))
	var answer: String = _text(await _call_as(chat, "features_look", {"features": [
		{"name": "the battlements", "real": "a plate higher than the top, every other stud",
			"seen": "not built", "off": true, "built": false}], "rebuild": ""}))
	_check("a build with none of them yet is asked again: %s" % answer.left(50),
		answer.begins_with("None of them is built yet") and _look().planned.size() == 1)
	text = _text(await _call_as(chat, "review_model", {}))
	_check("...at the next whole review, with what it named: %s"
		% _line_with(text, "1. the battlements"), text.begins_with(FeaturesLook.OPENING)
		and text.contains("1. the battlements: a plate higher than the top"))
	answer = _text(await _call_as(chat, "features_look", {"features": [
		{"name": "the battlements", "real": "a plate higher than the top",
			"seen": "a plate higher than the top", "off": false}], "rebuild": ""}))
	_check("none off: on to the review: %s" % answer.left(50),
		answer.contains("review_model for the rest"))
	text = _text(await _call_as(chat, "review_model", {}))
	_check("...and it is never asked a third time", text.begins_with("The whole model:"))


## Never answered: two changes refused, then they go ahead; or the model
## taken off to start again, which lets the look go.
func _unanswered(chat: String) -> void:
	print("\n── a look never answered ──")
	await _call_as(chat, "clear_model", {})
	await _call_as(chat, "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	await _call_as(chat, "submit_design", _tower())
	await _call_as(chat, "review_model", {})
	var said := PackedStringArray()
	for _n: int in 3:
		said.append(_text(await _call_as(chat, "edit_model", {"add": [{"part": "3024",
			"color": 4, "x": 10, "y": 18 + _n, "z": 10}]})).left(20))
	_check("two edits refused, the third goes ahead: %s" % " | ".join(said),
		said[0].begins_with("Not yet") and said[1].begins_with("Not yet")
		and not said[2].begins_with("Not yet") and bool(_look().last.get("unanswered", false)))
	await _call_as("c3b", "clear_model", {})
	await _call_as("c3b", "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	await _call_as("c3b", "submit_design", _tower())
	await _call_as("c3b", "review_model", {})
	var cleared: String = _text(await _call_as("c3b", "clear_model", {}))
	var again: String = _text(await _call_as("c3b", "submit_design", _tower()))
	_check("taken off to start again, the look is let go: %s | %s" % [cleared.left(30),
		again.left(30)], not cleared.begins_with("Not yet") and again.begins_with("Built.")
		and bool(_look().last.get("unanswered", false)))


## Beside the person's own model: no look, the review as before.
func _beside_a_model(chat: String) -> void:
	print("\n── a chat designing beside the person's own model ──")
	await _call_as(chat, "clear_model", {})
	var theirs: int = _main.call("_open",
		_main.get_script().get_script_constant_map()["SAMPLE_MODEL"])
	(_main.get("_builder") as Builder).forget_history()
	await _call_as(chat, "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	await _call_as(chat, "submit_design", _tower())
	var text: String = _text(await _call_as(chat, "review_model", {}))
	_check("their model stands (%d parts) and the review is as before" % theirs,
		theirs > 0 and text.begins_with("The whole model:") and _look().last.is_empty())


## A chat about the person's selection: never looked at.
func _about_a_selection(chat: String) -> void:
	print("\n── a chat about a selection ──")
	await _call_as(chat, "clear_model", {})
	await _call_as(chat, "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	await _call_as(chat, "submit_design", _tower())
	_check("the person's selection is asked about",
		_assistant.focus_on([_first_brick()], true).is_empty() and _assistant.asked_about_selection())
	var text: String = _text(await _call_as(chat, "review_model", {}))
	_check("the review is as before: %s" % text.left(40), not text.begins_with(
		FeaturesLook.OPENING) and _look().last.is_empty())
	_assistant.unfocus()


func _look() -> FeaturesLook:
	return _assistant.features_look()


func _call_as(chat: String, tool: String, arguments: Dictionary) -> Array:
	_next += 1
	var request: Dictionary = {"jsonrpc": "2.0", "id": _next, "method": "tools/call",
		"params": {"name": tool, "arguments": arguments,
			"_meta": {"brickworks/chat": {"chat": chat, "since": "2026-11-05T06:00:00Z"}}}}
	var sitting: Dictionary = _connector._sitting(request)
	_connector._begin(sitting, tool, arguments)
	var answer: Variant = _connector._taught(sitting, tool,
		await _connector.rpc.answer_rpc(request))
	return ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []) as Array


func _tower() -> Dictionary:
	var bricks: Array = []
	for course: int in 6:
		bricks.append({"part": "3003", "color": 4, "x": 10, "y": 3 * course, "z": 10, "rot": 0})
	return {"name": "A red tower", "description": "a slender red tower", "floor": "none",
		"bricks": bricks, "assemblies": [{"name": "tower", "x_from": 10, "x_to": 12,
			"z_from": 10, "z_to": 12}]}


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


func _listed(name: String) -> Dictionary:
	for tool: Dictionary in _connector.rpc.served_tools():
		if tool["name"] == name:
			return tool
	return {}


static func _text(blocks: Array) -> String:
	var out := PackedStringArray()
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "text":
			out.append(str(block.get("text", "")))
	return "\n".join(out)


static func _images(blocks: Array) -> int:
	var count: int = 0
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "image":
			count += 1
	return count


static func _line_with(text: String, word: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(word):
			return line.strip_edges().left(110)
	return "(none)"


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
