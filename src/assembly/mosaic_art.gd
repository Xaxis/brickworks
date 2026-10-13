## A picture laid as a modern LEGO Art set lays one.
##
## The classic mosaic (Mosaic) is a 1 x 1 plate a pixel. An Art set — 31212
## The Milky Way, 31208 The Great Wave, 31213 Mona Lisa — is built on the
## same 16 x 16 panels, but each part of the picture is laid in the element
## that draws it best, which is what makes it read as a picture rather than
## a grid:
##
##   flat areas in square tiles, merged into 1 x 2 up to 2 x 4 where a run of
##   them is one colour;
##   texture in 1 x 1 round tiles, the theme's signature;
##   a contour running on the diagonal in quarter-circle tiles, each turned
##   so its curve faces across the edge — a staircase becomes a curve;
##   stars in round tiles set a plate proud, in trans-clear, glow-in-the-dark
##   or metallic where the part is made so, and fainter points in round
##   plates whose stud stands proud;
##   and what stands out from the background raised on stacked plates, with
##   cheese slopes on the way down, as the Milky Way's core and the Great
##   Wave's crest are.
##
## Every element's colour is chosen only from those it is really made in
## (PartInfo.never_made_in): a quarter-circle tile is not made in Light Grey,
## so a quarter circle is never Light Grey.
##
## The panels are 16 x 16 plates joined underneath by 2 x 4 plates across
## every seam, so the whole picture is one piece and every element sits on
## studs.
##
## Two halves. [method read] works out a [Plan] from the picture — what each
## stud is (its style), how high it stands, whether it may take an accent —
## and [method lay] turns any plan into parts. The plan is the seam for the
## assistant: Claude draws the regions, relief and accents as an ArtPlan,
## which comes here as a [Guide] that [method read] keeps to wherever it
## says something and reads the picture wherever it does not.
class_name MosaicArt
extends RefCounted

## Studs a panel is across and down, as every LEGO Art panel is.
const PANEL := 16
## Panels across or down, at most: 96 studs, the classic mosaic's widest.
const MOST_PANELS := 6
## Plates the most important part may stand above the rest.
const MOST_DEPTH := 6

const BASE := "91405"       ## Plate 16 x 16, one a panel
const JOINER := "3020"      ## Plate 2 x 4, across a seam underneath
const ROUND := "98138"      ## Tile 1 x 1 Round
const SQUARE := "3070b"     ## Tile 1 x 1
const QUARTER := "25269"    ## Tile 1 x 1 Corner Round, a quarter circle
const SPECK := "6141"       ## Plate 1 x 1 Round, its stud proud
const SLOPE := "54200"      ## Slope 30 1 x 1 x 2/3, the cheese slope
const RISER := "3024"       ## Plate 1 x 1, under one stud of relief

## What a stud of the picture is. HOLE is a transparent pixel: nothing on
## the panel's studs there.
enum Style { HOLE, ROUND, SQUARE, QUARTER, STAR, SPECK, SLOPE }

## The tiles a flat run merges into, largest first: part, studs along x
## and along z unturned. All are longer along x unturned.
const TILES: Array = [
	["87079", 4, 2], ["26603", 3, 2], ["3068b", 2, 2],
	["2431", 4, 1], ["63864", 3, 1], ["3069b", 2, 1],
]
## The plates relief is stacked in, the same way.
const PLATES: Array = [
	["3034", 8, 2], ["3795", 6, 2], ["3020", 4, 2], ["3021", 3, 2], ["3022", 2, 2],
	["3460", 8, 1], ["3666", 6, 1], ["3710", 4, 1], ["3623", 3, 1], ["3023b", 2, 1],
]

## The solid colours: the classic mosaic's palette without its
## transparent, pearl, metallic and chrome ones, which here are accents.
const SOLID: Array[int] = [15, 71, 7, 72, 0, 4, 5, 27, 2, 10, 1, 9, 14, 25, 70, 28,
	19, 84, 26, 22, 3, 73, 6, 272, 288, 320, 191, 226, 212, 308, 379, 378]
## Finishes a star may take: trans-clear, glow-in-the-dark white, pearl
## white, metallic gold and silver, pearl gold and grey, and the trans
## colours a nebula is made of.
const ACCENTS: Array[int] = [47, 329, 183, 82, 297, 80, 135, 43, 46, 52, 57, 36, 33, 41]
## How strongly an accent is preferred over a solid colour as near: its
## distance is taken as this much of what it is.
const ACCENT_PULL := 0.6

## The quarter turn that points a quarter-circle tile's curve at (x, z).
## Measured off the part's cover (Rounds.lean: at no turn its material
## leans to -x -z, so its curve faces +x +z), and asserted against the
## mesh by mosaic_probe.
const QUARTER_TURN: Dictionary = {
	Vector2i(1, 1): 0, Vector2i(1, -1): 1, Vector2i(-1, -1): 2, Vector2i(-1, 1): 3}
## The quarter turn that puts a cheese slope's high side toward (x, z).
## Unturned it leans to -z.
const SLOPE_TURN: Dictionary = {
	Vector2i(0, -1): 0, Vector2i(-1, 0): 1, Vector2i(0, 1): 2, Vector2i(1, 0): 3}

## How much of its stud a quarter-circle tile covers: a quarter disc of a
## stud's radius. The rest is whatever is under it, which is why that has
## to be the colour across the edge.
const QUARTER_COVER := PI / 4.0

## Thresholds, in Oklab. Mean step to the neighbours below which an area is
## flat; lightness gradient per stud from which a contour is a contour; how
## far off the axes it must run to be a curve rather than a straight edge;
## how much lighter than its neighbours a stud must be to be a star or a
## speck; and how near what a quarter's corner shows must be to what is
## really across the edge.
const FLAT := 0.03
const EDGE := 0.1
const DIAGONAL := 0.4
const STAR_RISE := 0.22
const SPECK_RISE := 0.1
## How far toward a star's colour a neighbour may be and still be its halo.
const HALO_SHARE := 0.6
const SHOWS_NEAR := 0.14
## How near the background's colour a stud is to count as background: never
## raised, never sloped.
const BACKGROUND := 0.1
## The luminance, linear, above which black-point compensation leaves a
## colour alone: a dark grey.
const SHADOW_KNEE := 0.06
## How much more a difference in hue and saturation counts than one in
## lightness when matching (see [method gap]).
const CHROMA_WEIGHT := 1.5

## The plates the top elements stand on: the frame under the panels, then
## the panels.
const SURFACE := 2


## What the person chose.
class Options extends RefCounted:
	var panels_across: int = 3
	## 0 takes it from the picture's proportions.
	var panels_down: int = 0
	## Plates the part that stands out from the background rises; 0 is flat.
	var depth: int = 3
	var round_texture: bool = true
	var contours: bool = true
	var smooth_tiles: bool = true
	var accents: bool = true
	var dither: bool = true


## What each stud of the picture is to be. Cells run across then down,
## x + z * across, the top of the picture at z = 0.
class Plan extends RefCounted:
	var across: int = 0
	var down: int = 0
	## The colour each stud should look, in linear light; alpha under a half
	## is a hole.
	var want: PackedColorArray = PackedColorArray()
	## A Style each.
	var style: PackedByteArray = PackedByteArray()
	## A quarter's curve, or the way a slope rises: a quarter turn.
	var turn: PackedByteArray = PackedByteArray()
	## Plates stacked under the top element.
	var relief: PackedByteArray = PackedByteArray()
	## 1 where an accent finish may be used.
	var accent: PackedByteArray = PackedByteArray()
	## For a quarter, the colour across the edge, which its cut corner shows.
	var across_edge: PackedColorArray = PackedColorArray()
	## A star's finish, a colour code, or -1 to match one to the picture.
	var finish: PackedInt32Array = PackedInt32Array()
	## The colour a stud is laid in whatever the picture says, or -1.
	var fixed: PackedInt32Array = PackedInt32Array()
	## The colours the picture is matched to, or empty for all of them.
	var palette: PackedInt32Array = PackedInt32Array()
	## The panels' colour, or -1 to choose one.
	var base_colour: int = -1

	func cells() -> int:
		return across * down

	func at(x: int, z: int) -> int:
		return x + z * across

	func inside(x: int, z: int) -> bool:
		return x >= 0 and z >= 0 and x < across and z < down

	## A plan of [param a] x [param d] studs with every array sized, every
	## stud a round tile on the panel.
	func sized(a: int, d: int) -> void:
		across = a
		down = d
		style.resize(a * d)
		style.fill(Style.ROUND)
		turn.resize(a * d)
		turn.fill(0)
		relief.resize(a * d)
		relief.fill(0)
		accent.resize(a * d)
		accent.fill(0)
		across_edge.resize(a * d)
		across_edge.fill(Color(0, 0, 0))
		finish.resize(a * d)
		finish.fill(-1)
		fixed.resize(a * d)
		fixed.fill(-1)
		if want.size() != a * d:
			want.resize(a * d)


## What a designer has decided, stud by stud, for [method read] to keep to.
## Made from an ArtPlan (src/assembly/art_plan.gd), which is where Claude's
## regions become studs. Wherever it says nothing, the picture decides.
class Guide extends RefCounted:
	## A Tiling each.
	var texture: PackedByteArray = PackedByteArray()
	## Plates under the top element, or -1 to read it off the picture.
	var relief: PackedInt32Array = PackedInt32Array()
	## 1 where a contour may be laid in quarter circles.
	var contours: PackedByteArray = PackedByteArray()
	## 1 where a point of light in the picture may be a star.
	var stars: PackedByteArray = PackedByteArray()
	## The finish a star found there is laid in, or -1.
	var finish: PackedInt32Array = PackedInt32Array()
	## The one colour a region is laid in, or -1 for the picture's.
	var colour: PackedInt32Array = PackedInt32Array()
	## A star put exactly there, in this finish; -1 for none.
	var point: PackedInt32Array = PackedInt32Array()
	var palette: PackedInt32Array = PackedInt32Array()
	var base_colour: int = -1
	## How high relief read off the picture rises where [member relief]
	## says nothing, or -1 for the options' depth. The options' depth is
	## then the most anything stands, so it can be less than that.
	var depth: int = -1

	## Every stud left to the picture.
	func sized(cells: int) -> void:
		texture.resize(cells)
		texture.fill(Tiling.PICTURE)
		relief.resize(cells)
		relief.fill(-1)
		contours.resize(cells)
		contours.fill(1)
		stars.resize(cells)
		stars.fill(1)
		finish.resize(cells)
		finish.fill(-1)
		colour.resize(cells)
		colour.fill(-1)
		point.resize(cells)
		point.fill(-1)


## What a region's top is laid in: as the picture reads (round where it is
## busy, smooth where it is flat), round tiles, or smooth tiles, whatever it
## looks like.
enum Tiling { PICTURE, ROUND, SMOOTH }


## What a plan came to.
class Art extends RefCounted:
	var placements: Array[Assistant.Placement] = []
	## Per placement, the panel it is built in, from 0 across then down, or
	## -1 for the frame under them all.
	var panel_of: PackedInt32Array = PackedInt32Array()
	var panels: Vector2i = Vector2i.ONE
	var base_colour: int = 0
	var plan: Plan

	## As a model, for the checker and for placing.
	func model(name: String = "Picture") -> Assistant.Model:
		var out := Assistant.Model.new()
		out.name = name
		out.placements = placements
		return out

	## The sub-assembly a placement is put in, so a booklet builds a panel
	## at a time.
	func path_of(index: int) -> String:
		var panel: int = panel_of[index]
		return "Frame#1" if panel < 0 else "Panel %d#1" % (panel + 1)

	## Part id -> how many.
	func counts() -> Dictionary:
		var out: Dictionary = {}
		for placement: Assistant.Placement in placements:
			out[placement.part] = int(out.get(placement.part, 0)) + 1
		return out

	## How many of each kind of element, in words, most first: what a person
	## wants to know before building.
	func by_element() -> Array:
		var tally: Dictionary = {}
		for index: int in placements.size():
			var words: String = MosaicArt.kind_of(placements[index], panel_of[index])
			tally[words] = int(tally.get(words, 0)) + 1
		var out: Array = []
		for words: String in tally:
			out.append([words, int(tally[words])])
		out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
		return out


## What a placement is, in the words a person would count it in.
static func kind_of(placement: Assistant.Placement, panel: int) -> String:
	if panel < 0:
		return "joining plates"
	match placement.part:
		BASE:
			return "16 × 16 panels"
		ROUND:
			return "stars" if ACCENTS.has(placement.color) else "round tiles"
		SQUARE:
			return "square tiles"
		QUARTER:
			return "quarter circles"
		SPECK:
			return "round plates"
		SLOPE:
			return "cheese slopes"
	for shape: Array in TILES:
		if placement.part == str(shape[0]):
			return "larger tiles"
	return "relief plates"


## How many panels a picture comes to.
static func size_for(image: Image, options: Options) -> Vector2i:
	var across: int = clampi(options.panels_across, 1, MOST_PANELS)
	var down: int = options.panels_down
	if down <= 0 and image != null and not image.is_empty():
		down = roundi(float(across) * image.get_height() / image.get_width())
	return Vector2i(across, clampi(down, 1, MOST_PANELS))


## The whole of it: the picture read, then laid.
static func make(image: Image, options: Options, library: PartLibrary) -> Art:
	return lay(analyse(image, options, library), options, library)


## The picture as a plan, every stud's style, relief and accents worked out
## from it, keeping to [param guide] wherever it says something. A guide
## must be the size the panels come to.
static func analyse(image: Image, options: Options, library: PartLibrary,
		guide: Guide = null) -> Plan:
	var plan := Plan.new()
	if image == null or image.is_empty():
		return plan
	var panels: Vector2i = size_for(image, options)
	plan.want = picture_cells(image, panels.x * PANEL, panels.y * PANEL)
	black_point(plan.want, library)
	plan.sized(panels.x * PANEL, panels.y * PANEL)
	if guide != null and guide.texture.size() != plan.cells():
		push_warning("an Art guide of %d studs for a picture of %d, left out"
			% [guide.texture.size(), plan.cells()])
		guide = null
	if guide != null:
		plan.palette = guide.palette
		plan.base_colour = guide.base_colour
		# A region in one colour is that colour to everything that reads
		# the picture after this, so it is flat and its edge is an edge.
		for i: int in plan.cells():
			var code: int = guide.colour[i]
			var colour: PartLibrary.BrickColor = library.color(code) if code >= 0 else null
			if colour == null:
				continue
			plan.fixed[i] = code
			plan.want[i] = Color(Mosaic._linear(colour.rgb.r), Mosaic._linear(colour.rgb.g),
				Mosaic._linear(colour.rgb.b), plan.want[i].a)
	read(plan, options, library, guide)
	return plan


## The picture cut to the panels' proportions and sampled a stud each, in
## linear light. Cropped rather than squashed, as a printed canvas is.
static func picture_cells(image: Image, across: int, down: int) -> PackedColorArray:
	var source: Image = image.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	var w: int = source.get_width()
	var h: int = source.get_height()
	var aspect: float = float(across) / float(down)
	var crop := Rect2i(0, 0, w, h)
	if float(w) / float(h) > aspect:
		var cut: int = clampi(roundi(h * aspect), 1, w)
		crop = Rect2i((w - cut) / 2, 0, cut, h)
	else:
		var cut: int = clampi(roundi(w / aspect), 1, h)
		crop = Rect2i(0, (h - cut) / 2, w, cut)
	var scaled: Image = source.get_region(crop)
	# Linear before resizing, for the reason the classic mosaic gives.
	scaled.srgb_to_linear()
	scaled.convert(Image.FORMAT_RGBAF)
	scaled.resize(across, down, Image.INTERPOLATE_LANCZOS)
	var out := PackedColorArray()
	out.resize(across * down)
	for z: int in down:
		for x: int in across:
			# Lanczos rings past the range at a hard edge.
			var c: Color = scaled.get_pixel(x, z)
			out[x + z * across] = Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0),
				clampf(c.b, 0.0, 1.0), c.a)
	return out


## The picture's black taken to LEGO Black (black-point compensation, in
## the shadows only). Black plastic is a dark slate, lighter than a
## photograph's black, so a night sky matched as it is sits between Black
## and Dark Brown, as near the one as the other, and came out half brown.
## Here the darkest of the picture becomes Black, fading to no change at all
## by a dark grey, so a colour the palette has is still that colour.
static func black_point(want: PackedColorArray, library: PartLibrary) -> void:
	var black: PartLibrary.BrickColor = library.color(0)
	if black == null:
		return
	var floor_ := Color(Mosaic._linear(black.rgb.r), Mosaic._linear(black.rgb.g),
		Mosaic._linear(black.rgb.b))
	for i: int in want.size():
		var c: Color = want[i]
		var light: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		var lift: float = pow(clampf(1.0 - light / SHADOW_KNEE, 0.0, 1.0), 2.0)
		want[i] = Color(c.r + floor_.r * lift, c.g + floor_.g * lift, c.b + floor_.b * lift, c.a)


## Fill in a plan's styles, relief and accents from its picture, keeping to
## [param guide] where it says something.
static func read(plan: Plan, options: Options, library: PartLibrary,
		guide: Guide = null) -> void:
	var n: int = plan.cells()
	var lab := PackedVector3Array()
	lab.resize(n)
	var hole := PackedByteArray()
	hole.resize(n)
	for i: int in n:
		var c: Color = plan.want[i]
		hole[i] = 1 if c.a < 0.5 else 0
		lab[i] = Mosaic._oklab_linear(c.r, c.g, c.b)
	if plan.base_colour < 0:
		plan.base_colour = base_for(plan, library)
	var base_lab: Vector3 = _lab_of(library, plan.base_colour)

	var star: PackedByteArray = _stars(plan, lab, hole)
	if guide != null:
		for i: int in n:
			if guide.stars[i] == 0:
				star[i] = 0
			if guide.point[i] >= 0 and hole[i] == 0:
				star[i] = 1
	_calm(plan, lab, hole, star)
	var ground: Vector3 = _ground(plan, lab, hole)
	var depth: int = options.depth if guide == null or guide.depth < 0 else guide.depth
	_relief(plan, lab, hole, clampi(depth, 0, MOST_DEPTH), ground)
	if guide != null:
		for i: int in n:
			if guide.relief[i] >= 0 and hole[i] == 0:
				plan.relief[i] = clampi(guide.relief[i], 0, MOST_DEPTH)
	# The ground the slopes are read off, before any star is lifted: a star
	# set proud is not a hill to slope up to.
	var terrain: PackedByteArray = plan.relief.duplicate()
	const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
		Vector2i(0, -1)]

	for z: int in plan.down:
		for x: int in plan.across:
			var i: int = plan.at(x, z)
			if hole[i] == 1:
				plan.style[i] = Style.HOLE
				continue
			var texture: int = Tiling.PICTURE if guide == null else guide.texture[i]
			var style: int = Style.ROUND if options.round_texture else Style.SQUARE
			if texture == Tiling.ROUND:
				style = Style.ROUND
			elif texture == Tiling.SMOOTH:
				style = Style.SQUARE
			var light: float = lab[i].x
			var steps: float = 0.0
			var lightest: float = -INF
			var mean: float = 0.0
			var count: int = 0
			for dz: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if (dx == 0 and dz == 0) or not plan.inside(x + dx, z + dz):
						continue
					var j: int = plan.at(x + dx, z + dz)
					# A star is a point on the sky, not a sign the sky is busy.
					if hole[j] == 1 or star[j] == 1:
						continue
					steps += lab[i].distance_to(lab[j])
					mean += lab[j].x
					lightest = maxf(lightest, lab[j].x)
					count += 1
			if count > 0:
				mean /= count
				if options.smooth_tiles and steps / count < FLAT and texture == Tiling.PICTURE:
					style = Style.SQUARE

			if options.contours and (guide == null or guide.contours[i] == 1):
				var g: Vector2 = _gradient(plan, lab, hole, x, z)
				var big: float = maxf(absf(g.x), absf(g.y))
				if g.length() > EDGE and minf(absf(g.x), absf(g.y)) > DIAGONAL * big:
					var lighter := Vector2i(int(signf(g.x)), int(signf(g.y)))
					var facing: Vector2i = _facing(plan, lab, hole, x, z, lighter)
					if facing != Vector2i.ZERO:
						var other: int = plan.at(x + facing.x, z + facing.y)
						# On the panel its cut corner shows the panel; raised, the
						# plate under it, which is laid in the far side's colour.
						var shows: Vector3 = base_lab if terrain[i] == 0 else lab[other]
						# And on the subject's side of the edge, curve out, as a set
						# rounds the edge of a wave or an arm rather than of the sky.
						if lab[other].distance_to(shows) < SHOWS_NEAR \
								and lab[i].distance_to(ground) > lab[other].distance_to(ground):
							style = Style.QUARTER
							plan.turn[i] = int(QUARTER_TURN[facing])
							plan.across_edge[i] = plan.want[other]

			if star[i] == 1:
				style = Style.STAR
				plan.accent[i] = 1 if options.accents else 0
				if guide != null:
					plan.finish[i] = guide.point[i] if guide.point[i] >= 0 else guide.finish[i]
			elif count >= 3 and light >= lightest and light - mean > SPECK_RISE \
					and options.round_texture and texture != Tiling.SMOOTH:
				style = Style.SPECK

			# Sloped up to what is higher, except the background. Told its
			# height, a stud told 0 is background and one raised is not.
			var sloping: bool = lab[i].distance_to(ground) >= BACKGROUND
			if guide != null and guide.relief[i] >= 0:
				sloping = guide.relief[i] > 0
			if style != Style.STAR and options.depth > 0 and sloping:
				var up := Vector2i.ZERO
				var most: int = terrain[i]
				for side: Vector2i in SIDES:
					if not plan.inside(x + side.x, z + side.y):
						continue
					var j: int = plan.at(x + side.x, z + side.y)
					if hole[j] == 0 and terrain[j] > most:
						most = terrain[j]
						up = side
				if up != Vector2i.ZERO:
					style = Style.SLOPE
					plan.turn[i] = int(SLOPE_TURN[up])
			plan.style[i] = style

	# Stars set a plate proud of what they are in.
	if options.depth > 0:
		for i: int in n:
			if plan.style[i] == Style.STAR:
				plan.relief[i] = mini(plan.relief[i] + 1, MOST_DEPTH + 1)


## The stars: studs lighter than every neighbour, by STAR_RISE over their
## mean, and light. 1 each.
static func _stars(plan: Plan, lab: PackedVector3Array, hole: PackedByteArray) -> PackedByteArray:
	var star := PackedByteArray()
	star.resize(plan.cells())
	for z: int in plan.down:
		for x: int in plan.across:
			var i: int = plan.at(x, z)
			if hole[i] == 1 or lab[i].x <= 0.6:
				continue
			var lightest: float = -INF
			var mean: float = 0.0
			var count: int = 0
			for dz: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if (dx == 0 and dz == 0) or not plan.inside(x + dx, z + dz):
						continue
					var j: int = plan.at(x + dx, z + dz)
					if hole[j] == 0:
						lightest = maxf(lightest, lab[j].x)
						mean += lab[j].x
						count += 1
			if count >= 3 and lab[i].x >= lightest and lab[i].x - mean / count > STAR_RISE:
				star[i] = 1
	return star


## The glow round each star taken back to the sky it is on. A photograph's
## star is a point and a soft halo; dithered, the halo became a cross of
## grey round tiles round every star, which read as a fault. A set has one
## bright element on a calm ground, so a neighbour lit by the star — lighter
## than the sky two studs out, and nearer it than the star is — takes that
## sky's colour.
static func _calm(plan: Plan, lab: PackedVector3Array, hole: PackedByteArray,
		star: PackedByteArray) -> void:
	for z: int in plan.down:
		for x: int in plan.across:
			var i: int = plan.at(x, z)
			if star[i] == 0:
				continue
			# The sky: the ring two studs out, its middle by lightness.
			var ring: Array[int] = []
			for dz: int in range(-2, 3):
				for dx: int in range(-2, 3):
					if maxi(absi(dx), absi(dz)) == 2 and plan.inside(x + dx, z + dz):
						var j: int = plan.at(x + dx, z + dz)
						if hole[j] == 0 and star[j] == 0:
							ring.append(j)
			if ring.size() < 4:
				continue
			ring.sort_custom(func(a: int, b: int) -> bool: return lab[a].x < lab[b].x)
			var sky: int = ring[ring.size() / 2]
			var reach: float = lab[i].distance_to(lab[sky]) * HALO_SHARE
			for dz: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if (dx == 0 and dz == 0) or not plan.inside(x + dx, z + dz):
						continue
					var j: int = plan.at(x + dx, z + dz)
					if hole[j] == 1 or star[j] == 1:
						continue
					if lab[j].x > lab[sky].x and lab[j].distance_to(lab[sky]) < reach:
						plan.want[j] = plan.want[sky]
						lab[j] = lab[sky]


## Which way a quarter circle on a contour faces: across the edge, away from
## the side the stud belongs to. ZERO where there is no other side.
static func _facing(plan: Plan, lab: PackedVector3Array, hole: PackedByteArray,
		x: int, z: int, lighter: Vector2i) -> Vector2i:
	if not plan.inside(x + lighter.x, z + lighter.y) \
			or not plan.inside(x - lighter.x, z - lighter.y):
		return Vector2i.ZERO
	var bright: int = plan.at(x + lighter.x, z + lighter.y)
	var dark: int = plan.at(x - lighter.x, z - lighter.y)
	if hole[bright] == 1 or hole[dark] == 1:
		return Vector2i.ZERO
	var light: float = lab[plan.at(x, z)].x
	var on_bright: bool = absf(light - lab[bright].x) < absf(light - lab[dark].x)
	return -lighter if on_bright else lighter


## The lightness gradient at a stud, Sobel, per stud: toward the lighter.
static func _gradient(plan: Plan, lab: PackedVector3Array, hole: PackedByteArray,
		x: int, z: int) -> Vector2:
	var here: float = lab[plan.at(x, z)].x
	var l: Array[float] = []
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var nx: int = x + dx
			var nz: int = z + dz
			var value: float = here
			if plan.inside(nx, nz) and hole[plan.at(nx, nz)] == 0:
				value = lab[plan.at(nx, nz)].x
			l.append(value)
	var gx: float = ((l[2] + 2.0 * l[5] + l[8]) - (l[0] + 2.0 * l[3] + l[6])) / 8.0
	var gz: float = ((l[6] + 2.0 * l[7] + l[8]) - (l[0] + 2.0 * l[1] + l[2])) / 8.0
	return Vector2(gx, gz)


## The background's colour: the middle of what is round the picture's edge,
## channel by channel. What the subject stands out from.
static func _ground(plan: Plan, lab: PackedVector3Array, hole: PackedByteArray) -> Vector3:
	var okl := PackedFloat32Array()
	var oka := PackedFloat32Array()
	var okb := PackedFloat32Array()
	for z: int in plan.down:
		for x: int in plan.across:
			if x != 0 and z != 0 and x != plan.across - 1 and z != plan.down - 1:
				continue
			var i: int = plan.at(x, z)
			if hole[i] == 1:
				continue
			okl.append(lab[i].x)
			oka.append(lab[i].y)
			okb.append(lab[i].z)
	if okl.is_empty():
		return Vector3(-1, 0, 0)
	okl.sort()
	oka.sort()
	okb.sort()
	var middle: int = okl.size() / 2
	return Vector3(okl[middle], oka[middle], okb[middle])


## How high each stud stands: by how far it is from the background,
## blurred into terraces a few studs across, from nothing at the background
## to [param depth] at what stands out most. The background itself is never
## raised, so the subject's edge is a clean step, as a set's is. A flat
## picture stands flat.
static func _relief(plan: Plan, lab: PackedVector3Array, hole: PackedByteArray,
		depth: int, ground: Vector3) -> void:
	plan.relief.fill(0)
	if depth <= 0:
		return
	var stand := PackedFloat32Array()
	stand.resize(plan.cells())
	for i: int in plan.cells():
		stand[i] = 0.0 if hole[i] == 1 else lab[i].distance_to(ground)
	var radius: int = maxi(1, plan.across / 24)
	stand = _blur(_blur(stand, plan.across, plan.down, radius), plan.across, plan.down, radius)

	var values := PackedFloat32Array()
	for i: int in plan.cells():
		if hole[i] == 0:
			values.append(stand[i])
	values.sort()
	var lo: float = values[values.size() / 4] + 0.02
	var hi: float = values[(values.size() - 1) * 99 / 100]
	if hi - lo < 0.04:
		return
	for i: int in plan.cells():
		if hole[i] == 1 or lab[i].distance_to(ground) < BACKGROUND:
			continue
		var t: float = clampf((stand[i] - lo) / (hi - lo), 0.0, 1.0)
		plan.relief[i] = roundi(pow(t, 1.25) * depth)


## A box blur, across then down.
static func _blur(values: PackedFloat32Array, across: int, down: int,
		radius: int) -> PackedFloat32Array:
	var once := PackedFloat32Array()
	once.resize(values.size())
	for z: int in down:
		for x: int in across:
			var sum: float = 0.0
			var count: int = 0
			for dx: int in range(-radius, radius + 1):
				var nx: int = x + dx
				if nx >= 0 and nx < across:
					sum += values[nx + z * across]
					count += 1
			once[x + z * across] = sum / count
	var out := PackedFloat32Array()
	out.resize(values.size())
	for z: int in down:
		for x: int in across:
			var sum: float = 0.0
			var count: int = 0
			for dz: int in range(-radius, radius + 1):
				var nz: int = z + dz
				if nz >= 0 and nz < down:
					sum += once[x + nz * across]
					count += 1
			out[x + z * across] = sum / count
	return out


## The panels' colour: whichever colour a 16 x 16 plate is made in the most
## of the picture comes nearest, since it shows between round tiles and at
## every quarter circle's cut corner.
static func base_for(plan: Plan, library: PartLibrary) -> int:
	var palette: PackedInt32Array = colours_for(library, BASE, _among(plan, SOLID, library, BASE))
	if palette.is_empty():
		return 0
	var labs: Array[Vector3] = []
	for code: int in palette:
		labs.append(_lab_of(library, code))
	var votes: Dictionary = {}
	for i: int in plan.cells():
		var c: Color = plan.want[i]
		if c.a < 0.5:
			continue
		var here: Vector3 = Mosaic._oklab_linear(c.r, c.g, c.b)
		var best: int = 0
		for k: int in labs.size():
			if gap(here, labs[k]) < gap(here, labs[best]):
				best = k
		votes[palette[best]] = int(votes.get(palette[best], 0)) + 1
	var most: int = palette[0]
	for code: int in votes:
		if int(votes[code]) > int(votes.get(most, 0)):
			most = code
	return most


## [param among] cut to the plan's palette, where that leaves [param part]
## a colour to be; otherwise all of it.
static func _among(plan: Plan, among: Array[int], library: PartLibrary,
		part: String) -> Array[int]:
	if plan.palette.is_empty():
		return among
	var kept: Array[int] = []
	for code: int in among:
		if plan.palette.has(code):
			kept.append(code)
	return kept if not colours_for(library, part, kept).is_empty() else among


static func _made_in(library: PartLibrary, part: String, code: int) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(part)
	return info != null and library.color(code) != null and not info.never_made_in(code)


## The colours among [param among] that [param part] is not known never to
## have been made in.
static func colours_for(library: PartLibrary, part: String, among: Array[int]) -> PackedInt32Array:
	var out := PackedInt32Array()
	var info: PartLibrary.PartInfo = library.parts.get(part)
	if info == null:
		return out
	for code: int in among:
		if library.color(code) != null and not info.never_made_in(code):
			out.append(code)
	return out


static func _lab_of(library: PartLibrary, code: int) -> Vector3:
	var colour: PartLibrary.BrickColor = library.color(code)
	return Mosaic._oklab(colour.rgb if colour != null else Color.MAGENTA)


## The part a style is laid in. A star is a round tile on a plate when
## there is relief to stand it on, and a round plate, stud proud, when flat.
static func part_for(style: int, flat: bool) -> String:
	match style:
		Style.ROUND:
			return ROUND
		Style.SQUARE:
			return SQUARE
		Style.QUARTER:
			return QUARTER
		Style.STAR:
			return SPECK if flat else ROUND
		Style.SPECK:
			return SPECK
		Style.SLOPE:
			return SLOPE
	return ""


## Lay a plan in parts.
static func lay(plan: Plan, options: Options, library: PartLibrary) -> Art:
	var art := Art.new()
	art.plan = plan
	var n: int = plan.cells()
	if n == 0:
		return art
	art.panels = Vector2i(ceili(plan.across / float(PANEL)), ceili(plan.down / float(PANEL)))
	if plan.base_colour < 0:
		plan.base_colour = base_for(plan, library)
	art.base_colour = plan.base_colour
	var flat: bool = options.depth <= 0

	var labs: Dictionary = {}
	for code: int in SOLID + ACCENTS + [plan.base_colour]:
		labs[code] = _lab_of(library, code)
	var palettes: Dictionary = {}

	# What the plates of relief are laid in: the region's colour, matched
	# without dither to a softened picture, so a run of them is one colour
	# and merges into long plates. Their sides are seen from an angle.
	var risers: PackedInt32Array = colours_for(library, RISER, _among(plan, SOLID, library, RISER))
	var region := PackedInt32Array()
	region.resize(n)
	for z: int in plan.down:
		for x: int in plan.across:
			var sum := Color(0, 0, 0, 0)
			var count: int = 0
			for dz: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if plan.inside(x + dx, z + dz) and plan.want[plan.at(x + dx, z + dz)].a >= 0.5:
						sum += plan.want[plan.at(x + dx, z + dz)]
						count += 1
			region[plan.at(x, z)] = _nearest(sum / maxf(count, 1.0), risers, labs, false)
	var under: PackedInt32Array = region.duplicate()

	# The top colours, each from what its element is made in, the error
	# carried on as the classic mosaic carries it.
	var buffer: PackedColorArray = plan.want.duplicate()
	var colour := PackedInt32Array()
	colour.resize(n)
	colour.fill(-1)
	for z: int in plan.down:
		for x: int in plan.across:
			var i: int = plan.at(x, z)
			var style: int = plan.style[i]
			if style == Style.HOLE:
				continue
			var part: String = part_for(style, flat)
			var accented: bool = style == Style.STAR and plan.accent[i] == 1 and options.accents
			var key: String = part + ("+" if accented else "")
			if not palettes.has(key):
				var among: Array[int] = []
				among.append_array(SOLID)
				if accented:
					among.append_array(ACCENTS)
				palettes[key] = colours_for(library, part, _among(plan, among, library, part))
			var choices: PackedInt32Array = palettes[key]
			# Said outright: a region's one colour, or a star's finish,
			# where the part is made in it. Nothing to make up for after.
			var told: int = plan.fixed[i]
			if style == Style.STAR and accented and plan.finish[i] >= 0:
				told = plan.finish[i]
			if told >= 0 and not _made_in(library, part, told):
				told = -1
			var target: Color = buffer[i]
			var cover: float = 1.0
			var shows := Color(0, 0, 0)
			if style == Style.QUARTER:
				var shown: int = plan.base_colour
				if plan.relief[i] > 0:
					shown = _nearest(plan.across_edge[i], risers, labs, false)
					under[i] = shown
				shows = Mosaic._from_oklab(labs.get(shown, _lab_of(library, shown)))
				cover = QUARTER_COVER
				# What the tile itself has to be for tile and corner together
				# to look like the stud.
				target = Color(
					clampf((target.r - shows.r * (1.0 - cover)) / cover, 0.0, 1.0),
					clampf((target.g - shows.g * (1.0 - cover)) / cover, 0.0, 1.0),
					clampf((target.b - shows.b * (1.0 - cover)) / cover, 0.0, 1.0))
			var pick: int = told if told >= 0 else _nearest(target, choices, labs, accented)
			if pick < 0:
				continue
			colour[i] = pick
			# A star is a point of light in a finish, not a colour to make up
			# for in the sky round it.
			if options.dither and style != Style.STAR and told < 0:
				var made: Color = Mosaic._from_oklab(labs[pick])
				var seen: Color = made * cover + shows * (1.0 - cover)
				_spread(buffer, plan, x, z, buffer[i] - seen)

	_frame(art, library)
	for row: int in art.panels.y:
		for column: int in art.panels.x:
			_add(art, BASE, art.base_colour, column * PANEL, SURFACE - 1, row * PANEL, 0,
				column + row * art.panels.x)

	# Relief, a layer at a time, each plate on the layer below.
	var highest: int = 0
	for i: int in n:
		highest = maxi(highest, plan.relief[i])
	for layer: int in highest:
		var codes := PackedInt32Array()
		codes.resize(n)
		codes.fill(-1)
		for i: int in n:
			if plan.style[i] != Style.HOLE and plan.relief[i] > layer:
				codes[i] = under[i] if layer == plan.relief[i] - 1 else region[i]
		_cover(art, plan, codes, PLATES, RISER, SURFACE + layer, library, layer % 2 == 0)

	# Flat runs merged into the largest tiles they fill, level by level.
	for level: int in highest + 1:
		var codes := PackedInt32Array()
		codes.resize(n)
		codes.fill(-1)
		var any: bool = false
		for i: int in n:
			if plan.style[i] == Style.SQUARE and plan.relief[i] == level and colour[i] >= 0:
				codes[i] = colour[i]
				any = true
		if not any:
			continue
		if options.smooth_tiles:
			_courses(art, plan, codes, SURFACE + level, library)
		else:
			_cover(art, plan, codes, [], SQUARE, SURFACE + level, library, true)

	for z: int in plan.down:
		for x: int in plan.across:
			var i: int = plan.at(x, z)
			var style: int = plan.style[i]
			if style == Style.HOLE or style == Style.SQUARE or colour[i] < 0:
				continue
			var turn: int = plan.turn[i] if style == Style.QUARTER or style == Style.SLOPE else 0
			_add(art, part_for(style, flat), colour[i], x, SURFACE + plan.relief[i], z, turn,
				x / PANEL + (z / PANEL) * art.panels.x)
	return art


## The plates under the panels: two across every seam, which is what holds
## the picture together, and one under the middle of every outside edge,
## so each panel stands level.
static func _frame(art: Art, library: PartLibrary) -> void:
	var tone: int = art.base_colour
	var info: PartLibrary.PartInfo = library.parts.get(JOINER)
	if info != null and info.never_made_in(tone):
		tone = 0
	for row: int in art.panels.y:
		for column: int in art.panels.x:
			var x0: int = column * PANEL
			var z0: int = row * PANEL
			if column < art.panels.x - 1:
				for along: int in [3, 11]:
					_add(art, JOINER, tone, x0 + PANEL - 2, 0, z0 + along, 0, -1)
			if row < art.panels.y - 1:
				for along: int in [3, 11]:
					_add(art, JOINER, tone, x0 + along, 0, z0 + PANEL - 2, 1, -1)
			if column == 0:
				_add(art, JOINER, tone, x0, 0, z0 + 6, 0, -1)
			if column == art.panels.x - 1:
				_add(art, JOINER, tone, x0 + PANEL - 4, 0, z0 + 6, 0, -1)
			if row == 0:
				_add(art, JOINER, tone, x0 + 6, 0, z0, 1, -1)
			if row == art.panels.y - 1:
				_add(art, JOINER, tone, x0 + 6, 0, z0 + PANEL - 4, 1, -1)


## The tiles a row of a course is laid in, longest first, all along x.
const ROW_TILES: Array = [["2431", 4], ["63864", 3], ["3069b", 2], [SQUARE, 1]]
## Two rows of a course at once.
const COURSE_TILE := "87079"


## Flat areas laid in courses, as a set lays a large flat area: 2 x 4 tiles
## all running across, two rows to a course, each course's joints two studs
## along from the last, like brickwork. Where a course is not two rows of
## one colour the same joints are kept row by row, in 1 x 4 down to 1 x 1.
## A greedy fit of the largest tile each run would take came first: its mix
## of 1 x 1, 1 x 2, 2 x 2 and 2 x 4 every which way read as noise across a
## whole sky.
static func _courses(art: Art, plan: Plan, codes: PackedInt32Array, y: int,
		library: PartLibrary) -> void:
	var taken := PackedByteArray()
	taken.resize(codes.size())
	var wide: PartLibrary.PartInfo = library.parts.get(COURSE_TILE)
	for row: int in art.panels.y:
		for column: int in art.panels.x:
			var x0: int = column * PANEL
			var z0: int = row * PANEL
			var right: int = mini(x0 + PANEL, plan.across)
			var bottom: int = mini(z0 + PANEL, plan.down)
			var panel: int = column + row * art.panels.x
			for course: int in range((bottom - z0 + 1) / 2):
				var za: int = z0 + course * 2
				var zb: int = za + 1
				var start: int = x0 - 2 if course % 2 == 1 else x0
				for slot: int in range(start, right, 4):
					var lo: int = maxi(slot, x0)
					var hi: int = mini(slot + 4, right)
					var code: int = codes[plan.at(lo, za)]
					if hi - lo == 4 and zb < bottom and code >= 0 and wide != null \
							and not wide.never_made_in(code) \
							and _run_of(plan, codes, taken, lo, hi, za, code) \
							and _run_of(plan, codes, taken, lo, hi, zb, code):
						for z: int in [za, zb]:
							for x: int in range(lo, hi):
								taken[plan.at(x, z)] = 1
						_add(art, COURSE_TILE, code, lo, y, za, 0, panel)
						continue
					for z: int in [za, zb]:
						if z < bottom:
							_row(art, plan, codes, taken, lo, hi, z, y, library, panel)


## Whether studs [param lo] to [param hi] of row [param z] are all
## [param code] and free.
static func _run_of(plan: Plan, codes: PackedInt32Array, taken: PackedByteArray,
		lo: int, hi: int, z: int, code: int) -> bool:
	for x: int in range(lo, hi):
		var i: int = plan.at(x, z)
		if codes[i] != code or taken[i] == 1:
			return false
	return true


## One row of one slot of a course: each run of a colour in the longest tiles
## it takes, along x.
static func _row(art: Art, plan: Plan, codes: PackedInt32Array, taken: PackedByteArray,
		lo: int, hi: int, z: int, y: int, library: PartLibrary, panel: int) -> void:
	var x: int = lo
	while x < hi:
		var i: int = plan.at(x, z)
		var code: int = codes[i]
		if code < 0 or taken[i] == 1:
			x += 1
			continue
		var end: int = x
		while end < hi and codes[plan.at(end, z)] == code and taken[plan.at(end, z)] == 0:
			end += 1
		while x < end:
			for tile: Array in ROW_TILES:
				var length: int = int(tile[1])
				var info: PartLibrary.PartInfo = library.parts.get(str(tile[0]))
				if length > end - x or (length > 1 and (info == null or info.never_made_in(code))):
					continue
				for k: int in length:
					taken[plan.at(x + k, z)] = 1
				_add(art, str(tile[0]), code, x, y, z, 0, panel)
				x += length
				break


## Cover the studs given a colour in [param codes] (-1 for none) with the
## largest of [param shapes] each run of one colour fills, inside one panel,
## in a colour the part is made in; what is left in [param single].
## [param along_x_first] tries each shape lying along x before along z, and
## alternating it layer to layer bonds the layers across each other.
static func _cover(art: Art, plan: Plan, codes: PackedInt32Array, shapes: Array,
		single: String, y: int, library: PartLibrary, along_x_first: bool) -> void:
	var taken := PackedByteArray()
	taken.resize(codes.size())
	var turns: Array[int] = [0, 1]
	if not along_x_first:
		turns = [1, 0]
	for z: int in plan.down:
		for x: int in plan.across:
			var i: int = plan.at(x, z)
			if codes[i] < 0 or taken[i] == 1:
				continue
			var code: int = codes[i]
			var panel: int = x / PANEL + (z / PANEL) * art.panels.x
			var right: int = mini((x / PANEL + 1) * PANEL, plan.across)
			var bottom: int = mini((z / PANEL + 1) * PANEL, plan.down)
			var placed: bool = false
			for shape: Array in shapes:
				var part: String = str(shape[0])
				var info: PartLibrary.PartInfo = library.parts.get(part)
				if info == null or info.never_made_in(code):
					continue
				for turn: int in turns:
					var sx: int = int(shape[1]) if turn == 0 else int(shape[2])
					var sz: int = int(shape[2]) if turn == 0 else int(shape[1])
					if (sx == sz and turn == 1) or x + sx > right or z + sz > bottom:
						continue
					var fits: bool = true
					for dz: int in sz:
						for dx: int in sx:
							var j: int = plan.at(x + dx, z + dz)
							if codes[j] != code or taken[j] == 1:
								fits = false
								break
						if not fits:
							break
					if not fits:
						continue
					for dz: int in sz:
						for dx: int in sx:
							taken[plan.at(x + dx, z + dz)] = 1
					_add(art, part, code, x, y, z, turn, panel)
					placed = true
					break
				if placed:
					break
			if not placed:
				taken[i] = 1
				_add(art, single, code, x, y, z, 0, panel)


static func _add(art: Art, part: String, code: int, x: int, y: int, z: int, rot: int,
		panel: int) -> void:
	var placement := Assistant.Placement.new()
	placement.part = part
	placement.color = code
	placement.x = x
	placement.y = y
	placement.z = z
	placement.rot = rot
	art.placements.append(placement)
	art.panel_of.append(panel)


## How different two Oklab colours look, for choosing between the palette's:
## the distance with hue and saturation weighed half again over lightness.
## Plain Oklab distance sends a dim neutral grey — the halo round a star — to
## Reddish Brown, which is nearer in lightness than Black or Dark Bluish Grey
## and wrong in hue; a wrong hue is what the eye catches.
static func gap(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = a - b
	return sqrt(d.x * d.x + CHROMA_WEIGHT * CHROMA_WEIGHT * (d.y * d.y + d.z * d.z))


## The nearest of [param choices] in Oklab, an accent taken over a solid
## colour nearly as near when [param accented]. -1 when there is no choice.
static func _nearest(want: Color, choices: PackedInt32Array, labs: Dictionary,
		accented: bool) -> int:
	var here: Vector3 = Mosaic._oklab_linear(want.r, want.g, want.b)
	var best: int = -1
	var best_gap: float = INF
	for code: int in choices:
		var apart: float = gap(here, labs[code])
		if accented and ACCENTS.has(code):
			apart *= ACCENT_PULL
		if apart < best_gap:
			best_gap = apart
			best = code
	return best


## Floyd–Steinberg over the plan's cells, damped and clamped as the classic
## mosaic's is (Mosaic._spread says why).
static func _spread(buffer: PackedColorArray, plan: Plan, x: int, z: int, error: Color) -> void:
	const NEIGHBOURS: Array[Vector3] = [
		Vector3(1, 0, 7.0 / 16.0),
		Vector3(-1, 1, 3.0 / 16.0),
		Vector3(0, 1, 5.0 / 16.0),
		Vector3(1, 1, 1.0 / 16.0),
	]
	for step: Vector3 in NEIGHBOURS:
		var nx: int = x + int(step.x)
		var nz: int = z + int(step.y)
		if not plan.inside(nx, nz):
			continue
		var j: int = plan.at(nx, nz)
		var was: Color = buffer[j]
		var k: float = step.z * Mosaic.DAMPING
		buffer[j] = Color(clampf(was.r + error.r * k, 0.0, 1.0),
			clampf(was.g + error.g * k, 0.0, 1.0),
			clampf(was.b + error.b * k, 0.0, 1.0), was.a)


## Put an Art into the world as main lays a mosaic: every part through the
## ordinary placement path, each in its panel's sub-assembly (or the
## frame's). The world is not cleared first. The bricks placed, by id.
static func put_down(art: Art, world: BrickWorld, builder: Builder,
		checker: Assistant) -> PackedInt64Array:
	var ids := PackedInt64Array()
	var library: PartLibrary = checker.library
	for index: int in art.placements.size():
		var placement: Assistant.Placement = art.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		var at: Transform3D = checker._transform(placement, part)
		var brick_id: int = world.add_brick(placement.part, placement.color, at)
		if brick_id == 0:
			continue
		# As Builder.set_path puts it, which a script cannot call by its class:
		# a class named in code is its Script, whose own set_path wins.
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		brick.unit = art.path_of(index)
		brick.group = Assemblies.group_of(brick.unit)
		builder.register(brick_id, placement.part, at)
		ids.append(brick_id)
	return ids


## Studs a part covers along x and z at a turn, from the tables here.
static func footprint(part: String, rot: int) -> Vector2i:
	for table: Array in [TILES, PLATES]:
		for shape: Array in table:
			if str(shape[0]) == part:
				var along := Vector2i(int(shape[1]), int(shape[2]))
				return along if rot % 2 == 0 else Vector2i(along.y, along.x)
	if part == BASE:
		return Vector2i(PANEL, PANEL)
	return Vector2i.ONE


## The picture as the finished panels look from the front, [param px] pixels
## a stud: each top element drawn as its shape — round tiles as discs on the
## panel, quarter circles turned as laid, tiles square — and lighter the
## higher it stands. What the dialog shows before anything is built.
static func picture_of(art: Art, library: PartLibrary, px: int = 6) -> Image:
	var plan: Plan = art.plan
	var image := Image.create_empty(maxi(1, plan.across * px), maxi(1, plan.down * px),
		false, Image.FORMAT_RGBA8)
	var base: PartLibrary.BrickColor = library.color(art.base_colour)
	image.fill(base.rgb if base != null else Color.BLACK)
	var r: float = px / 2.0
	for placement: Assistant.Placement in art.placements:
		if placement.y < SURFACE or plan.style.is_empty():
			continue
		var x0: int = int(placement.x)
		var z0: int = int(placement.z)
		var style: int = plan.style[plan.at(x0, z0)]
		# The relief plates are covered by what is on them.
		if style != Style.SQUARE and placement.part != part_for(style, false) \
				and placement.part != part_for(style, true):
			continue
		if style == Style.SQUARE and not (placement.part == SQUARE
				or TILES.any(func(shape: Array) -> bool: return str(shape[0]) == placement.part)):
			continue
		var colour: PartLibrary.BrickColor = library.color(placement.color)
		var tone: Color = colour.rgb if colour != null else Color.MAGENTA
		tone = tone.lightened(0.05 * (int(placement.y) - SURFACE))
		var size: Vector2i = footprint(placement.part, placement.rot)
		var corner := Vector2.ZERO
		if style == Style.QUARTER:
			for facing: Vector2i in QUARTER_TURN:
				if int(QUARTER_TURN[facing]) == placement.rot:
					corner = Vector2(0.0 if facing.x > 0 else px, 0.0 if facing.y > 0 else px)
		for dz: int in size.y * px:
			for dx: int in size.x * px:
				var at := Vector2(dx + 0.5, dz + 0.5)
				var shade: Color = tone
				match style:
					Style.ROUND, Style.STAR, Style.SPECK:
						if at.distance_to(Vector2(r, r)) > r:
							continue
						if style == Style.SPECK and at.distance_to(Vector2(r, r)) < r * 0.55:
							shade = tone.lightened(0.12)
					Style.QUARTER:
						if at.distance_to(corner) > px:
							continue
					Style.SLOPE:
						shade = tone.darkened(0.25 * (1.0 - _rising(placement.rot, at, px)))
				image.set_pixel(x0 * px + dx, z0 * px + dz, shade)
	return image


## How far up a cheese slope a point of its stud is, 0 at the low edge.
static func _rising(rot: int, at: Vector2, px: int) -> float:
	for up: Vector2i in SLOPE_TURN:
		if int(SLOPE_TURN[up]) == rot:
			var t: float = at.x / px if up.x > 0 else (1.0 - at.x / px if up.x < 0
				else (at.y / px if up.y > 0 else 1.0 - at.y / px))
			return clampf(t, 0.0, 1.0)
	return 1.0
