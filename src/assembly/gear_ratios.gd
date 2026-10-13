## The gear trains of real LEGO® gears nearest a ratio wanted, their axles on
## the stud grid: phase P1c's ratio search (docs/MECHANISMS.md, section 9).
##
## Every LEGO tooth count factors into primes of 7 or less, so most ratios
## a person wants (365.25 days, a planet's year in Earth's) can only be come
## near. The Stern-Brocot tree finds the nearest fraction with a bounded
## denominator, but nearly every fraction it finds has a prime no gear has
## (686.98 / 365.256 is 1.8808 = 47/25 to 0.03%, and 47 is no gear's). So
## this searches the trains themselves: each mesh a pair of gears whose
## pitch circles meet at a distance the stud grid gives (Mechanism's own
## 1.25 LDU a tooth, to SPACING_SLACK), each train a product of meshes, the
## halves met in the middle so five meshes are a moment's work.
##
## With [code]to[/code] the output axle stands where it is asked to, in
## studs from the input's, and every axle between stands on a grid point
## near the line between them: the train fits between two holes already
## there, a gearbox's input and the pinion of a ring. Without it each mesh
## is said with its spacing, and where the axles go is the builder's.
##
## Pure: it reads the gear table and nothing else.
class_name GearRatios
extends RefCounted

const STUD := 20.0
## The spur gears a train is made of, by teeth, each with the part used:
## an axle hole, teeth a spur meshes (a double bevel's do).
const PARTS := {8: "3647", 12: "69778", 16: "4019", 20: "69779", 24: "3648b",
	28: "46372", 36: "32498", 40: "3649"}
const MOST_STAGES := 6
## How far apart, in studs, two axles of one mesh may be: a 40 and a 40.
const MOST_SPAN := 6
## How many trains a search answers with.
const KEEP := 3
## How many ratios each grid point keeps while a path is searched: enough
## for five meshes, few enough that GDScript does it in a second.
const PER_POINT := 4000


## One mesh: the driver's teeth, the driven's, and where the driven's axle
## stands from the driver's, studs across the axes (x, z for upright axles).
class Stage extends RefCounted:
	var drive: int = 0
	var driven: int = 0
	var step := Vector2i.ZERO

	func _init(a: int = 0, b: int = 0, at: Vector2i = Vector2i.ZERO) -> void:
		drive = a
		driven = b
		step = at

	## "a 40 drives a 24, 3 studs along"
	func said() -> String:
		return "%s drives %s, %s" % [GearRatios.teeth_said(drive), GearRatios.teeth_said(driven),
			GearRatios.step_said(step)]


## A train: its meshes from the input, its value as a fraction (output
## turns per input turn, negative when it turns the other way: each mesh of
## two spur gears turns the driven one the other way), and how far it is
## from what was wanted.
class Train extends RefCounted:
	var stages: Array[Stage] = []
	var num: int = 1
	var den: int = 1
	var error: float = 0.0

	func value() -> float:
		return float(num) / float(den) * (-1.0 if stages.size() % 2 == 1 else 1.0)

	## Where each axle stands from the input's, studs, the output's last.
	func axles() -> Array[Vector2i]:
		var at := Vector2i.ZERO
		var out: Array[Vector2i] = []
		for stage: Stage in stages:
			at += stage.step
			out.append(at)
		return out


static func teeth_said(teeth: int) -> String:
	return ("an %d" if teeth in [8, 11, 18, 80] else "a %d") % teeth


static func step_said(step: Vector2i) -> String:
	var across: int = absi(step.x)
	var along: int = absi(step.y)
	if across == 0 or along == 0:
		var studs: int = maxi(across, along)
		return "%d stud%s apart" % [studs, "" if studs == 1 else "s"]
	return "%d by %d studs apart (a diagonal, %s LDU)" % [maxi(across, along), mini(across, along),
		Mechanism._tidy(STUD * Vector2(step).length())]


## Every mesh the grid allows of [param teeth]: step (studs, x and z) ->
## Array of [drive, driven]. Two gears mesh at 1.25 LDU a tooth between
## centres, so a 16 and a 20 mesh on a stud's diagonal (44.72 for 45) and
## a 28 and a 40 on three studs' (84.85 for 85).
static func meshes(teeth: Array = [], span: int = MOST_SPAN) -> Dictionary:
	if teeth.is_empty():
		teeth = PARTS.keys()
	var pitch: float = float(Mechanism.table().get("ldu_per_tooth", 1.25))
	var out: Dictionary = {}
	for dx: int in range(-span, span + 1):
		for dz: int in range(-span, span + 1):
			if dx == 0 and dz == 0:
				continue
			var apart: float = STUD * sqrt(float(dx * dx + dz * dz))
			for a: Variant in teeth:
				for b: Variant in teeth:
					if absf(pitch * float(int(a) + int(b)) - apart) <= Mechanism.SPACING_SLACK:
						if not out.has(Vector2i(dx, dz)):
							out[Vector2i(dx, dz)] = []
						(out[Vector2i(dx, dz)] as Array).append([int(a), int(b)])
	return out


## The trains nearest [param wanted] (output turns per input turn; negative
## for the other way) in at most [param most] meshes, best first, at most
## [param keep] of them. [param to] (studs, or null) is where the output's
## axle must stand from the input's; every axle between stands within
## [param within] studs of the line between them, on a grid point of its
## own. A positive or negative [param wanted] asks for that way round; the
## search keeps to trains of the meshes' count that turn it so. [param first]
## (teeth, or 0) is the gear on the input axle: two trains taken off one
## shaft at one height share it.
static func search(wanted: float, most: int = 4, to: Variant = null, within: int = 2,
		teeth: Array = [], keep: int = KEEP, first: int = 0) -> Array[Train]:
	most = clampi(most, 1, MOST_STAGES)
	var steps: Dictionary = meshes(teeth)
	var found: Array[Train] = []
	if to == null:
		found = _free(absf(wanted), most, steps, keep * 4, first)
	else:
		found = _path(absf(wanted), most, to as Vector2i, within, steps, keep * 4, first)
	# The way round asked for: an even count of meshes keeps it, an odd one
	# turns it back.
	var kept: Array[Train] = []
	for train: Train in found:
		if signf(train.value()) == signf(wanted):
			train.error = absf(train.value()) / absf(wanted) - 1.0
			kept.append(train)
	kept.sort_custom(func(a: Train, b: Train) -> bool:
		var ea: float = absf(log(1.0 + a.error))
		var eb: float = absf(log(1.0 + b.error))
		if absf(ea - eb) > 1e-12:
			return ea < eb
		return a.stages.size() < b.stages.size())
	var out: Array[Train] = []
	var seen: Dictionary = {}
	for train: Train in kept:
		var key := Vector2i(train.num, train.den)
		if seen.has(key):
			continue
		seen[key] = true
		out.append(train)
		if out.size() >= keep:
			break
	return out


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t: int = a % b
		a = b
		b = t
	return absi(a)


static func _times(ratio: Vector2i, a: int, b: int) -> Vector2i:
	var num: int = ratio.x * a
	var den: int = ratio.y * b
	var g: int = _gcd(num, den)
	return Vector2i(num / g, den / g)


static func _train(stages: Array, ratio: Vector2i) -> Train:
	var train := Train.new()
	for stage: Variant in stages:
		train.stages.append(stage)
	train.num = ratio.x
	train.den = ratio.y
	return train


## Any spacing: each distinct mesh ratio once, every multiset of them up to
## half the meshes listed by value, and each half met by the other's
## nearest. A mesh is kept with its shortest straight spacing.
static func _free(wanted: float, most: int, steps: Dictionary, keep: int,
		first: int = 0) -> Array[Train]:
	var by_ratio: Dictionary = {}   ## Vector2i -> Stage
	for step: Vector2i in steps:
		# Each spacing once, laid along +x (and up to the diagonal), so a train
		# of them goes one way and no two of its axles stand on one point.
		if step.x <= 0 or step.y < 0 or step.y > step.x:
			continue
		for pair: Array in steps[step]:
			var key: Vector2i = _times(Vector2i(1, 1), int(pair[0]), int(pair[1]))
			var stage := Stage.new(int(pair[0]), int(pair[1]), step)
			var had: Stage = by_ratio.get(key)
			if had == null or _plainer(stage, had):
				by_ratio[key] = stage
	var units: Array = by_ratio.keys()
	var half: int = ceili(most / 2.0)
	var lists: Array = []   ## [value, ratio, stages]
	_multisets(units, by_ratio, 0, half, Vector2i(1, 1), [], lists)
	lists.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var values := PackedFloat64Array()
	for row: Array in lists:
		values.append(float(row[0]))
	var out: Array[Train] = []
	var best: Array = []   ## [error, num, den, stages]
	for one: Array in lists:
		var need: float = wanted / float(one[0])
		var at: int = values.bsearch(need)
		for n: int in range(maxi(at - 24, 0), mini(at + 24, lists.size())):
			var other: Array = lists[n]
			var count: int = (one[2] as Array).size() + (other[2] as Array).size()
			if count == 0 or count > most:
				continue
			var stages: Array = (one[2] as Array) + (other[2] as Array)
			# The input's own gear, asked for: some mesh of the train has it as
			# its driver, and that mesh goes first.
			if first > 0:
				var at_first: int = -1
				for k: int in stages.size():
					if (stages[k] as Stage).drive == first:
						at_first = k
						break
				if at_first < 0:
					continue
				var moved: Stage = stages[at_first]
				stages.remove_at(at_first)
				stages.push_front(moved)
			var ratio := Vector2i(int((one[1] as Vector2i).x) * int((other[1] as Vector2i).x),
				int((one[1] as Vector2i).y) * int((other[1] as Vector2i).y))
			var g: int = _gcd(ratio.x, ratio.y)
			ratio = Vector2i(ratio.x / g, ratio.y / g)
			var error: float = absf(log(float(ratio.x) / float(ratio.y) / wanted))
			best.append([error, ratio, stages])
			if best.size() > 4000:
				_trim(best, keep * 8)
	_trim(best, keep * 8)
	for row: Array in best.slice(0, keep * 8):
		out.append(_train(row[2], row[1]))
	return out


## Keep the [param most] nearest of [param rows] ([error, ...]), nearest
## first.
static func _trim(rows: Array, most: int) -> void:
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	if rows.size() > most:
		rows.resize(most)


## A ratio as a person reads it: six figures, no trailing zeros.
static func figure(value: float) -> String:
	if value == 0.0:
		return "0"
	var places: int = clampi(5 - floori(log(absf(value)) / log(10.0)), 0, 12)
	var said: String = String.num(value, places)
	if said.contains("."):
		said = said.rstrip("0").rstrip(".")
	return said


## A tie between two meshes of one ratio: the straight one, then the
## shorter.
static func _plainer(stage: Stage, other: Stage) -> bool:
	var straight: bool = stage.step.x == 0 or stage.step.y == 0
	var other_straight: bool = other.step.x == 0 or other.step.y == 0
	if straight != other_straight:
		return straight
	return Vector2(stage.step).length() < Vector2(other.step).length()


static func _multisets(units: Array, by_ratio: Dictionary, from: int, left: int, ratio: Vector2i,
		stages: Array, into: Array) -> void:
	into.append([float(ratio.x) / float(ratio.y), ratio, stages.duplicate()])
	if left == 0:
		return
	for n: int in range(from, units.size()):
		var stage: Stage = by_ratio[units[n]]
		stages.append(stage)
		_multisets(units, by_ratio, n, left - 1, _times(ratio, stage.drive, stage.driven), stages,
			into)
		stages.pop_back()


## Between two axles: the grid points near the line from the input to
## [param to] reached in so many meshes from either end, met in the
## middle. Each side keeps, at each point, every ratio it reached and the
## first way it reached it.
static func _path(wanted: float, most: int, to: Vector2i, within: int, steps: Dictionary,
		keep: int, first: int = 0) -> Array[Train]:
	var ahead: int = ceili(most / 2.0)
	var behind: int = most - ahead
	var line := Vector2(to)
	var forward: Array = _reach(Vector2i.ZERO, ahead, steps, line, within, 1, first)
	var backward: Array = _reach(to, behind, steps, line, within, -1)
	var best: Array = []   ## [error, ratio, stages]
	for f: int in forward.size():
		for b: int in backward.size():
			if f + b == 0 or f + b > most:
				continue
			var there: Dictionary = backward[b]
			for point: Vector2i in forward[f]:
				if not there.has(point):
					continue
				var mine: Dictionary = forward[f][point]
				var theirs: Dictionary = there[point]
				var order: Array = theirs.keys()
				order.sort_custom(func(x: Vector2i, y: Vector2i) -> bool:
					return float(x.x) / float(x.y) < float(y.x) / float(y.y))
				var values := PackedFloat64Array()
				for key: Vector2i in order:
					values.append(float(key.x) / float(key.y))
				for key: Vector2i in mine:
					var need: float = wanted / (float(key.x) / float(key.y))
					var at: int = values.bsearch(need)
					for n: int in range(maxi(at - 2, 0), mini(at + 2, order.size())):
						var other: Vector2i = order[n]
						var ratio := Vector2i(key.x * other.x, key.y * other.y)
						var g: int = _gcd(ratio.x, ratio.y)
						ratio = Vector2i(ratio.x / g, ratio.y / g)
						var stages: Array = (mine[key] as Array) + (theirs[other] as Array)
						if not _apart(stages):
							continue
						if first > 0 and (stages[0] as Stage).drive != first:
							continue
						best.append([absf(log(float(ratio.x) / float(ratio.y) / wanted)), ratio, stages])
						if best.size() > 4000:
							_trim(best, keep * 8)
	_trim(best, keep * 8)
	var out: Array[Train] = []
	for row: Array in best.slice(0, keep * 8):
		out.append(_train(row[2], row[1]))
	return out


## Whether a train's axles each stand on a grid point of their own.
static func _apart(stages: Array) -> bool:
	var at := Vector2i.ZERO
	var seen: Dictionary = {at: true}
	for stage: Stage in stages:
		at += stage.step
		if seen.has(at):
			return false
		seen[at] = true
	return true


## From [param start], [param levels] meshes out (or back, [param way] -1:
## the meshes that end there), the points near the line [param line] from
## the origin: per count of meshes, point -> {ratio: stages in order}. Out
## from the input, [param first] (teeth, or 0) drives the first mesh.
static func _reach(start: Vector2i, levels: int, steps: Dictionary, line: Vector2, within: int,
		way: int, first: int = 0) -> Array:
	var out: Array = [{start: {Vector2i(1, 1): []}}]
	var length: float = line.length()
	var unit: Vector2 = line / length if length > 0.0 else Vector2.RIGHT
	for level: int in levels:
		var next: Dictionary = {}
		var now: Dictionary = out[level]
		for point: Vector2i in now:
			for step: Vector2i in steps:
				var there: Vector2i = point + step * way
				var along: float = Vector2(there).dot(unit)
				var off: float = absf(Vector2(there).dot(Vector2(-unit.y, unit.x)))
				if along < -float(within) or along > length + float(within) or off > float(within):
					continue
				if not next.has(there):
					next[there] = {}
				var bucket: Dictionary = next[there]
				if bucket.size() >= PER_POINT:
					continue
				for ratio: Vector2i in now[point]:
					var stages: Array = now[point][ratio]
					for pair: Array in steps[step]:
						# Out from the input, its first mesh driven by the gear asked for.
						if first > 0 and way > 0 and level == 0 and int(pair[0]) != first:
							continue
						var key: Vector2i = _times(ratio, int(pair[0]), int(pair[1]))
						if bucket.has(key):
							continue
						var stage := Stage.new(int(pair[0]), int(pair[1]), step)
						bucket[key] = stages + [stage] if way > 0 else [stage] + stages
		out.append(next)
	return out


# -- saying it ----------------------------------------------------------------------


## The search's answer as a session reads it: what was asked, then each
## train with its fraction, its error, its gears by part and where each
## axle stands.
static func said(trains: Array[Train], wanted: float, most: int, to: Variant) -> String:
	var lines := PackedStringArray()
	var where: String = ""
	if to != null:
		var at: Vector2i = to
		where = ", the output's axle %s from the input's (x %d, z %d studs)" % [
			step_said(at).trim_suffix(" apart"), at.x, at.y]
	lines.append("Nearest %s (output turns per input turn%s) in up to %d meshes of spur gears on "
		% [GearRatios.figure(wanted), ", the other way" if wanted < 0.0 else "", most]
		+ "the stud grid%s:" % where)
	if trains.is_empty():
		lines.append("  none: %s" % ("no train of so few meshes gets there; allow more meshes, or "
			+ "more room off the line (within=)" if to != null else "allow more meshes"))
		return "\n".join(lines)
	var n: int = 0
	for train: Train in trains:
		n += 1
		lines.append("%d. %s = %d/%d, %+.4f%%, %d mesh%s, %s:" % [n,
			GearRatios.figure(train.value()), train.num, train.den, train.error * 100.0,
			train.stages.size(), "" if train.stages.size() == 1 else "es",
			"the same way round" if train.value() > 0.0 else "the other way round"])
		var at := Vector2i.ZERO
		var parts := PackedStringArray()
		for stage: Stage in train.stages:
			at += stage.step
			var place: String = " at (%d, %d)" % [at.x, at.y] if to != null else ""
			parts.append("%s (%s) drives %s (%s)%s, %s" % [teeth_said(stage.drive),
				PARTS.get(stage.drive, "?"), teeth_said(stage.driven), PARTS.get(stage.driven, "?"),
				place, step_said(stage.step)])
		lines.append("   " + "; then on that axle ".join(parts) + ".")
	lines.append("Each axle between carries two gears, the one driven and the one that drives "
		+ "the next, at different heights; gears of axles that do not mesh must not overlap at "
		+ "one height. Positions are studs from the input's axle, x and z.")
	return "\n".join(lines)
