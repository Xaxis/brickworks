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
## Half a cell: a bar a cell off a clip's axis is beside the clip, not in
## it, and its cover says so.
const ROUND_OFF_AXIS := 1.0
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
			if connector.kind != "shaft" and connector.kind != "bore":
				continue
			var start: Vector3 = at * connector.position
			var end: Vector3 = at * (connector.position + connector.axis * connector.length)
			var way: Vector3 = end - start
			var length: float = way.length()
			if length < 0.001:
				continue
			var row: Array = [entry[0], start, way / length, length, connector.radius]
			if connector.kind == "shaft":
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
	return held


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
	if absf(float(shaft[4]) - float(bore[4])) > ROUND_FIT:
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
static func overlap_within(mine: PackedInt32Array, theirs: PackedInt32Array,
		zones: Array, to_world: Transform3D, slack: float) -> bool:
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
							if not _in_a_zone(middle, zones, slack):
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


## Which stud-sized box a point falls in.
static func _bucket(at: Vector3) -> Vector3i:
	return Vector3i(floori(at.x / BUCKET), floori(at.y / BUCKET),
		floori(at.z / BUCKET))
