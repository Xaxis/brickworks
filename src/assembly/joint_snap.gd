## Where the part in hand goes when it is aimed at a connector of a part
## already down: a pin into a pin hole, an axle into an axle hole or a
## round one, a beam's hole onto a pin or an axle, a clip onto a bar and a
## bar into a clip, a tyre round a rim (and a rim into a tyre), and a door,
## a shutter or a window's pane on its frame's hinge. BrickLink
## Studio does this. Until it was done here a
## part by hand went on studs or against a face, so a pin could not be put
## into a hole at all, and nothing Technic could be built by hand.
##
## Two halves. [method ends_of] reads a part's connectors as the ends it
## joins by, in its own frame: where each is, which way it points, how
## deep a hole is and how far a pin reaches. [method pose] puts one end of
## the part in hand on one end of a part already down: the axes made one,
## the end where the joint puts it, and turned about the shared axis by a
## roll. Whether the pose has room is not decided here: the builder asks
## that by the rule check_design uses (Builder.room_for).
class_name JointSnap
extends RefCounted

## How near the pointer's line a connector has to be to be aimed at, in
## LDU. Under a stud, so of two holes side by side the one pointed at wins.
const REACH := 12.0
## A pin or an axle whose part goes on past its connector by at least this
## much, in LDU, is held by its collar: the collar goes to a hole's mouth
## and the rest into it. One that does not is an axle's tip, which goes in
## first and comes to rest at the far mouth, through the hole.
const COLLAR := 8.0
## The radius of a bar, in LDU, and of the clip that takes one. Only these
## rounds are snapped to: a pin's and a hole's are matched by their own
## connectors, a door's hinge by its labels ([method hinges_of]), and a
## hinge brick or a turntable is put together on its studs.
const BAR := 4.0
## How far a clip slides along a bar per step, in LDU: half a plate.
const SLIDE := 4.0
## A cross turns only by quarters in a cross; anything round in anything
## round turns freely, by this much a step unless the turn step is finer.
const CROSS_STEP := 90.0
const ROUND_STEP := 45.0

## What each kind of end in hand goes into or onto.
const TAKES: Dictionary = {
	"pin": ["pin_hole"],
	"axle": ["axle_hole", "pin_hole"],
	"pin_hole": ["pin", "axle"],
	"axle_hole": ["axle"],
	"shaft": ["bore"],
	"bore": ["shaft"],
	"tyre": ["rim"],
	"rim": ["tyre"],
	"hinge": ["hinge"],
}

## What the words for each kind of end are, as a person says them.
const SAID: Dictionary = {
	"pin": "pin", "axle": "axle", "pin_hole": "pin hole",
	"axle_hole": "axle hole", "shaft": "bar", "bore": "clip",
	"tyre": "tyre", "rim": "rim", "hinge": "hinge",
}

## A round wider than this, in LDU, is a tyre's inside or a rim's outside:
## narrower ones are a pin's, a hole's or a bar's, matched by their own. Past
## 8: a Technic hole's counterbore and a pin's collar are 8 across, and as a
## tyre and a rim a pin went round its hole's mouth, and a Technic brick
## round a pin (8841-1's second brick, turned 77 presses in the build flow).
const WIDE := 8.5
## How far a cover's box may come inside a tyre's round, or reach outside a
## rim's, and the round still be the part's innermost or outermost, in LDU:
## a cell's half diagonal and a little, which is how far an exact cover
## stands past the curve it follows.
const WRAP_SLACK := 2.0


## One end a part joins by.
class End extends RefCounted:
	## pin, axle, pin_hole, axle_hole, shaft (a bar), bore (a clip), tyre
	## (the inside of a part that goes round a round: a tyre's) or rim (the
	## outside of one that goes into a round: a rim's barrel).
	var kind: String
	## A pin or an axle: where its connector is, a collar or a tip. A
	## hole: its middle. A bar or a clip: where it starts. A tyre or a rim:
	## the middle of its round, on its axis.
	var at: Vector3
	## Unit. A pin or an axle: out of the part. A bar or a clip: the way
	## it runs from [member at]. A tyre or a rim: along its axis.
	var axis: Vector3
	## A pin or an axle: how far the part goes on past [member at] along
	## [member axis]. A hole: half its depth. A bar or a clip: its length.
	## A tyre or a rim: half its round's length.
	var reach: float = 0.0
	var radius: float = 0.0
	## An axle's tip: how far its shaft runs back from [member at], for a
	## part that is an axle and nothing else, whose hole goes on anywhere
	## along it. 0 for every other end.
	var back: float = 0.0
	## The brick it belongs to, for an end on a part already down.
	var brick: int = 0
	## A hinge's half (BrickNet's label): its frame, whose y is [member
	## axis] and whose x a turn about the hinge is counted from; its
	## subtype; and which half it is, in (0) or on (1). One half goes on
	## the other of its subtype, as Exact.meets pairs them.
	var frame := Basis.IDENTITY
	var sub: int = 0
	var pol: int = 0
	## A hinge's: the part's own box, and where the part stands (a part
	## down's). A door is put on its frame's hinge by pointing anywhere at
	## the frame, and hangs in it the way it closes ([method ways]).
	var box := AABB()
	var on := Transform3D.IDENTITY

	func is_male() -> bool:
		return kind == "pin" or kind == "axle"

	func is_hole() -> bool:
		return kind == "pin_hole" or kind == "axle_hole"

	func is_round() -> bool:
		return kind == "shaft" or kind == "bore"

	## A tyre's inside or a rim's outside: one goes round the other, their
	## middles together.
	func is_wrap() -> bool:
		return kind == "tyre" or kind == "rim"

	func is_hinge() -> bool:
		return kind == "hinge"

	## The same end on a part placed at [param where].
	func placed(where: Transform3D, brick_id: int) -> End:
		var out := End.new()
		out.kind = kind
		out.at = where * at
		out.axis = (where.basis * axis).normalized()
		out.reach = reach
		out.radius = radius
		out.back = back
		out.brick = brick_id
		if kind == "hinge":
			out.frame = (where.basis * frame).orthonormalized()
			out.sub = sub
			out.pol = pol
			out.box = box
			out.on = where
		return out

	## Where this end is to look at: a hole's middle, the middle of what
	## a pin or an axle has left to go into something, a bar's or a
	## clip's middle.
	func middle() -> Vector3:
		if is_wrap() or is_hinge():
			return at
		if is_round():
			return at + axis * (reach * 0.5)
		if is_male() and reach < COLLAR:
			return at - axis * 5.0
		return aimed(Vector3.ZERO, Vector3.FORWARD)

	## The point a person points at to mean this end: a hole's middle,
	## the middle of what a pin or an axle has left to go into something,
	## or where along a bar the line [param from] → [param way] passes
	## nearest.
	func aimed(from: Vector3, way: Vector3) -> Vector3:
		if is_hole() or is_wrap():
			return at
		if is_hinge():
			return at + axis * clampf(along_nearest(from, way), -reach, reach)
		if is_male():
			if reach >= COLLAR:
				return at + axis * minf(reach, BrickLattice.STUD) * 0.5
			# Anywhere along an axle's shaft: a wheel goes on in its middle.
			if back > 0.0:
				return at + axis * clampf(along_nearest(from, way), -back, -5.0)
			return at - axis * 5.0
		return at + axis * clampf(along_nearest(from, way), 0.0, reach)

	## How far along this end's line from [member at] the line from
	## [param from] going [param way] passes nearest it.
	func along_nearest(from: Vector3, way: Vector3) -> float:
		var w0: Vector3 = at - from
		var b: float = axis.dot(way)
		var d: float = axis.dot(w0)
		var e: float = way.dot(w0)
		var denominator: float = 1.0 - b * b
		if denominator < 1e-6:
			return 0.0
		return (b * e - d) / denominator


## A part's ends in its own frame, worked out once per part. Bodies asks on
## a worker as well as on the main thread (a stud on a part's side, in a
## hole or not): the cache is filled under a lock, as Joints._lines is.
## Two threads writing it at once stopped the app (10265-1, G14b).
static var _ends: Dictionary = {}
static var _ends_lock := Mutex.new()


static func ends_of(part: Lbm.PartMesh) -> Array:
	if part == null:
		return []
	var key: int = part.get_instance_id()
	_ends_lock.lock()
	var known: Variant = _ends.get(key)
	_ends_lock.unlock()
	if known != null:
		return known
	var out: Array = []
	for connector: Lbm.Connector in part.connectors:
		var end := End.new()
		end.kind = connector.kind
		end.axis = connector.axis.normalized()
		if end.axis.length_squared() < 0.5:
			continue
		match connector.kind:
			"pin", "axle":
				if connector.gender != "male":
					continue
				end.at = connector.position
				end.reach = maxf(_extent(part.bounds, end.at, end.axis).y, 0.0)
			"pin_hole", "axle_hole":
				var span: Vector2 = _hole_span(part, connector.position, end.axis)
				end.at = connector.position + end.axis * (span.x + span.y) * 0.5
				end.reach = (span.y - span.x) * 0.5
				if end.reach < 1.0:
					continue
			"shaft", "bore":
				if absf(connector.radius - BAR) > Joints.ROUND_FIT or connector.length < 1.0:
					continue
				end.at = connector.position
				end.reach = connector.length
				end.radius = connector.radius
			_:
				continue
		if not _repeats(out, end):
			out.append(end)
	# A round hole a pin's size that LDraw draws as a plain cylinder, not a
	# Technic hole: the steering ends of 4262 (8841-1 hangs its pan from
	# two), which a pin goes through as it goes through any hole. As deep
	# as the part is there, from the hole's mouth, no more than a stud: the
	# file has the plate's body against the pin's collar, past the end's
	# thinner hole. And with no counterbore for the collar to sit in, its
	# mouth is that much further out than a Technic hole's. Through a
	# plate's thickness at most: a round brick's hollow is that radius too,
	# and is no hole.
	for connector: Lbm.Connector in part.connectors:
		if connector.kind != "bore" or connector.length < 4.0 or connector.length > 8.0 \
				or absf(connector.radius - PIN_ROUND) > 0.5:
			continue
		var end := End.new()
		end.kind = "pin_hole"
		end.axis = connector.axis.normalized()
		if end.axis.length_squared() < 0.5 or _on_a_hole(out, connector.position, end.axis):
			continue
		var deep: float = clampf(_extent(part.bounds, connector.position, end.axis).y,
			connector.length, BrickLattice.STUD)
		end.at = connector.position + end.axis * deep * 0.5
		end.reach = deep * 0.5 + COUNTERBORE
		if not _repeats(out, end):
			out.append(end)
	out.append_array(_wraps(part))
	# An axle and nothing else: its two tips, back to back on one line,
	# each with the shaft behind it, along which a hole goes on anywhere.
	if out.size() == 2 and (out[0] as End).kind == "axle" and (out[1] as End).kind == "axle":
		var a: End = out[0]
		var b: End = out[1]
		var gap: Vector3 = b.at - a.at
		if a.axis.dot(b.axis) < -0.999 and gap.length() > 1.0 \
				and (gap - a.axis * gap.dot(a.axis)).length() < 0.5 and gap.dot(a.axis) < 0.0:
			a.back = gap.length()
			b.back = gap.length()
	_ends_lock.lock()
	_ends[key] = out
	_ends_lock.unlock()
	return out


## Each shape's hinge halves ([method hinges_of]), by its id, kept under the
## lock [member _ends] is.
static var _hinges: Dictionary = {}


## A part's hinge halves, in its own frame, from its exact shape's labels
## (BrickNet's, as Studio's hinge connections are): a door's and the frame
## it hangs in, a shutter's and its window's. The catalogue's connectors do
## not say them: 60621's pins are drawn as two bumps, which no connector
## reads, and 60596's holes as rounds 5 across that nothing of a door fits,
## so a door held over its frame stood beside it or on its studs, wherever
## it was pointed (walk180). Along its line as far as the part reaches
## either way, which is where it is aimed at. [] for a part with no shape,
## or none yet in a browser: its parts down are measured again when it
## comes (Builder._on_exact_fetched). Main thread, as Exact.shape_for is.
static func hinges_of(library: PartLibrary, part_id: String) -> Array:
	var shape: Exact.Shape = Exact.shape_for(library, part_id)
	if shape == null or not shape.kind.has(Exact.HINGE):
		return []
	_ends_lock.lock()
	var known: Variant = _hinges.get(shape.id)
	_ends_lock.unlock()
	if known != null:
		return known
	var out: Array = []
	var box := AABB(shape.lo, shape.hi - shape.lo)
	for k: int in shape.kind.size():
		if shape.kind[k] != Exact.HINGE or shape.pol[k] == Exact.NO_POLARITY:
			continue
		var end := End.new()
		end.kind = "hinge"
		end.frame = shape.frames[k].basis.orthonormalized()
		end.axis = end.frame.y
		end.at = shape.frames[k].origin
		var span: Vector2 = _extent(box, end.at, end.axis)
		end.reach = maxf(maxf(-span.x, span.y), 1.0)
		end.sub = shape.sub[k]
		end.pol = shape.pol[k]
		end.box = box
		out.append(end)
	_ends_lock.lock()
	_hinges[shape.id] = out
	_ends_lock.unlock()
	return out


## A part's ends ([method ends_of]) and its hinge halves ([method
## hinges_of]): what the hand puts a part on by, and what it is put on.
static func ends_for(library: PartLibrary, part_id: String) -> Array:
	var ends: Array = ends_of(library.mesh_for(part_id))
	var hinges: Array = hinges_of(library, part_id)
	return ends if hinges.is_empty() else ends + hinges


## A part's tyres and rims: the rounds wider than a pin across the stud axis
## that are the part's innermost (a bore nothing of the part comes inside,
## along its length: a tyre's hole) or its outermost (a shaft nothing
## reaches outside: a rim's barrel), each set of them on one line at one
## size as one end, from the first's start to the last's end. 50951 is
## three bores, two at 14 LDU and one at 12 between them, and 51719 three
## shafts the same; a tyre goes on a rim whose barrel is its hole's size.
## A wheel with its tyre on has neither: its rim's barrel has the tyre
## round it.
static func _wraps(part: Lbm.PartMesh) -> Array:
	var groups: Array = []   ## [kind, point, axis, low, high, radius]
	for connector: Lbm.Connector in part.connectors:
		if (connector.kind != "bore" and connector.kind != "shaft") \
				or connector.radius <= WIDE or connector.length < 1.0:
			continue
		var axis: Vector3 = connector.axis.normalized()
		var square: int = _square_axis(axis)
		if square < 0 or square == 1:
			continue
		var kind: String = "tyre" if connector.kind == "bore" else "rim"
		if not _bare(part, connector, square, kind == "tyre"):
			continue
		var joined: bool = false
		for group: Array in groups:
			if group[0] != kind or absf(float(group[5]) - connector.radius) > 0.5 \
					or absf((group[2] as Vector3).dot(axis)) < 0.999:
				continue
			var way: Vector3 = group[2]
			var gap: Vector3 = connector.position - (group[1] as Vector3)
			if (gap - way * gap.dot(way)).length() > Joints.ROUND_OFF_AXIS:
				continue
			var a: float = gap.dot(way)
			var b: float = a + connector.length * axis.dot(way)
			group[3] = minf(float(group[3]), minf(a, b))
			group[4] = maxf(float(group[4]), maxf(a, b))
			group[5] = maxf(float(group[5]), connector.radius)
			joined = true
			break
		if not joined:
			groups.append([kind, connector.position, axis, 0.0, connector.length,
				connector.radius])
	var out: Array = []
	for group: Array in groups:
		var end := End.new()
		end.kind = group[0]
		end.axis = group[2]
		end.at = (group[1] as Vector3) + end.axis * (float(group[3]) + float(group[4])) * 0.5
		end.reach = (float(group[4]) - float(group[3])) * 0.5
		end.radius = group[5]
		out.append(end)
	return out


## Which of the part's own axes [param axis] runs along, or -1 when it is
## square to none of them.
static func _square_axis(axis: Vector3) -> int:
	for n: int in 3:
		if absf(axis[n]) > 0.999:
			return n
	return -1


## Whether nothing of the part's cover comes inside a bore's round along its
## length ([param inside]), or reaches outside a shaft's: from in from
## either end of it, where the part's own faces meet it, by a cell or a
## quarter of its length. Never by all of it: a Technic brick's hole is a
## short round 8 across at each mouth, and asked along none of it, it was
## a rim the brick's own body stands outside.
static func _bare(part: Lbm.PartMesh, round: Lbm.Connector, along: int, inside: bool) -> bool:
	var a: float = round.position[along]
	var b: float = a + round.length * round.axis.normalized()[along]
	var inset: float = minf(part.cell_ldu, round.length * 0.25)
	var low: float = minf(a, b) + inset
	var high: float = maxf(a, b) - inset
	var u: int = (along + 1) % 3
	var v: int = (along + 2) % 3
	var cu: float = round.position[u]
	var cv: float = round.position[v]
	for cells: AABB in part.boxes:
		var box := AABB(cells.position * part.cell_ldu, cells.size * part.cell_ldu)
		if box.end[along] <= low or box.position[along] >= high:
			continue
		if inside:
			var du: float = maxf(0.0, maxf(box.position[u] - cu, cu - box.end[u]))
			var dv: float = maxf(0.0, maxf(box.position[v] - cv, cv - box.end[v]))
			if sqrt(du * du + dv * dv) < round.radius - WRAP_SLACK:
				return false
		else:
			var fu: float = maxf(absf(box.position[u] - cu), absf(box.end[u] - cu))
			var fv: float = maxf(absf(box.position[v] - cv), absf(box.end[v] - cv))
			if sqrt(fu * fu + fv * fv) > round.radius + WRAP_SLACK:
				return false
	return true


## The radius of a pin, and of a round hole one goes through, in LDU.
const PIN_ROUND := 6.0
## How deep a Technic hole's counterbore takes a pin's collar, in LDU: a
## pin's connector is the middle of its collar, which sits half in.
const COUNTERBORE := 2.0


## Whether a hole already found runs along the line through [param at]
## going [param axis]: a Technic hole's own bore is that hole.
static func _on_a_hole(ends: Array, at: Vector3, axis: Vector3) -> bool:
	for other: End in ends:
		if not other.is_hole() or absf(other.axis.dot(axis)) < 0.999:
			continue
		var gap: Vector3 = at - other.at
		if (gap - axis * gap.dot(axis)).length() <= Joints.ROUND_OFF_AXIS:
			return true
	return false


## Whether an end is already in the list: the same kind, the same way, at
## nearly the same place (3705 has two connectors at one tip).
static func _repeats(ends: Array, end: End) -> bool:
	for other: End in ends:
		if other.kind == end.kind and other.axis.dot(end.axis) > 0.999 \
				and other.at.distance_to(end.at) < 4.0 \
				and absf(other.reach - end.reach) < 4.0:
			return true
	return false


## How far a box reaches behind and ahead of a point along an axis.
static func _extent(box: AABB, from: Vector3, axis: Vector3) -> Vector2:
	var low: float = INF
	var high: float = -INF
	for n: int in 8:
		var along: float = (box.get_endpoint(n) - from).dot(axis)
		low = minf(low, along)
		high = maxf(high, along)
	return Vector2(low, high)


## Where a hole runs, along its axis from its connector: from its own
## bores where it has them (a pin hole is a bore 6 across with a
## counterbore 8 across at each mouth), or the part's own thickness there,
## no more than a stud each way, where it has none (an axle hole is a
## cross, which is not round).
static func _hole_span(part: Lbm.PartMesh, at: Vector3, axis: Vector3) -> Vector2:
	var low: float = INF
	var high: float = -INF
	for connector: Lbm.Connector in part.connectors:
		if connector.kind != "bore" or connector.radius < 5.0 or connector.radius > 9.0:
			continue
		if absf(connector.axis.dot(axis)) < 0.999:
			continue
		var gap: Vector3 = connector.position - at
		if (gap - axis * gap.dot(axis)).length() > Joints.ROUND_OFF_AXIS:
			continue
		var a: float = gap.dot(axis)
		var b: float = a + connector.length * connector.axis.dot(axis)
		if minf(a, b) > 12.0 or maxf(a, b) < -12.0:
			continue
		low = minf(low, minf(a, b))
		high = maxf(high, maxf(a, b))
	if low < high:
		return Vector2(low, high)
	var span: Vector2 = _extent(part.bounds, at, axis)
	return Vector2(maxf(span.x, -BrickLattice.STUD), minf(span.y, BrickLattice.STUD))


## Whether an end in hand goes onto or into an end already down.
static func mates(held: End, site: End) -> bool:
	if not (TAKES.get(held.kind, []) as Array).has(site.kind):
		return false
	if held.is_round() or held.is_wrap():
		return absf(held.radius - site.radius) <= Joints.ROUND_FIT
	if held.is_hinge():
		return held.sub == site.sub and held.pol != site.pol
	return true


## How far a turn about this joint goes per step, in degrees: a quarter
## for a cross in a cross, otherwise [param fine] if it is finer than
## [constant ROUND_STEP].
static func step_of(held: End, site: End, fine: float) -> float:
	if (held.kind == "axle" or held.kind == "axle_hole") \
			and (site.kind == "axle" or site.kind == "axle_hole"):
		return CROSS_STEP
	return minf(ROUND_STEP, fine) if fine > 0.0 else ROUND_STEP


## The ways one end in hand can go on one end already down, in the order
## they are offered: [side, slide] pairs. Side is which way along the
## joint's axis the part goes (a pin from the near or the far face of a
## beam, a beam the right way up or over); slide is, for a clip or a bar,
## where along the other the middle of this one goes, in LDU from the
## other's start. [param from] is where the pointer's line starts, which
## says which face is near.
static func ways(held: End, site: End, from: Vector3, way: Vector3) -> Array:
	var middle: Vector3 = site.at + site.axis * (site.reach * 0.5) if site.is_round() \
		else site.at
	var near: int = 1 if site.axis.dot(from - middle) >= 0.0 else -1
	if held.is_male():
		return [[near, 0.0], [-near, 0.0]]
	if held.is_hole() and site.kind == "axle" and site.back > 0.0:
		# Along an axle to where the pointer is, a whole LDU at a time: from
		# its hole just on the tip to its far side at the other tip. A wheel
		# or a bush goes on an axle anywhere along it (8841-1's belt wheel
		# halfway along its axle; the 1 x 4 on the axle's last 11 LDU).
		var wanted: float = -site.along_nearest(from, way) - held.reach
		var slide_on: float = clampf(roundf(wanted), 1.0 - held.reach, site.back - held.reach)
		return [[1, slide_on], [-1, slide_on]]
	if held.is_hole() or held.is_wrap():
		return [[1, 0.0], [-1, 0.0]]
	if held.is_hinge():
		# Along the line the way that keeps the part's own up the higher
		# first, each turned about it as it hangs shut ([method _shut]),
		# which is where the turn about the joint starts from: its slide.
		var out: Array = []
		for side: int in [1, -1]:
			out.append([side, _shut(held, site, side)])
		var up_one: float = (pose(held, site, 1, 0.0, 0.0, Basis.IDENTITY).basis * Vector3.UP).y
		var up_other: float = (pose(held, site, -1, 0.0, 0.0, Basis.IDENTITY).basis * Vector3.UP).y
		if up_other > up_one + 0.001:
			out.reverse()
		return out
	var length: float = held.reach
	var room: float = site.reach
	var out: Array = []
	if length <= room:
		# A clip on a bar: where the pointer is along the bar, on a step
		# from the bar's middle, so a clip as long as the bar but a step
		# can still sit square in the middle of it.
		var low: float = length * 0.5
		var high: float = room - length * 0.5
		var middle_of: float = room * 0.5
		var want: float = clampf(site.along_nearest(from, way), low, high)
		var slide: float = clampf(middle_of + roundf((want - middle_of) / SLIDE) * SLIDE,
			low, high)
		for side: int in [1, -1]:
			out.append([side, slide])
		return out
	# A bar through a clip: its end at the clip, running towards the
	# viewer, or away, or the clip at its middle.
	var toward: float = room - length * 0.5 if near < 0 else length * 0.5
	var away: float = length * 0.5 if near < 0 else room - length * 0.5
	for slide: float in [toward, away, room * 0.5]:
		for side: int in [1, -1]:
			out.append([side, slide])
	return out


## Where the part goes to put [param held] (in its own frame) on
## [param site] (in the world): the way it goes and where along it, from
## [method ways], and turned [param roll] degrees about the joint. Starts
## from [param basis], the way the part is held, turned as little as will
## line it up, so a part keeps the turn it was given. A hinge's half is
## laid on the other as BrickAgent lays one (Attach.pose): their frames one,
## flipped end for end on side -1, turned about the line by its slide, the
## turn it hangs shut at, and the roll.
static func pose(held: End, site: End, side: int, slide: float, roll: float,
		basis: Basis) -> Transform3D:
	if held.is_hinge():
		var turn := Basis(Vector3.UP, deg_to_rad(slide + roll))
		if side == -1:
			turn = turn * Attach.RX_PI
		var hung: Transform3D = Transform3D(site.frame, site.at) * Transform3D(turn, Vector3.ZERO) \
			* Transform3D(held.frame, held.at).affine_inverse()
		return Transform3D(_tidy(hung.basis), Vector3(snappedf(hung.origin.x, 0.001),
			snappedf(hung.origin.y, 0.001), snappedf(hung.origin.z, 0.001)))
	var along: Vector3 = site.axis
	var facing: Vector3
	var target: Vector3
	var anchor: Vector3 = held.at
	if held.is_male():
		# Into a hole from one face: the part's end points into it.
		facing = along * -side
		var mouth: Vector3 = site.at + along * (site.reach * side)
		target = mouth if held.reach >= COLLAR else site.at - along * (site.reach * side)
	elif held.is_hole():
		# Over a pin, against its collar; over an axle's tip, flush with it.
		facing = along * side
		target = site.at + site.axis * held.reach if site.reach >= COLLAR \
			else site.at - site.axis * (held.reach + slide)
	elif held.is_wrap():
		# A tyre round a rim, or a rim into a tyre: the middles of their
		# rounds together, either way round.
		facing = along * side
		target = site.at
	else:
		facing = along * side
		anchor = held.at + held.axis * (held.reach * 0.5)
		target = site.at + along * slide
	var turned: Basis = _turned_onto(basis, held.axis, facing)
	turned = Basis(along, deg_to_rad(roll)) * turned
	turned = _tidy(turned)
	var origin: Vector3 = target - turned * anchor
	return Transform3D(turned, Vector3(snappedf(origin.x, 0.001), snappedf(origin.y, 0.001),
		snappedf(origin.z, 0.001)))


## The turn about a hinge, in degrees from its two frames' own, a whole
## quarter, that hangs the part in hand most over the middle of the part it
## goes on: a door shut in its frame, a shutter across its window. BrickNet's
## frames on 60596's two hinges point one way, so a door on the right-hand
## one, turned by none, stood open back to back with the frame, through its
## post.
static func _shut(held: End, site: End, side: int) -> float:
	var mine: Vector3 = held.frame.inverse() * (held.box.get_center() - held.at)
	if side == -1:
		mine = Attach.RX_PI * mine
	var theirs: Vector3 = site.frame.inverse() * (site.on * site.box.get_center() - site.at)
	var from := Vector3(mine.x, 0.0, mine.z)
	var to := Vector3(theirs.x, 0.0, theirs.z)
	if from.length() < 1.0 or to.length() < 1.0:
		return 0.0
	return roundf(rad_to_deg(from.signed_angle_to(to, Vector3.UP)) / 90.0) * 90.0


## [param basis] turned as little as takes [param axis] (in the part's own
## frame) to point along [param facing].
static func _turned_onto(basis: Basis, axis: Vector3, facing: Vector3) -> Basis:
	var now: Vector3 = (basis * axis).normalized()
	var dot: float = now.dot(facing)
	if dot > 0.99999:
		return basis
	var arc: Quaternion
	if dot < -0.99999:
		# Half a turn, about the square axis least along the facing.
		var about: Vector3 = Vector3.UP if absf(facing.y) < 0.9 else Vector3.RIGHT
		about = (about - facing * about.dot(facing)).normalized()
		arc = Quaternion(about, PI)
	else:
		arc = Quaternion(now, facing)
	return (Basis(arc) * basis).orthonormalized()


## A basis within a whisker of one of the twenty-four square ones made
## exactly that one, so a part turned onto a square joint is square.
static func _tidy(basis: Basis) -> Basis:
	var square: Basis = BrickLattice.snap_basis(basis)
	for n: int in 3:
		if (square[n] - basis[n]).length() > 0.001:
			return basis.orthonormalized()
	return square


## The ends of every brick down, in the world, for the ends in hand to be
## put on.
static func sites_in(world: BrickWorld, library: PartLibrary) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		for end: End in ends_for(library, brick.part_id):
			out.append(end.placed(brick.transform, brick.id))
	return out


## Every part down kept with its ends, placed (as sites_in places them), by
## where they could be aimed at from (BrickGrid): the point
## [method End.aimed] gives (along a bar or a clip, anywhere on it; a
## hinge's, anywhere on its part), and as far round it as aimed_at looks,
## REACH and its half-LDU of a tie. A part with no ends is never asked.
static func site_grid(library: PartLibrary) -> BrickGrid:
	return BrickGrid.new(library, func(brick: BrickWorld.Brick, part: Lbm.PartMesh) -> Array:
		var ends: Array = []
		var box := AABB()
		for end: End in ends_for(library, brick.part_id) if part != null else []:
			var placed: End = end.placed(brick.transform, brick.id)
			var room := AABB(placed.aimed(Vector3.ZERO, Vector3.FORWARD), Vector3.ZERO)
			if placed.is_hinge():
				room = brick.transform * placed.box
			elif placed.is_round():
				room = AABB(placed.at, Vector3.ZERO).expand(placed.at + placed.axis * placed.reach)
			elif placed.back > 0.0:
				room = AABB(placed.at, Vector3.ZERO).expand(placed.at - placed.axis * placed.back)
			box = room if ends.is_empty() else box.merge(room)
			ends.append(placed)
		return [box.grow(REACH + 0.5) if not ends.is_empty() else null, ends, false])


## The ends of the parts in [param grid] (site_grid) that the line from
## [param from] going [param way] may be aimed at, no further than
## [param before]: of everything sites_in gives, in its order, every end
## aimed_at could choose.
static func near(grid: BrickGrid, from: Vector3, way: Vector3, before: float) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in grid.along(from, way, before):
		out.append_array(grid.kept_with(brick.id))
	return out


## The end of all [param sites] the pointer's line is aimed at, that
## [param held] has an end for: nearest the line, within [constant REACH],
## no further along it than [param before] (where it met something), and
## the nearer of two as near, on no brick in [param unseen] (hidden, which
## the pointer passes through). With none, the first of [method framed]:
## a hinge half of a part the line passes through the box of. Null when
## there is none.
static func aimed_at(sites: Array, held: Array, from: Vector3, way: Vector3,
		before: float, unseen: Dictionary = {}) -> End:
	var wanted: Dictionary = {}
	for end: End in held:
		for kind: String in TAKES.get(end.kind, []):
			wanted[kind] = true
	var best: End = null
	var best_off: float = REACH
	var best_along: float = INF
	for site: End in sites:
		if not wanted.has(site.kind) or unseen.has(site.brick):
			continue
		var usable: bool = false
		for end: End in held:
			if mates(end, site):
				usable = true
				break
		if not usable:
			continue
		var point: Vector3 = site.aimed(from, way)
		var along: float = (point - from).dot(way)
		if along <= 0.0 or along > before:
			continue
		var off: float = ((point - from) - way * along).length()
		if off < best_off - 0.5 or (off <= best_off + 0.5 and along < best_along):
			best = site
			best_off = minf(off, best_off)
			best_along = along
	if best != null:
		return best
	var framed_by: Array = framed(sites, held, from, way, before, unseen)
	return framed_by[0] if not framed_by.is_empty() else null


## Of [param sites], the hinge halves a hinge of [param held] goes on whose
## part's box the line from [param from] going [param way] enters no further
## along than [param before]: those of the part it enters first, nearest
## where it enters first. A door is put in its frame by pointing anywhere at
## the frame, its posts, its top or through its opening, as Studio and LDD
## seat one, where a hinge's line, at the inside of a post, is a stud and a
## half from the opening's middle; at a post, on that post's hinge, and on
## the face pointed at where a frame has a hinge on each (30179).
static func framed(sites: Array, held: Array, from: Vector3, way: Vector3,
		before: float, unseen: Dictionary = {}) -> Array:
	var hinges: Array = held.filter(func(end: End) -> bool: return end.is_hinge())
	var found: Array = []   ## [where the line enters, how far that is from the hinge, the site]
	if hinges.is_empty():
		return found
	for site: End in sites:
		if not site.is_hinge() or unseen.has(site.brick) \
				or not hinges.any(func(end: End) -> bool: return mates(end, site)):
			continue
		var into: Transform3D = site.on.affine_inverse()
		var entered: Variant = site.box.intersects_ray(into * from, (into.basis * way).normalized())
		if entered == null:
			continue
		var at: Vector3 = site.on * (entered as Vector3)
		var t: float = (at - from).dot(way)
		if t > before:
			continue
		var on_line: Vector3 = site.at + site.axis * clampf((at - site.at).dot(site.axis),
			-site.reach, site.reach)
		found.append([t, at.distance_to(on_line), site])
	found.sort_custom(func(a: Array, b: Array) -> bool:
		if absf(float(a[0]) - float(b[0])) > 1.0:
			return float(a[0]) < float(b[0])
		return float(a[1]) < float(b[1]))
	return found.map(func(row: Array) -> End: return row[2])


## Whether [param site] is within [constant REACH] of the line from [param
## from] going [param way]: aimed at itself, not only through its part's box
## ([method framed]).
static func within_reach(site: End, from: Vector3, way: Vector3) -> bool:
	var point: Vector3 = site.aimed(from, way)
	return ((point - from) - way * (point - from).dot(way)).length() < REACH


## Every way the part's ends go on [param site], in the order offered:
## [end, side, slide].
static func choices(held: Array, site: End, from: Vector3, way: Vector3) -> Array:
	var out: Array = []
	for end: End in held:
		if not mates(end, site):
			continue
		for pair: Array in ways(end, site, from, way):
			out.append([end, pair[0], pair[1]])
	return out


## In words: "the pin hole of Technic Brick 1 x 2 with Hole", "the hinge of
## Door 1 x 4 x 6 Frame". A bore a bar's size is a clip on a part named for
## one, and otherwise a hollow: a hollow stud's, or a pin's middle.
static func describe(site: End, name: String) -> String:
	var said: String = SAID.get(site.kind, site.kind)
	if site.kind == "bore" and not name.to_lower().contains("clip"):
		said = "hollow"
	return "the %s of %s" % [said, name]
