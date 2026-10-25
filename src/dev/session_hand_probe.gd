## A session's call leaves nothing in the person's hand, and the model it
## changed in view.
##
##   godot --headless --path . --script src/dev/session_hand_probe.gd
##
## walk239 (2026-10-24, M13 and M4): after a subscription session designed
## a taco truck and printed its signs, the desktop was left "Placing Panel
## 1 x 4 x 3 … TACOS roof sign: click puts one down" (print_part's print was
## put in hand, as a person's own new print is), and the view was on a
## corner of the truck, framed as it was before the session built it, so
## the person's first click dropped a stray panel. Here, over the session's
## own tool calls (CommandSocket.answer_rpc), with Select in hand: a row of
## bricks forty studs long added by edit_model is framed whole after the
## call; a print_part leaves Select in hand and no part; with a 1 x 2 in
## hand, a print_part leaves the 1 x 2 in hand; and a look that changes
## nothing leaves the view where the person turned it.
extends SceneTree

var _failures: int = 0
var _next: int = 0
var _socket: CommandSocket
var _main: Node
var _builder: Builder
var _verbs: EditVerbs
var _camera: CadCamera
var _world: BrickWorld


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	CustomParts.keeps = false
	CustomParts.dir = "user://session_hand_probe_parts/"
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: Node = _main.get("_playback")
	if playback != null:
		playback.call("stop")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_main.call("clear_model")
	for _n: int in 10:
		await process_frame
	_verbs.set_mode("select")
	_camera.frame(AABB(Vector3(-40, 0, -40), Vector3(80, 40, 80)))
	await _settle()

	print("a row of bricks forty studs long, added by a session")
	var said: String = await _say("edit_model", {"add": [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0},
		{"part": "3001", "color": 4, "x": 40, "y": 0, "z": 0},
		{"part": "3001", "color": 4, "x": 40, "y": 0, "z": 20}], "picture": false})
	await _settle()
	print("    %s" % said.left(160))
	var bricks: int = _world.brick_count() - (_main.get("_store") as ModelStore).scenery.size()
	_check("the three bricks went down (%d)" % bricks, bricks == 3)
	_check("...and the view frames all of them after the call (%s)" % _in_view(),
		_in_view() == "all in view")

	print("print_part, with Select in hand")
	var target: int = _first_brick()
	said = await _say("print_part", {"brick": target, "name": "Sign",
		"svg": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 40 20'><rect width='40' height='20' fill='#ffcc00'/></svg>"})
	await _frames(4)
	print("    %s" % said.left(160))
	_check("printed (%s)" % said.left(40), said.begins_with("Printed"))
	_check("...and the person's hand is as it was: %s, %s" % [_verbs.mode, _hand()],
		_verbs.mode == "select" and not _builder.held_part.begins_with("bw-")
		and not _builder.is_carrying())

	print("print_part, with a 1 x 2 in hand")
	_main.call("_on_part_chosen", "3004")
	await _frames(2)
	var colour: int = _builder.held_color
	target = _first_brick()
	said = await _say("print_part", {"brick": target, "name": "Sign again",
		"svg": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 40 20'><rect width='40' height='20' fill='#0055bf'/></svg>"})
	await _frames(4)
	_check("printed (%s)" % said.left(40), said.begins_with("Printed"))
	_check("...and the 1 x 2 is still in hand, to put down: %s, %s" % [_verbs.mode, _hand()],
		_verbs.mode == "place" and _builder.held_part == "3004" and _builder.held_color == colour)
	_verbs.set_mode("select")

	print("a look that changes nothing")
	_camera.frame(AABB(Vector3(-10, 0, -10), Vector3(20, 20, 20)))
	await _settle()
	var aimed: Array = _aim()
	said = await _say("look_at_model", {})
	await _settle()
	_check("look_at_model leaves the view where the person turned it (%s, then %s)" % [aimed, _aim()],
		_aim() == aimed)

	print("")
	print("session_hand: %s" % ("all checks passed" if _failures == 0
		else "%d check(s) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _hand() -> String:
	return "holding %s" % _builder.held_part if _verbs.mode == "place" else "nothing in hand"


func _first_brick() -> int:
	var store: ModelStore = _main.get("_store")
	var best: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not store.scenery.has(brick.id) and (best == 0 or brick.id > best):
			best = brick.id
	return best


## Whether every corner of what is built is in front of the camera and on
## the screen.
func _in_view() -> String:
	var box: AABB = _main.call("_built_bounds")
	var size: Vector2 = _camera.get_viewport().get_visible_rect().size
	var out: int = 0
	for n: int in 8:
		var corner: Vector3 = box.get_endpoint(n)
		var at: Vector2 = _camera.unproject_position(corner)
		if _camera.is_position_behind(corner) or at.x < 0 or at.y < 0 or at.x > size.x or at.y > size.y:
			out += 1
	return "all in view" if out == 0 else "%d of 8 corners out of view" % out


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	var said: String = ""
	for block: Dictionary in (await _rpc("tools/call", {"name": tool, "arguments": arguments})) \
			.get("content", []):
		said += str(block.get("text", ""))
	return said


## Where the view is going: its turn, tilt, distance and focus.
func _aim() -> Array:
	return [snappedf(_camera.get("_target_yaw"), 0.0001), snappedf(_camera.get("_target_pitch"), 0.0001),
		snappedf(_camera.get("_target_distance"), 0.01), (_camera.get("_target_focus") as Vector3).snappedf(0.01)]


## Until the view has eased to where it is going.
func _settle() -> void:
	var was: Transform3D = _camera.global_transform
	var still: int = 0
	for _n: int in 600:
		await process_frame
		var now: Transform3D = _camera.global_transform
		still = still + 1 if now.is_equal_approx(was) else 0
		was = now
		if still >= 5:
			return


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
