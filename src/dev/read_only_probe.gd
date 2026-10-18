## A tool that looks changes nothing.
##
##   godot --headless --path . --script src/dev/read_only_probe.gd
##
## The owner's Claude session: "check_design wrote my test gear and axle onto
## the baseplate as bricks #223 and #224, even though checking shouldn't
## change the model." A check from outside put its trial on the baseplate as
## the app's own run shows a draft, unless the session had submitted the
## model standing there itself; a model opened, or built by an earlier
## session, was checked onto. So a model is opened here as the person opens
## one, and every tool that only looks — the check, the searches, the guides,
## the looks at the model and the selection, the review — is called on it as
## a session calls it. The parts, their colours and where each stands must be
## the same, to the byte, after every one as before. And a part's geometry is
## waited for, never refused: attachment_points answered "has not arrived
## yet" for a Technic beam on the web.
##
## Claude is told which tools are read-only (MCP's readOnlyHint, from
## CommandSocket.HINTS), and decides from it what to ask the person about.
## So every tool that table calls read-only is called here — the window's
## own (the parts list, the gallery, a job) through the socket a session's
## calls come in by, on the app's scene — and one it calls read-only that
## nothing here calls fails.
extends SceneTree

var _failures: int = 0
var _world: BrickWorld
## Each tool called, by name.
var _called: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = library
	root.add_child(_world)
	var builder := Builder.new()
	builder.world = _world
	builder.library = library
	root.add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = _world
	assistant.builder = builder
	root.add_child(assistant)
	var store := ModelStore.new()
	store.world = _world
	store.library = library
	store.builder = builder
	store.keeps = false
	await process_frame

	var opened: int = store.open("res://models/house.ldr")
	_ok(opened > 20, "the house opened as the person opens a model: %d parts" % opened)
	var some: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if some.size() < 4:
			some.append(brick.id)
	var first: int = some[0]
	builder.selection.clear()
	for brick_id: int in some:
		builder.selection[brick_id] = true

	print("\nevery tool that looks, on a model this session did not build")
	var gear_and_axle: Array = [
		{"part": "3648b", "color": 71, "x": 40, "y": 0, "z": 40, "rot": 0},
		{"part": "3705", "color": 0, "x": 41, "y": 0, "z": 41, "rot": 0}]
	var calls: Array = [
		["check_design", {"name": "test", "bricks": gear_and_axle}],
		["check_design", {"bricks": [{"part": "3001", "color": 4, "x": 0, "y": 30, "z": 0}]}],
		["search_parts", {"query": "technic gear 24 tooth"}],
		["attachment_points", {"part": "32523", "x": 0, "y": 0, "z": 0}],
		["attachment_points", {"brick": first}],
		["how_real_sets_build_this", {"subject": "an orrery"}],
		["find_techniques", {"query": "gear train"}],
		["show_technique", {"name": "round tower"}],
		["find_parts_like", {"query": "gear"}],
		["plan_scale", {"subject": "an orrery", "longest_metres": 0.4}],
		["read_guide", {"section": "pins"}],
		["look_at_model", {}],
		["view_model", {"from": "corner"}],
		["selection", {}],
		["where_to_attach", {"part": "3024"}],
		["edit_selection", {"add": [{"part": "3024", "color": 4, "x": 0, "y": 40, "z": 0}],
			"check_only": true}],
		["search_gear_ratio", {"ratio": 0.3333}],
		["look_at_picture", {}],
		["find_reference", {"subject": "a lighthouse"}],
	]
	for call: Array in calls:
		_called[str(call[0])] = true
		var was: String = _standing(_world)
		var answer: Variant = await assistant.use_tool(str(call[0]), call[1])
		var said: String = _text_of(answer)
		_ok(_standing(_world) == was, "%s %s changes nothing: %s" % [call[0],
			JSON.stringify(call[1]).left(50), said.left(60).replace("\n", " ")])
		if str(call[0]) == "attachment_points" and (call[1] as Dictionary).has("part"):
			_ok(not said.contains("has not arrived") and said.contains("32523"),
				"...and says where a Technic beam attaches, its geometry waited for")
	# Not a feature's review: that lays the best real set's piece for it, as
	# its description says, and is one step to undo (claude_undo_probe).
	for asked: Array in [["", "", false], ["", "", true]]:
		var was: String = _standing(_world)
		var said: String = await assistant.review(str(asked[0]), str(asked[1]), bool(asked[2]))
		_ok(_standing(_world) == was, "review_model %s changes nothing: %s" % [
			"creative" if asked[2] else "whole", said.left(60).replace("\n", " ")])
	_ok(_world.brick_count() == opened, "the model is the %d parts it opened as" % opened)
	builder.selection.clear()
	assistant.unfocus()

	# The window's own that only look, which need the window: through the
	# socket a session's calls come in by, on the app's scene.
	print("\nthe window's own that only look, called as a session calls them")
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 60:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var socket := CommandSocket.new()
	socket.assistant = main.get("_assistant")
	socket.app = main
	main.add_child(socket)
	var app_store: ModelStore = main.get("_store")
	app_store.keeps = false
	var app_parts: int = app_store.open("res://models/house.ldr")
	# Shown whole, not assembling, so nothing moves but what a call moves.
	if playback != null:
		playback.stop()
	await process_frame
	var app_world: BrickWorld = main.get("_world")
	_ok(app_parts > 20, "the house opened in the app: %d parts" % app_parts)
	var sent: int = 0
	for call: Array in [["parts_list", {}], ["parts_list", {"which": "need"}],
			["gallery", {"q": "castle"}], ["job", {}], ["suggest_sections", {}],
			["evaluate_section", {"suggestion": 1}], ["booklet_layout", {}]]:
		_called[str(call[0])] = true
		var was: String = _standing(app_world)
		sent += 1
		var answer: Variant = await socket.answer_rpc({"jsonrpc": "2.0", "id": sent,
			"method": "tools/call", "params": {"name": call[0], "arguments": call[1]}})
		var said: String = _text_of(((answer as Dictionary).get("result", {}) as Dictionary)
			.get("content", []))
		_ok(_standing(app_world) == was and not said.is_empty(), "%s %s changes nothing: %s" % [
			call[0], JSON.stringify(call[1]), said.left(60).replace("\n", " ")])

	# Every tool the table calls read-only (CommandSocket.HINTS, which
	# every client is told) is one called above.
	var uncalled := PackedStringArray()
	for name: String in CommandSocket.HINTS.keys():
		if bool(CommandSocket.annotations(name).get("readOnlyHint", false)) and not _called.has(name):
			uncalled.append(name)
	_ok(uncalled.is_empty(), "every tool Claude is told is read-only was called here%s" % (
		"" if uncalled.is_empty() else ": not " + ", ".join(uncalled)))
	main.queue_free()
	await process_frame

	print("")
	if _failures > 0:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	else:
		print("looking changes nothing")
	quit(1 if _failures > 0 else 0)


## Every part on the baseplate: its number, part, colour and transform.
func _standing(world: BrickWorld) -> String:
	var rows := PackedStringArray()
	for brick: BrickWorld.Brick in world.bricks():
		rows.append("%d %s %d %s" % [brick.id, brick.part_id, brick.color_code, brick.transform])
	rows.sort()
	return "\n".join(rows)


static func _text_of(answer: Variant) -> String:
	if answer is Array:
		var out := PackedStringArray()
		for block: Variant in answer:
			if block is Dictionary:
				out.append(str((block as Dictionary).get("text", "")))
		return " ".join(out)
	return str(answer)


func _ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_failures += 1
