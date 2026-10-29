## Does File, Render…'s Product look draw, each backdrop as named, and leave
## the window as it was?
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1280x800 \
##       --script src/dev/product_render_probe.gd
##
## Forward+ on the graphics card, where the look has everything it is made
## of. A small scene (a plate, a red tower, a slope, a chrome round, a clear
## brick, a blue column) drawn with RenderSettings.look "product", and asked:
##
##   the copy of the model a render draws is in the product shaders, and
##     the window's own model never is;
##   it draws, and differs from the window's look of the same shot;
##   each of render_model's backdrops comes out as named: white white to
##     its corners, gradient bright under the model and falling away to its
##     corners, dark dark;
##   depth of field softens the picture;
##   the window's frame costs what it did before (its own measured time on
##     the card, the median of 120 frames, before and after), with its
##     environment as it was;
##   and then, on swatches of sixteen colours (a 2x4 brick of each) on the
##     white sweep at Good, each colour as LDraw has it: read off the
##     middle of the face the key lights and the camera sees, as CIEDE2000
##     against LDConfig's value. Black stays black (its bricks' mean
##     lightness, highlights and all), dark bluish grey is not crushed into
##     it, the bright colours and the clear ones are each near their own,
##     and a light grey face the key lights is smooth, not hatched with its
##     own shadow (render342).
##
## Leaves shots/render/product_*.png to look at.
extends SceneTree

const OUT := "res://shots/render/"

var _failures: int = 0
var _main: Node
var _render: StudioRender
var _world: BrickWorld


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	_world = _main.get("_world")
	var library: PartLibrary = _main.get("_library")
	if _world == null or library == null or library.parts.is_empty():
		print("  FAIL  no world or no catalogue")
		quit(1)
		return
	var method: String = RenderingServer.get_current_rendering_method()
	print("  renderer: %s" % method)
	if method != "forward_plus":
		print("product_render probe: SKIPPED, it needs Forward+ (run it on the GPU)")
		quit(0)
		return
	(_main.get("_builder") as Builder).hide_preview()
	_build_scene(library)
	for _n: int in 30:
		await process_frame

	var environment: Environment = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var window_look: Array = [environment.tonemap_mode, environment.ssil_enabled,
		environment.adjustment_enabled, environment.sky]
	var before: float = await _window_frame_ms()
	print("  the window's frame on the card before: %.3f ms" % before)

	_render = StudioRender.new()
	_render.library = library
	_render.scenery = (_main.get("_store") as ModelStore).scenery
	_render.eye = _main.get("_camera")
	_render.look = environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		_render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(_render)

	# The window's look and the product look of one shot.
	var window_shot: Image = await _render.render(_world, _settings("window", "white"))
	var product_shot: Image = await _render.render(_world, _settings("product", "white"))
	_say("the product look draws a picture", product_shot != null
		and product_shot.get_size() == Vector2i(480, 270))
	if window_shot == null or product_shot == null:
		quit(1)
		return
	product_shot.save_png(OUT + "product_white.png")
	window_shot.save_png(OUT + "product_window_look.png")
	var stage: BrickWorld = _render.get("_stage")
	var shaders: Array = BrickWorld.PRODUCT_SHADERS.values()
	var batches: int = 0
	var in_product: int = 0
	for child: Node in stage.get_children():
		var batch := child as MultiMeshInstance3D
		if batch == null or batch.material_override == null:
			continue
		batches += 1
		if (batch.material_override as ShaderMaterial).shader in shaders:
			in_product += 1
	_say("every batch of the render's copy is in a product shader, %d of %d" % [in_product,
		batches], batches > 0 and in_product == batches)
	var window_product: int = 0
	for child: Node in _world.get_children():
		var batch := child as MultiMeshInstance3D
		if batch != null and batch.material_override is ShaderMaterial \
				and (batch.material_override as ShaderMaterial).shader in shaders:
			window_product += 1
	_say("...and none of the window's, %d" % window_product, window_product == 0)
	var camera: Camera3D = _render.get("_camera")
	_say("the product look is graded through a film curve",
		camera.environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC)
	var differs: float = _model_difference(window_shot, product_shot)
	_say("it differs from the window's look of the same shot, %.3f" % differs, differs > 0.03)

	# Each backdrop as named.
	var white_corner: float = _corners(product_shot)
	_say("white: white to its corners, %.2f" % white_corner, white_corner > 0.85)
	var gradient: Image = await _render.render(_world, _settings("product", "gradient"))
	if gradient != null:
		gradient.save_png(OUT + "product_gradient.png")
		var middle: float = _floor_under(gradient)
		var corner: float = _corners(gradient)
		_say("gradient: %.2f under the model, %.2f in its corners" % [middle, corner],
			middle > 0.8 and middle - corner > 0.1)
	else:
		_say("gradient: drew a picture", false)
	var dark: Image = await _render.render(_world, _settings("product", "dark"))
	if dark != null:
		dark.save_png(OUT + "product_dark.png")
		var corner: float = _corners(dark)
		var middle: float = _floor_under(dark)
		_say("dark: %.2f in its corners, %.2f under the model" % [corner, middle],
			corner < 0.12 and middle >= corner)
	else:
		_say("dark: drew a picture", false)

	# Depth of field, at Best.
	var sharp_settings: RenderSettings = _settings("product", "white")
	sharp_settings.quality = RenderSettings.Quality.BEST
	sharp_settings.samples = 16
	var sharp: Image = await _render.render(_world, sharp_settings)
	var soft_settings: RenderSettings = sharp_settings.copy()
	soft_settings.f_stop = 2.0
	soft_settings.focus = 0.0
	var soft: Image = await _render.render(_world, soft_settings)
	if sharp != null and soft != null:
		soft.save_png(OUT + "product_depth_of_field.png")
		var crisp: float = _detail(sharp)
		var blurred: float = _detail(soft)
		_say("depth of field softens it: detail %.4f, %.4f with the lens open" % [crisp, blurred],
			blurred < crisp * 0.92)
	else:
		_say("depth of field: drew both pictures", false)

	# The window, after.
	for _n: int in 30:
		await process_frame
	var after: float = await _window_frame_ms()
	print("  the window's frame on the card after: %.3f ms" % after)
	_say("the window's frame costs what it did, %.3f ms then %.3f ms" % [before, after],
		after <= before * 1.1 + 0.3)
	var now: Array = [environment.tonemap_mode, environment.ssil_enabled,
		environment.adjustment_enabled, environment.sky]
	_say("...and its environment is as it was", now == window_look)

	await _swatches(library)

	print("")
	print("%d failed" % _failures if _failures
		else "the product look draws every backdrop and leaves the window as it was")
	quit(1 if _failures else 0)


func _build_scene(library: PartLibrary) -> void:
	_world.clear()
	var parts: Array = [
		["3958", 71, Vector3(0, 8, 0)],
		["3001", 4, Vector3(-20, 32, -20)],
		["3001", 4, Vector3(-20, 56, -20)],
		["3001", 4, Vector3(-20, 80, -20)],
		["3039", 14, Vector3(30, 32, 20)],
		["3062b", 383, Vector3(-40, 32, 40)],
		["3001", 47, Vector3(30, 32, -30)],
	]
	for part: Array in parts:
		if library.parts.has(str(part[0])):
			_world.add_brick(str(part[0]), int(part[1]), Transform3D(Basis.IDENTITY, part[2]))
		else:
			_say("the library has %s" % part[0], false)
	for n: int in 7:
		_world.add_brick("3005", 1, Transform3D(Basis.IDENTITY,
			Vector3(110, 24.0 * float(n + 1), 30)))


## Each colour as LDraw has it, on the white sweep: [code, name], laid out
## four by four so none hides another from the hero view.
const SWATCHES: Array = [
	[0, "black"], [72, "dark bluish grey"], [320, "dark red"], [272, "dark blue"],
	[4, "red"], [14, "yellow"], [1, "blue"], [2, "green"],
	[15, "white"], [19, "tan"], [71, "light bluish grey"], [47, "trans clear"],
	[36, "trans red"], [33, "trans dark blue"], [46, "trans yellow"], [34, "trans green"],
]
const BRIGHT: Array = ["red", "yellow", "blue", "green", "white", "tan"]
## Black's bricks, highlights and all, no lighter than this (sRGB
## luminance, 0 to 1): 0.218 before render342 on this sweep, 0.132 in the
## window look, 0.155 LDraw's own #1b2a34.
const BLACK_MOST := 0.19


func _swatches(library: PartLibrary) -> void:
	_world.clear()
	var ids: Array = []
	for n: int in SWATCHES.size():
		ids.append(_world.add_brick("3001", int(SWATCHES[n][0]), Transform3D(Basis.IDENTITY,
			Vector3((n % 4) * 140.0, 24.0, (n / 4) * 110.0))))
	for _n: int in 10:
		await process_frame
	var settings: RenderSettings = _settings("product", "white")
	settings.size = Vector2i(1280, 720)
	var image: Image = await _render.render(_world, settings)
	if image == null:
		_say("the swatches draw", false)
		return
	image.save_png(OUT + "product_swatches.png")
	var mesh: Lbm.PartMesh = library.mesh_for("3001")
	var low: Vector3 = mesh.bounds.position
	var high: Vector3 = mesh.bounds.end
	high.y = minf(high.y, BrickWorld._body_top(mesh))
	var faces: Dictionary = {
		"front": [Vector3(low.x, low.y, high.z), Vector3(high.x, low.y, high.z),
			Vector3(high.x, high.y, high.z), Vector3(low.x, high.y, high.z)],
		"side": [Vector3(low.x, low.y, low.z), Vector3(low.x, low.y, high.z),
			Vector3(low.x, high.y, high.z), Vector3(low.x, high.y, low.z)],
		"top": [Vector3(low.x, high.y, high.z), Vector3(high.x, high.y, high.z),
			Vector3(high.x, high.y, low.z), Vector3(low.x, high.y, low.z)],
	}
	var bright: float = 0.0
	var clear: float = 0.0
	var found: Dictionary = {}
	print("  swatches at Good, the lit face against LDraw (CIEDE2000):")
	for n: int in SWATCHES.size():
		var at: Transform3D = _render.staged_transform(ids[n])
		var want: Color = (library.colors[int(SWATCHES[n][0])] as PartLibrary.BrickColor).rgb
		var lit: Array = []
		var lightness: float = 0.0
		var pixels: int = 0
		for face: String in faces:
			var got: Array = _face(image, faces[face], at, settings.size)
			if face == "front":
				lit = got
			lightness += float(got[2]) * int(got[1])
			pixels += int(got[1])
		var difference: float = _ciede2000(lit[0], want)
		var name: String = SWATCHES[n][1]
		found[name] = [difference, lightness / maxf(pixels, 1), lit[3]]
		if name in BRIGHT:
			bright += difference / BRIGHT.size()
		elif name.begins_with("trans"):
			clear += difference / 5.0
		print("    %-18s LDraw #%s  drawn #%s  dE %4.1f" % [name, want.to_html(false),
			(lit[0] as Color).to_html(false), difference])
	_say("black stays black on the white sweep: its bricks' mean lightness %.3f, under %.2f"
		% [found["black"][1], BLACK_MOST], found["black"][1] < BLACK_MOST)
	_say("dark bluish grey is not crushed into it: dE %.1f from its own" % found["dark bluish grey"][0],
		found["dark bluish grey"][0] < 6.0)
	_say("red, yellow, blue, green, white and tan near their own: mean dE %.2f" % bright,
		bright < 5.0)
	_say("the clear colours near their own: mean dE %.2f" % clear, clear < 6.0)
	_say("a light grey face the key lights is smooth, not hatched: %.4f" % found["light bluish grey"][2],
		found["light bluish grey"][2] < 0.012)


## A face of a brick at [param at], in its own coordinates [param corners],
## its middle (a fifth in from each edge) as drawn: [mean colour, averaged
## in linear light; pixels; mean lightness; grain, the mean of each
## pixel's lightness against its four neighbours'].
func _face(image: Image, corners: Array, at: Transform3D, size: Vector2i) -> Array:
	var shot: StudioRender.Shot = _render.last_shot
	var quad: Array = []
	for uv: Vector2 in [Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.8, 0.8), Vector2(0.2, 0.8)]:
		var point: Vector3 = at * (corners[0] as Vector3).lerp(corners[1], uv.x).lerp(
			(corners[3] as Vector3).lerp(corners[2], uv.x), uv.y)
		var seen: Vector3 = shot.basis.inverse() * (point - shot.origin)
		var across: float = tan(deg_to_rad(shot.fov) * 0.5)
		var flat := Vector2(seen.x, seen.y) / -seen.z / across
		flat.x /= float(size.x) / float(size.y)
		quad.append(Vector2((flat.x * 0.5 + 0.5) * size.x, (0.5 - flat.y * 0.5) * size.y))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner: Vector2 in quad:
		lo = lo.min(corner)
		hi = hi.max(corner)
	var sum := Vector3.ZERO
	var lightness: float = 0.0
	var grain: float = 0.0
	var count: int = 0
	for y: int in range(maxi(int(lo.y), 1), mini(int(hi.y) + 1, image.get_height() - 1)):
		for x: int in range(maxi(int(lo.x), 1), mini(int(hi.x) + 1, image.get_width() - 1)):
			if not _inside(Vector2(x + 0.5, y + 0.5), quad):
				continue
			var here: Color = image.get_pixel(x, y)
			var linear: Color = here.srgb_to_linear()
			sum += Vector3(linear.r, linear.g, linear.b)
			lightness += here.get_luminance()
			grain += absf(4.0 * here.get_luminance() - image.get_pixel(x - 1, y).get_luminance()
				- image.get_pixel(x + 1, y).get_luminance() - image.get_pixel(x, y - 1).get_luminance()
				- image.get_pixel(x, y + 1).get_luminance())
			count += 1
	if count == 0:
		return [Color(0, 0, 0), 0, 0.0, 0.0]
	sum /= float(count)
	return [Color(sum.x, sum.y, sum.z).linear_to_srgb(), count, lightness / count, grain / count]


static func _inside(point: Vector2, quad: Array) -> bool:
	var side: float = 0.0
	for n: int in quad.size():
		var a: Vector2 = quad[n]
		var turn: float = ((quad[(n + 1) % quad.size()] as Vector2) - a).cross(point - a)
		if side == 0.0:
			side = signf(turn)
		elif turn != 0.0 and signf(turn) != side:
			return false
	return true


## CIE L*a*b* (D65) of an sRGB colour.
static func _lab(colour: Color) -> Vector3:
	var c: Color = colour.srgb_to_linear()
	var xyz := Vector3((0.4124 * c.r + 0.3576 * c.g + 0.1805 * c.b) / 0.95047,
		0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b,
		(0.0193 * c.r + 0.1192 * c.g + 0.9505 * c.b) / 1.08883)
	var f := Vector3.ZERO
	for i: int in 3:
		f[i] = pow(xyz[i], 1.0 / 3.0) if xyz[i] > 0.008856 else 7.787 * xyz[i] + 16.0 / 116.0
	return Vector3(116.0 * f.y - 16.0, 500.0 * (f.x - f.y), 200.0 * (f.y - f.z))


## The CIEDE2000 colour difference: about 1 is the least an eye tells apart.
static func _ciede2000(one: Color, two: Color) -> float:
	var a: Vector3 = _lab(one)
	var b: Vector3 = _lab(two)
	var mean_chroma: float = (Vector2(a.y, a.z).length() + Vector2(b.y, b.z).length()) * 0.5
	var g: float = 0.5 * (1.0 - sqrt(pow(mean_chroma, 7.0) / (pow(mean_chroma, 7.0) + pow(25.0, 7.0))))
	var c1: float = Vector2(a.y * (1.0 + g), a.z).length()
	var c2: float = Vector2(b.y * (1.0 + g), b.z).length()
	var h1: float = fposmod(rad_to_deg(atan2(a.z, a.y * (1.0 + g))), 360.0)
	var h2: float = fposmod(rad_to_deg(atan2(b.z, b.y * (1.0 + g))), 360.0)
	var dh: float = 0.0
	var hm: float = h1 + h2
	if c1 * c2 != 0.0:
		dh = h2 - h1
		if dh > 180.0:
			dh -= 360.0
		elif dh < -180.0:
			dh += 360.0
		if absf(h1 - h2) <= 180.0:
			hm = (h1 + h2) * 0.5
		else:
			hm = (h1 + h2 + 360.0) * 0.5 if h1 + h2 < 360.0 else (h1 + h2 - 360.0) * 0.5
	var big_dh: float = 2.0 * sqrt(c1 * c2) * sin(deg_to_rad(dh * 0.5))
	var lm: float = (a.x + b.x) * 0.5
	var cm: float = (c1 + c2) * 0.5
	var t: float = 1.0 - 0.17 * cos(deg_to_rad(hm - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * hm)) \
		+ 0.32 * cos(deg_to_rad(3.0 * hm + 6.0)) - 0.2 * cos(deg_to_rad(4.0 * hm - 63.0))
	var rc: float = 2.0 * sqrt(pow(cm, 7.0) / (pow(cm, 7.0) + pow(25.0, 7.0)))
	var rt: float = -sin(deg_to_rad(60.0 * exp(-pow((hm - 275.0) / 25.0, 2.0)))) * rc
	var sl: float = 1.0 + 0.015 * pow(lm - 50.0, 2.0) / sqrt(20.0 + pow(lm - 50.0, 2.0))
	var sc: float = 1.0 + 0.045 * cm
	var sh: float = 1.0 + 0.015 * cm * t
	var dl: float = (b.x - a.x) / sl
	var dc: float = (c2 - c1) / sc
	var dhh: float = big_dh / sh
	return sqrt(dl * dl + dc * dc + dhh * dhh + rt * dc * dhh)


func _settings(look: String, backdrop: String) -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.GOOD
	settings.size = Vector2i(480, 270)
	settings.view = "hero"
	settings.look = look
	settings.use_backdrop(backdrop)
	return settings


## The window's own measured time on the card, ms: the median of 120 frames.
func _window_frame_ms() -> float:
	var window: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(window, true)
	for _n: int in 20:
		await process_frame
	var times := PackedFloat32Array()
	for _n: int in 120:
		await process_frame
		times.append(RenderingServer.viewport_get_measured_render_time_gpu(window))
	RenderingServer.viewport_set_measure_render_time(window, false)
	times.sort()
	return times[times.size() / 2]


## How much the model's pixels differ between two pictures of one shot,
## on average, 0 to 1: the pixels that are not the backdrop's in either.
func _model_difference(a: Image, b: Image) -> float:
	var sum: float = 0.0
	var count: int = 0
	var backdrop: Color = a.get_pixel(4, 4)
	for y: int in range(0, a.get_height(), 2):
		for x: int in range(0, a.get_width(), 2):
			var one: Color = a.get_pixel(x, y)
			var two: Color = b.get_pixel(x, y)
			if absf(one.get_luminance() - backdrop.get_luminance()) < 0.04:
				continue
			sum += (absf(one.r - two.r) + absf(one.g - two.g) + absf(one.b - two.b)) / 3.0
			count += 1
	return sum / float(count) if count > 0 else 0.0


## The lightness of the picture's four corners, averaged.
func _corners(image: Image) -> float:
	var sum: float = 0.0
	var w: int = image.get_width()
	var h: int = image.get_height()
	for at: Vector2i in [Vector2i(3, 3), Vector2i(w - 4, 3), Vector2i(3, h - 4),
			Vector2i(w - 4, h - 4)]:
		sum += image.get_pixelv(at).get_luminance()
	return sum / 4.0


## The floor's lightness just below the model, in the middle of the picture.
func _floor_under(image: Image) -> float:
	var x: int = image.get_width() / 2
	var best: float = 0.0
	for y: int in range(int(image.get_height() * 0.8), int(image.get_height() * 0.95)):
		best = maxf(best, image.get_pixel(x, y).get_luminance())
	return best


## How much fine detail a picture has: the mean difference between
## neighbouring pixels.
func _detail(image: Image) -> float:
	var sum: float = 0.0
	var count: int = 0
	for y: int in range(1, image.get_height()):
		for x: int in range(1, image.get_width()):
			var here: float = image.get_pixel(x, y).get_luminance()
			sum += absf(here - image.get_pixel(x - 1, y).get_luminance()) \
				+ absf(here - image.get_pixel(x, y - 1).get_luminance())
			count += 1
	return sum / float(count)


func _say(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
