## A design's outline from one side, laid over the real thing's outline from
## the same side, with where they differ said in studs and plates.
##
## design15 to design19 measured likeness as boxes: how much of its box a
## model fills, the masses planned, each feature's share of the whole. The
## sessions kept 9 of 10 differences they were given as numbers, and the
## judge went on saying "squat and wide", "a tall, boxy brick stack", "the
## drum hidden in a boxy frame". A box's share cannot see a silhouette: the
## Burj's tower was 10 studs on 46, a share inside the line, and full width
## for its lowest third. Its trouble was how its width falls with height.
##
## So the session reads the real thing's outline off a photograph of it
## (find_reference) from one side, once: the top's height at each tenth of
## its length, left to right as the photograph shows it, as shares of the
## length; or, for a tall thing, its width at each tenth of its height, as
## shares of the height. The app measures the same off the model from that
## side, drawn at the model's own length (or height), and sets the two side
## by side: a picture of the model's elevation in its colours with the
## outline over it, and each run of tenths that differs by two plates (a
## stud across) or more, in studs and plates.
##
## The model's outline is the lattice's: each part's collision cover, 2 LDU
## cells with its studs taken off (tools/ldraw/occupancy.py), so a slope's
## outline is its slope and a model is read the same headless, in a window
## and in a browser. Nothing here draws on the graphics card.
##
## The session decides what to do with it: nothing is changed for it.
class_name Silhouette
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
## LDU per lattice cell (BrickLattice.CELL).
const CELL := 2.0
## Cells per plate.
const PLATE_CELLS := 4

## The sides a reading can be from, as view_model names them.
const SIDES: Array[String] = ["front", "back", "left", "right"]
## Each side's other: a reading laid the wrong way round is from it.
const ACROSS: Dictionary = {"front": "back", "back": "front", "left": "right",
	"right": "left"}

## The fewest and most samples a reading takes, evenly spaced, both ends in.
const FEWEST := 5
const MOST := 41
## The most a share may be: a long low thing's heights are under 1, a tall
## thing's widths too; read the other way, a tower's height is many lengths.
const LARGEST := 20.0

## Over the line: a height two plates or more off, a width three quarters
## of a stud or more (said rounded to studs). A reading off a photograph is
## good to about a fortieth of the length; two plates on a 30-stud car is
## a 37th, and a stud is the least a width can change by.
const OFF_HEIGHT := 2.0 * PLATE
const OFF_WIDTH := 0.75 * STUD
## Each sample reads the model's outline over this many cells either side
## (a fifth of a stud across, half a plate up), as an eye reads a photograph:
## one cell row through an open frame or past a plate-thin wing read nothing
## there, and the London skyline's lattice read 8 studs narrow at one tenth.
const BAND := 2
## The runs over the line said, largest first.
const RUNS_SAID := 5
## A reading laid the other way round is taken as meant when it fits this
## much better (its total difference this share of the other's or less).
const MIRROR_BETTER := 0.6

## The picture: its longest side at most, px, and the most px a cell.
const PICTURE_MOST := 900
const MOST_PX := 8
const MARGIN := 24
const BACKDROP := Color(0.93, 0.93, 0.91)
const LINE := Color(0.86, 0.05, 0.08)
## Hatched, so a part's own colour still shows between the stripes: orange
## rising where the model stands past the outline, blue falling where the
## outline holds what the model does not.
const PAST := Color(1.0, 0.5, 0.0)
const SHORT := Color(0.1, 0.45, 0.95)
## A stripe every so many px, so wide.
const HATCH_EVERY := 6
const HATCH_WIDE := 2
const TICK := Color(0.25, 0.25, 0.28)


## A model's outline from one side, in lattice cells: column 0 is the left
## of the view as a picture from that side shows it, row 0 the lowest cell
## read. Each column's top and bottom, each row's left and right; and the
## model's elevation in its colours, one pixel a cell, the nearest part in
## front.
class Outline extends RefCounted:
	var side: String = ""
	var cols: int = 0
	var rows: int = 0
	## Column 0's place across the view, in the view's own cells: a column's
	## place in the model is [method model_cell] of it.
	var across_low: int = 0
	## The lowest row read is this many cells over the ground (y = 0).
	var floor_cells: int = 0
	## Per column: the row past its highest filled cell (0 for an empty one),
	## and its lowest filled row (-1 for an empty one).
	var top := PackedInt32Array()
	var bottom := PackedInt32Array()
	## Per row: its leftmost filled column (-1 for an empty one), and the
	## column past its rightmost.
	var left := PackedInt32Array()
	var right := PackedInt32Array()
	var elevation: Image = null

	func is_empty() -> bool:
		return cols <= 0 or rows <= 0

	## Column [param column]'s cell in the model, along x (front, back) or
	## z (left, right).
	func model_cell(column: int) -> int:
		var at: int = column + across_low
		return at if side in ["front", "left"] else -at - 1

	## The model's axis the columns run along.
	func axis() -> String:
		return "x" if side in ["front", "back"] else "z"


## What a session read off its photograph, validated: [member error] says
## what is wrong with it, and nothing else is read then.
class Reading extends RefCounted:
	var side: String = ""
	## "heights" (the top at each sample along the length, shares of the
	## length) or "widths" (the width at each sample up the height, shares
	## of the height).
	var mode: String = ""
	var values := PackedFloat64Array()
	## With heights, the underside at each sample, or empty.
	var bottoms := PackedFloat64Array()
	## Plates up from the ground where the thing starts: a display base or a
	## plinth under it is left out of the model's outline.
	var above: float = 0.0
	## What it was read off, in the session's words.
	var picture: String = ""
	var error: String = ""


## One sample, the model's and the outline's, in LDU from the ground (or
## across, for a width), and where it is.
class Sample extends RefCounted:
	var share: float = 0.0     ## 0 at the left (or the ground), 1 at the right (or the top)
	var cell: int = 0          ## the column (or row) it reads, in the outline's cells
	var model: float = 0.0
	var outline: float = 0.0
	var model_low: float = 0.0     ## the underside, with bottoms
	var outline_low: float = -1.0

	func off() -> float:
		return model - outline

	func off_low() -> float:
		return model_low - outline_low if outline_low >= 0.0 else 0.0


## A reading laid over a model's outline.
class Comparison extends RefCounted:
	var reading: Reading
	var outline: Outline
	## Whether the reading was laid the other way round, as fitting far better.
	var reversed: bool = false
	## The model's length (heights) or height (widths) the outline is drawn at, LDU.
	var span: float = 0.0
	## The first filled column (heights) or row (widths), and the last.
	var first: int = 0
	var last: int = 0
	var samples: Array[Sample] = []
	## The runs over the line: {from, to (sample indexes), which ("top",
	## "underside", "width"), least, most (LDU off, signed)}.
	var runs: Array[Dictionary] = []

	func most_off() -> float:
		var most: float = 0.0
		for one: Sample in samples:
			most = maxf(most, absf(one.off()))
			most = maxf(most, absf(one.off_low()))
		return most


## [param said] as a session gives it to review_model's outline=, checked.
static func read(said: Variant) -> Reading:
	var reading := Reading.new()
	if not said is Dictionary:
		reading.error = ("outline= is an object: {\"from\": \"left\", \"heights\": [...]} or "
			+ "{\"from\": \"front\", \"widths\": [...]}.")
		return reading
	var given: Dictionary = said
	reading.side = str(given.get("from", "")).strip_edges().to_lower()
	if not SIDES.has(reading.side):
		reading.error = ("outline's from= is the side of your model the photograph shows: "
			+ "front, back, left or right (the front is +z).")
		return reading
	var heights: Variant = given.get("heights")
	var widths: Variant = given.get("widths")
	if (heights == null) == (widths == null):
		reading.error = ("Give one of heights= (the top's height at each tenth of its "
			+ "length, as shares of the length) or widths= (its width at each tenth of its "
			+ "height, as shares of the height).")
		return reading
	reading.mode = "heights" if heights != null else "widths"
	var values: Variant = _shares(heights if heights != null else widths, reading.mode)
	if values is String:
		reading.error = values
		return reading
	reading.values = values
	if given.has("bottoms") and given["bottoms"] != null:
		if reading.mode != "heights":
			reading.error = "bottoms= goes with heights=, the underside below each top."
			return reading
		var low: Variant = _shares(given["bottoms"], "bottoms")
		if low is String:
			reading.error = low
			return reading
		if (low as PackedFloat64Array).size() != reading.values.size():
			reading.error = "bottoms= has %d numbers and heights= %d: one each, at the same places." % [
				(low as PackedFloat64Array).size(), reading.values.size()]
			return reading
		for n: int in reading.values.size():
			if (low as PackedFloat64Array)[n] > reading.values[n] + 0.0001:
				reading.error = ("bottoms= is the underside at each place, under its top: "
					+ "number %d is over it." % (n + 1))
				return reading
		reading.bottoms = low
	var above: Variant = given.get("above", 0.0)
	if above == null:
		above = 0.0
	if not (above is float or above is int) or float(above) < 0.0:
		reading.error = "above= is plates up from the ground, 0 or more."
		return reading
	reading.above = float(above)
	reading.picture = str(given.get("picture", "")).strip_edges().left(200)
	return reading


## [param raw] as shares, or why not.
static func _shares(raw: Variant, called: String) -> Variant:
	if not raw is Array:
		return "%s= is a list of numbers, one at each tenth: 11 of them, from one end to the other." % called
	var list: Array = raw
	if list.size() < FEWEST or list.size() > MOST:
		return ("%s= has %d numbers: give %d to %d, evenly spaced from one end to the other, "
			% [called, list.size(), FEWEST, MOST] + "11 for each tenth.")
	var out := PackedFloat64Array()
	for one: Variant in list:
		if not (one is float or one is int):
			return "%s= holds only numbers, shares such as 0.25." % called
		var share: float = float(one)
		if share < 0.0 or share > LARGEST or is_nan(share):
			return "%s= holds shares from 0 to %d, as fractions of the whole: %s is not one." % [
				called, int(LARGEST), str(one)]
		out.append(share)
	return out


## The outline of [param bricks] from [param side], read from [param above]
## plates up: their lattice covers, each part's own as [param builder] works
## it out where the lattice has none.
static func of_bricks(bricks: Array, builder: Builder, library: PartLibrary, side: String,
		above: float = 0.0) -> Outline:
	var outline := Outline.new()
	outline.side = side
	var cut: int = roundi(above * PLATE_CELLS)
	# Each part's boxes in the view's own cells: [col0, col1, row0, row1, near, colour].
	var flat: Array = []
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-(1 << 30), -(1 << 30))
	for raw: Variant in bricks:
		var brick: BrickWorld.Brick = raw
		var packed: PackedInt32Array = builder.lattice.boxes_of(brick.id) \
			if builder.lattice != null else PackedInt32Array()
		if packed.is_empty():
			packed = builder.boxes_for(library.mesh_for(brick.part_id), brick.transform)
		if packed.is_empty():
			continue
		var colour: Color = library.color(brick.color_code).rgb
		for n: int in range(0, packed.size(), 6):
			var y0: int = maxi(packed[n + 1], cut)
			var y1: int = packed[n + 4]
			if y1 <= y0:
				continue
			var across: Vector2i
			var near: int
			match side:
				"front":
					across = Vector2i(packed[n], packed[n + 3])
					near = packed[n + 5]
				"back":
					across = Vector2i(-packed[n + 3], -packed[n])
					near = -packed[n + 2]
				"left":
					across = Vector2i(packed[n + 2], packed[n + 5])
					near = -packed[n]
				_:
					across = Vector2i(-packed[n + 5], -packed[n + 2])
					near = packed[n + 3]
			flat.append([across.x, across.y, y0, y1, near, colour])
			low = low.min(Vector2i(across.x, y0))
			high = high.max(Vector2i(across.y, y1))
	if flat.is_empty():
		return outline
	outline.cols = high.x - low.x
	outline.rows = high.y - low.y
	outline.across_low = low.x
	outline.floor_cells = low.y
	outline.top.resize(outline.cols)
	outline.top.fill(0)
	outline.bottom.resize(outline.cols)
	outline.bottom.fill(-1)
	outline.left.resize(outline.rows)
	outline.left.fill(-1)
	outline.right.resize(outline.rows)
	outline.right.fill(0)
	# Farthest first, so the nearest part is the one the elevation shows.
	flat.sort_custom(func(a: Array, b: Array) -> bool: return int(a[4]) < int(b[4]))
	var image := Image.create_empty(outline.cols, outline.rows, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for box: Array in flat:
		var c0: int = int(box[0]) - low.x
		var c1: int = int(box[1]) - low.x
		var r0: int = int(box[2]) - low.y
		var r1: int = int(box[3]) - low.y
		# Row 0 is the lowest: the image's rows run down, so it is turned over.
		image.fill_rect(Rect2i(c0, outline.rows - r1, c1 - c0, r1 - r0), box[5] as Color)
		for c: int in range(c0, c1):
			outline.top[c] = maxi(outline.top[c], r1)
			outline.bottom[c] = r0 if outline.bottom[c] < 0 else mini(outline.bottom[c], r0)
		for r: int in range(r0, r1):
			outline.left[r] = c0 if outline.left[r] < 0 else mini(outline.left[r], c0)
			outline.right[r] = maxi(outline.right[r], c1)
	outline.elevation = image
	return outline


## What a reader who read [param outline] exactly would give, as review_model's
## outline= takes it: [param count] samples, as shares to three places.
static func reading_of(outline: Outline, mode: String, count: int = 11) -> Dictionary:
	var said: Dictionary = {"from": outline.side}
	var span: Vector2i = _span(outline, mode)
	var whole: float = float(span.y - span.x + 1) * CELL
	var values: Array = []
	var lows: Array = []
	for n: int in count:
		var at: int = _at(span, float(n) / float(count - 1))
		if mode == "heights":
			values.append(snappedf(_top_near(outline, at, span) * CELL / whole, 0.001))
			lows.append(snappedf(_bottom_near(outline, at, span) * CELL / whole, 0.001))
		else:
			values.append(snappedf(_width_near(outline, at, span) * CELL / whole, 0.001))
	said[mode] = values
	if mode == "heights":
		said["bottoms"] = lows
	return said


## The first and last filled column (heights) or row (widths).
static func _span(outline: Outline, mode: String) -> Vector2i:
	var first: int = -1
	var last: int = -1
	var count: int = outline.cols if mode == "heights" else outline.rows
	for n: int in count:
		var filled: bool = outline.top[n] > 0 if mode == "heights" else outline.left[n] >= 0
		if filled:
			if first < 0:
				first = n
			last = n
	return Vector2i(first, last)


## The cell a share of the span reads.
static func _at(span: Vector2i, share: float) -> int:
	return clampi(span.x + roundi(share * float(span.y - span.x)), span.x, span.y)


## The highest top of the columns within [constant BAND] of column [param at],
## in cells.
static func _top_near(outline: Outline, at: int, span: Vector2i) -> float:
	var most: int = 0
	for c: int in range(maxi(span.x, at - BAND), mini(span.y, at + BAND) + 1):
		most = maxi(most, outline.top[c])
	return float(most)


## The lowest underside of the filled columns within [constant BAND] of
## column [param at], in cells.
static func _bottom_near(outline: Outline, at: int, span: Vector2i) -> float:
	var least: int = -1
	for c: int in range(maxi(span.x, at - BAND), mini(span.y, at + BAND) + 1):
		if outline.bottom[c] >= 0:
			least = outline.bottom[c] if least < 0 else mini(least, outline.bottom[c])
	return float(maxi(0, least))


## The leftmost column and the column past the rightmost of the filled rows
## within [constant BAND] of row [param at]; x -1 when none is filled.
static func _across_near(outline: Outline, at: int, span: Vector2i) -> Vector2i:
	var left: int = -1
	var right: int = 0
	for r: int in range(maxi(span.x, at - BAND), mini(span.y, at + BAND) + 1):
		if outline.left[r] >= 0:
			left = outline.left[r] if left < 0 else mini(left, outline.left[r])
			right = maxi(right, outline.right[r])
	return Vector2i(left, right)


## The width across those rows, leftmost to rightmost, in cells.
static func _width_near(outline: Outline, at: int, span: Vector2i) -> float:
	var across: Vector2i = _across_near(outline, at, span)
	return float(across.y - across.x) if across.x >= 0 else 0.0


## [param reading] laid over [param outline]: the samples, the runs over the
## line, and whether it fits far better laid the other way round.
static func compare(outline: Outline, reading: Reading) -> Comparison:
	var done: Comparison = _laid(outline, reading, false)
	# A width has no left or right to it: only a reading along the length can
	# be the other way round.
	if reading.mode == "heights":
		var turned: Comparison = _laid(outline, reading, true)
		var given_off: float = _total_off(done)
		var turned_off: float = _total_off(turned)
		if turned_off <= given_off * MIRROR_BETTER and given_off - turned_off \
				>= float(reading.values.size()) * PLATE:
			done = turned
	done.runs = _runs(done)
	return done


static func _laid(outline: Outline, reading: Reading, reversed: bool) -> Comparison:
	var laid := Comparison.new()
	laid.reading = reading
	laid.outline = outline
	laid.reversed = reversed
	var span: Vector2i = _span(outline, reading.mode)
	laid.first = span.x
	laid.last = span.y
	laid.span = float(span.y - span.x + 1) * CELL
	var count: int = reading.values.size()
	for n: int in count:
		var share: float = float(n) / float(count - 1)
		var read_at: int = count - 1 - n if reversed else n
		var sample := Sample.new()
		sample.share = share
		sample.cell = _at(span, share)
		sample.outline = reading.values[read_at] * laid.span
		if reading.mode == "heights":
			sample.model = _top_near(outline, sample.cell, span) * CELL
			if not reading.bottoms.is_empty():
				sample.model_low = _bottom_near(outline, sample.cell, span) * CELL
				sample.outline_low = reading.bottoms[read_at] * laid.span
		else:
			sample.model = _width_near(outline, sample.cell, span) * CELL
		laid.samples.append(sample)
	return laid


static func _total_off(laid: Comparison) -> float:
	var total: float = 0.0
	for one: Sample in laid.samples:
		total += absf(one.off()) + absf(one.off_low())
	return total


## The runs of samples over the line, each a stretch the same way off.
static func _runs(laid: Comparison) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var which: Array[String] = []
	which.append("width" if laid.reading.mode == "widths" else "top")
	if laid.reading.mode == "heights" and not laid.reading.bottoms.is_empty():
		which.append("underside")
	var line: float = OFF_WIDTH if laid.reading.mode == "widths" else OFF_HEIGHT
	for kind: String in which:
		var open: Dictionary = {}
		for n: int in laid.samples.size():
			var one: Sample = laid.samples[n]
			var off: float = one.off_low() if kind == "underside" else one.off()
			var over: bool = absf(off) >= line
			if over and not open.is_empty() and signf(off) == signf(float(open["most"])):
				open["to"] = n
				if absf(off) > absf(float(open["most"])):
					open["most"] = off
				if absf(off) < absf(float(open["least"])):
					open["least"] = off
				continue
			if not open.is_empty():
				runs.append(open)
				open = {}
			if over:
				open = {"from": n, "to": n, "which": kind, "least": off, "most": off}
		if not open.is_empty():
			runs.append(open)
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absf(float(a["most"])) > absf(float(b["most"])))
	return runs


## The comparison in words: what is laid over what, each run over the line
## with where it is in tenths and in studs or plates, and every sample.
static func said(laid: Comparison) -> String:
	var reading: Reading = laid.reading
	var heights: bool = reading.mode == "heights"
	var lines := PackedStringArray()
	var from: String = "the %s" % reading.side if reading.side in ["front", "back"] \
		else "its %s side" % reading.side
	lines.append(("The silhouette, from %s: your model's outline in its colours, with the "
		+ "outline you read off %s over it in red, drawn at your model's %s (%s). Orange "
		+ "stripes are your model standing past the outline, blue stripes the outline your "
		+ "model does not fill. "
		+ "Ticks along the foot are studs, a long one every 5; up the side, bricks (3 plates).")
		% [from, "the photograph" if reading.picture.is_empty() else "\"%s\"" % reading.picture,
			"length" if heights else "height",
			_studs(laid.span) if heights else _plates(laid.span)])
	if reading.above > 0.0:
		lines.append("Read from %s plates up: what stands under that (a display base) is left out."
			% _n(reading.above))
	if laid.reversed:
		lines.append(("Laid the other way round: it fits far better so, so the photograph "
			+ "shows the thing facing the other way from this view. from=\"%s\" is the side "
			+ "that shows it the photograph's way.") % ACROSS[reading.side])
	if laid.runs.is_empty():
		lines.append("Within %s everywhere: the silhouette is the one you read." % (
			"two plates" if heights else "a stud"))
	else:
		lines.append("Where they differ by %s or more, largest first:" % (
			"two plates" if heights else "a stud"))
		for n: int in mini(RUNS_SAID, laid.runs.size()):
			lines.append("  - " + _run_said(laid, laid.runs[n]))
		if laid.runs.size() > RUNS_SAID:
			lines.append("  - ... and %d more stretch%s" % [laid.runs.size() - RUNS_SAID,
				"" if laid.runs.size() - RUNS_SAID == 1 else "es"])
	lines.append(_table(laid))
	if not laid.runs.is_empty():
		lines.append(("Bring each to the outline with edit_model, or keep it and say why. A "
			+ "keep for minifigure scale or the parts names the stretch it keeps and by how "
			+ "much; the rest comes to the outline."))
	return "\n".join(lines)


static func _run_said(laid: Comparison, run: Dictionary) -> String:
	var count: int = laid.samples.size()
	var a: Sample = laid.samples[int(run["from"])]
	var b: Sample = laid.samples[int(run["to"])]
	var low: bool = str(run["which"]) == "underside"
	# The sample furthest off, for its two figures.
	var worst: Sample = a
	for n: int in range(int(run["from"]), int(run["to"]) + 1):
		var one: Sample = laid.samples[n]
		if absf(one.off_low() if low else one.off()) > absf(worst.off_low() if low else worst.off()):
			worst = one
	var where: String = _tenths(int(run["from"]), int(run["to"]), count)
	var least: float = float(run["least"])
	var most: float = float(run["most"])
	if laid.reading.mode == "widths":
		var studs: String = _amount(absf(least) / STUD, absf(most) / STUD, "stud")
		return "%s of its height (%s up): %s %s than the outline (%s against %s)" % [
			where, _plate_span(laid, a.cell, b.cell), studs,
			"wider" if most > 0.0 else "narrower", _studs(worst.model), _studs(worst.outline)]
	var plates: String = _amount(absf(least) / PLATE, absf(most) / PLATE, "plate")
	var said: String = "%s of its length (%s): %s %s" % [where, _stud_span(laid, a.cell, b.cell),
		"its underside" if low else "its top", plates]
	said += (" lower than the outline's" if most < 0.0 else " higher than the outline's") if low \
		else (" taller than the outline" if most > 0.0 else " lower than the outline")
	var model: float = worst.model_low if low else worst.model
	var outline: float = worst.outline_low if low else worst.outline
	return said + " (%s against %s)" % [_plates(model), _plates(outline)]


## "at 3/10" or "from 2/10 to 4/10", for samples at tenths; otherwise as shares.
static func _tenths(from: int, to: int, count: int) -> String:
	var a: String = _fraction(from, count)
	var b: String = _fraction(to, count)
	return "at %s" % a if from == to else "from %s to %s" % [a, b]


static func _fraction(index: int, count: int) -> String:
	if count == 11:
		return "%d/10" % index
	if count == 21:
		return "%d/20" % index
	return "%.2f" % (float(index) / float(count - 1))


## Columns [param from] to [param to] as the model's own coordinates, studs.
static func _stud_span(laid: Comparison, from: int, to: int) -> String:
	var one: int = laid.outline.model_cell(from)
	var other: int = laid.outline.model_cell(to)
	var a: float = float(mini(one, other)) * CELL / STUD
	var b: float = float(maxi(one, other) + 1) * CELL / STUD
	var axis: String = laid.outline.axis()
	if from == to:
		return "%s %s" % [axis, _n(snappedf(a, 0.5))]
	return "%s %s to %s" % [axis, _n(snappedf(a, 0.5)), _n(snappedf(b, 0.5))]


static func _plate_span(laid: Comparison, from: int, to: int) -> String:
	var floor_at: int = laid.outline.floor_cells
	var a: float = float(from + floor_at) / PLATE_CELLS
	var b: float = float(to + floor_at + 1) / PLATE_CELLS
	return "plates %s to %s" % [_n(floorf(a)), _n(ceilf(b))]


## Every sample, the outline's and the model's.
static func _table(laid: Comparison) -> String:
	var heights: bool = laid.reading.mode == "heights"
	var cells := PackedStringArray()
	for one: Sample in laid.samples:
		var unit: float = PLATE if heights else STUD
		var pair: String = "%s/%s" % [_n(snappedf(one.outline / unit, 0.5)),
			_n(snappedf(one.model / unit, 0.5))]
		if heights and one.outline_low >= 0.0:
			pair += " (under %s/%s)" % [_n(snappedf(one.outline_low / unit, 0.5)),
				_n(snappedf(one.model_low / unit, 0.5))]
		cells.append(pair)
	return "%s, the outline's / yours, in %s: %s." % [
		"Each sample left to right" if heights else "Each sample from the ground up",
		"plates of height" if heights else "studs of width", " · ".join(cells)]


static func _amount(least: float, most: float, unit: String) -> String:
	var a: int = maxi(1, roundi(least))
	var b: int = maxi(1, roundi(most))
	if a == b:
		return "a %s" % unit if a == 1 else "%d %ss" % [a, unit]
	return "%d to %d %ss" % [mini(a, b), maxi(a, b), unit]


static func _studs(ldu: float) -> String:
	var studs: float = snappedf(ldu / STUD, 0.5)
	return "1 stud" if is_equal_approx(studs, 1.0) else "%s studs" % _n(studs)


static func _plates(ldu: float) -> String:
	var plates: float = snappedf(ldu / PLATE, 0.5)
	return "1 plate" if is_equal_approx(plates, 1.0) else "%s plates" % _n(plates)


static func _n(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## The picture: the model's elevation in its colours, the outline read over
## it in red, what stands past it orange and what falls short of it blue,
## with stud ticks along the foot and brick ticks up the side.
static func picture(laid: Comparison) -> Image:
	var outline: Outline = laid.outline
	if outline.is_empty() or outline.elevation == null:
		return null
	var heights: bool = laid.reading.mode == "heights"
	# The outline may stand taller (or wider) than the model: room for it.
	var reach_up: int = outline.rows
	var reach_side: int = 0
	for one: Sample in laid.samples:
		if heights:
			reach_up = maxi(reach_up, ceili(one.outline / CELL))
		else:
			reach_side = maxi(reach_side, ceili((one.outline - one.model) / CELL / 2.0))
	var wide_cells: int = outline.cols + 2 * reach_side
	var px: int = clampi(int(float(PICTURE_MOST - 2 * MARGIN) / maxf(1.0,
		float(maxi(wide_cells, reach_up)))), 1, MOST_PX)
	var width: int = wide_cells * px + 2 * MARGIN
	var height: int = reach_up * px + 2 * MARGIN
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(BACKDROP)
	var scaled: Image = outline.elevation.duplicate()
	scaled.resize(outline.cols * px, outline.rows * px, Image.INTERPOLATE_NEAREST)
	var origin := Vector2i(MARGIN + reach_side * px, height - MARGIN)  # the left of row 0's foot
	image.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()),
		Vector2i(origin.x, origin.y - outline.rows * px))
	# Past and short, a column (or a row) at a time between the samples.
	if heights:
		for c: int in range(laid.first, laid.last + 1):
			var at: float = _outline_at(laid, c, false)
			var model: float = float(outline.top[c]) * CELL
			_shade_column(image, origin, px, c, model, at)
			if laid.samples[0].outline_low >= 0.0:
				var under: float = _outline_at(laid, c, true)
				var model_low: float = float(maxi(0, outline.bottom[c])) * CELL
				_shade_column(image, origin, px, c, under, model_low)
	else:
		for r: int in range(laid.first, laid.last + 1):
			if outline.left[r] < 0:
				continue
			var at: float = _outline_at(laid, r, false)
			var middle: float = float(outline.left[r] + outline.right[r]) * 0.5
			var half_model: float = float(outline.right[r] - outline.left[r]) * 0.5
			var half: float = at / CELL * 0.5
			for towards: float in [-1.0, 1.0]:
				var edge_model: float = middle + towards * half_model
				var edge: float = middle + towards * half
				var a: float = minf(edge_model, edge)
				var b: float = maxf(edge_model, edge)
				if b - a < 0.5:
					continue
				var past: bool = half_model > half
				_hatch(image, Rect2i(origin.x + roundi(a * px), origin.y - (r + 1) * px,
					roundi((b - a) * px), px), past)
	# The outline read, in red, joined sample to sample.
	var points: Array[Vector2] = []
	var lows: Array[Vector2] = []
	for one: Sample in laid.samples:
		if heights:
			var x: float = origin.x + (float(one.cell) + 0.5) * px
			points.append(Vector2(x, origin.y - one.outline / CELL * px))
			if one.outline_low >= 0.0:
				lows.append(Vector2(x, origin.y - one.outline_low / CELL * px))
		else:
			var across: Vector2i = _across_near(outline, one.cell, Vector2i(laid.first, laid.last))
			var r: int = one.cell
			var middle: float = float(across.x + across.y) * 0.5 \
				if across.x >= 0 else float(outline.cols) * 0.5
			var y: float = origin.y - (float(r) + 0.5) * px
			points.append(Vector2(origin.x + (middle - one.outline / CELL * 0.5) * px, y))
			lows.append(Vector2(origin.x + (middle + one.outline / CELL * 0.5) * px, y))
	_polyline(image, points)
	_polyline(image, lows)
	if heights and not points.is_empty():
		# Its two ends down to the ground (or to the underside).
		var foot: float = origin.y
		_line(image, points[0], Vector2(points[0].x, lows[0].y if not lows.is_empty() else foot))
		_line(image, points[-1], Vector2(points[-1].x, lows[-1].y if not lows.is_empty() else foot))
	elif not heights and not points.is_empty():
		_line(image, points[0], lows[0])
		_line(image, points[-1], lows[-1])
	# Stud ticks along the foot, brick ticks up the side.
	var stud_cells: int = int(STUD / CELL)
	for n: int in range(0, wide_cells + 1, stud_cells):
		var x: int = MARGIN + n * px
		var long: bool = (n / stud_cells) % 5 == 0
		image.fill_rect(Rect2i(x, height - MARGIN + 2, 1, 10 if long else 5), TICK)
	var brick_cells: int = 3 * PLATE_CELLS
	for n: int in range(0, reach_up + 1, brick_cells):
		var y: int = height - MARGIN - n * px
		var long: bool = (n / brick_cells) % 5 == 0
		image.fill_rect(Rect2i(MARGIN - (10 if long else 5) - 2, y, 10 if long else 5, 1), TICK)
	return image


## The outline read, between its samples, at column (or row) [param cell], LDU.
static func _outline_at(laid: Comparison, cell: int, low: bool) -> float:
	var samples: Array[Sample] = laid.samples
	for n: int in samples.size() - 1:
		var a: Sample = samples[n]
		var b: Sample = samples[n + 1]
		if cell >= a.cell and cell <= b.cell:
			var t: float = 0.0 if b.cell == a.cell else float(cell - a.cell) / float(b.cell - a.cell)
			return lerpf(a.outline_low if low else a.outline, b.outline_low if low else b.outline, t)
	return samples[-1].outline_low if low else samples[-1].outline


## Column [param c] shaded between two heights, LDU: orange where the first
## (the model's top, or the outline's underside) stands over the second.
static func _shade_column(image: Image, origin: Vector2i, px: int, c: int, upper: float,
		lower: float) -> void:
	var a: float = minf(upper, lower) / CELL
	var b: float = maxf(upper, lower) / CELL
	if b - a < 0.5:
		return
	_hatch(image, Rect2i(origin.x + c * px, origin.y - roundi(b * px), px,
		roundi((b - a) * px)), upper > lower)


## [param area] striped: orange rising for past, blue falling for short.
static func _hatch(image: Image, area: Rect2i, past: bool) -> void:
	area = area.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if area.size.x <= 0 or area.size.y <= 0:
		return
	var colour: Color = PAST if past else SHORT
	for x: int in range(area.position.x, area.end.x):
		var start: int = area.position.y - posmod(x if past else -x, HATCH_EVERY)
		for y: int in range(start, area.end.y, HATCH_EVERY):
			var stripe := Rect2i(x, y, 1, HATCH_WIDE).intersection(area)
			if stripe.size.y > 0:
				image.fill_rect(stripe, colour)


static func _polyline(image: Image, points: Array[Vector2]) -> void:
	for n: int in points.size() - 1:
		_line(image, points[n], points[n + 1])


## A line three pixels thick.
static func _line(image: Image, from: Vector2, to: Vector2) -> void:
	var steps: int = maxi(1, ceili(from.distance_to(to)))
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	for n: int in steps + 1:
		var at: Vector2 = from.lerp(to, float(n) / float(steps))
		var dot := Rect2i(Vector2i(roundi(at.x) - 1, roundi(at.y) - 1), Vector2i(3, 3))
		dot = dot.intersection(bounds)
		if dot.size.x > 0 and dot.size.y > 0:
			image.fill_rect(dot, LINE)
