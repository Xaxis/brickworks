## Does a session see what a person sees (APP_UX4, seeing)? Each tool called
## the way the connector and the desktop's MCP port call it
## (CommandSocket.answer_rpc, tools/call), and its picture measured against
## the app's own drawing of the same.
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 \
##       --script src/dev/seeing_probe.gd
##
## PROBE_SIZE=1280x720 tools/probe.sh seeing runs it at a laptop's size.
## Keeps every picture a call answered with, and the window, in
## SEEING_SHOTS, or user://seeing_probe.
##
## On the car (models/car.ldr):
##   1. view_board: six views in 1 call, one picture, each labelled, and each
##      within MOST_APART of view_model's own view from that side, drawn at
##      the board's size;
##   2. highlight= three parts: their edges magenta (EDGED_LEAST of the ring
##      round each part where it shows), every other part drawn at
##      GHOST_MOST of its own strength or less, part by part;
##   3. xray= the roof: the seat, out of sight from the top, in the picture
##      in its own colour where the roof hid it;
##   4. step=3: the parts of steps 1 to 3 and no others, as the app draws
##      them alone, step 3's edged in magenta and nothing else;
##   5. booklet_page page 2 within MOST_APART of the PDF's page 2 (the
##      person's Instructions, Save as PDF), drawn by poppler at the same size;
##   6. split_parts with picture=true answers with a picture of the whole
##      model, merge_parts unasked with a close look at what it made, edged,
##      mirror_parts with picture=false in words alone, each one undo;
##   7. render_model Best says "Path traced, N samples" where the card traces
##      and "frames averaged" where it does not (a card that cannot, and a
##      picture with nothing behind it);
##   and none of view_board and booklet_page changes the model or its history.
extends SceneTree

## The most two pictures of one thing may differ: the mean over every
## pixel's channels of how far apart they are, 0 to 1.
const MOST_APART := 0.03
## Of the ring round each picked-out part where it shows, at least this
## much is magenta.
const EDGED_LEAST := 0.9
## The most of its own strength a part not picked out is drawn at.
const GHOST_MOST := 0.4
const BACK := Color(0.93, 0.94, 0.96)

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _next: int = 0
var _shots: String = ""
var _window: String = ""


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
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var size: Vector2i = DisplayServer.window_get_size()
	_window = "%dx%d" % [size.x, size.y]
	_shots = OS.get_environment("SEEING_SHOTS")
	if _shots.is_empty():
		_shots = OS.get_user_data_dir().path_join("seeing_probe")
	_shots = _shots.path_join(_window)
	DirAccess.make_dir_recursive_absolute(_shots)
	print("seeing: the window %s, pictures in %s" % [_window, _shots])
	if not ModelShot.possible():
		print("seeing probe: SKIPPED: no window to draw in")
		quit(1)
		return

	var listed: Dictionary = await _rpc("tools/list", {})
	var tools: Dictionary = {}
	for tool: Dictionary in listed.get("tools", []):
		tools[str(tool["name"])] = tool
	_check("tools/list offers view_board and booklet_page",
		tools.has("view_board") and tools.has("booklet_page"))
	var takes: Array = ["mirror_parts", "split_parts", "merge_parts"].filter(func(name: String) -> bool:
		return tools.has(name) and ((tools[name]["inputSchema"] as Dictionary)["properties"]
			as Dictionary).has("picture"))
	_check("...and mirror_parts, split_parts and merge_parts take picture= (%d of 3)" % takes.size(),
		takes.size() == 3)

	await _open_car()
	var model: Array = _signature()
	var depth: int = _builder.history_depth()
	await _board()
	await _highlight()
	await _xray()
	await _step()
	await _booklet()
	_check("view_board and booklet_page changed nothing: the model and its history as they were",
		_signature() == model and _builder.history_depth() == depth)
	await _hand_pictures()
	await _best_words()
	await _frames(10)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_shots.path_join("window.png"))
	print("")
	print("seeing: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- 1. six views in one ------------------------------------------------------------


func _board() -> void:
	print("")
	print("── 1. view_board: six views in one call ──")
	var before: int = _next
	var started: int = Time.get_ticks_msec()
	var answer: Dictionary = await _rpc("tools/call", {"name": "view_board", "arguments": {}})
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	var pictures: Array[Image] = _images(answer)
	_print(_text(answer))
	_check("six views in %d call, %.1f s, %d picture" % [_next - before, seconds, pictures.size()],
		_next - before == 1 and pictures.size() == 1)
	if pictures.is_empty():
		return
	var board: Image = pictures[0]
	board.save_png(_shots.path_join("1_board.png"))
	var cell: int = SeeTools.CELL
	var high: int = cell + ModelShot.LABEL_HIGH
	_check("...a board of 3 x 2 cells, %d x %d px" % [board.get_width(), board.get_height()],
		board.get_width() == 3 * cell and board.get_height() == 2 * high)
	var said: String = _text(answer)
	var worst: float = 0.0
	var labelled: int = 0
	for index: int in SeeTools.VIEWS.size():
		var view: String = SeeTools.VIEWS[index]
		var at := Vector2i((index % 3) * cell, (index / 3) * high)
		var label: Image = board.get_region(Rect2i(at, Vector2i(cell, ModelShot.LABEL_HIGH - 2)))
		var inked: float = _share(label, func(c: Color) -> bool: return c.get_luminance() < 0.4)
		labelled += 1 if inked > 0.005 and said.contains(view) else 0
		var shown: Image = board.get_region(Rect2i(at + Vector2i(0, ModelShot.LABEL_HIGH),
			Vector2i(cell, cell)))
		var alone: Array[Image] = _images(await _rpc("tools/call", {"name": "view_model",
			"arguments": {"from": view}}))
		if alone.is_empty():
			_check("view_model from the %s answers with a picture" % view, false)
			continue
		var own: Image = alone[0]
		own.save_png(_shots.path_join("1_view_model_%s.png" % view))
		own.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
		var apart: float = _apart(shown, own)
		worst = maxf(worst, apart)
		print("    %s: %.4f apart from view_model's, label ink %.1f%%" % [view, apart, inked * 100.0])
	_check("each of the six labelled (%d)" % labelled, labelled == 6)
	_check("...and each within %.2f of view_model's own view from that side (worst %.4f)" % [
		MOST_APART, worst], worst <= MOST_APART)


# -- 2. three parts picked out ------------------------------------------------------


func _highlight() -> void:
	print("")
	print("── 2. highlight= three parts ──")
	# Three parts of the car's body that show from the corner, apart.
	var picked: Array = [_part_at("4070", 1), _part_at("3005", 1), _part_at("3788", 1)]
	if not _check("three parts to pick out: %s" % str(picked), not picked.has(0)):
		return
	var plain: Image = await _one({"views": ["corner"]}, "2_plain")
	var answer: Dictionary = await _rpc("tools/call", {"name": "view_board",
		"arguments": {"views": ["corner"], "highlight": picked}})
	_print(_text(answer))
	var shown: Array[Image] = _images(answer)
	if not _check("view_board highlight= answers with one picture", shown.size() == 1
			and plain != null):
		return
	var marked: Image = shown[0]
	marked.save_png(_shots.path_join("2_highlight.png"))
	var see: SeeTools = _see()
	var codes: Image = see._shot._codes.get_texture().get_image()
	# Which part each pixel shows, in the picture as the app draws it, from
	# a picture-taker of the probe's own.
	var ids: Dictionary = await _ids({}, "corner")
	if not _check("the parts each pixel shows read", not ids.is_empty()):
		return
	# 1. Each picked part's ring, where it shows, magenta.
	var rings: Array = []
	var stage_of: Dictionary = {}
	for n: int in picked.size():
		stage_of[n + 1] = picked[n]
	var edged_ok: int = 0
	for brick_id: int in picked:
		var ring: Array = _ring(codes, func(number: int) -> bool:
			return int(stage_of.get(number, 0)) == brick_id)
		var magenta: float = _share_at(marked, ring, _is_magenta)
		rings.append("#%d %d px %.0f%%" % [brick_id, ring.size(), magenta * 100.0])
		edged_ok += 1 if ring.size() > 40 and magenta >= EDGED_LEAST else 0
	_check("each picked part's edge magenta, at least %d%% of its ring: %s" % [
		roundi(EDGED_LEAST * 100.0), ", ".join(rings)], edged_ok == 3)
	# 2. Every other part drawn at GHOST_MOST of its strength or less.
	var near: Dictionary = _grown(_where(codes, func(number: int) -> bool:
		return stage_of.has(number)), 4)
	var strongest: float = 0.0
	var strongest_id: int = 0
	var counted: int = 0
	# Measured where the part is alone on the line of sight: where others
	# stand behind it, a see-through part's pixel is theirs as well.
	var parts: Dictionary = ids["alone"]
	for brick_id: int in parts:
		if picked.has(brick_id):
			continue
		var strength: float = _strength(plain, marked, parts[brick_id], near)
		if strength < 0.0:
			continue
		counted += 1
		if strength > strongest:
			strongest = strength
			strongest_id = brick_id
	_check("every other part drawn at %d%% of its strength or less, where it is alone on the line of sight: %d parts, the strongest #%d at %.0f%%" % [
		roundi(GHOST_MOST * 100.0), counted, strongest_id, strongest * 100.0],
		counted >= 10 and strongest <= GHOST_MOST)


# -- 3. through the roof ------------------------------------------------------------


func _xray() -> void:
	print("")
	print("── 3. xray= the car's roof ──")
	var seat: BrickWorld.Brick = _world.get_brick(_part_at("4079", 1))
	if not _check("the car's seat", seat != null):
		return
	var seat_box: AABB = _box(seat)
	# The roof: what is over the seat.
	var roof: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id) or brick.id == seat.id:
			continue
		var box: AABB = _box(brick)
		if box.position.y >= seat_box.end.y - 0.5 and box.position.x < seat_box.end.x \
				and box.end.x > seat_box.position.x and box.position.z < seat_box.end.z \
				and box.end.z > seat_box.position.z:
			roof.append(brick.id)
	print("    the roof over it: %s" % ", ".join(PackedStringArray(roof.map(func(id: int) -> String:
		return "#%d %s" % [id, _world.get_brick(id).part_id]))))
	var hidden: Dictionary = await _ids({}, "top")
	var through: Dictionary = await _ids(_id_set(roof), "top")
	var before: int = (hidden["parts"] as Dictionary).get(seat.id, []).size()
	var seen: Array = (through["parts"] as Dictionary).get(seat.id, [])
	var plain: Image = await _one({"views": ["top"]}, "3_plain_top")
	var answer: Dictionary = await _rpc("tools/call", {"name": "view_board",
		"arguments": {"views": ["top"], "xray": roof}})
	_print(_text(answer))
	var shown: Array[Image] = _images(answer)
	if not _check("view_board xray= answers with one picture", shown.size() == 1 and plain != null):
		return
	shown[0].save_png(_shots.path_join("3_xray_roof.png"))
	var seat_colour: Color = _library.color(seat.color_code).shown
	var like_seat := func(c: Color) -> bool:
		return _hue_near(c, seat_colour)
	var in_xray: float = _share_at(shown[0], seen, like_seat)
	var in_plain: float = _share_at(plain, seen, like_seat)
	_check("the seat hidden from the top (%d px in sight), under the roof: %d px of it in sight through it" % [
		before, seen.size()], before < 20 and seen.size() > 400)
	_check("...and in the picture there in its own colour: %.0f%% of those pixels, %.0f%% without x-ray" % [
		in_xray * 100.0, in_plain * 100.0], in_xray >= 0.6 and in_plain <= 0.1)


# -- 4. as built to a step ----------------------------------------------------------


func _step() -> void:
	print("")
	print("── 4. step=3 ──")
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery, {},
		true)
	var upto: Dictionary = {}
	var fresh: Dictionary = {}
	for step: Instructions.Step in steps:
		if step.number > 3:
			continue
		for brick_id: int in step.brick_ids:
			upto[brick_id] = true
			if step.number == 3:
				fresh[brick_id] = true
	var answer: Dictionary = await _rpc("tools/call", {"name": "view_board",
		"arguments": {"views": ["corner"], "step": 3}})
	var said: String = _text(answer)
	_print(said)
	var shown: Array[Image] = _images(answer)
	if not _check("view_board step=3 answers with one picture, %d parts in steps 1 to 3, %d new in 3" % [
			upto.size(), fresh.size()], shown.size() == 1 and fresh.size() > 0
			and said.contains("As built to step 3 of %d, %d parts" % [steps[steps.size() - 1].number,
				upto.size()])):
		return
	var marked: Image = shown[0]
	marked.save_png(_shots.path_join("4_step_3.png"))
	# The app's own drawing of steps 1 to 3 alone.
	var skip: Dictionary = _store.scenery.duplicate()
	for brick: BrickWorld.Brick in _world.bricks():
		if not upto.has(brick.id):
			skip[brick.id] = true
	var shot := ModelShot.new()
	shot.library = _library
	root.add_child(shot)
	var alone: Image = await shot.take(_world, "corner", skip)
	shot.queue_free()
	alone.save_png(_shots.path_join("4_steps_1_to_3_alone.png"))
	var codes: Image = _see()._shot._codes.get_texture().get_image()
	# Step 3's parts are the codes' new ones: the rest are numbered first.
	var is_new := func(number: int) -> bool: return number > upto.size() - fresh.size()
	var near: Dictionary = _grown(_where_magenta(marked), 1)
	var apart: float = _apart(marked, alone, near)
	_check("the parts of steps 1 to 3 and no others, as the app draws them alone: %.4f apart, the magenta left out" % apart,
		apart <= MOST_APART)
	var ring: Array = _ring(codes, is_new)
	var edged: float = _share_at(marked, ring, _is_magenta)
	_check("step 3's parts edged in magenta: %.0f%% of their ring (%d px)" % [edged * 100.0,
		ring.size()], ring.size() > 40 and edged >= EDGED_LEAST)
	var reach: Dictionary = _grown(_set_of(ring), 3)
	var stray: int = 0
	var all_magenta: Dictionary = _where_magenta(marked)
	for at: int in all_magenta:
		stray += 0 if reach.has(at) else 1
	_check("...and nothing else: %d of %d magenta px away from their edge" % [stray,
		all_magenta.size()], stray <= all_magenta.size() / 50)


# -- 5. a booklet page --------------------------------------------------------------


func _booklet() -> void:
	print("")
	print("── 5. booklet_page page 2 ──")
	var started: int = Time.get_ticks_msec()
	var answer: Dictionary = await _finished(await _rpc("tools/call", {"name": "booklet_page",
		"arguments": {"page": 2}}))
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	_print(_text(answer))
	var shown: Array[Image] = _images(answer)
	if not _check("booklet_page page 2 answers with its picture in %.1f s" % seconds,
			shown.size() == 1):
		return
	var page: Image = shown[0]
	page.save_png(_shots.path_join("5_booklet_page_2.png"))
	# The person's way: Instructions, then Save as PDF.
	var dir: String = OS.get_user_data_dir().path_join("seeing_booklet")
	DirAccess.make_dir_recursive_absolute(dir)
	var html: String = dir.path_join("car_instructions.html")
	await _main.call("_export_booklet", html)
	var pdf: String = dir.path_join("car.pdf")
	var wrote: String = await _main.call("save_booklet_as", "pdf", pdf)
	print("    %s" % wrote)
	var stem: String = dir.path_join("pdf")
	OS.execute("pdftoppm", ["-png", "-f", "2", "-l", "2", "-scale-to-x", str(page.get_width()),
		"-scale-to-y", str(page.get_height()), pdf, stem])
	var drawn: Image = null
	for name: String in ["pdf-2.png", "pdf-02.png", "pdf-002.png"]:
		if FileAccess.file_exists(dir.path_join(name)):
			drawn = Image.load_from_file(dir.path_join(name))
	if not _check("the PDF's page 2, drawn by poppler at %d x %d" % [page.get_width(),
			page.get_height()], drawn != null and drawn.get_size() == page.get_size()):
		return
	drawn.save_png(_shots.path_join("5_pdf_page_2.png"))
	var apart: float = _apart(page, drawn)
	_check("booklet_page's page 2 within %.2f of the PDF's: %.4f apart" % [MOST_APART, apart],
		apart <= MOST_APART)


# -- 6. the hand tools, pictured ----------------------------------------------------


func _hand_pictures() -> void:
	print("")
	print("── 6. split, merge and mirror, pictured ──")
	var plate: int = _put("3020", 4, Vector3(400.0, 96.0, 0.0))
	var depth: int = _builder.history_depth()
	var answer: Dictionary = await _rpc("tools/call", {"name": "split_parts",
		"arguments": {"bricks": [plate], "picture": true}})
	_print(_text(answer))
	var shown: Array[Image] = _images(answer)
	var magenta: float = _share(shown[0], _is_magenta) if not shown.is_empty() else 0.0
	_check("split_parts picture=true answers with a picture of the whole model, %s, %.1f%% magenta" % [
		str(shown[0].get_size()) if not shown.is_empty() else "none", magenta * 100.0],
		shown.size() == 1 and shown[0].get_width() == ModelShot.SIZE and magenta > 0.001
		and _builder.history_depth() == depth + 1)
	if not shown.is_empty():
		shown[0].save_png(_shots.path_join("6_split_picture_true.png"))
	var pieces: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3024" and brick.transform.origin.x > 360.0:
			pieces.append(brick.id)
	answer = await _rpc("tools/call", {"name": "merge_parts", "arguments": {"bricks": pieces}})
	_print(_text(answer))
	shown = _images(answer)
	magenta = _share(shown[0], _is_magenta) if not shown.is_empty() else 0.0
	_check("merge_parts unasked answers with a close look at what it made, %s, %.1f%% magenta" % [
		str(shown[0].get_size()) if not shown.is_empty() else "none", magenta * 100.0],
		shown.size() == 1 and shown[0].get_width() == SeeTools.CLOSE_UP and magenta > 0.002)
	if not shown.is_empty():
		shown[0].save_png(_shots.path_join("6_merge_close_up.png"))
	var made: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.transform.origin.x > 360.0 and not _store.scenery.has(brick.id):
			made.append(brick.id)
	answer = await _rpc("tools/call", {"name": "mirror_parts",
		"arguments": {"bricks": made, "copy": true, "picture": false}})
	_print(_text(answer))
	_check("mirror_parts picture=false answers in words alone",
		_images(answer).is_empty() and _text(answer).begins_with("Mirrored"))
	for _n: int in 3:
		await _rpc("tools/call", {"name": "undo", "arguments": {}})
	_check("three undos take the three changes back", _builder.history_depth() == depth)


# -- 7. how Best was drawn ----------------------------------------------------------


func _best_words() -> void:
	print("")
	print("── 7. render_model Best says how it was drawn ──")
	var traces: bool = PathTracer.available()
	var answer: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"quality": "best", "size": "720p"}}))
	var said: String = _text(answer)
	_print(said)
	if traces:
		_check("on this card, which traces: \"Path traced, %d samples\"" % RenderSettings.TRACED_SAMPLES,
			said.contains("Path traced, %d samples" % RenderSettings.TRACED_SAMPLES))
	else:
		_check("on this card, which does not trace: \"frames averaged\"",
			said.contains("frames averaged") and not said.contains("Path traced"))
	answer = await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"quality": "best", "size": "720p", "backdrop": "none"}}))
	said = _text(answer)
	_print(said)
	_check("with nothing behind the model: \"frames averaged\", and not path traced, said",
		said.contains("frames averaged") and not said.contains("Path traced")
		and (not traces or said.contains("not path traced")))
	if traces:
		# A card that cannot trace, as the web's and Compatibility's.
		PathTracer._can = false
		answer = await _finished(await _rpc("tools/call", {"name": "render_model",
			"arguments": {"quality": "best", "size": "720p"}}))
		said = _text(answer)
		_print(said)
		PathTracer._can = true
		_check("on a card that cannot trace: \"frames averaged\", and why",
			said.contains("frames averaged") and not said.contains("Path traced"))


# -- measures -----------------------------------------------------------------------


## The mean over every pixel's channels of how far [param a] and [param b]
## are apart, 0 to 1, leaving out the pixels in [param leave] (y * w + x).
static func _apart(a: Image, b: Image, leave: Dictionary = {}) -> float:
	var one: Image = a.duplicate() as Image
	var two: Image = b.duplicate() as Image
	one.convert(Image.FORMAT_RGB8)
	two.convert(Image.FORMAT_RGB8)
	if one.get_size() != two.get_size():
		return 1.0
	var x: PackedByteArray = one.get_data()
	var y: PackedByteArray = two.get_data()
	var sum: int = 0
	var count: int = 0
	for at: int in range(0, x.size(), 3):
		if leave.has(at / 3):
			continue
		sum += absi(x[at] - y[at]) + absi(x[at + 1] - y[at + 1]) + absi(x[at + 2] - y[at + 2])
		count += 3
	return float(sum) / float(maxi(count, 1)) / 255.0


## How much of [param image] [param test] holds for.
static func _share(image: Image, test: Callable) -> float:
	var copy: Image = image.duplicate() as Image
	copy.convert(Image.FORMAT_RGB8)
	var data: PackedByteArray = copy.get_data()
	var hits: int = 0
	for at: int in range(0, data.size(), 3):
		if test.call(Color8(data[at], data[at + 1], data[at + 2])):
			hits += 1
	return float(hits) / float(maxi(data.size() / 3, 1))


## Of the pixels [param where] (y * w + x), how many [param test] holds for.
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


static func _hue_near(c: Color, want: Color) -> bool:
	if c.s < 0.25 or want.s < 0.25:
		return absf(c.v - want.v) < 0.15 and c.s < 0.25 and want.s < 0.25
	return absf(wrapf(c.h - want.h, -0.5, 0.5)) < 0.06


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


## The pixels of [param codes] on the edge of the parts [param mine] says
## are wanted (by their codes' numbers, new ones only): wanted pixels with a
## neighbour that is not that part.
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


## The pixels of [param codes] whose new part [param mine] says is wanted.
static func _where(codes: Image, mine: Callable) -> Dictionary:
	var data: PackedByteArray = codes.get_data()
	var channels: int = 4 if codes.get_format() == Image.FORMAT_RGBA8 else 3
	var out: Dictionary = {}
	for at: int in codes.get_width() * codes.get_height():
		var code: Array = _code(data, at, channels)
		if bool(code[1]) and mine.call(int(code[0])):
			out[at] = true
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


static func _id_set(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for brick_id: int in ids:
		out[brick_id] = true
	return out


## [param pixels] grown by [param by] px each way, on a picture
## ModelShot.SIZE across.
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


## How strongly a part is drawn in [param marked] against [param plain],
## over its pixels [param at] away from [param leave]: how far each is from
## the background, over how far it is when drawn as it is. -1 when too few
## of its pixels stand off the background to say.
static func _strength(plain: Image, marked: Image, at: Array, leave: Dictionary) -> float:
	var width: int = plain.get_width()
	var sum: float = 0.0
	var count: int = 0
	for pixel: int in at:
		if leave.has(pixel):
			continue
		var own: Color = plain.get_pixel(pixel % width, pixel / width)
		var off: float = maxf(absf(own.r - BACK.r), maxf(absf(own.g - BACK.g), absf(own.b - BACK.b)))
		if off < 0.2:
			continue
		var seen: Color = marked.get_pixel(pixel % width, pixel / width)
		var now: float = maxf(absf(seen.r - BACK.r), maxf(absf(seen.g - BACK.g),
			absf(seen.b - BACK.b)))
		sum += minf(now / off, 1.5)
		count += 1
	return sum / float(count) if count >= 30 else -1.0


## Which part each pixel shows, from [param from], with [param through]
## drawn see-through, from a picture-taker of the probe's own with every
## part edged (its codes): {"parts": brick id -> [pixels], "alone": brick id
## -> [pixels where it is the only part on the line of sight]}. Alone is
## where the part nearest the eye is also the part furthest from it: the
## codes drawn again from the other side of the model, along the same line.
func _ids(through: Dictionary, from: String) -> Dictionary:
	var shot := ModelShot.new()
	shot.library = _library
	root.add_child(shot)
	# Numbered as ModelShot._edges_on numbers them: the edged in the world's
	# order, from 1, what is see-through left out.
	var order: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			shot.edged[brick.id] = true
			if not through.has(brick.id):
				order.append(brick.id)
	shot.see_through = through
	var image: Image = await shot.take(_world, from, _store.scenery)
	if image == null:
		shot.queue_free()
		return {}
	var front: PackedInt32Array = _numbered(shot._codes.get_texture().get_image(), order)
	# The same lines of sight from the far side: the camera turned half round
	# its up, through the model, so a pixel's column is mirrored.
	var eye: Transform3D = shot._camera.global_transform
	var behind := Transform3D(Basis(-eye.basis.x, eye.basis.y, -eye.basis.z),
		eye.origin - eye.basis.z * 2.0 * (shot._camera.global_position
			- shot._staged_bounds.get_center()).length())
	shot._codes_camera.global_transform = behind
	shot._codes.render_target_update_mode = SubViewport.UPDATE_ONCE
	await _frames(ModelShot.FRAMES_TO_DRAW)
	var far: Image = shot._codes.get_texture().get_image()
	far.flip_x()
	var back: PackedInt32Array = _numbered(far, order)
	shot.queue_free()
	var parts: Dictionary = {}
	var alone: Dictionary = {}
	for at: int in front.size():
		var brick_id: int = front[at]
		if brick_id == 0:
			continue
		if not parts.has(brick_id):
			parts[brick_id] = []
		(parts[brick_id] as Array).append(at)
		if back[at] == brick_id:
			if not alone.has(brick_id):
				alone[brick_id] = []
			(alone[brick_id] as Array).append(at)
	return {"parts": parts, "alone": alone}


## Each pixel's part by its number in the model, 0 for none, from codes
## numbered in [param order].
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


## The socket's own SeeTools, whose picture-taker drew the last call.
func _see() -> SeeTools:
	return (_socket.call("_the_app_tools") as AppTools)._see


func _one(arguments: Dictionary, name: String) -> Image:
	var shown: Array[Image] = _images(await _rpc("tools/call", {"name": "view_board",
		"arguments": arguments}))
	if shown.is_empty():
		return null
	shown[0].save_png(_shots.path_join(name + ".png"))
	return shown[0]


func _open_car() -> void:
	_main.call("clear_model")
	await _frames(5)
	var placed: int = _store.open("res://models/car.ldr")
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	await _frames(20)


func _part_at(part: String, nth: int) -> int:
	var seen: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and not _store.scenery.has(brick.id):
			seen += 1
			if seen == nth:
				return brick.id
	return 0


func _box(brick: BrickWorld.Brick) -> AABB:
	return (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()


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


## [param result], or when it is a job, the job's answer once it ends.
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
