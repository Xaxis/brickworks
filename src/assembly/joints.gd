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


## Which stud-sized box a point falls in.
static func _bucket(at: Vector3) -> Vector3i:
	return Vector3i(floori(at.x / BUCKET), floori(at.y / BUCKET),
		floori(at.z / BUCKET))
