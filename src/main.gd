## The workbench: the scene you build in.
##
## For now this is the proof that the pipeline holds end to end — LDraw
## source converted offline, loaded as quantised geometry, batched by shape
## and drawn with per-instance colour — with a real published model opened
## as the test. Everything it does by hand here becomes a tool later.
extends Node3D

## Shipped with the build. It used to be read out of vendor/, which the
## export excludes, so the web build silently fell back to the demo wall.
const SAMPLE_MODEL := "res://models/car.ldr"

@onready var _camera: CadCamera = $CadCamera
@onready var _world: BrickWorld = $BrickWorld
@onready var _builder: Builder = $Builder
@onready var _status: Label = $HUD/Status
@onready var _title: Label = $HUD/Title

var _catalogue_ms: int = 0
var _stability: Stability
var _stability_text: String = ""
var _counts_base: String = ""
var _stability_at: int = 0
var _counts: Label
var _bin_dock: SideDock
var _chat_dock: SideDock
var _store: ModelStore
var _bar: ModelBar
var _bin: PartsBin
var _chat: ChatPanel
var _account: Account
var _steps: StepsBar
var _thumbnails: PartThumbnails
var _assistant: Assistant

var _library: PartLibrary


func _ready() -> void:
	_library = PartLibrary.new()
	var started: int = Time.get_ticks_msec()
	if not _library.load_catalogue():
		_title.text = "No catalogue"
		_status.text = "Run tools/build_meshes.py to generate assets/generated/."
		return
	_catalogue_ms = Time.get_ticks_msec() - started

	_world.library = _library
	_world.rebuilt.connect(_on_rebuilt)
	_builder.world = _world
	_builder.library = _library
	_build_ui()

	var stress: String = _argument("--stress")
	var wanted: String = _argument("--model")
	var placed: int = 0
	if not stress.is_empty():
		placed = _build_stress(stress.to_int())
	elif not wanted.is_empty():
		placed = _open(wanted)
		if placed == 0:
			push_error("could not open %s" % wanted)
	else:
		# Whatever was on screen last time comes back first; the sample
		# model is only for a first visit.
		placed = _store.restore()
		if placed == 0:
			placed = _open(SAMPLE_MODEL)
		if placed == 0:
			placed = _build_demo()
	_lay_baseplate()


	# Wait a frame so the deferred batch rebuild has run and the bounds are
	# real before framing them.
	await get_tree().process_frame
	_camera.frame(_world.model_bounds())

	var autobuild: String = _argument("--autobuild")
	if not autobuild.is_empty():
		_autobuild(autobuild.to_int())

	var ask: String = _argument("--ask")
	if not ask.is_empty():
		await _ask(ask)

	if not _argument("--showcase").is_empty():
		_showcase()

	var bench: String = _argument("--bench")
	if not bench.is_empty():
		await _benchmark(bench.to_int())

	var shot: String = _argument("--shot")
	if not shot.is_empty():
		await _capture(shot)


## A few parts, close up, for judging how they look rather than whether
## they are in the right place.
func _showcase() -> void:
	_world.clear()
	_builder.lattice.clear()
	var wanted: String = _argument("--showcase")
	var row: Array = [
		["3001", 4], ["3003", 14], ["3024", 15], ["3062b", 1],
		["3040b", 2], ["3941", 25], ["4073", 47], ["3005", 0],
	]
	if wanted != "1" and not wanted.is_empty():
		row = [[wanted, 4]]
	var x: float = 0.0
	for entry: Array in row:
		var at := Transform3D(Basis.IDENTITY, Vector3(x, 24.0, 0.0))
		var id: int = _world.add_brick(entry[0], entry[1], at)
		if id != 0:
			_builder.register(id, entry[0], at)
		x += 60.0
	await get_tree().process_frame
	_camera.frame(_world.model_bounds(), 1.05)
	_camera.set_view("default")


## Run one design through the assistant and report, for checking the
## whole loop without a person having to type into the panel.
func _ask(brief: String) -> void:
	# Start from a bare baseplate, so what appears is what was asked for
	# and not a sample model with something new beside it.
	_world.clear()
	_builder.lattice.clear()
	_lay_baseplate()

	var started: int = Time.get_ticks_msec()
	_assistant.progress.connect(func(note: String) -> void:
		print("  [%5.1fs] %s" % [(Time.get_ticks_msec() - started) / 1000.0, note]))
	_assistant.said.connect(func(text: String) -> void:
		print("  said: %s" % text.substr(0, 300)))

	_assistant.design(brief)
	var outcome: Array = await _assistant.finished
	print("ask ok=%s bricks=%d  %s  (%.0fs)" % [
		outcome[0], _assistant._placed_ids.size(), outcome[1],
		(Time.get_ticks_msec() - started) / 1000.0])
	_camera.frame(_world.model_bounds())
	await get_tree().process_frame


## Measure a settled frame rate and print it, then quit.
func _benchmark(frames: int) -> void:
	# Without this the number is the monitor's refresh rate, not the
	# renderer's: a 120 Hz panel reports 120 fps however little work it is.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	# Discard the first second: shader compilation, the shadow atlas and
	# the camera easing all land in it and none of them recur.
	for _warm: int in 60:
		await get_tree().process_frame

	var started: int = Time.get_ticks_usec()
	for _n: int in frames:
		await get_tree().process_frame
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1_000_000.0

	# The engine's own counters, so the claim can be checked rather than
	# inferred from a frame time that might be capped by something else.
	var draw_calls: int = int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(
		Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var video_mb: float = Performance.get_monitor(
		Performance.RENDER_VIDEO_MEM_USED) / 1048576.0

	print("bench bricks=%d batches=%d  %.2f ms/frame  %.0f fps  draws=%d  prims=%d  vram=%.0fMB" % [
		_world.brick_count(), _world.get_child_count(),
		elapsed / float(frames) * 1000.0, float(frames) / elapsed,
		draw_calls, primitives, video_mb])
	get_tree().quit()


## Save a frame and quit. Used by tools/shot.sh so a change to how parts
## look can be checked without a person having to look at it.
func _capture(path: String) -> void:
	# Several frames, not one: the camera eases towards its framing and the
	# shadow atlas fills over a few frames, so the first frame is neither
	# framed nor lit the way a real one is.
	#
	# The frames are forced, not awaited. A process frame is not a drawn
	# frame: when the window is in the background — which it is whenever
	# this runs unattended — the OS stops asking for redraws entirely, so
	# awaiting frame_post_draw waits forever and the captured texture is
	# whatever was last drawn.
	#
	# That cost most of an afternoon. Bricks added after a long wait were
	# absent from every screenshot while the scene tree, the batches, the
	# instance transforms and the instance colours all insisted they were
	# there. They were. The picture was old.
	# Anything that has to come off the network before the picture is
	# worth taking — whether this build has accounts, for one — needs
	# longer than a dozen frames. --settle buys that time in frames
	# rather than in a sleep, so the scene keeps drawing while it waits.
	var settle: float = maxf(_argument("--settle").to_float(), 0.0)
	for _n: int in 12 + int(settle * 60.0):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(path)
	if error != OK:
		push_error("shot: could not write %s (%d)" % [path, error])
	else:
		print("shot %s  %dx%d" % [path, image.get_width(), image.get_height()])
	get_tree().quit(0 if error == OK else 1)


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.substr(prefix.length() + 1)
	return ""


## The panels either side of the viewport: the parts bin on the left, the
## design assistant on the right. Both are built in code rather than in
## the scene because they are data-driven — 24,731 parts and 322 colours
## are not things to lay out by hand.
func _build_ui() -> void:
	# The library has no scene tree of its own, so it borrows this one to
	# park its HTTP requests on.
	_library.set_fetch_host(self)
	_library.fetched.connect(_on_part_fetched)
	_library.fetch_failed.connect(func(part_id: String, why: String) -> void:
		push_warning("could not fetch %s: %s" % [part_id, why]))

	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder

	_stability = Stability.new()
	_stability.library = _library
	_stability.lattice = _builder.lattice

	_thumbnails = PartThumbnails.new()
	_thumbnails.library = _library
	add_child(_thumbnails)

	# Accounts exist for one reason: the assistant spends money per
	# request. Everything the builder does is already running by the time
	# this finishes probing, and none of it waits on the answer.
	_account = Account.new()
	# The geometry this build did not ship may not live beside it, and
	# only the deployment knows where it does. Whatever the probe says —
	# including that it failed — something has to be set here, because
	# requests that arrive before it answers are held until it does, and
	# a deployment that serves its own parts would otherwise hold them
	# for ever waiting on a URL that was never going to come.
	_account.changed.connect(func() -> void:
		if _library.remote_parts.is_empty():
			_library.remote_parts = (_account.parts_url
				if not _account.parts_url.is_empty()
				else Origin.here() + "/parts/"))
	add_child(_account)

	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	# On desktop there is no proxy in front of us, so talk to the model
	# directly when a key is around — that is a developer running with
	# their own key, and there is nobody to bill. Otherwise the desktop
	# build talks to the same hosted function the web build does, which
	# means the same sign-in and the same monthly budget.
	var key: String = "" if OS.has_feature("web") else _anthropic_key()
	if not key.is_empty():
		_assistant.direct_key = key
	else:
		_assistant.endpoint = _account.api_base() + Assistant.DEFAULT_ENDPOINT
		_assistant.account = _account
	add_child(_assistant)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(column)

	_bar = ModelBar.new()
	_bar.world = _world
	_bar.builder = _builder
	column.add_child(_bar)
	_bar.bind(_store)
	_bar.cleared.connect(func() -> void:
		_lay_baseplate()
		_on_model_changed())
	_bar.opened.connect(func(_bricks: int) -> void:
		_lay_baseplate()
		_on_model_changed()
		_camera.frame(_world.model_bounds()))

	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(layout)

	_bin = PartsBin.new()
	_bin.library = _library
	_bin.thumbnails = _thumbnails
	_bin.part_chosen.connect(_on_part_chosen)
	_bin.color_chosen.connect(_on_color_chosen)
	_thumbnails.ready_for.connect(_bin.on_thumbnail)

	_bin_dock = SideDock.new()
	_bin_dock.setup(_bin, SideDock.Edge.LEFT, 336.0)
	layout.add_child(_bin_dock)

	# The middle column is the viewport. Nothing is drawn into it, but the
	# counters and the key list live at its top and bottom so they cannot
	# end up underneath a panel.
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_theme_constant_override("separation", 0)
	layout.add_child(middle)

	_counts = _viewport_label(12)
	_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(_counts)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(spacer)

	# The hint is wide, and a container asks its children how narrow they
	# can get. Left to itself the strip set the middle column's minimum
	# width and squeezed the assistant off the right edge, so it lives in
	# a clipping wrapper that claims no width of its own.
	# Above the key strip, so the strip stays where it always is rather
	# than jumping down the screen when playback starts.
	_steps = StepsBar.new()
	_steps.reveal.connect(func(ids: Dictionary) -> void: _world.show_only(ids))
	middle.add_child(_steps)

	var hint_area := Control.new()
	hint_area.custom_minimum_size = Vector2(0, 26)
	hint_area.clip_contents = true
	hint_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(hint_area)

	var hint := ControlsHint.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -24.0
	hint.offset_bottom = 0.0
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_area.add_child(hint)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(pad)

	_chat = ChatPanel.new()
	_chat_dock = SideDock.new()
	_chat_dock.setup(_chat, SideDock.Edge.RIGHT, 340.0)
	layout.add_child(_chat_dock)
	_chat.bind(_assistant)
	if _assistant.direct_key.is_empty():
		_chat.watch(_account)

	_bin.populate()
	_builder.held_color = _bin.selected_color()

	# Anything that changes the model marks it for saving.
	_builder.placed.connect(func(_id: int, _part: String) -> void:
		_on_model_changed())
	_builder.removed.connect(func(_id: int) -> void: _on_model_changed())
	_assistant.built.connect(func(_n: int) -> void: _on_model_changed())


## A label that reads over the 3D behind it, whatever colour that is.
static func _viewport_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The key for a direct desktop call, from the environment or a .env
## beside the project. Never compiled in, and never used on the web.
static func _anthropic_key() -> String:
	var from_env: String = OS.get_environment("ANTHROPIC_API_KEY")
	if not from_env.is_empty():
		return from_env
	var file: FileAccess = FileAccess.open("res://.env", FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		for prefix: String in ["ANTHROPIC_API_KEY=", "AI__ANTHROPIC_API_KEY="]:
			if line.begins_with(prefix):
				return line.substr(prefix.length()).strip_edges().lstrip("\"'").rstrip("\"'")
	return ""


## The working model is written a couple of seconds after the last
## change, so closing the tab costs seconds rather than an afternoon.
## Turn the whole build on the baseplate, keeping the lattice exact.
func _turn_model(quarter_turns: int) -> void:
	var moved: Array = _world.rotate_model(quarter_turns, _store.scenery)
	if moved.is_empty():
		return
	for entry: Dictionary in moved:
		_builder.lattice.release(entry["id"])
	for entry: Dictionary in moved:
		_builder.register(entry["id"], entry["part"], entry["at"])
	_on_model_changed()


## Start or leave the booklet. Editing while playback is on would place
## bricks into a model that is only half on screen, so the build steps
## are worked out once, on entry, from whatever is there.
func _toggle_steps() -> void:
	if _steps.is_playing_back():
		_steps.stop()
		return
	if _world.brick_count() == 0:
		return
	_steps.start(_world, _library, _store.scenery)


func _on_model_changed() -> void:
	if _store != null:
		_store.touch()


func _on_part_chosen(part_id: String) -> void:
	_builder.held_part = part_id
	# On the web most parts are a request away rather than resident. Ask
	# for it as soon as it is picked, so it is usually there by the time
	# the cursor reaches the model.
	if not _library.is_resident(part_id):
		_library.request_mesh(part_id)
	_refresh_preview()


func _on_part_fetched(part_id: String) -> void:
	if _builder.held_part == part_id:
		_refresh_preview()


func _on_color_chosen(color_code: int) -> void:
	_builder.held_color = color_code
	_refresh_preview()


## Open an LDraw model and place every part of it. Returns how many landed.
func _open(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var model: LdrModel = LdrModel.load_file(path)
	if model == null:
		return 0

	var placed: int = 0
	var missing: Dictionary = {}
	for item: Variant in model.flatten(_library.parts):
		var placement: LdrModel.Placement = item
		var brick_id: int = _world.add_brick(
			placement.part_id, placement.color_code, placement.transform)
		if brick_id != 0:
			_builder.register(brick_id, placement.part_id, placement.transform)
			placed += 1
		else:
			missing[placement.part_id] = true

	if not missing.is_empty():
		push_warning("model %s: %d part(s) unavailable: %s" % [
			path.get_file(), missing.size(),
			", ".join(PackedStringArray(missing.keys()).slice(0, 8))])
	return placed


## A fallback when no sample model is around: a wall that exercises the
## batching, the palette and the lattice all at once.
func _build_demo() -> int:
	const BRICK := "3001"          # Brick 2 x 4
	const COURSE_HEIGHT := 24      # one brick
	const STUD := 20
	var palette: PackedInt32Array = PackedInt32Array([4, 14, 2, 1, 26, 25, 15, 0])

	var placed: int = 0
	for course: int in 10:
		# Offset alternate courses by two studs, the way a real wall is laid.
		var offset: int = (course % 2) * STUD * 2
		for column: int in 6:
			# Courses go up. The negated height was left over from thinking
			# in LDraw's axes, where -Y is up, and built the whole wall
			# downward through the baseplate.
			var at := Transform3D(
				Basis.IDENTITY,
				Vector3(column * STUD * 4 + offset, course * COURSE_HEIGHT, 0))
			if _world.add_brick(BRICK, palette[course % palette.size()], at) != 0:
				placed += 1
	return placed


## Build something by driving the placement path rather than the model, so
## the whole chain gets exercised: a ray is cast, the lattice is marched,
## the hit face decides a target, the target is snapped to the stud grid
## and dropped onto whatever is below, the result is collision checked, and
## only then is a brick placed.
##
## A brick that lands half a plate low, or one that is allowed to overlap
## its neighbour, shows up here and nowhere else — placing bricks by
## writing transforms directly would prove nothing about any of it.
func _autobuild(courses: int) -> void:
	var palette: Array[int] = [4, 14, 2, 1, 26, 25, 15, 191]
	const BRICK := "3001"      # Brick 2 x 4: 80 x 40 LDU
	const LONG := 80.0
	const SHORT := 40.0
	# A hollow square, four bricks to a side. The long walls take the full
	# span and the short walls fit between them, which is what stops the
	# corners overlapping; the pair swaps every course, so the courses bond
	# the way a real wall does instead of stacking four separate columns.
	const REACH := 2.0 * LONG          # 160: half the outer span
	var placed: int = 0
	var refused: int = 0

	for course: int in courses:
		_builder.held_color = palette[course % palette.size()]
		var swap: bool = course % 2 == 1

		for side: int in 4:
			var full: bool = (side < 2) != swap
			var offset: float = REACH - SHORT * 0.5    # 140
			for n: int in (4 if full else 3):
				var along: float
				var target: Vector3
				if full:
					along = -1.5 * LONG + n * LONG     # -120 -40 40 120
				else:
					along = -LONG + n * LONG           # -80 0 80

				match side:
					0:
						target = Vector3(along, 0.0, -offset)
						_builder.held_rotation = 0
					1:
						target = Vector3(along, 0.0, offset)
						_builder.held_rotation = 0
					2:
						target = Vector3(-offset, 0.0, along)
						_builder.held_rotation = 1
					_:
						target = Vector3(offset, 0.0, along)
						_builder.held_rotation = 1

				# Aim straight down from well above, the way a cursor would.
				_builder.update_preview(
					target + Vector3(0.0, 2000.0, 0.0), Vector3.DOWN)
				if _builder.place() != 0:
					placed += 1
				else:
					refused += 1

	# Collision has to be shown firing, not merely never asked. Every brick
	# above sat on a clear column, so nothing was refused; put one exactly
	# where another already is and it must be.
	var overlap_refused: bool = false
	var sample: BrickWorld.Brick = null
	for brick: Variant in _world.bricks():
		sample = brick
		break
	if sample != null:
		var cells: Array[Vector3i] = _builder._cells_for(
			_library.mesh_for(sample.part_id), sample.transform)
		overlap_refused = _builder.lattice.collides(cells)

	print("autobuild placed=%d refused=%d cells=%d overlap_detected=%s" % [
		placed, refused, _builder.lattice.occupied_cells(), overlap_refused])


## Fill a cube with bricks to find where the frame time goes.
##
## Deliberately uses a handful of part types rather than one: a single part
## would collapse into one batch and flatter the numbers, whereas a real
## model spreads over dozens.
func _build_stress(target: int) -> int:
	var kinds: PackedStringArray = PackedStringArray([
		"3001", "3003", "3004", "3005", "3020", "3024", "3068b", "3062b"])
	var palette: PackedInt32Array = PackedInt32Array([
		4, 14, 2, 1, 26, 25, 15, 0, 70, 72, 191, 308])

	# A roughly cubic arrangement on the real lattice, so the spatial
	# spread matches what a big model actually looks like.
	var side: int = int(ceil(pow(float(target), 1.0 / 3.0)))
	var placed: int = 0
	var n: int = 0
	for y: int in side:
		for z: int in side:
			for x: int in side:
				if placed >= target:
					return placed
				var at := Transform3D(Basis.IDENTITY,
					Vector3(x * 80.0, y * 24.0, z * 40.0))
				if _world.add_brick(
						kinds[n % kinds.size()], palette[(n / 7) % palette.size()], at) != 0:
					placed += 1
				n += 1
	return placed


## Something to build on. A model opened from a file floats in space
## otherwise, and there is nothing for a first brick to rest against.
func _lay_baseplate() -> void:
	const PLATE := "3811"   # Baseplate 32 x 32
	var at := Transform3D(Basis.IDENTITY, Vector3(0.0, -8.0, 0.0))
	var brick_id: int = _world.add_brick(PLATE, 288, at)  # Dark Green
	if brick_id != 0:
		_builder.register(brick_id, PLATE, at)
		if _store != null:
			_store.scenery[brick_id] = true


func _on_rebuilt(brick_count: int, batch_count: int, triangle_count: int) -> void:
	if _counts == null:
		return
	_counts_base = "%s bricks · %d batches · %s triangles · %s parts" % [
		_comma(brick_count), batch_count, _comma(triangle_count),
		_comma(_library.parts.size())]
	# Stability is cheap but not free, and a rebuild can fire several
	# times while a model is being dropped in. Once a second is plenty
	# for something a person reads.
	var now: int = Time.get_ticks_msec()
	if _stability != null and now - _stability_at > 900:
		_stability_at = now
		_stability_text = _stability.check(_world).summary()


func _process(_delta: float) -> void:
	if _store != null:
		_store.tick()
	if _counts == null:
		return
	# Frame time belongs beside the counts: the whole point of batching is
	# that the counts can grow without it moving.
	# The counts line is rebuilt from its parts rather than patched, so
	# repeated frames cannot accrete suffixes.
	var fps: float = Engine.get_frames_per_second()
	var line: String = "%s · fps %.0f" % [_counts_base, fps]
	if not _stability_text.is_empty():
		line += " · " + _stability_text
	_counts.text = line


## The palette the number keys reach for: a readable spread rather than
## the first twelve codes, which are mostly greys and browns.
const QUICK_COLORS: Array[int] = [4, 14, 2, 1, 26, 25, 15, 0, 70, 191]

## Parts the bracket keys cycle. A starter bin, not the catalogue — the
## catalogue has 24,731 entries and needs a search box, which is next.
const QUICK_PARTS: Array[String] = [
	"3005", "3004", "3622", "3009", "3003", "3001", "3007",
	"3024", "3023", "3020", "3031", "3068b", "3040b", "3298", "4070", "3062b"]

var _part_index: int = 5
var _color_index: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _over_panel():
			_builder.hide_preview()
			return
		_refresh_preview()
		return

	if not (event is InputEventMouseButton):
		return
	var button: InputEventMouseButton = event
	if not button.pressed or button.alt_pressed or button.shift_pressed:
		return

	if _over_panel():
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		_builder.place()
		_refresh_preview()
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		_builder.remove_hovered()
		_refresh_preview()


## True when the cursor is over a panel rather than the model.
##
## Without this, clicking a part in the bin also drops a brick behind it,
## and moving the mouse across the assistant leaves a ghost following the
## cursor over the text.
func _over_panel() -> bool:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	for panel: Control in [_bin_dock, _chat_dock, _bar]:
		if panel != null and panel.get_global_rect().has_point(mouse):
			return true
	return false


func _refresh_preview() -> void:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	_builder.update_preview(
		_camera.project_ray_origin(mouse),
		_camera.project_ray_normal(mouse))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed():
		return
	# A single-letter shortcut must never fire while someone is typing a
	# part name or a brief.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	var key: InputEventKey = event
	match key.keycode:
		KEY_F:
			_camera.frame(_world.model_bounds())
		KEY_1: _camera.set_view("front")
		KEY_2: _camera.set_view("back")
		KEY_3: _camera.set_view("left")
		KEY_4: _camera.set_view("right")
		KEY_5: _camera.set_view("top")
		KEY_0: _camera.set_view("default")
		KEY_R:
			_builder.rotate_held(-1 if key.shift_pressed else 1)
			_refresh_preview()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var step: int = 1 if key.keycode == KEY_BRACKETRIGHT else -1
			_color_index = posmod(_color_index + step, QUICK_COLORS.size())
			_builder.held_color = QUICK_COLORS[_color_index]
			_bin._on_colour(QUICK_COLORS[_color_index])
			_refresh_preview()
		KEY_Q, KEY_E:
			_turn_model(1 if key.keycode == KEY_E else -1)
		KEY_B:
			_toggle_steps()
		KEY_LEFT, KEY_RIGHT:
			# Only while a booklet is up. Left and right otherwise belong
			# to whatever has focus, and stealing them would break the
			# search box and the brief.
			if _steps.is_playing_back():
				if key.keycode == KEY_RIGHT:
					_steps.step_forward()
				else:
					_steps.step_back()
		KEY_TAB:
			# Both panels away, for looking at the model.
			var showing: bool = _bin_dock.is_open() or _chat_dock.is_open()
			_bin_dock.set_open(not showing)
			_chat_dock.set_open(not showing)
		KEY_Z:
			if key.ctrl_pressed or key.meta_pressed:
				if key.shift_pressed:
					_builder.redo()
				else:
					_builder.undo()
				_refresh_preview()
		KEY_SLASH:
			if _bin:
				_bin.focus_search()
		KEY_S:
			if (key.ctrl_pressed or key.meta_pressed) and _bar:
				_bar._on_save()
		KEY_ESCAPE:
			# Leaving playback first. Escape reads as "out of this mode",
			# and quitting the app because someone wanted the whole model
			# back would be a bad surprise.
			if _steps.is_playing_back():
				_steps.stop()
				return
			if OS.has_feature("web"):
				return
			get_tree().quit()


static func _comma(value: int) -> String:
	var text: String = str(value)
	var out: String = ""
	var count: int = 0
	for n: int in range(text.length() - 1, -1, -1):
		out = text[n] + out
		count += 1
		if count % 3 == 0 and n > 0:
			out = "," + out
	return out
