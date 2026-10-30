## Rubber bands round pulleys and springs between two ends (B10): two more
## of Flex's kinds, laid by the flex tool (FlexTool) as hoses and chains are.
##
## LDCad's path and spring system is the reference. A band there is a loop
## through circles, each wrapped one way or the other, its cross-section
## swept along the loop; a spring is a coil between two points, its windings
## fixed and their spacing whatever the length gives. LDraw itself has a
## band only as a circle (85543, a torus 18.75 LDU round) and a few shapes
## it was formed into (85543-f4, round two bushes), and a spring only at the
## length it is moulded. So a band laid here is the official band's own
## cross-section in pieces along its loop, as the flex system lays a tube
## (a scaled piece of band where the loop has turned four degrees), and a
## spring is a coil of the official spring's wire and diameter, its turns
## counted from the length it is laid at and stretched or squeezed with its
## ends after. Both pieces are parts of the app's making (CustomParts), whose
## LDraw text goes out in any file that uses them, so LDView, LDCad and
## Studio draw them as they are here. The item is still sold, and counted,
## as the official part: the band that fits, the spring or the shock.
##
## Pure but for [method piece_part], which puts a made piece in the library.
class_name Bands
extends RefCounted

## The official bands, each a torus: the radius of its centreline and the
## half width of its section, from its file (85543 is t02i1111 scaled 18.75:
## 18.75 x 0.1111 = 2.08 either way); a square one (u151) is 3 LDU along its
## axis and 2.875 across.
const BANDS: Dictionary = {
	"85543": {"radius": 18.75, "half": 2.083},
	"85545": {"radius": 32.5, "half": 2.031},
	"85546": {"radius": 41.25, "half": 1.906},
	"u151": {"radius": 18.6875, "half": 1.4375, "axial": 1.5},
}
## How far a band stretches, its loop over its own length: twice is what a
## LEGO® band takes in a model without wearing; more is said.
const STRETCH_MOST := 2.0

## The springs, each a coil: the radius of its wire's centreline, the
## wire's radius and the distance from one turn to the next, measured off
## its file (70038: wire 5.9 to 8.1 LDU from the axis, a turn every 7 LDU).
const SPRINGS: Dictionary = {
	"70038": {"coil": 6.9, "wire": 1.1, "pitch": 7.0},
	"41837": {"coil": 7.1, "wire": 0.75, "pitch": 8.1},
	"71953": {"coil": 7.1, "wire": 0.75, "pitch": 9.1},
	"22977": {"coil": 7.1, "wire": 0.75, "pitch": 4.7},
	"90026": {"coil": 7.0, "wire": 0.8, "pitch": 3.6},
	"90033": {"coil": 7.0, "wire": 0.8, "pitch": 5.5},
}
## The 6.5L shock absorbers, complete, and the spring each has: its
## cylinder (4255) on one end's pin, its piston rod (4254) on the other's,
## the spring between the cylinder's seat and the rod's collar, as 73129
## puts them (cylinder at 0, spring at 56, rod at 110).
const SHOCKS: Dictionary = {
	"73129": "70038", "41838": "41837", "76138": "71953", "76537": "22977",
	"89953": "90026", "89954": "90033",
}
const SHOCK_CYLINDER := "4255"
const SHOCK_ROD := "4254"
## Pin hole to pin hole, fully out and pushed in (LDCad's 10240-1 has one
## at 88.37), LDU.
const SHOCK_LONGEST := 110.0
const SHOCK_SHORTEST := 88.0
## The spring's seat on the cylinder from its pin hole, and the rod's collar
## from its own, LDU.
const SHOCK_SEAT := 56.0
const SHOCK_COLLAR := 10.0
## A shock beside a beam, their holes on one pin: half the shock's width
## and half the beam's, LDU.
const SHOCK_ASIDE := 20.0
## The colour a spring's coil is drawn in: LDraw's for spring steel.
const COIL_COLOUR := 494
## A shock's piston rod is black, as 73129 has it.
const ROD_COLOUR := 0

## The parts the app makes for these: a piece of a band, and a coil.
const SEGMENT_PREFIX := "bw-belt-"
const COIL_PREFIX := "bw-coil-"


## Whether [param part_id] is one of the pieces made here.
static func is_piece_id(part_id: String) -> bool:
	return part_id.begins_with(SEGMENT_PREFIX) or part_id.begins_with(COIL_PREFIX)


## The band a piece is of ("85543" for "bw-belt-85543"), or "".
static func band_of_piece(part_id: String) -> String:
	return part_id.trim_prefix(SEGMENT_PREFIX) if part_id.begins_with(SEGMENT_PREFIX) else ""


## The spring and its turns a coil is ["70038", 11] for "bw-coil-70038-11"),
## or [] for any other part.
static func coil_of_piece(part_id: String) -> Array:
	if not part_id.begins_with(COIL_PREFIX):
		return []
	var rest: String = part_id.trim_prefix(COIL_PREFIX)
	var at: int = rest.rfind("-")
	if at <= 0 or not rest.substr(at + 1).is_valid_int():
		return []
	return [rest.left(at), int(rest.substr(at + 1))]


# -- round things ---------------------------------------------------------------


## A thing a band goes round, in the world: a pulley, a wheel, a bush, an
## axle.
class Round extends RefCounted:
	var brick: int = 0
	## On its axis, where a band goes round it: in its groove, or for an
	## axle, wherever along it.
	var centre: Vector3
	## Unit, the way its axle runs.
	var axis: Vector3
	## Where a band's inside sits, LDU: the bottom of its groove.
	var radius: float = 0.0
	## How far either side of [member centre] along its axis a band may go
	## round it at the same radius: an axle's length; 0 for a groove.
	var reach: float = 0.0
	## Where along it a band goes, -1 to 1 of [member reach]: an axle's.
	var along: float = 0.0


## Each part's shape about its axle, worked out once: part -> {} for a part
## that is not round, else {"axis", "centre" (both its own), "radius",
## "reach"}. Read on the main thread only (the tool's clicks, a move's
## follow).
static var _shapes: Dictionary = {}


## The round thing [param brick] is, where it stands, or null: a part round
## about its axle (an axle hole's, a pin hole's, or an axle's own way). A
## band goes in its groove, the narrowest place round it between its ends;
## round an axle, as near [param near] along it as it reaches.
static func round_of(brick: BrickWorld.Brick, library: PartLibrary, near: Variant = null,
		at: Variant = null) -> Round:
	# A band's own piece, or a spring's, is no pulley.
	if brick == null or library == null or is_piece_id(brick.part_id):
		return null
	var shape: Dictionary = shape_of(library, brick.part_id)
	if shape.is_empty():
		return null
	var where: Transform3D = brick.transform if at == null else at
	var round := Round.new()
	round.brick = brick.id
	round.axis = (where.basis * (shape["axis"] as Vector3)).normalized()
	round.centre = where * (shape["centre"] as Vector3)
	round.radius = float(shape["radius"])
	round.reach = float(shape["reach"])
	if round.reach > 0.0 and near != null:
		var off: float = clampf(((near as Vector3) - round.centre).dot(round.axis), -round.reach,
			round.reach)
		round.centre += round.axis * off
		round.along = off / round.reach
	return round


## The shape of a part about its axle (see [member _shapes]).
static func shape_of(library: PartLibrary, part_id: String) -> Dictionary:
	if _shapes.has(part_id):
		return _shapes[part_id]
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	if mesh == null or mesh.surfaces.is_empty():
		return {}
	var shape: Dictionary = _measure(mesh)
	_shapes[part_id] = shape
	return shape


## How finely a part's profile along its axle is read, LDU.
const PROFILE_STEP := 0.5
## A part is round when, at its groove, its farthest point in each eighth of
## a turn is at least this much of the farthest in any.
const ROUND_ENOUGH := 0.8


static func _measure(mesh: Lbm.PartMesh) -> Dictionary:
	var axis := Vector3.ZERO
	var axle: bool = false
	for kind: String in ["axle_hole", "pin_hole", "axle", "pin"]:
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == kind:
				axis = connector.axis.normalized()
				axle = kind == "axle" or kind == "pin"
				break
		if axis != Vector3.ZERO:
			break
	if axis == Vector3.ZERO:
		var size: Vector3 = mesh.bounds.size
		axis = Vector3.RIGHT if size.x <= size.y and size.x <= size.z \
			else (Vector3.UP if size.y <= size.z else Vector3.BACK)
	# The middle of its box, on its axle: an off-centre hole's axle is
	# parallel to the middle one's, and the middle is where it turns.
	var centre: Vector3 = mesh.bounds.get_center()
	var across_u: Vector3 = (Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).cross(axis).normalized()
	var across_v: Vector3 = axis.cross(across_u)
	var low: float = INF
	var high: float = -INF
	var points: Array = []
	for surface: ArrayMesh in mesh.surfaces:
		for point: Vector3 in surface.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var gap: Vector3 = point - centre
			var along: float = gap.dot(axis)
			points.append(Vector3(along, gap.dot(across_u), gap.dot(across_v)))
			low = minf(low, along)
			high = maxf(high, along)
	if points.is_empty() or high - low < 0.5:
		return {}
	var bins: int = ceili((high - low) / PROFILE_STEP) + 1
	var farthest := PackedFloat32Array()
	farthest.resize(bins)
	# Each bin's farthest in each eighth of a turn, bin by bin: one array, a
	# packed array in an Array being a copy each time it is read.
	var sectors := PackedFloat32Array()
	sectors.resize(bins * 8)
	var outer: float = 0.0
	for point: Vector3 in points:
		var n: int = clampi(roundi((point.x - low) / PROFILE_STEP), 0, bins - 1)
		var r: float = Vector2(point.y, point.z).length()
		farthest[n] = maxf(farthest[n], r)
		var sector: int = posmod(floori((atan2(point.z, point.y) + PI / 8.0) / (PI / 4.0)), 8)
		sectors[n * 8 + sector] = maxf(sectors[n * 8 + sector], r)
		outer = maxf(outer, r)
	if outer < 1.0:
		return {}
	var length: float = high - low
	# An axle, or a pin: long beside how thick it is, a band goes round it
	# anywhere along it.
	if axle and length > outer * 5.0:
		return {"axis": axis, "centre": centre + axis * (low + high) * 0.5, "radius": outer,
			"reach": length * 0.5 - 2.0}
	# Its groove: the narrowest place between its ends, where it is no
	# narrower than half as wide as it is (a place where only its hub has
	# corners is no groove); the middle of it where it runs flat.
	var least: float = INF
	var first: int = -1
	var last: int = -1
	var margin: int = maxi(roundi(1.0 / PROFILE_STEP), 1)
	for n: int in range(margin, bins - margin):
		if farthest[n] < outer * 0.5:
			continue
		if farthest[n] < least - 0.2:
			least = farthest[n]
			first = n
			last = n
		elif farthest[n] <= least + 0.2:
			last = n
	if first < 0:
		# Too thin to have a middle: its one widest place.
		least = outer
		first = 0
		last = bins - 1
	var groove: float = low + (float(first + last) * 0.5) * PROFILE_STEP
	# Round there: its farthest corner in every eighth of a turn about as far.
	var widest: float = 0.0
	var narrowest: float = INF
	for n: int in range(maxi(first - margin, 0), mini(last + margin, bins - 1) + 1):
		for k: int in 8:
			widest = maxf(widest, sectors[n * 8 + k])
	for k: int in 8:
		var best: float = 0.0
		for n: int in range(maxi(first - margin * 2, 0), mini(last + margin * 2, bins - 1) + 1):
			best = maxf(best, sectors[n * 8 + k])
		narrowest = minf(narrowest, best)
	if widest <= 0.0 or narrowest < widest * ROUND_ENOUGH:
		return {}
	return {"axis": axis, "centre": centre + axis * groove, "radius": least, "reach": 0.0}


# -- a band's loop ----------------------------------------------------------------


## The loop a band makes round [param rounds], in the order they were
## picked, its centreline [param half] LDU out from each one's groove: the
## arc round each and the straight runs between them, tangent to both. Each
## is wrapped the way the order turns at it: round its outside where the
## loop turns the same way as the whole loop does, round its inside where it
## turns back (an idler pressed into a belt). All on one plane, their axles
## one way. Returns {"path" (a closed Flex.Path), "length" (the loop's exact
## length, its arcs as arcs), "axis", "order" (the rounds in the order it
## goes round), "sides" (+1 round the outside, -1 the inside), "touches"
## (each one's arc: [from, to] along the path)}; or {"why"}.
static func loop(rounds: Array, half: float) -> Dictionary:
	if rounds.size() < 2:
		return {"why": "a band goes round two things or more"}
	var first: Round = rounds[0]
	for one: Round in rounds:
		if one.reach == 0.0:
			first = one
			break
	var axis: Vector3 = first.axis
	var centres := PackedVector3Array()
	for one: Round in rounds:
		if absf(one.axis.dot(axis)) < 0.995:
			return {"why": "their axles are not all one way"}
		var centre: Vector3 = one.centre
		var off: float = (centre - first.centre).dot(axis)
		if one.reach > 0.0:
			# Along an axle to the band's plane, as far as the axle goes.
			var moved: float = clampf(-off, -one.reach * (1.0 + one.along),
				one.reach * (1.0 - one.along))
			centre += axis * moved
			off += moved
		if absf(off) > 2.0:
			return {"why": "they are not in one plane: one is %.0f LDU out of it" % absf(off)}
		centres.append(centre - axis * off)
	# The plane's two ways, turning about the axle.
	var u: Vector3 = Vector3.UP - axis * axis.dot(Vector3.UP)
	if u.length_squared() < 0.01:
		u = Vector3.RIGHT - axis * axis.x
	u = u.normalized()
	var v: Vector3 = axis.cross(u)
	var origin: Vector3 = first.centre
	var flat := PackedVector2Array()
	for centre: Vector3 in centres:
		flat.append(Vector2((centre - origin).dot(u), (centre - origin).dot(v)))
	var order: Array = rounds.duplicate()
	var count: int = order.size()
	# Anticlockwise about the axle: picked the other way round, the same
	# loop read backwards.
	var area: float = 0.0
	for n: int in count:
		area += flat[n].cross(flat[(n + 1) % count])
	if area < 0.0:
		order.reverse()
		flat.reverse()
	var sides := PackedInt32Array()
	for n: int in count:
		if count < 3:
			sides.append(1)
			continue
		var turn: float = (flat[n] - flat[(n - 1 + count) % count]).cross(flat[(n + 1) % count] - flat[n])
		sides.append(1 if turn >= 0.0 else -1)
	# Each run's outward normal: the band leaves one at its centre plus the
	# normal times its signed radius, and meets the next the same way.
	var normals := PackedVector2Array()
	for n: int in count:
		var a: Round = order[n]
		var b: Round = order[(n + 1) % count]
		var gap: Vector2 = flat[(n + 1) % count] - flat[n]
		var reach: float = gap.length()
		var ra: float = float(sides[n]) * (a.radius + half)
		var rb: float = float(sides[(n + 1) % count]) * (b.radius + half)
		if reach < absf(ra - rb) + 0.01 or (sides[n] != sides[(n + 1) % count]
				and reach < absf(ra) + absf(rb) + 0.01):
			return {"why": "two of them are too close for a band between them"}
		var theta: float = gap.angle() - acos(clampf((ra - rb) / reach, -1.0, 1.0))
		normals.append(Vector2(cos(theta), sin(theta)))
	var lift := func(point: Vector2) -> Vector3:
		return origin + u * point.x + v * point.y
	var path := Flex.Path.new()
	path.closed = true
	var length: float = 0.0
	var touches: Array = []
	var run_from: float = 0.0
	for n: int in count:
		var here: Round = order[n]
		var side: float = float(sides[n])
		var r: float = here.radius + half
		var came: Vector2 = normals[(n - 1 + count) % count] * side
		var leaves: Vector2 = normals[n] * side
		var start: float = came.angle()
		var sweep: float = fposmod(leaves.angle() - start, TAU) if side > 0.0 \
			else -fposmod(start - leaves.angle(), TAU)
		var steps: int = maxi(ceili(absf(sweep) * r / 0.5), 1)
		var arc_from: float = run_from
		for step: int in steps:
			var angle: float = start + sweep * float(step) / float(steps)
			path.points.append(lift.call(flat[n] + Vector2(cos(angle), sin(angle)) * r))
		length += absf(sweep) * r
		touches.append([arc_from, arc_from + absf(sweep) * r])
		# The straight run to the next, a point every 4 LDU, so no piece of
		# it is longer than the flex system lays one.
		var from2: Vector2 = flat[n] + leaves * r
		var next: int = (n + 1) % count
		var to2: Vector2 = flat[next] + normals[n] * float(sides[next]) * ((order[next] as Round).radius + half)
		var run: float = from2.distance_to(to2)
		var run_steps: int = maxi(ceili(run / 4.0), 1)
		for step: int in run_steps:
			path.points.append(lift.call(from2.lerp(to2, float(step) / float(run_steps))))
		length += run
		run_from = arc_from + absf(sweep) * r + run
	path.points.append(path.points[0])
	path.measure()
	return {"path": path, "length": length, "axis": axis, "order": order, "sides": sides,
		"touches": touches}


## A band, [param band] (85543 ...), laid round [param rounds] in the
## order picked, as pieces of [param segment] (its made piece, [method
## piece_part]). Warned when the loop is shorter than the band (it would
## hang slack) or stretches it more than [constant STRETCH_MOST].
static func lay_band(band: String, rounds: Array, segment: String) -> Flex.Laid:
	var laid := Flex.Laid.new()
	var spec: Dictionary = BANDS.get(band, {})
	if spec.is_empty():
		laid.warnings.append("%s is no band" % band)
		return laid
	var made: Dictionary = loop(rounds, float(spec["half"]))
	if made.has("why"):
		laid.warnings.append(str(made["why"]))
		return laid
	var path: Flex.Path = made["path"]
	laid.path = path
	laid.length = float(made["length"])
	laid.wanted = natural_length(band)
	laid.links = rounds.size()
	laid.tightest = INF
	for one: Round in rounds:
		laid.tightest = minf(laid.tightest, one.radius + float(spec["half"]))
	laid.slack = laid.wanted - laid.length
	var stretch: float = laid.length / laid.wanted
	if laid.length < laid.wanted - 0.5:
		laid.warnings.append("this band is %.0f LDU round and the loop %.0f: it would hang slack"
			% [laid.wanted, laid.length])
	elif stretch > STRETCH_MOST:
		laid.warnings.append("it is stretched %.1f times its length; a band takes about twice"
			% stretch)
	laid.notes.append("round %d, %.0f LDU, stretched %.2f times" % [rounds.size(), laid.length,
		stretch])
	laid.pieces = pieces_along(path, segment, made["axis"])
	return laid


## How long a band is round its centreline, unstretched, LDU.
static func natural_length(band: String) -> float:
	return TAU * float((BANDS.get(band, {"radius": 0.0}) as Dictionary)["radius"])


## The band that fits a loop [param length] long, of the round ones (or the
## square one, with [param square]): the longest no longer than the loop,
## so it holds with the least stretch; the shortest if every one is longer.
static func band_for(length: float, square: bool = false) -> String:
	var best: String = ""
	var shortest: String = ""
	for band: String in BANDS:
		if (BANDS[band] as Dictionary).has("axial") != square:
			continue
		var own: float = natural_length(band)
		if shortest.is_empty() or own < natural_length(shortest):
			shortest = band
		if own <= length + 0.5 and (best.is_empty() or own > natural_length(best)):
			best = band
	return best if not best.is_empty() else shortest


## A closed path laid as pieces of [param part], each one LDU of it
## stretched from one cut to the next: cut where the way it runs has turned
## Flex.PIECE_TURN since the last cut. Each piece's own x is [param axis],
## so a square band's section lies square to its pulleys.
static func pieces_along(path: Flex.Path, part: String, axis: Vector3) -> Array:
	var out: Array = []
	var cuts := PackedInt32Array([0])
	var started: int = 0
	var limit: float = cos(deg_to_rad(Flex.PIECE_TURN))
	var last: int = path.points.size() - 1
	for n: int in range(1, last):
		var began: Vector3 = (path.points[started + 1] - path.points[started]).normalized()
		var now: Vector3 = (path.points[n + 1] - path.points[n]).normalized()
		if now.dot(began) < limit or path.along[n] - path.along[started] > Flex.PIECE_LONGEST:
			cuts.append(n)
			started = n
	cuts.append(last)
	for n: int in range(1, cuts.size()):
		var a: Vector3 = path.points[cuts[n - 1]]
		var b: Vector3 = path.points[cuts[n]]
		var span: float = a.distance_to(b)
		if span < 0.01:
			continue
		# A piece runs from its origin along its own -y.
		var basis: Basis = Flex.basis_along((b - a) / span, axis, "-y")
		basis.y *= span
		out.append({"part": part, "at": Transform3D(basis, a)})
	return out


# -- a spring between two ends -----------------------------------------------------


## The spring a part picked from the bin lays: the spring itself, or a
## shock absorber's. "" for any other part.
static func spring_of(part_id: String) -> String:
	if SPRINGS.has(part_id):
		return part_id
	return str(SHOCKS.get(part_id, ""))


## How many turns a spring laid [param length] long has: as many as its
## own pitch gives, two at least.
static func turns_for(spring: String, length: float) -> int:
	var spec: Dictionary = SPRINGS.get(spring, {"pitch": 7.0})
	return maxi(roundi(length / float(spec["pitch"])), 2)


## How long a coil of [param turns] is unloaded: its turns at its pitch.
static func coil_length(spring: String, turns: int) -> float:
	return float(turns) * float((SPRINGS.get(spring, {"pitch": 7.0}) as Dictionary)["pitch"])


## The shortest a coil of [param turns] goes, its turns touching, LDU.
static func solid_length(spring: String, turns: int) -> float:
	return float(turns) * float((SPRINGS.get(spring, {"wire": 1.0}) as Dictionary)["wire"]) * 2.0 \
		+ float((SPRINGS.get(spring, {"wire": 1.0}) as Dictionary)["wire"]) * 2.0


## A spring from [param a] to [param b]: [param part] a spring (70038 ...)
## laid as a coil of [param coil] (its made piece) from one to the other, or
## a 6.5L shock absorber (73129 ...) laid as its cylinder on [param a], its
## rod on [param b] and its spring's coil between them. [param across] is
## the way the shock's pin holes run (its ends' holes'). The coil's turns are
## [param turns]: what it was made with; it is stretched or squeezed to fit.
static func lay_spring(part: String, a: Vector3, b: Vector3, across: Vector3, coil: String,
		turns: int) -> Flex.Laid:
	var laid := Flex.Laid.new()
	var spring: String = spring_of(part)
	var gap: float = a.distance_to(b)
	if spring.is_empty() or gap < 1.0:
		laid.warnings.append("its two ends are in one place" if gap < 1.0 else "%s is no spring" % part)
		return laid
	var way: Vector3 = (b - a) / gap
	var normal: Vector3 = across.cross(way)
	if normal.length_squared() < 1e-6:
		normal = (Vector3.UP if absf(way.y) < 0.9 else Vector3.RIGHT).cross(way)
	normal = normal.normalized()
	var turned: Basis = Flex.basis_along(way, normal, "-y")
	var from: Vector3 = a
	var length: float = gap
	if SHOCKS.has(part):
		laid.pieces.append({"part": SHOCK_CYLINDER, "at": Transform3D(turned, a), "role": "cylinder"})
		laid.pieces.append({"part": SHOCK_ROD, "at": Transform3D(turned, b), "role": "rod",
			"color": ROD_COLOUR})
		from = a + way * SHOCK_SEAT
		length = gap - SHOCK_SEAT - SHOCK_COLLAR
		if gap > SHOCK_LONGEST + 0.5:
			laid.warnings.append("its ends are %.0f LDU apart and it reaches %.0f at most" % [gap,
				SHOCK_LONGEST])
		elif gap < SHOCK_SHORTEST - 0.5:
			laid.warnings.append("its ends are %.0f LDU apart and it goes in to %.0f at least" % [gap,
				SHOCK_SHORTEST])
	var rest: float = coil_length(spring, turns)
	if length < solid_length(spring, turns) - 0.5:
		laid.warnings.append("squeezed to %.0f LDU, its %d turns would be pressed solid" % [length, turns])
	var squeezed: Basis = turned
	squeezed.y *= maxf(length, 0.1) / rest
	laid.pieces.insert(1 if SHOCKS.has(part) else 0, {"part": coil, "at": Transform3D(squeezed, from),
		"role": "coil", "color": COIL_COLOUR})
	laid.path = Flex.Path.new()
	laid.path.points = PackedVector3Array([a, b])
	laid.path.measure()
	laid.length = gap
	laid.wanted = rest
	laid.links = turns
	laid.notes.append("%d turns over %.0f LDU, %.1f LDU apart" % [turns, length, length / float(turns)])
	return laid


## A laid spring's ends and turns read off its pieces: {"a", "b", "across",
## "part" (the spring, or the shock), "turns", "spring"}, or {} when they
## are not one.
static func spring_read(pieces: Array) -> Dictionary:
	var coil: Dictionary = {}
	var cylinder: Dictionary = {}
	var rod: Dictionary = {}
	for piece: Dictionary in pieces:
		var part: String = str(piece["part"])
		if part.begins_with(COIL_PREFIX):
			coil = piece
		elif part == SHOCK_CYLINDER:
			cylinder = piece
		elif part == SHOCK_ROD:
			rod = piece
	if coil.is_empty():
		return {}
	var named: Array = coil_of_piece(str(coil["part"]))
	if named.is_empty():
		return {}
	var spring: String = str(named[0])
	var turns: int = int(named[1])
	var at: Transform3D = coil["at"]
	var down: Vector3 = -at.basis.y
	var a: Vector3 = at.origin
	var b: Vector3 = at.origin + down * coil_length(spring, turns)
	var across: Vector3 = at.basis.z.normalized()
	var part: String = spring
	if not cylinder.is_empty() and not rod.is_empty():
		a = (cylinder["at"] as Transform3D).origin
		b = (rod["at"] as Transform3D).origin
		across = (cylinder["at"] as Transform3D).basis.z.normalized()
		for shock: String in SHOCKS:
			if str(SHOCKS[shock]) == spring:
				part = shock
				break
	return {"a": a, "b": b, "across": across, "part": part, "turns": turns, "spring": spring}


# -- the made pieces ------------------------------------------------------------------


## The made piece for [param id] (a band's segment, a coil) in the library,
## made now if it is not there. False when it could not be made.
static func piece_part(library: PartLibrary, id: String) -> bool:
	if library.parts.has(id) and library.mesh_for(id) != null:
		return true
	var text: String = piece_text(id)
	if text.is_empty():
		return false
	var made: Dictionary = CustomParts.add(library, text, id, false)
	return str(made["problem"]).is_empty()


## The LDraw text of a made piece, or "" for an id that is none: drawn as
## polygons alone, so it reads with nothing but itself. LDraw's axes: its
## length runs down its +y from its origin.
static func piece_text(id: String) -> String:
	var lines := PackedStringArray()
	var band: String = band_of_piece(id)
	var coil: Array = coil_of_piece(id)
	if BANDS.has(band):
		var spec: Dictionary = BANDS[band]
		lines.append("0 ~Rubber Belt %s Segment" % band)
		lines.append("0 Name: %s.dat" % id)
		lines.append("0 Author: Brickworks")
		lines.append("0 !LDRAW_ORG Unofficial_Part")
		lines.append("0 !CATEGORY Technic")
		lines.append("0 // One LDU of %s's band, stretched piece by piece along the loop it is laid in."
			% band)
		var half: float = float(spec["half"])
		if spec.has("axial"):
			# Square: across its pulleys' axle (x) and out from them (z).
			var x: float = float(spec["axial"])
			var corners: Array = [Vector2(x, half), Vector2(-x, half), Vector2(-x, -half), Vector2(x, -half)]
			for n: int in 4:
				lines.append(_quad(corners[n], corners[(n + 1) % 4]))
		else:
			for n: int in 12:
				var a: float = TAU * float(n) / 12.0
				var b: float = TAU * float(n + 1) / 12.0
				lines.append(_quad(Vector2(cos(a), sin(a)) * half, Vector2(cos(b), sin(b)) * half))
	elif coil.size() == 2 and SPRINGS.has(str(coil[0])):
		var spring: String = coil[0]
		var turns: int = coil[1]
		var spec: Dictionary = SPRINGS[spring]
		lines.append("0 ~Spring %s Coil with %d Turns" % [spring, turns])
		lines.append("0 Name: %s.dat" % id)
		lines.append("0 Author: Brickworks")
		lines.append("0 !LDRAW_ORG Unofficial_Part")
		lines.append("0 !CATEGORY Technic")
		lines.append("0 // %s's coil, %d turns at its own pitch, squeezed or stretched with its ends."
			% [spring, turns])
		lines.append_array(_coil(float(spec["coil"]), float(spec["wire"]),
			float(spec["pitch"]), turns))
	else:
		return ""
	return "\n".join(lines) + "\n"


## A quad of a piece of band one LDU long, between two corners of its
## section (x across, z out).
static func _quad(one: Vector2, two: Vector2) -> String:
	return "4 16 %s 0 %s %s 1 %s %s 1 %s %s 0 %s" % [_n(one.x), _n(one.y), _n(one.x), _n(one.y),
		_n(two.x), _n(two.y), _n(two.x), _n(two.y)]


## A coil's polygons: its wire swept round a helix of [param radius] down
## [param pitch] a turn, 12 steps a turn and six sides to the wire.
static func _coil(radius: float, wire: float, pitch: float, turns: int) -> PackedStringArray:
	var out := PackedStringArray()
	var steps: int = turns * 12
	var rings: Array = []
	for k: int in steps + 1:
		var t: float = TAU * float(k) / 12.0
		var middle := Vector3(radius * cos(t), pitch * float(k) / 12.0, radius * sin(t))
		var tangent := Vector3(-radius * sin(t), pitch / TAU, radius * cos(t)).normalized()
		var inward := Vector3(-cos(t), 0.0, -sin(t))
		var side: Vector3 = tangent.cross(inward).normalized()
		var ring := PackedVector3Array()
		for w: int in 6:
			var phi: float = TAU * float(w) / 6.0
			ring.append(middle + (inward * cos(phi) + side * sin(phi)) * wire)
		rings.append(ring)
	for k: int in steps:
		var a: PackedVector3Array = rings[k]
		var b: PackedVector3Array = rings[k + 1]
		for w: int in 6:
			var w2: int = (w + 1) % 6
			out.append("4 16 %s %s %s %s" % [_v(a[w]), _v(b[w]), _v(b[w2]), _v(a[w2])])
	return out


static func _v(point: Vector3) -> String:
	return "%s %s %s" % [_n(point.x), _n(point.y), _n(point.z)]


static func _n(value: float) -> String:
	var said: String = String.num(value, 3)
	return "0" if said == "-0" else said
