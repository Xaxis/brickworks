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

## The colours a mosaic is laid in: the standard palette a set is
## moulded in, rather than all 322 including one-offs. It was the parts
## bin's swatch row until the bin offered every colour; a mosaic still
## wants only colours a 1 x 1 plate is really made in.
const PALETTE: Array[int] = [
	15, 71, 7, 72, 0, 4, 5, 27, 2, 10, 1, 9, 14, 25, 70, 28,
	19, 84, 26, 22, 3, 73, 6, 272, 288, 320, 191, 226, 212, 308,
	47, 40, 36, 33, 34, 43, 41, 46, 379, 378, 383, 297, 80, 135,
]

## How wide a mosaic may be, in studs. A 96 x 96 is 9,216 plates, which
## the renderer takes in its stride and a person would take a fortnight
## to build.
const MAX_WIDTH := 96
const MIN_WIDTH := 8


class Pixel extends RefCounted:
	var x: int = 0
	var z: int = 0
	var color_code: int = 0


## A mosaic as the person chose it: how wide, which part of the picture, in
## which colours, and whether a run of one colour goes in larger plates.
class Options extends RefCounted:
	var across: int = 48
	var dither: bool = true
	## The part of the picture laid, as fractions of it, 0 to 1 from its top
	## left: what was drawn on it in the dialog. The whole of it by default.
	var crop: Rect2 = Rect2(0, 0, 1, 1)
	## The colours chosen (a set's, what the person owns); empty for
	## [constant PALETTE].
	var palette: PackedInt32Array = PackedInt32Array()
	## Runs of a colour in the largest plates they fill ([method merge]).
	var mixed: bool = true


## One plate of a laid mosaic: its stud at the low corner, and its size in
## studs along x and z as it lies.
class Plate extends RefCounted:
	var part: String = PIXEL_PART
	var color_code: int = 0
	var x: int = 0
	var z: int = 0
	var size: Vector2i = Vector2i.ONE


## What a picture came to: a colour a stud, and the plates laid over them.
class Laid extends RefCounted:
	var across: int = 0
	var down: int = 0
	## Each stud's colour, x + z * across, the top of the picture at z = 0;
	## -1 where the picture is clear.
	var cells: PackedInt32Array = PackedInt32Array()
	## The colour each stud was asked to be, in linear light, as the picture
	## was sampled, before it was matched.
	var want: PackedColorArray = PackedColorArray()
	var plates: Array[Plate] = []
	## The colours it was matched to.
	var palette: PackedInt32Array = PackedInt32Array()
	## The picture's own pixels it was laid from: the crop.
	var source: Rect2i = Rect2i()

	## Studs with a plate on them.
	func studs() -> int:
		return cells.size() - cells.count(-1)

	## Part and colour, "3024/4", -> how many: the parts list it comes to.
	func counts() -> Dictionary:
		var out: Dictionary = {}
		for plate: Plate in plates:
			var key: String = "%s/%d" % [plate.part, plate.color_code]
			out[key] = int(out.get(key, 0)) + 1
		return out

	## How many of each size, most first: [["1 × 1", 310], ...].
	func by_size() -> Array:
		var tally: Dictionary = {}
		for plate: Plate in plates:
			var words: String = "%d × %d" % [mini(plate.size.x, plate.size.y),
				maxi(plate.size.x, plate.size.y)]
			tally[words] = int(tally.get(words, 0)) + 1
		var out: Array = []
		for words: String in tally:
			out.append([words, int(tally[words])])
		out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
		return out

	## The colours it is laid in.
	func colours() -> int:
		var seen: Dictionary = {}
		for code: int in cells:
			if code >= 0:
				seen[code] = true
		return seen.size()


## The plates a run of one colour is laid in, the most studs first: the
## part, and its studs one way and the other. Which way an LDraw plate is
## drawn is read off its shape when it is put down ([method transform_of]),
## so a table that has it the wrong way round still lays it right.
const PLATES: Array = [
	["41539", 8, 8], ["3036", 8, 6], ["3958", 6, 6], ["3035", 8, 4],
	["3032", 6, 4], ["2445", 12, 2], ["3832", 10, 2], ["3034", 8, 2],
	["3031", 4, 4], ["3795", 6, 2], ["60479", 12, 1], ["4477", 10, 1],
	["3460", 8, 1], ["3020", 4, 2], ["3666", 6, 1], ["3021", 3, 2],
	["3710", 4, 1], ["3022", 2, 2], ["3623", 3, 1], ["3023b", 2, 1],
	[PIXEL_PART, 1, 1],
]


## A picture laid as the person chose: cut to the crop, matched to the
## colours chosen, and each run of one colour in the largest plates it
## fills when [member Options.mixed] — the picture the same stud for stud
## either way, in fewer parts.
static func make(image: Image, options: Options, library: PartLibrary) -> Laid:
	var laid := Laid.new()
	if image == null or image.is_empty():
		return laid
	laid.source = crop_rect(image.get_size(), options.crop)
	laid.palette = palette_for(options.palette, library)
	var scaled: Image = _scaled(image.get_region(laid.source), options.across)
	laid.across = scaled.get_width()
	laid.down = scaled.get_height()
	laid.want.resize(laid.across * laid.down)
	for z: int in laid.down:
		for x: int in laid.across:
			laid.want[x + z * laid.across] = scaled.get_pixel(x, z)
	laid.cells.resize(laid.across * laid.down)
	laid.cells.fill(-1)
	for pixel: Pixel in _matched(scaled, laid.palette, library, options.dither):
		laid.cells[pixel.x + pixel.z * laid.across] = pixel.color_code
	laid.plates = merge(laid.cells, laid.across, laid.down, library) if options.mixed \
		else singles(laid.cells, laid.across, laid.down)
	return laid


## The pixels of a picture of [param size] that [param crop], fractions of
## it, takes in: whole pixels, at least one each way.
static func crop_rect(size: Vector2i, crop: Rect2) -> Rect2i:
	var x0: int = clampi(roundi(crop.position.x * size.x), 0, maxi(0, size.x - 1))
	var y0: int = clampi(roundi(crop.position.y * size.y), 0, maxi(0, size.y - 1))
	var x1: int = clampi(roundi(crop.end.x * size.x), x0 + 1, size.x)
	var y1: int = clampi(roundi(crop.end.y * size.y), y0 + 1, size.y)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


## The picture cut to [param crop], fractions of it; the picture itself when
## that is the whole of it.
static func cut(image: Image, crop: Rect2) -> Image:
	if image == null or image.is_empty():
		return image
	var rect: Rect2i = crop_rect(image.get_size(), crop)
	return image if rect.size == image.get_size() else image.get_region(rect)


## The colours a classic mosaic's studs are matched to. Chosen (a set's,
## what is owned): those a stud can be ([method paintable]) that a 1 x 1
## plate is not known never to have been made in. None chosen, All colours:
## LEGO's palette for the 1 x 1 plate now, every colour it has been in a
## set in since PartLibrary.recent_since, so every stud can be bought; in a
## build with no such data, [constant PALETTE]'s that can be. All of
## PALETTE once laid the car photo's background in 415 Chrome Silver studs,
## a colour no 1 x 1 plate is made in: a third of a Pick a Brick list that
## could not be filled.
static func palette_for(chosen: PackedInt32Array, library: PartLibrary) -> PackedInt32Array:
	var plate: PartLibrary.PartInfo = library.parts.get(PIXEL_PART)
	var now: bool = chosen.is_empty() and plate != null and not plate.colors_recent.is_empty()
	var among: PackedInt32Array = chosen if not chosen.is_empty() \
		else plate.colors_recent if now else PackedInt32Array(PALETTE)
	var known: Dictionary = {}
	var out := PackedInt32Array()
	for code: int in among:
		if out.has(code) or not paintable(code, library):
			continue
		if chosen.is_empty() and not now and not _sold(library, PIXEL_PART, code, known):
			continue
		if plate != null and plate.never_made_in(code):
			continue
		out.append(code)
	return out


## Whether [param code] is a colour a mosaic's stud can be: opaque plastic,
## pearl or metallic paint, as a person's own pieces are.
static func paintable(code: int, library: PartLibrary) -> bool:
	var colour: PartLibrary.BrickColor = library.color(code)
	return colour != null and colour.alpha >= 255 \
		and colour.group in ["solid", "pearlescent plastic", "metallic paint"]


## The colours of a set's parts, or of what is owned, as a palette: from
## rows of [part, colour, ...] or keys "part/colour" -> count, each colour
## once, in the order met. [param parts], when given, keeps to those parts
## (by number, retired numbers as they are now).
static func colours_in(rows: Variant, library: PartLibrary,
		parts: PackedStringArray = PackedStringArray()) -> PackedInt32Array:
	var wanted: Dictionary = {}
	for part: String in parts:
		wanted[library.resolve(part)] = true
	var out := PackedInt32Array()
	var pairs: Array = []
	if rows is Dictionary:
		for key: String in rows:
			if int((rows as Dictionary)[key]) > 0:
				pairs.append([key.get_slice("/", 0), int(key.get_slice("/", 1))])
	elif rows is Array:
		pairs = rows
	for row: Variant in pairs:
		var pair: Array = row
		if not wanted.is_empty() and not wanted.has(library.resolve(str(pair[0]))):
			continue
		var code: int = library.plain_code(int(pair[1]))
		if not out.has(code):
			out.append(code)
	return out


## The part numbers a classic mosaic is laid in.
static func plate_parts() -> PackedStringArray:
	var out := PackedStringArray()
	for shape: Array in PLATES:
		out.append(str(shape[0]))
	return out


## One 1 x 1 plate a stud.
static func singles(cells: PackedInt32Array, across: int, down: int) -> Array[Plate]:
	var out: Array[Plate] = []
	for z: int in down:
		for x: int in across:
			var code: int = cells[x + z * across]
			if code >= 0:
				out.append(_plate(PIXEL_PART, code, x, z, Vector2i.ONE))
	return out


## Runs of one colour in the largest plates they fill, row by row from the
## top left: at each stud not yet covered, the plate with the most studs
## (either way round) whose every stud is that colour and free, and that is
## made in that colour as a LEGO element — so a shop can sell every lot of
## it. Nothing changes colour: the picture is the same stud for stud, in
## fewer parts.
static func merge(cells: PackedInt32Array, across: int, down: int,
		library: PartLibrary) -> Array[Plate]:
	var out: Array[Plate] = []
	# How far each stud's colour runs to the right, covered or not: a
	# plate wider than that cannot start here, which rules most out at once.
	var run := PackedInt32Array()
	run.resize(cells.size())
	for z: int in down:
		for x: int in range(across - 1, -1, -1):
			var i: int = x + z * across
			if cells[i] < 0:
				run[i] = 0
			elif x + 1 < across and cells[i + 1] == cells[i]:
				run[i] = run[i + 1] + 1
			else:
				run[i] = 1
	var taken := PackedByteArray()
	taken.resize(cells.size())
	var sold: Dictionary = {}
	for z: int in down:
		for x: int in across:
			var i: int = x + z * across
			var code: int = cells[i]
			if code < 0 or taken[i] == 1:
				continue
			var laid: bool = false
			for shape: Array in PLATES:
				var part: String = str(shape[0])
				if part != PIXEL_PART and not _sold(library, part, code, sold):
					continue
				for turn: int in 2:
					var size := Vector2i(int(shape[1]), int(shape[2]))
					if turn == 1:
						if size.x == size.y:
							break
						size = Vector2i(size.y, size.x)
					if x + size.x > across or z + size.y > down \
							or not _free(cells, run, taken, across, x, z, size, code):
						continue
					for dz: int in size.y:
						for dx: int in size.x:
							taken[i + dx + dz * across] = 1
					out.append(_plate(part, code, x, z, size))
					laid = true
					break
				if laid:
					break
	return out


## Whether every stud of a plate of [param size] at [param x], [param z] is
## [param code] and free.
static func _free(cells: PackedInt32Array, run: PackedInt32Array, taken: PackedByteArray,
		across: int, x: int, z: int, size: Vector2i, code: int) -> bool:
	for dz: int in size.y:
		var j: int = x + (z + dz) * across
		if cells[j] != code or run[j] < size.x:
			return false
		for dx: int in size.x:
			if taken[j + dx] == 1:
				return false
	return true


## Whether LEGO sells [param part] in [param code] now: it has been in a
## set in that colour since PartLibrary.recent_since, where the catalogue
## knows; else an element number is known for it; in a build with neither,
## it is not known never to have been made in it.
static func _sold(library: PartLibrary, part: String, code: int, known: Dictionary) -> bool:
	var key: String = "%s/%d" % [part, code]
	if not known.has(key):
		if not known.has(""):
			known[""] = not library.element_for(PIXEL_PART, 0).is_empty()
		var info: PartLibrary.PartInfo = library.parts.get(part)
		if info != null and not info.colors_recent.is_empty():
			known[key] = info.colors_recent.has(code)
		elif bool(known[""]):
			known[key] = not library.element_for(part, code).is_empty()
		else:
			known[key] = info != null and not info.never_made_in(code)
	return bool(known[key])


static func _plate(part: String, code: int, x: int, z: int, size: Vector2i) -> Plate:
	var plate := Plate.new()
	plate.part = part
	plate.color_code = code
	plate.x = x
	plate.z = z
	plate.size = size
	return plate


## Where a plate goes: flat on the ground, its low corner on stud
## ([member Plate.x], [member Plate.z]), turned whichever way its shape
## covers [member Plate.size]. Read off the part's own cells, as the
## builder reads them, so the plate's corner is the stud's whatever the
## part's origin.
static func transform_of(plate: Plate, part: Lbm.PartMesh, builder: Builder) -> Transform3D:
	var fallback := Transform3D()
	for rot: int in 2:
		var basis: Basis = BrickLattice.basis_for("up", rot)
		var span: Array = builder._cell_span(part, Transform3D(basis, Vector3.ZERO))
		if span.is_empty():
			break
		var lo: Vector3i = span[0]
		var hi: Vector3i = span[1]
		var want := Vector3i(plate.x * BrickLattice.CELLS_PER_STUD, 0,
			plate.z * BrickLattice.CELLS_PER_STUD)
		var at := Transform3D(basis, BrickLattice.to_ldu(want - lo))
		if Vector2i(hi.x - lo.x + 1, hi.z - lo.z + 1) == plate.size * BrickLattice.CELLS_PER_STUD:
			return at
		if rot == 0:
			fallback = at
	return fallback


## Put a laid mosaic into the world, a brick a plate, through the ordinary
## placement path, so it is undone, saved, listed and walked by the booklet
## like anything built by hand. The world is not cleared first. The bricks
## placed, by id; a plate whose part is not to hand is left out.
static func put_down(laid: Laid, world: BrickWorld, builder: Builder,
		library: PartLibrary) -> PackedInt64Array:
	var ids := PackedInt64Array()
	# One shape read per part and size, not per plate: 1,300 of them.
	var placed: Dictionary = {}
	for plate: Plate in laid.plates:
		var part: Lbm.PartMesh = library.mesh_for(plate.part)
		if part == null:
			continue
		var key: String = "%s %s" % [plate.part, plate.size]
		if not placed.has(key):
			var at: Transform3D = transform_of(_plate(plate.part, 0, 0, 0, plate.size), part, builder)
			placed[key] = at
		var origin: Transform3D = placed[key]
		var here := Transform3D(origin.basis, origin.origin + Vector3(
			plate.x * BrickLattice.STUD, 0.0, plate.z * BrickLattice.STUD))
		var brick_id: int = world.add_brick(plate.part, plate.color_code, here)
		if brick_id != 0:
			builder.register(brick_id, plate.part, here)
			ids.append(brick_id)
	return ids


## Every part a laid mosaic uses to hand before it is put down: read from
## disk where the build has it, and on the web fetched, each kind at once,
## until each has come or is not coming, for twenty seconds at most.
static func fetch(laid: Laid, library: PartLibrary) -> void:
	var waiting: Array[String] = []
	var kinds: Dictionary = {}
	for plate: Plate in laid.plates:
		kinds[plate.part] = true
	for part: String in kinds:
		if not library.is_resident(part):
			library.mesh_for(part)
		if not library.is_resident(part) and library.request_mesh(part, true):
			waiting.append(part)
	var deadline: int = Time.get_ticks_msec() + 20000
	while not waiting.is_empty() and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
		waiting = waiting.filter(func(part: String) -> bool:
			return not library.is_resident(part) and library.is_on_its_way(part))


## A laid mosaic seen from the front, [param px] pixels a stud: each stud in
## its colour and each plate's edge a shade darker, so the sizes it is laid
## in show. What the dialog draws before anything is built.
static func picture_of(laid: Laid, library: PartLibrary, px: int = 6) -> Image:
	var image := Image.create_empty(maxi(1, laid.across * px), maxi(1, laid.down * px),
		false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for plate: Plate in laid.plates:
		var colour: PartLibrary.BrickColor = library.color(plate.color_code)
		var tone: Color = colour.rgb if colour != null else Color.MAGENTA
		var rect := Rect2i(plate.x * px, plate.z * px, plate.size.x * px, plate.size.y * px)
		image.fill_rect(rect, tone.darkened(0.3))
		if px >= 3:
			image.fill_rect(rect.grow(-1), tone)
	return image


## Work out the plates for an image.
##
## [param palette] is the colour codes to choose from — the standard
## moulded palette, not the whole library.
static func lay_out(image: Image, across: int, palette: PackedInt32Array,
		library: PartLibrary, dither: bool = true) -> Array[Pixel]:
	if image == null or image.is_empty() or palette.is_empty():
		var none: Array[Pixel] = []
		return none
	return _matched(_scaled(image, across), palette, library, dither)


## The picture a stud a pixel, [param across] wide and as tall as its
## proportions make it, in linear light.
static func _scaled(image: Image, across: int) -> Image:
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
	return scaled


## Each stud of [param scaled] matched to [param palette], the error carried
## on when [param dither]. A hole for a clear pixel.
static func _matched(scaled: Image, palette: PackedInt32Array, library: PartLibrary,
		dither: bool) -> Array[Pixel]:
	var pixels: Array[Pixel] = []
	if palette.is_empty():
		return pixels
	var across: int = scaled.get_width()
	var down: int = scaled.get_height()

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
