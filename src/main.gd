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

var _library: PartLibrary


func _ready() -> void:
	_library = PartLibrary.new()
	var started: int = Time.get_ticks_msec()
	if not _library.load_catalogue():
		_title.text = "No catalogue"
		_status.text = "Run tools/build_meshes.py to generate assets/generated/."
		return
	var catalogue_ms: int = Time.get_ticks_msec() - started

	_world.library = _library
	_world.rebuilt.connect(_on_rebuilt)
	_builder.world = _world
	_builder.library = _library

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
		placed = _open(SAMPLE_MODEL)
		if placed == 0:
			placed = _build_demo()
	_lay_baseplate()

	_title.text = "%d parts catalogued, %d colours — %d ms" % [
		_library.parts.size(), _library.colors.size(), catalogue_ms]

	# Wait a frame so the deferred batch rebuild has run and the bounds are
	# real before framing them.
	await get_tree().process_frame
	_camera.frame(_world.model_bounds())

	var autobuild: String = _argument("--autobuild")
	if not autobuild.is_empty():
		_autobuild(autobuild.to_int())

	var bench: String = _argument("--bench")
	if not bench.is_empty():
		await _benchmark(bench.to_int())

	var shot: String = _argument("--shot")
	if not shot.is_empty():
		await _capture(shot)


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
	for _n: int in 30:
		await get_tree().process_frame
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


func _on_rebuilt(brick_count: int, batch_count: int, triangle_count: int) -> void:
	_status.text = "%s bricks · %d batches · %s triangles" % [
		_comma(brick_count), batch_count, _comma(triangle_count)]


func _process(_delta: float) -> void:
	if _status == null:
		return
	# Frame time belongs beside the counts: the whole point of batching is
	# that the counts can grow without it moving.
	var fps: float = Engine.get_frames_per_second()
	_status.text = _status.text.split(" · fps")[0] + " · fps %.0f" % fps


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
		_refresh_preview()
		return

	if not (event is InputEventMouseButton):
		return
	var button: InputEventMouseButton = event
	if not button.pressed or button.alt_pressed or button.shift_pressed:
		return

	if button.button_index == MOUSE_BUTTON_LEFT:
		_builder.place()
		_refresh_preview()
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		_builder.remove_hovered()
		_refresh_preview()


func _refresh_preview() -> void:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	_builder.update_preview(
		_camera.project_ray_origin(mouse),
		_camera.project_ray_normal(mouse))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed():
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
			_part_index = posmod(_part_index + step, QUICK_PARTS.size())
			_builder.held_part = QUICK_PARTS[_part_index]
			_refresh_preview()
		KEY_SEMICOLON, KEY_APOSTROPHE:
			var shift: int = 1 if key.keycode == KEY_APOSTROPHE else -1
			_color_index = posmod(_color_index + shift, QUICK_COLORS.size())
			_builder.held_color = QUICK_COLORS[_color_index]
			_refresh_preview()
		KEY_Z:
			if key.ctrl_pressed or key.meta_pressed:
				if key.shift_pressed:
					_builder.redo()
				else:
					_builder.undo()
				_refresh_preview()
		KEY_ESCAPE:
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
