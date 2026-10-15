## Where a pin, an axle or a ball joins two parts.
##
## Studs are found geometrically: a stud ends up inside the part above
## it, so sampling past its tip finds what it holds. A pin cannot be
## found that way, because the hole it goes into is empty space — it has
## to be, or the pin would read as a collision — so the two connectors
## have to be matched to each other instead.
##
## This lives on its own because two callers need the same answer from
## different inputs, and they had drifted apart once already in this
## project's history over the stud convention. The assistant asks about
## a design it is holding as placements; the instructions ask about a
## world of bricks with transforms. Both want "which of these joins to
## which", and a joint means different things to each: the checker lets
## a joint overlap and counts it as holding something, while the
## booklet needs to put the hole on the table before the pin goes in.
class_name Joints
extends RefCounted

## Which kind of connector accepts which, male to female or neutral.
const MATES: Dictionary = {
	"pin": "pin_hole",
	"axle": "axle_hole",
	"ball": "socket",
	"bar": "clip",
}

## A shaft is in a bore when the two are one axis to within this, in LDU.
## Three quarters of a cell: a bar a cell off a clip's axis is beside the
## clip, not in it, and its cover says so. Not half: a real set drawn with a
## clip turned to 66 degrees (20015's 60470a on 48336's handle) has the
## clip's eye 1.1 LDU off the bar, as LDraw's six decimals put it, and the
## 24 parts hung off it floated. Mechanism's axles allow the same
## (LINE_SLACK).
const ROUND_OFF_AXIS := 1.5
## And when the bore is no more than this wider or narrower than the
## shaft. A hinge plate's pin is drawn 3.9 across in an eye of 4 (2430 in
## 2429), and a bar in a pin hole, 4 in 6, rattles: real sets do not hang
## anything that way.
const ROUND_FIT := 1.0
## How far along its axis a shaft must reach into a bore to be in it.
const ROUND_DEPTH := 0.5
## How far a cover's cell may stand outside the round it belongs to, in
## LDU, for a part square to the grid and for one turned. A square part's
## cells are those whose middles are inside it, and the boxes merging them
## reach half a cell's diagonal past a curve, 1.41. A turned part keeps
## every cell its boxes touch at all, which is that plus another half
## diagonal of a cell, 1.73.
const ROUND_SLACK := 1.5
const ROUND_SLACK_TURNED := 3.2
## How far off the mate's axis line a connector may sit, in LDU. A pin
## bore is 6 LDU, so 4 keeps it inside the hole it claims to be in and
## stops a pin matching the hole one stud over.
const OFF_AXIS := 4.0
## How far along that line the two may be apart, in LDU. A pin's own
## connector sits at the pin's middle and a hole's at the hole's middle,
## and a pin joining two beams is half a stud from each.
const ALONG_AXIS := 20.0
## The box a mate is looked for in, in LDU. One stud, which is
## ALONG_AXIS, so a mate is in this box or one of the twenty-six
## touching it.
const BUCKET := 20.0


## Which things join to which, as [plug, socket] pairs.
##
## [param entries] is an array of [key, Transform3D, Lbm.PartMesh]. The
## key is whatever the caller wants back — a placement index, a brick id
## — and comes out untouched.
static func pairs(entries: Array) -> Array:
	## Bucketed, so a pin is compared with the holes near it rather than
	## with every hole in the model. A chassis has hundreds of each and
	## all-against-all is their product.
	var sockets: Dictionary = {}   ## Vector3i -> Array of [key, kind, at, way]
	var plugs: Array = []
	for entry: Array in entries:
		var part: Lbm.PartMesh = entry[2]
		if part == null:
			continue
		var at: Transform3D = entry[1]
		for connector: Lbm.Connector in part.connectors:
			if connector.kind == "stud" or connector.kind == "tube" \
					or connector.kind == "ridge":
				continue
			var where: Vector3 = at * connector.position
			var way: Vector3 = (at.basis * connector.axis).normalized()
			if connector.gender == "male":
				if MATES.has(connector.kind):
					plugs.append([entry[0], connector.kind, where, way])
			else:
				var box: Vector3i = _bucket(where)
				if not sockets.has(box):
					sockets[box] = []
				sockets[box].append([entry[0], connector.kind, where, way])

	var found: Array = []
	var seen: Dictionary = {}
	# An axle or a pin is in every hole along its whole length, not only
	# the ones by its ends: an axle 6 through two beams' holes and a gear's
	# between them is in all three, and the connectors by its tips are
	# nowhere near the gear. A part with an axle hole goes onto the axle,
	# as a wheel goes onto its pin; the axle goes into a round hole.
	for one: Array in through(entries):
		var pair: Array = [one[1], one[0]] if one[2] == "grips" else [one[0], one[1]]
		var key: String = "%s|%s" % pair
		if not seen.has(key):
			seen[key] = true
			found.append(pair)
	for plug: Array in plugs:
		var wanted: String = MATES[plug[1]]
		var home: Vector3i = _bucket(plug[2])
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					var near: Variant = sockets.get(home + Vector3i(dx, dy, dz))
					if near == null:
						continue
					for socket: Array in near:
						if socket[0] == plug[0] or socket[1] != wanted:
							continue
						if not lines_up(plug[2], plug[3], socket[2], socket[3]):
							continue
						var key: String = "%s|%s" % [plug[0], socket[0]]
						if seen.has(key):
							continue
						seen[key] = true
						found.append([plug[0], socket[0]])
	return found


## Every hole along an axle or a pin, as [shaft key, hole key, how]: how is
## "grips" for an axle in an axle hole (the two turn as one) and "turns"
## for an axle or a pin in a round hole. The rule is Mechanism's, so the
## checker and the mechanism agree about what holds what: a hole is on the
## line to within [constant Mechanism.LINE_SLACK] and its middle is no more
## than [constant Mechanism.REACH_SLACK] past either end; a pin does not go
## into an axle hole.
static func through(entries: Array) -> Array:
	var holes: Dictionary = {}    ## bucket -> Array of [key, kind, middle, way]
	var lines: Array = []         ## [key, kind, origin, way, from, to]
	for entry: Array in entries:
		var part: Lbm.PartMesh = entry[2]
		if part == null:
			continue
		var at: Transform3D = entry[1]
		var own: Array = _lines_of(part)
		for line: Array in own[0]:
			lines.append([entry[0], line[0], at * (line[1] as Vector3),
				(at.basis * (line[2] as Vector3)).normalized(), line[3], line[4]])
		for hole: Array in own[1]:
			Mechanism._bucket_in(holes, [entry[0], hole[0], at * (hole[1] as Vector3),
				(at.basis * (hole[2] as Vector3)).normalized()])
	var out: Array = []
	if holes.is_empty():
		return out
	var seen: Dictionary = {}
	for line: Array in lines:
		var origin: Vector3 = line[2]
		var way: Vector3 = line[3]
		for hole: Array in Mechanism._near_line(holes, origin, way, float(line[4]),
				float(line[5])):
			if hole[0] == line[0] or absf((hole[3] as Vector3).dot(way)) < 0.99:
				continue
			if line[1] == "pin" and hole[1] == "axle":
				continue
			var gap: Vector3 = (hole[2] as Vector3) - origin
			var along: float = gap.dot(way)
			if along < float(line[4]) - Mechanism.REACH_SLACK \
					or along > float(line[5]) + Mechanism.REACH_SLACK:
				continue
			if (gap - way * along).length() > Mechanism.LINE_SLACK:
				continue
			var how: String = "grips" if line[1] == "axle" and hole[1] == "axle" else "turns"
			var key: String = "%s|%s" % [line[0], hole[0]]
			if seen.has(key):
				# An axle keyed in one of a part's holes and through a round one
				# of the same part is keyed to it.
				if how == "grips":
					(out[int(seen[key])] as Array)[2] = how
				continue
			seen[key] = out.size()
			out.append([line[0], hole[0], how])
	return out


## A part's axles and pins and its holes, in its own frame, worked out once
## per part: [Mechanism._shaft_of, its holes as Mechanism._holes_of gives
## them, the pin and axle holes its connectors name and no bare bore].
##
## A bore its size is a round hole to Mechanism, and rightly: it turns. But
## the checker forgives a pair joined here all over, as it does a pin in its
## hole, and a bore is where a hinge's two halves meet: 3830's pin in 3831's
## eye, which Joints.rounds forgives only inside the eye. Taken as a hole
## here, the top swung a quarter turn into its own base was buildable.
static var _lines: Dictionary = {}


static func _lines_of(part: Lbm.PartMesh) -> Array:
	var key: int = part.get_instance_id()
	if not _lines.has(key):
		var shafts: Array = Mechanism._shaft_of(part)
		var named: Array = []
		for hole: Array in Mechanism._holes_of(part, shafts):
			for connector: Lbm.Connector in part.connectors:
				if (connector.kind == "pin_hole" or connector.kind == "axle_hole") \
						and Mechanism._same_line(connector.position,
							connector.axis.normalized(), hole[1], hole[2]) \
						and connector.position.distance_to(hole[1]) < 1.0:
					named.append(hole)
					break
		_lines[key] = [shafts, named]
	return _lines[key]


## Gears whose teeth are in each other's, both ways round: key -> {other key
## -> "an 8 with a 24"}; and each such gear with the axle its partner is
## keyed on, said "past the axle of what it meshes". Their covers are discs, and two discs a mesh apart
## share the ring the teeth turn in, so the checker would refuse every
## gear train there is; this is what it forgives. Read by Mechanism, from
## the gear table, so a mesh here is a mesh there: spur, crown, bevel and
## worm, at the pitch the table gives to within [constant Mechanism.MESH_SLACK].
## [param entries] as [method pairs] takes them, with the part's id fourth.
static func meshing(entries: Array) -> Dictionary:
	var out: Dictionary = {}
	var gears: Array = []
	for entry: Array in entries:
		if entry.size() < 4 or entry[2] == null:
			continue
		if Mechanism.spec_of(str(entry[3])).is_empty():
			continue
		gears.append({"key": gears.size() + 1, "part": str(entry[3]), "at": entry[1],
			"mesh": entry[2], "was": entry[0]})
	if gears.size() < 2:
		return out
	var model: Mechanism = Mechanism.build(gears)
	for coupling: Mechanism.Coupling in model.couplings:
		if coupling.how == "chain":
			continue
		var one: Variant = gears[coupling.one.key - 1]["was"]
		var other: Variant = gears[coupling.other.key - 1]["was"]
		var said: String = "%s with %s" % [_teeth(coupling.one), _teeth(coupling.other)]
		# Meshing, at the teeth's ratio, but further out than real sets
		# stand theirs: said, so a builder knows it runs loose or tight.
		if not coupling.off_said().is_empty():
			said += " (%s)" % coupling.off_said()
		for pair: Array in [[one, other], [other, one]]:
			if not out.has(pair[0]):
				out[pair[0]] = {}
			(out[pair[0]] as Dictionary)[pair[1]] = said
	if out.is_empty():
		return out
	# And each gear with the axle its partner is keyed on. On a stud's
	# diagonal a 28 meshing an 8 stands 44.72 from the 8's middle, and its
	# teeth clear the 8's axle by 1.4 LDU: a cell of the 2 LDU lattice, so the
	# two covers met, and the check refused the 8 and 28 real sets stand at
	# 44.7. A gear in mesh never reaches its partner's axle: the partner's
	# pitch circle is between them.
	var keyed: Dictionary = {}   ## a gear's own key -> the shafts gripping it
	for one: Array in through(entries):
		if str(one[2]) == "grips":
			if not keyed.has(one[1]):
				keyed[one[1]] = []
			(keyed[one[1]] as Array).append(one[0])
	for gear: Variant in out.keys():
		for partner: Variant in (out[gear] as Dictionary).keys():
			for shaft: Variant in keyed.get(partner, []):
				if shaft == gear:
					continue
				for pair: Array in [[gear, shaft], [shaft, gear]]:
					if not out.has(pair[0]):
						out[pair[0]] = {}
					if not (out[pair[0]] as Dictionary).has(pair[1]):
						(out[pair[0]] as Dictionary)[pair[1]] = "past the axle of what it meshes"
	return out


## "an 8", "a 24", "a worm".
static func _teeth(gear: Mechanism.Gear) -> String:
	if gear.kind == "worm":
		return "a worm"
	return ("an %d" if gear.teeth in [8, 11, 18, 80] else "a %d") % gear.teeth


## Each thing joined, to everything it is joined to, both ways round.
static func both_ways(entries: Array) -> Dictionary:
	var held: Dictionary = {}
	for pair: Array in pairs(entries):
		_add(held, pair[0], pair[1])
		_add(held, pair[1], pair[0])
	return held


static func _add(held: Dictionary, one: Variant, other: Variant) -> void:
	if not held.has(one):
		held[one] = {}
	(held[one] as Dictionary)[other] = true


## Whether a plug at one place, pointing one way, is inside a socket.
static func lines_up(plug_at: Vector3, plug_way: Vector3,
		socket_at: Vector3, socket_way: Vector3) -> bool:
	# Collinear, either nose to nose or the same way round: a hole is
	# neutral and its recorded direction is whichever face was read first.
	if absf(plug_way.dot(socket_way)) < 0.95:
		return false
	var gap: Vector3 = plug_at - socket_at
	var along: float = gap.dot(socket_way)
	if absf(along) > ALONG_AXIS:
		return false
	return (gap - socket_way * along).length() <= OFF_AXIS


## How far apart a ball's middle and a socket's may be and the ball be in
## the socket, in LDU. A ball is 16 across; a cell is 2.
const BALL_SLACK := 2.0


## Balls in sockets, both ways round: key -> {other key -> true}. A Joint-8
## ball or a towball (a sphere 16 LDU across, which is what a towball is:
## tools/ldraw/connectivity.py reads both as "ball") in a socket whose
## middle is its middle, whichever way either is turned. [method pairs]
## asks a ball to line up with its socket's axis, which a ball turned in its
## socket, as a towball on a trailer always is, does not: 3184's 2508
## towballs in 98263's sockets held nothing, and 235 parts floated.
static func balls(entries: Array) -> Dictionary:
	var sockets: Dictionary = {}   ## bucket -> Array of [key, middle]
	var found: Array = []          ## [key, middle]
	for entry: Array in entries:
		var part: Lbm.PartMesh = entry[2]
		if part == null:
			continue
		var at: Transform3D = entry[1]
		for connector: Lbm.Connector in part.connectors:
			if connector.kind == "ball":
				found.append([entry[0], at * connector.position])
			elif connector.kind == "socket":
				var middle: Vector3 = at * connector.position
				var box: Vector3i = _bucket(middle)
				if not sockets.has(box):
					sockets[box] = []
				(sockets[box] as Array).append([entry[0], middle])
	var held: Dictionary = {}
	for ball: Array in found:
		var home: Vector3i = _bucket(ball[1])
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					for socket: Array in sockets.get(home + Vector3i(dx, dy, dz), []):
						if socket[0] != ball[0] \
								and (socket[1] as Vector3).distance_to(ball[1]) <= BALL_SLACK:
							_add(held, ball[0], socket[0])
							_add(held, socket[0], ball[0])
	return held


## [param more]'s joints added to [param into]'s, both key -> {key -> true}.
static func merge(into: Dictionary, more: Dictionary) -> void:
	for key: Variant in more:
		for other: Variant in more[key]:
			_add(into, key, other)


## The line a part turns on as one half of a hinge, in its own frame:
## [a point on it, its way], or [] for none. A click hinge's finger or fork
## first (the middle of its knuckle), then a round a pin or a bar is (a
## hinge brick's pin and eye, a hinge plate's, a clip's or a bar's: radius
## 3.5 to 6.5, the longest), then a ball or a socket's centre with no way
## (Vector3.ZERO), which turns about any. For laying a hinge's two halves
## on one line from the parts' own data.
static func hinge_line_of(mesh: Lbm.PartMesh) -> Array:
	if mesh == null:
		return []
	var best: Lbm.Connector = null
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "finger" or connector.kind == "fork":
			return [connector.position + connector.axis * (connector.length * 0.5),
				connector.axis.normalized()]
		if (connector.kind == "shaft" or connector.kind == "bore") \
				and connector.radius >= 3.5 and connector.radius <= 6.5 \
				and (best == null or connector.length > best.length):
			best = connector
	if best != null:
		return [best.position + best.axis * (best.length * 0.5), best.axis.normalized()]
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "ball" or connector.kind == "socket":
			return [connector.position, Vector3.ZERO]
	return []


## The kinds of round and what each fits: a shaft in a bore of its size,
## a click hinge's finger in a fork (tools/ldraw/connectivity.py, _HINGES),
## and neither in the other's.
const ROUND_FAMILY: Dictionary = {"shaft": "round", "bore": "round",
	"finger": "hinge", "fork": "hinge"}


## Something round turning in something round that fits it, both ways
## round: key -> {other key -> Array of zones}.
##
## A clip on a bar, a bar in a hollow stud, a hinge's pin in its eye and a
## turntable's disc in its base are all a shaft of one part in a bore of
## another, coaxial and the same size (tools/ldraw/connectivity.py finds
## both from the cylinders a part is drawn with). The cover cannot hold
## any of them, because it fills a bore like any other ring, so the two
## parts read as a collision exactly there — and only there. A zone says
## where: [a point on the axis, the axis, from, to, radius, cores], one for
## every bore either part has on that axis that the other reaches into,
## since a bar that goes in through a hollow stud carries on through the
## tube beneath it (see [method _zones_of]). The checker forgives an
## overlap that lies wholly inside the zones and nothing else, so the same
## two parts meeting anywhere else still collide.
##
## Coaxial and nothing more: a turntable's top is in its base at any angle
## about the axis they share, which is the whole point of a turntable.
static func rounds(entries: Array) -> Dictionary:
	var shafts: Array = []    ## [key, start, way, length, radius]
	var bores: Array = []
	var by_key: Dictionary = {}   ## key -> its bores
	var shafts_of: Dictionary = {}   ## key -> its shafts
	for entry: Array in entries:
		var part: Lbm.PartMesh = entry[2]
		if part == null:
			continue
		var at: Transform3D = entry[1]
		for connector: Lbm.Connector in part.connectors:
			if not ROUND_FAMILY.has(connector.kind):
				continue
			var start: Vector3 = at * connector.position
			var end: Vector3 = at * (connector.position + connector.axis * connector.length)
			var way: Vector3 = end - start
			var length: float = way.length()
			if length < 0.001:
				continue
			var row: Array = [entry[0], start, way / length, length, connector.radius,
				ROUND_FAMILY[connector.kind]]
			if connector.kind == "shaft" or connector.kind == "finger":
				shafts.append(row)
				if not shafts_of.has(entry[0]):
					shafts_of[entry[0]] = []
				(shafts_of[entry[0]] as Array).append(row)
			else:
				bores.append(row)
				if not by_key.has(entry[0]):
					by_key[entry[0]] = []
				(by_key[entry[0]] as Array).append(row)

	# Bucketed by where each bore reaches, so a shaft is compared with the
	# bores near it and not with every bore in a model.
	var near: Dictionary = {}
	for n: int in bores.size():
		for box: Vector3i in _buckets_along(bores[n]):
			if not near.has(box):
				near[box] = []
			(near[box] as Array).append(n)

	var held: Dictionary = {}
	for shaft: Array in shafts:
		var tried: Dictionary = {}
		for box: Vector3i in _buckets_along(shaft):
			for n: int in near.get(box, []):
				if tried.has(n):
					continue
				tried[n] = true
				var bore: Array = bores[n]
				if bore[0] == shaft[0] or not _fits(shaft, bore):
					continue
				var zones: Array = []
				for pair: Array in [[shaft[0], bore[0]], [bore[0], shaft[0]]]:
					zones.append_array(_zones_of(by_key.get(pair[0], []),
						shafts_of.get(pair[0], []), shafts_of.get(pair[1], []), bore))
				_add_zones(held, shaft[0], bore[0], zones)
				_add_zones(held, bore[0], shaft[0], zones)
	_knuckles(shafts, held)
	return held


## A hinge's knuckles turn on one line: the older hinge plates (4275b with
## three fingers, 4276b with two) draw each finger's end as a round, and a
## finger of one lies between two of the other, along one line at one size.
## No round is in a bore there, so the plate hinged up on another floated
## (8849's, folded square, where the file has them exactly so). Held both
## ways, and forgiving nothing: knuckles meet end to end.
const KNUCKLE_WIDEST := 8.0
## How far apart along the line two knuckles may end and still meet, LDU.
const KNUCKLE_GAP := 1.0


static func _knuckles(shafts: Array, held: Dictionary) -> void:
	var ends: Dictionary = {}   ## bucket -> Array of shaft indices with an end in it
	for n: int in shafts.size():
		var row: Array = shafts[n]
		if row[5] != "round" or float(row[4]) > KNUCKLE_WIDEST:
			continue
		for end: int in 2:
			var point: Vector3 = (row[1] as Vector3) + (row[2] as Vector3) * (float(row[3]) * end)
			var box: Vector3i = _bucket(point)
			if not ends.has(box):
				ends[box] = []
			(ends[box] as Array).append(n)
	for n: int in shafts.size():
		var knuckle: Array = shafts[n]
		if knuckle[5] != "round" or float(knuckle[4]) > KNUCKLE_WIDEST:
			continue
		var start: Vector3 = knuckle[1]
		var way: Vector3 = knuckle[2]
		var length: float = knuckle[3]
		var before: Dictionary = {}   ## key -> true: a round of that part ending at this one's start
		var after: Dictionary = {}
		var seen: Dictionary = {}
		for end: int in 2:
			var home: Vector3i = _bucket(start + way * (length * end))
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					for dz: int in [-1, 0, 1]:
						for m: int in ends.get(home + Vector3i(dx, dy, dz), []):
							if seen.has(m):
								continue
							seen[m] = true
							var other: Array = shafts[m]
							if other[0] == knuckle[0] \
									or absf(float(other[4]) - float(knuckle[4])) > 0.5 \
									or not _coaxial(other, knuckle):
								continue
							var span: Vector2 = _span(other, start, way)
							if absf(span.y) <= KNUCKLE_GAP and span.x < span.y:
								before[other[0]] = true
							if absf(span.x - length) <= KNUCKLE_GAP and span.y > span.x:
								after[other[0]] = true
		for key: Variant in before:
			if after.has(key):
				_add_zones(held, knuckle[0], key, [])
				_add_zones(held, key, knuckle[0], [])


## One part's bores on a joint's axis that the other part's shafts reach
## into, each as a zone: [a point on the axis, the axis, from, to,
## radius, cores].
##
## Only those reached, and less the part's own plastic inside them. A
## bore is empty only out to its wall and in from anything standing
## inside it: 3941, a 2x2 round brick, is a bore 16 across with its
## centre tube, a shaft 8 across, inside it. A pin pushed into the tube's
## foot is a joint on that axis, and taking the whole 16 as empty would
## forgive anything at all overlapping the tube above it.
static func _zones_of(mine: Array, my_shafts: Array, their_shafts: Array,
		joint: Array) -> Array:
	var origin: Vector3 = joint[1]
	var way: Vector3 = joint[2]
	var out: Array = []
	for bore: Array in mine:
		if not _coaxial(bore, joint):
			continue
		var span: Vector2 = _span(bore, origin, way)
		var reached: bool = false
		for shaft: Array in their_shafts:
			if _coaxial(shaft, joint):
				var reach: Vector2 = _span(shaft, origin, way)
				if minf(span.y, reach.y) - maxf(span.x, reach.x) >= ROUND_DEPTH:
					reached = true
					break
		if not reached:
			continue
		var cores: Array = []
		for core: Array in my_shafts:
			if _coaxial(core, joint) and float(core[4]) < float(bore[4]) - ROUND_FIT:
				var at: Vector2 = _span(core, origin, way)
				cores.append([at.x, at.y, core[4]])
		out.append([origin, way, span.x, span.y, bore[4], cores])
	return out


## Where a round runs along an axis, from and to.
static func _span(row: Array, origin: Vector3, way: Vector3) -> Vector2:
	var a: float = ((row[1] as Vector3) - origin).dot(way)
	var b: float = a + float(row[3]) * (row[2] as Vector3).dot(way)
	return Vector2(minf(a, b), maxf(a, b))


## Whether a shaft is in a bore: one axis, one size, and reaching in.
static func _fits(shaft: Array, bore: Array) -> bool:
	if shaft[5] != bore[5] or absf(float(shaft[4]) - float(bore[4])) > ROUND_FIT:
		return false
	if not _coaxial(shaft, bore):
		return false
	var way: Vector3 = bore[2]
	var a: float = (shaft[1] - bore[1]).dot(way)
	var b: float = a + float(shaft[3]) * (shaft[2] as Vector3).dot(way)
	var reach: float = minf(maxf(a, b), bore[3]) - maxf(minf(a, b), 0.0)
	return reach >= ROUND_DEPTH


## Whether two rounds share an axis line, either way along it.
static func _coaxial(one: Array, other: Array) -> bool:
	var way: Vector3 = other[2]
	if absf((one[2] as Vector3).dot(way)) < 0.999:
		return false
	var gap: Vector3 = one[1] - other[1]
	return (gap - way * gap.dot(way)).length() <= ROUND_OFF_AXIS


static func _add_zones(held: Dictionary, one: Variant, other: Variant,
		zones: Array) -> void:
	if not held.has(one):
		held[one] = {}
	var mine: Dictionary = held[one]
	if not mine.has(other):
		mine[other] = []
	(mine[other] as Array).append_array(zones)


## The stud-sized boxes a round reaches into, ends and middle.
static func _buckets_along(row: Array) -> Array[Vector3i]:
	var start: Vector3 = row[1]
	var end: Vector3 = start + (row[2] as Vector3) * float(row[3])
	var reach := Vector3.ONE * float(row[4])
	var low: Vector3i = _bucket(start.min(end) - reach)
	var high: Vector3i = _bucket(start.max(end) + reach)
	var out: Array[Vector3i] = []
	for x: int in range(low.x, high.x + 1):
		for y: int in range(low.y, high.y + 1):
			for z: int in range(low.z, high.z + 1):
				out.append(Vector3i(x, y, z))
	return out


## Whether every cell two covers share lies inside the zones of a round
## joint between them. The covers are boxes of lattice cells, six ints
## each, low corner then high; [param to_world] carries a cell's middle
## into the coordinates the zones are in, which differ only inside a
## section. False when they share no cell at all.
##
## And, for two halves turned against each other, [param own] — each
## half's frame and its boxes square in that frame — forgives a shared
## cell at either half's surface as well. A hinge's halves are shaped to
## clear each other as the top turns, by less than a cell, and the turned
## half's cover keeps every cell it touches: 3938 tipped ten degrees on
## 3937 shared 149 cells with it, 99 of them outside the pin, along the
## knuckle and under the plate's edges, and the hinge was refused for
## turning. A real collision, the top swung on into the base, is deeper
## than a cell, and still is.
static func overlap_within(mine: PackedInt32Array, theirs: PackedInt32Array,
		zones: Array, to_world: Transform3D, slack: float,
		own: Array = []) -> bool:
	var frames: Array[Transform3D] = []
	for cover: Array in own:
		frames.append((cover[0] as Transform3D).affine_inverse())
	var any: bool = false
	var i: int = 0
	while i < mine.size():
		var j: int = 0
		while j < theirs.size():
			var from := Vector3i(maxi(mine[i], theirs[j]), maxi(mine[i + 1], theirs[j + 1]),
				maxi(mine[i + 2], theirs[j + 2]))
			var to := Vector3i(mini(mine[i + 3], theirs[j + 3]),
				mini(mine[i + 4], theirs[j + 4]), mini(mine[i + 5], theirs[j + 5]))
			if from.x < to.x and from.y < to.y and from.z < to.z:
				for x: int in range(from.x, to.x):
					for y: int in range(from.y, to.y):
						for z: int in range(from.z, to.z):
							var middle: Vector3 = to_world * (
								Vector3(x + 0.5, y + 0.5, z + 0.5) * BrickLattice.CELL)
							if not _in_a_zone(middle, zones, slack) \
									and not _at_a_surface(middle, own, frames):
								return false
							any = true
			j += 6
		i += 6
	return any


## Whether a point is in a cell either cover leaves empty, or in one with
## an empty cell beside it, each cover read in its own square frame.
static func _at_a_surface(point: Vector3, own: Array,
		frames: Array[Transform3D]) -> bool:
	for n: int in own.size():
		var boxes: PackedInt32Array = own[n][1]
		var at: Vector3 = frames[n] * point / BrickLattice.CELL
		var cell := Vector3i(floori(at.x), floori(at.y), floori(at.z))
		for step: Vector3i in SIDES:
			if not _in_boxes(cell + step, boxes):
				return true
	return false


const SIDES: Array[Vector3i] = [Vector3i.ZERO, Vector3i.LEFT, Vector3i.RIGHT,
	Vector3i.DOWN, Vector3i.UP, Vector3i.FORWARD, Vector3i.BACK]


static func _in_boxes(cell: Vector3i, boxes: PackedInt32Array) -> bool:
	var i: int = 0
	while i < boxes.size():
		if cell.x >= boxes[i] and cell.x < boxes[i + 3] \
				and cell.y >= boxes[i + 1] and cell.y < boxes[i + 4] \
				and cell.z >= boxes[i + 2] and cell.z < boxes[i + 5]:
			return true
		i += 6
	return false


## The round of each gear among [param parts] ([part id, Transform3D] each):
## [where it stands, its middle and its axis in its own frame, the radius
## its teeth reach]. A gear's cover is the square round its teeth when its
## outline will not go in the box limit (a 20 is 8 boxes, a 28 and a 36 26),
## and the square's corners are air: [method past_the_teeth] reads them so.
static func gear_rounds(parts: Array, from: PartLibrary) -> Array:
	var out: Array = []
	for one: Array in parts:
		var spec: Dictionary = Mechanism.spec_of(str(one[0]))
		if spec.is_empty() or str(spec.get("kind", "")) in ["worm", "ring"]:
			continue
		var mesh: Lbm.PartMesh = from.mesh_for(str(one[0])) if from != null else null
		if mesh == null:
			continue
		var axis: Vector3 = Mechanism._axis_of(spec.get("axis", "z"))
		var reach: float = 0.0
		for n: int in 3:
			if absf(axis[n]) < 0.5:
				reach = maxf(reach, maxf(absf(mesh.bounds.position[n]), absf(mesh.bounds.end[n])))
		out.append([one[1], axis * float(spec.get("plane", 0.0)), axis, reach])
	return out


## Whether two covers meet only where one of [param rounds] (gear_rounds)
## reaches past its teeth: every cell both hold has its middle outside that
## gear's round. A 20 beside a frame on a stud's diagonal meets it only in
## its square's corner.
static func past_the_teeth(mine: PackedInt32Array, theirs: PackedInt32Array, rounds: Array,
		to_world: Transform3D) -> bool:
	if rounds.is_empty():
		return false
	var any: bool = false
	var i: int = 0
	while i < mine.size():
		var j: int = 0
		while j < theirs.size():
			var from := Vector3i(maxi(mine[i], theirs[j]), maxi(mine[i + 1], theirs[j + 1]),
				maxi(mine[i + 2], theirs[j + 2]))
			var to := Vector3i(mini(mine[i + 3], theirs[j + 3]),
				mini(mine[i + 4], theirs[j + 4]), mini(mine[i + 5], theirs[j + 5]))
			if from.x < to.x and from.y < to.y and from.z < to.z:
				for x: int in range(from.x, to.x):
					for y: int in range(from.y, to.y):
						for z: int in range(from.z, to.z):
							var middle: Vector3 = to_world * (
								Vector3(x + 0.5, y + 0.5, z + 0.5) * BrickLattice.CELL)
							var outside: bool = false
							for round: Array in rounds:
								var at: Transform3D = round[0]
								var centre: Vector3 = at * (round[1] as Vector3)
								var way: Vector3 = (at.basis * (round[2] as Vector3)).normalized()
								var gap: Vector3 = middle - centre
								if (gap - way * gap.dot(way)).length() > float(round[3]):
									outside = true
									break
							if not outside:
								return false
							any = true
			j += 6
		i += 6
	return any


static func _in_a_zone(point: Vector3, zones: Array, slack: float) -> bool:
	for zone: Array in zones:
		var gap: Vector3 = point - (zone[0] as Vector3)
		var along: float = gap.dot(zone[1])
		if along < float(zone[2]) - slack or along > float(zone[3]) + slack:
			continue
		var off: float = (gap - (zone[1] as Vector3) * along).length()
		if off > float(zone[4]) + slack:
			continue
		# Not in plastic of the part's own standing inside the bore: a core
		# is solid, so the slack works inwards from its surface.
		var cored: bool = false
		for core: Array in zone[5]:
			if along > float(core[0]) + slack and along < float(core[1]) - slack \
					and off < float(core[2]) - slack:
				cored = true
				break
		if not cored:
			return true
	return false


## What holds without a stud, a pin, a clip or a hinge: by glue, and by
## being one thing. key -> {other key -> true}, both ways. The build check
## (Assistant._check, check_design, review_model, the bench's probe) and the
## balance (Balance) both join what this says, so a model is in as many
## pieces to the one as it stands in for the other.
##
## A sticker is held by the face it lies on: of the parts behind its film
## (Stickers.lies_on), the one it covers most. Film is no joint, so a
## sticker over two parts leaves them as joined as they were. The check
## joined what sits on a part's top, and a sticker has no connector: two cab
## plates stuck on a locomotive's sides were two pieces of their own.
##
## And a flexible thing is one thing (Flex.one_thing): a hose's rings, a
## string's braids, a cable's or a vine's segments, a chain's links, each one
## with the rest. It is held wherever any of it is, as the plastic says: a
## string by the studs its ends sit on, a hose by the pins in its ends; and
## one end left free hangs from the other. A sailing ship's rigging was
## counted braid by braid, and the ship called 64 pieces.
##
## And magnets that touch hold each other: a train's cars on their couplings.
##
## A part touching nothing is still a piece of its own: nothing here joins
## what is not there. [param entries] are [key, Transform3D, Lbm.PartMesh,
## part id, path], the path the sub-model it is in (Assemblies.path_of), ""
## for none.
static func held_otherwise(entries: Array, library: PartLibrary) -> Dictionary:
	var held: Dictionary = {}
	var films: Array = []
	var solid: Array = []          ## [key, transform, box] of what a film can lie on
	var magnets: Array = []        ## [key, "", box in the world]
	for entry: Array in entries:
		var part: Lbm.PartMesh = entry[2]
		if part == null:
			continue
		if Stickers.sticks(library, str(entry[3])):
			films.append(entry)
			continue
		solid.append([entry[0], entry[1], part.bounds])
		var info: PartLibrary.PartInfo = library.parts.get(str(entry[3]))
		if is_magnet(info):
			magnets.append([entry[0], "", (entry[1] as Transform3D) * part.bounds])
	for film: Array in films:
		var under: Array = Stickers.lies_on(film[1], (film[2] as Lbm.PartMesh).bounds,
			solid, film[0])
		if not under.is_empty():
			_add(held, film[0], under[0][0])
			_add(held, under[0][0], film[0])
	for pair: Array in Flex.one_thing(entries, library) + Flex.touching(magnets):
		_add(held, pair[0], pair[1])
		_add(held, pair[1], pair[0])
	return held


## Whether a part carries a magnet: the magnet family's own, and a train's
## buffer beam or coupling with its magnet in it. The Emerald Night (10194)
## couples its tender with 64422, "Train Buffer Beam with Sealed Magnet",
## filed under Train, and the check had it two pieces. A casing or a holder
## without its magnet ("for Sealed Magnet") holds nothing.
static func is_magnet(info: PartLibrary.PartInfo) -> bool:
	if info == null:
		return false
	if info.category == "Magnet":
		return true
	return _MAGNET_NAME.search(info.name) != null


static var _MAGNET_NAME: RegEx = RegEx.create_from_string(
	"\\b(with|and) (Black |Sealed )?Magnet\\b|^Train Buffer Sealed Magnet$")


## The widest hole or peg [method pushed_in] reads, in LDU: a Technic pin
## hole's bore. A hand's grip and a clip's eye are 4, an arm's shoulder 5;
## anything wider is a turntable, a round brick's inside or a dish, whose
## middle is where other parts stand without being held by it.
const PUSHED_WIDEST := 6.0
## How far a part's origin may be off a post's axis and still be worn on
## it, in LDU. As [constant ROUND_OFF_AXIS].
const WORN_OFF_AXIS := 1.0


## What is pushed into what, by the plastic of one part being where
## another part's hole or peg is: key -> {other key -> true}, both ways.
##
## A joint the connectors cannot pair. A hand closes on whatever is held
## in it, and most of what a figure holds has no bar the hand's grip fits:
## a carrot, a loaf, a cup, a staff whose handle is not round, a sword
## slid through the hand past its hilt. All of them pass through the
## grip, which is empty except where they are. And a peg pushed into a
## hole the connectors never read (the stump's into 5059, a spring into
## its hips) has its middle inside the part it went into. So a bore of a
## part whose middle another part's cover fills holds that part, and a
## peg whose middle is inside another part's cover is held by it. Read at
## the middle, not the ends: a bore's mouth and a peg's root are where the
## parts beside them stand without being joined.
##
## And a part drawn about a post, its origin on the post's axis: a cloth
## cape is worn round a torso's neck and has no hole the connectors can
## read, being cloth. LDraw draws what is worn there about the neck,
## and the cape's origin is on the post.
##
## And a visor on its helmet's pivots ([method _pivots]).
##
## [param entries] are as [method pairs] takes them, with the part's id
## fourth where the caller has it (for the pivots); [param filled] is
## asked (a cell's box, the key asking) for the keys of the other entries
## whose covers fill that cell, each where its entry's transform puts it.
static func pushed_in(entries: Array, filled: Callable) -> Dictionary:
	var held: Dictionary = {}
	var posts: Dictionary = {}   ## bucket -> Array of [key, start, way, length]
	for entry: Array in entries:
		var part: Lbm.PartMesh = entry[2]
		if part == null:
			continue
		var at: Transform3D = entry[1]
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != "shaft" and connector.kind != "bore":
				continue
			if connector.radius > PUSHED_WIDEST or connector.length < ROUND_DEPTH:
				continue
			var start: Vector3 = at * connector.position
			var way: Vector3 = at.basis * connector.axis
			var middle: Vector3 = start + way * (connector.length * 0.5)
			# A hole is filled by anything inside it, a thin handle off its
			# axis as much as a bar on it: the cells of a cube inside the
			# bore round its middle. A peg is inside what holds it at its
			# middle.
			var reach: float = 0.0 if connector.kind == "shaft" \
				else maxf(connector.radius - 1.0, 0.0) * 0.7
			var low: Vector3i = BrickLattice.to_cell(middle - Vector3.ONE * reach)
			var high: Vector3i = BrickLattice.to_cell(middle + Vector3.ONE * reach)
			var box := PackedInt32Array([low.x, low.y, low.z,
				high.x + 1, high.y + 1, high.z + 1])
			for found: Variant in filled.call(box, entry[0]):
				_add(held, entry[0], found)
				_add(held, found, entry[0])
			if connector.kind == "shaft":
				# And a peg in a hole the cover leaves open, as the cover of
				# 5059 leaves the hole the stump's peg goes into: the part
				# round the peg's middle on every side of it.
				for found: Variant in _round_about(middle, way.normalized(),
						connector.radius + 1.5, entry[0], filled):
					_add(held, entry[0], found)
					_add(held, found, entry[0])
				var row: Array = [entry[0], start, way.normalized(), connector.length]
				for bucket: Vector3i in _buckets_along([entry[0], start, way.normalized(),
						connector.length, 0.0]):
					if not posts.has(bucket):
						posts[bucket] = []
					(posts[bucket] as Array).append(row)
	_pivots(entries, held)
	if posts.is_empty():
		return held
	for entry: Array in entries:
		var origin: Vector3 = (entry[1] as Transform3D).origin
		for post: Array in posts.get(_bucket(origin), []):
			if post[0] == entry[0]:
				continue
			var gap: Vector3 = origin - (post[1] as Vector3)
			var along: float = gap.dot(post[2])
			if along < -ROUND_DEPTH or along > float(post[3]) + ROUND_DEPTH:
				continue
			if (gap - (post[2] as Vector3) * along).length() <= WORN_OFF_AXIS:
				_add(held, entry[0], post[0])
				_add(held, post[0], entry[0])
	return held


## The parts that are on every side of a peg, [param out] from its axis at
## [param middle]: six points round it, each a cell, all in one other part.
static func _round_about(middle: Vector3, way: Vector3, out: float, key: Variant,
		filled: Callable) -> Array:
	var across: Vector3 = way.cross(Vector3.UP if absf(way.y) < 0.9 else Vector3.RIGHT).normalized()
	var other: Vector3 = way.cross(across).normalized()
	var common: Dictionary = {}
	for n: int in 6:
		var turn: float = TAU * float(n) / 6.0
		var point: Vector3 = middle + (across * cos(turn) + other * sin(turn)) * out
		var cell: Vector3i = BrickLattice.to_cell(point)
		var here: Dictionary = {}
		for found: Variant in filled.call(PackedInt32Array([cell.x, cell.y, cell.z,
				cell.x + 1, cell.y + 1, cell.z + 1]), key):
			if n == 0 or common.has(found):
				here[found] = true
		common = here
		if common.is_empty():
			return []
	return common.keys()


## A visor turns on its helmet: the pins at its sides in the helmet's
## dimples, which LDraw draws as small primitives along X and which the
## connectors read only now and then (2447b and 3842b have none, 61190f's
## pins stop at the mouth of 61189's dimples). Where each part's are is
## read off those primitives ([constant MinifigData.PIVOTS],
## tools/minifig.py pivot_of), and two parts whose pivots are one point on
## one axis are joined there, as the figure builder puts them.
static func _pivots(entries: Array, held: Dictionary) -> void:
	var seen: Dictionary = {}   ## bucket -> Array of [key, point, axis]
	for entry: Array in entries:
		var part_id: String = str(entry[3]) if entry.size() > 3 else ""
		var pivot: Array = MinifigData.PIVOTS.get(Minifig._family(part_id),
			MinifigData.PIVOTS.get(part_id, []))
		if pivot.size() != 2:
			continue
		var at: Transform3D = entry[1]
		# [y, z] in the part's LDraw frame; the app's is turned half about X.
		var point: Vector3 = at * Vector3(0.0, -float(pivot[0]), -float(pivot[1]))
		var axis: Vector3 = at.basis.x.normalized()
		var box: Vector3i = _bucket(point)
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					for other: Array in seen.get(box + Vector3i(dx, dy, dz), []):
						if other[0] == entry[0]:
							continue
						if absf(axis.dot(other[2])) < 0.99:
							continue
						if point.distance_to(other[1]) > ROUND_OFF_AXIS:
							continue
						_add(held, entry[0], other[0])
						_add(held, other[0], entry[0])
		if not seen.has(box):
			seen[box] = []
		(seen[box] as Array).append([entry[0], point, axis])


## Which stud-sized box a point falls in.
static func _bucket(at: Vector3) -> Vector3i:
	return Vector3i(floori(at.x / BUCKET), floori(at.y / BUCKET),
		floori(at.z / BUCKET))
