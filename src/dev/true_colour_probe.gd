## Does a colour on screen read as the colour it is?
##
##   godot --path . --resolution 1400x900 --script src/dev/true_colour_probe.gd
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 \
##       --script src/dev/true_colour_probe.gd
##
## The first is the Compatibility renderer the web build uses (the plain
## `godot` here draws in software, with that renderer); the second is
## Forward+ on the GPU.
##
## Black read as navy: a black Tower of Orthanc came out dark slate blue.
## Nothing was wrong in any one place a person would look — the colour
## list, the shader, the lights and the tonemapper each looked
## reasonable — so this asks the picture. A row of the colours a model
## is mostly built from, under the app's own lights, and the lit faces
## sampled and held against the colour they are meant to be, in Oklab:
## L for how light, C for how coloured, h for which hue.
##
## Two references, because they disagree: the colour list's display
## value (LDraw's, what the app draws from) and LEGO's own as Rebrickable
## publishes it. LDraw's black is #1B2A34, a blue-black; LEGO's #05131D.
extends SceneTree

## Code, name, LEGO's own value (Rebrickable colors.csv).
const ROW: Array = [
	[0, "Black", "05131D"],
	[72, "Dark Bluish Grey", "6C6E68"],
	[71, "Light Bluish Grey", "A0A5A9"],
	[15, "White", "FFFFFF"],
	[4, "Red", "C91A09"],
	[1, "Blue", "0055BF"],
]

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

	# A 2 x 4 brick for a face turned to the eye, and a 2 x 2 tile in
	# front of it for a flat top in the light.
	builder.hide_preview()
	world.clear()
	for n: int in ROW.size():
		var x: float = float(n) * 100.0
		world.add_brick("3001", ROW[n][0], Transform3D(Basis.IDENTITY, Vector3(x, 24.0, 0.0)))
		world.add_brick("3068b", ROW[n][0], Transform3D(Basis.IDENTITY, Vector3(x, 8.0, 60.0)))
	await process_frame
	main.get_node("HUD").visible = false
	camera.square_on(false)
	camera.frame(world.model_bounds(), 0.7)
	camera.set("_target_yaw", 0.0)
	camera.set("_target_pitch", deg_to_rad(26.0))
	camera.call("_apply", 1.0)
	for _n: int in 12:
		await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var marked: Image = image.duplicate()

	print("")
	print("  %-18s %-8s %-8s  %-8s %-8s   %s" % [
		"", "LDraw", "LEGO", "top", "front", "top L C h  |  LDraw L C h  |  LEGO L C h"])
	var measured: Dictionary = {}
	for n: int in ROW.size():
		var code: int = ROW[n][0]
		var x: float = float(n) * 100.0
		var top: Color = _sample(image, marked, camera, Vector3(x, 8.0, 60.0),
			Vector3(14.0, 0.0, 14.0))
		var front: Color = _sample(image, marked, camera, Vector3(x, 12.0, 20.0),
			Vector3(28.0, 7.0, 0.0))
		var ldraw: Color = library.color(code).rgb
		var lego := Color.html(ROW[n][2])
		measured[code] = [top, front, ldraw, lego]
		print("  %-18s #%s  #%s   #%s  #%s   %s  |  %s  |  %s" % [
			ROW[n][1], ldraw.to_html(false), lego.to_html(false),
			top.to_html(false), front.to_html(false),
			_lch_text(top), _lch_text(ldraw), _lch_text(lego)])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var out: String = "shots/true_colour_%s.png" % method
	marked.save_png(ProjectSettings.globalize_path("res://" + out))
	print("")
	print("  wrote %s" % out)
	print("")

	# What a person means by "reads as": black is black and the greys
	# are grey — no more colour in them than LEGO's own values carry —
	# the two greys are two greys, and red and blue keep their hue.
	for code: int in [0, 72, 71, 15]:
		var top: Color = measured[code][0]
		var front: Color = measured[code][1]
		var lego: Color = measured[code][3]
		var allowed: float = maxf(_lch(lego).y * 1.25, 0.012)
		_say("%s reads neutral: chroma %.3f on top, %.3f in front (LEGO's own %.3f)" % [
				library.color(code).name, _lch(top).y, _lch(front).y, _lch(lego).y],
			_lch(top).y <= allowed and _lch(front).y <= allowed)
	var black_l: float = _lch(measured[0][1]).x
	_say("black is dark: L %.2f in front" % black_l, black_l < 0.32)
	var dark_l: float = _lch(measured[72][0]).x
	var light_l: float = _lch(measured[71][0]).x
	# Lit, a grey should read as that grey and not the next one up: the
	# top in full light a little above its own value, never a step above.
	# Dark bluish grey read 0.80 here, which is light bluish grey's place,
	# and a castle built in the two greys came out in one.
	for code: int in [72, 71]:
		var own: float = _lch(measured[code][2]).x
		var lit: float = _lch(measured[code][0]).x
		_say("%s lit reads as itself: L %.2f on top, its own %.2f" % [
				library.color(code).name, lit, own],
			lit > own - 0.05 and lit < own + 0.15)
	_say("the two greys are two greys: L %.2f against %.2f on top" % [dark_l, light_l],
		light_l - dark_l > 0.12)
	_say("white is lighter than light grey: L %.2f against %.2f" % [
			_lch(measured[15][0]).x, light_l],
		_lch(measured[15][0]).x > light_l + 0.04)
	for code: int in [4, 1]:
		var seen: float = _lch(measured[code][0]).z
		var meant: float = _lch(measured[code][2]).z
		var off: float = absf(angle_difference(seen, meant))
		_say("%s keeps its hue on top: %.0f against %.0f degrees" % [
				library.color(code).name, rad_to_deg(seen), rad_to_deg(meant)],
			rad_to_deg(off) < 12.0)

	print("")
	print("%d failed" % _failures if _failures
		else "every colour in the row reads as itself, on %s" % method)
	quit(1 if _failures else 0)


## The mean colour of a face, measured over a box around a point on it,
## and the box drawn on the copy that is kept.
func _sample(image: Image, marked: Image, camera: CadCamera, at: Vector3,
		half: Vector3) -> Color:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner: int in 8:
		var point := at + Vector3(
			-half.x if corner & 1 else half.x,
			-half.y if corner & 2 else half.y,
			-half.z if corner & 4 else half.z)
		var screen: Vector2 = camera.unproject_position(point)
		lo = Vector2(minf(lo.x, screen.x), minf(lo.y, screen.y))
		hi = Vector2(maxf(hi.x, screen.x), maxf(hi.y, screen.y))
	var scale: Vector2 = Vector2(image.get_size()) / camera.get_viewport().get_visible_rect().size
	var rect := Rect2i(Vector2i(lo * scale), Vector2i((hi - lo) * scale))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var total := Vector3.ZERO
	var counted: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var pixel: Color = image.get_pixel(x, y)
			total += Vector3(pixel.r, pixel.g, pixel.b)
			counted += 1
	for x: int in range(rect.position.x, rect.end.x):
		marked.set_pixel(x, rect.position.y, Color.MAGENTA)
		marked.set_pixel(x, maxi(rect.end.y - 1, 0), Color.MAGENTA)
	for y: int in range(rect.position.y, rect.end.y):
		marked.set_pixel(rect.position.x, y, Color.MAGENTA)
		marked.set_pixel(maxi(rect.end.x - 1, 0), y, Color.MAGENTA)
	if counted == 0:
		return Color(0, 0, 0, 0)
	total /= float(counted)
	return Color(total.x, total.y, total.z)


## Oklab lightness, chroma and hue (radians) of an sRGB colour.
static func _lch(color: Color) -> Vector3:
	var r: float = _linear(color.r)
	var g: float = _linear(color.g)
	var b: float = _linear(color.b)
	var l: float = pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m: float = pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s: float = pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	var lightness: float = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
	var a: float = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
	var bb: float = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	return Vector3(lightness, sqrt(a * a + bb * bb), atan2(bb, a))


static func _linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _lch_text(color: Color) -> String:
	var lch: Vector3 = _lch(color)
	return "%.2f %.3f %4.0f" % [lch.x, lch.y, rad_to_deg(lch.z)]


func _say(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
