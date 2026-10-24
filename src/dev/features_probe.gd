## The app works a design's features with it, one at a time: for each it
## looks up how real sets built it, lays the best piece that lays whole where
## the feature goes, and the design accepts, adjusts or rejects it.
##
##   godot --headless --path . --script src/dev/features_probe.gd
##
## The last held-out owl called find_techniques once, before building, and
## laid nothing from it; design5's feature chain told sessions which feature
## was next, and they worked two of six, read the three pieces handed over
## and built their own: no real piece was laid in any bench run. The creative
## pass moved its dimension because the app hands that turn over itself. So
## now the app does the retrieval and the placing: each feature comes back
## with a real set's piece standing in the model, and the design's part is
## settle_feature — accept (moved, turned, recoloured), next, reject with a
## reason, or built. From outside, saving waits until every feature is
## settled; it wrote the file first and handed the next feature after, and
## every session then ended.
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
	_ok(Techniques.for_feature("spoiler").is_empty(), "a spoiler has none, and none is made up")
	_ok(Assistant._subject_words("A barn owl as a detailed LEGO display model") == "owl",
		"a brief's subject is the word the index knows: \"%s\""
			% Assistant._subject_words("A barn owl as a detailed LEGO display model"))

	print("\nwhere a feature goes, said or read off its name")
	_ok(FeaturePass.read_spots({"features": ["eyes", {"name": "Beak", "x": 7, "y": 4, "z": 15,
		"facing": "+z"}]}) == {"beak": {"x": 7.0, "y": 4.0, "z": 15.0, "facing": "+z"}},
		"a feature given with x, y, z and facing keeps its spot; a bare name has none")
	_ok(FeaturePass._ways("+x")[0] == [1, "up"] and FeaturePass._ways("+x").size() == 5,
		"a side feature is tried as built with its front turned out, then tipped studs out")
	_ok(FeaturePass._plural("ear tufts") and FeaturePass._plural("eyes")
		and not FeaturePass._plural("beak") and not FeaturePass._plural("grass"),
		"eyes and ear tufts come in pairs; a beak and grass do not")

	# What _start does, without the request it ends in.
	assistant._busy = true
	assistant._brief = "A barn owl as a detailed LEGO display model"
	assistant._messages = [{"role": "user", "content": "a barn owl"}]

	print("\nthe silhouette is submitted, with its features and where they go")
	await _reply(assistant, [_tool("submit_design", _owl(["eyes",
		{"name": "beak", "x": 8, "y": 1, "z": 13, "facing": "+z"}]))])
	var look: String = _text_of(assistant._messages.back())
	_ok(assistant._looked_back, "it holds, so it is looked at whole first")
	_ok(look.contains("each feature you listed — eyes, beak —")
		and look.contains("the app lays the best real set's piece"),
		"...told the app lays a real piece for each feature in turn")

	print("\nit approves the silhouette, and the app lays a real piece for the eyes")
	var before: int = world.brick_count()
	await _reply(assistant, [{"type": "text", "text": "The silhouette reads."}])
	var eyes: String = _text_of(assistant._messages.back())
	print("    " + eyes.substr(0, 1100).replace("\n", "\n    "))
	_ok(eyes.contains("The eyes — feature 1 of 2"), "the eyes, as feature 1 of 2")
	var proposed: FeaturePass.Proposal = assistant.feature_pass().proposal("eyes")
	_ok(proposed != null and not proposed.piece.is_empty() and bool(proposed.piece["lays"]),
		"the app chose a real piece that lays whole: %s" % (proposed.piece.get("id", "none")
			if proposed != null else "none"))
	_ok(world.brick_count() > before and proposed != null and not proposed.ids.is_empty()
		and assistant.feature_pass()._standing(proposed.ids),
		"...and laid it in the model (%d parts to %d)" % [before, world.brick_count()])
	_ok(eyes.contains("laid the best piece that lays whole and fits where it goes")
		and eyes.contains("settle_feature"), "...handed over to accept, adjust or reject")
	_ok(eyes.contains("read off its name"), "...saying where it goes was a guess from its name")
	_ok(_said("working the eyes (feature 1 of 2)"), "the progress line says which feature")
	var eyes_id: String = str(proposed.piece.get("id", "")) if proposed != null else ""

	print("\nit accepts the eyes, and the beak comes next, laid where it was said to go")
	await _reply(assistant, [_tool("settle_feature", {"feature": "eyes", "verdict": "accept"})])
	_ok(assistant._feature_said("eyes").begins_with("real piece %s" % eyes_id)
		and assistant._feature_said("eyes").contains("accepted"),
		"the eyes are recorded as the app's piece, accepted: %s" % assistant._feature_said("eyes"))
	var beak: String = _text_of(assistant._messages.back())
	_ok(beak.contains("The beak — feature 2 of 2"), "settling it ends the eyes' turn: the beak is next")
	var beak_one: FeaturePass.Proposal = assistant.feature_pass().proposal("beak")
	_ok(beak_one != null and not beak_one.guessed and str(beak_one.spot["facing"]) == "+z",
		"...at the spot submit_design gave it")
	var beak_laid: int = beak_one.ids.size() if beak_one != null else 0
	print("    the beak: %s, %d bricks laid" % [beak_one.piece.get("id", "nothing fits")
		if beak_one != null else "?", beak_laid])

	print("\nit rejects the beak with a reason, and builds its own")
	var standing: int = world.brick_count()
	await _reply(assistant, [_tool("settle_feature", {"feature": "beak", "verdict": "reject",
		"reason": "too big for this head; a jumper and a slope read better"})])
	_ok(assistant._feature_said("beak").begins_with("the app's piece rejected: too big"),
		"the beak is recorded as rejected, with the reason")
	_ok(world.brick_count() == standing - beak_laid, "...and the app's piece is taken off")
	_ok(not ended.is_empty() and bool(ended[0][0]), "with nothing left to work, the run ends well")
	_ok(_said("features:\n  eyes: real piece %s" % eyes_id), "...saying what each feature came to")

	print("\nfrom outside: saving waits until every feature is settled")
	assistant._busy = false
	world.clear()
	builder.lattice.clear()
	# This is about features, not joints. An owl with nothing on a joint is
	# sent back once (Assistant._unjointed_refusal), and a cleared model
	# arms that again, so the build below answered with the send-back and
	# every check after it failed (since b217576). Spent here, as a session
	# that submitted it twice would have.
	assistant._joints_refused = true
	var built: Variant = await assistant.use_tool("submit_design", _owl([
		{"name": "eyes", "x": 5, "y": 13, "z": 7, "facing": "+z"},
		{"name": "beak", "x": 8, "y": 1, "z": 13, "facing": "+z"}]))
	_ok(str(built).contains("the app lays the best real set's piece"),
		"the build's answer says the app lays a piece for each feature")
	var socket := CommandSocket.new()
	socket.assistant = assistant
	root.add_child(socket)
	var count: int = world.brick_count()
	var refused: Variant = await socket._run_own("save_model", {"name": "owl.ldr"})
	var refused_text: String = _blocks_text(refused)
	print("    " + refused_text.substr(0, 400).replace("\n", "\n    "))
	_ok(refused_text.begins_with("Not saved yet: 2 of its 2 features are not settled"),
		"save_model refuses with two features open")
	_ok(refused_text.contains("The eyes — feature 1 of 2") and world.brick_count() > count,
		"...and hands the eyes back with the app's piece laid")
	var first: FeaturePass.Proposal = assistant.feature_pass().proposal("eyes")
	var first_id: String = str(first.piece.get("id", ""))
	_ok(first.copies.size() == 2 and absf(float((first.copies[1]["at"] as Vector3).x) - 8.0
		- (8.0 - float((first.copies[0]["at"] as Vector3).x))) <= 1.0,
		"eyes said off the middle are laid as a pair, mirrored across the model (x %s and %s)"
		% [(first.copies[0]["at"] as Vector3).x, (first.copies[1]["at"] as Vector3).x
			if first.copies.size() > 1 else "none"])
	_save_picture(refused, "eyes_proposal")
	var next: Variant = await assistant.use_tool("settle_feature", {"feature": "eyes",
		"verdict": "next"})
	var second: FeaturePass.Proposal = assistant.feature_pass().proposal("eyes")
	_ok(not second.settled() and str(second.piece.get("id", "")) != first_id
		and not second.piece.is_empty(), "\"next\" lays the next-best piece instead: %s"
		% second.piece.get("id", "none"))
	var where_was: Vector3 = FeaturePass._low(second.copies[0]["bricks"])
	# A stud toward the middle of the body's top (z 6 to 8), so it still stands.
	var by: float = -1.0 if where_was.z >= 7.0 else 1.0
	var adjusted: Variant = await assistant.use_tool("settle_feature", {"feature": "eyes",
		"verdict": "accept", "move": {"dx": 0, "dy": 0, "dz": by}})
	var moved_to: Vector3 = FeaturePass._low(second.copies[0]["bricks"])
	print("    " + _blocks_text(adjusted).substr(0, 300).replace("\n", "\n    "))
	_ok(second.verdict == "adjusted" and is_equal_approx(moved_to.z, where_was.z + by),
		"accepting it moved a stud lays it again there (z %s to %s)" % [where_was.z,
			moved_to.z])
	_ok(_blocks_text(adjusted).contains("Next, the beak:")
		and _blocks_text(adjusted).contains("The beak — feature 2 of 2"),
		"...and the answer hands the next feature, the beak")
	var short: Variant = await assistant.use_tool("settle_feature", {"feature": "beak",
		"verdict": "reject", "reason": "no"})
	_ok(_blocks_text(short).begins_with("Say why in a sentence"),
		"a rejection without a reason is not taken")
	var beak_piece: Array[int] = assistant.feature_pass().proposal("beak").ids.duplicate()
	var done: Variant = await assistant.use_tool("settle_feature", {"feature": "beak",
		"verdict": "built", "reason": "the face key laid a beak already"})
	var gone: bool = not beak_piece.is_empty()
	for id: int in beak_piece:
		gone = gone and world.get_brick(id) == null
	_ok(gone, "settled as built, the app's piece for the beak comes off (%d parts)"
		% beak_piece.size())
	_ok(_blocks_text(done).contains("Every feature is settled")
		and _blocks_text(done).contains("review_model {\"assembly\": \"owl\"}"),
		"the last one settled says what is next: %s" % _blocks_text(done).get_slice("\n\n", 2))
	var saved: Variant = await socket._run_own("save_model", {"name": "owl.ldr"})
	_ok(_blocks_text(saved) == "This app cannot do that from outside.",
		"with every feature settled, saving goes ahead (to the app, absent here)")
	var whole: Variant = await assistant.review("")
	_ok(_blocks_text(whole).contains("eyes: real piece %s \"%s\" laid by the app, adjusted"
		% [second.piece["id"], second.piece["name"]]) and _blocks_text(whole).contains(
		"beak: built by the design: the face key"),
		"the whole review lists what each feature came to")

	print("\nseveral settled in one call, and a feature skipped does not hold the save")
	world.clear()
	builder.lattice.clear()
	assistant._joints_refused = true
	await assistant.use_tool("submit_design", _owl(["eyes", "beak", "ear tufts"]))
	var listed: String = _blocks_text(await assistant.review(""))
	_ok(listed.contains("beak: not worked yet — real sets have ")
		and listed.contains("ear tufts: not worked yet — real sets have "),
		"the whole review names the real piece each feature would be laid: %s"
		% _around(listed, "beak: not worked yet"))
	var skipped: String = _blocks_text(await assistant.use_tool("settle_feature", {
		"feature": "beak, ear tufts", "verdict": "skip",
		"reason": "the face key has both already"}))
	_ok(assistant._feature_said("beak").begins_with("left out by the design")
		and assistant._feature_said("ear tufts").begins_with("left out by the design"),
		"\"beak, ear tufts\" skipped in one call: %s" % skipped.substr(0, 120))
	var all_built: String = _blocks_text(await assistant.use_tool("settle_feature", {
		"feature": "all", "verdict": "built", "reason": "white dishes with black studs"}))
	_ok(assistant._feature_said("eyes").begins_with("built by the design")
		and all_built.contains("Every feature is settled"),
		"\"all\" settles the one left, and says every feature is settled")
	var saved_now: Variant = await socket._run_own("save_model", {"name": "owl.ldr"})
	_ok(_blocks_text(saved_now) == "This app cannot do that from outside.",
		"...and saving goes ahead with two features skipped")
	# Looked at whole and changed, a change's answer says to save: a fire
	# engine session went from its surface pass to its figure and answered
	# with nothing saved.
	var touched: String = _blocks_text(await assistant.use_tool("edit_model", {"add": [
		{"part": "3024", "color": 15, "x": 4, "y": 13, "z": 6}]}))
	_ok(touched.ends_with("Not saved yet: save_model keeps it. The design is not kept until "
		+ "it is saved."), "after the whole review, a change's answer says to save: %s"
		% touched.right(90))

	print("\nsaving waits once on a part BrickBench counts as a piece of its own")
	# A 4 x 4 dish on a round plate's studs stays on in the hand (its tube
	# grips them), and BrickNet's graph joins it to nothing: critique221's
	# potato saved so, in two pieces, and its dog in five.
	world.clear()
	builder.lattice.clear()
	var dish: Array = [{"part": "3003", "color": 72, "x": 1, "y": 0, "z": 1, "rot": 0},
		{"part": "4032a", "color": 72, "x": 1, "y": 3, "z": 1, "rot": 0},
		{"part": "3960", "color": 15, "x": 0, "y": 4, "z": 0, "rot": 0}]
	var stood: String = _blocks_text(await assistant.use_tool("submit_design",
		{"name": "Lamp", "description": "a lamp", "bricks": dish}))
	var held_back: String = _blocks_text(await socket._run_own("save_model", {"name": "lamp.ldr"}))
	_ok(stood.begins_with("Built.") and held_back.begins_with("Not saved yet: BrickBench counts "
		+ "it as 2 pieces") and held_back.contains("3960"),
		"a dish held only by a stud in its tube holds the save, named: %s / %s"
			% [stood.left(60), held_back.left(140)])
	# Said with what to do, so the design can act on it: the seat half a stud
	# across was said first, and laid there the dish was refused as off its
	# studs. A stud at its tube's middle joins it, which is a jumper's.
	var swap: String = "swap #2 (4032a plate 2 x 2 round with axlehole at 1,3,1) for a 2 x 2 " \
		+ "jumper plate (87580) in its place"
	_ok(held_back.contains("its tube stands between that part's studs") and held_back.contains(swap),
		"...with how to join it: %s" % held_back.get_slice("\n", 1))
	var swapped: Array = dish.duplicate(true)
	swapped[1]["part"] = "87580"
	await assistant.use_tool("submit_design", {"name": "Lamp", "description": "a lamp",
		"bricks": swapped})
	var fixed: String = _blocks_text(await socket._run_own("save_model", {"name": "lamp.ldr"}))
	_ok(fixed == "This app cannot do that from outside.",
		"...and the plate under it swapped as said, it saves: %s" % fixed.left(140))
	# A dome on a wide plate: a jumper laid under its tube, it a plate higher.
	var dome: Array = [{"part": "3001", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3020", "color": 72, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "24947", "color": 15, "x": 2, "y": 4, "z": 0, "rot": 0}]
	await assistant.use_tool("submit_design", {"name": "Lamp", "description": "a lamp",
		"bricks": dome})
	var on_plate: String = _blocks_text(await socket._run_own("save_model", {"name": "lamp.ldr"}))
	var laid: RegExMatch = RegEx.create_from_string("24947 .*; lay a 2 x 2 jumper plate \\(87580\\) "
		+ "at (-?[\\d.]+),(-?[\\d.]+),(-?[\\d.]+) under it and stand it on the jumper's middle "
		+ "stud, a plate higher, at (-?[\\d.]+),(-?[\\d.]+),(-?[\\d.]+)").search(on_plate)
	_ok(laid != null, "a dome on a 2 x 4's studs: a jumper laid under it, said: %s"
		% on_plate.get_slice("\n", 1))
	if laid != null:
		var raised: Array = dome.duplicate(true)
		raised[2].merge({"x": float(laid.get_string(4)), "y": float(laid.get_string(5)),
			"z": float(laid.get_string(6))}, true)
		raised.append({"part": "87580", "color": 72, "x": float(laid.get_string(1)),
			"y": float(laid.get_string(2)), "z": float(laid.get_string(3)), "rot": 0})
		var stood_up: String = _blocks_text(await assistant.use_tool("submit_design",
			{"name": "Lamp", "description": "a lamp", "bricks": raised}))
		var kept: String = _blocks_text(await socket._run_own("save_model", {"name": "lamp.ldr"}))
		_ok(stood_up.begins_with("Built.") and kept == "This app cannot do that from outside.",
			"...and laid as said, it saves: %s / %s" % [stood_up.left(60), kept.left(140)])
	dish.pop_back()
	await assistant.use_tool("submit_design", {"name": "Lamp", "description": "a lamp",
		"bricks": dish})
	_ok(_blocks_text(await socket._run_own("save_model", {"name": "lamp.ldr"}))
		== "This app cannot do that from outside.", "...and in one piece it saves")

	print("\neach feature is offered a piece that is that feature, or none")
	# The walk180 tug: its features were offered a tugboat's funnel, every one,
	# because "harbour tug boat" ran together as "tugboat" in the search.
	world.clear()
	builder.lattice.clear()
	for x: int in [0, 8, 16, 24]:
		for z: int in [0, 10]:
			await assistant.use_tool("edit_model", {"add": [{"part": "3034", "color": 4,
				"x": x, "y": 0, "z": z, "rot": 0}]})
	assistant._brief = ""
	assistant._named_as = ("Harbour Tug. A small harbour tugboat with tyre fenders, a "
		+ "wheelhouse and a funnel. Floor none: a boat is picked up and played with.")
	var firsts: Dictionary = {}
	for feature: String in ["tyre fenders", "wheelhouse windows", "funnel", "towing bitts",
			"mast and navigation lights", "claw hands", "front door"]:
		var offered: Array = assistant.feature_pass().candidates_for(feature)
		var nouns: Array = FeaturePass.nouns_of(feature)
		var all_fit: bool = true
		for entry: Variant in offered:
			if FeaturePass.names_it(entry, RealSnippets.words(feature), nouns) == 0:
				all_fit = false
		var offered_first: String = str((offered[0] as Dictionary)["text"]).get_slice(":", 0) \
			if not offered.is_empty() else "none"
		print("    %s: %s" % [feature, offered_first])
		if not offered.is_empty():
			firsts[str((offered[0] as Dictionary)["id"])] = true
		_ok(all_fit, "%s: each of the %d offered names it" % [feature, offered.size()])
	_ok(assistant.feature_pass().candidates_for("towing bitts").is_empty(),
		"towing bitts: no real piece is a bitt, so none is offered")
	_ok(firsts.size() >= 6, "the first offers are %d different pieces, not one for all"
		% firsts.size())

	print("")
	if _failures == 0:
		print("OK features_probe")
	else:
		print("FAILED features_probe: %d" % _failures)
	quit(1 if _failures > 0 else 0)


## An owl's silhouette on a 16 x 16 plate: a body of 2 x 4 bricks, with
## the features given.
func _owl(features: Array) -> Dictionary:
	var bricks: Array = [{"part": "91405", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for level: int in 4:
		for x: int in [4, 8]:
			bricks.append({"part": "3001", "color": 19, "x": x, "y": 1 + level * 3,
				"z": 6, "rot": 0})
	return {"name": "barn owl", "description": "a body on a base", "bricks": bricks,
		"assemblies": [{"name": "owl", "x_from": 0, "x_to": 16, "z_from": 0, "z_to": 16}],
		"features": features}


func _reply(assistant: Assistant, content: Array) -> void:
	var body: String = JSON.stringify({"content": content,
		"stop_reason": "end_turn"})
	await assistant._on_response([HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), body.to_utf8_buffer()])


func _tool(name: String, input: Dictionary) -> Dictionary:
	return {"type": "tool_use", "id": "t%d" % randi(), "name": name,
		"input": input}


## The picture in an answer, if it has one, to shots/features/ to look at.
## Headless runs have none: run windowed for it.
func _save_picture(answer: Variant, name: String) -> void:
	if not answer is Array:
		print("    no picture (headless: run windowed for one)")
		return
	for block: Variant in answer as Array:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "image":
			var image := Image.new()
			image.load_png_from_buffer(Marshalls.base64_to_raw(
				str(((block as Dictionary)["source"] as Dictionary)["data"])))
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/features"))
			image.save_png("res://shots/features/%s.png" % name)
			_ok(not image.is_empty(), "the proposal comes with a picture: shots/features/%s.png" % name)
			return
	_ok(not ModelShot.possible(), "the proposal comes with a picture where one can be taken")


## The words of an answer, a String or blocks.
func _blocks_text(answer: Variant) -> String:
	if answer is String:
		return answer
	var said := PackedStringArray()
	for block: Variant in answer as Array:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
			said.append(str((block as Dictionary)["text"]))
	return "\n\n".join(said)


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
			elif inner is Array:
				said.append(_blocks_text(inner))
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


## A line of [param text] from [param start], for a check's words.
func _around(text: String, start: String) -> String:
	var at: int = text.find(start)
	return text.substr(at, 140).get_slice("\n", 0) if at >= 0 else text.left(140)
