## A design Claude finishes in the panel is framed whole, as Frame all frames it.
##
##   godot --path . --resolution 1280x720 --script src/dev/design_frame_probe.gd
##   godot --path . --resolution 1400x900 --script src/dev/design_frame_probe.gd
##
## The app's own designs were framed only when the window was out of view: in
## view the camera stayed where it was, on the example car a first visit opens
## on, and a tower built in its place went up out of the top of the window
## (drawn_flow's build_again_1_after, 2026-11-01). A session's call is framed
## as it ends (Main.after_session_call); the panel's design was not.
##
## Here the real app is asked in the panel as a person asks, the loop's
## requests answered by a stand-in for Anthropic's API on this machine (as
## design_undo_probe answers them): a tower sixteen bricks tall on the first
## visit's car, then a wall twenty-four bricks long on a new model. Once each
## ends and the view has come to rest, every corner of what was built is
## inside the part of the window the model is seen in, and the view is the one
## Frame all gives. A change that takes the tower out of a view that showed it
## whole is framed again; a person who turns the view as Claude works, or is
## looking closely at part of the model, keeps their view. Undo takes the wall
## off and Redo puts it up whole in view. Pictures in shots/design_frame/.
extends SceneTree

const SHOTS := "res://shots/design_frame/"
const TALL := 16
const LONG := 24

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _store: ModelStore
var _camera: CadCamera
var _library: PartLibrary
var _api: _Api
var _notes: PackedStringArray = []
var _size: String = ""
## Where the view was going just after the person turned it (_ask's meanwhile).
var _meanwhile_aim: Array = []


## A stand-in for the Messages API: each POST answered with the next reply
## written here, and "Done." once they run out.
class _Api extends Node:
	var replies: Array = []
	var asked: int = 0
	var port: int = 0
	var _server := TCPServer.new()
	var _peers: Array = []

	func _init() -> void:
		for wanted: int in range(8931, 9010):
			if _server.listen(wanted, "127.0.0.1") == OK:
				port = wanted
				return

	func _process(_delta: float) -> void:
		while _server.is_connection_available():
			_peers.append([_server.take_connection(), PackedByteArray()])
		for held: Array in _peers.duplicate():
			var peer: StreamPeerTCP = held[0]
			peer.poll()
			if peer.get_available_bytes() > 0:
				held[1] = (held[1] as PackedByteArray) \
					+ (peer.get_data(peer.get_available_bytes())[1] as PackedByteArray)
			var got: PackedByteArray = held[1]
			var text: String = got.get_string_from_utf8()
			var cut: int = text.find("\r\n\r\n")
			if cut < 0:
				continue
			var length: RegExMatch = RegEx.create_from_string("(?i)content-length: *(\\d+)") \
				.search(text.left(cut))
			if length != null and got.size() < cut + 4 + int(length.get_string(1)):
				continue
			asked += 1
			var reply: Dictionary = replies.pop_front() if not replies.is_empty() \
				else {"content": [{"type": "text", "text": "Done."}], "stop_reason": "end_turn"}
			var bytes: PackedByteArray = JSON.stringify(reply).to_utf8_buffer()
			peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
				+ "Content-Length: %d\r\nConnection: close\r\n\r\n" % bytes.size()).to_utf8_buffer())
			peer.put_data(bytes)
			peer.disconnect_from_host()
			_peers.erase(held)

	func _exit_tree() -> void:
		_server.stop()


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	_world = _main.get("_world")
	_store = _main.get("_store")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	var assistant: Assistant = _main.get("_assistant")
	var chat: ChatPanel = _main.get("_chat")
	if chat == null:
		_main.call("_make_chat")
		chat = _main.get("_chat")
	if _world == null or _camera == null or assistant == null or chat == null:
		print("  FAIL  no world, camera, assistant, panel or edit verbs")
		quit(1)
		return
	var room: Vector2 = root.get_visible_rect().size
	_size = "%dx%d" % [roundi(room.x), roundi(room.y)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	assistant.progress.connect(func(note: String) -> void: _notes.append(note))
	_api = _Api.new()
	root.add_child(_api)
	assistant.endpoint = "http://127.0.0.1:%d/v1/messages" % _api.port
	assistant.stream_replies = false
	# A key for this run only, written nowhere, and sent nowhere but the
	# stand-in above.
	OwnKey._this_visit = "sk-ant-probe-design-frame-0000000000000000000000000000"
	var ended: Array = []
	assistant.finished.connect(func(ok: bool, summary: String) -> void:
		ended.append([ok, summary]))

	print("\n%s: a first visit's car, and a tower asked for in the panel" % _size)
	await _rest()
	var car: int = _parts()
	_ok(car > 0 and bool(_main.get("_sample_untouched")),
		"a first visit opens on the example car (%d parts)" % car)
	var car_seen: String = _whole_in_view("the car")
	_ok(car_seen.is_empty(), "...whole in view %s" % car_seen)
	_api.replies = [_reply("A tower", _tower(TALL))]
	await _ask(chat, "a tower of red and yellow bricks", ended)
	_ok(not ended.is_empty() and bool(ended.back()[0]),
		"the run ends well: %s" % (str(ended.back()[1]).left(80) if not ended.is_empty() else "never"))
	_ok(_parts() >= TALL, "the tower stands, %d parts, the car off" % _parts())
	await _rest()
	_shoot("tower")
	var seen: String = _whole_in_view("the tower")
	_ok(seen.is_empty(), "the finished tower is whole in view %s" % seen)
	_ok(_framed_as_frame_all(), "...framed as Frame all frames it")

	print("\na change that takes the tower out of a view that showed it whole")
	var taller: Array = _tower(TALL + 6)
	_api.replies = [_reply("A taller tower", taller)]
	await _ask(chat, "six bricks taller", ended)
	await _rest()
	_ok(_parts() >= TALL + 6, "the tower is six bricks taller (%d parts)" % _parts())
	seen = _whole_in_view("the taller tower")
	_ok(seen.is_empty(), "...and whole in view again %s" % seen)

	print("\na person who turns the view while Claude works keeps it")
	_api.replies = [_reply("A taller tower still", _tower(TALL + 10))]
	var asked_aim: Array = _aim()
	await _ask(chat, "four bricks taller", ended, func() -> void:
		_camera.key_turn(Vector2(1.0, 0.0)))
	await _rest()
	_ok(_parts() >= TALL + 10, "the tower is four bricks taller (%d parts)" % _parts())
	_ok(_meanwhile_aim != asked_aim and _aim() == _meanwhile_aim,
		"...and the view is the one the person turned it to: asked at %s, turned to %s, now %s"
		% [str(asked_aim), str(_meanwhile_aim), str(_aim())])

	print("\na person looking closely at part of it keeps that")
	_camera.key_zoom(6)
	await _rest()
	seen = _whole_in_view("the tower")
	_ok(not seen.is_empty(), "zoomed in, the tower is not whole in view")
	var theirs: Array = _aim()
	_api.replies = [_reply("Taller again", _tower(TALL + 12))]
	await _ask(chat, "two bricks taller", ended)
	await _rest()
	_ok(_parts() >= TALL + 12, "the tower is two bricks taller (%d parts)" % _parts())
	_ok(_aim() == theirs, "...and the view is still the close one")

	print("\na wall on a new model")
	await (_main.get("_bar") as ModelBar)._start_new()
	await _rest()
	var wall: Array = []
	for n: int in LONG:
		wall.append({"part": "3001", "color": 4 if n % 2 == 0 else 14,
			"x": 4 * n - 2 * LONG, "y": 0, "z": 0, "rot": 0})
	_api.replies = [_reply("A wall", wall)]
	await _ask(chat, "a long low wall of red and yellow bricks", ended)
	_ok(_parts() >= LONG, "the wall stands, %d parts" % _parts())
	await _rest()
	_shoot("wall")
	seen = _whole_in_view("the wall")
	_ok(seen.is_empty(), "the finished wall is whole in view %s" % seen)
	_ok(_framed_as_frame_all(), "...framed as Frame all frames it")

	print("\nUndo and Redo of the wall")
	var verbs: EditVerbs = _main.get("_verbs")
	var walled: int = _parts()
	await verbs.press("undo")
	await _rest()
	_ok(_parts() == 0, "Undo takes the wall off, one step (%d parts)" % _parts())
	_shoot("undone")
	await verbs.press("redo")
	await _rest()
	_ok(_parts() == walled, "Redo puts the wall up again (%d parts)" % _parts())
	seen = _whole_in_view("the wall")
	_ok(seen.is_empty(), "...whole in view %s" % seen)

	print("\ndesign_frame %s: %s" % [_size,
		"every check passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures > 0 else 0)


## Asked in the panel as a person asks, a design rather than three sketches;
## [param meanwhile] is what the person does as soon as it is asked.
func _ask(chat: ChatPanel, words: String, ended: Array, meanwhile: Callable = Callable()) -> void:
	var was: int = ended.size()
	chat._input.text = words
	chat._sketch_first.button_pressed = false
	_notes = []
	chat._on_send()
	if meanwhile.is_valid():
		meanwhile.call()
		_meanwhile_aim = _aim()
	var until: int = Time.get_ticks_msec() + 300000
	while ended.size() == was and Time.get_ticks_msec() < until:
		await process_frame
	if ended.size() == was:
		print("  (no end after %d requests: %s)" % [_api.asked, " / ".join(_notes.slice(-12))])
	var playback: BuildPlayback = _main.get("_playback")
	var played: int = Time.get_ticks_msec() + 10000
	while playback != null and playback.is_playing() and Time.get_ticks_msec() < played:
		await process_frame


## Until the view has come to rest where it is going.
func _rest() -> void:
	for _n: int in 20:
		await process_frame
	var until: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until:
		var target: float = float(_camera.get("_target_distance"))
		var focus: Vector3 = _camera.get("_target_focus")
		if absf(_camera.distance_now() - target) <= 0.002 * target \
				and _camera.focus_now().distance_to(focus) <= 0.5:
			break
		await process_frame
	for _n: int in 5:
		await process_frame


## "" when every corner of what is built is drawn inside the part of the window
## the model is seen in; else where it goes out, and where the top part is.
func _whole_in_view(what: String) -> String:
	var seen: Rect2 = _camera.seen_rect()
	var box: AABB = _main.call("_model_bounds")
	var out: PackedStringArray = []
	for n: int in 8:
		var corner: Vector3 = box.get_endpoint(n)
		var at: Vector2 = _camera.unproject_position(corner)
		if _camera.is_position_behind(corner) or not seen.has_point(at):
			out.append("(%d, %d)" % [roundi(at.x), roundi(at.y)])
	var top: Rect2 = _top_on_screen()
	var said: String = "(the view %s, the top part %s)" % [_rect(seen), _rect(top)]
	return "" if out.is_empty() else "%s: %s goes out at %s %s" % ["NOT", what, ", ".join(out), said]


## The highest part's corners as drawn: the box round them.
func _top_on_screen() -> Rect2:
	var top: BrickWorld.Brick = null
	var top_box := AABB()
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = (brick.transform * part.bounds).abs()
		if top == null or box.end.y > top_box.end.y:
			top = brick
			top_box = box
	var rect := Rect2()
	for n: int in 8:
		var at: Vector2 = _camera.unproject_position(top_box.get_endpoint(n))
		rect = Rect2(at, Vector2.ZERO) if n == 0 else rect.expand(at)
	return rect


## Whether the view is the one Frame all (F, Home) would go to now.
func _framed_as_frame_all() -> bool:
	var now: Array = _aim()
	var was: Dictionary = _camera.aim()
	var target: float = float(_camera.get("_target_distance"))
	var focus: Vector3 = _camera.get("_target_focus")
	_camera.frame(_main.call("_built_bounds"))
	var frame_all: float = float(_camera.get("_target_distance"))
	var frame_focus: Vector3 = _camera.get("_target_focus")
	print("        distance %.1f, Frame all's %.1f; focus %s, Frame all's %s"
		% [target, frame_all, focus.snappedf(0.1), frame_focus.snappedf(0.1)])
	_camera.aim_at(was)
	return _aim() == now and now.size() == 4 and absf(target - frame_all) <= 0.01 * frame_all \
		and focus.distance_to(frame_focus) <= 1.0


## [param count] 2 x 4 bricks stacked, red and yellow in turn.
func _tower(count: int) -> Array:
	var bricks: Array = []
	for n: int in count:
		bricks.append({"part": "3001", "color": 4 if n % 2 == 0 else 14,
			"x": 0, "y": 3 * n, "z": 0, "rot": 0})
	return bricks


func _aim() -> Array:
	return _main.call("_camera_aim")


func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


func _shoot(name: String) -> void:
	var picture: Image = root.get_texture().get_image()
	if picture != null:
		picture.save_png(ProjectSettings.globalize_path(SHOTS + "%s_%s.png" % [name, _size]))


func _rect(rect: Rect2) -> String:
	return "%d,%d %dx%d" % [roundi(rect.position.x), roundi(rect.position.y),
		roundi(rect.size.x), roundi(rect.size.y)]


func _reply(name: String, bricks: Array) -> Dictionary:
	return {"content": [{"type": "tool_use", "id": "toolu_probe_%d" % randi(),
		"name": "submit_design", "input": {"name": name, "description": name.to_lower(),
		"bricks": bricks}}], "stop_reason": "tool_use"}


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
