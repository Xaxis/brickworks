## Is the model in the middle of the room it has, and does a click still
## find the part drawn under it?
##
##   xvfb-run -a -s "-screen 0 2600x1500x24" env MESA_VK_WSI_DEBUG=sw \
##     godot --path . --resolution 1280x720 --script src/dev/centring_probe.gd
##   ...and again at two pixels to the unit, the same interface in a window
##   twice the size (what a Retina screen does to a 1280 x 720 one):
##     godot --path . --resolution 2560x1440 --script src/dev/centring_probe.gd -- --ratio=2
##
## The 3D draws across the whole window, behind the columns, and the view
## was centred on the window: in a laptop's window, with one column open,
## the model sat 168 units to the side of its column. Now the lens is
## shifted to the middle of the model's part of the window (CadCamera.seen).
## The first try at a shifted lens drew the model in the right place and
## then missed every click, because Godot's own ray from the screen assumes
## a centred lens; so this clicks as well as looks.
##
## In a 1280 x 720 window (one column at a time), and with --ratio=2 in a
## window twice that with the interface kept the same size — two device
## pixels to the unit, as a Retina screen has — with each column folded in
## turn:
##
##   - after Fit (F), the middle of the model is within 2% of the middle of
##     the model's part of the window (Main.model_cover's "view"), and all
##     of it is inside;
##   - five parts, each where a straight line from the eye reaches it first
##     (no screen-to-world conversion in choosing them), are each drawn at
##     their point on the screen — hiding the part changes the pixel there —
##     and a click there with Select selects exactly that part.
##
## And a column folding, then folding mid-drag: the model glides to the new
## middle, and under a held button it stays where it is until let go.
##
## And, at 1x, the pictures: File › Export › Picture at its own size, the
## share card's and the Studio thumbnail's, and the critique's shot, of a
## flat car, Orthanc and an L, with each column folded (the view's lens
## shifted one way, then the other): what is drawn in each has its middle
## within 2% of the picture's, fills 80 to 97% of its narrower way and
## touches no edge. Framed on the box round the model, the car's picture
## sat 5% low and filled 64% of it, and the L's 9% low and 8% to the side.
## Pictures go to shots/centring/.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _verbs: EditVerbs
var _library: PartLibrary
var _bin_dock: SideDock
var _chat_dock: SideDock
var _targets: Array[int] = []
var _ratio: int = 1


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")
	_library = _main.get("_library")
	_bin_dock = _main.get("_bin_dock")
	_chat_dock = _main.get("_chat_dock")
	if OS.get_cmdline_user_args().has("--ratio=2"):
		await _two_to_the_unit()
	_main.call("clear_model")
	await _frames(5)

	# Five bricks in five colours, spread over the baseplate, and a tower
	# in the middle so the model has a height to frame.
	var spots: Array[Vector3] = [Vector3(-200, 24, -120), Vector3(200, 24, -120),
		Vector3(-200, 24, 120), Vector3(200, 24, 120), Vector3(0, 24, 160)]
	var colours: Array[int] = [4, 1, 14, 26, 27]
	for n: int in spots.size():
		_targets.append(_put("3001", colours[n], spots[n]))
	for level: int in 4:
		_put("3001", 15, Vector3(0, 24 + 24 * level, -20))
	await _frames(10)
	_verbs.set_mode("select")
	await _frames(3)

	var room: Vector2 = root.get_visible_rect().size
	print("  a %s window, %.2f pixels to the unit, %s units: columns \"%s\""
		% [str(DisplayServer.window_get_size()), float(DisplayServer.window_get_size().x) / room.x,
		str(room.round()), str(_main.get("_columns"))])
	for folded: String in ["assistant", "parts"]:
		await _fold(folded)
		await _fit()
		_centred(folded)
		await _clicks(folded)
		await _shot("%dx_%s_folded" % [_ratio, folded])

	await _glides()
	await _pictures()

	print("")
	if _failures == 0:
		print("centring: after Fit the model is in the middle of its part of the window, "
			+ "and every click finds the part drawn there, at 1x and 2x with either column folded")
	else:
		print("centring: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the checks ---------------------------------------------------------------


## The model's part of the window, as Main.model_cover samples it: between
## the columns, under the bars.
func _view() -> Rect2:
	return (_main.call("model_cover") as Dictionary)["view"]


func _centred(folded: String) -> void:
	var view: Rect2 = _view()
	var bounds: AABB = _main.call("_built_bounds")
	var middle: Vector2 = _camera.unproject_position(bounds.get_center())
	var off: Vector2 = middle - view.get_center()
	var share := Vector2(absf(off.x) / view.size.x, absf(off.y) / view.size.y)
	_check("%dx, %s folded: after Fit the model's middle is %.1f%% across and %.1f%% down from the middle of its part of the window (%.0f, %.0f units)"
		% [_ratio, folded, share.x * 100.0, share.y * 100.0, off.x, off.y],
		share.x <= 0.02 and share.y <= 0.02)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n: int in 8:
		var corner: Vector3 = bounds.position + bounds.size * Vector3(
			float(n & 1), float((n >> 1) & 1), float((n >> 2) & 1))
		var at: Vector2 = _camera.unproject_position(corner)
		lo = lo.min(at)
		hi = hi.max(at)
	var drawn := Rect2(lo, hi - lo)
	# Fit frames the ball round the model to the narrower side of the room
	# it has, with a quarter to spare (CadCamera.frame): about 76% of it.
	# Framed to the window instead, the ball takes about 90% of the model's
	# part here, and more as the bars grow.
	var radius: float = bounds.size.length() * 0.5
	var centre: Vector3 = bounds.get_center()
	var ball: float = 0.0
	for way: Vector3 in [_camera.global_transform.basis.x, _camera.global_transform.basis.y]:
		ball += 0.5 * _camera.unproject_position(centre + way * radius).distance_to(
			_camera.unproject_position(centre - way * radius))
	var fills: float = ball / minf(view.size.x, view.size.y)
	_check("...all of it inside that part, its ball %.0f%% of the narrower side" % (fills * 100.0),
		view.encloses(drawn) and fills > 0.68 and fills < 0.85)


## Five parts, found from the world rather than the screen: a point on each
## one's top that a straight line from the eye meets before anything else.
## Each must be drawn at its point on the screen, and a click there must
## select it and nothing else.
func _clicks(folded: String) -> void:
	var eye: Vector3 = _camera.global_position
	var found: int = 0
	var drawn: int = 0
	var picked: int = 0
	var said: Array[String] = []
	var room: Vector2 = root.get_visible_rect().size
	var pixels: Vector2 = Vector2(DisplayServer.window_get_size()) / room
	for brick_id: int in _targets:
		var point: Vector3 = _top_of(brick_id)
		var hit: BrickLattice.Hit = _builder.lattice.raycast(eye, (point - eye).normalized())
		if not hit.is_valid() or hit.brick_id != brick_id \
				or absf(hit.distance - eye.distance_to(point)) > 6.0:
			said.append("%d hidden from the eye" % brick_id)
			continue
		var at: Vector2 = _camera.unproject_position(point)
		if not _view().grow(-4.0).has_point(at) or _main.call("_over_panel_at", at):
			said.append("%d off the model's part" % brick_id)
			continue
		found += 1
		# Drawn there: hiding it changes what is on the screen at that point.
		var keep: Dictionary = {}
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.id != brick_id:
				keep[brick.id] = true
		_world.show_only(keep)
		var without: Color = await _pixel(at * pixels)
		_world.show_only({})
		var with: Color = await _pixel(at * pixels)
		var change: float = absf(with.r - without.r) + absf(with.g - without.g) \
			+ absf(with.b - without.b)
		if change > 0.15:
			drawn += 1
		else:
			said.append("%d not drawn at %s" % [brick_id, str(at.round())])
		await _click(at)
		var chosen: Array = _builder.selection.keys()
		if chosen == [brick_id]:
			picked += 1
		else:
			said.append("a click on %d chose %s" % [brick_id, str(chosen)])
	_builder.clear_selection()
	await _frames(2)
	_check("%dx, %s folded: %d parts seen from the eye are drawn where they project (%d)%s"
		% [_ratio, folded, found, drawn, ("; " + ", ".join(said)) if not said.is_empty() else ""],
		found == _targets.size() and drawn == found)
	_check("...and a click on each selects exactly that part (%d of %d)" % [picked, found],
		found == _targets.size() and picked == found)


## A column folding moves the model to the new middle a little at a time, and
## not while a button is held: a drag begun on the model keeps it under the
## pointer until let go.
func _glides() -> void:
	print("")
	print("  a column folding")
	await _fold("assistant")
	await _fit()
	var bounds: AABB = _main.call("_built_bounds")
	var middle: Vector3 = bounds.get_center()
	# Where the middle of the model is on the screen, frame by frame, with
	# the clock slowed to a tenth: a window this size drawn in software
	# on a loaded machine gets a few frames a second, and at that rate the
	# column's own 0.22 s slide is over in a frame or two whatever follows
	# it. Game time, so the slide and the camera's easing both slow alike.
	var path: Array[Vector2] = []
	var began: int = Time.get_ticks_usec()
	Engine.time_scale = 0.1
	_bin_dock.set_open(false)
	while Time.get_ticks_usec() - began < 8000000:
		await process_frame
		path.append(Vector2((Time.get_ticks_usec() - began) / 10000000.0,
			_camera.unproject_position(middle).x))
	Engine.time_scale = 1.0
	var start: float = path[0].y
	var travel: float = path[-1].y - start
	var steady: bool = true
	var tenth: int = -1
	var ninth: int = -1
	for n: int in path.size():
		var done: float = (path[n].y - start) / travel if travel != 0.0 else 0.0
		if n > 0 and (path[n].y - path[n - 1].y) * travel < -0.01:
			steady = false
		if tenth < 0 and done >= 0.1:
			tenth = n
		if ninth < 0 and done >= 0.9:
			ninth = n
	var over: float = path[ninth].x - path[tenth].x if tenth >= 0 and ninth >= 0 else 0.0
	var off: float = path[-1].y - _view().get_center().x
	# A jump crosses a tenth of the way and nine tenths in the same frame.
	_check("folding the parts bin glides the model %.0f units to the new middle, most of it over %.2f s and %d frames, never back (%.1f off)"
		% [travel, over, ninth - tenth, off], absf(travel) > 100.0 and steady
		and ninth - tenth >= 2 and absf(off) < _view().size.x * 0.02)

	# Mid-drag: a right drag on the model, a column opening under it.
	var at: Vector2 = _camera.unproject_position(middle)
	await _move(at)
	_right(at, true)
	await _frames(2)
	at += Vector2(12.0, 0.0)
	await _move(at)
	await _frames(4)
	var grabbed: Vector3 = _camera.pivot()
	var was: Vector2 = _camera.unproject_position(grabbed)
	_bin_dock.set_open(true)
	var worst: float = 0.0
	for _n: int in 40:
		await process_frame
		worst = maxf(worst, _camera.unproject_position(grabbed).distance_to(was))
	_check("a column opening mid-drag leaves what was grabbed where it was (%.2f units at worst)"
		% worst, _camera.is_dragging() and worst < 1.0)
	_right(at, false)
	for _n: int in 60:
		await process_frame
	var settled: float = _camera.unproject_position(_camera.focus).x - _view().get_center().x
	_check("...and once let go the view glides to the new middle (%.1f units off)" % settled,
		absf(settled) < _view().size.x * 0.02)


## Each picture of each model, with each column folded: the exported
## picture follows the view's direction, which is the same both times, and
## must not follow its lens, which is not. The critique's shot looks from
## its own corner, so it is taken once, and so is Orthanc, whose 9,429
## parts drawn in software in the window are most of the time this takes.
## At 1x only: a picture is drawn at its own size, whatever the window's
## pixels, and at 2x the window alone took the run past half an hour.
func _pictures() -> void:
	if _ratio != 1:
		return
	print("")
	print("  pictures")
	var began: int = Time.get_ticks_msec()
	var picture: Picture = (_main.get("_exports") as Exports).picture
	var shot := ModelShot.new()
	shot.library = _library
	shot.rulers = false
	root.add_child(shot)
	var sizes: Dictionary = {"export": Picture.SIZE, "share card": SharePanel.CARD,
		"Studio thumbnail": Exports.STUDIO_THUMBNAIL}
	for folded: String in ["assistant", "parts"]:
		await _fold(folded)
		for model: String in ["car", "orthanc", "L"]:
			if model == "orthanc" and folded != "assistant":
				continue
			var opened: int = Time.get_ticks_msec()
			# Not framed by Fit first: a picture is framed by itself, from the
			# way the view looks and nothing else about it.
			await _model(model)
			for named: String in sizes:
				if named != "export" and model != "car":
					continue
				var image: Image = await picture.take(sizes[named])
				_framed("%dx, %s folded, %s's %s picture" % [_ratio, folded, model, named],
					image, "%dx_%s_folded_%s_%s" % [_ratio, folded, model, named.to_snake_case()])
			if folded == "assistant":
				# Its viewport is made by its first picture.
				if shot.get("_viewport") == null:
					await shot.take(_world, "corner", _store.scenery)
				# Drawn on nothing, so what is drawn is what is not clear.
				var view: SubViewport = shot.get("_viewport")
				view.transparent_bg = true
				view.world_3d.environment.background_mode = Environment.BG_CLEAR_COLOR
				_framed("%dx, %s's critique shot" % [_ratio, model],
					await shot.take(_world, "corner", _store.scenery),
					"%dx_%s_critique" % [_ratio, model])
				view.transparent_bg = false
				view.world_3d.environment.background_mode = Environment.BG_COLOR
			print("    (%s, %.0f s)" % [model, (Time.get_ticks_msec() - opened) / 1000.0])
	shot.queue_free()
	print("    (the pictures took %.0f s)" % ((Time.get_ticks_msec() - began) / 1000.0))


## What is drawn in a picture — everything not clear — has its middle within
## 2% of the picture's, fills most of the picture's narrower way, and is not
## cut by an edge.
func _framed(what: String, image: Image, name: String) -> void:
	if image == null:
		_check("%s: there is one" % what, false)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/centring"))
	image.save_png(ProjectSettings.globalize_path("res://shots/centring/%s.png" % name))
	var frame := Vector2(image.get_size())
	var drawn: Rect2i = image.get_used_rect()
	var off: Vector2 = (Vector2(drawn.get_center()) - frame * 0.5) / frame
	var fills: float = maxf(drawn.size.x / frame.x, drawn.size.y / frame.y)
	var clear: bool = drawn.position.x > 0 and drawn.position.y > 0 \
		and drawn.end.x < image.get_width() and drawn.end.y < image.get_height()
	_check("%s: drawn %.1f%% %s and %.1f%% %s of the middle, filling %.0f%% of it%s (shots/centring/%s.png)"
		% [what, absf(off.x) * 100.0, "left" if off.x < 0.0 else "right",
		absf(off.y) * 100.0, "high" if off.y < 0.0 else "low", fills * 100.0,
		"" if clear else ", cut by an edge", name],
		absf(off.x) <= 0.02 and absf(off.y) <= 0.02 and fills >= 0.8 and fills <= 0.97 and clear)


## A flat car (the example), a tall tower (Orthanc, 9,429 parts) or an L:
## a long low arm and a short tall one, whose box is mostly empty.
func _model(which: String) -> void:
	_main.call("clear_model")
	await _frames(3)
	if which == "L":
		for n: int in 8:
			_put("3001", 1, Vector3(-160 + 80 * n, 24, -100))
		for n: int in 5:
			for level: int in 4:
				_put("3003", 4, Vector3(-220, 24 + 24 * level, -60 + 40 * n))
	else:
		_main.call("_open", "res://models/%s.ldr" % which)
	await _frames(5)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	await _frames(3)


# -- gestures -------------------------------------------------------------------


## Fold one column, as a person does in a window with room for one: by
## opening the other's rail. Where both fit, by its own rail.
func _fold(which: String) -> void:
	var folding: SideDock = _chat_dock if which == "assistant" else _bin_dock
	var keeping: SideDock = _bin_dock if which == "assistant" else _chat_dock
	if not keeping.is_open():
		await _click(keeping.rail().get_global_rect().get_center())
	if folding.is_open():
		await _click(folding.rail().get_global_rect().get_center())
	await _frames(40)


func _fit() -> void:
	_builder.clear_selection()
	await _key(KEY_F)
	await _frames(60)


## Twice the device pixels to each unit of the interface, as a Retina
## screen has: the interface laid out as for a window half this size. A
## desktop window this big would otherwise be laid out at its design size.
func _two_to_the_unit() -> void:
	_ratio = 2
	var match_density := Callable(_main, "_match_screen_density")
	if root.size_changed.is_connected(match_density):
		root.size_changed.disconnect(match_density)
	var half: Vector2 = Vector2(DisplayServer.window_get_size()) * 0.5
	root.content_scale_factor = _main.call("screen_factor", half.x, half.y, false)
	await _frames(30)


func _put(part: String, colour: int, at: Vector3) -> int:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	return brick_id


func _top_of(brick_id: int) -> Vector3:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
	return Vector3(box.get_center().x, box.end.y - 6.0, box.get_center().z)


func _pixel(at: Vector2) -> Color:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var x: int = clampi(roundi(at.x), 0, image.get_width() - 1)
	var y: int = clampi(roundi(at.y), 0, image.get_height() - 1)
	return image.get_pixel(x, y)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	return at * (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)


## Where the last event put the pointer, in the window's pixels, so a
## motion can say how far it went: a drag is told from a click by that.
var _pointer: Vector2 = Vector2.ZERO


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _pointer
	event.button_mask = Input.get_mouse_button_mask()
	_pointer = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _right(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if down else 0
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


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
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/centring"))
	image.save_png(ProjectSettings.globalize_path("res://shots/centring/%s.png" % name))
	print("    picture: shots/centring/%s.png" % name)
