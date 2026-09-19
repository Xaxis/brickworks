## The workbench: the scene you build in.
##
## For now this is the proof that the pipeline holds end to end — LDraw
## source converted offline, loaded as quantised geometry, batched by shape
## and drawn with per-instance colour — with a real published model opened
## as the test. Everything it does by hand here becomes a tool later.
extends Node3D

const SAMPLE_MODEL := "res://vendor/ldraw/models/car.ldr"

@onready var _camera: CadCamera = $CadCamera
@onready var _world: BrickWorld = $BrickWorld
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

	var placed: int = _open(SAMPLE_MODEL)
	if placed == 0:
		placed = _build_demo()

	_title.text = "%d parts catalogued, %d colours — %d ms" % [
		_library.parts.size(), _library.colors.size(), catalogue_ms]

	# Wait a frame so the deferred batch rebuild has run and the bounds are
	# real before framing them.
	await get_tree().process_frame
	_camera.frame(_world.model_bounds())

	var shot: String = _argument("--shot")
	if not shot.is_empty():
		await _capture(shot)


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
		if _world.add_brick(placement.part_id, placement.color_code, placement.transform) != 0:
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
			var at := Transform3D(
				Basis.IDENTITY,
				Vector3(column * STUD * 4 + offset, -course * COURSE_HEIGHT, 0))
			if _world.add_brick(BRICK, palette[course % palette.size()], at) != 0:
				placed += 1
	return placed


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
