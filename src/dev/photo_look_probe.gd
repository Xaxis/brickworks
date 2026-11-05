## Is a new design's first whole review set beside a photograph of the real
## thing, and is the photograph never a model built of bricks?
##
##   godot --path . --resolution 1400x900 --script src/dev/photo_look_probe.gd
##
## PhotoLook (src/ai/photo_look.gd): a connector chat's first whole review
## (review_model with no assembly) of a new design leads with the look in
## place of the rest of the review: a photograph of the real thing, the one
## the chat's own find_reference brought or, when it asked for none, one
## found for it with its own words for the subject (plan_scale's, the
## design's name, how_real_sets_build_this's, cleaned of a set's words); then
## the model from the view the photograph's title names (or the corner), the
## front and the side; then the question, answered with compare_with_photo. A
## subject with no photograph is told so. Every change but the answer, a
## save, a look at the model and another photograph is refused until it
## answers (twice at most); the answer is kept, and the review or save after
## it counts the parts added and taken off since. Once a subject; never
## beside the person's own model, never about a selection. Never a picture of
## anything built of bricks, by its title or by what Commons files it under;
## while a set is held out, find_reference drops those too. Commons is never
## asked here: the finder is the probe's. In a window, for the pictures.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _connector: ClaudeConnector
var _assistant: Assistant
var _finder: Finder
var _next: int = 0


## Commons, as the probe answers it: each search's pictures by its words.
class Finder extends ReferenceFinder:
	var asked := PackedStringArray()
	var answers: Dictionary = {}

	func look_for(subject: String) -> void:
		asked.append(subject)
		var got: Array = answers.get(subject, [])
		if got.is_empty():
			missed.emit("nothing on Wikimedia Commons matches \"%s\"" % subject)
		else:
			found.emit(got)


## Commons' search answered, nothing fetched: what would be.
class Searched extends ReferenceFinder:
	func _fetch_next() -> void:
		pass

	func kept() -> Array:
		return _pending


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_unit()
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
	_finder = Finder.new()
	_assistant._finder = _finder

	_served()
	await _its_own_photo("c1")
	await _found_for_it("c2")
	await _no_photo("c3")
	await _unanswered("c4")
	await _beside_a_model("c5")
	await _about_a_selection("c6")

	print("")
	print("photo look: the first whole review beside a photograph of the real thing, never "
		+ "one of bricks, once a subject" if _failures == 0
		else "photo look: %d FAILED" % _failures)
	_finder.free()
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## The words searched, the view matched, and the bricks kept out.
func _unit() -> void:
	print("── what is searched, which view, and nothing of bricks ──")
	_check("a set's words come off the subject: %s | %s" % [
		PhotoLook.cleaned("Burj Khalifa (LEGO Architecture style)"),
		PhotoLook.cleaned("Air Mail, in the style of LEGO® City sets: fitting in 20 x 23 studs")],
		PhotoLook.cleaned("Burj Khalifa (LEGO Architecture style)") == "Burj Khalifa"
		and PhotoLook.cleaned("Air Mail, in the style of LEGO® City sets: fitting in 20 x 23 "
			+ "studs") == "Air Mail")
	var asked: PackedStringArray = PhotoLook.queries({"plan_scale": "single drum road roller",
		"how_real_sets_build_this": "road roller"}, "Single drum road roller")
	_check("the real thing plan_scale sized first, then the kind, once each: %s"
		% ", ".join(asked), asked == PackedStringArray(["single drum road roller", "road roller"]))
	_check("a photograph's angle from its title, none when it names none: %s %s %s '%s'" % [
		PhotoLook.view_for("Hamm HD10 roller (front).jpg"),
		PhotoLook.view_for("1970 Dodge Charger side view.jpg"),
		PhotoLook.view_for("Burj Khalifa aerial view.jpg"),
		PhotoLook.view_for("Burj Khalifa from Safa Park.jpg")],
		PhotoLook.view_for("Hamm HD10 roller (front).jpg") == "front"
		and PhotoLook.view_for("1970 Dodge Charger side view.jpg") == "right"
		and PhotoLook.view_for("Burj Khalifa aerial view.jpg") == "top"
		and PhotoLook.view_for("Burj Khalifa from Safa Park.jpg").is_empty())
	_check("bricks by a title, or by what Commons files it under; Legolas is not LEGO",
		ReferenceFinder.of_lego("Lego Burj Khalifa.jpg", "")
		and ReferenceFinder.of_lego("A Wizard Is Never Late diorama.png",
			"The Lord of the Rings|Lego models of Middle-earth")
		and not ReferenceFinder.of_lego("Legolas at the gate.jpg", "Middle-earth")
		and not ReferenceFinder.of_lego("Horse cart.jpg", "Carts|Horses"))
	var lego: Dictionary = _picture("Lego lighthouse set.jpg", true)
	var real: Dictionary = _picture("Lighthouse on a cliff.jpg")
	_check("the look takes the first that is not of bricks",
		PhotoLook.first_of([lego, real]) == real and PhotoLook.first_of([lego]).is_empty())

	var pages: Dictionary = {"query": {"pages": [
		_page("File:A wizard arrives diorama.png", "Lego models of Middle-earth"),
		_page("File:Horse cart.jpg", "Carts")]}}
	var held: PackedStringArray = DesignMemory.held_out()
	DesignMemory.hold_out(PackedStringArray(["9469-1"]))
	var titles: PackedStringArray = _searched(pages)
	_check("while a set is held out, find_reference shows nothing of bricks: %s"
		% ", ".join(titles), titles == PackedStringArray(["Horse cart.jpg"]))
	DesignMemory.hold_out(PackedStringArray())
	titles = _searched(pages)
	_check("...and for a person, a builder's model comes back marked: %s" % ", ".join(titles),
		titles.size() == 2)
	DesignMemory.hold_out(held)


func _searched(pages: Dictionary) -> PackedStringArray:
	var commons := Searched.new()
	root.add_child(commons)
	var request := HTTPRequest.new()
	root.add_child(request)
	commons._on_searched(0, 200, PackedStringArray(), JSON.stringify(pages).to_utf8_buffer(),
		request)
	var out := PackedStringArray()
	for one: Dictionary in commons.kept():
		out.append("%s%s" % [one["title"], " (bricks)" if bool(one["lego"]) else ""])
	commons.queue_free()
	return out


func _served() -> void:
	print("\n── the answer, as a session is served it ──")
	var tool: Dictionary = _listed(PhotoLook.TOOL)
	_check("compare_with_photo is served, read-only, each feature photo against model: %s"
		% JSON.stringify(tool.get("inputSchema", {}).get("required", [])),
		not tool.is_empty() and bool(tool["annotations"].get("readOnlyHint", false))
		and tool["inputSchema"]["properties"]["features"]["items"]["required"]
			== ["name", "photo", "model", "settle", "why"])


## Its own find_reference: the first photograph not of bricks, beside the
## view its title names, the front and the side; nothing but the answer, a
## save, a look and another photograph goes ahead; the answer kept, and the
## rebuild counted at the review after it. Once a subject.
func _its_own_photo(chat: String) -> void:
	print("\n── its own photograph, beside the view its title names ──")
	await _call_as(chat, "clear_model", {})
	_finder.answers = {"red lighthouse": [_picture("Lego red lighthouse.jpg", true),
		_picture("Red lighthouse side view.jpg")]}
	await _call_as(chat, "find_reference", {"subject": "red lighthouse"})
	await _call_as(chat, "submit_design", _tower())
	var said: Array = await _call_as(chat, "review_model", {})
	var text: String = _text(said)
	_check("the first whole review leads with the look: %s" % text.left(70).replace("\n", " "),
		text.begins_with(PhotoLook.OPENING) and _look().waiting())
	_check("...in place of the rest of the review", not text.contains("The whole model:"))
	_check("...the photograph its find_reference brought, not the one of bricks: %s"
		% _line_with(text, "The real thing"), text.contains("The real thing, from your "
			+ "find_reference: Red lighthouse side view.jpg") and not text.contains("Lego red"))
	_check("...with the whole's size and its features: %s" % _line_with(text, "features you"),
		text.contains("Measured, in studs: the whole model is") and not text.contains(
			"Its massing") and text.contains("The features you named with the design: lantern."))
	var words: PackedStringArray = _captions(said)
	_check("...the photograph, then the side its title names, then the front: %s"
		% " | ".join(words.slice(1, 4)), _images(said) == 3 and words.size() == 5
		and words[1].begins_with("The real thing") and words[2] == "Yours from the side (from "
			+ "+x), the view its title names:" and words[3] == "Yours from the front "
			+ "(from +z):")
	_check("...each picture a PNG, the photograph its own bytes", _pngs(said)
		and _image_data(said, 0) == Marshalls.raw_to_base64(
			(_finder.answers["red lighthouse"][1] as Dictionary)["bytes"]))
	_check("...and the question last, to answer with compare_with_photo",
		words[4] == PhotoLook.ASK % PhotoLook.TOOL)
	_check("...no real set shown or named", not text.contains("omr")
		and not text.contains("real set"))
	var refused: String = _text(await _call_as(chat, "edit_model", {"remove": [_first_brick()]}))
	_check("an edit waits for the answer: %s" % refused.left(60), refused.begins_with("Not yet")
		and _parts() == 6)
	var looked: Array = await _call_as(chat, "view_model", {"from": "corner"})
	_check("...a look at the model goes ahead: %d picture" % _images(looked), _images(looked) == 1)
	var half: String = _text(await _call_as(chat, PhotoLook.TOOL, {"photo": "a red lighthouse",
		"is_it": true, "silhouette": "taller", "features": [{"name": "lantern",
			"photo": "a fifth of its height", "model": "two plates", "settle": "rebuild"}]}))
	_check("an answer with no why is asked in full: %s" % half.left(50),
		half.begins_with("Answer in full") and _look().waiting())
	var answer: String = _text(await _call_as(chat, PhotoLook.TOOL, {
		"photo": "a red and white lighthouse on a cliff, from the side", "is_it": true,
		"silhouette": "the photograph's tower is six times as tall as it is wide and tapers; "
			+ "mine is a straight stack three times as tall", "features": [
			{"name": "lantern", "photo": "a glass room a fifth of the height, as wide as the "
				+ "top", "model": "not there: the stack ends flat", "settle": "rebuild",
				"why": "it is what a lighthouse is known by"},
			{"name": "colour", "photo": "red", "model": "red", "settle": "keep",
				"why": "it matches"}]}))
	_check("the answer is kept, and what it settled to rebuild is to be rebuilt: %s"
		% answer.left(60), answer.begins_with("Now rebuild lantern") and not _look().waiting()
		and (_look().last["answer"]["features"] as Array).size() == 2)
	await _call_as(chat, "edit_model", {"add": [{"part": "3062b", "color": 47, "x": 10,
		"y": 18, "z": 10}]})
	var rest: String = _text(await _call_as(chat, "review_model", {}))
	_check("the next whole review is the review: %s" % rest.left(40),
		rest.begins_with("The whole model:") and not rest.contains(PhotoLook.OPENING))
	var rebuilt: Dictionary = _look().last.get("rebuilt", {})
	_check("...and the rebuild was counted there: %s" % JSON.stringify(rebuilt),
		int(rebuilt.get("added", -1)) == 1 and int(rebuilt.get("removed", -1)) == 0
		and int(rebuilt.get("kept", -1)) == 6)
	await _call_as(chat, "submit_design", _tower())
	rest = _text(await _call_as(chat, "review_model", {}))
	_check("...and a second design of the sitting is never looked at again",
		rest.begins_with("The whole model:"))


## No find_reference: one found with its own words, cleaned of the set's,
## the bricks passed over; a three-quarter view first when the title names
## no angle, said as no more than that. A photograph that is not the thing is
## said to be.
func _found_for_it(chat: String) -> void:
	print("\n── a chat that asked for no photograph ──")
	await _call_as(chat, "clear_model", {})
	_finder.asked = PackedStringArray()
	_finder.answers = {"Red Tower": [_picture("Red Tower Lego set.jpg", true),
		_picture("Red Tower from the park.jpg")]}
	await _call_as(chat, "plan_scale", {"subject": "Red Tower (LEGO Architecture style)",
		"longest_metres": 30})
	await _call_as(chat, "submit_design", _tower())
	var said: Array = await _call_as(chat, "review_model", {})
	var text: String = _text(said)
	var words: PackedStringArray = _captions(said)
	_check("one is found for it with its own words: %s" % ", ".join(_finder.asked),
		_finder.asked == PackedStringArray(["Red Tower"]) and text.contains("The real thing, "
			+ "found for you with \"Red Tower\": Red Tower from the park.jpg"))
	_check("...beside the corner, then the front and the side: %s" % " | ".join(words.slice(2, 5)),
		_images(said) == 4 and words[2] == "Yours from the corner (a three-quarter view, as "
			+ "most photographs are taken):"
		and words[3] == "Yours from the front (from +z):"
		and words[4] == "Yours from the side (from +x):")
	var answer: String = _text(await _call_as(chat, PhotoLook.TOOL, {"photo": "a brick church "
		+ "tower", "is_it": false, "silhouette": "not the thing", "features": [{"name": "spire",
			"photo": "none", "model": "none", "settle": "keep", "why": "not the thing"}]}))
	_check("none to rebuild, and the photograph not the thing: %s" % answer.right(70),
		answer.begins_with("Then each reads") and answer.contains("find_reference with its "
			+ "own name brings another"))


## No photograph anywhere: the look says so and what it searched, and asks
## all the same, against what it knows.
func _no_photo(chat: String) -> void:
	print("\n── a subject with no photograph ──")
	await _call_as(chat, "clear_model", {})
	_finder.asked = PackedStringArray()
	_finder.answers = {}
	await _call_as(chat, "plan_scale", {"subject": "a glorp", "longest_metres": 3})
	await _call_as(chat, "how_real_sets_build_this", {"subject": "space blob"})
	await _call_as(chat, "submit_design", _tower())
	var said: Array = await _call_as(chat, "review_model", {})
	var text: String = _text(said)
	_check("two searches, then the look says none came: %s" % _line_with(text, "No photograph"),
		_finder.asked == PackedStringArray(["a glorp", "A red tower"])
		and text.contains("No photograph of the real thing came back from Wikimedia Commons "
			+ "for \"a glorp\", \"A red tower\"") and _look().waiting())
	_check("...the model alone, from the corner, the front and the side: %d pictures"
		% _images(said), _images(said) == 3 and not text.contains("The real thing,")
		and not text.contains("its title names"))
	var answer: String = _text(await _call_as(chat, PhotoLook.TOOL, {"photo": "none",
		"is_it": false, "silhouette": "a blob is round; mine is square", "features": [{"name":
			"roundness", "photo": "none: from what I know, round", "model": "square",
			"settle": "rebuild", "why": "a blob is round"}]}))
	_check("...and answered all the same: %s" % answer.left(40), answer.begins_with(
		"Now rebuild roundness") and not answer.contains("photograph was not the thing"))


## Never answered: two changes refused, then they go ahead; or the model
## taken off to start again, which lets the look go.
func _unanswered(chat: String) -> void:
	print("\n── a look never answered ──")
	await _call_as(chat, "clear_model", {})
	_finder.answers = {}
	await _call_as(chat, "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	await _call_as(chat, "submit_design", _tower())
	await _call_as(chat, "review_model", {})
	var refused := PackedStringArray()
	for n: int in 3:
		refused.append(_text(await _call_as(chat, "edit_model", {"add": [{"part": "3024",
			"color": 4, "x": 10, "y": 18 + n, "z": 10}]})).left(20))
	_check("two edits refused, the third goes ahead: %s" % " | ".join(refused),
		refused[0].begins_with("Not yet") and refused[1].begins_with("Not yet")
		and not refused[2].begins_with("Not yet") and bool(_look().last.get("unanswered", false)))
	await _call_as("c4b", "clear_model", {})
	await _call_as("c4b", "plan_scale", {"subject": "a red tower", "longest_metres": 30})
	await _call_as("c4b", "submit_design", _tower())
	await _call_as("c4b", "review_model", {})
	var cleared: String = _text(await _call_as("c4b", "clear_model", {}))
	var again: String = _text(await _call_as("c4b", "submit_design", _tower()))
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
		PhotoLook.OPENING) and _look().last.is_empty())
	_assistant.unfocus()


func _look() -> PhotoLook:
	return _assistant.photo_look()


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
			"z_from": 10, "z_to": 12}], "features": [{"name": "lantern"}]}


## A picture as ReferenceFinder hands one over, a flat colour of its own.
static func _picture(title: String, lego: bool = false) -> Dictionary:
	var image := Image.create(96, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(0.8, 0.1, 0.1) if not lego else Color(0.9, 0.8, 0.1))
	image.set_pixel(1, 1, Color(float(title.length() % 7) / 7.0, 0.5, 0.5))
	return {"bytes": image.save_png_to_buffer(), "title": title, "credit": "Someone, CC BY 4.0",
		"lego": lego, "colours": {}}


static func _page(title: String, categories: String) -> Dictionary:
	return {"title": title, "imageinfo": [{"thumburl": "https://upload.example.invalid/%s"
		% title.trim_prefix("File:").uri_encode(), "extmetadata": {
			"Categories": {"value": categories}}}]}


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


## The answer's words, a block each.
static func _captions(blocks: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "text":
			out.append(str(block.get("text", "")))
	return out


static func _images(blocks: Array) -> int:
	var count: int = 0
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "image":
			count += 1
	return count


static func _image_data(blocks: Array, at: int) -> String:
	var seen: int = 0
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "image":
			if seen == at:
				return str(block.get("data", ""))
			seen += 1
	return ""


static func _pngs(blocks: Array) -> bool:
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "image" and (str(block.get("mimeType", "")) != "image/png"
				or Marshalls.base64_to_raw(str(block.get("data", ""))).size() < 60):
			return false
	return true


static func _line_with(text: String, word: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(word):
			return line.strip_edges().left(110)
	return "(none)"


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
