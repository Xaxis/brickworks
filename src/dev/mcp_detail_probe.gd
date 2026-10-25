## The detail pass offers a feature only a piece that is right where it goes.
##
##   godot --headless --path . --script src/dev/mcp_detail_probe.gd
##
## walk256 (bench/results/walk256-2026-10-25, findings M17): of the four
## pieces the app laid for its lighthouse's features, the session rejected
## three: the cottage door laid on the ground in front of its wall, stuck on
## outside it and a course taller; the windows on the ground outside the wall;
## a Parisian restaurant's chimney stack, 3 by 5 studs, on a cottage 8 by 6.
## Here walk256's own design (tests/fixtures/mcp/walk256_lighthouse.json) is
## submitted over the MCP port and each of those features reviewed: a door or
## a window is offered only standing upright in its wall's plane, else none
## with why; a chimney only at most half what it stands on each way. And a
## wall with an opening left for its door is offered a real door in the
## opening, so the check drops what fails, not every piece. Needs the real-set
## index (tools/snippets.py build); says SKIP without it. Exits non-zero when
## a piece is offered where it does not belong.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _assistant: Assistant
var _world: BrickWorld
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if not RealSnippets.available():
		print("SKIP no real-set index at %s (tools/snippets.py build)" % RealSnippets.INDEX)
		quit(0)
		return
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
	(_main.get("_store") as ModelStore).keeps = false
	_assistant = _main.get("_assistant")
	_world = _main.get("_world")
	await _lighthouse()
	await _door_in_its_opening()
	print("")
	print("detail: each feature is offered a piece that is right where it goes, or none "
		+ "and why" if _failures == 0 else "detail: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _lighthouse() -> void:
	print("── walk256's lighthouse: the cottage's door, windows and chimney ──")
	await _call("clear_model", {})
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/mcp/walk256_lighthouse.json"))
	var built: String = _text(await _call("submit_design", design))
	_check("walk256's design stands: %s" % built.get_slice("\n", 0).left(60),
		built.begins_with("Built."))
	# The cottage's front wall faces +z at z=13, from y=6 up to the roof at 18.
	for feature: String in ["cottage door", "cottage windows"]:
		var said: String = _text(await _call("review_model", {"feature": feature}))
		var box: AABB = _laid_box(feature)
		var one: FeaturePass.Proposal = _assistant.feature_pass().proposal(feature)
		if box.size.length() > 0.0:
			_check("%s: laid upright in the wall's plane: %s to %s studs deep" % [feature,
				_studs(box.position.z), _studs(box.end.z)],
				str((one.copies[0] as Dictionary)["up"]) == "up"
					and box.position.z <= 12.5 * FeaturePass.STUD + 0.01
					and box.end.z <= 13.5 * FeaturePass.STUD + 0.01)
		else:
			_check("%s: none offered, and why: %s" % [feature, _line_with(said, "No real set").left(160)],
				said.contains("No real set's piece") and said.contains("outside the wall"))
		await _call("settle_feature", {"feature": feature, "verdict": "built",
			"reason": "the design sets it in the wall itself"})
	var chimney: String = _text(await _call("review_model", {"feature": "chimney"}))
	var cottage: AABB = _assistant._bounds_of(_assistant._bricks_inside({"x_from": 13,
		"x_to": 21, "y_from": 6, "y_to": 30, "z_from": 7, "z_to": 13}))
	var stack: AABB = _laid_box("chimney")
	_check("chimney: %s, on a cottage %s by %s studs" % ["a piece %s by %s studs, %s plates"
		% [_studs(stack.size.x), _studs(stack.size.z), _plates(stack.size.y)]
			if stack.size.length() > 0.0 else _line_with(chimney, "No real set").left(120),
		_studs(cottage.size.x), _studs(cottage.size.z)],
		stack.size.length() <= 0.0 or (stack.size.x <= 0.5 * cottage.size.x + 1.0
			and stack.size.z <= 0.5 * cottage.size.z + 1.0))


func _door_in_its_opening() -> void:
	print("── a wall with an opening left for its door ──")
	await _call("clear_model", {})
	# A wall a stud thick along x, its face to +z at z=6, eight courses on a
	# row of plates, with an opening four studs wide and six courses tall
	# left in its middle and bridged above.
	var bricks: Array = []
	for x: int in range(0, 16, 4):
		bricks.append({"part": "3710", "color": 71, "x": x, "y": 0, "z": 5, "rot": 0})
	for course: int in 8:
		var y: int = 1 + 3 * course
		# Each run in a running bond, halves at its ends on every other course:
		# the two piers either side of the opening, then the courses over it.
		var runs: Array = [[0, 6], [10, 16]] if course < 6 else [[0, 16]]
		for run: Array in runs:
			var x: int = run[0]
			if course % 2 == 1:
				bricks.append({"part": "3005", "color": 15, "x": x, "y": y, "z": 5, "rot": 0})
				x += 1
			while x + 2 <= int(run[1]):
				bricks.append({"part": "3004", "color": 15, "x": x, "y": y, "z": 5, "rot": 0})
				x += 2
			if x < int(run[1]):
				bricks.append({"part": "3005", "color": 15, "x": x, "y": y, "z": 5, "rot": 0})
	var wall: String = _text(await _call("submit_design", {"name": "House",
		"description": "a small house with a front door",
		"features": [{"name": "front door", "x": 8, "y": 1, "z": 6, "facing": "+z"}],
		"bricks": bricks}))
	_check("the wall stands: %s" % wall.get_slice("\n", 0).left(80), wall.begins_with("Built."))
	var said: String = _text(await _call("review_model", {"feature": "front door"}))
	var box: AABB = _laid_box("front door")
	_check("a real door is laid in the opening: %s; %s to %s studs across, %s to %s deep"
		% [_line_with(said, "\"").strip_edges().left(240), _studs(box.position.x), _studs(box.end.x),
			_studs(box.position.z), _studs(box.end.z)],
		box.size.length() > 0.0 and box.position.x >= 5.9 * FeaturePass.STUD
			and box.end.x <= 10.1 * FeaturePass.STUD and box.position.z <= 5.5 * FeaturePass.STUD)


## What the app laid for [param feature], in LDU; empty when it laid none.
func _laid_box(feature: String) -> AABB:
	var one: FeaturePass.Proposal = _assistant.feature_pass().proposal(feature)
	var box := AABB()
	if one == null or one.piece.is_empty():
		return box
	var bricks: Array[BrickWorld.Brick] = []
	for id: int in one.ids:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		if brick != null:
			bricks.append(brick)
	return _assistant._bounds_of(bricks)


static func _studs(ldu: float) -> String:
	return str(snappedf(ldu / FeaturePass.STUD, 0.1))


static func _plates(ldu: float) -> String:
	return str(snappedf(ldu / FeaturePass.PLATE, 0.5))


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


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
