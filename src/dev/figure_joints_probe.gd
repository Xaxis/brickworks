## Does a session building a figure, a creature or a character hear of its
## joints where it decides how to build it?
##
##   godot --headless --path . --script src/dev/figure_joints_probe.gd
##
## The attach round (docs/BRICKBENCH.md, 2026-10-15): placing by connectors
## worked, and 7 of 20 sessions used it, for eyes, brows and flames; none put a
## figure's limbs on a joint. Every character session decided how to build at
## its first submit or check, just after reading the shapes guide, and was told
## nothing of joints there: check_design could not tell a figure from a tower
## (it carries no name), the living things' advice said "the shape pattern, for
## a creature's body", plan_scale's figure answer named no joint, no search
## for a limb was ever made, and the review's one line about a rigid leg pointed
## at a section no session read. So, each where a session reads it:
##   - the subject is read by words: a person, a creature, a thing with a face,
##     and nothing else (a whale-tail spoiler, a dollhouse, a clock face);
##   - check_design's and submit_design's reply on one built with nothing on a
##     joint names each joint's one call, with an attach written out, twice in
##     full and then in a line; nothing once it is posed, nothing for a tower;
##   - plan_scale for a figure lays out the posed minifigure and the armatures,
##     and for a creature at a scale says it is built on joints all the same;
##   - search_parts names the joint parts for a limb, and once for a character;
##   - the review says which limb stands stiff and stacked;
##   - read_guide "shapes" is led, for a character, by what it is built of.
extends SceneTree

var _failures: int = 0
var _passed: int = 0
var _assistant: Assistant


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
	_assistant = Assistant.new()
	_assistant.library = library
	_assistant.world = world
	_assistant.builder = builder
	root.add_child(_assistant)
	await process_frame

	print("\nthe subject, by its words")
	for pair: Array in [
			["A dark-brown statue of a man sits hunched forward on a rough block", "figure"],
			["A bright-blue balloon-dog sculpture stands on a white plinth", "creature"],
			["A white toilet with a long neck and grinning human head", "figure"],
			["A plush blue armchair has large white eyes with long eyelashes", "face"],
			["A brown potato-shaped toy wears a black hat. It has white eyes", "face"],
			["an owl on a branch", "creature"], ["a knight on horseback", "figure"],
			["two women and a boy at a bus stop", "figure"],
			["she holds a lantern over her head", "figure"],
			["a Porsche 911 with a whale-tail spoiler and a rear-engine layout", ""],
			["a lighthouse on a rock", ""], ["a bonsai tree in a pot", ""],
			["a clock face on a tower", ""], ["a computer and a desk", ""],
			["a dollhouse with three rooms", ""], ["the mouth of a cave in a cliff face", ""],
			["a crane with a long arm", ""], ["a toy car", ""]]:
		var kind: String = Style.character_of(str(pair[0]))
		_ok(kind == str(pair[1]), "\"%s\" is %s" % [pair[0],
			"a %s" % kind if not kind.is_empty() else "no character"])

	print("\ncheck_design, where how to build it is decided")
	var stacked: Array = _stacked_figure()
	_assistant.heard("A dark-brown statue of a man sits hunched forward on a rough block.", true)
	var first: String = _text(await _assistant.use_tool("check_design", {"bricks": stacked}))
	_ok(first.contains("nothing in it is on a joint") and first.contains("place_technique")
		and first.contains("posed minifigure") and first.contains("jointed figure")
		and first.contains("limb on a clip") and first.contains("head on a neck")
		and first.contains("\"attach\": {\"to\""),
		"a statue stacked square is told each joint's call, an attach written out: %s"
			% _around(first, "nothing in it is on a joint"))
	_ok(first.find("nothing in it is on a joint") < first.find("Look at it"),
		"...before the look, among the first advice")
	var second: String = _text(await _assistant.use_tool("check_design", {"bricks": stacked}))
	var third: String = _text(await _assistant.use_tool("check_design", {"bricks": stacked}))
	_ok(second.contains("A set builds one of sub-assemblies") and third.contains("Still nothing in it is on a joint")
		and not third.contains("A set builds one of sub-assemblies"),
		"...twice in full, then in a line: %s" % _around(third, "Still nothing"))
	var posed: Array = stacked.duplicate(true)
	posed.append_array(_limb_on_a_clip_at(0, 15, 0))
	var once_posed: String = _text(await _assistant.use_tool("check_design", {"bricks": posed}))
	_ok(not once_posed.contains("on a joint"), "posed, an arm on a clip, it is told nothing of joints")
	_assistant.heard("a lighthouse on a rock", true)
	var tower: String = _text(await _assistant.use_tool("check_design", {"bricks": stacked}))
	_ok(not tower.contains("on a joint"), "a lighthouse built the same is told nothing of joints")
	# The subject heard from a tool, before any brief: plan_scale's subject.
	_assistant.heard("", true)
	await _assistant.use_tool("plan_scale", {"subject": "a seated thinker statue", "longest_metres": 1.0})
	var after_plan: String = _text(await _assistant.use_tool("check_design", {"bricks": stacked}))
	_ok(after_plan.contains("nothing in it is on a joint"),
		"with no brief, the subject plan_scale was asked about is the one read")

	print("\nthe advice for a creature")
	var calls: String = "; ".join(Style.calls_for(Style.traits_of("a dragon"), {}, {}, "a dragon"))
	_ok(not calls.contains("the shape pattern, for a creature's body") and calls.contains("jointed animal")
		and calls.contains("tail on a bar"),
		"a dragon is told of joints, not to lay its body as a shape: %s" % calls.left(160))
	var tree: String = "; ".join(Style.calls_for(Style.traits_of("a bonsai tree"), {}, {}, "a bonsai tree"))
	_ok(tree.contains("for a living thing") and not tree.contains("jointed"),
		"a bonsai tree is still a living thing, with no joints: %s" % tree.left(100))

	print("\nplan_scale")
	_assistant.heard("", true)
	var statue: String = _text(await _assistant.use_tool("plan_scale",
		{"subject": "a seated statue of a man", "longest_metres": 1.8}))
	_ok(statue.contains("place_technique \"posed minifigure\"") and statue.contains("\"jointed figure\"")
		and statue.contains("jointed armature"),
		"a statue of a man is offered the posed minifigure and the armature: %s"
			% _around(statue, "smaller than any scale"))
	var dragon: String = _text(await _assistant.use_tool("plan_scale",
		{"subject": "a dragon", "longest_metres": 12.0}))
	_ok(dragon.contains("built on joints") and dragon.contains("\"jointed animal\""),
		"a dragon at a scale is built on joints all the same: %s" % _around(dragon, "at any size"))
	_assistant.heard("", true)
	var lighthouse: String = _text(await _assistant.use_tool("plan_scale",
		{"subject": "a lighthouse", "longest_metres": 30.0}))
	_ok(not lighthouse.contains("joint"), "a lighthouse is told nothing of joints")

	print("\nsearch_parts")
	_assistant.heard("a lighthouse on a rock", true)
	var plain: String = _text(await _assistant.use_tool("search_parts", {"query": "brick 2 x 4"}))
	_ok(not plain.contains("on a joint"), "a lighthouse's search for a brick is told nothing of joints")
	var arm: String = _text(await _assistant.use_tool("search_parts", {"query": "robot arm"}))
	_ok(arm.contains("63868") and arm.contains("60478") and arm.contains("14418")
		and arm.contains("44301a"), "a search for an arm names the joint parts: %s"
			% _around(arm, "For a limb"))
	_assistant.heard("A bright-blue balloon-dog sculpture stands on a white plinth.", true)
	var dog: String = _text(await _assistant.use_tool("search_parts", {"query": "brick round 2 x 2"}))
	var dog_again: String = _text(await _assistant.use_tool("search_parts", {"query": "dome"}))
	_ok(dog.contains("For a limb, a head or a tail on a joint") and not dog_again.contains("For a limb"),
		"a balloon dog's first search names them, once")

	print("\nread_guide")
	_assistant.heard("A dark-brown statue of a man sits hunched forward on a rough block.", true)
	var shapes: String = _text(await _assistant.use_tool("read_guide", {"section": "shapes"}))
	_ok(shapes.begins_with("This subject is a figure") and shapes.contains("SAY THE SHAPE"),
		"the shapes guide is led, for a statue, by what a figure is built of")
	_assistant.heard("a lighthouse on a rock", true)
	var shapes_tower: String = _text(await _assistant.use_tool("read_guide", {"section": "shapes"}))
	_ok(shapes_tower.begins_with("SAY THE SHAPE"), "...and for a lighthouse is the guide as it was")
	var described: String = ""
	for tool: Dictionary in _assistant._tools():
		if str(tool.get("name", "")) == "read_guide":
			described = str(tool.get("description", ""))
	_ok(described.contains("\"figures\""), "read_guide's own description names \"figures\"")

	print("\nthe review")
	_assistant.heard("A dark-brown statue of a man sits hunched forward on a rough block.", true)
	var laid: String = _text(await _assistant.use_tool("submit_design", {"name": "Thinker",
		"description": "a seated statue of a man", "floor": "none", "bricks": stacked}))
	_ok(laid.contains("Built") or not laid.begins_with("Not applied"),
		"the stacked statue is submitted: %s" % laid.left(120))
	var reviewed: String = _text(await _assistant.review(""))
	_ok(reviewed.contains("Stiff, stacked limbs") and reviewed.contains("left arm")
		and reviewed.contains("right arm"),
		"its review says which limbs stand stiff and stacked: %s" % _around(reviewed, "Stiff"))
	var laid_posed: String = _text(await _assistant.use_tool("submit_design", {"name": "Thinker",
		"description": "a seated statue of a man", "floor": "none", "bricks": _posed_figure()}))
	_ok(not laid_posed.begins_with("Not applied"), "posed, it is submitted: %s" % laid_posed.left(160))
	var reviewed_posed: String = _text(await _assistant.review(""))
	_ok(not reviewed_posed.contains("Stiff, stacked") and not reviewed_posed.contains("Nothing in it is on a joint"),
		"...and its review says nothing of stiff limbs: %s" % _around(reviewed_posed, "Stiff"))

	print("\nfigure joints probe: %d passed, %d failed" % [_passed, _failures])
	quit(1 if _failures > 0 else 0)


## A man stacked square, named as a session names its parts: legs, a body, two
## arms hanging under the shoulders, a head. It stands, square, on its legs.
static func _stacked_figure() -> Array:
	return [
		{"part": "3004", "color": 308, "x": 1, "y": 0, "z": 0, "rot": 1, "name": "left leg"},
		{"part": "3004", "color": 308, "x": 2, "y": 0, "z": 0, "rot": 1, "name": "right leg"},
		{"part": "3003", "color": 308, "x": 1, "y": 3, "z": 0, "rot": 0},
		{"part": "3003", "color": 308, "x": 1, "y": 6, "z": 0, "rot": 0},
		{"part": "3001", "color": 308, "x": 0, "y": 9, "z": 0, "rot": 0, "name": "shoulders"},
		{"part": "3005", "color": 308, "x": 0, "y": 6, "z": 0, "rot": 0, "name": "left arm"},
		{"part": "3005", "color": 308, "x": 3, "y": 6, "z": 0, "rot": 0, "name": "right arm"},
		{"part": "3003", "color": 308, "x": 1, "y": 12, "z": 0, "rot": 0, "name": "head"},
	]


## The same man with each arm on a clip at its shoulder, swung down and out.
static func _posed_figure() -> Array:
	var bricks: Array = _stacked_figure().filter(func(b: Variant) -> bool:
		return not str((b as Dictionary).get("name", "")).ends_with("arm"))
	# The head at the left of the shoulders, the clip at their right end, its
	# arm reaching out past them.
	for brick: Dictionary in bricks:
		if str(brick.get("name", "")) == "head":
			brick["x"] = 0
	bricks.append_array(_limb_on_a_clip_at(2, 12, 0))
	return bricks


## Show_technique's "limb on a clip" without its body: the clip plate at x, y,
## z and the arm on it, named so the review reads it as an arm.
static func _limb_on_a_clip_at(x: int, y: int, z: int) -> Array:
	var out: Array = []
	for raw: Variant in Techniques.named("limb on a clip")["bricks"]:
		var brick: Dictionary = (raw as Dictionary).duplicate(true)
		if str(brick.get("name", "")) == "body":
			continue
		if brick.has("x"):
			brick["x"] = float(brick["x"]) + x
			brick["y"] = float(brick["y"]) - 3 + y
			brick["z"] = float(brick["z"]) + z
		if str(brick.get("name", "")) == "arm":
			brick["name"] = "left arm"
		if brick.has("attach") and str((brick["attach"] as Dictionary).get("to", "")).begins_with("arm."):
			brick["attach"]["to"] = str(brick["attach"]["to"]).replace("arm.", "left arm.")
		out.append(brick)
	return out


func _text(answer: Variant) -> String:
	if answer is String:
		return answer
	var out := PackedStringArray()
	if answer is Array:
		for block: Variant in answer:
			if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
				out.append(str((block as Dictionary).get("text", "")))
	return "\n".join(out)


static func _around(text: String, phrase: String) -> String:
	var at: int = text.find(phrase)
	return (text.substr(maxi(at, 0), 160) if at >= 0 else text.left(160)).replace("\n", " ")


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s" % what)
