## The real thing's outline, read off a photograph of it before the first
## build, and handed back as the sizes to build to.
##
## design21 handed the first mass as a solid to send as it is, and lost its
## screen: the four sessions that built the solid it named (an extrude down to
## the ground, tiers a stud each side apart) lost both orders head to head, "a
## block on wheels", "a wedding cake"; the four that read the outline and
## built their own way won 7 of 8. A measure helped where a solid did not.
##
## So the answer is sizes, and no solid: the outline in levels of studs and
## plates, each setback where the reading puts it, on the side it steps in on,
## and how tall each tier is, and the plan from above. A long thing's body is
## read over what holds it up, and what breaks its outline (wheels, tracks, a
## header, a blade, a guard) is read as masses of their own, so the body is not
## filled down to the ground under them.
##
## design22 answered that way and lost likeness, for three reasons this
## answers (design23):
## - The brief's "fitting in about W x D" bounds a set with its stand and its
##   scene, and was laid as the model's foot: a dozer 33 by 30, a palace a U 24
##   deep. The box is a bound: the long side fits it, and the depth comes from
##   the real thing's own plan (deep=), never the box's other side.
## - Each tenth answered to the plate carried the reading's noise: a level
##   roofline read 0.14 to 0.19 became blocks of 20 to 27 plates. Tenths within
##   a few plates of their neighbours are one level now, and a level ends only
##   where the reading steps.
## - A real long, low building's proportion leaves no room at microscale for
##   its storeys, balcony and portico. A building's storeys= say what its face
##   needs, and the answer stretches the face for them, as a set does, with
##   the height read beside it. What stands above the face (a dome, a tower,
##   a pediment) keeps its own height on top of it: the Capitol's set has
##   wings of 18 plates where 14 are read and a dome of 48 where 52 are, so
##   stretching the dome with the storeys (to 70) would lose it.
##
## Nothing here knows what a car or a tower is: a reading is heights along a
## long thing or widths up a tall one, and the session says which.
class_name OutlinePlan
extends RefCounted

## The sides a photograph can be from, as view_model names them.
const SIDES: Array[String] = ["front", "back", "left", "right"]
## The plans from above a mass can have, by what a builder calls them.
const PLANS: Array[String] = ["rectangle", "square", "round", "Y", "T", "L", "cross", "H",
	"U", "triangle"]
## Other words for them.
const PLAN_WORDS: Dictionary = {"rect": "rectangle", "box": "rectangle", "oval": "round",
	"circle": "round", "circular": "round", "ellipse": "round", "plus": "cross",
	"x": "cross", "tri": "triangle", "triangular": "triangle", "y": "Y", "t": "T",
	"l": "L", "h": "H", "u": "U"}
## The plans whose arms have a thickness.
const ARMED: Array[String] = ["Y", "T", "L", "cross", "H", "U"]
## An arm's thickness, a share of the width, when none is said.
const ARM := 0.34
## The sides a setback can step in on, as the photograph shows it.
const STEP_SIDES: Array[String] = ["left", "right", "both"]
## What studs= can measure: the model's longest side, the brief's box as a
## bound ("fitting in about 12 x 13 studs"), or the part the outline reads.
const MEASURES: Array[String] = ["longest", "box", "read"]
## Other names for them: design22 asked for the box as the model's footprint,
## and a session may still say so. It is the same bound.
const MEASURE_WORDS: Dictionary = {"footprint": "box"}

## The fewest and most samples a reading takes, evenly spaced, both ends in.
const FEWEST := 5
const MOST := 41
## The most a share may be: a tower's height is many of its widths.
const LARGEST := 20.0
## The most steps and breaks a reading may give.
const MOST_STEPS := 40
const MOST_BREAKS := 12
## A long thing's width across, a share of its length, when nothing says it:
## a car's is about 0.4.
const DEEP := 0.4
## Studs to plates: a stud is 20 LDU across, a plate 8 up.
const PLATES_PER_STUD := 2.5
## How far off the ground a break must start to be off it, a share.
const GROUNDED := 0.02
## A size studs= gives this many times the scale's, or under its share, is
## said beside the scale's.
const FAR := 1.5
## Neighbouring tenths within this share of the reading's measure are one
## level: a reading by eye off a photograph is good to about a twenty-fifth.
## design22's Capitol wings, level in the photograph, read 0.14 to 0.19.
const NOISE := 0.04
## ...and never closer than a brick up or a stud across: a step smaller is a
## band, not a step.
const LEAST_PLATES := 3.0
const LEAST_STUDS := 1.0
## A stretch between steps whose reading moves more than this many levels'
## worth is a slope or a curve (a roof's pitch, a dome, a bonnet), not a level.
const SLOPED := 2.0
## A deep= this near the box's own shape, on a thing at least this deep, is
## said: it may be the box's shape and not the real thing's (design22's dozer
## gave 0.9 in a 33 x 30 box).
const BOX_LIKE := 0.03
const BOXY := 0.6
## The plates a building's face needs for its storeys at microscale: a plinth,
## each storey a brick of windows with its sill and its floor's line, and a
## cornice, parapet or balustrade over the top. Tune-half Architecture sets
## give a storey 5 to 7 plates where they have room (a palace's three storeys
## 22 plates over its plinth, a capitol's wings 18 for three).
const PLINTH := 2
const STOREY := 5
const CORNICE := 2
## A storey squeezed to a brick and a plate: what an expert gives one before
## stretching further.
const LEAST_STOREY := 4
## A face of more storeys than this is a tower's: its floors are texture (a
## plate or a grille's line each), and its height is its proportion's.
const FEW_STOREYS := 6
## The most storeys= may say.
const MOST_STOREYS := 300
## The most an expert stretches a face's height for its storeys: past it a
## storey is built a brick and a plate tall rather than stretched further.
const MOST_STRETCH := 2.0
## The share of a long thing's length a level must run to be its main block,
## the face its storeys are counted on.
const MAIN_BLOCK := 0.25

var side: String = ""
## "heights" (a long thing: the top at each sample along its length, shares
## of the length) or "widths" (a tall thing: its width at each sample up its
## height, shares of the height).
var mode: String = ""
var values := PackedFloat64Array()
## With heights, the underside at each sample, or empty.
var bottoms := PackedFloat64Array()
## Where the outline steps, shares along the reading's own way (along the
## length for heights, up the height for widths), rising; empty for a smooth
## outline. Each with the side it steps in on (widths): left, right or both.
var steps := PackedFloat64Array()
var step_sides := PackedStringArray()
## How many setbacks came with no side said.
var unsided: int = 0
## What breaks the outline, each a mass of its own: {"name", "from", "to",
## "bottom", "top"}, shares of the reading's measure (a long thing's length, a
## tall thing's height) from the outline's left as the photograph shows it and
## from the ground.
var breaks: Array = []
## Its plan from above, one of PLANS.
var plan: String = "rectangle"
## The arms' thickness for a Y, T, L, cross, H or U, a share of the width.
var arm: float = 0.0
## heights: the width across, a share of the length; widths: the depth, a
## share of the width. 0 when not said.
var deep: float = 0.0
## How many storeys its face shows, a building's; 0 when not said.
var storeys: int = 0
## What it was read off, in the session's words.
var picture: String = ""
var error: String = ""

## Its size, once [method fit]: the studs one share of the reading is (a long
## thing's length, a tall thing's height); a long thing's width across, a tall
## thing's widest width and its depth, in studs.
var unit: float = 0.0
var across: float = 0.0
var widest: float = 0.0
var depth: float = 0.0
## How many times its face is stretched for its storeys: 1 for none.
var stretch: float = 1.0
## Its face's height read, in plates, before any stretch (see [method
## face_plates]): what is up to it stretches, and what stands above it rises
## by the plates the face gained.
var face: float = 0.0
## How the size was set, as the answer says it.
var sized_by: String = ""
## What the answer says about the size besides, one sentence each.
var notes := PackedStringArray()


## [param said] as plan_scale's outline= gives it, checked: [member error] says
## what is wrong, and nothing else is read then.
static func read(said: Variant) -> OutlinePlan:
	var reading := OutlinePlan.new()
	if not said is Dictionary:
		reading.error = ("outline= is an object: {\"from\": \"front\", \"heights\": [...]} "
			+ "or {\"from\": \"front\", \"widths\": [...]}.")
		return reading
	var given: Dictionary = said
	reading.side = str(given.get("from", "")).strip_edges().to_lower()
	if not SIDES.has(reading.side):
		reading.error = ("outline's from= is the side of your model the photograph shows: "
			+ "front, back, left or right (the front is +z; a car laid along x is seen "
			+ "from the front or the back).")
		return reading
	var heights: Variant = given.get("heights")
	var widths: Variant = given.get("widths")
	if (heights == null) == (widths == null):
		reading.error = ("Give one of heights= (a long thing: the top's height at each "
			+ "tenth of its length, as shares of the length) or widths= (a tall thing: its "
			+ "width at each tenth of its height, as shares of the height).")
		return reading
	reading.mode = "heights" if heights != null else "widths"
	var values: Variant = _shares(heights if heights != null else widths, reading.mode)
	if values is String:
		reading.error = values
		return reading
	reading.values = values
	if Array(reading.values).max() <= 0.0:
		reading.error = "%s= are all 0: there is nothing there to build." % reading.mode
		return reading
	if given.has("bottoms") and given["bottoms"] != null:
		if reading.mode != "heights":
			reading.error = "bottoms= goes with heights=, the underside below each top."
			return reading
		var low: Variant = _shares(given["bottoms"], "bottoms")
		if low is String:
			reading.error = low
			return reading
		if (low as PackedFloat64Array).size() != reading.values.size():
			reading.error = ("bottoms= has %d numbers and heights= %d: one each, at the "
				+ "same places.") % [(low as PackedFloat64Array).size(), reading.values.size()]
			return reading
		for n: int in reading.values.size():
			if (low as PackedFloat64Array)[n] > reading.values[n] + 0.0001:
				reading.error = ("bottoms= is the underside at each place, under its top: "
					+ "number %d is over it." % (n + 1))
				return reading
		reading.bottoms = low
	if given.has("steps") and given["steps"] != null:
		var why: String = reading._read_steps(given["steps"])
		if not why.is_empty():
			reading.error = why
			return reading
	if given.has("breaks") and given["breaks"] != null:
		var why: String = reading._read_breaks(given["breaks"])
		if not why.is_empty():
			reading.error = why
			return reading
	var named: String = str(given.get("plan", "rectangle")).strip_edges()
	var planned: String = plan_named(named)
	if planned.is_empty():
		reading.error = ("plan= is its shape from above: %s." % ", ".join(PLANS))
		return reading
	reading.plan = planned
	reading.arm = float(given.get("arm", 0.0)) if (given.get("arm") is float
		or given.get("arm") is int) else 0.0
	if reading.arm < 0.0 or reading.arm >= 1.0:
		reading.error = "arm= is how thick the plan's arms are, a share of its width: 0.2 to 0.6."
		return reading
	var deep_: Variant = given.get("deep", 0.0)
	if deep_ == null:
		deep_ = 0.0
	if not (deep_ is float or deep_ is int) or float(deep_) < 0.0 or float(deep_) > LARGEST:
		reading.error = ("deep= is %s, a share such as %s." % [
			"its width across, a share of its length" if reading.mode == "heights"
				else "its depth, a share of its width", "0.4" if reading.mode == "heights"
				else "0.6"])
		return reading
	reading.deep = float(deep_)
	var storeys_: Variant = given.get("storeys", 0)
	if storeys_ == null:
		storeys_ = 0
	if not (storeys_ is float or storeys_ is int) or float(storeys_) < 0.0 \
			or float(storeys_) > MOST_STOREYS or not is_equal_approx(float(storeys_),
				roundf(float(storeys_))):
		reading.error = ("storeys= is how many storeys its face shows, a whole number such as 3 "
			+ "(a colonnade counts the storeys it spans).")
		return reading
	reading.storeys = int(roundf(float(storeys_)))
	reading.picture = str(given.get("picture", "")).strip_edges().left(200)
	return reading


## steps= read in: each a share, or {"at": share, "side": left, right or
## both}. "" when they are good, else what is wrong.
func _read_steps(raw: Variant) -> String:
	var way: String = "along its length" if mode == "heights" else "up its height"
	if not raw is Array or (raw as Array).size() > MOST_STEPS:
		return ("steps= is where the outline steps, each a share %s, lowest first: up "
			% way + "to %d of them. A tall thing's setback says the side it steps in " % MOST_STEPS
			+ "on: {\"at\": 0.4, \"side\": \"left\"} (left, right or both, as the photograph "
			+ "shows it).")
	var last: float = 0.0
	for one: Variant in raw:
		var at: Variant = one
		var on: String = ""
		if one is Dictionary:
			at = (one as Dictionary).get("at")
			on = str((one as Dictionary).get("side", "")).strip_edges().to_lower()
			if not on.is_empty() and not STEP_SIDES.has(on):
				return ("a step's side is the one it steps in on, as the photograph shows "
					+ "it: left, right or both, not \"%s\"." % on)
		if not (at is float or at is int) or float(at) <= 0.0 or float(at) >= 1.0 \
				or float(at) <= last:
			return ("steps= holds shares between 0 and 1, each past the one before (0.12 is "
				+ "a step an eighth of the way %s): %s is not one." % [
					"along" if mode == "heights" else "up", JSON.stringify(at)])
		last = float(at)
		steps.append(last)
		if on.is_empty():
			on = "both"
			if mode == "widths":
				unsided += 1
		step_sides.append(on)
	return ""


## breaks= read in: what breaks the outline, each its own mass. "" when they
## are good, else what is wrong.
func _read_breaks(raw: Variant) -> String:
	var measure: String = "the length" if mode == "heights" else "the height"
	var shape: String = ("each {\"name\": \"front wheel\", \"from\": 0.08, \"to\": 0.26, "
		+ "\"bottom\": 0, \"top\": 0.18}: from and to across, as the photograph shows it, "
		+ "from the outline's left; bottom and top up from the ground; all shares of %s, as "
		% measure + "the outline's are")
	if not raw is Array or (raw as Array).size() > MOST_BREAKS:
		return "breaks= is what breaks the outline, up to %d: %s." % [MOST_BREAKS, shape]
	for one: Variant in raw:
		if not one is Dictionary:
			return "breaks= holds objects, %s." % shape
		var given: Dictionary = one
		var name: String = str(given.get("name", "")).strip_edges().left(40)
		if name.is_empty():
			return "a break says what it is: \"name\": \"front wheel\", \"track\", \"header\"."
		var numbers: Dictionary = {}
		for key: String in ["from", "to", "bottom", "top"]:
			var value: Variant = given.get(key)
			if not (value is float or value is int) or float(value) < 0.0 \
					or float(value) > LARGEST or is_nan(float(value)):
				return "%s's %s= is a share of %s from 0: %s." % [name, key, measure, shape]
			numbers[key] = float(value)
		if numbers["to"] <= numbers["from"] or numbers["top"] <= numbers["bottom"]:
			return ("%s: its to= is past its from=, and its top= over its bottom=." % name)
		breaks.append({"name": name, "from": numbers["from"], "to": numbers["to"],
			"bottom": numbers["bottom"], "top": numbers["top"]})
	return ""


## A plan by any of its names, as PLANS has it; "" for none.
static func plan_named(named: String) -> String:
	var plain: String = named.strip_edges()
	for one: String in PLANS:
		if one.to_lower() == plain.to_lower():
			return one
	return str(PLAN_WORDS.get(plain.to_lower(), ""))


## [param raw] as shares, or why not.
static func _shares(raw: Variant, called: String) -> Variant:
	if not raw is Array:
		return ("%s= is a list of numbers, one at each tenth: 11 of them, from one end to "
			% called + "the other.")
	var list: Array = raw
	if list.size() < FEWEST or list.size() > MOST:
		return ("%s= has %d numbers: give %d to %d, evenly spaced from one end to the "
			% [called, list.size(), FEWEST, MOST] + "other, 11 for each tenth.")
	var out := PackedFloat64Array()
	for one: Variant in list:
		if not (one is float or one is int):
			return "%s= holds only numbers, shares such as 0.25." % called
		var share: float = float(one)
		if share < 0.0 or share > LARGEST or is_nan(share):
			return "%s= holds shares from 0 to %d, fractions of the whole: %s is not one." % [
				called, int(LARGEST), str(one)]
		out.append(share)
	return out


## What plan_scale's studs= measures, and its numbers: {"measure", "numbers"},
## or {"error"} saying what forms it takes. Empty for none given.
static func studs_read(raw: Variant) -> Dictionary:
	if raw == null:
		return {}
	var forms: String = ("studs= names what it measures: {\"box\": [12, 13]}, the brief's box "
		+ "(\"fitting in about 12 x 13 studs\"), a bound the model fits in; {\"longest\": 54}, "
		+ "the model's longest side; or {\"read\": 6}, the part the outline reads (a long "
		+ "thing's length, a tall thing's widest width as the photograph shows it)")
	if not raw is Dictionary or (raw as Dictionary).size() != 1:
		return {"error": "%s. %s says none, so it was not taken." % [forms,
			JSON.stringify(raw)]}
	var measure: String = str((raw as Dictionary).keys()[0]).strip_edges().to_lower()
	measure = str(MEASURE_WORDS.get(measure, measure))
	if not MEASURES.has(measure):
		return {"error": "%s. \"%s\" is not one, so it was not taken." % [forms, measure]}
	var value: Variant = (raw as Dictionary).values()[0]
	var numbers: Array[float] = []
	var listed: Array = (value as Array) if value is Array else [value]
	for one: Variant in listed:
		if (one is float or one is int) and float(one) > 0.0:
			numbers.append(float(one))
	if numbers.is_empty() or numbers.size() > (2 if measure == "box" else 1):
		return {"error": "%s. %s has %s, so it was not taken." % [forms, JSON.stringify(raw),
			"no size in studs" if numbers.is_empty() else "too many numbers"]}
	return {"measure": measure, "numbers": numbers}


## The model's axis the reading runs along: a long thing's length, or a tall
## thing's width.
func axis() -> String:
	return "x" if side in ["front", "back"] else "z"


## Whether the photograph's left is the axis' far end: from the back or the
## right, the picture's left is the model's +x (or +z).
func reversed() -> bool:
	return side in ["back", "right"]


## The model's side a photograph's [param left_or_right] is: "-x" from the
## front.
func model_side(left_or_right: String) -> String:
	var low: bool = (left_or_right == "left") != reversed()
	return ("-" if low else "+") + axis()


## The highest share read: a long thing's highest top, a tall thing's widest.
func most() -> float:
	return Array(values).max()


## Sized: [param studs] as [method studs_read] gives it (empty for none), and
## [param planned] the scale's studs along the longest side, used when studs=
## says none. Sets [member unit] and the rest, [member sized_by] and
## [member notes], and the stretch its storeys need.
func fit(studs: Dictionary, planned: float) -> void:
	var measure: String = str(studs.get("measure", ""))
	var numbers: Array = studs.get("numbers", [])
	var top: float = most()
	notes = PackedStringArray()
	# A long thing's width across or a tall thing's depth, a share: its own
	# plan's, never a box's other side.
	var ratio: float = deep if deep > 0.0 else (DEEP if mode == "heights" else 1.0)
	var other: float = -1.0
	match measure:
		"longest":
			unit = float(numbers[0]) / maxf(1.0, top)
			sized_by = "studs= {\"longest\": %s}: %s studs along its longest side" % [
				_n(numbers[0]), _n(numbers[0])]
		"read":
			unit = float(numbers[0]) / (1.0 if mode == "heights" else top)
			sized_by = "studs= {\"read\": %s}: the part read, %s" % [_n(numbers[0]),
				"its length, %s studs" % _n(numbers[0]) if mode == "heights"
				else "its widest width as the photograph shows it, %s studs" % _n(numbers[0])]
		"box":
			var sides: Vector2 = _boxed(numbers, ratio)
			unit = sides.x if mode == "heights" else sides.x / maxf(0.0001, top)
			other = sides.y
		_:
			unit = maxf(1.0, planned) / maxf(1.0, top)
			sized_by = "the scale above: %s studs along its longest side" % _n(snappedf(
				maxf(1.0, planned), 0.1))
	unit = maxf(1.0, unit)
	if mode == "heights":
		across = maxf(1.0, roundf(other if other > 0.0 else ratio * unit))
	else:
		widest = maxf(1.0, roundf(top * unit))
		depth = maxf(1.0, roundf(other if other > 0.0 else widest * ratio))
	face = face_plates()
	stretch = _stretched()


## The brief's box [param numbers] as a bound, for a plan [param ratio] deep:
## [code]Vector2(seen, other)[/code], the studs along the side the reading runs
## (a long thing's length, a tall thing's widest face) and across it. The
## plan's long side is the box's long side; its short side is the plan's own,
## held to the box's short side, never taken from it. Says how in
## [member sized_by] and [member notes].
func _boxed(numbers: Array, ratio: float) -> Vector2:
	var big: float = Array(numbers).max()
	var small: float = Array(numbers).min()
	var share: float = ratio if ratio <= 1.0 else 1.0 / ratio
	var own: float = big * share
	var short_: float = minf(own, small)
	var seen: float = big if ratio <= 1.0 else short_
	var other: float = short_ if ratio <= 1.0 else big
	var said := PackedStringArray()
	for n: float in numbers:
		said.append(_n(n))
	var box: String = " x ".join(said)
	var whole: String = ("its length" if mode == "heights" else "its widest face")
	var crosswise: String = ("its width across" if mode == "heights" else "its depth")
	var long_name: String = whole if ratio <= 1.0 else crosswise
	var short_name: String = crosswise if ratio <= 1.0 else whole
	var plan_: String = ("from its own plan (deep %s)" % _share(deep) if deep > 0.0
		else ("at 0.4 of its length, a long thing's usual" if mode == "heights"
			else "as deep as it is wide, as none was said"))
	if own > small + 0.5:
		sized_by = ("the brief's box, %s studs, as a bound: %s fits the box's %s, and %s, %s "
			+ "studs %s, is held to the box's %s") % [box, long_name, _n(big), short_name,
				_n(snappedf(own, 0.5)), plan_, _n(small)]
	else:
		sized_by = ("the brief's box, %s studs, as a bound: %s fits the box's %s, and %s is %s "
			+ "studs, %s%s") % [box, long_name, _n(big), short_name, _n(maxf(1.0,
				roundf(short_))), plan_, "" if absf(roundf(short_) - small) < 0.5
				else ", not the box's %s" % _n(small)]
	if deep <= 0.0:
		notes.append(("Give deep=, %s read off a photograph from its end or from above, to "
			+ "size it to its own plan: the box bounds the set with its stand and its scene, "
			+ "not the thing.") % ("its width across as a share of its length" if mode
				== "heights" else "its depth as a share of its width"))
	elif numbers.size() == 2 and not is_equal_approx(big, small) and share >= BOXY \
			and absf(share - small / big) <= BOX_LIKE:
		notes.append(("deep= %s is the box's own shape (%s / %s). The box bounds the set, with "
			+ "its stand and its scene: if %s came from it, give the real thing's own %s, read "
			+ "off a photograph from its end or from above.") % [_share(deep), _n(small),
				_n(big), _share(deep), "width across" if mode == "heights" else "depth"])
	return Vector2(seen, other)


## A share said to two places: 0.45, not 0.5.
static func _share(value: float) -> String:
	return str(snappedf(value, 0.01))


## The model's longest side at this size, in studs.
func longest() -> float:
	return unit * maxf(1.0, most())


## The reading at [param share] along (0 to 1) of [param list], linear between
## its samples.
static func _at(list: PackedFloat64Array, share: float) -> float:
	if list.is_empty():
		return 0.0
	var spot: float = clampf(share, 0.0, 1.0) * float(list.size() - 1)
	var low: int = clampi(floori(spot), 0, list.size() - 1)
	var high: int = mini(low + 1, list.size() - 1)
	return lerpf(list[low], list[high], spot - float(low))


## The reading over [code][from, to][/code] as one level: the median of its
## middle half, so the slope across a step on either side does not pull it.
static func _level(list: PackedFloat64Array, from: float, to: float) -> float:
	var span: float = to - from
	var seen: Array[float] = []
	for n: int in 21:
		seen.append(_at(list, from + span * (0.25 + 0.5 * float(n) / 20.0)))
	seen.sort()
	return seen[seen.size() / 2]


## How far the reading may move and stay one level, a share as the reading's
## are: NOISE of its measure, and never under a brick up (heights) or a stud
## across (widths) at the size fitted.
func tolerance() -> float:
	if mode == "heights":
		return maxf(NOISE, LEAST_PLATES / maxf(1.0, unit * PLATES_PER_STUD))
	return maxf(NOISE, LEAST_STUDS / maxf(1.0, unit))


## [param list] in levels along the reading's way, ground (or the
## photograph's left) first. Each {"from", "to"} (shares) with "level" (a
## share, as the list's), or a slope with "slope": true and its "start", "end",
## "peak", "peak_at", "low" and "low_at". Tenths within [method tolerance] of
## their neighbours are one level. With [param stepped] and steps read, a
## level ends only at a step, and a stretch between two that moves more than
## SLOPED levels' worth is a slope; with none read, a level ends where the
## reading jumps past the tolerance, and tenths that move each by more are a
## slope (heights) or a tier each (widths). Neighbouring levels within the
## tolerance are then one: a step under a brick is a band, not a step.
func levels(list: PackedFloat64Array, stepped: bool = true) -> Array:
	var tol: float = tolerance()
	var pieces: Array = []
	if stepped and not steps.is_empty():
		var edges: Array[float] = [0.0]
		for one: float in steps:
			edges.append(one)
		edges.append(1.0)
		for n: int in edges.size() - 1:
			var a: float = edges[n]
			var b: float = edges[n + 1]
			var piece: Dictionary = _piece(list, a, b, "step" if n > 0 else "end")
			if mode == "heights" and float(piece["high"]) - float(piece["lowest"]) > SLOPED * tol:
				piece["slope"] = true
			pieces.append(piece)
	else:
		pieces = _runs(list, tol)
	return _merged(pieces, tol)


## The piece of [param list] over [code][a, b][/code]: its level, and how far
## its middle moves ("high", "lowest"), with "after" what it begins at.
func _piece(list: PackedFloat64Array, a: float, b: float, after: String) -> Dictionary:
	var span: float = b - a
	var high: float = -1.0e9
	var lowest: float = 1.0e9
	var peak_at: float = a
	var low_at: float = a
	for n: int in 11:
		var at: float = a + span * (0.1 + 0.8 * float(n) / 10.0)
		var value: float = _at(list, at)
		if value > high:
			high = value
			peak_at = at
		if value < lowest:
			lowest = value
			low_at = at
	return {"from": a, "to": b, "level": _level(list, a, b), "high": high, "lowest": lowest,
		"peak_at": peak_at, "low_at": low_at, "after": after, "span": span,
		"start": _at(list, a), "end": _at(list, b)}


## [param list] with no steps read, in runs: each tenth joins the run before
## while within [param tol] of its median. Runs of two or more are levels; a
## lone tenth between them is part of a slope (heights) or a tier of its own
## (widths).
func _runs(list: PackedFloat64Array, tol: float) -> Array:
	var count: int = list.size()
	var runs: Array = []
	var start: int = 0
	var held: Array[float] = [list[0]]
	for n: int in range(1, count):
		var sorted_: Array[float] = held.duplicate()
		sorted_.sort()
		if absf(list[n] - sorted_[sorted_.size() / 2]) <= tol:
			held.append(list[n])
		else:
			runs.append(Vector2i(start, n - 1))
			start = n
			held = [list[n]]
	runs.append(Vector2i(start, count - 1))
	var at := func(n: int) -> float:
		return float(n) / float(count - 1)
	# Lone tenths in a row are one slope, along a long thing.
	var kinds: Array = []
	for run: Vector2i in runs:
		kinds.append("level" if run.y > run.x or mode == "widths" or runs.size() == 1
			else "slope")
	var pieces: Array = []
	var n: int = 0
	while n < runs.size():
		var run: Vector2i = runs[n]
		if kinds[n] == "slope":
			var last: int = n
			while last + 1 < runs.size() and kinds[last + 1] == "slope":
				last += 1
			var a: float = at.call((runs[n - 1] as Vector2i).y) if n > 0 else 0.0
			var b: float = at.call((runs[last + 1] as Vector2i).x) if last + 1 < runs.size() \
				else 1.0
			var piece: Dictionary = _piece(list, a, b, "slope")
			piece["slope"] = true
			pieces.append(piece)
			n = last + 1
			continue
		var a: float = 0.0
		if n > 0:
			a = at.call(run.x) if kinds[n - 1] == "slope" else \
				(at.call((runs[n - 1] as Vector2i).y) + at.call(run.x)) / 2.0
		var b: float = 1.0
		if n + 1 < runs.size():
			b = at.call(run.y) if kinds[n + 1] == "slope" else \
				(at.call(run.y) + at.call((runs[n + 1] as Vector2i).x)) / 2.0
		var values_: Array[float] = []
		for k: int in range(run.x, run.y + 1):
			values_.append(list[k])
		values_.sort()
		var piece: Dictionary = _piece(list, a, b, "jump" if n > 0 else "end")
		piece["level"] = values_[values_.size() / 2]
		pieces.append(piece)
		n += 1
	return pieces


## [param pieces] with neighbouring levels within [param tol] made one, the
## closest pair first, so long as all they join stay within half again of it.
## Each joined level is its parts' median by length; "bands" counts the steps
## read that it joined over.
func _merged(pieces: Array, tol: float) -> Array:
	for piece: Dictionary in pieces:
		piece["members"] = [[float(piece["level"]), float(piece["span"])]]
		piece["bands"] = 0
	while true:
		var best: int = -1
		var gap: float = 1.0e9
		for n: int in pieces.size() - 1:
			var a: Dictionary = pieces[n]
			var b: Dictionary = pieces[n + 1]
			if a.get("slope", false) or b.get("slope", false):
				continue
			var apart: float = absf(float(a["level"]) - float(b["level"]))
			if apart > tol or apart >= gap:
				continue
			var all: Array = (a["members"] as Array) + (b["members"] as Array)
			var high: float = -1.0e9
			var low: float = 1.0e9
			for one: Array in all:
				high = maxf(high, float(one[0]))
				low = minf(low, float(one[0]))
			if high - low > 1.5 * tol:
				continue
			best = n
			gap = apart
		if best < 0:
			break
		var a: Dictionary = pieces[best]
		var b: Dictionary = pieces[best + 1]
		var joined: Array = (a["members"] as Array) + (b["members"] as Array)
		a["members"] = joined
		a["to"] = b["to"]
		a["span"] = float(a["to"]) - float(a["from"])
		a["level"] = _weighted_median(joined)
		a["bands"] = int(a["bands"]) + int(b["bands"]) + (1 if str(b["after"]) == "step" else 0)
		a["end"] = b["end"]
		pieces.remove_at(best + 1)
	return pieces


## The median of [code][value, weight][/code] pairs by weight.
static func _weighted_median(pairs: Array) -> float:
	var sorted_: Array = pairs.duplicate()
	sorted_.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var total: float = 0.0
	for one: Array in sorted_:
		total += float(one[1])
	var run: float = 0.0
	for one: Array in sorted_:
		run += float(one[1])
		if run >= total / 2.0:
			return float(one[0])
	return float((sorted_[sorted_.size() - 1] as Array)[0])


## The plates a building's face needs for [member storeys] at microscale; 0
## for none said or a tower's many.
func storeys_need() -> float:
	if storeys <= 0 or storeys > FEW_STOREYS:
		return 0.0
	return float(PLINTH + storeys * STOREY + CORNICE)


## The height its face is read at, in plates, before any stretch: a long
## thing's main block (the highest level a quarter of its length or more), a tall thing's whole height.
func face_plates() -> float:
	if mode == "widths":
		return unit * PLATES_PER_STUD
	# Its main block, where its storeys are counted: the highest level that runs
	# MAIN_BLOCK of its length or more (the Guggenheim's rotunda, not the lower
	# annex beside it as long; its set stretches the rotunda 20 read to 32);
	# else its longest level. A slope (a dome, a curve) is never its face.
	var main: float = -1.0
	var longest_: float = 0.0
	var longest_level: float = 0.0
	for piece: Dictionary in levels(values):
		if piece.get("slope", false):
			continue
		var span: float = float(piece["span"])
		if span >= MAIN_BLOCK - 0.0001:
			main = maxf(main, float(piece["level"]))
		if span > longest_:
			longest_ = span
			longest_level = float(piece["level"])
	var level_: float = main if main >= 0.0 else longest_level
	if main < 0.0 and longest_ <= 0.0:
		level_ = _level(values, 0.0, 1.0)
	return level_ * unit * PLATES_PER_STUD


## How many times its heights stretch so its storeys fit: 1 when they fit as
## read, at most MOST_STRETCH.
func _stretched() -> float:
	var need: float = storeys_need()
	var read_: float = roundf(face)
	if need <= 0.0 or read_ <= 0.0 or need <= read_:
		return 1.0
	return minf(MOST_STRETCH, need / read_)


## [param share] of the reading's measure up, as plates at its size: up to
## its face stretched, and above it raised by the plates the face gained, so
## a dome or a tower keeps its own height on the taller storeys.
func _plates(share: float) -> float:
	var read_: float = share * unit * PLATES_PER_STUD
	if stretch <= 1.0 or read_ <= face:
		return roundf(read_ * stretch)
	return roundf(read_ + face * (stretch - 1.0))


## "22 plates", or "22 plates (15 read)" when stretched.
func _plates_said(share: float) -> String:
	var built: float = _plates(share)
	if stretch <= 1.0:
		return "%s plates" % _n(built)
	return "%s plates (%s read)" % [_n(built), _n(roundf(share * unit * PLATES_PER_STUD))]


## A tall thing's tiers at its size, ground first: each {"y0", "y1"} plates,
## {"left", "right"} studs from the outline's leftmost edge as the photograph
## shows it, and "in" (studs it stepped in by, on "side", from the tier under
## it). Each tier is a level of the reading, so a setback under the tolerance
## is no tier. Each setback goes on the side the reading puts it, not centred:
## the first tier's edges are where they are, and each after moves only the
## side named, by the whole studs its width changed. A tier that does not begin
## at a step read (the reading narrows with none said) steps in on both sides.
func tiers() -> Array:
	var out: Array = []
	if mode != "widths":
		return out
	var parts: Array = levels(values)
	if parts.size() < 2 and steps.is_empty():
		return out
	var left: float = 0.0
	var right: float = 0.0
	var tall: float = unit * PLATES_PER_STUD * stretch
	for n: int in parts.size():
		var part: Dictionary = parts[n]
		var wide: float = maxf(1.0, roundf(float(part["level"]) * unit))
		var stepped: float = 0.0
		var on: String = ""
		if n == 0:
			right = wide
		else:
			stepped = (right - left) - wide
			on = _side_at(float(part["from"]))
			match on:
				"left":
					left += stepped
				"right":
					right -= stepped
				_:
					var half: float = float(int(stepped / 2.0))
					left += half
					right -= stepped - half
		out.append({"y0": roundf(float(part["from"]) * tall), "y1": roundf(float(part["to"])
			* tall), "left": left, "right": right, "in": stepped, "side": on,
			"bands": int(part["bands"])})
	var least: float = 0.0
	for one: Dictionary in out:
		least = minf(least, float(one["left"]))
	for one: Dictionary in out:
		one["left"] = float(one["left"]) - least
		one["right"] = float(one["right"]) - least
	return out


## The side the step read at [param share] steps in on; "both" where none was
## read there.
func _side_at(share: float) -> String:
	for n: int in steps.size():
		if absf(steps[n] - share) < 0.0001:
			return step_sides[n]
	return "both"


## [param from_left] studs from the photograph's left of an outline [param
## whole] studs across, as the model's coordinate along [method axis].
func _coord(from_left: float, whole: float) -> float:
	return whole - from_left if reversed() else from_left


## "x 3 to 12" for a span [param a] to [param b] studs from the photograph's
## left of an outline [param whole] studs across.
func _span_said(a: float, b: float, whole: float) -> String:
	var one: float = _coord(a, whole)
	var two: float = _coord(b, whole)
	return "%s %s to %s" % [axis(), _n(snappedf(minf(one, two), 0.5)),
		_n(snappedf(maxf(one, two), 0.5))]


## The reading as a session reads it back: what was read.
func said_read() -> String:
	var what: String = ("its top along its length, from the %s" % side) if mode == "heights" \
		else ("its width up its height, from the %s" % side)
	var parts := PackedStringArray([what])
	if not bottoms.is_empty():
		parts.append("its underside")
	if not steps.is_empty():
		parts.append("%d %s" % [steps.size(), ("steps" if mode == "heights" else "setbacks")
			if steps.size() != 1 else ("step" if mode == "heights" else "setback")])
	if not breaks.is_empty():
		parts.append("%d %s breaking it" % [breaks.size(), "masses" if breaks.size() != 1
			else "mass"])
	if storeys > 0:
		parts.append("%d storey%s" % [storeys, "" if storeys == 1 else "s"])
	if plan != "rectangle":
		parts.append("%s plan" % _plan_said())
	return ", ".join(parts) + ((" (off \"%s\")" % picture) if not picture.is_empty() else "")


## Its size, as built: "54 studs long and 25 across, 30 plates at its highest"
## or "168 plates tall (67 studs), 16 studs at its widest and 9 deep".
func said_size() -> String:
	if mode == "heights":
		# Its highest as the levels say it, not a tenth they made one with its
		# neighbours.
		var high: float = 0.0
		for piece: Dictionary in levels(values):
			high = maxf(high, float(piece["high"]) if piece.get("slope", false)
				else float(piece["level"]))
		return "%s studs long and %s across, %s plates at its highest" % [_n(roundf(unit)),
			_n(across), _n(_plates(high))]
	return "%s plates tall (%s studs), %s at its widest and %s deep" % [
		_n(_plates(1.0)), _n(roundf(unit * stretch)), _studs(widest), _n(depth)]


## "1 stud" or "6 studs".
static func _studs(value: float) -> String:
	return "%s stud%s" % [_n(value), "" if is_equal_approx(value, 1.0) else "s"]


## The sizes to build to, as the answer says them: the outline in levels of
## studs and plates, a tall thing's tiers with each setback on its side, what
## breaks it as masses of their own, its storeys' height, and its plan.
func said_sizes() -> String:
	var lines := PackedStringArray()
	var tall: String = _said_storeys()
	if not tall.is_empty():
		lines.append(tall)
	if mode == "heights":
		lines.append(_said_heights())
	else:
		lines.append(_said_widths())
	if not breaks.is_empty():
		lines.append(_said_breaks())
	var ground: String = _said_ground()
	if not ground.is_empty():
		lines.append(ground)
	lines.append(_said_plan())
	return "\n\n".join(lines)


## What its storeys need beside the height read, and the stretch; "" with
## none said.
func _said_storeys() -> String:
	if storeys <= 0:
		return ""
	var read_: float = roundf(face)
	if storeys > FEW_STOREYS:
		return ("Its %d storeys are a tower's floors: at this size they are texture, a plate or a "
			+ "grille's line each, so its height is its proportion's, %s plates.") % [storeys,
				_n(read_)]
	var need: float = storeys_need()
	var many: String = ("its storey needs" if storeys == 1 else "its %d storeys need" % storeys)
	var how: String = ("a plinth of %d, %d for each storey, a brick of windows with its sill and "
		+ "its floor's line, and %d for its cornice, parapet or balustrade") % [PLINTH, STOREY,
			CORNICE]
	if stretch <= 1.0:
		return "Height for its features: %s %s plates at this size, %s. Its face is %s plates as read: room for %s." % [
			many, _n(need), how, _n(read_), "it" if storeys == 1 else "each"]
	var built: float = roundf(read_ * stretch)
	var said: String = ("Height for its features: %s %s plates at this size, %s. " % [many,
		_n(need), how]
		+ "Its face is %s plates as read, so it is stretched %s times, to %s plates, and every "
			% [_n(read_), _n(snappedf(stretch, 0.1)), _n(built)]
		+ "height up to it with it")
	if mode == "heights" and most() * unit * PLATES_PER_STUD > face + 0.5:
		said += ("; what stands above its face (a dome, a tower, a pediment) keeps its own height "
			+ "and stands on it, %s plates higher than read") % _n(built - read_)
	said += (". The height read is beside each: at microscale an expert stretches a building's "
		+ "storeys before losing one, a balcony or a portico, and keeps what crowns them at its "
		+ "own size. Its length and plan stay as read.")
	if need > built + 0.5:
		said += (" That is the most an expert stretches it: build each storey %d plates (a brick "
			+ "and a plate) to fit them.") % LEAST_STOREY
	return said


func _said_heights() -> String:
	var lines := PackedStringArray()
	var tol: float = tolerance()
	lines.append(("Its top along %s, in levels (%s studs long; the photograph's left at %s %s; "
		+ "tenths within %s plates of each other are one level, and a level ends only where it "
		+ "steps):") % [axis(), _n(roundf(unit)), axis(), "0" if not reversed() else _n(roundf(
			unit)), _n(roundf(tol * unit * PLATES_PER_STUD))])
	lines.append_array(_said_levels(levels(values)))
	# An underside on the ground all along says nothing a level would.
	if not bottoms.is_empty() and Array(bottoms).max() > GROUNDED:
		lines.append("Its underside along %s, in levels:" % axis())
		lines.append_array(_said_levels(levels(bottoms, false)))
	return "\n".join(lines)


## Each piece of [param pieces] as a line: "  x 0 to 18: 22 plates" or a
## slope's ends and its highest.
func _said_levels(pieces: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var bands: int = 0
	for piece: Dictionary in pieces:
		var where: String = _span_said(float(piece["from"]) * unit, float(piece["to"]) * unit,
			unit)
		bands += int(piece.get("bands", 0))
		if not piece.get("slope", false):
			out.append("  %s: %s" % [where, _plates_said(float(piece["level"]))])
			continue
		var a: float = float(piece["start"])
		var b: float = float(piece["end"])
		var line: String = "  %s: a slope or a curve, %s at %s %s" % [where, _plates_said(a),
			axis(), _n(snappedf(_coord(float(piece["from"]) * unit, unit), 0.5))]
		var peak: float = float(piece["high"])
		var low: float = float(piece["lowest"])
		if peak > maxf(a, b) + tolerance() * 0.5:
			line += ", highest %s at %s %s" % [_plates_said(peak), axis(), _n(snappedf(
				_coord(float(piece["peak_at"]) * unit, unit), 0.5))]
		elif low < minf(a, b) - tolerance() * 0.5:
			line += ", lowest %s at %s %s" % [_plates_said(low), axis(), _n(snappedf(
				_coord(float(piece["low_at"]) * unit, unit), 0.5))]
		line += ", %s at %s %s (built with slopes or curves, not steps)" % [_plates_said(b),
			axis(), _n(snappedf(_coord(float(piece["to"]) * unit, unit), 0.5))]
		out.append(line)
	if bands > 0:
		out.append("  (%d of the steps read %s under a brick at this size: one level, a band "
			% [bands, "is" if bands == 1 else "are"] + "or a line of tiles, not a step.)")
	return out


func _said_widths() -> String:
	var lines := PackedStringArray()
	var tall: float = unit * PLATES_PER_STUD * stretch
	var levels_: Array = tiers()
	var whole: float = widest
	for one: Dictionary in levels_:
		whole = maxf(whole, float(one["right"]))
	if levels_.is_empty():
		var wide: float = maxf(1.0, roundf(float((levels(values)[0] as Dictionary)["level"])
			* unit))
		lines.append("Up its height (%s), one level: %s studs wide, %s." % [
			_plates_said(1.0), _n(wide), _span_said(0.0, wide, wide)])
		return "\n".join(lines)
	var said := PackedStringArray()
	var bands: int = 0
	for n: int in levels_.size():
		var tier: Dictionary = levels_[n]
		bands += int(tier.get("bands", 0))
		var line: String = "%d. y %s to %s, %s plates tall: %s studs wide, %s" % [n + 1,
			_n(tier["y0"]), _n(tier["y1"]), _n(float(tier["y1"]) - float(tier["y0"])),
			_n(float(tier["right"]) - float(tier["left"])), _span_said(float(tier["left"]),
				float(tier["right"]), whole)]
		if n > 0:
			var stepped: float = float(tier["in"])
			var on: String = str(tier["side"])
			if is_zero_approx(stepped):
				line += " (the setback is under a stud at this size: a band, not a step)"
			elif on == "both" and absf(stepped) >= 2.0:
				line += " (%s %s on its %s side and %s on its %s)" % [
					"in" if stepped > 0.0 else "out", _n(absf(float(int(stepped / 2.0)))),
					model_side("left"), _n(absf(stepped - float(int(stepped / 2.0)))),
					model_side("right")]
			elif on == "both":
				# One stud cannot be split between two sides on the grid.
				line += " (%s 1 stud on its %s side: one stud does not split between both)" % [
					"in" if stepped > 0.0 else "out", model_side("right")]
			else:
				line += " (%s %s stud%s on its %s side, the photograph's %s; the %s stays)" % [
					"in" if stepped > 0.0 else "out", _n(absf(stepped)),
					"" if is_equal_approx(absf(stepped), 1.0) else "s", model_side(on), on,
					model_side("right" if on == "left" else "left")]
		said.append(line)
	lines.append(("Up its height (%s plates up y%s; %s from the photograph's left, %s %s at its "
		+ "left edge), in %d tiers, ground first, each setback on the side the reading puts it "
		+ "(widths within %s of each other are one tier):\n") % [_n(roundf(tall)),
			" (%s read)" % _n(roundf(unit * PLATES_PER_STUD)) if stretch > 1.0 else "", axis(),
			axis(), "0" if not reversed() else _n(whole), levels_.size(), _studs(roundf(
				tolerance() * unit))]
		+ "\n".join(Array(said).map(func(s: String) -> String: return "  " + s)))
	if bands > 0:
		lines.append(("%d of the setbacks read %s under a stud at this size, so the tiers either "
			+ "side are one.") % [bands, "is" if bands == 1 else "are"])
	if unsided > 0:
		lines.append(("%d of its setbacks came with no side, so each was taken as both "
			+ "sides evenly, which reads as a wedding cake where the real thing steps in "
			+ "on one face: give each {\"at\": share, \"side\": \"left\", \"right\" or "
			+ "\"both\"} as the photograph shows it.") % unsided)
	return "\n".join(lines)


func _said_breaks() -> String:
	var whole: float = unit if mode == "heights" else widest
	if mode == "widths":
		for one: Dictionary in tiers():
			whole = maxf(whole, float(one["right"]))
	var said := PackedStringArray()
	for one: Dictionary in breaks:
		var a: float = float(one["from"]) * unit
		var b: float = float(one["to"]) * unit
		said.append("  %s: %s (%s studs), y %s to %s plates (%s tall)%s" % [one["name"],
			_span_said(a, b, whole), _n(snappedf(b - a, 0.5)), _n(_plates(float(one["bottom"]))),
			_n(_plates(float(one["top"]))), _n(_plates(float(one["top"])) - _plates(float(
				one["bottom"]))), ", on the ground" if float(one["bottom"]) <= GROUNDED else ""])
	return ("What breaks the outline, each a mass of its own at its own size, built its own way "
		+ "and not part of the body's outline above:\n" + "\n".join(said))


## Where a long thing's body is read down to the ground under what holds it
## up: over a break that stands on the ground, or meeting it at places with
## its underside off it between. "" when neither.
func _said_ground() -> String:
	# A building's breaks on the ground (its steps, a terrace) stand before its
	# body, which goes down to the ground: the Capitol's portico steps were
	# told to be read as an underside. Wheels, tracks and legs are a vehicle's
	# or a machine's, which says no storeys.
	if mode != "heights" or storeys > 0:
		return ""
	var count: int = values.size()
	var said := PackedStringArray()
	for one: Dictionary in breaks:
		if float(one["bottom"]) > GROUNDED:
			continue
		var low: float = 1.0e9
		for n: int in count:
			var share: float = float(n) / float(count - 1)
			if share >= float(one["from"]) and share <= float(one["to"]):
				low = minf(low, bottoms[n] if not bottoms.is_empty() else 0.0)
		if low <= GROUNDED and low < float(one["top"]):
			said.append(one["name"])
	if not said.is_empty():
		return ("Its body is read down to the ground over %s: read its underside there, "
			% " and ".join(said) + "where the body stops above it (bottoms=), not the ground. "
			+ "A body filled down to the ground over its wheels or tracks reads as a block on "
			+ "them.")
	if bottoms.is_empty() or not breaks.is_empty():
		return ""
	var touching: Array = []
	var lifted: bool = false
	for n: int in count:
		if bottoms[n] <= GROUNDED:
			touching.append(n)
		elif not touching.is_empty() and n < count - 1:
			lifted = true
	if touching.is_empty() or not lifted:
		return ""
	var places := PackedStringArray()
	for n: int in touching:
		places.append("%s %s" % [axis(), _n(snappedf(_coord(float(n) / float(count - 1) * unit,
			unit), 0.5))])
	return ("Its underside meets the ground at %s and is off it between: if what stands on "
		% ", ".join(places) + "the ground there is wheels, tracks or legs, read them as breaks=, "
		+ "masses of their own, and the body's underside over them (%s plates up where it is "
		% _n(_plates(Array(bottoms).max())) + "highest).")


func _said_plan() -> String:
	var wide: float = across if mode == "heights" else widest
	var long: float = roundf(unit) if mode == "heights" else depth
	var arms: String = ""
	if ARMED.has(plan):
		arms = ", its arms about %s studs thick" % _n(maxf(1.0, roundf((arm if arm > 0.0
			else ARM) * minf(wide, long))))
	if mode == "heights":
		return "Its plan from above: %s, %s studs along %s and %s across%s." % [
			_plan_said(), _n(long), axis(), _n(wide), arms]
	return "Its plan from above: %s, %s studs across its widest tier and %s deep%s." % [
		_plan_said(), _n(wide), _n(depth), arms]


func _plan_said() -> String:
	if plan in ["rectangle", "square"]:
		return "a %s" % plan
	if plan == "round":
		return "round"
	return "an %s" % plan if plan in ["H", "L", "U"] else "a %s" % plan


static func _n(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.1))
