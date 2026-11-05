## A moulded animal goes on studs the way it does in a real set: put there by
## hand and by Claude over MCP, and a creature that is one part is not sent
## back for having no joints.
##
##   env -u WAYLAND_DISPLAY MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" \
##     godot --path . --resolution 1400x900 --script src/dev/moulded_animal_probe.gd
##
## design16's Gandalf sessions (bench/results/realset-2026-11-05-d16base and
## -d16lev2, set 9469) both chose the set's own horse, 10509p02, and neither
## could stand it on a plate. The check seated its hooves on the studs and
## then refused it, "its tubes land between that part's studs", more than a
## dozen times; "the app's two checks disagree about where its hooves land".
## And the creature rule sent the design back: "nothing in it is on a joint".
##
## The horse's hooves are drawn (stud23, a stud's square socket) 6 LDU along
## its length off the grid of the two studs on its back, which LDraw's own
## file says: "Offset by z=-4 to get feet on stud grid". The seat reads the
## hooves; the stud check read the part's corner, which is on its back's grid,
## and its sockets, which the catalogue laid as squares on that grid, 6 LDU
## from every hoof. So, each the way a session or a person does it:
##   - by Claude: edit_model puts it on a plate at whole studs, and by its
##     hoof's connector (attach, as the second session did), and moves one a
##     person put down: each stands with its hooves on the studs, and nothing
##     says it is off them;
##   - by hand: taken from the bin and aimed at the plate, its ghost stands
##     with its hooves on the studs, and goes down there;
##   - the creature rule: a design whose creature is the moulded horse is
##     built, and one of stacked bricks is still sent back once.
## Pictures of each go to shots/moulded_animal/.
extends SceneTree

const HORSE := "10509p02"
## An 8 x 8 plate, the horse's ground.
const PLATE := "41539"
## How near a stud a hoof has to be to be on it, in LDU across.
const ON_A_STUD := 0.5

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _assistant: Assistant
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_assistant = _main.get("_assistant")
	_socket = CommandSocket.new()
	_socket.assistant = _assistant
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	_where_the_hooves_are()
	await _by_claude()
	await _by_hand()
	await _the_creature_rule()
	print("")
	print("moulded animal: %s" % ("every check passed" if _failures == 0
		else "%d FAILED" % _failures))
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## Where the horse takes a stud, as each reader has it: the hooves it draws
## (its downward tubes, which the seat goes by) and its sockets (which the
## stud check, a drag's snap, the booklet's support and the balance read).
func _where_the_hooves_are() -> void:
	print("── where the horse takes a stud ──")
	var mesh: Lbm.PartMesh = _library.mesh_for(HORSE)
	var drawn: Array = []
	for c: Lbm.Connector in mesh.connectors:
		if c.kind == "tube" and c.axis.y < -0.99:
			drawn.append(Vector2(c.position.x, c.position.z))
	print("    drawn hooves %s; sockets %s" % [drawn, mesh.sockets])
	var worst: float = 0.0
	for socket: Vector2 in mesh.sockets:
		var nearest: float = INF
		for hoof: Vector2 in drawn:
			nearest = minf(nearest, socket.distance_to(hoof))
		worst = maxf(worst, nearest)
	_check("every socket is a hoof it draws, to a fifth of an LDU (worst %.1f LDU off)" % worst,
		mesh.sockets.size() == drawn.size() and worst <= 0.21)


# -- by Claude --------------------------------------------------------------------


func _by_claude() -> void:
	print("── by Claude, over MCP ──")
	_main.call("clear_model")
	await _frames(4)
	# Where a session first puts it: whole studs, along the plate.
	var said: String = await _say("edit_model", {"add": [
		{"part": PLATE, "color": 2, "x": 0, "y": 0, "z": 0, "name": "base"},
		{"part": HORSE, "color": 70, "x": 1, "y": 1, "z": 3, "rot": 1, "name": "horse"}]})
	print("    " + _first_lines(said))
	_stands_on_its_studs("put at whole studs", said)
	await _shot("claude_whole_studs")
	# By its hoof, as design16's second session did (hole[1] on stud 63).
	_main.call("clear_model")
	await _frames(4)
	said = await _say("edit_model", {"add": [
		{"part": PLATE, "color": 2, "x": 0, "y": 0, "z": 0, "name": "base"},
		{"part": HORSE, "color": 70, "name": "horse",
			"attach": {"to": "base.stud[27]", "by": "hole[1]", "orient": {"yaw": 270}}}]})
	print("    " + _first_lines(said))
	_stands_on_its_studs("put by its hoof's connector", said)
	# Moved a stud along, as a session moves what stands.
	said = await _say("edit_model", {"move": [{"bricks": [_number(HORSE)], "dx": 1}]})
	print("    " + _first_lines(said))
	_stands_on_its_studs("moved a stud along", said)


## Whether the horse stands, the edit [param said] applied, with every hoof on
## a stud of the plate, and nothing said of it being off them.
func _stands_on_its_studs(how: String, said: String) -> void:
	var horse: BrickWorld.Brick = _world.get_brick(_brick(HORSE))
	var plate: BrickWorld.Brick = _world.get_brick(_brick(PLATE))
	_check("%s, it is applied and nothing says it is off its studs" % how,
		horse != null and plate != null and not said.begins_with("Not applied")
		and not said.contains("off its studs") and not said.contains("tubes land between"))
	if horse == null or plate == null:
		return
	var off: float = _hooves_off(horse.transform, plate)
	_check("...and every hoof stands on a stud of the plate (worst %.2f LDU off)" % off,
		off <= ON_A_STUD)


# -- by hand ----------------------------------------------------------------------


func _by_hand() -> void:
	print("── by hand ──")
	_main.call("clear_model")
	await _frames(4)
	await _say("edit_model", {"add": [{"part": PLATE, "color": 2, "x": 0, "y": 0, "z": 0}]})
	var plate: BrickWorld.Brick = _world.get_brick(_brick(PLATE))
	var mesh: Lbm.PartMesh = _library.mesh_for(PLATE)
	var top: AABB = (plate.transform * mesh.bounds).abs()
	_camera.frame(top.grow(120.0))
	_camera.look_from(Vector3(0.35, 0.8, 0.5).normalized())
	await _frames(40)
	_main.call("_on_part_chosen", HORSE)
	for _n: int in 600:
		if _library.mesh_for(HORSE) != null:
			break
		await process_frame
	await _key(KEY_R)
	var point: Vector2 = _camera.unproject_position(
		Vector3(top.get_center().x + 6.0, top.end.y, top.get_center().z + 4.0))
	await _move(point + Vector2(0, 1))
	await _move(point)
	var ghost: Transform3D = _builder.ghost_transform()
	var aimed: float = _hooves_off(ghost, plate)
	print("    the ghost stands at %s, %s; its hooves %.1f LDU off the studs at worst"
		% [ghost.origin, "green" if _builder.can_place() else "red", aimed])
	_check("the horse in hand, aimed at the plate, can go down there", _builder.can_place())
	_check("...with every hoof on a stud (worst %.2f LDU off)" % aimed, aimed <= ON_A_STUD)
	await _shot("hand_aimed")
	await _click(point)
	var horse: BrickWorld.Brick = _world.get_brick(_brick(HORSE))
	_check("clicked, the horse is down", horse != null)
	if horse != null:
		var off: float = _hooves_off(horse.transform, plate)
		_check("...where its ghost stood, every hoof on a stud (worst %.2f LDU off)" % off,
			off <= ON_A_STUD and horse.transform.origin.distance_to(ghost.origin) < 0.01)
	await _key(KEY_ESCAPE)
	# And Claude, asked to check what the person built, finds it on its studs.
	var said: String = await _say("edit_model", {"move": [{"bricks": [_number(HORSE)],
		"dz": 1}]})
	print("    " + _first_lines(said))
	_stands_on_its_studs("put down by hand, then moved by Claude", said)
	await _shot("hand_placed")


# -- the creature rule ------------------------------------------------------------


func _the_creature_rule() -> void:
	print("── the creature rule ──")
	_main.call("clear_model")
	await _frames(4)
	# design16's second session's words, which the rule read as a creature's.
	var brief: String = ("Gandalf Arrives, in the style of LEGO® The Hobbit and Lord of the "
		+ "Rings sets: fitting in about 7 x 17 studs, 70 to 120 pieces.")
	var about: String = "Test: lane and horse."
	var kind: String = Style.character_of("%s Gandalf Arrives %s" % [brief, about])
	_check("the design is a creature's, so the rule is asked (%s)" % kind, kind == "creature")
	_assistant.heard(brief, true)
	# The horse along the plate's middle, the cart's bed beside it.
	var cart: Array = [
		{"part": PLATE, "color": 2, "x": 0, "y": 0, "z": 0, "name": "base"},
		{"part": HORSE, "color": 70, "x": 1, "y": 1, "z": 3, "rot": 1},
		{"part": "3034", "color": 6, "x": 0, "y": 1, "z": 6, "rot": 1},
		{"part": "3010", "color": 6, "x": 0, "y": 2, "z": 6, "rot": 1},
		{"part": "3010", "color": 6, "x": 4, "y": 2, "z": 6, "rot": 1},
		{"part": "3062b", "color": 14, "x": 0, "y": 1, "z": 0}]
	var said: String = await _say("submit_design", {"name": "Gandalf Arrives",
		"description": about, "brief": brief, "floor": "none", "bricks": cart})
	print("    " + _first_lines(said))
	_check("a design whose creature is the moulded horse is built, not sent back",
		not said.begins_with("Not applied") and not said.contains("nothing in it is on a joint"))
	_check("...and its horse stands", _brick(HORSE) != 0)
	# Kept for a creature of stacked bricks: it is sent back once.
	_main.call("clear_model")
	await _frames(4)
	_assistant.heard("a horse standing in a field", true)
	var stacked: Array = [{"part": PLATE, "color": 2, "x": 0, "y": 0, "z": 0}]
	for n: int in 4:
		stacked.append({"part": "3001", "color": 70, "x": 2, "y": 1 + 3 * n, "z": 3, "rot": 1})
	stacked.append({"part": "3003", "color": 70, "x": 0, "y": 13, "z": 3})
	said = await _say("submit_design", {"name": "Horse", "description": "a horse",
		"floor": "none", "bricks": stacked})
	print("    " + _first_lines(said))
	_check("a horse of stacked bricks is still sent back once",
		said.begins_with("Not applied, this once"))


# -- helpers ----------------------------------------------------------------------


## The worst of the horse's hooves at [param at] from the nearest stud of
## [param plate], in LDU across.
func _hooves_off(at: Transform3D, plate: BrickWorld.Brick) -> float:
	var horse: Lbm.PartMesh = _library.mesh_for(HORSE)
	var mesh: Lbm.PartMesh = _library.mesh_for(plate.part_id)
	var worst: float = 0.0
	for hoof: Lbm.Connector in horse.connectors:
		if hoof.kind != "tube" or hoof.axis.y > -0.99:
			continue
		var foot: Vector3 = at * hoof.position
		var nearest: float = INF
		for stud: Lbm.Connector in mesh.connectors:
			if stud.kind != "stud" or stud.axis.y < 0.99:
				continue
			var top: Vector3 = plate.transform * stud.position
			nearest = minf(nearest, Vector2(foot.x - top.x, foot.z - top.z).length())
		worst = maxf(worst, nearest)
	return worst


## The newest brick of [param part], or 0.
func _brick(part: String) -> int:
	var found: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			found = maxi(found, brick.id)
	return found


## The number edit_model knows the newest brick of [param part] by, as a
## session reads the model; -1 where there is none.
func _number(part: String) -> int:
	var placements: Array = _assistant._model_from_world().placements
	for n: int in placements.size():
		if placements[n].id == _brick(part):
			return n
	return -1


func _first_lines(text: String) -> String:
	return text.left(700).replace("\n", " | ")


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var result: Dictionary = (answer as Dictionary).get("result", {}) as Dictionary
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	await _frames(4)
	return text


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _click(at: Vector2) -> void:
	await _move(at)
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/moulded_animal/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/moulded_animal/%s.png" % name)
