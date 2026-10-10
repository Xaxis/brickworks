## Is every finish drawn as itself?
##
##   godot --path . --resolution 1400x900 --script src/dev/finish_probe.gd
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 \
##       --script src/dev/finish_probe.gd
##
## The first is the Compatibility renderer the web build uses (the plain
## `godot` here draws in software, with that renderer); the second is
## Forward+ on the GPU. Run both: they are two different shader backends.
##
## Chrome, metallic, pearl, speckle, glitter, opal, glow-in-the-dark,
## fluorescent, rubber, fabric and milky white all rendered as plain
## glossy or plain transparent plastic once, because the colour list
## kept the finish and nothing ever read it. Nothing errored; the only
## way to see it was to look. So this leaves pictures to look at —
## shots/finishes_<renderer>.png, the app's own view of a row of each,
## and shots/finishes_shot_<renderer>.png, the critique render, which has
## no sky to reflect — and asks the pixels a question a person would:
## put the same grey in every finish, and does each one come out looking
## different from plain plastic, in the direction it should?
##
## Not headless: the pictures are the point, and a headless run has no
## device to draw them with.
extends SceneTree

## One real colour of each finish, for the picture. Plain red and trans
## clear lead, so there is plastic to hold the rest against.
const SHOWN: Array = [
	[4, "plastic"], [47, "trans"], [383, "chrome"], [334, "chrome gold"],
	[80, "metallic"], [297, "pearl"], [132, "speckle"],
	[114, "glitter"], [362, "opal"], [329, "glow"], [42, "fluorescent"],
	[256, "rubber"], [20004, "fabric"], [79, "milky"],
]
const BRICK := "3001"
const ROUND := "3062b"
## Codes for the made-up colours below, well clear of LDraw's.
const TEST_CODES := 990000

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Counted in frames, and a window nothing is looking at gets one a
	# second on this machine.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame

	var world: BrickWorld = _main.get("_world")
	var library: PartLibrary = _main.get("_library")
	var camera: CadCamera = _main.get("_camera")
	if world == null or library == null or library.parts.is_empty():
		print("  FAIL  no world or no catalogue")
		quit(1)
		return
	var method: String = RenderingServer.get_current_rendering_method()
	print("  renderer: %s" % method)

	_check_data(library)

	# The picture: one real colour of each finish, a 2 x 4 brick and a
	# 1 x 1 round of it, in rows of five read left to right. Without the
	# ghost of the brick in hand, which would otherwise stand in it.
	(_main.get("_builder") as Builder).hide_preview()
	world.clear()
	for n: int in SHOWN.size():
		var code: int = SHOWN[n][0]
		var at := Vector3(float(n % 5) * 150.0, 24.0, float(n / 5) * 110.0)
		world.add_brick(BRICK, code, Transform3D(Basis.IDENTITY, at))
		world.add_brick(ROUND, code,
			Transform3D(Basis.IDENTITY, at + Vector3(70.0, 0.0, 10.0)))
	await process_frame
	print("  %d bricks in the picture" % world.brick_count())
	_check_batching(world, library)

	var hud: CanvasLayer = _main.get_node("HUD")
	hud.visible = false
	_look_at(camera, world.model_bounds(), 0.55)
	var picture: Image = await _settled_view()
	_save(picture, "res://shots/finishes_%s.png" % method)

	# The critique render: no sky, a flat background, an orthographic
	# camera. Chrome that only looked like chrome because the sky was in
	# it would be grey plastic here.
	var shot := ModelShot.new()
	_main.add_child(shot)
	var critique: Image = await shot.take(world, "corner")
	if critique != null:
		_save(critique, "res://shots/finishes_shot_%s.png" % method)
	else:
		_say("the critique render came back empty", false)

	# The question for the pixels: the same grey in every finish.
	await _same_grey_each_finish(world, library, camera)
	await _previews_show_the_finish(library)

	hud.visible = true
	print("")
	print("%d failed" % _failures if _failures
		else "every finish is drawn as itself, on %s" % method)
	quit(1 if _failures else 0)


## What the colour list says, read the way the renderer reads it.
func _check_data(library: PartLibrary) -> void:
	var counts: Dictionary = {}
	for code: int in library.colors:
		var color: PartLibrary.BrickColor = library.colors[code]
		counts[color.drawn_as] = int(counts.get(color.drawn_as, 0)) + 1
	var said := PackedStringArray()
	for finish: int in PartLibrary.FINISH_NAMES.size():
		said.append("%s %d" % [PartLibrary.FINISH_NAMES[finish], int(counts.get(finish, 0))])
	print("  finishes: %s" % ", ".join(said))
	for finish: int in range(1, PartLibrary.FINISH_NAMES.size()):
		_say("some colour is %s" % PartLibrary.FINISH_NAMES[finish],
			int(counts.get(finish, 0)) > 0)

	# The glitter's own fleck colour and amount, from LDConfig's MATERIAL.
	var glitter: PartLibrary.BrickColor = library.color(114)
	_say("glitter trans dark pink carries its flecks (%.2f of %s)"
		% [glitter.fleck_fraction, glitter.fleck.to_html(false)],
		glitter.fleck_fraction > 0.0 and glitter.fleck.r > 0.5)
	_say("glow-in-dark opaque is drawn opaque",
		not library.color(21).is_transparent())
	_say("glow-in-dark trans is still see-through",
		library.color(294).is_transparent())
	var packed: Color = library.color(383).instance_custom
	_say("chrome silver packs finish %d, got %.2f" % [
		PartLibrary.BrickColor.Finish.CHROME, packed.a],
		int(floor(packed.a)) == PartLibrary.BrickColor.Finish.CHROME)


## Fourteen colours of one part, every finish among them, must not cost
## more batches than two colours did: opaque and transparent.
func _check_batching(world: BrickWorld, library: PartLibrary) -> void:
	var info: PartLibrary.PartInfo = library.parts[BRICK]
	var part: Lbm.PartMesh = library.mesh_for(BRICK)
	var batches: Dictionary = world.get("_batches")
	var live: int = 0
	for key: String in batches:
		var batch: BrickWorld.Batch = batches[key]
		if key.begins_with(info.mesh_hash + ":") and batch.multimesh.instance_count > 0:
			live += 1
	_say("%d colours of %s, every finish, in %d batches (at most %d)" % [
			SHOWN.size(), BRICK, live, part.surface_count() * 2],
		live <= part.surface_count() * 2)

	# And the finish is really in the batch, not only in the library.
	var found: bool = false
	for key: String in batches:
		var batch: BrickWorld.Batch = batches[key]
		if not key.begins_with(info.mesh_hash + ":0:"):
			continue
		for slot: int in batch.multimesh.visible_instance_count:
			var brick: BrickWorld.Brick = world.get_brick(batch.brick_ids[slot])
			if brick != null and brick.color_code == 383:
				var custom: Color = batch.multimesh.get_instance_custom_data(slot)
				found = custom.is_equal_approx(library.color(383).instance_custom)
	_say("the chrome brick's batch carries its finish", found)


## One grey, every finish, side by side, against plain plastic.
func _same_grey_each_finish(world: BrickWorld, library: PartLibrary, camera: CadCamera) -> void:
	world.clear()
	var codes: Array[int] = []
	var transparent: Array[bool] = []
	var finish_count: int = PartLibrary.FINISH_NAMES.size()
	# Each finish twice over: opaque grey, then the same grey see-through,
	# because half the finishes only exist in transparent plastic and a
	# transparent one has to be held against transparent plastic.
	for see_through: int in 2:
		for finish: int in finish_count:
			var made := PartLibrary.BrickColor.new()
			made.code = TEST_CODES + see_through * 100 + finish
			made.name = "test grey %s" % PartLibrary.FINISH_NAMES[finish]
			made.alpha = 128 if see_through == 1 else 255
			made.rgb = Color(0.6, 0.6, 0.62, made.alpha / 255.0)
			made.shown = made.rgb
			made.drawn_as = finish
			made.fleck = Color(0.95, 0.85, 0.3)
			made.fleck_fraction = 0.3
			made.pack_finish()
			library.colors[made.code] = made
			codes.append(made.code)
			transparent.append(see_through == 1)
	var places: Array[Vector3] = []
	for n: int in codes.size():
		var finish: int = n % finish_count
		var at := Vector3(float(finish % 6) * 110.0, 24.0,
			float((n / finish_count) * 2 + finish / 6) * 90.0)
		world.add_brick(BRICK, codes[n], Transform3D(Basis.IDENTITY, at))
		places.append(at)
	await process_frame
	# From where the sun's reflection off a top face comes to the eye,
	# so plain plastic glints and the question "is rubber matte" has a
	# highlight to be without.
	var sun: DirectionalLight3D = _main.get_node("Sun")
	var to_sun: Vector3 = sun.global_transform.basis.z.normalized()
	var glint := Vector3(-to_sun.x, to_sun.y, -to_sun.z)
	_look_at(camera, world.model_bounds(), 0.72,
		atan2(glint.x, glint.z), asin(clampf(glint.y, 0.2, 0.9)))
	var image: Image = await _settled_view()

	var stats: Array[Vector4] = []
	var marked: Image = image.duplicate()
	for at: Vector3 in places:
		var rect: Rect2i = _rect_of(image, camera, at)
		var middle: Vector4 = _region(image, rect)
		# The brightest is taken over the whole brick, studs and edges
		# included, which is where plastic's highlights are and a matte
		# finish has none.
		var whole: Vector4 = _region(image, _rect_of(image, camera, at, 0.5))
		stats.append(Vector4(middle.x, middle.y, whole.z, middle.w))
		# Where it measured, drawn on the copy that is kept, so a number
		# below can be checked against the brick it came from.
		for x: int in range(rect.position.x, rect.end.x):
			marked.set_pixel(x, rect.position.y, Color.MAGENTA)
			marked.set_pixel(x, rect.end.y - 1, Color.MAGENTA)
		for y: int in range(rect.position.y, rect.end.y):
			marked.set_pixel(rect.position.x, y, Color.MAGENTA)
			marked.set_pixel(rect.end.x - 1, y, Color.MAGENTA)
	_save(marked, "res://shots/finishes_grey_%s.png" % RenderingServer.get_current_rendering_method())
	for n: int in codes.size():
		var finish: int = n % finish_count
		var reference: Vector4 = stats[n - finish]
		var here: Vector4 = stats[n]
		var gap: float = Vector3(here.x - reference.x, here.y - reference.y,
			here.z - reference.z).length()
		var label: String = "%s%s" % [
			"trans " if transparent[n] else "", PartLibrary.FINISH_NAMES[finish]]
		if finish == PartLibrary.BrickColor.Finish.PLASTIC:
			print("  plastic %s: mean %.3f, spread %.3f, peak %.3f"
				% [label, here.x, here.y, here.z])
			continue
		# Only the finishes a real colour has in that plastic: LDConfig
		# has no opaque glitter, no transparent chrome.
		if not _real(finish, transparent[n]):
			continue
		# Rubber and fabric are only asked to differ. Whether they look
		# matte is for the eye, in the picture: Burley diffuse brightens a
		# rough surface towards grazing, so "its brightest is duller than
		# plastic's" was tried and is not true of real rough plastic either.
		_say("%s differs from plain plastic of the same grey (by %.3f: mean %.3f, spread %.3f, peak %.3f)"
			% [label, gap, here.x, here.y, here.z], gap > 0.02)
		match finish:
			PartLibrary.BrickColor.Finish.CHROME:
				_say("...and chrome has more contrast in it than plastic",
					here.y > reference.y)
			PartLibrary.BrickColor.Finish.GLOW, PartLibrary.BrickColor.Finish.FLUORESCENT:
				_say("...and it gives off light: brighter than plastic",
					here.x > reference.x)
			PartLibrary.BrickColor.Finish.SPECKLE, PartLibrary.BrickColor.Finish.GLITTER:
				_say("...and it is flecked: more spread than plastic",
					here.y > reference.y)
	for code: int in codes:
		library.colors.erase(code)


## Which finishes come in which plastic, as LDConfig has them.
static func _real(finish: int, see_through: bool) -> bool:
	const F := PartLibrary.BrickColor.Finish
	if finish in [F.GLITTER, F.OPAL, F.MILKY]:
		return see_through
	if finish in [F.CHROME, F.METAL, F.PEARL, F.SPECKLE, F.FABRIC]:
		return not see_through
	return true


## Where a brick is in the picture: its box projected, then the middle
## half of that, so it is brick and not sky.
func _rect_of(image: Image, camera: CadCamera, at: Vector3, share: float = 0.25) -> Rect2i:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner: int in 8:
		var point := at + Vector3(
			-40.0 if corner & 1 else 40.0,
			-24.0 if corner & 2 else 0.0,
			-20.0 if corner & 4 else 20.0)
		var screen: Vector2 = camera.unproject_position(point)
		lo = Vector2(minf(lo.x, screen.x), minf(lo.y, screen.y))
		hi = Vector2(maxf(hi.x, screen.x), maxf(hi.y, screen.y))
	var scale: Vector2 = Vector2(image.get_size()) / camera.get_viewport().get_visible_rect().size
	var middle: Vector2 = (lo + hi) * 0.5 * scale
	var half: Vector2 = (hi - lo) * share * scale
	return Rect2i(Vector2i(middle - half), Vector2i(half * 2.0)).intersection(
		Rect2i(Vector2i.ZERO, image.get_size()))


## Mean, spread and brightest luminance over a rectangle of the picture.
static func _region(image: Image, rect: Rect2i) -> Vector4:
	var total: float = 0.0
	var squares: float = 0.0
	var brightest: float = 0.0
	var counted: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var lum: float = image.get_pixel(x, y).get_luminance()
			total += lum
			squares += lum * lum
			brightest = maxf(brightest, lum)
			counted += 1
	if counted == 0:
		return Vector4.ZERO
	var mean: float = total / counted
	return Vector4(mean, sqrt(maxf(squares / counted - mean * mean, 0.0)), brightest, counted)


## The parts bin's previews are drawn by a different path — one mesh, a
## material tint — and must show the finish as well.
func _previews_show_the_finish(library: PartLibrary) -> void:
	var thumbs: PartThumbnails = _main.get("_thumbnails")
	if thumbs == null:
		print("  skip  no thumbnailer")
		return
	var plain := PartLibrary.BrickColor.new()
	plain.code = TEST_CODES + 500
	plain.alpha = 255
	plain.rgb = Color(0.6, 0.6, 0.62)
	plain.shown = plain.rgb
	plain.pack_finish()
	var chrome := PartLibrary.BrickColor.new()
	chrome.code = TEST_CODES + 501
	chrome.alpha = 255
	chrome.rgb = plain.rgb
	chrome.shown = plain.rgb
	chrome.drawn_as = PartLibrary.BrickColor.Finish.CHROME
	chrome.pack_finish()
	library.colors[plain.code] = plain
	library.colors[chrome.code] = chrome
	thumbs.request(BRICK, plain.code)
	thumbs.request(BRICK, chrome.code)
	var a: Texture2D = null
	var b: Texture2D = null
	for _n: int in 400:
		await process_frame
		a = thumbs.request(BRICK, plain.code)
		b = thumbs.request(BRICK, chrome.code)
		if a != null and b != null:
			break
	if a == null or b == null:
		_say("the previews of a grey and a chrome 3001 were drawn", false)
	else:
		_save(b.get_image(), "res://shots/finishes_preview_chrome.png")
		var spread_a: float = _spread(a.get_image())
		var spread_b: float = _spread(b.get_image())
		_say("a chrome preview is not a grey one (spread %.3f against %.3f)"
			% [spread_b, spread_a], absf(spread_b - spread_a) > 0.01)
	library.colors.erase(plain.code)
	library.colors.erase(chrome.code)


static func _spread(image: Image) -> float:
	var total: float = 0.0
	var squares: float = 0.0
	var counted: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < 0.6:
				continue
			var lum: float = pixel.get_luminance()
			total += lum
			squares += lum * lum
			counted += 1
	if counted == 0:
		return 0.0
	var mean: float = total / counted
	return sqrt(maxf(squares / counted - mean * mean, 0.0))


## From the front and above, close, and there at once rather than eased
## towards: the camera's framing is for a person, and this is a picture.
func _look_at(camera: CadCamera, box: AABB, margin: float = 0.72,
		yaw: float = 0.0, pitch: float = deg_to_rad(32.0)) -> void:
	camera.square_on(false)
	camera.frame(box, margin)
	camera.set("_target_yaw", yaw)
	camera.set("_target_pitch", pitch)
	camera.call("_apply", 1.0)


## The app's own view, once it has drawn what is there now. Awaited, not
## forced: forcing a draw from inside a frame re-enters the renderer.
func _settled_view() -> Image:
	for _n: int in 12:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _save(image: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var error: int = image.save_png(ProjectSettings.globalize_path(path))
	print("  wrote %s" % path.trim_prefix("res://") if error == OK
		else "  could not write %s (%d)" % [path, error])


func _say(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
