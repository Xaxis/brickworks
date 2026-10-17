## A model whose centre of mass is past the edge of what it stands on falls
## over: turned about that edge until something else of it reaches the floor,
## and again about the next edge while it still does not stand. Where it
## comes to rest is [method fall]'s, found from the parts' covers; how it gets
## there is [method timed]'s: a rigid body turning about the edge under
## gravity from rest, θ'' = τ(θ)/I, its moment of inertia about the edge from
## the parts (Swing.lump), stopping dead where it lands (no bounce: how much a
## model of bricks bounces is not measured). The edge is taken not to slip,
## and each further fall starts from rest. Its time is as good as the masses
## and the moment of inertia (docs/MECHANISMS.md §14), a few per cent.
##
## Each fall is a turn about a line on the floor: the support's edge the
## centre of mass is past (Balance.margin_in). A point of the model a
## distance u out past that edge and h above the floor comes down to it when
## the model has turned atan2(h, u); the least of those over every corner of
## every part's cover is where the next thing touches. The model is one rigid
## thing as it falls: what stands on it is carried, and nothing comes apart.
class_name Topple
extends RefCounted

## At most this many falls, one edge after another.
const MOST := 4
## A point this near the floor rests on it, LDU.
const ON_FLOOR := 1.0
## Parts with more cover boxes than this give their box's corners instead.
const MOST_BOXES := 24


## Every corner of every part's cover where [param placed] (brick id ->
## Transform3D) puts it, else where it stands; not [param floor_ids].
static func corners_of(world: BrickWorld, library: PartLibrary, placed: Dictionary,
		floor_ids: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	for brick: BrickWorld.Brick in world.bricks():
		if floor_ids.has(brick.id):
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var at: Transform3D = placed.get(brick.id, brick.transform)
		if mesh.boxes.is_empty() or mesh.boxes.size() > MOST_BOXES:
			for corner: int in 8:
				out.append(at * mesh.bounds.get_endpoint(corner))
			continue
		for box: AABB in mesh.boxes:
			var cells := AABB(box.position * mesh.cell_ldu, box.size * mesh.cell_ldu)
			for corner: int in 8:
				out.append(at * cells.get_endpoint(corner))
	return out


## How [param points] (the model's cover) with its centre of mass at
## [param centre] falls on a floor at [param floor_y]: {"turn": Transform3D
## from where it stands to where it rests, "falls": [[edge name, degrees]],
## "rests": bool, "words": String}; "falls" empty when it stands.
static func fall(points: PackedVector3Array, centre: Vector3, floor_y: float) -> Dictionary:
	var turn := Transform3D.IDENTITY
	var falls: Array = []
	var steps: Array = []   ## [point on the line, its way, radians]
	var rests: bool = false
	for _n: int in MOST:
		var support := PackedVector2Array()
		var lowest: float = INF
		for p: Vector3 in points:
			lowest = minf(lowest, (turn * p).y)
		for p: Vector3 in points:
			var q: Vector3 = turn * p
			if q.y <= lowest + ON_FLOOR:
				support.append(Vector2(q.x, q.z))
		var hull: PackedVector2Array = Geometry2D.convex_hull(support)
		if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
			hull.resize(hull.size() - 1)
		var c: Vector3 = turn * centre
		var flat := Vector2(c.x, c.z)
		var standing: Dictionary
		if hull.size() >= 3:
			standing = Balance.margin_in(hull, flat)
		else:
			standing = Topple._past_line(hull, flat)
		if float(standing["margin"]) >= 0.0:
			rests = true
			break
		var ends: PackedVector2Array = standing["ends"]
		var way2: Vector2 = standing["way"]
		var out := Vector3(way2.x, 0.0, way2.y).normalized()
		var a := Vector3(ends[0].x, lowest, ends[0].y)
		var b := Vector3(ends[1].x, lowest, ends[1].y) if ends.size() > 1 else a + out.cross(Vector3.UP)
		var line: Vector3 = (b - a).normalized()
		if line.length() < 0.5:
			line = out.cross(Vector3.UP).normalized()
		# Turning by +φ about the line must carry what is above the edge out
		# past it and down.
		if line.cross(Vector3.UP).dot(out) < 0.0:
			line = -line
		var least: float = PI
		for p: Vector3 in points:
			var q: Vector3 = turn * p - a
			var u: float = q.dot(out)
			var h: float = q.y
			if h <= ON_FLOOR and absf(u) <= ON_FLOOR * 2.0:
				continue
			var phi: float = atan2(h, u)
			if phi > 0.0001 and phi < least:
				least = phi
		var about := Transform3D(Basis.IDENTITY, a) * Transform3D(Basis(line, least), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -a)
		turn = about * turn
		falls.append([Balance.edge_name(way2), rad_to_deg(least)])
		steps.append([a, line, least])
	var said: String = ""
	if not falls.is_empty():
		said = Topple.words(falls, turn, rests)
	return {"turn": turn, "falls": falls, "steps": steps, "rests": rests, "words": said}


## The time step of [method timed], s.
const STEP := 0.001


## [param steps] (fall's) in time: each a turn about its edge from rest under
## gravity, the model a rigid body of [param lumped] (Swing.lump where it
## stands: grams, centre, inertia). {"seconds": the whole fall, "falls": [{
## "seconds", "table": the turn every STEP, radians}], "speed": the last
## fall's turning rate as it lands, rad/s, "line" and "point": its edge}.
static func timed(steps: Array, lumped: Dictionary) -> Dictionary:
	var grams: float = float(lumped["grams"])
	var centre: Vector3 = lumped["centre"]
	var inertia: Basis = lumped["inertia"]
	var turn := Transform3D.IDENTITY
	var falls: Array = []
	var total: float = 0.0
	var speed: float = 0.0
	var line := Vector3.ZERO
	var point := Vector3.ZERO
	var weight := Vector3(0.0, -grams * Swing.GRAVITY, 0.0)
	for step: Array in steps:
		point = step[0]
		line = (step[1] as Vector3).normalized()
		var angle: float = step[2]
		var lever: Vector3 = turn * centre - point
		lever -= line * lever.dot(line)
		var spun: Basis = turn.basis * inertia * turn.basis.transposed()
		var about_edge: float = line.dot(spun * line) + grams * lever.length_squared()
		var theta: float = 0.0
		var omega: float = 0.0
		var seconds: float = 0.0
		var table := PackedFloat32Array([0.0])
		while theta < angle:
			var torque: float = line.dot((Basis(line, theta) * lever).cross(weight))
			omega += STEP * maxf(torque, 0.0) / maxf(about_edge, 1e-9)
			if omega <= 0.0:
				# Balanced on the edge: it would stand there; nudged on.
				omega = 0.01
			theta = minf(theta + STEP * omega, angle)
			seconds += STEP
			table.append(theta)
			if seconds > 20.0:
				theta = angle
				table.append(theta)
		falls.append({"seconds": seconds, "table": table})
		total += seconds
		speed = omega
		turn = Transform3D(Basis.IDENTITY, point) * Transform3D(Basis(line, angle), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -point) * turn
	return {"seconds": total, "falls": falls, "speed": speed, "line": line, "point": point}


## The turn [param seconds] into [param steps] timed as [param timing]
## ([method timed]).
static func turn_at(steps: Array, timing: Dictionary, seconds: float) -> Transform3D:
	var out := Transform3D.IDENTITY
	var left: float = seconds
	var falls: Array = timing["falls"]
	for n: int in steps.size():
		var step: Array = steps[n]
		var fall: Dictionary = falls[n]
		var table: PackedFloat32Array = fall["table"]
		var angle: float = float(step[2])
		if left < float(fall["seconds"]):
			angle = table[clampi(int(left / STEP), 0, table.size() - 1)]
		var a: Vector3 = step[0]
		out = Transform3D(Basis.IDENTITY, a) * Transform3D(Basis(step[1], angle), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -a) * out
		left -= float(fall["seconds"])
		if left <= 0.0:
			break
	return out


## A support of one point or a line: how far the centre is past it.
static func _past_line(hull: PackedVector2Array, flat: Vector2) -> Dictionary:
	if hull.is_empty():
		return {"margin": 0.0, "ends": PackedVector2Array(), "way": Vector2.RIGHT}
	var a: Vector2 = hull[0]
	var b: Vector2 = hull[hull.size() - 1]
	var on: Vector2 = Geometry2D.get_closest_point_to_segment(flat, a, b)
	var away: Vector2 = flat - on
	if away.length() < 0.01:
		return {"margin": 0.0, "ends": PackedVector2Array([a, b]), "way": Vector2.RIGHT}
	return {"margin": -away.length(), "ends": PackedVector2Array([a, b]), "way": away.normalized()}


## "tipped over to the left and lies on its side".
static func words(falls: Array, turn: Transform3D, rests: bool) -> String:
	var first: String = str(falls[0][0])
	var up: Vector3 = turn.basis * Vector3.UP
	var lies: String
	var leaning: float = rad_to_deg(acos(clampf(up.y, -1.0, 1.0)))
	if leaning < 15.0:
		lies = "comes to rest still upright"
	elif leaning < 60.0:
		lies = "rests leaning %d°, its far end on the floor" % roundi(leaning)
	elif up.y < -0.7:
		lies = "lies upside down"
	elif first.contains("front"):
		lies = "lies on its front"
	elif first.contains("back"):
		lies = "lies on its back"
	else:
		lies = "lies on its side"
	var out: String = "tipped over to the %s and %s" % [first, lies]
	if falls.size() > 1:
		out += " (it fell %d times, %s)" % [falls.size(), ", ".join(falls.map(
			func(one: Array) -> String: return "%d° to the %s" % [roundi(float(one[1])), one[0]]))]
	if not rests:
		out += "; it does not come to rest within %d falls" % MOST
	return out
