## Does a session see how parts join, and what it made (APP_UX5 seeing2)?
## Each tool called the way the connector and the desktop's MCP port call
## it (CommandSocket.answer_rpc, tools/call), and its picture read part by
## part.
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 \
##       --script src/dev/seeing2_probe.gd
##
## PROBE_SIZE=1280x720 tools/probe.sh seeing2 runs it at a laptop's size.
## Keeps every picture a call answered with, and the window's, in
## SEEING2_SHOTS, or user://seeing2_probe.
##
## On the car (models/car.ldr):
##   1. view_board {"studs": true}: the stud map in 1 call, a legend under
##      it, and each part's colour, read off the picture where it is in
##      sight from one of the six sides, that of where its studs point,
##      worked out here from its connectors; every part painted so on the
##      picture's stage; View, Stud directions draws the window the same,
##      follows a part put down, and gives the car its colours back off;
##   2. highlight="3024" edges exactly the car's 1 x 1 plates, "step:3"
##      exactly step 3's new parts, "red" the red ones;
##   3. check_design {"edit": {}} with a part floating: the part it names
##      edged in magenta in its picture;
##   4. edit_booklet's pull by brick number pulls it (its page drawn
##      otherwise), and a part id not in the step is refused with the
##      step's parts, nothing changed;
##   5. render_model build answers with six frames, the last the whole
##      model; render_motion (1484-1's doors) with six;
##   and none of the looks changes the model or its history.
## Written to run on a build without them (pre261): there it fails, it does
## not stop.
extends SceneTree

const VIEWS: Array[String] = ["front", "back", "left", "right", "top", "corner"]
const CELL := 512
const LABEL_HIGH := 34
## Of the ring round each picked-out part where it shows, at least this
## much is magenta.
const EDGED_LEAST := 0.9
## The most two pictures of one thing may differ for "the same".
const MOST_APART := 0.03
const DOORS := "res://vendor/omr/files/1484-1.mpd"

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Node
var _next: int = 0
var _shots: String = ""
var _window: String = ""
## The stud map's colours, from the app's own StudMap; empty without one.
var _colours: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	BookletMaker.open_when_written = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var size: Vector2i = DisplayServer.window_get_size()
	_window = "%dx%d" % [size.x, size.y]
	_shots = OS.get_environment("SEEING2_SHOTS")
	if _shots.is_empty():
		_shots = OS.get_user_data_dir().path_join("seeing2_probe")
	_shots = _shots.path_join(_window)
	DirAccess.make_dir_recursive_absolute(_shots)
	print("seeing2: the window %s, pictures in %s" % [_window, _shots])
	if not ModelShot.possible():
		print("seeing2 probe: SKIPPED: no window to draw in")
		quit(3)
		return
	if ResourceLoader.exists("res://src/ui/stud_map.gd"):
		_colours = (load("res://src/ui/stud_map.gd") as GDScript).get_script_constant_map().get(
			"COLOURS", {})

	var listed: Dictionary = await _rpc("tools/list", {})
	var tools: Dictionary = {}
	for tool: Dictionary in listed.get("tools", []):
		tools[str(tool["name"])] = tool
	var board_takes: Dictionary = ((tools.get("view_board", {}) as Dictionary).get("inputSchema",
		{}) as Dictionary).get("properties", {})
	_check("tools/list: view_board takes studs=, and highlight= a part number as a string",
		board_takes.has("studs") and board_takes.has("highlight")
		and str((board_takes["highlight"] as Dictionary).get("type", "")) != "array")

	await _open_car()
	var model: Array = _signature()
	var depth: int = _builder.history_depth()
	await _stud_map()
	await _selectors()
	_check("view_board's stud map and selectors changed nothing: the model and its history as they were",
		_signature() == model and _builder.history_depth() == depth)
	await _window_map()
	await _findings()
	await _pull()
	await _build_video()
	await _motion_frames()
	await _frames(10)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_shots.path_join("window.png"))
	print("")
	print("seeing2: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- 1. the stud map ----------------------------------------------------------------


## Where [param brick]'s studs point, worked out here from its connectors as
## the doc says a stud map shows them: one way; up and one way more, the
## other; two ways or more besides up, "sides"; none, "none".
func _facing(brick: BrickWorld.Brick) -> String:
	var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var ways: Dictionary = {}
	if part != null:
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != "stud" or connector.gender != "male":
				continue
			var d: Vector3 = (brick.transform.basis * connector.axis).normalized()
			var ax: float = absf(d.x)
			var ay: float = absf(d.y)
			var az: float = absf(d.z)
			if ay >= ax and ay >= az:
				ways["up" if d.y > 0.0 else "down"] = true
			elif ax >= az:
				ways["right" if d.x > 0.0 else "left"] = true
			else:
				ways["front" if d.z > 0.0 else "back"] = true
	if ways.is_empty():
		return "none"
	if ways.size() == 1:
		return str(ways.keys()[0])
	if ways.size() == 2 and ways.has("up"):
		ways.erase("up")
		return str(ways.keys()[0])
	return "sides"


## The facing a pixel's colour is, by the stud map's colours: hue for the
## six ways, darkness for black and grey.
func _class_of(c: Color) -> String:
	if c.s < 0.3:
		return "sides" if c.v < 0.3 else "none"
	var best: String = ""
	var near: float = INF
	for name: String in ["up", "down", "front", "back", "left", "right"]:
		var apart: float = absf(wrapf(c.h - (_colours[name] as Color).h, -0.5, 0.5))
		if apart < near:
			near = apart
			best = name
	return best


func _stud_map() -> void:
	print("")
	print("── 1. the car's stud map in one call ──")
	var expected: Dictionary = {}
	var counted: Dictionary = {}
	var odd := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var facing: String = _facing(brick)
		expected[brick.id] = facing
		counted[facing] = int(counted.get(facing, 0)) + 1
		if facing != "up":
			odd.append("#%d %s %s" % [brick.id, brick.part_id, facing])
	print("    worked out here: %s; not up: %s" % [str(counted), ", ".join(odd)])
	var before: int = _next
	var started: int = Time.get_ticks_msec()
	var answer: Dictionary = await _rpc("tools/call", {"name": "view_board",
		"arguments": {"studs": true}})
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	var said: String = _text(answer)
	_print(said)
	var pictures: Array[Image] = _images(answer)
	if not _check("the stud map in %d call, %.1f s, %d picture" % [_next - before, seconds,
			pictures.size()], _next - before == 1 and pictures.size() == 1 and not _colours.is_empty()
			and said.contains("where its studs point")):
		return
	var board: Image = pictures[0]
	board.save_png(_shots.path_join("1_stud_map.png"))
	var high: int = CELL + LABEL_HIGH
	_check("...the six views, %d x %d px, and a legend under them" % [board.get_width(),
		board.get_height()], board.get_width() == 3 * CELL and board.get_height() > 2 * high + 30)
	# The legend: each facing the car has, its colour's swatch, its count said.
	var band: Image = board.get_region(Rect2i(0, 2 * high, board.get_width(),
		board.get_height() - 2 * high))
	var shown: int = 0
	var words: int = 0
	for name: String in counted:
		var colour: Color = _colours[name]
		var swatch: Callable = func(c: Color) -> bool:
			return absf(c.r - colour.r) < 0.04 and absf(c.g - colour.g) < 0.04 \
				and absf(c.b - colour.b) < 0.04
		shown += 1 if _share(band, swatch) > 0.0005 else 0
		words += 1 if said.contains("(%d)" % int(counted[name])) else 0
	_check("...the legend shows each facing the car has, in its colour (%d of %d), its count said (%d)"
		% [shown, counted.size(), words], shown == counted.size() and words == counted.size())
	# Each part, read off the picture: its pixels in every view where it is
	# nearest the eye, away from its edges, by colour.
	var votes: Dictionary = {}
	for k: int in VIEWS.size():
		var ids: PackedInt32Array = await _front(VIEWS[k])
		if ids.is_empty():
			_check("the parts each pixel shows from the %s" % VIEWS[k], false)
			return
		var at := Vector2i((k % 3) * CELL, (k / 3) * high + LABEL_HIGH)
		var side: int = ModelShot.SIZE
		for y: int in range(4, side - 4, 2):
			for x: int in range(4, side - 4, 2):
				var id: int = ids[y * side + x]
				if id == 0 or not expected.has(id):
					continue
				if ids[(y - 3) * side + x] != id or ids[(y + 3) * side + x] != id \
						or ids[y * side + x - 3] != id or ids[y * side + x + 3] != id:
					continue
				var seen: String = _class_of(board.get_pixel(at.x + x / 2, at.y + y / 2))
				if not votes.has(id):
					votes[id] = {}
				votes[id][seen] = int((votes[id] as Dictionary).get(seen, 0)) + 1
	var right: int = 0
	var wrong := PackedStringArray()
	var hidden := PackedStringArray()
	for id: int in expected:
		var got: Dictionary = votes.get(id, {})
		var total: int = 0
		var best: String = ""
		for name: String in got:
			total += int(got[name])
			if best.is_empty() or int(got[name]) > int(got[best]):
				best = name
		if total < 4:
			hidden.append("#%d %s" % [id, _world.get_brick(id).part_id])
		elif best == expected[id]:
			right += 1
		else:
			wrong.append("#%d %s %s read %s %s" % [id, _world.get_brick(id).part_id, expected[id],
				best, str(got)])
	print("    out of sight from all six: %s" % (", ".join(hidden) if not hidden.is_empty() else "none"))
	if not wrong.is_empty():
		print("    wrong: %s" % "; ".join(wrong))
	_check("each part's colour that of its studs' facing, read off the picture: %d of %d in sight right"
		% [right, expected.size() - hidden.size()], wrong.is_empty() and right > 0)
	# And every part, in sight or not, painted so on the picture's stage.
	var shot: ModelShot = _see()._shot
	var staged: Dictionary = shot._stage.call("painted_ids") if shot._stage.has_method("painted_ids") else {}
	var painted: int = 0
	for id: int in expected:
		var on_stage: int = int(shot._on_stage.get(id, 0))
		painted += 1 if staged.get(on_stage) == _colours[expected[id]] else 0
	_check("...every part painted its facing's colour on the picture's stage: %d of %d" % [painted,
		expected.size()], painted == expected.size())


## Which part each pixel of the view from [param from] shows, nearest the
## eye, by its number in the model (0 for none): a picture-taker of the
## probe's own, every part edged, so its codes number them all.
func _front(from: String) -> PackedInt32Array:
	var shot := ModelShot.new()
	shot.library = _library
	root.add_child(shot)
	var order: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			shot.edged[brick.id] = true
			order.append(brick.id)
	var image: Image = await shot.take(_world, from, _store.scenery)
	if image == null:
		shot.queue_free()
		return PackedInt32Array()
	var ids: PackedInt32Array = _numbered(shot._codes.get_texture().get_image(), order)
	shot.queue_free()
	return ids


## View, Stud directions in the window, as a person turns it on.
func _window_map() -> void:
	print("")
	print("── 1b. View, Stud directions in the window ──")
	var map: Node = _shell.get("stud_map") as Node if _shell != null else null
	var in_view: bool = false
	for menu: Array in Shell.MENUS:
		in_view = in_view or (str(menu[0]) == "View" and (menu[1] as Array).has("stud_map"))
	if not _check("View, Stud directions: a row of View", map != null and in_view
			and not _colours.is_empty()):
		return
	await _frames(5)
	var red_off: float = await _red_share("1_window_plain.png")
	_shell.call("run", "stud_map")
	await _frames(8)
	var expected: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			expected[brick.id] = _facing(brick)
	var painted: Dictionary = _world.call("painted_ids")
	var drawn: int = 0
	for id: int in expected:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var shown: Color = _world._shown_colour(brick, _library.color(brick.color_code))
		drawn += 1 if painted.get(id) == _colours[expected[id]] and shown == _colours[expected[id]] else 0
	_check("every part drawn its facing's colour in the window, as in the picture: %d of %d, the baseplate as it was"
		% [drawn, expected.size()], drawn == expected.size() and _store.scenery.keys().all(
			func(id: int) -> bool: return not painted.has(id)))
	var legend: Control = map.get("legend")
	var rect: Rect2 = legend.get_global_rect() if legend != null else Rect2()
	var inside: bool = Rect2(Vector2.ZERO, Vector2(DisplayServer.window_get_size())).encloses(rect)
	_check("...its legend in sight, inside the window: %s" % str(rect),
		legend != null and legend.is_visible_in_tree() and inside and rect.size.x > 40.0)
	var red_on: float = await _red_share("1_window_stud_map.png")
	_check("...the car drawn in the map's colours, not its own: red %.1f%% of the model's room on, %.1f%% off"
		% [red_on * 100.0, red_off * 100.0], red_off > 0.002 and red_on < red_off * 0.1)
	# A part put down while it is on is painted too.
	var plate: int = _put("3024", 4, Vector3(200.0, 8.0, 200.0))
	await _frames(4)
	painted = _world.call("painted_ids")
	_check("...a part put down while it is on painted its facing's colour",
		painted.get(plate) == _colours["up"])
	await _rpc("tools/call", {"name": "undo", "arguments": {}})
	_shell.call("run", "stud_map")
	await _frames(8)
	painted = _world.call("painted_ids")
	var red_after: float = await _red_share("1_window_after.png")
	_check("...and turned off, every part its own colour again (red %.1f%%)" % (red_after * 100.0),
		painted.is_empty() and red_after > red_off * 0.5)


## How much of the model's room in the window is the car's red, and the
## window kept as [param name].
func _red_share(name: String) -> float:
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_viewport().get_texture().get_image()
	shot.save_png(_shots.path_join(name))
	var room: Rect2 = (_main.get("_over_model") as Control).get_global_rect()
	var region: Image = shot.get_region(Rect2i(room).intersection(Rect2i(Vector2i.ZERO,
		shot.get_size())))
	var red: Callable = func(c: Color) -> bool:
		return c.s > 0.6 and c.v > 0.3 and (c.h < 0.04 or c.h > 0.96)
	return _share(region, red)


# -- 2. selectors ---------------------------------------------------------------------


func _selectors() -> void:
	print("")
	print("── 2. highlight= by part number, step and colour ──")
	var plates: Array = []
	var reds: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		if brick.part_id == "3024":
			plates.append(brick.id)
		if brick.color_code == 4:
			reds += 1
	await _picked({"views": ["corner"], "highlight": "3024"}, plates,
		"highlight=\"3024\" picks out exactly the car's %d 1 x 1 plates" % plates.size(), "2_3024")
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery, {},
		true)
	var third: Array = []
	for step: Instructions.Step in steps:
		if step.number == 3:
			for brick_id: int in step.brick_ids:
				third.append(brick_id)
	await _picked({"views": ["corner"], "highlight": "step:3"}, third,
		"highlight=\"step:3\" picks out exactly step 3's %d parts" % third.size(), "2_step_3")
	var answer: Dictionary = await _rpc("tools/call", {"name": "view_board",
		"arguments": {"views": ["corner"], "highlight": "red"}})
	_print(_text(answer))
	var red: String = _library.color(4).name
	_check("highlight=\"red\" picks out the car's %d red parts" % reds,
		_text(answer).contains("%d %s part" % [reds, red]) and _images(answer).size() == 1)


## view_board with [param arguments] edges exactly [param wanted]: the parts
## its own codes drew edged are those, part for part, and each one's ring,
## where it shows, is magenta, and nothing else is.
func _picked(arguments: Dictionary, wanted: Array, what: String, name: String) -> void:
	var answer: Dictionary = await _rpc("tools/call", {"name": "view_board", "arguments": arguments})
	_print(_text(answer))
	var shown: Array[Image] = _images(answer)
	if not _check(what + ": one picture", shown.size() == 1 and not wanted.is_empty()):
		return
	var marked: Image = shown[0]
	marked.save_png(_shots.path_join(name + ".png"))
	var shot: ModelShot = _see()._shot
	# Every other part is see-through and left out of the codes: what they
	# drew is what was edged, in the world's order.
	var drawn: Array = []
	for brick: BrickWorld.Brick in shot._codes_stage.bricks():
		drawn.append("%s@%s" % [brick.part_id, str(brick.transform.origin.snapped(Vector3.ONE * 0.1))])
	drawn.sort()
	var asked: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if wanted.has(brick.id):
			asked.append("%s@%s" % [brick.part_id, str(brick.transform.origin.snapped(Vector3.ONE * 0.1))])
	asked.sort()
	_check("...%d parts edged, those and no others" % drawn.size(), drawn == asked)
	var codes: Image = shot._codes.get_texture().get_image()
	var rings := PackedStringArray()
	var edged_ok: int = 0
	var counted: int = 0
	var all_rings: Array = []
	# The codes number each part by its number on their own stage.
	for staged: BrickWorld.Brick in shot._codes_stage.bricks():
		var ring: Array = _ring(codes, func(number: int) -> bool: return number == staged.id)
		all_rings.append_array(ring)
		if ring.size() < 40:
			continue
		counted += 1
		var magenta: float = _share_at(marked, ring, _is_magenta)
		rings.append("%s %.0f%%" % [staged.part_id, magenta * 100.0])
		edged_ok += 1 if magenta >= EDGED_LEAST else 0
	var reach: Dictionary = _grown(_set_of(all_rings), 3)
	var stray: int = 0
	var magenta_px: Dictionary = _where_magenta(marked)
	for at: int in magenta_px:
		stray += 0 if reach.has(at) else 1
	_check("...each one in sight edged in magenta (%d of %d: %s), %d of %d magenta px elsewhere"
		% [edged_ok, counted, ", ".join(rings), stray, magenta_px.size()],
		counted > 0 and edged_ok == counted and stray <= magenta_px.size() / 50)


# -- 3. check_design's findings ---------------------------------------------------------


func _findings() -> void:
	print("")
	print("── 3. check_design's findings pictured ──")
	var floater: int = _put("3024", 14, Vector3(0.0, 400.0, 0.0))
	var depth: int = _builder.history_depth()
	var answer: Dictionary = await _finished(await _rpc("tools/call", {"name": "check_design",
		"arguments": {"edit": {}}}))
	var said: String = _text(answer)
	_print(said)
	var shown: Array[Image] = _images(answer)
	if not _check("a part floating, #%d: check_design names it and answers with a picture"
			% floater, said.contains("#%d" % floater) and shown.size() == 1):
		await _rpc("tools/call", {"name": "undo", "arguments": {}})
		return
	shown[0].save_png(_shots.path_join("3_check_design.png"))
	var shot: ModelShot = _see()._shot
	var edged: Array = []
	var order: int = 0
	var at: Vector3 = _world.get_brick(floater).transform.origin
	for brick: BrickWorld.Brick in shot._codes_stage.bricks():
		edged.append(brick.id)
		if brick.transform.origin.is_equal_approx(at):
			order = brick.id
	var codes: Image = shot._codes.get_texture().get_image()
	var ring: Array = _ring(codes, func(number: int) -> bool: return number == order)
	var magenta: float = _share_at(shown[0], ring, _is_magenta)
	_check("...the part it names magenta in its picture: %.0f%% of its ring (%d px), %d part%s edged"
		% [magenta * 100.0, ring.size(), edged.size(), "" if edged.size() == 1 else "s"],
		order > 0 and ring.size() > 40 and magenta >= EDGED_LEAST)
	_check("...and nothing changed", _builder.history_depth() == depth)
	await _rpc("tools/call", {"name": "undo", "arguments": {}})


# -- 4. a pull by brick number ------------------------------------------------------------


func _pull() -> void:
	print("")
	print("── 4. edit_booklet's pull by brick number ──")
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery, {},
		true)
	# Brick 3, as the MCP walk's session named it; the first part when 3 is not one.
	var number: int = 3
	if _store.scenery.has(number) or _world.get_brick(number) == null:
		for brick: BrickWorld.Brick in _world.bricks():
			if not _store.scenery.has(brick.id):
				number = brick.id
				break
	var at: Instructions.Step = null
	for step: Instructions.Step in steps:
		if not step.in_callout() and step.brick_ids.has(number):
			at = step
	if not _check("brick #%d, in step %d" % [number, at.number if at != null else 0], at != null):
		return
	var part: String = _world.get_brick(number).part_id
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var laid: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, "Car")
	maker.queue_free()
	var page: int = 0
	for one: Booklet.Page in laid:
		for entry: Booklet.Entry in one.entries:
			if entry.number == at.number:
				page = one.number
	var before: Image = await _page(page, "4_page_before")
	var depth: int = _builder.history_depth()
	var answer: Dictionary = await _rpc("tools/call", {"name": "edit_booklet",
		"arguments": {"step": at.number, "pull": {"parts": [number]}}})
	var said: String = _text(answer)
	_print(said)
	var looks: String = str(_world.step_looks)
	var after: Image = await _page(page, "4_page_pulled")
	var apart: float = _apart(before, after) if before != null and after != null else 0.0
	_check("pull {\"parts\": [%d]}, brick %d a %s in step %d, pulls it: kept as %s, page %d drawn otherwise (%.4f apart)"
		% [number, number, part, at.number, part, page, apart],
		looks.contains("\"%s\"" % part.to_lower()) and apart > 0.001
		and _builder.history_depth() == depth + 1)
	# A part id that is not in the step.
	var not_in: String = "3001"
	for brick_id: int in at.brick_ids:
		if _world.get_brick(brick_id).part_id == not_in:
			not_in = "4073"
	var kept: String = str(_world.step_looks)
	answer = await _rpc("tools/call", {"name": "edit_booklet",
		"arguments": {"step": at.number, "pull": {"parts": [not_in]}}})
	said = _text(answer)
	_print(said)
	var named: int = 0
	for brick_id: int in at.brick_ids:
		named += 1 if said.contains("#%d " % brick_id) else 0
	_check("a part id not in the step, %s, refused with the step's %d parts named (%d), nothing changed"
		% [not_in, at.brick_ids.size(), named], said.begins_with("Nothing changed")
		and named == at.brick_ids.size() and str(_world.step_looks) == kept
		and _builder.history_depth() == depth + 1)
	await _rpc("tools/call", {"name": "undo", "arguments": {}})
	_check("...one undo takes the pull back", str(_world.step_looks) != kept
		and _builder.history_depth() == depth)


func _page(number: int, name: String) -> Image:
	var shown: Array[Image] = _images(await _finished(await _rpc("tools/call",
		{"name": "booklet_page", "arguments": {"page": number}})))
	if shown.is_empty():
		return null
	shown[0].save_png(_shots.path_join(name + ".png"))
	return shown[0]


# -- 5. what it made, in six frames ---------------------------------------------------------


func _build_video() -> void:
	print("")
	print("── 5. render_model build: six frames ──")
	var parts: int = _world.brick_count() - _store.scenery.size()
	var started: int = Time.get_ticks_msec()
	var answer: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"kind": "build", "seconds": 10}}))
	var said: String = _text(answer)
	_print(said)
	var shown: Array[Image] = _images(answer)
	var counts: Array = []
	var found: RegExMatch = RegEx.create_from_string("Parts on show in each: ([\\d, ]+) of (\\d+)").search(said)
	if found != null:
		for one: String in found.get_string(1).split(","):
			counts.append(int(one.strip_edges()))
	var rising: bool = counts.size() == 6
	for k: int in range(1, counts.size()):
		rising = rising and int(counts[k]) >= int(counts[k - 1])
	_check("the build video answered with one picture of six frames in %.0f s, parts on show %s, the last the whole model (%d)"
		% [(Time.get_ticks_msec() - started) / 1000.0, str(counts), parts],
		shown.size() == 1 and said.contains("6 of its frames") and rising
		and not counts.is_empty() and int(counts[counts.size() - 1]) == parts
		and int(found.get_string(2)) == parts)
	if shown.is_empty():
		return
	shown[0].save_png(_shots.path_join("5_build_frames.png"))
	var cells: Array[Image] = _cells(shown[0], 6)
	var dialog: RenderDialog = _main.get("_render")
	var built: BuildRender = dialog._last.get("build") as BuildRender
	_check("...laid two across, three down, the first frame not the last (%.3f apart), the video's last frame the whole model"
		% (_apart(cells[0], cells[5]) if cells.size() == 6 else 0.0),
		cells.size() == 6 and _apart(cells[0], cells[5]) > 0.02 and built != null
		and built.shown[built.frames - 1] == parts)


func _motion_frames() -> void:
	print("")
	print("── 5b. render_motion: six frames ──")
	var real: String = ProjectSettings.globalize_path(DOORS)
	if not FileAccess.file_exists(real):
		_check("1484-1's doors to render (tools/omr.py fetch brings the sets)", false)
		return
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 600:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(20)
	var kept: String = _text(await _rpc("tools/call", {"name": "define_motion",
		"arguments": {"name": "Open the doors", "suggested": true}}))
	_print(kept)
	var answer: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_motion",
		"arguments": {"name": "Open the doors"}}))
	var said: String = _text(answer)
	_print(said)
	var shown: Array[Image] = _images(answer)
	var cells: Array[Image] = _cells(shown[0], 6) if shown.size() == 1 else []
	if shown.size() == 1:
		shown[0].save_png(_shots.path_join("5_motion_frames.png"))
	_check("render_motion answered with six frames in one picture, the first not the last",
		said.contains("6 of its frames") and cells.size() == 6 and _apart(cells[0], cells[5]) > 0.005)


## [param count] frames laid as PosePanel.sheet_of lays them, two across.
func _cells(sheet: Image, count: int) -> Array[Image]:
	var out: Array[Image] = []
	var rows: int = ceili(float(count) / 2.0)
	var wide: int = (sheet.get_width() - PosePanel.SHEET_GAP) / 2
	var high: int = (sheet.get_height() - PosePanel.SHEET_GAP * (rows - 1)) / rows
	if wide <= 0 or high <= 0 or wide * 2 + PosePanel.SHEET_GAP != sheet.get_width() \
			or high * rows + PosePanel.SHEET_GAP * (rows - 1) != sheet.get_height():
		return out
	for k: int in count:
		out.append(sheet.get_region(Rect2i((k % 2) * (wide + PosePanel.SHEET_GAP),
			(k / 2) * (high + PosePanel.SHEET_GAP), wide, high)))
	return out


# -- measures -----------------------------------------------------------------------


static func _apart(a: Image, b: Image) -> float:
	var one: Image = a.duplicate() as Image
	var two: Image = b.duplicate() as Image
	one.convert(Image.FORMAT_RGB8)
	two.convert(Image.FORMAT_RGB8)
	if one.get_size() != two.get_size():
		return 1.0
	var x: PackedByteArray = one.get_data()
	var y: PackedByteArray = two.get_data()
	var sum: int = 0
	for at: int in x.size():
		sum += absi(x[at] - y[at])
	return float(sum) / float(maxi(x.size(), 1)) / 255.0


static func _share(image: Image, test: Callable) -> float:
	var copy: Image = image.duplicate() as Image
	copy.convert(Image.FORMAT_RGB8)
	var data: PackedByteArray = copy.get_data()
	var hits: int = 0
	for at: int in range(0, data.size(), 3):
		if test.call(Color8(data[at], data[at + 1], data[at + 2])):
			hits += 1
	return float(hits) / float(maxi(data.size() / 3, 1))


static func _share_at(image: Image, where: Array, test: Callable) -> float:
	if where.is_empty():
		return 0.0
	var width: int = image.get_width()
	var hits: int = 0
	for at: int in where:
		if test.call(image.get_pixel(at % width, at / width)):
			hits += 1
	return float(hits) / float(where.size())


static func _is_magenta(c: Color) -> bool:
	return c.r > 0.85 and c.b > 0.85 and c.g < 0.2


## The codes as booklet_codes writes them: [number mod 6912, new], or
## [0, false] where no part is.
static func _code(data: PackedByteArray, at: int, channels: int) -> Array:
	var r: int = data[at * channels]
	var g: int = data[at * channels + 1]
	var b: int = data[at * channels + 2]
	if r < 40 or g < 40 or b < 40:
		return [0, false]
	var lr: int = roundi((r - 64) / 8.0)
	var lg: int = roundi((g - 64) / 8.0)
	var lb: int = roundi((b - 64) / 8.0)
	return [lr + 24 * lg + 576 * (lb / 2), lb % 2 == 1]


## The edge pixels of the new parts [param mine] says are wanted.
static func _ring(codes: Image, mine: Callable) -> Array:
	var data: PackedByteArray = codes.get_data()
	var channels: int = 4 if codes.get_format() == Image.FORMAT_RGBA8 else 3
	var width: int = codes.get_width()
	var height: int = codes.get_height()
	var numbers := PackedInt32Array()
	numbers.resize(width * height)
	for at: int in width * height:
		var code: Array = _code(data, at, channels)
		numbers[at] = int(code[0]) if bool(code[1]) and mine.call(int(code[0])) else 0
	var out: Array = []
	for y: int in range(1, height - 1):
		for x: int in range(1, width - 1):
			var at: int = y * width + x
			var number: int = numbers[at]
			if number == 0:
				continue
			if numbers[at - 1] != number or numbers[at + 1] != number \
					or numbers[at - width] != number or numbers[at + width] != number:
				out.append(at)
	return out


static func _where_magenta(image: Image) -> Dictionary:
	var copy: Image = image.duplicate() as Image
	copy.convert(Image.FORMAT_RGB8)
	var data: PackedByteArray = copy.get_data()
	var out: Dictionary = {}
	for at: int in range(0, data.size(), 3):
		if data[at] > 216 and data[at + 2] > 216 and data[at + 1] < 51:
			out[at / 3] = true
	return out


static func _set_of(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for at: int in list:
		out[at] = true
	return out


static func _grown(pixels: Dictionary, by: int) -> Dictionary:
	var width: int = ModelShot.SIZE
	var out: Dictionary = {}
	for at: int in pixels:
		var x: int = at % width
		var y: int = at / width
		for dy: int in range(-by, by + 1):
			for dx: int in range(-by, by + 1):
				var nx: int = x + dx
				var ny: int = y + dy
				if nx >= 0 and ny >= 0 and nx < width and ny < width:
					out[ny * width + nx] = true
	return out


static func _numbered(codes: Image, order: Array) -> PackedInt32Array:
	var data: PackedByteArray = codes.get_data()
	var channels: int = 4 if codes.get_format() == Image.FORMAT_RGBA8 else 3
	var out := PackedInt32Array()
	out.resize(codes.get_width() * codes.get_height())
	for at: int in out.size():
		var number: int = int(_code(data, at, channels)[0])
		out[at] = int(order[number - 1]) if number > 0 and number <= order.size() else 0
	return out


# -- helpers ------------------------------------------------------------------------


func _see() -> SeeTools:
	return (_socket.call("_the_app_tools") as AppTools)._see


func _open_car() -> void:
	_main.call("clear_model")
	await _frames(5)
	var placed: int = _store.open("res://models/car.ldr")
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	await _frames(20)


func _put(part: String, colour: int, at: Vector3) -> int:
	var where := Transform3D(Basis.IDENTITY, at)
	var depth: int = _builder.history_depth()
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	_builder.fold_since(depth)
	return brick_id


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


func _finished(result: Dictionary) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	if found == null:
		return result
	for _n: int in 600:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments":
			{"id": int(found.get_string(1))}})
		if not _text(polled).contains(" is still going"):
			return polled
	return {"content": [{"type": "text", "text": "the job never ended"}]}


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
				out.append(picture)
	return out


func _print(said: String) -> void:
	print("    " + said.replace("\n", "\n    "))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
