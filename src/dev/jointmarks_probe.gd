## Where a part connects, marked in the window (docs/APP_UX9.md, jointmarks):
## View › Connection points, read off the window's own pictures.
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1280x720 \
##       --script src/dev/jointmarks_probe.gd
##
## -- --only=menu,beam,kinds,cost,written,session runs those parts alone;
## --orthanc times the marks on Orthanc too (said, not judged: the cap);
## --shots=DIR keeps the pictures (else user://jointmarks_probe).
## PROBE_COMPAT=1 tools/probe.sh jointmarks -- --only=beam draws them with
## the web's renderer.
##
##  menu:    on out of the box; View › Connection points turns it off and on,
##           ticked as it is, and kept; made only when first needed (Later).
##  beam:    a 2780 pin in hand over a 32524 beam 7, aimed at its third hole:
##           each of the seven holes' marks centred within 1 px of the hole's
##           mouth as the camera draws it, hollow (the part shows through its
##           middle) at the size of a pin's hole across, the pin's end filled
##           amber in the hole it is aimed at; the beam's studs-for-anti-studs
##           grey to a pin.
##  kinds:   ten parts, each under the pointer: studs, anti-studs, clips,
##           bars, balls, sockets, hinges, pins and axles, pin and axle holes
##           each marked at its own size (what is drawn, read back from the
##           batch the card draws), seen in the window from above or below,
##           studs and anti-studs counted against the catalogue.
##  cost:    the car at 1280 x 720, a 1 x 2 brick in hand moved over it each
##           frame: the frame's time with the marks on within COST of off,
##           in turns of on and off in one run.
##  written: the saved file, Export picture, a session's picture and a
##           Render byte for byte the same with the marks drawn.
##  session: view_model {"marks": true} over the connector's tools/call: the
##           picture in 1 call with the marks drawn in it, said in words, and
##           the model and the window untouched.
extends SceneTree

## A frame with the marks no more than this much longer than without.
const COST := 0.10
## Off, on, off, on…: frames each, the first SETTLE of each not counted.
const TURNS := 8
const BLOCK := 150
const SETTLE := 20
const BEAM := "32524"
const PIN := "2780"
## The ten parts of the bar, each with the kinds it is to show; the Technic
## brick twice, one with a pin hole and one with an axle hole.
const SAMPLES: Array = [
	["3001", "a brick", ["stud", "anti-stud"]],
	["3020", "a plate", ["stud", "anti-stud"]],
	["61252", "a 1 x 1 clip plate", ["stud", "anti-stud", "clip"]],
	["87994", "a bar", ["bar"]],
	["14417", "a ball plate", ["stud", "anti-stud", "ball"]],
	["14418", "a socket plate", ["stud", "anti-stud", "socket"]],
	["3937", "a hinge", ["anti-stud", "hollow", "hinge"]],
	["3705", "an axle", ["axle"]],
	["3700", "a Technic brick with a pin hole", ["stud", "anti-stud", "pin_hole"]],
	["32064", "a Technic brick with an axle hole", ["stud", "anti-stud", "axle_hole"]],
	["87087", "a SNOT brick", ["stud", "anti-stud"]],
]

var _failures: int = 0
var _main: Node
var _shell: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _verbs: Node
var _library: PartLibrary
var _store: ModelStore
var _socket: CommandSocket
var _pointer: Vector2 = Vector2.ZERO
var _virtual: bool = OS.get_environment("XAUTHORITY").contains("xvfb-run")
var _shots: String = ""
var _only: PackedStringArray = []
var _next: int = 0
var _said: Array[String] = []


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _say(what: String) -> void:
	print("    " + what)
	_said.append(what)


func _wants(part: String) -> bool:
	return _only.is_empty() or _only.has(part)


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var orthanc: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
		elif arg == "--orthanc":
			orthanc = true
	if _shots.is_empty():
		_shots = OS.get_user_data_dir().path_join("jointmarks_probe")
	var size: Vector2i = DisplayServer.window_get_size()
	_shots = _shots.path_join("%s_%dx%d" % [RenderingServer.get_current_rendering_method(),
		size.x, size.y])
	DirAccess.make_dir_recursive_absolute(_shots)
	print("jointmarks: %s on %s, the window %dx%d, pictures in %s" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
		size.x, size.y, _shots])
	if not Picture.possible():
		print("jointmarks probe: SKIPPED: no window to draw in")
		quit(3)
		return
	BookletMaker.open_when_written = false
	# The pointer off where the model will be, so nothing is under it as the
	# window starts.
	_move_to(Vector2(4, 4))
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_shell = _main.get("_shell")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_verbs = _main.get("_verbs")
	_library = _main.get("_library")
	_store = _main.get("_store")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_move_to(Vector2(8, 400))

	if _wants("menu"):
		await _menu()
	if _wants("beam"):
		await _beam()
	if _wants("kinds"):
		await _kinds()
	if _wants("cost"):
		await _cost("res://models/car.ldr", true)
	if orthanc:
		await _cost("res://models/orthanc.ldr", false)
	if _wants("written"):
		await _written()
	if _wants("session"):
		await _session()
	_finish()


func _finish() -> void:
	var out := FileAccess.open(_shots.path_join("said.txt"), FileAccess.WRITE)
	if out != null:
		out.store_string("\n".join(_said) + "\n")
	print("")
	print("jointmarks: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the marks -----------------------------------------------------------------------


func _marks() -> Node3D:
	return _shell.get("joint_marks")


func _drawn() -> Vector2i:
	var marks: Node3D = _marks()
	return marks.call("drawn") if marks != null else Vector2i.ZERO


func _set_marks(on: bool) -> void:
	if bool(ShellPrefs.value("joint_marks")) != on:
		_shell.call("run", "joint_marks")
	await _frames(4)


## Nothing in hand, the pointer off the model.
func _empty_hand() -> void:
	_builder.held_part = ""
	_builder.hide_preview()
	_verbs.call("set_mode", "select")
	_move_to(Vector2(4, 4))
	await _frames(4)


func _clear() -> void:
	await _empty_hand()
	_main.call("clear_model")
	await _frames(6)


func _put(part: String, colour: int, at: Transform3D) -> int:
	var brick: int = _builder.put_part(part, colour, at)
	await _arrived([part])
	return brick


## The parts' shapes in, as the window draws them.
func _arrived(parts: Array) -> void:
	for part: String in parts:
		if not _library.is_resident(part):
			_library.request_mesh(part, true)
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 60000:
		var waiting: bool = false
		for part: String in parts:
			waiting = waiting or _library.mesh_for(part) == null
		if not waiting:
			break
		await process_frame
	await _frames(6)


## The camera on [param box] from [param way], settled.
func _look(box: AABB, way: Vector3, margin: float = 1.6) -> void:
	_camera.look_from(way.normalized())
	_camera.frame(box, margin)
	await _frames(6)
	var began: int = Time.get_ticks_msec()
	while (_camera.is_sliding() or _camera.is_turning()) and Time.get_ticks_msec() - began < 5000:
		await process_frame
	await _frames(10)


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(_shots.path_join(name + ".png"))
	return image


## A point of the model on [param image]: the camera's point scaled to the
## picture's pixels.
func _on_image(point: Vector3, image: Image) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	return _camera.screen_of(point) * (Vector2(image.get_size()) / rect)


static func _changed(a: Image, b: Image, x: int, y: int) -> bool:
	var p: Color = a.get_pixel(x, y)
	var q: Color = b.get_pixel(x, y)
	return maxf(maxf(absf(p.r - q.r), absf(p.g - q.g)), absf(p.b - q.b)) > 0.08


static func _blue(c: Color) -> bool:
	return c.b > 0.7 and c.b > c.r + 0.35 and c.g > 0.35 and c.g < 0.8


static func _amber(c: Color) -> bool:
	return c.r > 0.8 and c.g > 0.5 and c.g < 0.85 and c.b < 0.4


# -- menu ------------------------------------------------------------------------------


func _menu() -> void:
	print("\nmenu: on out of the box, View › Connection points")
	_check("on out of the box (ShellPrefs joint_marks)", bool(ShellPrefs.value("joint_marks")))
	var command: Object = _shell.call("command", "joint_marks")
	_check("View › Connection points is a command, ticked",
		command != null and str(command.get("words")) == "Connection points"
		and bool((command.get("ticked") as Callable).call()))
	var menus: Array = _shell.get("MENUS") if _shell.get("MENUS") != null else []
	var in_view: bool = false
	for menu: Array in menus:
		in_view = in_view or (str(menu[0]) == "View" and (menu[1] as Array).has("joint_marks"))
	_check("in the View menu, after Stud directions", in_view or menus.is_empty())
	_check("not made as the window started, nothing in hand or under the pointer: made on first need, through Later (%s)"
		% ("not made" if _marks() == null else "made"),
		_marks() == null and Later.PATHS.has(&"JointMarks"))
	await _clear()
	await _put("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	await _look(AABB(Vector3(-40, 0, -20), Vector3(80, 24, 40)), Vector3(0.6, 0.7, 0.8))
	# A part in hand: the marks of what is round it.
	_main.call("_on_part_chosen", "3020")
	await _arrived(["3020"])
	_move_to(_camera.screen_of(Vector3(0, 30, 0)))
	await _frames(10)
	_check("a part in hand: the marks made and drawn (%s)" % _drawn(),
		_marks() != null and _drawn().x > 0)
	_shell.call("run", "joint_marks")
	await _frames(4)
	var command_ticked: bool = bool((command.get("ticked") as Callable).call())
	_check("View › Connection points: off, none drawn, unticked, kept as off (%s)" % _drawn(),
		_drawn() == Vector2i.ZERO and not command_ticked
		and not bool(ShellPrefs.value("joint_marks")))
	_move_to(_camera.screen_of(Vector3(10, 30, 5)))
	await _frames(6)
	_check("off stays off as the hand moves (%s)" % _drawn(), _drawn() == Vector2i.ZERO)
	_shell.call("run", "joint_marks")
	await _frames(6)
	_check("and on again (%s)" % _drawn(), _drawn().x > 0
		and bool(ShellPrefs.value("joint_marks")))
	# The part under the pointer, nothing in hand.
	await _empty_hand()
	_check("nothing in hand, the pointer off the model: none (%s)" % _drawn(),
		_drawn() == Vector2i.ZERO)
	_move_to(_camera.screen_of(Vector3(0, 24, 0)))
	await _frames(8)
	var marks: int = JointMarks.marks_of(_library, "3001").size()
	_check("nothing in hand, a 2 x 4 brick under the pointer: its %d marks (%s)" % [marks, _drawn()],
		_drawn() == Vector2i(marks, 0))
	await _empty_hand()


# -- beam --------------------------------------------------------------------------------


func _beam() -> void:
	print("\nbeam: a 2780 pin in hand over a 32524 beam 7")
	await _clear()
	var at := Transform3D(Basis.IDENTITY, Vector3(10, 30, 10))
	var beam: int = await _put(BEAM, 71, at)
	_check("the beam down", beam != 0)
	var part: Lbm.PartMesh = _library.mesh_for(BEAM)
	await _look(at * part.bounds, Vector3(0.3, 1.0, 0.45), 1.5)
	# Each hole's mouth on the camera's side, in the world, along the beam.
	var holes: Array = []
	var eye: Vector3 = _camera.global_position
	for end: JointSnap.End in JointSnap.ends_for(_library, BEAM):
		if end.kind != "pin_hole":
			continue
		var best: Array = []
		for side: float in [1.0, -1.0]:
			var mouth: Vector3 = at * (end.at + end.axis * end.reach * side)
			var facing: Vector3 = (at.basis * end.axis * side).normalized()
			if facing.dot((eye - mouth).normalized()) > 0.0:
				best = [mouth, facing]
		holes.append(best)
	holes.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).z < (b[0] as Vector3).z)
	_check("seven holes found facing the camera", holes.size() == 7)
	if holes.size() != 7:
		return
	# The pin picked from the bin, aimed through the window at the third.
	var third: Vector3 = holes[2][0]
	_main.call("_on_part_chosen", PIN)
	await _arrived([PIN])
	_move_to(_camera.screen_of(third))
	await _frames(12)
	var end: JointSnap.End = _builder.joint_end()
	_check("the pin is on the third hole's joint, its end a pin (%s)" % (end.kind if end != null else "none"),
		_builder.is_on_joint() and end != null and end.kind == "pin")
	var seated: Transform3D = _builder.ghost_transform()
	var shown: Image = await _shot("beam_marks_on")
	await _set_marks(false)
	var plain: Image = await _shot("beam_marks_off")
	await _set_marks(true)
	var on: Array = _marks().call("shown")
	# Read the picture: each hole's ring, its middle and its size.
	var worst: float = 0.0
	var hollow: int = 0
	var sized: int = 0
	var lines: PackedStringArray = []
	for n: int in holes.size():
		var mouth: Vector3 = holes[n][0]
		var facing: Vector3 = holes[n][1]
		var c: Vector2 = _on_image(mouth, shown)
		# Across the hole, square to the eye: the ring's true radius on screen.
		var across: Vector3 = facing.cross((eye - mouth).normalized())
		if across.length() < 0.01:
			across = facing.cross(Vector3.RIGHT)
		across = across.normalized()
		var inner_px: float = c.distance_to(_on_image(mouth + across * JointSnap.PIN_ROUND, shown))
		var outer_px: float = c.distance_to(_on_image(mouth + across * (JointSnap.PIN_ROUND
			+ JointMarks.BAND), shown))
		var sum := Vector2.ZERO
		var count: int = 0
		var reach: int = int(ceil(outer_px + 4.0))
		for y: int in range(int(c.y) - reach, int(c.y) + reach + 1):
			for x: int in range(int(c.x) - reach, int(c.x) + reach + 1):
				if x < 0 or y < 0 or x >= shown.get_width() or y >= shown.get_height():
					continue
				if Vector2(x + 0.5, y + 0.5).distance_to(c) > outer_px + 3.0:
					continue
				if _changed(shown, plain, x, y) and _blue(shown.get_pixel(x, y)):
					sum += Vector2(x + 0.5, y + 0.5)
					count += 1
		var centre: Vector2 = sum / float(count) if count > 0 else Vector2.INF
		var off: float = centre.distance_to(c)
		worst = maxf(worst, off)
		# Its middle: the part through it, or the pin's end filled.
		var middle: int = 0
		var amber: int = 0
		var inside: int = 0
		var r_in: float = inner_px * 0.6
		for y: int in range(int(c.y - r_in), int(c.y + r_in) + 1):
			for x: int in range(int(c.x - r_in), int(c.x + r_in) + 1):
				if Vector2(x + 0.5, y + 0.5).distance_to(c) > r_in:
					continue
				inside += 1
				if _changed(shown, plain, x, y):
					middle += 1
				if _amber(shown.get_pixel(x, y)):
					amber += 1
		# Its size: along the line across it, where the blue begins and ends.
		var dir: Vector2 = (_on_image(mouth + across, shown) - c).normalized()
		var first: float = -1.0
		var last: float = -1.0
		for step: int in range(0, int(outer_px * 2.0 + 8.0) * 4):
			var r: float = float(step) * 0.25
			var p: Vector2 = c + dir * r
			if p.x < 0 or p.y < 0 or p.x >= shown.get_width() or p.y >= shown.get_height():
				break
			if _blue(shown.get_pixelv(Vector2i(p))):
				if first < 0.0:
					first = r
				last = r
		var size_ok: bool = absf(first - inner_px) <= 1.5 and absf(last - outer_px) <= 1.5
		if size_ok:
			sized += 1
		if n == 2:
			_check("the third hole: the pin's end filled amber in it, %d of %d px of its middle" % [
				amber, inside], inside > 0 and float(amber) / float(inside) >= 0.9)
		elif inside > 0 and float(middle) / float(inside) <= 0.02:
			hollow += 1
		lines.append("hole %d: ring centred %.2f px from its mouth (%d px), blue from %.1f to %.1f px across (a pin's %.1f, the ring's %.1f), middle %d/%d changed, %d amber" % [
			n + 1, off, count, first, last, inner_px, outer_px, middle, inside, amber])
	for line: String in lines:
		_say(line)
	_check("each of the seven holes marked within 1 px of its projected centre (worst %.2f px)" % worst,
		worst <= 1.0)
	_check("the six holes not aimed at hollow: the beam shows through their middles (%d of 6)" % hollow,
		hollow == 6)
	_check("each ring the size of a pin's hole, within 1.5 px (%d of 7)" % sized, sized == 7)
	# What a pin cannot take: none here is grey but its anti-studs, which are
	# the holes' own mouths underneath, one mark taken by a pin or a stud.
	var grey: int = 0
	var blue: int = 0
	var hand: int = 0
	for mark: Dictionary in on:
		match int(mark["role"]):
			0: blue += 1
			1: grey += 1
			2: hand += 1
	_say("drawn: %d blue (a pin takes them), %d grey, %d the hand's" % [blue, grey, hand])
	_check("the hand's end drawn once, the holes' fourteen mouths blue", hand == 1 and blue == 14)
	# A 1 x 2 brick in hand over the beam: its studs-in-holes are what it
	# takes from below; from above the beam has nothing for it (all grey but
	# the mouths underneath, which take a stud).
	_main.call("_on_part_chosen", "3004")
	await _arrived(["3004"])
	_move_to(_camera.screen_of(holes[4][0]))
	await _frames(10)
	var with_brick: Array = _marks().call("shown")
	var takes: int = 0
	var not_taken: int = 0
	for mark: Dictionary in with_brick:
		if int(mark["role"]) == 0:
			takes += 1
		elif int(mark["role"]) == 1:
			not_taken += 1
	await _shot("beam_brick_in_hand")
	_check("a brick in hand: the mouths underneath blue (a stud fits), the top's grey (%d blue, %d grey)" % [
		takes, not_taken], takes == 7 and not_taken == 7)
	await _empty_hand()
	# The pin put down in the third hole, as the MCP walk's session had it:
	# marked by its two ends, filled, and nothing along its sides (its
	# record's anti-studs and its hollow middle drew rings in the air there).
	var pin: int = await _put(PIN, 0, seated)
	_move_to(_camera.screen_of(seated * Vector3(12.0, 0.0, 0.0)))
	await _frames(10)
	var pin_marks: Array = _marks().call("shown")
	var ends_only: bool = pin_marks.size() == 2
	for mark: Dictionary in pin_marks:
		ends_only = ends_only and int(mark["shape"]) == 0
	await _shot("beam_pin_down")
	_check("a pin down in the third hole, under the pointer: its two ends filled and nothing else (%d marks, shapes %s)"
		% [pin_marks.size(), pin_marks.map(func(m: Dictionary) -> int: return int(m["shape"]))],
		pin != 0 and int(_shell.get("stress").hovered.call()) == pin and ends_only)
	var pictured: Dictionary = await _rpc("tools/call", {"name": "view_model",
		"arguments": {"marks": true}})
	var pin_images: Array[Image] = _images(pictured)
	if pin_images.size() == 1:
		pin_images[0].save_png(_shots.path_join("beam_pin_session.png"))
	var counted: String = _text(pictured).get_slice(",", 1).strip_edges()
	_check("its picture over MCP: the beam's 14 mouths and the pin's 2 ends, 16 marks (%s)" % counted,
		pin_images.size() == 1 and counted == "16")


# -- kinds -------------------------------------------------------------------------------


func _kinds() -> void:
	print("\nkinds: ten parts, each under the pointer")
	var band: float = JointMarks.BAND
	var seen_kinds: Dictionary = {}
	var sized_kinds: Dictionary = {}
	for sample: Array in SAMPLES:
		var part_id: String = sample[0]
		await _clear()
		# Off the baseplate, so the eye below it sees the part's underside.
		var at := Transform3D(Basis.IDENTITY, Vector3(1210, 40, 1210))
		var brick: int = await _put(part_id, 15 if part_id != "3705" else 0, at)
		var part: Lbm.PartMesh = _library.mesh_for(part_id)
		var info: PartLibrary.PartInfo = _library.parts.get(part_id)
		if brick == 0 or part == null or info == null:
			_check("%s (%s) down" % [sample[1], part_id], false)
			continue
		var marks: Array = JointMarks.marks_of(_library, part_id)
		var kinds: Dictionary = {}
		var studs: int = 0
		var anti: int = 0
		var wrong: PackedStringArray = []
		for mark: Array in marks:
			kinds[mark[4]] = true
			if mark[4] == "stud":
				studs += 1
			if mark[4] == "anti-stud" or mark[7]:
				anti += 1
		# The record's anti-studs along a pin's or an axle's side, left
		# unmarked by design (JointMarks.on_round), counted as such.
		var on_round: int = 0
		var ends: Array = JointSnap.ends_for(_library, part_id)
		for socket: Vector2 in part.sockets:
			if JointMarks.on_round(ends, Vector3(socket.x, part.bounds.position.y, socket.y)):
				on_round += 1
		var seen: Dictionary = {}
		var drawn_rows: Array = []
		var all_drawn: Array = []
		for way: Vector3 in [Vector3(0.7, 0.9, 1.0), Vector3(-0.8, -0.6, -0.9)]:
			await _look(at * part.bounds, way, 2.2)
			_move_to(_camera.screen_of(at * part.bounds.get_center()))
			await _frames(10)
			if int(_shell.get("stress").hovered.call()) != brick:
				# The pointer missed the part's middle: try the corners' middles.
				for corner: int in 8:
					_move_to(_camera.screen_of(at * part.bounds.get_center().lerp(
						part.bounds.get_endpoint(corner), 0.4)))
					await _frames(6)
					if int(_shell.get("stress").hovered.call()) == brick:
						break
			var on: Image = await _shot("kinds_%s_%s" % [part_id, "above" if way.y > 0 else "below"])
			drawn_rows = _marks().call("shown") if _marks() != null else []
			await _set_marks(false)
			var off: Image = await _shot("kinds_%s_%s_off" % [part_id, "above" if way.y > 0 else "below"])
			await _set_marks(true)
			if drawn_rows.size() != marks.size():
				_say("%s from %s: %d drawn of %d, the pointer on brick %d" % [part_id,
					"above" if way.y > 0 else "below", drawn_rows.size(), marks.size(),
					int(_shell.get("stress").hovered.call())])
				continue
			all_drawn = drawn_rows
			for n: int in marks.size():
				var row: Dictionary = drawn_rows[n]
				var p: Vector2 = _on_image(row["at"], on)
				var r_px: float = p.distance_to(_on_image((row["at"] as Vector3)
					+ _camera.global_transform.basis.x * float(row["radius"]), on))
				var hits: int = 0
				var reach: int = int(ceil(r_px + 2.0))
				for y: int in range(int(p.y) - reach, int(p.y) + reach + 1):
					for x: int in range(int(p.x) - reach, int(p.x) + reach + 1):
						if x >= 0 and y >= 0 and x < on.get_width() and y < on.get_height() \
								and _changed(on, off, x, y):
							hits += 1
				if hits >= 3:
					seen[n] = true
		_check("%s (%s): all its %d marks drawn under the pointer" % [sample[1], part_id, marks.size()],
			all_drawn.size() == marks.size() and marks.size() > 0)
		drawn_rows = all_drawn
		# What the card draws, read back from the batch: each kind's own size.
		for n: int in mini(marks.size(), drawn_rows.size()):
			var mark: Array = marks[n]
			var row: Dictionary = drawn_rows[n]
			var kind: String = mark[4]
			var end: JointSnap.End = mark[5]
			var radius: float = float(row["radius"])
			var expected: float = _own_size(kind, end, part)
			var hollow_mark: bool = int(row["shape"]) in [1, 3, 5]
			var as_drawn: float = radius - band if hollow_mark else radius
			if absf(as_drawn - expected) > 0.01:
				wrong.append("%s %.2f not %.2f" % [kind, as_drawn, expected])
			elif seen.has(n):
				sized_kinds[kind] = true
			if seen.has(n):
				seen_kinds[kind] = true
		_check("%s: each mark its own size (%s)" % [sample[1], ", ".join(wrong) if not wrong.is_empty()
			else ", ".join(PackedStringArray(kinds.keys()))], wrong.is_empty())
		var missing: PackedStringArray = []
		for kind: String in sample[2]:
			if not kinds.has(kind):
				missing.append(kind)
		_check("%s: shows %s" % [sample[1], ", ".join(PackedStringArray(sample[2]))], missing.is_empty())
		_check("%s: %d stud marks against the catalogue's %d, %d anti-stud against %d%s" % [sample[1],
			studs, info.stud_count, anti, info.socket_count,
			"" if on_round == 0 else " (and %d along its round's side, left unmarked)" % on_round],
			studs == info.stud_count and anti + on_round == info.socket_count)
		_say("%s %s: %d marks, %d seen in the window from above or below" % [part_id, info.name,
			marks.size(), seen.size()])
	var every: PackedStringArray = ["stud", "anti-stud", "clip", "hollow", "bar", "ball", "socket",
		"hinge", "axle", "pin_hole", "axle_hole"]
	var unseen: PackedStringArray = []
	for kind: String in every:
		if not sized_kinds.has(kind):
			unseen.append(kind)
	_check("every kind seen in the window at its own size (%s)" % (", ".join(unseen) + " not"
		if not unseen.is_empty() else ", ".join(every)), unseen.is_empty())
	await _empty_hand()


## A kind's own size, LDU: a male's radius, or the radius of the male a
## hollow one takes.
func _own_size(kind: String, end: JointSnap.End, part: Lbm.PartMesh) -> float:
	match kind:
		"stud", "anti-stud":
			for connector: Lbm.Connector in part.connectors:
				if connector.kind == "stud" and connector.radius > 0.0:
					return connector.radius
			return 6.0
		"pin", "pin_hole", "axle", "axle_hole":
			return JointSnap.PIN_ROUND
		"hinge":
			return JointSnap.BAR
	return end.radius if end != null else -1.0


# -- cost --------------------------------------------------------------------------------


func _cost(model: String, judged: bool) -> void:
	print("\ncost: %s at %s, a 1 x 2 brick in hand moved over it" % [model.get_file(),
		DisplayServer.window_get_size()])
	await _clear()
	var placed: int = _store.open(model)
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	playback_stop()
	var bricks: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			bricks.append(brick.part_id)
	await _arrived(bricks)
	_world.rebuilds_in_slices = false
	_world.call("_flush")
	_camera.set_view("default")
	await _look(_main.call("_built_bounds"), -_camera.global_transform.basis.z * -1.0, 1.25)
	# Where the pointer goes: the middles of parts on show, in turn.
	var spots: Array[Vector2] = []
	var view: Rect2 = root.get_visible_rect().grow(-40.0)
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var p: Vector2 = _camera.screen_of(brick.transform * mesh.bounds.get_center())
		if view.has_point(p):
			spots.append(p)
		if spots.size() >= 40:
			break
	_check("%s open, %d parts to move over" % [model.get_file(), spots.size()], spots.size() >= 8)
	if spots.size() < 8:
		return
	_main.call("_on_part_chosen", "3004")
	await _arrived(["3004"])
	var rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var times: Array = [[], []]
	var gpu: Array = [[], []]
	var counts: Array[int] = []
	var step: int = 0
	JointMarks.worked = 0
	JointMarks.work_usec = 0
	JointMarks.most_usec = 0
	for turn: int in TURNS * 2:
		var on: bool = turn % 2 == 1
		await _set_marks(on)
		var last: int = Time.get_ticks_usec()
		for n: int in BLOCK:
			# Along the line from one part to the next, a few frames a part.
			var a: Vector2 = spots[(step / 6) % spots.size()]
			var b: Vector2 = spots[(step / 6 + 1) % spots.size()]
			_move_to(a.lerp(b, float(step % 6) / 6.0))
			step += 1
			await process_frame
			var now: int = Time.get_ticks_usec()
			if n >= SETTLE:
				(times[int(on)] as Array).append(float(now - last) / 1000.0)
				(gpu[int(on)] as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			last = now
			if on and n == BLOCK / 2:
				counts.append(_drawn().x)
	RenderingServer.viewport_set_measure_render_time(rid, false)
	var off_ms: float = _middle(times[0])
	var on_ms: float = _middle(times[1])
	var off_gpu: float = _middle(gpu[0])
	var on_gpu: float = _middle(gpu[1])
	counts.sort()
	var marks_drawn: int = counts[counts.size() / 2] if not counts.is_empty() else 0
	await _shot("cost_%s" % model.get_file().get_basename())
	_say("%s: a frame %.3f ms with the marks (%d drawn, middle of the turns) against %.3f ms without, x%.3f; the card's share %.3f against %.3f ms, x%.3f; %d frames each; marks worked out %d times, %.3f ms each on average, %.3f at the most" % [
		model.get_file(), on_ms, marks_drawn, off_ms, on_ms / maxf(off_ms, 0.001), on_gpu, off_gpu,
		on_gpu / maxf(off_gpu, 0.001), (times[0] as Array).size(), JointMarks.worked,
		float(JointMarks.work_usec) / 1000.0 / maxf(float(JointMarks.worked), 1.0),
		float(JointMarks.most_usec) / 1000.0])
	if judged:
		_check("%s at %s: a frame with the marks within %d%% of without (x%.3f)" % [model.get_file(),
			DisplayServer.window_get_size(), int(COST * 100.0), on_ms / maxf(off_ms, 0.001)],
			marks_drawn > 0 and on_ms <= off_ms * (1.0 + COST))
	await _empty_hand()


func playback_stop() -> bool:
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	return playback != null


static func _middle(values: Array) -> float:
	if values.is_empty():
		return -1.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


# -- written -----------------------------------------------------------------------------


func _written() -> void:
	print("\nwritten: nothing the marks are drawn in is saved, rendered or put in a picture")
	await _clear()
	var placed: int = _store.open("res://models/car.ldr")
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	playback_stop()
	var bricks: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		bricks.append(brick.part_id)
	await _arrived(bricks)
	_camera.set_view("default")
	await _look(_main.call("_built_bounds"), _camera.global_transform.basis.z, 1.25)
	var shot := ModelShot.new()
	shot.library = _library
	root.add_child(shot)
	var render := StudioRender.new()
	render.library = _library
	render.scenery = _store.scenery
	render.eye = _camera
	render.look = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(render)
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = Vector2i(320, 180)
	settings.view = "hero"

	await _set_marks(false)
	var plain: Dictionary = await _outputs("plain", shot, render, settings)
	# The marks on and drawn: a part in hand over the car, its marks round it.
	await _set_marks(true)
	_main.call("_on_part_chosen", "3004")
	await _arrived(["3004"])
	var middle: Vector3 = (_main.call("_built_bounds") as AABB).get_center()
	_move_to(_camera.screen_of(middle))
	await _frames(10)
	var drawn: Vector2i = _drawn()
	_check("the marks drawn round the hand while it is all written (%s)" % drawn, drawn.x > 0)
	var marked: Dictionary = await _outputs("marked", shot, render, settings)
	await _empty_hand()
	for what: String in plain:
		var same: bool = plain[what] == marked[what]
		if not same:
			# Whether this output is the same twice over at all.
			var again: Dictionary = await _outputs("again", shot, render, settings)
			_say("%s differs; drawn again plainly it is %s" % [what,
				"the same as the first" if again[what] == plain[what] else "different again"])
		_check("%s byte for byte the same with the marks drawn (%d bytes)" % [what,
			(plain[what] as PackedByteArray).size()], same and (plain[what] as PackedByteArray).size() > 0)
	shot.queue_free()
	render.queue_free()


## The saved file and each picture, as bytes.
func _outputs(name: String, shot: ModelShot, render: StudioRender,
		settings: RenderSettings) -> Dictionary:
	var out: Dictionary = {}
	var path: String = _shots.path_join("written_%s.ldr" % name)
	_store.save_file(path, "Car")
	out["the saved file"] = FileAccess.get_file_as_bytes(path)
	var exports: Node = _main.get("_exports")
	var picture: Image = await (exports.get("picture") as Picture).take(Vector2i(640, 400))
	out["Export picture"] = picture.get_data() if picture != null else PackedByteArray()
	if picture != null:
		picture.save_png(_shots.path_join("written_%s_picture.png" % name))
	var seen: Image = await shot.take(_world, "corner", _store.scenery)
	out["a session's picture"] = seen.get_data() if seen != null else PackedByteArray()
	var rendered: Image = await render.render(_world, settings)
	out["a Render"] = rendered.get_data() if rendered != null else PackedByteArray()
	if rendered != null:
		rendered.save_png(_shots.path_join("written_%s_render.png" % name))
	return out


# -- session -----------------------------------------------------------------------------


func _session() -> void:
	print("\nsession: view_model {\"marks\": true} over the connector's tools/call")
	await _clear()
	var at := Transform3D(Basis.IDENTITY, Vector3(10, 30, 10))
	await _put(BEAM, 71, at)
	await _put("3001", 4, Transform3D(Basis.IDENTITY, Vector3(10, 24, 80)))
	await _empty_hand()
	var listed: Dictionary = await _rpc("tools/list", {})
	var takes: Dictionary = {}
	for tool: Dictionary in listed.get("tools", []):
		if str(tool.get("name", "")) == "view_model":
			takes = ((tool.get("inputSchema", {}) as Dictionary).get("properties", {}) as Dictionary)
	_check("tools/list: view_model takes marks=", takes.has("marks"))
	var model: Array = _signature()
	var depth: int = _builder.history_depth()
	var drawn_before: Vector2i = _drawn()
	var plain: Dictionary = await _rpc("tools/call", {"name": "view_model", "arguments": {}})
	var marked: Dictionary = await _rpc("tools/call", {"name": "view_model",
		"arguments": {"marks": true}})
	var plain_images: Array[Image] = _images(plain)
	var images: Array[Image] = _images(marked)
	var text: String = _text(marked)
	_say("said: %s" % text.substr(0, 400))
	_check("one call: a picture, and what the marks are in words", images.size() == 1
		and text.contains("Connection points marked"))
	if images.size() == 1 and plain_images.size() == 1:
		images[0].save_png(_shots.path_join("session_marks.png"))
		plain_images[0].save_png(_shots.path_join("session_plain.png"))
		var blue: int = _count(images[0], _blue)
		var blue_plain: int = _count(plain_images[0], _blue)
		_check("the marks drawn in its picture: %d px blue against %d without" % [blue, blue_plain],
			blue > 200 and blue > blue_plain * 4)
	var again: Dictionary = await _rpc("tools/call", {"name": "view_model", "arguments": {}})
	var again_images: Array[Image] = _images(again)
	_check("the next picture without them: none drawn in it",
		again_images.size() == 1 and plain_images.size() == 1
		and _count(again_images[0], _blue) <= maxi(_count(plain_images[0], _blue) * 2, 50))
	_check("the model, its history and the window's marks as they were",
		_signature() == model and _builder.history_depth() == depth and _drawn() == drawn_before)


func _count(image: Image, test: Callable) -> int:
	var count: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			if test.call(image.get_pixel(x, y)):
				count += 1
	return count


func _signature() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		out.append([brick.id, brick.part_id, brick.color_code, brick.transform])
	return out


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


static func _images(result: Dictionary) -> Array[Image]:
	var out: Array[Image] = []
	for block: Dictionary in result.get("content", []):
		if str(block.get("type", "")) == "image":
			var picture := Image.new()
			if picture.load_png_from_buffer(Marshalls.base64_to_raw(str(block.get("data", "")))) == OK:
				picture.convert(Image.FORMAT_RGB8)
				out.append(picture)
	return out


# -- the pointer -------------------------------------------------------------------------


func _move_to(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _pointer
	_pointer = event.position
	if _virtual:
		Input.warp_mouse(event.position)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
