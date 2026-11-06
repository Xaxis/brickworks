## Is a new design measured against a photograph of the real thing, found
## with the session's own name for it, and is the photograph never a model
## built of bricks?
##
##   godot --path . --resolution 1400x900 --script src/dev/photo_look_probe.gd
##
## PhotoLook (src/ai/photo_look.gd): a connector chat's first whole review
## (review_model with no assembly) of a new design leads with the look, in
## steps, each answered with compare_with_photo:
## 1. name: the real thing's own name (make and model), or "none" (the look
##    ends);
## 2. find: the next whole review shows the photograph found with those words
##    only (the chat's own find_reference's when it searched the same words;
##    never one of bricks), beside the model from the view its title names
##    (or the corner), the front and the side, and asks the shares, with the
##    axes but none of the model's numbers; none found, said so;
## 3. read: is_it false ends the look; else the whole's and each feature's
##    length, width and height as shares, each feature with its box; the app
##    measures the same off the model (the parts whose middle is in the box)
##    and sets them side by side, marking each more than a quarter off and a
##    stud or more;
## 4. settle: each over the line rebuild or keep; rebuilds told their sizes;
## 5. again: the rebuilt measured in their boxes now, beside the photograph's
##    and what they were, the parts moved counted; the next whole review asks
##    once if it was not given.
## Every change but the answer, a save, a look at the model and another
## photograph is refused while name, read or settle waits (twice at most);
## clear_model lets it go. Once a subject; never beside the person's own
## model, never about a selection. While a set is held out, find_reference
## drops every picture of bricks too. Commons is never asked here: the
## finder is the probe's. In a window, for the pictures.
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
	await _measured_and_rebuilt("c1")
	await _asked_again("c2")
	await _named_none("c3")
	await _not_the_thing("c4")
	await _no_photo("c5")
	await _not_drawn("c7")
	await _unanswered("c6")
	await _beside_a_model("c8")
	await _about_a_selection("c9")

	print("")
	print("photo look: the first whole review measured against a photograph found with the "
		+ "session's own name for the thing, never one of bricks, once a subject"
		if _failures == 0 else "photo look: %d FAILED" % _failures)
	_finder.free()
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## The words searched, the view matched, the shares read and measured, the
## line, and the bricks kept out.
func _unit() -> void:
	print("── what is searched, which view, the shares, and nothing of bricks ──")
	_check("a set's words come off: %s | %s" % [
		PhotoLook.cleaned("Burj Khalifa (LEGO Architecture style)"),
		PhotoLook.cleaned("Air Mail, in the style of LEGO® City sets: fitting in 20 x 23 studs")],
		PhotoLook.cleaned("Burj Khalifa (LEGO Architecture style)") == "Burj Khalifa"
		and PhotoLook.cleaned("Air Mail, in the style of LEGO® City sets: fitting in 20 x 23 "
			+ "studs") == "Air Mail")
	var asked: PackedStringArray = PhotoLook.queries("a Hamm HD 10 tandem roller, such as "
		+ "councils use")
	_check("its own name, then the name alone: %s" % " | ".join(asked),
		asked == PackedStringArray(["a Hamm HD 10 tandem roller, such as councils use",
			"Hamm HD 10 tandem roller"]))
	_check("...and a plain name searched once: %s" % " | ".join(PhotoLook.queries(
		"Eiffel Tower")), PhotoLook.queries("Eiffel Tower") == PackedStringArray(
			["Eiffel Tower"]) and PhotoLook.queries("").is_empty())
	_check("none said: none, None., n/a; a name is not", PhotoLook.none_said("none")
		and PhotoLook.none_said("None.") and PhotoLook.none_said("n/a")
		and not PhotoLook.none_said("Nonesuch Palace"))
	_check("a photograph's angle from its title, none when it names none: %s %s %s '%s'" % [
		PhotoLook.view_for("Hamm HD10 roller (front).jpg"),
		PhotoLook.view_for("1970 Dodge Charger side view.jpg"),
		PhotoLook.view_for("Burj Khalifa aerial view.jpg"),
		PhotoLook.view_for("Burj Khalifa from Safa Park.jpg")],
		PhotoLook.view_for("Hamm HD10 roller (front).jpg") == "front"
		and PhotoLook.view_for("1970 Dodge Charger side view.jpg") == "right"
		and PhotoLook.view_for("Burj Khalifa aerial view.jpg") == "top"
		and PhotoLook.view_for("Burj Khalifa from Safa Park.jpg").is_empty())
	_check("shares as fractions or percentages; a dimension left out is not there: %s"
		% JSON.stringify(PhotoLook.shares_of({"length": 0.3, "width": "40%", "height": 55})),
		PhotoLook.shares_of({"length": 0.3, "width": "40%", "height": 55})
			== {"length": 0.3, "width": 0.4, "height": 0.55}
		and PhotoLook.shares_of({"length": 0.3}) == {"length": 0.3}
		and PhotoLook.shares_of("tall").is_empty())
	# A machine 25 studs long, 10 wide, 30 plates (12 studs) high: its drum 4
	# studs of the length, the photograph's 30%.
	var whole := Vector3(25, 30, 10)
	var shares: Dictionary = PhotoLook.whole_shares(whole)
	_check("the whole's shares, of its longest, height in plates: %s" % JSON.stringify(shares),
		is_equal_approx(float(shares["length"]), 1.0) and is_equal_approx(float(shares["width"]),
			0.4) and is_equal_approx(float(shares["height"]), 0.48))
	var drum: Dictionary = PhotoLook.feature_shares({"count": 9, "size": Vector3(4, 12, 10)},
		whole)
	_check("a feature's shares of the whole's: %s" % JSON.stringify(drum),
		is_equal_approx(float(drum["length"]), 0.16) and is_equal_approx(float(drum["width"]),
			1.0) and is_equal_approx(float(drum["height"]), 0.4))
	var along_z: Dictionary = PhotoLook.feature_shares({"count": 1, "size": Vector3(10, 3, 4)},
		Vector3(10, 30, 25))
	_check("...the length the longer way across the ground, x or z: %s"
		% JSON.stringify(along_z), is_equal_approx(float(along_z["length"]), 0.16)
		and is_equal_approx(float(along_z["width"]), 1.0))
	var rows: Array[Dictionary] = [{"name": "drum", "photo": {"length": 0.3, "width": 0.9,
		"height": 0.47}, "model": drum}, {"name": "lamp", "photo": {"length": 0.06},
		"model": {"length": 0.04}}]
	var offs: Array[Dictionary] = PhotoLook.offs_of(rows, whole)
	var said := PackedStringArray()
	for off: Dictionary in offs:
		said.append("%s %s" % [off["name"], off["dimension"]])
	_check("over the line: more than a quarter off and a stud or more: %s" % ", ".join(said),
		said == PackedStringArray(["drum length"]))
	var table: String = PhotoLook.table(rows, offs, whole)
	_check("...marked in the table, with the photograph's share as a size: %s"
		% _line_with(table, "| drum"), table.contains("**30%, yours 16%: off**, the "
			+ "photograph's is 7.5 studs") and table.contains("90%, yours 100%")
		and table.contains("47%, yours 40%") and not table.contains("6%, yours 4%: off"))
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
	var properties: Dictionary = tool.get("inputSchema", {}).get("properties", {})
	_check("compare_with_photo is served, read-only, a step a field: %s"
		% ", ".join(properties.keys()), not tool.is_empty()
		and bool(tool["annotations"].get("readOnlyHint", false))
		and properties.keys() == ["real_thing", "photo", "is_it", "whole", "features", "settled",
			"again"]
		and properties["features"]["items"]["required"] == ["name", "where"])


## The whole way: the name asked; the session's own find_reference shown
## (searched with the same words), not the one of bricks, beside the side its
## title names; the shares read, measured, one over the line; settled
## rebuild; rebuilt; measured again and within; the next review the review.
func _measured_and_rebuilt(chat: String) -> void:
	print("\n── named, shown, read, measured, settled, rebuilt, measured again ──")
	await _call_as(chat, "clear_model", {})
	_finder.asked = PackedStringArray()
	_finder.answers = {"red lighthouse": [_picture("Lego red lighthouse.jpg", true),
		_picture("Red lighthouse side view.jpg")]}
	await _call_as(chat, "find_reference", {"subject": "red lighthouse"})
	await _call_as(chat, "submit_design", _tower())
	var text: String = _text(await _call_as(chat, "review_model", {}))
	_check("the first whole review asks the real thing's own name: %s"
		% text.left(60).replace("\n", " "), text.begins_with(PhotoLook.OPENING)
		and text.contains(PhotoLook.ASK_NAME % PhotoLook.TOOL) and _look().step() == "name"
		and text.contains("The features you named with the design: lantern."))
	_check("...in place of the rest of the review, and no picture yet",
		not text.contains("The whole model:"))
	var refused: String = _text(await _call_as(chat, "edit_model", {"remove": [_first_brick()]}))
	_check("an edit waits for the name: %s" % refused.left(60), refused.begins_with("Not yet")
		and refused.contains("real_thing") and _parts() == 6)
	var named: String = _text(await _call_as(chat, PhotoLook.TOOL, {"real_thing":
		"Red lighthouse"}))
	_check("named, it is sent to the review: %s" % named.left(60),
		named.begins_with("Now review_model") and _look().step() == "find")
	var said: Array = await _call_as(chat, "review_model", {})
	text = _text(said)
	var words: PackedStringArray = _captions(said)
	_check("...which shows its own find_reference's photograph, the same words, not the one "
		+ "of bricks, nothing searched again: %s" % words[0].left(80), words[0].begins_with(
			"The real thing, from your find_reference: Red lighthouse side view.jpg")
		and not text.contains("Lego red") and _finder.asked == PackedStringArray(
			["red lighthouse"]) and _look().step() == "read")
	_check("...the photograph, then the side its title names, the front, the corner none: %s"
		% " | ".join(words.slice(1, 3)), _images(said) == 3 and words.size() == 4
		and words[1] == "Yours from the side (from +x), the view its title names:"
		and words[2] == "Yours from the front (from +z):")
	_check("...each picture a PNG, the photograph its own bytes", _pngs(said)
		and _image_data(said, 0) == Marshalls.raw_to_base64(
			(_finder.answers["red lighthouse"][1] as Dictionary)["bytes"]))
	_check("...and the shares asked last, the axes said but none of the model's numbers: %s"
		% _line_with(text, "length runs"), words[3].begins_with("Read the photograph first")
		and text.contains("In your model the length runs along x, the width along z, and the "
			+ "height up.") and not text.contains("studs long") and not text.contains("Measured"))
	refused = _text(await _call_as(chat, "edit_model", {"remove": [_first_brick()]}))
	_check("an edit waits for the shares: %s" % refused.left(50), refused.begins_with("Not yet")
		and _parts() == 6)
	var half: String = _text(await _call_as(chat, PhotoLook.TOOL, {"photo": "a lighthouse",
		"is_it": true, "whole": {"height": 1}, "features": [{"name": "lantern", "height": 0.4}]}))
	_check("an answer with no box and one share of the whole is asked in full: %s"
		% half.left(40), half.begins_with("Answer in full") and _look().step() == "read")
	# The tower: 2 x 2 studs, 18 plates. Its lantern the top brick, 3 plates:
	# a sixth of the height to the photograph's 0.4, off; as long as the
	# whole to the photograph's 0.6, but less than a stud from it, so not.
	var table: String = _text(await _call_as(chat, PhotoLook.TOOL, {
		"photo": "a red lighthouse on a cliff, from the side", "is_it": true,
		"whole": {"length": 0.3, "width": 0.3, "height": 1},
		"features": [
			{"name": "lantern", "where": {"y_from": 15, "y_to": 18}, "length": 0.6, "width": 0.6,
				"height": 0.4},
			{"name": "plinth", "where": {"y_from": 0, "y_to": 3}, "height": 0.15},
			{"name": "gallery", "where": {"x_from": 40, "x_to": 44}, "height": 0.05}]}))
	_check("the shares measured beside the photograph's: %s" % _line_with(table, "| lantern"),
		table.contains("| lantern (1 part) | 60%, yours 100% | 60%, yours 100% | **40%, yours "
			+ "17%: off**, the photograph's is 7 plates |")
		and table.contains("| the whole, of its longest | 30%, yours 28% | 30%, yours 28% | "
			+ "100%, yours 100% |") and table.contains("| plinth (1 part) | — | — | 15%, yours "
			+ "17% |"))
	_check("...a box with no part in it said so, the whole's size said after: %s"
		% _line_with(table, "No part"), table.contains("No part of yours has its middle inside "
			+ "the box given for gallery") and table.contains("Your whole: 2 studs long, 2 wide, "
			+ "18 plates high.") and table.contains(PhotoLook.ASK_SETTLE % PhotoLook.TOOL)
		and _look().step() == "settle" and _look().off_names() == PackedStringArray(["lantern"]))
	refused = _text(await _call_as(chat, "edit_model", {"remove": [_first_brick()]}))
	_check("an edit waits for the settling: %s" % refused.left(50),
		refused.begins_with("Not yet") and _parts() == 6)
	var open: String = _text(await _call_as(chat, PhotoLook.TOOL, {"settled": []}))
	_check("each over the line must be settled: %s" % open, open == "Settle each over the "
		+ "line: lantern, each rebuild or keep, and why.")
	var settled: String = _text(await _call_as(chat, PhotoLook.TOOL, {"settled": [{"name":
		"Lantern", "settle": "rebuild", "why": "the lantern is what it is known by"}]}))
	_check("settled rebuild, told its size: %s" % settled.left(110), settled.begins_with(
		"Now rebuild Lantern, the most different first and before any detail, to these: "
		+ "Lantern: height 7 plates (3 plates now).") and _look().step() == "rebuild")
	var added: String = _text(await _call_as(chat, "edit_model", {"add": [
		{"part": "3003", "color": 47, "x": 10, "y": 18, "z": 10},
		{"part": "3003", "color": 47, "x": 10, "y": 21, "z": 10}]}))
	_check("the rebuild goes ahead: %s" % added.left(40), not added.begins_with("Not yet")
		and _parts() == 8)
	var again: String = _text(await _call_as(chat, PhotoLook.TOOL, {"again": [{"name":
		"lantern", "where": {"y_from": 15, "y_to": 24}}]}))
	var rebuilt: Dictionary = _look().last.get("rebuilt", {})
	_check("measured again, beside the photograph and what it was: %s"
		% _line_with(again, "| lantern"), again.contains("| lantern (3 parts) | 60%, yours "
			+ "100% (was 100%) | 60%, yours 100% (was 100%) | 40%, yours 38% (was 17%) |")
		and again.contains("Each is now within a quarter") and _look().step() == "done")
	_check("...and the rebuild counted: %s" % JSON.stringify(rebuilt),
		int(rebuilt.get("added", -1)) == 2 and int(rebuilt.get("removed", -1)) == 0
		and int(rebuilt.get("kept", -1)) == 6)
	var rest: String = _text(await _call_as(chat, "review_model", {}))
	_check("the next whole review is the review: %s" % rest.left(40),
		rest.begins_with("The whole model:"))
	await _call_as(chat, "submit_design", _tower())
	rest = _text(await _call_as(chat, "review_model", {}))
	_check("...and a second design of the sitting is never looked at again",
		rest.begins_with("The whole model:"))


## Rebuilt and never measured again: the next whole review asks it once,
## then the review goes on. A photograph found with its own name, the one
## of bricks passed over; the corner first when its title names no angle.
func _asked_again(chat: String) -> void:
	print("\n── rebuilt, and the next review asks it measured again ──")
	await _call_as(chat, "clear_model", {})
	_finder.asked = PackedStringArray()
	_finder.answers = {"Red Rock Light": [_picture("Red Rock Light Lego set.jpg", true),
		_picture("Red Rock Light from the bay.jpg")]}
	await _call_as(chat, "plan_scale", {"subject": "Red Tower (LEGO Architecture style)",
		"longest_metres": 30})
	await _call_as(chat, "submit_design", _tower())
	await _call_as(chat, "review_model", {})
	await _call_as(chat, PhotoLook.TOOL, {"real_thing": "Red Rock Light"})
	var said: Array = await _call_as(chat, "review_model", {})
	var words: PackedStringArray = _captions(said)
	_check("searched with its own name only, never its design's or plan_scale's: %s"
		% ", ".join(_finder.asked), _finder.asked == PackedStringArray(["Red Rock Light"])
		and words[0].begins_with("The real thing, found for you with \"Red Rock Light\": Red "
			+ "Rock Light from the bay.jpg"))
	_check("...beside the corner, then the front and the side: %s" % " | ".join(words.slice(1, 4)),
		_images(said) == 4 and words[1] == "Yours from the corner (a three-quarter view, as "
			+ "most photographs are taken):" and words[2] == "Yours from the front (from +z):"
		and words[3] == "Yours from the side (from +x):")
	await _call_as(chat, PhotoLook.TOOL, {"photo": "a lighthouse", "is_it": true,
		"whole": {"length": 0.3, "height": 1}, "features": [{"name": "lantern", "where":
			{"y_from": 15}, "height": 0.4}]})
	await _call_as(chat, PhotoLook.TOOL, {"settled": [{"name": "lantern", "settle": "rebuild",
		"why": "too short"}]})
	await _call_as(chat, "edit_model", {"add": [{"part": "3022", "color": 47, "x": 10, "y": 18,
		"z": 10}]})
	var asked: String = _text(await _call_as(chat, "review_model", {}))
	_check("the next whole review asks the rebuilt measured again: %s" % asked.left(60),
		asked.begins_with(PhotoLook.ASK_AGAIN % [PhotoLook.TOOL, "lantern"])
		and _look().step() == "again"
		and int((_look().last.get("rebuilt", {}) as Dictionary).get("added", -1)) == 1)
	var still: String = _text(await _call_as(chat, PhotoLook.TOOL, {"again": [{"name": "lantern",
		"where": {"y_from": 15}}]}))
	_check("...and measured, still short of it, said so: %s" % _line_with(still, "Still"),
		still.contains("**40%, yours 21% (was 17%): off**") and still.contains("Still over the "
			+ "line: lantern's height.") and _look().step() == "done")
	var rest: String = _text(await _call_as(chat, "review_model", {}))
	_check("...then the review: %s" % rest.left(40), rest.begins_with("The whole model:"))


## Nothing real to it: "none", and the look ends; the review goes on.
func _named_none(chat: String) -> void:
	print("\n── a subject with no real counterpart ──")
	await _call_as(chat, "clear_model", {})
	_finder.asked = PackedStringArray()
	await _call_as(chat, "submit_design", _tower())
	await _call_as(chat, "review_model", {})
	var none: String = _text(await _call_as(chat, PhotoLook.TOOL, {"real_thing": "none"}))
	var rest: String = _text(await _call_as(chat, "review_model", {}))
	_check("none, nothing searched, and the review: %s | %s" % [none.left(40), rest.left(30)],
		none.begins_with("Then there is no photograph") and _finder.asked.is_empty()
		and rest.begins_with("The whole model:") and _look().step() == "done")


## A photograph that is not the thing: said so, and none to measure against.
func _not_the_thing(chat: String) -> void:
	print("\n── a photograph that is not the thing ──")
	await _call_as(chat, "clear_model", {})
	_finder.answers = {"Gandalf": [_picture("G-20 Toronto June 2010.jpg")]}
	await _call_as(chat, "submit_design", _tower())
	await _call_as(chat, "review_model", {})
	await _call_as(chat, PhotoLook.TOOL, {"real_thing": "Gandalf"})
	await _call_as(chat, "review_model", {})
	var answer: String = _text(await _call_as(chat, PhotoLook.TOOL, {"photo": "a crowd in a "
		+ "street", "is_it": false}))
	var rest: String = _text(await _call_as(chat, "review_model", {}))
	_check("not the thing: the look ends, no table, then the review: %s" % answer.left(50),
		answer.begins_with("Then there is no photograph to measure against, and the look ends")
		and not answer.contains("|") and rest.begins_with("The whole model:")
		and not bool(_look().last.get("is_it", true)))


## No photograph for its name: each search said, and the review goes on.
func _no_photo(chat: String) -> void:
	print("\n── a name with no photograph ──")
	await _call_as(chat, "clear_model", {})
	_finder.asked = PackedStringArray()
	_finder.answers = {}
	await _call_as(chat, "submit_design", _tower())
	await _call_as(chat, "review_model", {})
	await _call_as(chat, PhotoLook.TOOL, {"real_thing": "a glorp, such as live in ponds"})
	var said: Array = await _call_as(chat, "review_model", {})
	var text: String = _text(said)
	_check("two searches, then none came, said: %s" % text.left(90),
		_finder.asked == PackedStringArray(["a glorp, such as live in ponds", "glorp"])
		and text.begins_with(PhotoLook.NO_PHOTO % "a glorp, such as live in ponds\", \"glorp")
		and _images(said) == 0 and _look().step() == "done")
	var rest: String = _text(await _call_as(chat, "review_model", {}))
	_check("...and the review after: %s" % rest.left(30), rest.begins_with("The whole model:"))


## The model not drawn in time, as behind a busy graphics card: the
## photograph goes all the same, and the session is asked to take its own.
func _not_drawn(chat: String) -> void:
	print("\n── the model not drawn in time ──")
	await _call_as(chat, "clear_model", {})
	_finder.answers = {"red lighthouse": [_picture("Red lighthouse on a cliff.jpg")]}
	await _call_as(chat, "submit_design", _tower())
	await _call_as(chat, "review_model", {})
	await _call_as(chat, PhotoLook.TOOL, {"real_thing": "red lighthouse"})
	var shot: ModelShot = _assistant._ensure_shot()
	var was: float = shot.give_up_after
	shot.give_up_after = 0.0
	var said: Array = await _call_as(chat, "review_model", {})
	shot.give_up_after = was
	var text: String = _text(said)
	_check("the photograph still goes, alone: %d picture" % _images(said),
		_images(said) == 1 and text.contains("The real thing, found for you with \"red "
			+ "lighthouse\": Red lighthouse on a cliff.jpg") and _look().step() == "read")
	_check("...and it is asked to take its own: %s" % _line_with(text, "drawn in time"),
		text.contains(PhotoLook.UNDRAWN) and not text.contains("Yours from"))
	var looked: Array = await _call_as(chat, "view_model", {"from": "front"})
	_check("...which it can, the look waiting: %d picture" % _images(looked),
		_images(looked) == 1 and _look().step() == "read")


## Never answered: two changes refused, then they go ahead; or the model
## taken off to start again, which lets the look go.
func _unanswered(chat: String) -> void:
	print("\n── a look never answered ──")
	await _call_as(chat, "clear_model", {})
	await _call_as(chat, "submit_design", _tower())
	await _call_as(chat, "review_model", {})
	var refused := PackedStringArray()
	for n: int in 3:
		refused.append(_text(await _call_as(chat, "edit_model", {"add": [{"part": "3024",
			"color": 4, "x": 10, "y": 18 + n, "z": 10}]})).left(20))
	_check("two edits refused, the third goes ahead: %s" % " | ".join(refused),
		refused[0].begins_with("Not yet") and refused[1].begins_with("Not yet")
		and not refused[2].begins_with("Not yet")
		and str(_look().last.get("unanswered", "")) == "name" and _look().step() == "done")
	await _call_as("c6b", "clear_model", {})
	await _call_as("c6b", "submit_design", _tower())
	await _call_as("c6b", "review_model", {})
	var cleared: String = _text(await _call_as("c6b", "clear_model", {}))
	var again: String = _text(await _call_as("c6b", "submit_design", _tower()))
	_check("taken off to start again, the look is let go: %s | %s" % [cleared.left(30),
		again.left(30)], not cleared.begins_with("Not yet") and again.begins_with("Built.")
		and str(_look().last.get("unanswered", "")) == "name")


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
			return line.strip_edges().left(130)
	return "(none)"


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
