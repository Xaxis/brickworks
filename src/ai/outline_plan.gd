## The real thing's outline, read off a photograph of it before the first
## build, and handed back as the sizes to build to.
##
## design21 handed the first mass as a solid to send as it is, and lost its
## screen: the four sessions that built the solid it named (an extrude down to
## the ground, tiers a stud each side apart) lost both orders head to head, "a
## block on wheels", "a wedding cake"; the four that read the outline and
## built their own way won 7 of 8. A measure helped where a solid did not.
##
## So the answer is sizes, and no solid: the outline in studs and plates at
## each tenth, each setback where the reading puts it, on the side it steps in
## on, and how tall each tier is, and the plan from above. A long thing's body
## is read over what holds it up, and what breaks its outline (wheels, tracks,
## a header, a blade, a guard) is read as masses of their own, so the body is
## not filled down to the ground under them.
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
## What studs= can measure: the model's longest side, its foot as a brief gives
## it ("fitting in about 12 x 13 studs"), or the part the outline reads.
const MEASURES: Array[String] = ["longest", "footprint", "read"]

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
## How the size was set, as the answer says it.
var sized_by: String = ""


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
	var forms: String = ("studs= names what it measures: {\"longest\": 54}, the model's "
		+ "longest side; {\"footprint\": [12, 13]}, its foot as a brief gives it (\"fitting in "
		+ "about 12 x 13 studs\"); or {\"read\": 6}, the part the outline reads (a long "
		+ "thing's length, a tall thing's widest width as the photograph shows it)")
	if not raw is Dictionary or (raw as Dictionary).size() != 1:
		return {"error": "%s. %s says none, so it was not taken." % [forms,
			JSON.stringify(raw)]}
	var measure: String = str((raw as Dictionary).keys()[0]).strip_edges().to_lower()
	if not MEASURES.has(measure):
		return {"error": "%s. \"%s\" is not one, so it was not taken." % [forms, measure]}
	var value: Variant = (raw as Dictionary).values()[0]
	var numbers: Array[float] = []
	var listed: Array = (value as Array) if value is Array else [value]
	for one: Variant in listed:
		if (one is float or one is int) and float(one) > 0.0:
			numbers.append(float(one))
	if numbers.is_empty() or numbers.size() > (2 if measure == "footprint" else 1):
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
## says none. Sets [member unit] and the rest, and [member sized_by].
func fit(studs: Dictionary, planned: float) -> void:
	var measure: String = str(studs.get("measure", ""))
	var numbers: Array = studs.get("numbers", [])
	var top: float = most()
	var other: float = 0.0
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
		"footprint":
			var big: float = Array(numbers).max()
			var small: float = Array(numbers).min()
			if mode == "heights":
				unit = big
				other = small if numbers.size() == 2 else 0.0
			else:
				# The face the photograph shows is the wide one unless deep= says the
				# thing is deeper than it is wide.
				var seen: float = small if deep > 1.0 and numbers.size() == 2 else big
				unit = seen / top
				other = (big if seen == small else small) if numbers.size() == 2 else seen
			var said := PackedStringArray()
			for n: float in numbers:
				said.append(_n(n))
			sized_by = "studs= {\"footprint\": [%s]}: %s studs at its foot" % [", ".join(said),
				" x ".join(said)]
		_:
			unit = maxf(1.0, planned) / maxf(1.0, top)
			sized_by = "the scale above: %s studs along its longest side" % _n(snappedf(
				maxf(1.0, planned), 0.1))
	unit = maxf(1.0, unit)
	if mode == "heights":
		var wide: float = other if other > 0.0 else (deep if deep > 0.0 else DEEP) * unit
		across = maxf(1.0, roundf(wide))
	else:
		widest = maxf(1.0, roundf(top * unit))
		var ratio: float = deep if deep > 0.0 else 1.0
		depth = maxf(1.0, roundf(other if other > 0.0 else widest * ratio))


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


## The stretches between steps, ground (or the photograph's left) first: each
## {"from", "to"} shares and its "level", the reading's share there.
func stretches() -> Array:
	var edges: Array[float] = [0.0]
	for one: float in steps:
		edges.append(one)
	edges.append(1.0)
	var out: Array = []
	for n: int in edges.size() - 1:
		out.append({"from": edges[n], "to": edges[n + 1],
			"level": _level(values, edges[n], edges[n + 1])})
	return out


## A tall thing's tiers at its size, ground first: each {"y0", "y1"} plates,
## {"left", "right"} studs from the outline's leftmost edge as the photograph
## shows it, and "in" (studs it stepped in by, on "side", from the tier under
## it). Each setback goes on the side the reading puts it, not centred: the
## first tier's edges are where they are, and each after moves only the side
## named, by the whole studs its width changed.
func tiers() -> Array:
	var out: Array = []
	if mode != "widths" or steps.is_empty():
		return out
	var parts: Array = stretches()
	var left: float = 0.0
	var right: float = 0.0
	var tall: float = unit * PLATES_PER_STUD
	for n: int in parts.size():
		var part: Dictionary = parts[n]
		var wide: float = maxf(1.0, roundf(float(part["level"]) * unit))
		var stepped: float = 0.0
		var on: String = ""
		if n == 0:
			right = wide
		else:
			stepped = (right - left) - wide
			on = step_sides[n - 1]
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
			* tall), "left": left, "right": right, "in": stepped, "side": on})
	var least: float = 0.0
	for one: Dictionary in out:
		least = minf(least, float(one["left"]))
	for one: Dictionary in out:
		one["left"] = float(one["left"]) - least
		one["right"] = float(one["right"]) - least
	return out


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
	if plan != "rectangle":
		parts.append("%s plan" % _plan_said())
	return ", ".join(parts) + ((" (off \"%s\")" % picture) if not picture.is_empty() else "")


## Its size, as built: "54 studs long and 25 across, 30 plates at its highest"
## or "168 plates tall (67 studs), 16 studs at its widest and 9 deep".
func said_size() -> String:
	if mode == "heights":
		return "%s studs long and %s across, %s plates at its highest" % [_n(roundf(unit)),
			_n(across), _n(roundf(most() * unit * PLATES_PER_STUD))]
	return "%s plates tall (%s studs), %s at its widest and %s deep" % [
		_n(roundf(unit * PLATES_PER_STUD)), _n(roundf(unit)), _studs(widest), _n(depth)]


## "1 stud" or "6 studs".
static func _studs(value: float) -> String:
	return "%s stud%s" % [_n(value), "" if is_equal_approx(value, 1.0) else "s"]


## The sizes to build to, as the answer says them: the outline at each tenth
## in studs and plates, its stretches or tiers and where each steps, what
## breaks it as masses of their own, and its plan.
func said_sizes() -> String:
	var lines := PackedStringArray()
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


func _said_heights() -> String:
	var lines := PackedStringArray()
	var plates: float = unit * PLATES_PER_STUD
	lines.append("At each tenth of its length (%s studs along %s; the photograph's left at %s %s):"
		% [_n(roundf(unit)), axis(), axis(), "0" if not reversed() else _n(roundf(unit))])
	var count: int = values.size()
	for n: int in count:
		var share: float = float(n) / float(count - 1)
		var line: String = "  %s, %s %s: top %s plates" % [_tenth(n, count), axis(), _n(
			snappedf(_coord(share * unit, unit), 0.5)), _n(roundf(values[n] * plates))]
		if not bottoms.is_empty():
			line += ", underside %s" % _n(roundf(bottoms[n] * plates))
		lines.append(line)
	if not steps.is_empty():
		var parts: Array = stretches()
		var said := PackedStringArray()
		for n: int in parts.size():
			var part: Dictionary = parts[n]
			said.append("%s: top %s plates" % [_span_said(float(part["from"]) * unit,
				float(part["to"]) * unit, unit), _n(roundf(float(part["level"]) * plates))])
		lines.append("Its top steps %d %s, in %d stretches, each level along its own "
			% [steps.size(), "times" if steps.size() != 1 else "time", parts.size()]
			+ "length: %s." % "; ".join(said))
	return "\n".join(lines)


func _said_widths() -> String:
	var lines := PackedStringArray()
	var tall: float = unit * PLATES_PER_STUD
	var levels: Array = tiers()
	var whole: float = widest
	for one: Dictionary in levels:
		whole = maxf(whole, float(one["right"]))
	lines.append("At each tenth of its height (%s plates up y; %s from the photograph's left, "
		% [_n(roundf(tall)), axis()] + "%s %s at its left edge):" % [axis(),
			"0" if not reversed() else _n(whole)])
	var count: int = values.size()
	for n: int in count:
		var share: float = float(n) / float(count - 1)
		var line: String = "  %s, y %s: " % [_tenth(n, count), _n(roundf(share * tall))]
		if levels.is_empty():
			var wide: float = snappedf(values[n] * unit, 0.5)
			var left: float = (whole - wide) / 2.0
			line += "%s studs wide, %s" % [_n(wide), _span_said(left, left + wide, whole)]
		else:
			# The tier this tenth is in: the last whose foot is at or under it.
			var tier: Dictionary = levels[0]
			for one: Dictionary in levels:
				if share * tall >= float(one["y0"]) - 0.0001:
					tier = one
			line += "%s studs wide, %s" % [_n(float(tier["right"]) - float(tier["left"])),
				_span_said(float(tier["left"]), float(tier["right"]), whole)]
		lines.append(line)
	if not levels.is_empty():
		var said := PackedStringArray()
		for n: int in levels.size():
			var tier: Dictionary = levels[n]
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
		lines.append("In %d tiers, ground first, each setback on the side the reading puts it:\n"
			% levels.size() + "\n".join(Array(said).map(func(s: String) -> String:
				return "  " + s)))
		if unsided > 0:
			lines.append(("%d of its setbacks came with no side, so each was taken as both "
				+ "sides evenly, which reads as a wedding cake where the real thing steps in "
				+ "on one face: give each {\"at\": share, \"side\": \"left\", \"right\" or "
				+ "\"both\"} as the photograph shows it.") % unsided)
	return "\n".join(lines)


func _said_breaks() -> String:
	var plates: float = unit * PLATES_PER_STUD
	var whole: float = unit if mode == "heights" else widest
	if mode == "widths":
		for one: Dictionary in tiers():
			whole = maxf(whole, float(one["right"]))
	var said := PackedStringArray()
	for one: Dictionary in breaks:
		var a: float = float(one["from"]) * unit
		var b: float = float(one["to"]) * unit
		said.append("  %s: %s (%s studs), y %s to %s plates (%s tall)%s" % [one["name"],
			_span_said(a, b, whole), _n(snappedf(b - a, 0.5)), _n(roundf(float(one["bottom"])
				* plates)), _n(roundf(float(one["top"]) * plates)), _n(roundf((float(one["top"])
				- float(one["bottom"])) * plates)), ", on the ground"
				if float(one["bottom"]) <= GROUNDED else ""])
	return ("What breaks the outline, each a mass of its own, built its own way and not part "
		+ "of the body's outline above:\n" + "\n".join(said))


## Where a long thing's body is read down to the ground under what holds it
## up: over a break that stands on the ground, or meeting it at places with
## its underside off it between. "" when neither.
func _said_ground() -> String:
	if mode != "heights":
		return ""
	var plates: float = unit * PLATES_PER_STUD
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
		% _n(roundf(Array(bottoms).max() * plates)) + "highest).")


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


## "3/10" for sample [param n] of [param count].
static func _tenth(n: int, count: int) -> String:
	if count == 11:
		return "%d/10" % n
	return "%d/%d" % [n, count - 1]


static func _n(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.1))
