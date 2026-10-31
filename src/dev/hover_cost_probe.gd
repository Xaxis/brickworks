## What the pointer moving over a big model costs a frame, Select in hand.
##
##   gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
##       --resolution 1280x860 --script src/dev/hover_cost_probe.gd \
##       [-- --model=res://models/orthanc.ldr] [--shots=DIR]
##
## Orthanc (9,429 parts in 19 sub-assemblies) by default. The pointer goes
## from one part's middle to another's in two steps, as a mouse does and as
## the together check moves it, and the frame each step changed the hover
## in is timed: its own work, from the frame's start to the end of its
## drawing. Then the same steps with a still frame between, as a browser
## hands a mouse's steps over, on a device pretended to draw quickly (each
## step draws a frame) and slowly (PointerPace: the steps and the frame
## between draw nothing, the part the pointer rests on is outlined after). Then the hover's pieces, each timed alone on
## the same parts: the part under the pointer, what a click there would
## take (its whole sub-assembly), and that outlined. --shots=DIR: the
## pointer at rest on a part, outlined, at 1280 x 720 and 1400 x 900.
##
## A part of Orthanc is one of a sub-assembly of hundreds, and the hover
## took it whole: every part of the model walked to find the sub-assembly's,
## 11 to 45 ms for each step onto a part of another, and its hundreds drawn
## into the outline's mask, 2 to 10 ms (2026-10-31). The bar: what a click
## would take is found in under TAKES_MS whatever the model's size, and a
## device drawing slowly draws nothing for the steps and the part the
## pointer rests on after. A step's frame is said, not judged: its own work
## is mostly the outline of what it takes, which grows with that, and on a
## box shared with other work the clock stretches it. It runs on a checkout
## from before PointerPace too, to time that.
extends SceneTree

const MODEL := "res://models/orthanc.ldr"
## What a click would take, found, at the worst.
const TAKES_MS := 2.0
const MOVES := 24
## PointerPace, where the checkout has it: a checkout from before it is
## timed too, and has none to pretend with.
const PACE := "res://src/render/pointer_pace.gd"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _verbs: EditVerbs
var _pointer: Vector2 = Vector2.ZERO
var _virtual: bool = OS.get_environment("XAUTHORITY").contains("xvfb-run")
## Each frame since the moves began: [its start, the frames drawn before
## it, the end of its drawing, the card's ms, the hover outline's showings
## before it, the start of its drawing], times in microseconds.
var _log: Array = []
var _hover: SelectionOutline
var _pace: Script = load(PACE) if ResourceLoader.exists(PACE) else null


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var model: String = MODEL
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model = arg.trim_prefix("--model=")
	# As the app runs: a frame drawn only when something changed.
	IdleDraw.begin()
	print("  %s, %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name()])
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 60:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_verbs = _main.get("_verbs")
	_move_to(Vector2(8, 400))
	var placed: int = int(_main.call("_open", model))
	_check("%s opens (%d parts)" % [model.get_file(), placed], placed > 0)
	if placed <= 0:
		_finish()
		return
	if playback != null:
		playback.stop()
	_camera.set_view("default")
	_camera.frame(_main.call("_built_bounds"))
	_verbs.set_mode("select")
	await _settled()
	process_frame.connect(_frame_begins)
	var rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	RenderingServer.frame_pre_draw.connect(_frame_drawing)
	RenderingServer.frame_post_draw.connect(_frame_drawn.bind(rid))

	# Parts whose middles are on show, each of another sub-assembly where
	# there are any, as the together check aims at parts.
	var spots: Array = _spots(8)
	_check("%d parts to point at" % spots.size(), spots.size() >= 4)
	if spots.size() < 4:
		_finish()
		return

	# Each step's frame: the frame the hover changed in, its own work (its
	# start to its drawing's), all of it to the end of its drawing, and
	# whether it drew. The drawing is the window's, a frame of all of
	# Orthanc whatever changed, and here in Xvfb the picture is copied out
	# by the processor too.
	_hover = _main.get("_hover_outline")
	var steps: Array[float] = []
	var wholes: Array[float] = []
	var gpu: Array[float] = []
	var lags: Array[int] = []
	var drew: int = 0
	var outlined: int = 0
	var last: Vector2 = spots[0]["at"]
	_move_to(last)
	await _frames(4)
	# A device that draws quickly: each step drawn in its own frame.
	print("    this window draws a frame in %.0f ms (PointerPace)" % (float(_pace.call("drawn_ms")) if _pace != null else -1.0))
	_pretend(0.0)
	for n: int in MOVES:
		var aim: Vector2 = spots[(n + 1) % spots.size()]["at"]
		for to: Vector2 in [(last + aim) / 2.0, aim]:
			# A move given now is had by this frame's scripts.
			var from: int = _log.size() - 1
			_move_to(to)
			await _frames(6)
			var at: int = _changed(from)
			if at < 0:
				continue
			lags.append(at - from)
			var frame: Array = _log[at]
			var drawn: bool = int(_log[at + 1][1]) > int(frame[1])
			if drawn and int(frame[5]) > 0 and int(frame[2]) > 0:
				steps.append((int(frame[5]) - int(frame[0])) / 1000.0)
				wholes.append((int(frame[2]) - int(frame[0])) / 1000.0)
				drew += 1
				gpu.append(float(frame[3]))
			else:
				steps.append((int(_log[at + 1][0]) - int(frame[0])) / 1000.0)
		last = aim
		outlined += 1 if _hover.visible else 0
	print("    the hover changed %d frames after the step (%d steps that changed it)"
		% [_middle_int(lags), lags.size()])

	# A device drawing slowly, as a browser does in software, and the same
	# steps on one drawing quickly: two steps with a still frame between,
	# as a browser hands a mouse's steps over, 25 to 30 ms apart. Drawing
	# quickly the steps onto another part each draw a frame; drawing slowly
	# they and the frame between draw nothing (that frame drew the outline
	# while the pointer was still for a frame, and in the together check the
	# second step waited for it), and once the pointer rests the part it
	# rests on is drawn outlined.
	var drawn_by: Dictionary = {}
	var paced_shown: int = 0
	for slow: bool in [false, true]:
		_pretend(300.0 if slow else 0.0)
		var during: Array[int] = []
		for n: int in 6:
			var aim: Dictionary = spots[(n + 2) % spots.size()]
			var from: int = _log.size() - 1
			_move_to((last + aim["at"]) / 2.0)
			await _frames(2)
			_move_to(aim["at"])
			await _frames(1)
			# The frames of the steps and the one between, each drawn or not
			# by the time the next began.
			var count: int = 0
			for at: int in range(from, from + 3):
				count += 1 if int(_log[at + 1][1]) > int(_log[at][1]) else 0
			during.append(count)
			# At rest: still for PointerPace.REST_MS, and the frame after.
			await create_timer(0.25).timeout
			await _frames(2)
			if slow:
				# The part the app has there: an edge a pixel off may be its
				# neighbour's.
				var under: int = int(_main.get("_hovered"))
				var there: int = int(_main.call("_brick_under_pointer"))
				if under == there and there > 0 and _hover.visible and _hover.get("_pending") == null \
						and (_hover.get("_copied") as Dictionary).size() + (_hover.get("_shared") as Dictionary).size() > 0:
					paced_shown += 1
				else:
					print("      resting on part %d: hovered %d, outline on %s, waiting %s, the app's part there %d"
						% [int(aim["brick"]), under, _hover.visible, _hover.get("_pending") != null, there])
			last = aim["at"]
		drawn_by[slow] = during
	_pretend(-1.0)
	print("    frames drawn while the pointer stepped: drawing quickly %s, drawing slowly %s; outlined once it rested %d of 6"
		% [_list(drawn_by[false]), _list(drawn_by[true]), paced_shown])
	_check("drawing quickly, the steps draw the hover as they go (%s)" % _list(drawn_by[false]),
		(drawn_by[false] as Array).max() > 0)
	_check("drawing slowly, the pointer's steps onto another part draw no frame (%s)" % _list(drawn_by[true]),
		(drawn_by[true] as Array).max() == 0)
	_check("...and the part it rests on is outlined once it is still (%d of 6)" % paced_shown, paced_shown == 6)

	# The pieces alone, on each spot: the part under the pointer, what a
	# click there takes, and that outlined.
	var under_ms: Array[float] = []
	var takes_ms: Array[float] = []
	var outline_ms: Array[float] = []
	var taken: Array[int] = []
	var outline := SelectionOutline.new()
	outline.world = _world
	outline.library = _main.get("_library")
	outline.colour = SelectionOutline.HOVER
	_main.add_child(outline)
	for spot: Dictionary in spots:
		var began: int = Time.get_ticks_usec()
		var brick_id: int = _verbs.brick_at(spot["at"])
		under_ms.append((Time.get_ticks_usec() - began) / 1000.0)
		began = Time.get_ticks_usec()
		var members: PackedInt64Array = _builder.takes(brick_id)
		takes_ms.append((Time.get_ticks_usec() - began) / 1000.0)
		taken.append(members.size())
		var shown: Dictionary = {}
		for member: int in members:
			shown[member] = true
		began = Time.get_ticks_usec()
		outline.show_selection(shown)
		outline_ms.append((Time.get_ticks_usec() - began) / 1000.0)
		await _frames(2)
	outline.show_selection({})
	outline.queue_free()

	_check("%d steps of %d moves changed the hover, one a move at the least" % [steps.size(), MOVES], steps.size() >= MOVES)
	if steps.is_empty():
		_finish()
		return
	var step_ms: float = _middle(steps)
	print("    %d parts, %d triangles drawn; %d moves of two steps, %d of them onto another part, %d of those drawn, the outline on after %d"
		% [_world.brick_count(), (_main.get("_drawn") as Array)[1], MOVES, steps.size(), drew, outlined])
	print("    a step's frame, its own work: %.1f ms at the median, %.1f at the most (%s); to the end of its drawing %.1f ms; the card's %.1f ms"
		% [step_ms, steps.max(), _list(steps.slice(0, 16)), _middle(wholes), _middle(gpu)])
	print("    the part under the pointer %s ms; what a click takes %s ms (%s parts); outlined %s ms"
		% [_list(under_ms), _list(takes_ms), "/".join(taken.map(func(n: int) -> String: return str(n))),
			_list(outline_ms)])
	_check("what a click would take is found in %.2f ms at the most (under %.0f), %d parts at the most"
		% [takes_ms.max(), TAKES_MS, taken.max()], takes_ms.max() < TAKES_MS)
	_check("the part pointed at is outlined after the moves (%d of %d)" % [outlined, MOVES],
		outlined == MOVES)
	await _shots(spots[1])
	_finish()


## With --shots=DIR, the pointer at rest on [spot]'s part, outlined, at
## 1280 x 720 and 1400 x 900: hover_<size>.png.
func _shots(spot: Dictionary) -> void:
	var dir: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			dir = arg.trim_prefix("--shots=")
	if dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	# Every frame drawn: one with nothing new to draw would never come.
	IdleDraw.end()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1400, 900)]:
		DisplayServer.window_set_size(size)
		await _frames(20)
		_move_to(Vector2(8, 400))
		await _frames(6)
		var brick: BrickWorld.Brick = _world.get_brick(int(spot["brick"]))
		_move_to(_camera.unproject_position(brick.transform.origin))
		await _frames(10)
		await RenderingServer.frame_post_draw
		var path: String = dir.path_join("hover_%dx%d.png" % [size.x, size.y])
		root.get_texture().get_image().save_png(path)
		print("    %s: the pointer on part %d, hovered %d, outlined %s" % [path, brick.id,
			int(_main.get("_hovered")), _hover.visible])


## A device drawing a frame in [ms], or as it is (-1).
func _pretend(ms: float) -> void:
	if _pace != null:
		_pace.call("pretend", ms)


func _frame_begins() -> void:
	_log.append([Time.get_ticks_usec(), Engine.get_frames_drawn(), 0, 0.0,
		_hover.get("_shown_count") if _hover != null else 0, 0])


func _frame_drawing() -> void:
	if not _log.is_empty():
		_log[_log.size() - 1][5] = Time.get_ticks_usec()


func _frame_drawn(rid: RID) -> void:
	if _log.is_empty():
		return
	var frame: Array = _log[_log.size() - 1]
	frame[2] = Time.get_ticks_usec()
	frame[3] = RenderingServer.viewport_get_measured_render_time_gpu(rid)


## The frame from [from] on that showed the hover something new, or -1.
func _changed(from: int) -> int:
	for at: int in range(from, mini(from + 5, _log.size() - 1)):
		if int(_log[at + 1][4]) != int(_log[at][4]):
			return at
	return -1


## [count] parts whose middles are on show and under the pointer there,
## each of another sub-assembly while there are others.
func _spots(count: int) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var view: Rect2 = Rect2(Vector2(360, 120), Vector2(560, 560))
	for brick: BrickWorld.Brick in _world.bricks():
		if out.size() >= count:
			break
		var unit: String = Assemblies.path_of(brick)
		if seen.has(unit) and seen.size() < 19:
			continue
		if _camera.is_position_behind(brick.transform.origin):
			continue
		var at: Vector2 = _camera.unproject_position(brick.transform.origin)
		if not view.has_point(at) or _verbs.brick_at(at) != brick.id or bool(_main.call("_over_panel_at", at)):
			continue
		seen[unit] = true
		out.append({"at": at, "brick": brick.id})
	return out


func _move_to(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _pointer
	_pointer = event.position
	if _virtual:
		Input.warp_mouse(event.position)
	Input.parse_input_event(event)
	# Had now, with the warp: the view reads the system's pointer, which
	# the warp moved at once, and a browser's move comes before the frame
	# that has it, as this frame's scripts are still to run.
	Input.flush_buffered_events()


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


## The model in, its parts' geometry arrived and the workers quiet.
func _settled() -> void:
	var library: PartLibrary = _main.get("_library")
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 120000:
		await process_frame
		var waiting: bool = false
		for brick: BrickWorld.Brick in _world.bricks():
			if library.mesh_for(brick.part_id) == null:
				waiting = true
				break
		if not waiting:
			break
	_world.rebuilds_in_slices = false
	_world.call("_flush")
	await create_timer(3.0).timeout
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _middle(values: Array[float]) -> float:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2] if not sorted.is_empty() else -1.0


func _middle_int(values: Array[int]) -> int:
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2] if not sorted.is_empty() else -1


func _list(values: Array) -> String:
	return "/".join(values.map(func(v: float) -> String: return "%.1f" % v))


func _finish() -> void:
	print("")
	print("hover cost: %s" % ("%d FAILED" % _failures if _failures > 0
		else "a step of the pointer over a big model costs a frame of its own, not the model's"))
	quit(1 if _failures > 0 else 0)
