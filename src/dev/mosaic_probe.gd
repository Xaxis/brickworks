## Check a picture comes out looking like the picture.
##
##   godot --headless --path . --script src/dev/mosaic_probe.gd
##
## The failure that matters is not a crash — it is a mosaic that is
## recognisably the wrong colours, which looks like a working feature
## until you hold it against the photograph. So the checks are on the
## colour decisions: a flat red square must come out red, the palette
## must be honoured, and Oklab has to survive the round trip the dither
## depends on.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	var palette := PackedInt32Array(PartsBin.SWATCHES)
	print("  palette: %d colours" % palette.size())

	# Oklab both ways. The dither subtracts a matched colour from the
	# wanted one, so a lossy round trip becomes error injected into every
	# neighbour — noise that looks like grain.
	#
	# The comparison is in linear, because that is what both sides of
	# that subtraction are: the image buffer is decoded once up front and
	# _from_oklab hands back light rather than encoded values.
	var drift: float = 0.0
	for sample: Color in [Color.RED, Color.WHITE, Color.BLACK,
			Color(0.2, 0.45, 0.7), Color(0.9, 0.85, 0.1)]:
		var back: Color = Mosaic._from_oklab(Mosaic._oklab(sample))
		drift = maxf(drift, absf(back.r - Mosaic._linear(sample.r)))
		drift = maxf(drift, absf(back.g - Mosaic._linear(sample.g)))
		drift = maxf(drift, absf(back.b - Mosaic._linear(sample.b)))
	_check("Oklab round-trips in linear, worst channel off by %.5f" % drift,
		drift < 0.001)

	# A flat square of one colour, which must come back as that colour
	# and nothing else.
	var flat := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	flat.fill(library.color(4).rgb)   # Red
	var laid: Array[Mosaic.Pixel] = Mosaic.lay_out(flat, 16, palette, library, false)
	_check("a 16 x 16 square makes 256 plates, got %d" % laid.size(),
		laid.size() == 256)
	var all_red: bool = true
	for pixel: Mosaic.Pixel in laid:
		if pixel.color_code != 4:
			all_red = false
	_check("a red square comes out red", all_red)

	# Every colour chosen has to be one you can actually buy.
	var gradient := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			gradient.set_pixel(x, y, Color(x / 31.0, y / 31.0, 0.5))
	var mixed: Array[Mosaic.Pixel] = Mosaic.lay_out(
		gradient, 32, palette, library, true)
	var stray: int = 0
	var used: Dictionary = {}
	for pixel: Mosaic.Pixel in mixed:
		used[pixel.color_code] = true
		if not palette.has(pixel.color_code):
			stray += 1
	_check("every plate is a palette colour (%d strays)" % stray, stray == 0)
	_check("a gradient uses more than a handful of colours, got %d"
		% used.size(), used.size() >= 6)

	# Dithering is the difference between a gradient and three stripes.
	var banded: Array[Mosaic.Pixel] = Mosaic.lay_out(
		gradient, 32, palette, library, false)
	var flat_colours: Dictionary = {}
	for pixel: Mosaic.Pixel in banded:
		flat_colours[pixel.color_code] = true
	_check("dithering uses more colours than not: %d vs %d"
		% [used.size(), flat_colours.size()], used.size() > flat_colours.size())

	# A transparent background is a hole, not a black slab.
	var logo := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	logo.fill(Color(0, 0, 0, 0))
	for n: int in 16:
		logo.set_pixel(n, 8, Color(1, 1, 1, 1))
	var sparse: Array[Mosaic.Pixel] = Mosaic.lay_out(
		logo, 16, palette, library, false)
	_check("transparent pixels are left out, got %d plates" % sparse.size(),
		sparse.size() == 16)

	# Non-square images keep their proportions.
	var wide := Image.create_empty(64, 16, false, Image.FORMAT_RGBA8)
	wide.fill(Color.WHITE)
	var stretched: Array[Mosaic.Pixel] = Mosaic.lay_out(
		wide, 32, palette, library, false)
	var depth: int = 0
	for pixel: Mosaic.Pixel in stretched:
		depth = maxi(depth, pixel.z + 1)
	_check("a 4:1 picture stays 4:1, got 32 x %d" % depth, depth == 8)

	print("")
	print("%d failed" % _failures if _failures else "the mosaic reads true")
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
