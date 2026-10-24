## A session's answers carry what it needs for its next decision, and a
## check asks "what if" of the model it has.
##
##   godot --headless --path . --script src/dev/mcp_lean_probe.gd
##
## walk180 (bench/results/walk180-2026-10-23, findings M8 and M9): an edit of
## its tug was answered with the whole massing table and a picture of the
## whole model, a look at 15 fenders with the 100 kinds of part in the whole
## model, and "what breaks first" took four checks of the bow typed out
## again, each answered with the same picture of the whole tug. Here, on the
## house in the app's scene, called as the MCP port calls them: check_design
## edit= checks a copy of the model with the change and leaves the model as
## it was, names a part standing by its number, and a brick number not there
## is refused; an edit says what it changed and that nothing broke, and its
## sizes only when they change; view_model gives the sizes once for each
## change; a look at a section lists the section's parts, not the whole
## model's, and a look at the whole still tallies the whole. Exits non-zero
## when an answer is wrong.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 60:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var store: ModelStore = _main.get("_store")
	store.keeps = false
	var parts: int = store.open("res://models/house.ldr")
	if playback != null:
		playback.stop()
	await process_frame
	_world = _main.get("_world")
	_check("the house opened: %d parts" % parts, parts > 20)
	await _what_if()
	await _the_edit()
	await _looks()
	print("")
	print("lean: a check asks what if of the model it has, an edit says what it changed "
		+ "and broke, and the sizes and the tally are said once" if _failures == 0
		else "lean: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _what_if() -> void:
	print("── check_design edit=: what if, on a copy ──")
	var first: int = _first_brick()
	var was: String = _standing()
	var said: Array = await _call("check_design", {"edit": {"remove": [first]}})
	var text: String = _text(said)
	_check("it is a what-if on a copy: %s" % text.get_slice("\n", 0).left(90),
		text.begins_with("What if, on a copy of the model as it stands (took off 1)"))
	_check("...and the model is as it was", _standing() == was)
	_check("...and weighed: %s" % _line_with(text, "Balance:").left(80),
		not _line_with(text, "Balance:").is_empty())
	_check("...and no picture of what stands there", _images(said) == 0)
	said = await _call("check_design", {"edit": {}})
	_check("edit={} checks the model as it is: %s" % _text(said).get_slice("\n", 1).left(60),
		_text(said).begins_with("What if") and _standing() == was)
	var joints: String = _line_with(_text(said), "Most loaded stud joints")
	_check("...naming a part standing by its number: %s" % joints.left(90),
		joints.is_empty() or joints.contains(" #"))
	said = await _call("check_design", {"edit": {"remove": [987654]}})
	_check("a number not there is refused: %s" % _text(said).left(60),
		_text(said).begins_with("No brick has 987654"))
	said = await _call("check_design", {"bricks": [{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0}]})
	_check("a check of bricks from outside says why it is not drawn",
		_text(said).contains("Not drawn") and _images(said) == 0)


func _the_edit() -> void:
	print("── an edit: what it changed and what that broke ──")
	await _call("view_model", {"from": "front"})
	var first: int = _first_brick()
	var said: Array = await _call("edit_model", {"recolor": [{"bricks": [first], "color": 1}]})
	var text: String = _text(said)
	_check("it landed: %s" % text.get_slice("\n", 0), text.begins_with("Done."))
	_check("...it says what it changed: %s" % text.get_slice("\n", 1),
		text.get_slice("\n", 1) == "Recoloured 1 Blue (1).")
	_check("...and what that broke: %s" % text.get_slice("\n", 2),
		text.get_slice("\n", 2).begins_with("It stands") or text.get_slice("\n", 2).begins_with("As it stands now"))
	_check("...and not the sizes, which it did not change", not text.contains("Measured, in studs"))
	said = await _call("edit_model", {"recolor": [{"bricks": [first], "color": 4}], "picture": false})
	_check("picture=false: words alone", _images(said) == 0 and _text(said).begins_with("Done."))


func _looks() -> void:
	print("── the sizes once a change, the tally of what was asked ──")
	var said: Array = await _call("view_model", {"from": "corner"})
	_check("view_model of a model whose sizes were said leaves them out",
		not _text(said).contains("Measured, in studs"))
	# The highest part off, so the model is lower: its sizes change.
	var top: int = _highest_brick()
	var off: String = _text(await _call("edit_model", {"remove": [top], "picture": false}))
	_check("an edit that changes the sizes says them: %s" % off.get_slice("\n", 1),
		off.begins_with("Done.") and off.contains("Measured, in studs"))
	said = await _call("view_model", {"from": "corner"})
	_check("...and the look after it does not say them again",
		not _text(said).contains("Measured, in studs"))
	await _call("undo", {})
	var whole: String = _text(await _call("look_at_model", {}))
	_check("a look at the whole tallies the whole", whole.contains("Parts and colours, most first:"))
	var near: String = _text(await _call("look_at_model", {"where": {"x_from": -100, "x_to": 100,
		"z_from": -100, "z_to": 100, "y_from": 0, "y_to": 1}}))
	_check("a look at a section listed whole has no tally of the whole: %s" % near.get_slice("\n", 1),
		near.contains("you asked about") and not near.contains("Parts and colours"))


func _highest_brick() -> int:
	var assistant: Assistant = _main.get("_assistant")
	var best: int = 0
	var height: float = -INF
	for brick: BrickWorld.Brick in _world.bricks():
		if assistant.scenery.has(brick.id):
			continue
		var corners: Array = assistant._corners_in_studs(brick)
		if not corners.is_empty() and (corners[1] as Vector3).y > height:
			height = (corners[1] as Vector3).y
			best = brick.id
	return best


func _first_brick() -> int:
	var lowest: int = 0
	var assistant: Assistant = _main.get("_assistant")
	for brick: BrickWorld.Brick in _world.bricks():
		if assistant.scenery.has(brick.id):
			continue
		if lowest == 0 or brick.id < lowest:
			lowest = brick.id
	return lowest


## Every brick's part, colour and place, to tell a change.
func _standing() -> String:
	var rows: PackedStringArray = PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		rows.append("%d %s %d %s" % [brick.id, brick.part_id, brick.color_code, str(brick.transform)])
	rows.sort()
	return "\n".join(rows)


func _call(tool: String, arguments: Dictionary) -> Array:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	return ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []) as Array


static func _text(blocks: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
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


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
