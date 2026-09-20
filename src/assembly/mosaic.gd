## A picture, laid out in bricks.
##
## One 1 x 1 plate per pixel, flat on the ground, which is how a real
## brick mosaic is built: plates on a baseplate, looked at from above or
## stood up once it is finished. Tiles would give a smoother picture but
## a tile clutches nothing, so a mosaic of tiles is a pile of tiles.
##
## Two things decide whether it looks like the photograph.
##
## The colour match has to be perceptual. Nearest-in-RGB picks by a
## distance that has little to do with what the eye does — it will send
## a mid grey to navy before it sends it to a lighter grey — so both
## sides go to Oklab first, where equal distances look equally different.
##
## And the palette is small. A real one is: these are the colours a 1 x 1
## plate is actually moulded in, not all 147 solid colours in the
## library, most of which exist on one part from 1978. Matching to a
## small palette without dithering gives flat bands across anything
## subtle — a sky becomes three stripes — so the error from each pixel
## is carried into its neighbours.
class_name Mosaic
extends RefCounted

## The part every pixel is made of.
const PIXEL_PART := "3024"

## How wide a mosaic may be, in studs. A 96 x 96 is 9,216 plates, which
## the renderer takes in its stride and a person would take a fortnight
## to build.
const MAX_WIDTH := 96
const MIN_WIDTH := 8


class Pixel extends RefCounted:
	var x: int = 0
	var z: int = 0
	var color_code: int = 0


## Work out the plates for an image.
##
## [param palette] is the colour codes to choose from — the standard
## moulded palette, not the whole library.
static func lay_out(image: Image, across: int, palette: PackedInt32Array,
		library: PartLibrary, dither: bool = true) -> Array[Pixel]:
	var pixels: Array[Pixel] = []
	if image == null or image.is_empty() or palette.is_empty():
		return pixels

	across = clampi(across, MIN_WIDTH, MAX_WIDTH)
	var down: int = maxi(1, int(round(
		float(across) * float(image.get_height()) / float(image.get_width()))))

	# Linear first, then resize. Averaging sRGB numbers is averaging the
	# encoding rather than the light, which shifts every midtone and
	# haloes every edge — most visible exactly where a mosaic lives, in
	# large smooth areas. srgb_to_linear only accepts eight-bit formats,
	# hence the conversion either side of it; the precision it costs in
	# the darks is beneath a palette of forty-four colours.
	var scaled: Image = image.duplicate()
	scaled.convert(Image.FORMAT_RGBA8)
	scaled.srgb_to_linear()
	scaled.convert(Image.FORMAT_RGBAF)
	scaled.resize(across, down, Image.INTERPOLATE_LANCZOS)

	# The palette in Oklab, once, rather than per pixel: a 96 x 96 image
	# against 44 colours is 405,504 comparisons, and converting inside
	# that loop would make it 405,504 conversions too.
	var lab: Array[Vector3] = []
	for code: int in palette:
		var color: PartLibrary.BrickColor = library.color(code)
		lab.append(_oklab(color.rgb if color != null else Color.MAGENTA))

	for y: int in down:
		for x: int in across:
			var want: Color = scaled.get_pixel(x, y)
			# Transparent pixels are holes, not black squares. A logo on
			# a clear background is the common case and filling it in
			# would bury the subject in a slab.
			if want.a < 0.5:
				continue

			# The buffer is already linear, so this does not decode again.
			var here: Vector3 = _oklab_linear(want.r, want.g, want.b)
			var best: int = 0
			var best_gap: float = INF
			for index: int in lab.size():
				var gap: float = here.distance_squared_to(lab[index])
				if gap < best_gap:
					best_gap = gap
					best = index

			var pixel := Pixel.new()
			pixel.x = x
			# Rows run away from the viewer, so the top of the picture is
			# the far edge and it reads the right way up from the front.
			pixel.z = y
			pixel.color_code = palette[best]
			pixels.append(pixel)

			if dither:
				# Both sides linear, so the error means what it says.
				_spread(scaled, x, y, across, down,
					want - _from_oklab(lab[best]))

	return pixels


## How much of each pixel's error to pass on. Full strength is correct
## for a printer with hundreds of dots per inch; at one plate per eight
## millimetres each speck is something a person can see and count, so a
## little of the error is dropped rather than chased. Gradients stay
## smooth and flat areas stay flat.
const DAMPING := 0.78


## Floyd–Steinberg: push each pixel's error into the neighbours not yet
## visited, so a colour the palette cannot hit is approximated by a mix
## of ones it can. Without it every gradient becomes a band.
static func _spread(image: Image, x: int, y: int, across: int, down: int,
		error: Color) -> void:
	const NEIGHBOURS: Array[Vector3] = [
		Vector3(1, 0, 7.0 / 16.0),
		Vector3(-1, 1, 3.0 / 16.0),
		Vector3(0, 1, 5.0 / 16.0),
		Vector3(1, 1, 1.0 / 16.0),
	]
	for step: Vector3 in NEIGHBOURS:
		var nx: int = x + int(step.x)
		var ny: int = y + int(step.y)
		if nx < 0 or nx >= across or ny < 0 or ny >= down:
			continue
		var was: Color = image.get_pixel(nx, ny)
		# Clamped. The buffer is floating point so it will happily hold
		# 1.4 or -0.3, and an unclamped error compounds along a row until
		# the nearest match to a slightly-off white is a saturated pink.
		# That is what it did: the white of the lighthouse came out
		# speckled with magenta.
		image.set_pixel(nx, ny, Color(
			clampf(was.r + error.r * step.z * DAMPING, 0.0, 1.0),
			clampf(was.g + error.g * step.z * DAMPING, 0.0, 1.0),
			clampf(was.b + error.b * step.z * DAMPING, 0.0, 1.0),
			was.a))


## sRGB to Oklab. Perceptually uniform, so a plain distance in it means
## "looks this different" — which is the whole reason for going there.
static func _oklab(color: Color) -> Vector3:
	return _oklab_linear(_linear(color.r), _linear(color.g), _linear(color.b))


## The same, for values that have already been decoded. The image buffer
## is linear throughout, so running it through the transfer function
## again would darken every pixel before it was matched.
static func _oklab_linear(r: float, g: float, b: float) -> Vector3:
	var l: float = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	var m: float = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	var s: float = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

	var l_: float = signf(l) * pow(absf(l), 1.0 / 3.0)
	var m_: float = signf(m) * pow(absf(m), 1.0 / 3.0)
	var s_: float = signf(s) * pow(absf(s), 1.0 / 3.0)

	return Vector3(
		0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
		1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
		0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_)


## Back again, so the dither can work out what the match got wrong —
## into linear, which is the space the buffer is in.
static func _from_oklab(lab: Vector3) -> Color:
	var l_: float = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z
	var m_: float = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z
	var s_: float = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z

	var l: float = l_ * l_ * l_
	var m: float = m_ * m_ * m_
	var s: float = s_ * s_ * s_

	# Linear out, to match the buffer the error is subtracted from.
	return Color(
		4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


static func _linear(channel: float) -> float:
	# The exact transfer function, not a 2.2 power: the approximation
	# visibly lifts dark greys, and a photograph is mostly mid tones.
	return (channel / 12.92 if channel <= 0.04045
		else pow((channel + 0.055) / 1.055, 2.4))


static func _srgb(channel: float) -> float:
	var c: float = clampf(channel, 0.0, 1.0)
	return (c * 12.92 if c <= 0.0031308
		else 1.055 * pow(c, 1.0 / 2.4) - 0.055)
