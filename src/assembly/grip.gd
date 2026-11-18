## The joint a part was picked up off the model by, which it goes on by
## (docs/APP_UX9.md, grabseat). StudWorx seats a part by the stud or hole it
## was grabbed by (11-13: "so a brick with studs on every side can go into a
## side hole by its top stud"). Here a part lifted off the model went on by
## whichever of its ends took the joint the pointer found, or by its foot on
## the studs, wherever it had been held: a SNOT brick picked up by its side
## stud went on by its foot, a beam picked up by its end hole went onto a pin
## by another hole.
##
## Which joint (the brief's first open question): the one nearest the
## pointer's line where it met the part as it was picked up, of those seen
## from there, measured to the joint itself (a stud's height, a hole's
## length, a pin's reach) as the hand aims at a joint (JointSnap.aimed_at).
## Between two joints it is the nearer to the line; a stud or a stud's hole
## facing away is not seen, so the top stud is never held from below, where
## the line meets the ceiling of the hollow over the hole that is meant; and
## a pin hole under a face is not seen through it (SURFACE).
## Further than NEAR from the line (between four studs, a brick's bare side)
## none is held, and the part goes on as one from the bin does. What else is
## at that joint, within SAME of the point on it nearest the line, is the same
## joint: a hollow stud is a stud that goes in a stud's hole and a clip a bar
## goes in; a Technic hole's mouth is a pin hole and a stud's hole.
##
## What it goes on (the brief's second): the joint of the part pointed at,
## nearest the pointer, that takes the one held, by that one alone: a stud
## into a stud's hole and a hole onto a stud, by the parts' exact labels, as
## the check joins them (Exact.meets); a pin, an axle, a hole, a bar, a clip,
## a ball or a socket by the hand's own joints (JointSnap). Where it has no
## room there it shows so, red, at the joint held: going on by another joint
## is what the person did not ask for. Where nothing there takes it at all (a
## side stud over a brick's top studs) the part goes on by what does, as one
## from the bin, so the hand never comes to a dead end.
class_name Grip
extends RefCounted

## How near the point pressed a joint has to be to be the one held, LDU: half
## a stud's pitch, so of two studs side by side the nearer is held, and a
## brick's bare side holds none.
const NEAR := 10.0
## What passes this near the point on the joint held is the same joint, LDU:
## under a stud's radius plus a little, and well under the 20 between two
## studs or two holes.
const SAME := 4.5
## How tall a stud is, and how deep a stud goes in a hole, LDU.
const STUD_TALL := 4.0
## A pin's or an axle's radius, LDU (a Technic pin is 12 across): what the
## pointer's line meets of it, where its end (JointSnap.End) has none.
const PIN := 6.0
## How far past where the line met the part a joint held may be, LDU: a
## brick's hollow, whose ceiling the line meets over the hole that is meant.
const DEEP := 24.0
## A stud or a stud's hole is seen from the line, so can be held, when it
## faces back along it more nearly than this (about 73 degrees off).
const SEEN := -0.3
## How far past where the line met the part a pin, an axle, a hole, a bar
## or a ball may be, LDU, past its own radius: at the part's face. A Technic
## brick's pin hole runs under its top face, 10 below, and a press on that
## face between its studs holds the stud nearer, not the hole hidden under it.
const SURFACE := 4.0
## How near the pointer a stud or a hole of the part pointed at has to be to
## be gone on, LDU: past the 14.1 from a stud grid's corner to its studs.
const REACH := 15.0

## The part held.
var part: String = ""
## Where it stood when it was picked up: what it is turned least from.
var was := Transform3D.IDENTITY
## Where the pointer met it, in its own frame.
var point := Vector3.ZERO
## The joint held, in the part's own frame: its studs and studs' holes by
## their index in its exact shape, and its JointSnap ends.
var studs := PackedInt32Array()
var ends: Array = []


## The joint of [param part_id], standing at [param where], that the
## pointer's line from [param from] going [param way] holds, having met the
## part [param struck] along it (BrickLattice.Hit.distance); null for none
## within NEAR.
static func picked(library: PartLibrary, part_id: String, where: Transform3D,
		from: Vector3, way: Vector3, struck: float) -> Grip:
	var into: Transform3D = where.affine_inverse()
	var start: Vector3 = into * from
	var along: Vector3 = (into.basis * way).normalized()
	var shape: Exact.Shape = Exact.shape_for(library, part_id)
	var joints: Array = joints_of(library, part_id)
	var nearest: Array = []
	var spot := Vector3.ZERO
	var best: float = INF
	for joint: Array in joints:
		if joint[0] is int and not _faces(shape, int(joint[0]), along):
			continue
		var met: Array = from_line(start, along, joint[1], joint[2])
		var deep: float = DEEP if joint[0] is int else float(joint[3]) + SURFACE
		if float(met[1]) > struck + deep:
			continue
		# A ball or a round is met anywhere within its radius of the line.
		var off: float = maxf(float(met[0]) - float(joint[3]), 0.0)
		if off < best - 0.001:
			best = off
			nearest = joint
			spot = met[2]
	if nearest.is_empty() or best > NEAR:
		return null
	var out := Grip.new()
	out.part = part_id
	out.was = where
	out.point = spot
	for joint: Array in joints:
		if _to_segment(spot, joint[1], joint[2]) > SAME:
			continue
		if joint[0] is JointSnap.End:
			out.ends.append(joint[0])
		elif _faces(shape, int(joint[0]), along):
			out.studs.append(int(joint[0]))
	return out


## Every joint of [param part_id] a part can be held by, in its own frame:
## [the stud or hole's index in its exact shape, or its JointSnap end, where
## it starts, where it ends, its radius]. Studs (plain and hollow) and the
## holes a stud goes in; not the tubes and posts a stud or a hollow stud goes
## in half a stud off, which a person asks for by Connect, not by a grip.
static func joints_of(library: PartLibrary, part_id: String) -> Array:
	var out: Array = []
	var shape: Exact.Shape = Exact.shape_for(library, part_id)
	for k: int in shape.connector_count() if shape != null else 0:
		if not is_stud_joint(shape, k):
			continue
		var frame: Transform3D = shape.frames[k]
		var way: Vector3 = (-frame.basis.y).normalized()
		out.append([k, frame.origin, frame.origin + way * STUD_TALL, 0.0])
	for end: JointSnap.End in JointSnap.ends_for(library, part_id):
		var run: Array = _run_of(end)
		out.append([end, run[0], run[1], PIN if end.is_male()
			else end.radius if end.is_ball() or end.is_wrap() or end.is_round() else 0.0])
	return out


## Whether connector [param k] of [param shape] is a stud or a stud's hole:
## a stud, a hollow stud or a hole, not a tube or a post.
static func is_stud_joint(shape: Exact.Shape, k: int) -> bool:
	if shape.kind[k] == Exact.STUD:
		return shape.sub[k] == Exact.S_STUD or shape.sub[k] == Exact.S_OPEN
	return shape.kind[k] == Exact.HOLE and shape.sub[k] == Exact.S_HOLE


## Whether connector [param k] of [param mine] goes on connector [param t] of
## [param theirs]: a stud in a hole, a hole on a stud (Exact.STUD_MATES).
static func takes(mine: Exact.Shape, k: int, theirs: Exact.Shape, t: int) -> bool:
	if not is_stud_joint(theirs, t):
		return false
	return (mine.kind[k] == Exact.STUD) != (theirs.kind[t] == Exact.STUD)


## Where a part goes to put its connector [param k] of [param mine] on
## [param target] (Exact.Item.connector: [index, where, way, basis], in the
## world): the two at one place and pointing one way, as Exact.meets joins
## them, turned as little as that takes from [param start] and then [param
## roll] quarter turns about the joint.
static func pose(mine: Exact.Shape, k: int, start: Basis, target: Array, roll: int) -> Transform3D:
	var frame: Transform3D = mine.frames[k]
	var way: Vector3 = (-frame.basis.y).normalized()
	var want: Vector3 = target[2]
	var turned: Basis = JointSnap._turned_onto(start, way, want)
	turned = JointSnap._tidy(Basis(want, roll * PI * 0.5) * turned)
	var origin: Vector3 = (target[1] as Vector3) - turned * frame.origin
	return Transform3D(turned, Vector3(snappedf(origin.x, 0.001), snappedf(origin.y, 0.001),
		snappedf(origin.z, 0.001)))


## Whether a stud or a hole of a part down, [param target] (as [method pose]
## takes it), is seen from the pointer's line [param way]: a stud pointing
## back along it, a hole opening back along it.
static func seen(target: Array, is_stud: bool, way: Vector3) -> bool:
	var open: Vector3 = (target[2] as Vector3) if is_stud else -(target[2] as Vector3)
	return open.dot(way) < SEEN


## Whether stud or hole [param k] of [param shape] faces back along [param
## along] (in the part's frame): a stud pointing at the line's start, a hole
## opening towards it.
static func _faces(shape: Exact.Shape, k: int, along: Vector3) -> bool:
	var way: Vector3 = (-shape.frames[k].basis.y).normalized()
	var open: Vector3 = way if shape.kind[k] == Exact.STUD else -way
	return open.dot(along) < SEEN


## The nearest a line from [param start] going [param along] (a unit) comes
## to the segment [param a] to [param b]: [how near, how far along the line,
## the point on the segment]. Along the line, the segment's end it meets
## first: a hole looked into from its mouth is at its mouth.
static func from_line(start: Vector3, along: Vector3, a: Vector3, b: Vector3) -> Array:
	var ab: Vector3 = b - a
	var length: float = ab.length_squared()
	var s: float = 0.0
	if length > 1e-9:
		# The segment's parameter where the two come nearest, clamped to it.
		var w0: Vector3 = a - start
		var bb: float = ab.dot(along)
		var denominator: float = length - bb * bb
		var d: float = ab.dot(w0)
		var e: float = along.dot(w0)
		if denominator > 1e-6 * length:
			s = clampf((bb * e - d) / denominator, 0.0, 1.0)
		else:
			s = 0.0 if bb >= 0.0 else 1.0
	var point: Vector3 = a + ab * s
	var t: float = (point - start).dot(along)
	return [point.distance_to(start + along * t), t, point]


## Where an end runs, [from, to], in the part's own frame: a pin or an axle
## out from its collar or tip as far as it reaches, a hole through its length,
## a bar or a clip along it, a hinge along its line, a ball or a socket at its
## middle, a round along its axis.
static func _run_of(end: JointSnap.End) -> Array:
	if end.is_ball():
		return [end.at, end.at]
	if end.is_male():
		return [end.at, end.at + end.axis * end.reach] if end.reach > 0.0 \
			else [end.at, end.at - end.axis * 5.0]
	if end.is_round():
		return [end.at, end.at + end.axis * end.reach]
	return [end.at - end.axis * end.reach, end.at + end.axis * end.reach]


static func _on_segment(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var length: float = ab.length_squared()
	if length < 1e-9:
		return a
	return a + ab * clampf((p - a).dot(ab) / length, 0.0, 1.0)


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	return p.distance_to(_on_segment(p, a, b))
