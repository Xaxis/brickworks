## A part's loading sketch never holds the bin: "32" typed in the bin, whose
## first page is baseplates, and the searches after it, each frame timed with
## the sketches' share of it; and the sketches themselves, pictured.
##
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . \
##     --resolution 1400x900 --script src/dev/bin_sketch_probe.gd
##
## A tile waiting for its picture draws its part from the catalogue
## (PartSketch). The sketch drew every stud as a 20-point cylinder through
## script, and "32" lists 3811 (32 x 32, 1,024 studs), 10a and 10b (24 x 32),
## 51542, 606 and 609 first: 110-213 ms a baseplate, 1,117 ms in one frame at a
## load of 22 (sketchfast, 2026-11-05). Then the tile drew it again on every
## frame of its picture's fade, 2-3 s more across them. Here:
##
##   look     the sketches of parts of every kind (a baseplate, plates, bricks,
##            rounds, slopes, an inverted slope, a beam, a tile, a jumper) at
##            the bin's size and larger, and halfway through a picture's
##            fade, each tile drawn alone: --shots=DIR keeps the picture, for
##            a person to put beside another run's. A tile's material (the
##            shimmer) reaches its sketch.
##   typed    "32" typed in the bin as a person types it, cold, then until
##            every picture in sight has landed and faded in: no frame's
##            sketches take more than [constant BUDGET_MS] ms of it (the
##            grab's budget, under the slack at a load past the box's cores),
##            and no sketch is drawn again while the pictures fade in.
##   later    "3", "6", "brick" and "32" again, each typed over the last: the
##            same of their frames; and each search run whole once more, said
##            in its parts: the search and its tiles made (PartsBin._run_search),
##            the rest of its frame up to its drawing (layout, labels, the
##            tiles' drawing, its sketches of it), the window drawn, and the
##            frame after.
##
## Headless (godot --headless ... --script src/dev/bin_sketch_probe.gd) it
## stands in for the web's script: no picture comes, every tile stays its
## sketch, and the same bar holds of the frames; there is no look.
## --frames says every frame over 24 ms of its own; --only=look|typed runs one.
extends SceneTree

## The most a frame's sketches may take, ms: the grab's budget.
const BUDGET_MS := 24.0
## A key every so often, past the bin's debounce (PartsBin.SEARCH_DEBOUNCE).
const KEY_GAP_MS := 180
const FIRST := "32"
const LATER: Array = ["3", "6", "brick", "32"]
## Parts of every kind the sketch draws.
const LOOK: Array = ["3811", "3024", "3023b", "3001", "3005", "3062b", "3941", "6141",
	"3039", "3040b", "3660a", "4286", "32524", "3070b", "3794b", "3032", "51542"]

var _failures: int = 0
var _headless: bool = false
var _shots: String = ""
var _phase: String = ""
## Each frame's start: [usec, CPU wait so far, sketches' usec so far, sketches
## drawn so far, tiles fading in, phase as it began].
var _samples: Array = []
var _sampling: bool = false
var _bin: PartsBin


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	_headless = DisplayServer.get_name() == "headless"
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not _headless and only in ["", "look"]:
		await _look()
	if only in ["", "typed"]:
		await _typed()
	print("")
	print("bin_sketch: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _wait(count: int) -> void:
	for _n: int in count:
		await process_frame


func _wait_ms(ms: int) -> void:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < ms:
		await process_frame


# -- the sketches, pictured -------------------------------------------------------


func _look() -> void:
	print("\nthe sketches, each tile alone")
	var library := PartLibrary.new()
	if not library.load_catalogue():
		_check("the catalogue loads", false)
		return
	var red: PartLibrary.BrickColor = library.color(4)
	var colour: Color = red.shown if red != null else Color(0.7, 0.1, 0.1)
	var infos: Array = []
	for id: String in LOOK:
		var info: PartLibrary.PartInfo = library.parts.get(id)
		if info == null:
			print("    (%s is not in the catalogue)" % id)
			continue
		infos.append(info)
	var board := ColorRect.new()
	board.color = Color(0.12, 0.13, 0.15)
	board.size = Vector2(root.get_visible_rect().size)
	root.add_child(board)
	var tiles: Array[ThumbTile] = []
	# The bin's size, larger, and halfway through a picture's fade.
	var rows: Array = [[64.0, 1.0], [150.0, 1.0], [64.0, 0.5]]
	var y: float = 8.0
	var clear := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	for row: Array in rows:
		var side: float = row[0]
		var across: int = floori((board.size.x - 16.0) / (side + 4.0))
		for n: int in infos.size():
			var tile := ThumbTile.new((infos[n] as PartLibrary.PartInfo).id, 4)
			tile.sketch = infos[n]
			tile.sketch_colour = colour
			tile.position = Vector2(8.0 + (n % across) * (side + 4.0), y + (n / across) * (side + 4.0))
			tile.size = Vector2(side, side)
			board.add_child(tile)
			tile.material = null
			if float(row[1]) < 1.0:
				# Halfway: its picture landed (see-through here) and fading in.
				tile.show_picture(clear, true)
				tile.set_process(false)
				tile.set("_shown", float(row[1]))
				tile.queue_redraw()
			tiles.append(tile)
		y += ceili(float(infos.size()) / across) * (side + 4.0) + 8.0
	await _wait(4)
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	# The window's pixels for the root's: the app is drawn at its own scale.
	var scale: Vector2 = Vector2(shot.get_size()) / root.get_visible_rect().size
	if not _shots.is_empty():
		DirAccess.make_dir_recursive_absolute(_shots)
		var path: String = _shots.path_join("sketches.png")
		shot.get_region(Rect2i(0, 0, shot.get_width(), mini(shot.get_height(), ceili(y * scale.y)))).save_png(path)
		print("    picture: %s" % path)
	# Every tile drew something in its square.
	var drawn: int = 0
	var ground: Color = board.color
	for tile: ThumbTile in tiles:
		var area := Rect2i(Vector2i(tile.position * scale), Vector2i(tile.size * scale))
		var lit: int = 0
		for py: int in range(area.position.y, area.end.y, 2):
			for px: int in range(area.position.x, area.end.x, 2):
				var pixel: Color = shot.get_pixel(px, py)
				if absf(pixel.r - ground.r) + absf(pixel.g - ground.g) + absf(pixel.b - ground.b) > 0.06:
					lit += 1
		if lit > 8:
			drawn += 1
	_check("every tile draws its part (%d of %d)" % [drawn, tiles.size()], drawn == tiles.size())
	# A tile's material reaches its sketch: one that paints whatever is drawn
	# pure green leaves the sketch green, and nothing else of its colour.
	var green := ShaderMaterial.new()
	green.shader = Shader.new()
	green.shader.code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(0.0, 1.0, 0.0, COLOR.a > 0.01 ? 1.0 : 0.0); }"
	var first: ThumbTile = tiles[1]
	first.material = green
	await _wait(3)
	await RenderingServer.frame_post_draw
	shot = root.get_texture().get_image()
	var greens: int = 0
	var area := Rect2i(Vector2i(first.position * scale), Vector2i(first.size * scale))
	for py: int in range(area.position.y, area.end.y):
		for px: int in range(area.position.x, area.end.x):
			var pixel: Color = shot.get_pixel(px, py)
			if pixel.g > 0.9 and pixel.r < 0.1 and pixel.b < 0.1:
				greens += 1
	_check("a tile's material reaches its sketch, as the shimmer must (%d pixels of %s painted)"
		% [greens, first.part_id], greens > 20)
	board.queue_free()
	await _wait(3)


# -- the bin, typed in ---------------------------------------------------------------


func _typed() -> void:
	print("\n\"%s\" typed in the bin, cold, and the searches after it" % FIRST)
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	var library: PartLibrary = main.get("_library")
	_bin = main.get("_bin")
	var since: int = Time.get_ticks_msec()
	while _bin._offerable == 0 and Time.get_ticks_msec() - since < 60000:
		await process_frame
	_check("the bin is filled (%d parts)" % _bin._offerable, _bin._offerable > 0)
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	(main.get("_bin_dock") as SideDock).set_open(true)
	await _wait_ms(int(SideDock.SLIDE_SECONDS * 2000.0))
	since = Time.get_ticks_msec()
	while not library.search_ready() and Time.get_ticks_msec() - since < 60000:
		await process_frame
	# The first page's pictures in, so what is typed is what is measured.
	await _settled(20000)
	await _wait_ms(500)
	process_frame.connect(_sample)
	_sampling = true
	await _click(_bin._search.get_global_rect().get_center())
	if not _bin._search.has_focus():
		_bin._search.grab_focus()
	_phase = "typed"
	await _type(FIRST)
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 10000 and not _answered(FIRST):
		await process_frame
	_check("\"%s\" answered (%s ...)" % [FIRST, ", ".join(_bin.first_found(8))], _answered(FIRST))
	await _wait(10)
	_phase = "fading"
	var landed: bool = await _settled(30000)
	await _wait_ms(300)
	if not _headless:
		_check("every picture in sight landed and faded in", landed)
	_said("typed", "\"%s\" typed" % FIRST)
	_said("fading", "its pictures landing and fading in")
	var again: Array = _frames_of("fading")
	var redrawn: int = 0
	var fading: int = 0
	for frame: Dictionary in again:
		redrawn += int(frame.draws)
		fading += 1 if int(frame.fading) > 0 else 0
	if not _headless:
		_check("no sketch drawn again as the pictures land and fade in (%d drawn over %d frames, %d of them fading)"
			% [redrawn, again.size(), fading], redrawn == 0 and fading > 0)
	for query: String in LATER:
		_phase = "later " + query
		await _key(KEY_A, true)
		await _type(query)
		since = Time.get_ticks_msec()
		while Time.get_ticks_msec() - since < 10000 and not _answered(query):
			await process_frame
		await _settled(20000)
		await _wait_ms(300)
		_said(_phase, "\"%s\" typed over it" % query)
	_sampling = false
	process_frame.disconnect(_sample)
	print("\n  each search run whole once more, warm, said in its parts")
	for query: String in LATER:
		await _parts_of(query)
	if "--frames" in OS.get_cmdline_user_args():
		for frame: Dictionary in _frames_of(""):
			if float(frame.own) > BUDGET_MS:
				print("    frame %.1f ms of its own, %.1f of it sketches (%d), %.1f waiting (%s)"
					% [frame.own, frame.sketch, frame.draws, frame.waited, frame.phase])
	main.queue_free()
	await _wait(5)


## A frame's own work at the start of each frame, as it began.
func _sample() -> void:
	if not _sampling:
		return
	var fading: int = 0
	if _bin != null:
		for cell: Node in _bin._grid.get_children():
			var tile: Variant = cell.get_meta("tile") if cell.has_meta("tile") else null
			if tile is ThumbTile and (tile as ThumbTile).is_processing():
				fading += 1
	_samples.append([Time.get_ticks_usec(), ProbeTime.waited_ms(), PartSketch.spent_usec,
		PartSketch.drawn, fading, _phase])


## The frames of [param phase] (each frame's phase as it ended; every frame
## for ""), each {own, waited, sketch, draws, fading, phase}.
func _frames_of(phase: String) -> Array:
	var out: Array = []
	for n: int in range(1, _samples.size()):
		var was: Array = _samples[n - 1]
		var now: Array = _samples[n]
		if not phase.is_empty() and str(now[5]) != phase:
			continue
		var waited: float = float(now[1]) - float(was[1])
		out.append({"own": maxf((int(now[0]) - int(was[0])) / 1000.0 - waited, 0.0),
			"waited": waited, "sketch": (int(now[2]) - int(was[2])) / 1000.0,
			"draws": int(now[3]) - int(was[3]), "fading": int(was[4]), "phase": str(now[5])})
	return out


## [param phase]'s frames said, and its sketches' share of each under the bar.
func _said(phase: String, what: String) -> void:
	var frames: Array = _frames_of(phase)
	var longest: Dictionary = {"own": 0.0, "sketch": 0.0, "draws": 0}
	var most: Dictionary = {"own": 0.0, "sketch": 0.0, "draws": 0}
	var total: float = 0.0
	var draws: int = 0
	for frame: Dictionary in frames:
		if float(frame.own) > float(longest.own):
			longest = frame
		if float(frame.sketch) > float(most.sketch):
			most = frame
		total += float(frame.sketch)
		draws += int(frame.draws)
	var bar: float = BUDGET_MS * ProbeTime.slack(ProbeTime.box_load())
	print("    %s: %d frames, the longest %.1f ms of its own (%.1f of it sketches, %d drawn); sketches %.1f ms in all, %d drawn"
		% [what, frames.size(), longest.own, longest.sketch, longest.draws, total, draws])
	_check("%s: a frame's sketches at most %.1f ms (%d drawn in it, the frame %.1f): under %.1f (%s)"
		% [what, most.sketch, most.draws, most.own, bar, ProbeTime.load_said(ProbeTime.box_load())],
		float(most.sketch) < bar)


## [param query] run whole, the search and its tiles made timed on their own,
## then the next frame, its sketches and the rest.
func _parts_of(query: String) -> void:
	_bin._search.set_text(query)
	_bin._pending = false
	var began: int = Time.get_ticks_usec()
	var waited: float = ProbeTime.waited_ms()
	var found: Array = _bin._find(query, _bin._category)
	var finding: float = (Time.get_ticks_usec() - began) / 1000.0 - (ProbeTime.waited_ms() - waited)
	began = Time.get_ticks_usec()
	waited = ProbeTime.waited_ms()
	_bin._run_search(query)
	var run: float = (Time.get_ticks_usec() - began) / 1000.0 - (ProbeTime.waited_ms() - waited)
	var spent: int = PartSketch.spent_usec
	var drawn: int = PartSketch.drawn
	# The rest of this frame up to its drawing (layout, the tiles' drawing
	# into their canvas items), its drawing, then the next frame whole.
	var marks: Array = [[Time.get_ticks_usec(), ProbeTime.waited_ms()]]
	var drawing: Callable = func() -> void:
		if marks.size() == 1:
			marks.append([Time.get_ticks_usec(), ProbeTime.waited_ms(), PartSketch.spent_usec,
				PartSketch.drawn])
	RenderingServer.frame_pre_draw.connect(drawing)
	await process_frame
	marks.append([Time.get_ticks_usec(), ProbeTime.waited_ms()])
	await process_frame
	marks.append([Time.get_ticks_usec(), ProbeTime.waited_ms()])
	RenderingServer.frame_pre_draw.disconnect(drawing)
	if marks.size() < 4:
		print("    \"%s\": its frame drew nothing" % query)
		await _settled(20000)
		return
	var span: Callable = func(from: int, to: int) -> float:
		return maxf((int(marks[to][0]) - int(marks[from][0])) / 1000.0
			- (float(marks[to][1]) - float(marks[from][1])), 0.0)
	var sketch: float = (int(marks[1][2]) - spent) / 1000.0
	print("    \"%s\" (%d found): the search %.1f ms, its tiles made %.1f; then laid out and drawn %.1f (%.1f of it %d sketches), the window drawn %.1f; the frame after %.1f, %d sketches"
		% [query, found.size(), finding, maxf(run - finding, 0.0), span.call(0, 1), sketch,
			int(marks[1][3]) - drawn, span.call(1, 2), span.call(2, 3), PartSketch.drawn - int(marks[1][3])])
	await _settled(20000)


## Whether the bin lists what [param query] asks: no search of it waiting,
## nor one on a worker (PartsBin._seek) still to be listed.
func _answered(query: String) -> bool:
	var seeking: Variant = _bin.get("_seeking")
	return _bin._search.text == query and not _bin._pending and _bin.get("_waiting") != true \
		and not (seeking is int and int(seeking) >= 0) and not _bin.first_found(1).is_empty()


## Until every tile in sight has its picture and none is fading in, or
## [param ms] pass: whether they did. Headless no picture comes.
func _settled(ms: int) -> bool:
	if _headless:
		await _wait(30)
		return true
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < ms:
		var waiting: int = 0
		var view: Rect2 = (_bin.get("_scroll") as Control).get_global_rect()
		for cell: Node in _bin._grid.get_children():
			var tile: Variant = cell.get_meta("tile") if cell.has_meta("tile") else null
			if not tile is ThumbTile or not view.intersects((cell as Control).get_global_rect()):
				continue
			var one: ThumbTile = tile
			if one.state == ThumbTile.State.LOADING or one.is_processing():
				waiting += 1
		if waiting == 0 and _bin._grid.get_child_count() > 0:
			return true
		await process_frame
	return false


# -- input, as a person sends it ------------------------------------------------


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _wait(2)


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
		await _wait(2)
	await _wait(3)


## [param text] typed a key every [constant KEY_GAP_MS] ms, each pressed and
## let go a frame apart.
func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		var at: int = Time.get_ticks_msec()
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
		while Time.get_ticks_msec() - at < KEY_GAP_MS:
			await process_frame


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _wait(3)
