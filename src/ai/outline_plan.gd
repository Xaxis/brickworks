## The real thing's outline, read off a photograph of it before the first
## build, and the first mass laid to it.
##
## design16 to design20 handed a session a measure of its model after it was
## built, against the real thing: its masses, its features' shares, a
## photograph beside it, and at last its outline laid over the real one's.
## Each time the session kept its model. design20's Charger was told its body
## reached the ground between its wheels, 4 plates at 6 of 11 places, and
## nothing moved; its Burj matched the outline at every tenth and the judge
## still called it "stubby, a few big steps", which is the steps and the plan,
## not the outline at a tenth.
##
## So the outline comes first. plan_scale takes what the session reads off a
## photograph (find_reference) taken square from one side: the top's height
## at each tenth of a long thing's length, with its underside, or a tall
## thing's width at each tenth of its height; where it steps (each setback,
## or each step along a roofline) and its plan from above (round, a Y, a T, a
## cross...). It is scaled to the size the model is built at, and the app's
## own shapes take it as their profile: an extrude's top and underside, a
## revolve's radius, a stack of tiers, a prism's storeys. The first mass then
## has the outline, and no edit is asked for.
##
## The session decides what the mass is and what goes on it: nothing is laid
## for it unasked. Nothing here knows what a car or a tower is.
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
## How thick a plan's arms are, a share of its width: a Y's wings are thicker,
## as a tower's three wings round its core are.
const ARM := 0.34
const Y_ARM := 0.42

## The fewest and most samples a reading takes, evenly spaced, both ends in.
const FEWEST := 5
const MOST := 41
## The most a share may be: a tower's height is many of its widths.
const LARGEST := 20.0
## The most steps a reading may give.
const MOST_STEPS := 40
## A long thing's width across, a share of its length, when nothing says it:
## a car's is about 0.4.
const DEEP := 0.4
## Studs to plates: a stud is 20 LDU across, a plate 8 up.
const PLATES_PER_STUD := 2.5
## A smooth widths reading is laid in tiers this many plates tall: a course.
const COURSE := 3.0

var side: String = ""
## "heights" (a long thing: the top at each sample along its length, shares
## of the length) or "widths" (a tall thing: its width at each sample up its
## height, shares of the height).
var mode: String = ""
var values := PackedFloat64Array()
## With heights, the underside at each sample, or empty.
var bottoms := PackedFloat64Array()
## Where the outline steps, shares along the reading's own way (along the
## length for heights, up the height for widths), rising; empty for a
## smooth outline.
var steps := PackedFloat64Array()
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

## Its size, once [method sized]: a long thing's length and width across in
## studs; a tall thing's height in plates and its widest width and depth in
## studs.
var length: float = 0.0
var across: float = 0.0
var height: float = 0.0
var widest: float = 0.0
var depth: float = 0.0


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
	if reading.values.size() > 0 and Array(reading.values).max() <= 0.0:
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
		var at: Variant = given["steps"]
		if not at is Array or (at as Array).size() > MOST_STEPS:
			reading.error = ("steps= is where the outline steps, as shares %s, lowest "
				% ("along its length" if reading.mode == "heights" else "up its height")
				+ "first: up to %d of them, each between 0 and 1." % MOST_STEPS)
			return reading
		var last: float = 0.0
		for one: Variant in at:
			if not (one is float or one is int) or float(one) <= 0.0 or float(one) >= 1.0 \
					or float(one) <= last:
				reading.error = ("steps= holds shares between 0 and 1, each past the one "
					+ "before (0.12 is a step an eighth of the way %s): %s is not one." % [
						"along" if reading.mode == "heights" else "up", str(one)])
				return reading
			last = float(one)
			reading.steps.append(last)
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


## The model's axis the reading runs along: a long thing's length, or a tall
## thing's width.
func axis() -> String:
	return "x" if side in ["front", "back"] else "z"


## Whether the photograph's left is the axis' far end: from the back or the
## right, the picture's left is the model's +x (or +z).
func reversed() -> bool:
	return side in ["back", "right"]


## Sized to be built at [param studs]: a long thing's length, or a tall
## thing's widest width, in studs; [param other] the footprint's other side
## (0 when not known).
func sized(studs: float, other: float = 0.0) -> void:
	if mode == "heights":
		length = maxf(1.0, studs)
		var wide: float = other if other > 0.0 else (deep if deep > 0.0 else DEEP) * length
		across = maxf(1.0, roundf(wide))
	else:
		var most: float = Array(values).max()
		widest = maxf(1.0, roundf(studs))
		height = widest / most * PLATES_PER_STUD
		var ratio: float = deep if deep > 0.0 else (other / studs if other > 0.0
			and plan == "rectangle" else 1.0)
		depth = maxf(1.0, roundf(widest * ratio))


## Sized by a scale's length along its longest side, [param studs]: a long
## thing's length, a tall thing's height (in studs, as plan_scale gives it).
func sized_by_longest(studs: float, other: float = 0.0) -> void:
	if mode == "heights":
		sized(studs, other)
	else:
		sized(maxf(1.0, roundf(studs * Array(values).max())), other)


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


## The reading as [[share along, share]...]: its samples, or with steps a
## level between each two (and each end), a jump at each step.
func _shape(list: PackedFloat64Array) -> Array:
	var out: Array = []
	if steps.is_empty():
		for n: int in list.size():
			out.append(Vector2(float(n) / float(list.size() - 1), list[n]))
		return out
	var edges: Array[float] = [0.0]
	for one: float in steps:
		edges.append(one)
	edges.append(1.0)
	for n: int in edges.size() - 1:
		var level: float = _level(list, edges[n], edges[n + 1])
		out.append(Vector2(edges[n], level))
		out.append(Vector2(edges[n + 1], level))
	return out


## A long thing's top, as an extrude's profile: [[studs along, plates up],
## ...] from [param start] over [param long] studs, its plates [param scale]
## times the length's share (the length's own when 0), the photograph's left
## at the low end unless it was taken from the back or the right.
func top_profile(start: float, long: float, scale: float = 0.0) -> Array:
	return _profile(values, start, long, scale)


## Its underside, the same way; empty when none was read.
func under_profile(start: float, long: float, scale: float = 0.0) -> Array:
	return [] if bottoms.is_empty() else _profile(bottoms, start, long, scale)


func _profile(list: PackedFloat64Array, start: float, long: float, scale: float) -> Array:
	var plates: float = scale if scale > 0.0 else long * PLATES_PER_STUD
	var out: Array = []
	for point: Vector2 in _shape(list):
		var along: float = point.x if not reversed() else 1.0 - point.x
		out.append([snappedf(start + along * long, 0.1), snappedf(point.y * plates, 0.1)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out


## A tall thing's tiers, as a tiers solid's levels: [[plates up, studs along
## x, studs along z], ...] over [param tall] plates, ground first; a step is
## two levels at one height. [param wide] is its widest width (its own when
## 0), [param deep_] its depth at that width. Each level stands at a whole
## plate, and a smooth reading changes only at a whole course. Each width
## keeps its base's evenness: a setback is a stud each side, as a set's is,
## so every tier stays centred on the studs of the one under it.
func levels(tall: float = 0.0, wide: float = 0.0, deep_: float = 0.0) -> Array:
	var high: float = tall if tall > 0.0 else height
	var most: float = Array(values).max()
	var widest_: float = maxf(1.0, roundf(wide if wide > 0.0 else high / PLATES_PER_STUD * most))
	var ratio: float = (deep_ / widest_) if deep_ > 0.0 \
		else (depth / widest if widest > 0.0 else 1.0)
	var deepest: float = maxf(1.0, roundf(widest_ * ratio))
	var out: Array = []
	var points: Array = []
	if steps.is_empty():
		# A smooth outline in courses, each as wide as the reading at its middle:
		# a level at every sample would be a slope the lattice reads as noise.
		var count: int = maxi(1, roundi(high / COURSE))
		for n: int in count:
			var share: float = _at(values, (float(n) + 0.5) / float(count)) / most
			points.append(Vector2(COURSE * n, share))
			points.append(Vector2(COURSE * (n + 1), share))
	else:
		for point: Vector2 in _shape(values):
			points.append(Vector2(roundf(point.x * high), point.y / most))
	for point: Vector2 in points:
		var w: float = _width(point.y * widest_, widest_)
		var d: float = _width(point.y * deepest, deepest)
		var level: Array = [point.x, w, d] if axis() == "x" else [point.x, d, w]
		# A tier as wide as the one under it is that tier, taller: a setback
		# too small to lay a stud in is no setback.
		if out.size() >= 2 and out.size() % 2 == 0 and level[1] == out[-1][1] \
				and level[2] == out[-1][2]:
			out.pop_back()
			continue
		out.append(level)
	return out


## [param w] in whole studs as even or odd as [param base], the nearer of the
## two either side, never under a stud (two for an even base) or over the base.
static func _width(w: float, base: float) -> float:
	var even: bool = roundi(base) % 2 == 0
	var n: float = roundf(w)
	if (roundi(n) % 2 == 0) != even:
		n += 1.0 if w > n else -1.0
	return clampf(n, 2.0 if even else 1.0, base)


## The storeys of a prism to this outline: each storey's share of the height
## and its width's share of the widest, ground first. Empty for a smooth
## reading (no steps) or a long thing's.
func storeys() -> Array:
	if mode != "widths" or steps.is_empty():
		return []
	var out: Array = []
	var most: float = Array(values).max()
	var shape: Array = _shape(values)
	for n: int in range(0, shape.size(), 2):
		var one: Vector2 = shape[n]
		var two: Vector2 = shape[n + 1]
		out.append(Vector2(two.x - one.x, one.y / most))
	return out


## Whether ([param u], [param v]) is inside [param plan] from above, each -0.5
## to 0.5 across its box: u along x, v along z, the front +z. [param arm] is its
## arms' thickness (0 for the plan's own).
static func in_plan(plan_: String, u: float, v: float, arm_: float = 0.0) -> bool:
	if absf(u) > 0.5 or absf(v) > 0.5:
		return false
	var a: float = arm_ if arm_ > 0.0 else (Y_ARM if plan_ == "Y" else ARM)
	match plan_:
		"round":
			return u * u + v * v <= 0.25
		"cross":
			return absf(u) <= a / 2.0 or absf(v) <= a / 2.0
		"T":
			return v <= -0.5 + a or absf(u) <= a / 2.0
		"L":
			return v <= -0.5 + a or u <= -0.5 + a
		"U":
			return absf(u) >= 0.5 - a or v <= -0.5 + a
		"H":
			return absf(u) >= 0.5 - a or absf(v) <= a / 2.0
		"triangle":
			return absf(u) <= 0.5 * (0.5 - v)
		"Y":
			return _in_y(u, v, a)
	return true


## A Y of three wings from its middle, one to the front (+z) and two back at
## 120 degrees, filling its box: each wing a bar [param a] of the box's width
## thick, round at its tip. Its wings' length R is what makes the two back
## tips reach the box's sides (2 R sin 120 + a = 1); the box's depth is then
## stretched over the Y's own, 1.5 R + a.
static func _in_y(u: float, v: float, a: float) -> bool:
	var r: float = (1.0 - a) / (2.0 * sin(PI * 2.0 / 3.0))
	# Its own depth runs from -(R/2 + a/2) behind the middle to R + a/2 in
	# front: the box's middle is a quarter of R in front of the Y's.
	var p := Vector2(u, v * (1.5 * r + a) + 0.25 * r)
	for k: int in 3:
		var angle: float = float(k) * PI * 2.0 / 3.0
		var d := Vector2(sin(angle), cos(angle))
		var s: float = clampf(p.dot(d), 0.0, r)
		if (p - d * s).length() <= a / 2.0:
			return true
	return false


## The reading as a session reads it back: what was read, and its size.
func said_read() -> String:
	var what: String = ("its top along its length, from the %s" % side) if mode == "heights" \
		else ("its width up its height, from the %s" % side)
	var parts := PackedStringArray([what])
	if not bottoms.is_empty():
		parts.append("its underside")
	if not steps.is_empty():
		parts.append("%d %s" % [steps.size(), "steps" if steps.size() != 1 else "step"])
	if plan != "rectangle":
		parts.append("a %s plan" % plan)
	return ", ".join(parts) + ((" (off \"%s\")" % picture) if not picture.is_empty() else "")


## Its size, as built: "54 studs long, 25 across" or "104 plates tall, 12 studs
## at its widest and 12 deep".
func said_size() -> String:
	if mode == "heights":
		return "%s studs long and %s across, %s plates at its highest" % [_n(length), _n(across),
			_n(Array(values).max() * length * PLATES_PER_STUD)]
	return "%s plates tall, %s studs at its widest and %s deep" % [_n(height), _n(widest),
		_n(depth)]


## The outline at its size, sample by sample, as a session reads it: a long
## thing's top (and underside) in plates at each tenth along, a tall thing's
## width in studs at each tenth up.
func said_samples() -> String:
	var lines := PackedStringArray()
	var count: int = values.size()
	for n: int in count:
		var share: float = float(n) / float(count - 1)
		if mode == "heights":
			var x: float = (share if not reversed() else 1.0 - share) * length
			var line: String = "%s at %s %s: top %s plates" % [_tenth(n, count), axis(), _n(
				snappedf(x, 0.1)), _n(snappedf(values[n] * length * PLATES_PER_STUD, 0.5))]
			if not bottoms.is_empty():
				line += ", underside %s" % _n(snappedf(bottoms[n] * length * PLATES_PER_STUD, 0.5))
			lines.append(line)
		else:
			var most: float = Array(values).max()
			lines.append("%s up, y %s: %s studs wide" % [_tenth(n, count), _n(snappedf(share
				* height, 0.5)), _n(snappedf(values[n] / most * widest, 0.5))])
	return "\n".join(lines)


## The first mass laid to it, as a submit_design pattern to send as it is:
## the shape pattern with one solid whose profile is the outline.
func mass(colour: int = 71) -> Dictionary:
	if mode == "heights":
		var extrude: Dictionary = {"along": axis(), "from": 0, "width": across,
			"profile": "outline"}
		if not bottoms.is_empty():
			extrude["under"] = "outline"
		if plan != "rectangle":
			extrude["plan"] = plan
		return {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": colour,
			"solids": [{"extrude": extrude}]}
	var x_wide: float = widest if axis() == "x" else depth
	var z_deep: float = depth if axis() == "x" else widest
	var tiers: Dictionary = {"centre": [x_wide / 2.0, z_deep / 2.0], "levels": "outline"}
	if plan != "rectangle":
		tiers["plan"] = plan
	return {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": colour,
		"solids": [{"tiers": tiers}]}


## "3/10" for sample [param n] of [param count].
static func _tenth(n: int, count: int) -> String:
	if count == 11:
		return "%d/10" % n
	return "%d/%d" % [n, count - 1]


static func _n(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(snappedf(value, 0.1))
