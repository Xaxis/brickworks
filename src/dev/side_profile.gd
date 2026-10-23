## taper165's side-profile measure (src/ai/taper.gd at 6185b456), copied for
## the dev measures that read a body's side (sculpt_probe, side_profile_of): not
## the check's. Preloaded, as it has no class name.
##
## A rounded body's outline seen from the side, measured course by course.
##
## Corner rounds round what is seen from above. Seen from the side, a body's
## outline is the width of each of its courses, and a body whose courses are
## all one width is a drum whatever rounds its corners. bench164 read the
## potato, the rabbit and the toilet's head that way, 12 of the 22 verdicts
## lost to BrickAgent: 55 corner rounds in the potato, laid as rings of one
## size 10 studs across from plate 3 to 32, "a can". m147's potato of plain
## plates swelled and narrowed, and the judge called it an egg. Nothing
## measured it, and view_model's own massing said "10 across" six times over.
##
## So each course's widest piece is measured across x and deep along z, in
## studs, and a run of courses that keeps one width over most of the mass it
## belongs to is a straight side. The share is the measure, whatever the
## mass's proportions: an ellipse keeps within a stud of its widest for
## sqrt(2/W - 1/W^2) of its height, under 0.56 for a round six studs across or
## more, tall or squat. Static and reading only its arguments: the check calls
## it on a worker.
extends RefCounted

## Narrower than this a mass is a leg, a neck or a moulded part's job.
const WIDEST_FROM := 6
## A run this share of its mass's height is a drum's: a round's is under 0.56,
## and BrickAgent's potato, its oval face built sideways, is 0.73 deep.
const STRAIGHT_SHARE := 0.75
## And at least this many courses, three bricks: a mass less tall has no
## room to swell and narrow.
const SHORTEST := 9
## Nor a mass at the bottom less tall than this share of its widest either
## way: a plinth, a base, a pair of feet, flat by nature. A pig's body, as
## flat, stands on its legs.
const TALL_FROM := 0.4
## Courses from the bottom a mass may start at and be what the rest stands on.
const BASE_WITHIN := 3
## Plates to a stud, up the side.
const PLATES_PER_STUD := 2.5
## Courses a stud or more wider than the run's (an arm hanging beside it, a
## face built on its front) it may hold and still be straight: a third.
const WIDER_AT_MOST := 1.0 / 3.0
## A mass ends where it narrows below half its width, widens again, or keeps
## a narrower width longer than this share of its run: a head, a neck or a
## hat on it is a mass of its own.
const PLATEAU_SHARE := 0.5
## The most straight masses said.
const SAID_AT_MOST := 3


## Each course's widest piece, bottom to top: [plate, low stud x, high stud x,
## low stud z, high stud z, cells] per row, cells a set of Vector2i. From
## [param covers], each a placement's cover on the lattice, boxes of six ints
## with the high corner exclusive (BrickLattice). A part is in a course as the
## rectangle round its boxes that fill three quarters of the course's height,
## to the nearest stud: so a stud on its top is not a course of its own, a
## curved slope's thin end is narrower than its thick one, and a ring of corner
## rounds, a thin wall in many small boxes, is as wide as it is seen.
static func courses(covers: Array) -> Array:
	var by_plate: Dictionary = {}    ## plate -> {Vector2i stud: true}
	var per: int = BrickLattice.CELLS_PER_PLATE
	var stud: float = BrickLattice.CELLS_PER_STUD
	for raw: Variant in covers:
		var packed: PackedInt32Array = raw
		var spans: Dictionary = {}    ## plate -> [low x, low z, high x, high z] in cells
		var n: int = 0
		while n + 5 < packed.size():
			for plate: int in range(floori(float(packed[n + 1]) / per),
					ceili(float(packed[n + 4]) / per)):
				if mini(packed[n + 4], (plate + 1) * per) - maxi(packed[n + 1], plate * per) \
						< per * 3 / 4:
					continue
				var was: Array = spans.get(plate, [packed[n], packed[n + 2], packed[n + 3],
					packed[n + 5]])
				spans[plate] = [mini(was[0], packed[n]), mini(was[1], packed[n + 2]),
					maxi(was[2], packed[n + 3]), maxi(was[3], packed[n + 5])]
			n += 6
		for plate: int in spans:
			var span: Array = spans[plate]
			if not by_plate.has(plate):
				by_plate[plate] = {}
			var layer: Dictionary = by_plate[plate]
			for x: int in range(roundi(span[0] / stud), roundi(span[2] / stud)):
				for z: int in range(roundi(span[1] / stud), roundi(span[3] / stud)):
					layer[Vector2i(x, z)] = true
	var plates: Array = by_plate.keys()
	plates.sort()
	var rows: Array = []
	for plate: int in plates:
		var piece: Dictionary = _biggest_piece(by_plate[plate])
		var lo := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
		var hi := Vector2i(-0x7FFFFFFF, -0x7FFFFFFF)
		for cell: Vector2i in piece:
			lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
			hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
		rows.append([plate, lo.x, hi.x, lo.y, hi.y, piece])
	return rows


## The biggest group of studs in a course that touch side by side: a body's
## course, not its four legs' box.
static func _biggest_piece(layer: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var best: Dictionary = {}
	for start: Vector2i in layer:
		if seen.has(start):
			continue
		var piece: Dictionary = {start: true}
		seen[start] = true
		var todo: Array[Vector2i] = [start]
		while not todo.is_empty():
			var at: Vector2i = todo.pop_back()
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
					Vector2i(0, -1)]:
				var next: Vector2i = at + step
				if layer.has(next) and not seen.has(next):
					seen[next] = true
					piece[next] = true
					todo.append(next)
		if piece.size() > best.size():
			best = piece
	return best


## A row's width across x (axis 0) or deep along z (axis 1), in studs.
static func width(row: Array, axis: int) -> int:
	return int(row[2]) - int(row[1]) + 1 if axis == 0 else int(row[4]) - int(row[3]) + 1


## Whether two rows are the same body: on consecutive plates, sharing a stud.
static func _continues(below: Array, above: Array) -> bool:
	if int(above[0]) != int(below[0]) + 1:
		return false
	var lower: Dictionary = below[5]
	var upper: Dictionary = above[5]
	var small: Dictionary = lower if lower.size() < upper.size() else upper
	var big: Dictionary = upper if small == lower else lower
	for cell: Vector2i in small:
		if big.has(cell):
			return true
	return false


## The straight sides among [param rows] (courses), each [first row, last
## row, axis, width, courses, first and last row of its mass, its share of
## the mass]: the courses keep the width (a stud wider at most, and a third
## of them wider still) over STRAIGHT_SHARE of the mass's height. Two that
## share a course, the more straight kept.
static func straight(rows: Array) -> Array:
	var found: Array = []
	for axis: int in 2:
		var held: Array = held_widths(rows, axis)
		var widths: Dictionary = {}
		for value: Variant in held:
			if int(value) >= WIDEST_FROM:
				widths[int(value)] = true
		for wide: int in widths:
			var start: int = -1
			for n: int in rows.size():
				var fits: bool = int(held[n]) >= wide
				if start >= 0 and (not fits or not _continues(rows[n - 1], rows[n])):
					_keep_run(found, rows, held, start, n - 1, axis, wide)
					start = -1
				if fits and start < 0:
					start = n
			if start >= 0:
				_keep_run(found, rows, held, start, rows.size() - 1, axis, wide)
	found.sort_custom(func(a: Array, b: Array) -> bool:
		return _straightness(a) > _straightness(b))
	var kept: Array = []
	for one: Array in found:
		var clear: bool = true
		for other: Array in kept:
			if int(one[0]) <= int(other[1]) and int(other[0]) <= int(one[1]):
				clear = false
				break
		if clear:
			kept.append(one)
	return kept


## Each row's width across x (axis 0) or along z, a course narrower than both
## its neighbours taken at the narrower of theirs: a course of parts that do
## not touch side by side (a ring of separate quarters, a band of tiles) is
## not a waist, and m147's potato read as a stack of short drums for them.
static func held_widths(rows: Array, axis: int) -> Array:
	var out: Array = []
	for row: Array in rows:
		out.append(width(row, axis))
	for n: int in range(1, rows.size() - 1):
		if _continues(rows[n - 1], rows[n]) and _continues(rows[n], rows[n + 1]):
			out[n] = maxi(int(out[n]), mini(width(rows[n - 1], axis), width(rows[n + 1], axis)))
	return out


## [param first] to [param last] of [param held] kept when it is straight at
## [param wide]: trimmed at both ends to courses that keep the width, then
## most of the height of the mass it is in ([method mass]).
static func _keep_run(found: Array, rows: Array, held: Array, first: int, last: int,
		axis: int, wide: int) -> void:
	while first <= last and int(held[first]) > wide + 1:
		first += 1
	while last >= first and int(held[last]) > wide + 1:
		last -= 1
	var courses_up: int = last - first + 1
	if courses_up < SHORTEST:
		return
	var wider: int = 0
	for n: int in range(first, last + 1):
		if int(held[n]) > wide + 1:
			wider += 1
	if float(wider) > WIDER_AT_MOST * courses_up:
		return
	var whole: Vector2i = mass(rows, held, first, last, wide)
	var share: float = float(courses_up) / (whole.y - whole.x + 1)
	var widest: int = 0
	for n: int in range(whole.x, whole.y + 1):
		widest = maxi(widest, maxi(width(rows[n], 0), width(rows[n], 1)))
	if share < STRAIGHT_SHARE or (whole.x < BASE_WITHIN
			and (whole.y - whole.x + 1) / PLATES_PER_STUD < TALL_FROM * widest):
		return
	found.append([first, last, axis, wide, courses_up, whole.x, whole.y, share])


## The rows of the mass a run of [param first] to [param last], [param wide]
## across, is in: on from it both ways while the courses continue it and
## narrow, to half its width, and not along a plateau longer than
## PLATEAU_SHARE of the run.
static func mass(rows: Array, held: Array, first: int, last: int, wide: int) -> Vector2i:
	var plateau: int = maxi(3, roundi((last - first + 1) * PLATEAU_SHARE))
	var ends: Array = []
	for way: int in [-1, 1]:
		var at: int = first if way < 0 else last
		var flat: int = 0
		var end: int = at
		while true:
			var next: int = at + way
			if next < 0 or next >= rows.size() or int(held[next]) * 2 < wide \
					or int(held[next]) > maxi(int(held[at]), wide + 1) \
					or not _continues(rows[mini(at, next)], rows[maxi(at, next)]):
				break
			flat = flat + 1 if int(held[next]) == int(held[at]) and int(held[next]) < wide \
				else 0
			if flat >= plateau:
				end = at - way * flat
				break
			at = next
			end = at
		ends.append(end)
	return Vector2i(ends[0], ends[1])


## How straight a run is: its share of its mass, then its size.
static func _straightness(one: Array) -> float:
	return float(one[7]) * 1000.0 + int(one[4]) * int(one[3])


## A round's width at each sixth of its height from the bottom, [param wide]
## across at its middle: an ellipse's chord at each sixth's middle.
static func round_widths(wide: int) -> Array:
	var out: Array = []
	for n: int in 6:
		var t: float = (n + 0.5) / 3.0 - 1.0
		out.append(roundi(wide * sqrt(1.0 - t * t)))
	return out


## A mass's widths by sixths of its height from the bottom: each sixth's
## middle course, as [method held_widths] has it.
static func widths_by_sixths(held: Array, first: int, last: int) -> Array:
	var out: Array = []
	var tall: int = last - first + 1
	for n: int in 6:
		out.append(int(held[mini(last, first + floori(tall * (n + 0.5) / 6.0))]))
	return out


## What a body's straight sides are, said with the numbers: "" when none.
## [param named] gives a mass's name from its first and last plate and a row
## of it ("" when it has none): the assembly the designer said it is.
static func said(rows: Array, named: Callable = Callable()) -> String:
	var sides: Array = straight(rows)
	if sides.is_empty():
		return ""
	sides.sort_custom(func(a: Array, b: Array) -> bool:
		return (int(a[6]) - int(a[5])) * int(a[3]) > (int(b[6]) - int(b[5])) * int(b[3]))
	var lines := PackedStringArray()
	for one: Array in sides.slice(0, SAID_AT_MOST):
		var axis: int = one[2]
		var low: int = int(rows[int(one[5])][0])
		var high: int = int(rows[int(one[6])][0])
		var name: String = ""
		if named.is_valid():
			name = str(named.call(low, high, rows[int(one[0])]))
		var measured: Array = widths_by_sixths(held_widths(rows, axis), int(one[5]),
			int(one[6]))
		var most: int = 0
		for value: Variant in measured:
			most = maxi(most, int(value))
		lines.append("  %splates %d to %d: %d %s for %d of its %d courses (%d%%). By sixths "
			% ["the %s, " % name if not name.is_empty() else "", low, high, int(one[3]),
				"across x" if axis == 0 else "deep along z", int(one[4]), high - low + 1,
				roundi(float(one[7]) * 100.0)]
			+ "of its height from the bottom: %s; a round that tall and %d wide: %s."
			% [_listed(measured), most, _listed(round_widths(most))])
	return ("Seen from the side it is straight-sided. Corner rounds round what is seen "
		+ "from above; from the side the outline is each course's width, and here it keeps "
		+ "one width up most of the body, a drum or a can however its corners are rounded "
		+ "(a round keeps within a stud of its widest for about half its height). Measured "
		+ "course by course, in studs:\n%s\n" % "\n".join(lines)
		+ "A round body swells and narrows: lay each course at the round's width for its "
		+ "height, as the round pattern does with a \"diameter\" on each band (an egg "
		+ "narrower at its top, a pear at its top and wide low, a belly wide low); laid by "
		+ "hand, each ring of corner rounds a size smaller toward the top and the bottom "
		+ "(2577 rings 8 across, 5152 rings 6, 3063b rings 4), rounded tops (5651, 49612) "
		+ "on the step above the widest course and inverted curved slopes (24201, 13547, "
		+ "32803) under the step below it. A mass meant to be straight (a hat, a can, a "
		+ "column, a leg, a plinth) stays as it is.")


static func _listed(values: Array) -> String:
	return ", ".join(PackedStringArray(values.map(func(v: Variant) -> String: return str(v))))
