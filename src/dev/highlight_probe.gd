## Does a glossy face catch the light without turning into another colour?
##
##   godot --path . --resolution 1200x800 --script src/dev/highlight_probe.gd
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1200x800 \
##       --script src/dev/highlight_probe.gd
##
## The first is the Compatibility renderer the web build uses; the second
## is Forward+ on the GPU.
##
## The eleventh Tower of Orthanc stood on a rock of dark bluish grey, and
## the picture showed a pale grey rock ringed with white bands — every
## slope facing the camera drawn white. There was no white in the model.
## A flat glossy face at the mirror angle to one small, hard light
## reflects it from every point at once, so the whole face goes; the
## true-colour check looks at faces square to the eye and lit tops, and
## never saw it. So this asks the picture, from eight directions and two
## heights, of a field of slopes in one dark colour turned every way a
## ring of them faces: how much of the model is drawn lighter than the
## next grey up. Four facings were tried first and passed with the rock
## still banded: a ring always has a slope at the exact mirror angle.
extends SceneTree

const GREY := 72
const SLOPES: Array = ["3040b", "3039", "4286"]
const FACINGS := 16
## Oklab L. Dark bluish grey is 0.53 of its own and light bluish grey
## 0.72; white is 1. Lighter than 0.80 reads as a lighter brick.
const NEAR_WHITE := 0.80
## A highlight is a spot; a face gone pale is a share of the picture.
const MOST_NEAR_WHITE := 0.02
## The lightest tenth may climb above the colour, not to the next one.
const LIGHTEST_TENTH := 0.72

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	var world: BrickWorld = main.get("_world")
	var library: PartLibrary = main.get("_library")
	var camera: CadCamera = main.get("_camera")
	var builder: Builder = main.get("_builder")
	if world == null or library == null or library.parts.is_empty():
		print("  FAIL  no world or no catalogue")
		quit(1)
		return
	var method: String = RenderingServer.get_current_rendering_method()
	print("  renderer: %s" % method)

	# Every slope in every facing, in rows, standing on nothing: the
	# ground would be in the mask and its green is not the question.
	builder.hide_preview()
	world.clear()
	var placed: int = 0
	for row: int in SLOPES.size():
		for turn: int in FACINGS:
			var basis := Basis(Vector3.UP, turn * TAU / FACINGS)
			var at := Vector3((turn % 8) * 90.0, 24.0, (row * 2 + turn / 8) * 90.0)
			if world.add_brick(SLOPES[row], GREY, Transform3D(basis, at)) != 0:
				placed += 1
	_say("%d slopes of %d kinds placed in dark bluish grey, %d ways round"
		% [placed, SLOPES.size(), FACINGS], placed == SLOPES.size() * FACINGS)
	main.get_node("HUD").visible = false
	camera.square_on(false)

	var worst_white: float = 0.0
	var worst_tenth: float = 0.0
	var worst_at: int = 0
	var kept: Image = null
	for view: int in 16:
		var yaw: int = (view % 8) * 45
		var pitch: float = 30.0 if view < 8 else 50.0
		camera.frame(world.model_bounds(), 0.8)
		camera.set("_target_yaw", deg_to_rad(float(yaw)))
		camera.set("_target_pitch", deg_to_rad(pitch))
		camera.call("_apply", 1.0)
		world.show_only({})
		for _n: int in 8:
			await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		# The same view with every brick hidden: whatever differs is model.
		world.show_only({-1: true})
		for _n: int in 8:
			await RenderingServer.frame_post_draw
		var empty: Image = root.get_texture().get_image()
		world.show_only({})
		var lightness: PackedFloat32Array = _model_lightness(picture, empty)
		if lightness.is_empty():
			continue
		lightness.sort()
		var white: int = 0
		for value: float in lightness:
			if value > NEAR_WHITE:
				white += 1
		var share: float = float(white) / lightness.size()
		var tenth: float = lightness[int(lightness.size() * 0.9)]
		print("  from %3d degrees, %2.0f up: %5.1f%% pale, lightest tenth from L %.2f, %d pixels"
			% [yaw, pitch, share * 100.0, tenth, lightness.size()])
		if share >= worst_white:
			worst_white = share
			worst_at = yaw
			kept = picture
		worst_tenth = maxf(worst_tenth, tenth)

	# And the pictures the assistant critiques, which have lights of their
	# own: a rock it is shown in white is a rock it will "fix".
	var shot_white: float = 0.0
	var shot_at: String = ""
	if ModelShot.possible():
		var shot := ModelShot.new()
		shot.rulers = false
		main.add_child(shot)
		for view: String in ModelShot.ANGLES:
			var picture: Image = await shot.take(world, view)
			if picture == null:
				continue
			# Its background is one flat colour, and a corner is background.
			var empty: Image = Image.create(picture.get_width(), picture.get_height(),
				false, picture.get_format())
			empty.fill(picture.get_pixel(0, 0))
			var lightness: PackedFloat32Array = _model_lightness(picture, empty)
			if lightness.is_empty():
				continue
			var white: int = 0
			for value: float in lightness:
				if value > NEAR_WHITE:
					white += 1
			var share: float = float(white) / lightness.size()
			print("  the assistant's %-10s view: %5.1f%% pale" % [view, share * 100.0])
			if share >= shot_white:
				shot_white = share
				shot_at = view

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	if kept != null:
		var out: String = "shots/highlight_%s.png" % method
		kept.save_png(ProjectSettings.globalize_path("res://" + out))
		print("  wrote %s, the view from %d degrees" % [out, worst_at])
	print("")
	_say("a dark grey slope catches the light without going pale: at most %.1f%% lighter than L %.2f"
		% [worst_white * 100.0, NEAR_WHITE], worst_white < MOST_NEAR_WHITE)
	_say("...and its lightest tenth stays below the next grey up: L %.2f" % worst_tenth,
		worst_tenth < LIGHTEST_TENTH)
	_say("...and in the pictures the assistant is shown: at most %.1f%% pale (%s)"
		% [shot_white * 100.0, shot_at], not shot_at.is_empty() and shot_white < MOST_NEAR_WHITE)

	print("")
	print("%d failed" % _failures if _failures
		else "glossy faces keep their colour in the light, on %s" % method)
	quit(1 if _failures else 0)


## Oklab lightness of every pixel that is model rather than background,
## and not at its edge: an edge pixel is part brick and part background,
## and against the assistant's near-white background every one of them
## read as a pale face.
static func _model_lightness(picture: Image, empty: Image) -> PackedFloat32Array:
	var width: int = picture.get_width()
	var height: int = picture.get_height()
	var model := PackedByteArray()
	model.resize(width * height)
	for y: int in height:
		for x: int in width:
			var seen: Color = picture.get_pixel(x, y)
			var behind: Color = empty.get_pixel(x, y)
			if absf(seen.r - behind.r) + absf(seen.g - behind.g) \
					+ absf(seen.b - behind.b) >= 0.06:
				model[y * width + x] = 1
	var out := PackedFloat32Array()
	const IN := 2
	for y: int in range(IN, height - IN, 2):
		for x: int in range(IN, width - IN, 2):
			if not (model[y * width + x] and model[y * width + x - IN]
					and model[y * width + x + IN] and model[(y - IN) * width + x]
					and model[(y + IN) * width + x]):
				continue
			out.append(_lightness(picture.get_pixel(x, y)))
	return out


static func _lightness(color: Color) -> float:
	var r: float = _linear(color.r)
	var g: float = _linear(color.g)
	var b: float = _linear(color.b)
	var l: float = pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m: float = pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s: float = pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s


static func _linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


func _say(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
