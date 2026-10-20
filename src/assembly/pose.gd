## Posing: each sub-assembly that hangs from a hinge, a clip or a turntable
## turned about that real joint, by an angle a slider sets.
##
## J swings a selection a step at a time about the joint it hangs from
## (Builder.swing_selection); this holds every such joint in the model at
## once, each with an angle from where it stood when the pose began (its
## rest), so a crane's arm can be raised and its hook swung on the end of
## it, set back to rest, or put through an animation (PoseAnimation) with
## the model itself never touched in between.
##
## A joint is found as J finds one: a sub-assembly's parts with a shaft of
## one part in a bore of another outside it (Joints.rounds). One inside
## another turns with it: the inner is turned about its rest axis first and
## the outer then carries both, so a hook on an arm stays on the arm.
class_name Poser
extends RefCounted

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var assemblies: Assemblies


## One joint a sub-assembly turns about.
class Joint extends RefCounted:
	var path: String = ""
	## Through the joint, at rest, and the way its pin runs.
	var point: Vector3
	var axis: Vector3
	## The parts on the other side it may press against as it turns.
	var partners: Dictionary = {}
	## Everything that turns with it: the sub-assembly and all inside it.
	var ids: PackedInt64Array = PackedInt64Array()
	var depth: int = 0
	## Degrees from rest.
	var angle: float = 0.0

	## "turntable" about the upright, "hinge" otherwise.
	func kind() -> String:
		return "turntable" if absf(axis.y) > 0.9 else "hinge"


var joints: Array[Joint] = []
## Where every part that turns stood at rest: brick id -> Transform3D.
var rest: Dictionary = {}
## The lattice's cells of each of them there: brick id -> its boxes. What a
## part overlapped at rest is not in its way: the cells are 2 LDU, coarser
## than a hinge's fit, and 31070-1's back window swung up and let go at 0
## stopped 6 LDU and 4 degrees short of where it was built. Grab learned the
## same (Grab._built_touching).
var rest_cells: Dictionary = {}


## Every joint in the model, its rest where its parts stand now. Returns
## how many.
func find() -> int:
	joints.clear()
	rest.clear()
	rest_cells.clear()
	if assemblies == null:
		return 0
	for path: String in assemblies.paths():
		var ids: PackedInt64Array = assemblies.ids_under(path)
		if ids.is_empty():
			continue
		# A laid hose, tube, string or chain is one of these too, and its end
		# pin in a hole reads as a hinge; swung about it, the tube tore off
		# its other hole (flex_pose_flow on a preview, 2026-10-12).
		var parts: Array = []
		for brick_id: int in ids:
			parts.append(world.get_brick(brick_id).part_id)
		if not Flex.kind_of(parts).is_empty():
			continue
		var found: Dictionary = builder._joint_of(ids)
		if found.is_empty():
			continue
		var joint := Joint.new()
		joint.path = path
		joint.point = found["point"]
		joint.axis = (found["axis"] as Vector3).normalized()
		joint.partners = found["partners"]
		joint.ids = ids
		joint.depth = Assemblies.segments(path).size()
		joints.append(joint)
		for brick_id: int in ids:
			rest[brick_id] = world.get_brick(brick_id).transform
			rest_cells[brick_id] = builder.lattice.boxes_of(brick_id)
	joints.sort_custom(func(a: Joint, b: Joint) -> bool:
		if a.depth != b.depth:
			return a.depth < b.depth
		return a.path.naturalnocasecmp_to(b.path) < 0)
	return joints.size()


func joint(path: String) -> Joint:
	for one: Joint in joints:
		if one.path == path:
			return one
	return null


## Each joint's angle now: path -> degrees.
func angles() -> Dictionary:
	var out: Dictionary = {}
	for one: Joint in joints:
		out[one.path] = one.angle
	return out


## Where every part that turns stands at [param wanted] (path -> degrees;
## a joint not named stays at rest): innermost joints first, each about its
## rest axis, and the outer ones carrying them.
func transforms_for(wanted: Dictionary) -> Dictionary:
	var out: Dictionary = rest.duplicate()
	for n: int in range(joints.size() - 1, -1, -1):
		var one: Joint = joints[n]
		var degrees: float = float(wanted.get(one.path, 0.0))
		if is_zero_approx(degrees):
			continue
		var around: Transform3D = Transform3D(Basis.IDENTITY, one.point) \
			* Transform3D(Basis(one.axis, deg_to_rad(degrees)), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -one.point)
		for brick_id: int in one.ids:
			out[brick_id] = around * (out[brick_id] as Transform3D)
	# Each is turned from its rest, never from the last frame, so nothing
	# drifts to be squared up. Squared up, Play rewrote every part of every
	# joint keyed, turned up to 0.0006 on 8808-1's LDraw matrices, with no
	# step to undo.
	return out


## Stand the parts as [param wanted] says, without asking whether they have
## room and without a step to undo: a slider being dragged, a frame of an
## animation played in the window. The lattice is left as it was until
## [method settle].
func stand(wanted: Dictionary) -> void:
	var placed: Dictionary = transforms_for(wanted)
	for brick_id: Variant in placed:
		if world.get_brick(int(brick_id)) != null:
			world.move_brick(int(brick_id), placed[brick_id])


## Set one joint to [param degrees], as far towards it as it has room for
## from where it was at [param was] degrees: one step to undo, the parts
## where the lattice says they are. Returns the angle it reached.
func settle(path: String, degrees: float, was: float) -> float:
	var one: Joint = joint(path)
	if one == null:
		return was
	var before: Dictionary = angles()
	before[path] = was
	var start: Dictionary = transforms_for(before)
	var reached: float = degrees
	var wanted: Dictionary = before.duplicate()
	wanted[path] = degrees
	if not _has_room(one, transforms_for(wanted), start):
		# The furthest it goes from where it was towards where it was asked.
		var low: float = was
		var high: float = degrees
		for _round: int in 12:
			var mid: float = (low + high) * 0.5
			wanted[path] = mid
			if _has_room(one, transforms_for(wanted), start):
				low = mid
			else:
				high = mid
		reached = low
		wanted[path] = reached
	one.angle = reached
	var placed: Dictionary = transforms_for(angles())
	var steps: Array = []
	for brick_id: int in one.ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var to: Transform3D = placed[brick_id]
		steps.append({"undo": "move", "brick": brick_id, "transform": start[brick_id]})
		world.move_brick(brick_id, to)
		builder.lattice.release(brick_id)
		builder.lattice.occupy_boxes(brick_id, builder.boxes_for(library.mesh_for(brick.part_id), to))
	if not is_equal_approx(reached, was):
		builder.record(steps, "posed %s at %d°" % [Assemblies.label(path), roundi(reached)])
	return reached


## Whether a joint's parts have room at [param placed], pressing only on
## what they are joined to; the lattice is put back as it was ([param
## start]) either way.
func _has_room(one: Joint, placed: Dictionary, start: Dictionary) -> bool:
	var moving: Dictionary = {}
	for brick_id: int in one.ids:
		moving[brick_id] = true
		builder.lattice.release(brick_id)
	var free: bool = true
	for brick_id: int in one.ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var packed: PackedInt32Array = builder.boxes_for(library.mesh_for(brick.part_id),
			placed[brick_id])
		for other: int in builder.lattice.blockers_boxes(packed):
			if not moving.has(other) and not one.partners.has(other) \
					and not _touched_at_rest(brick_id, other):
				free = false
				break
		if not free:
			break
	for brick_id: int in one.ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null:
			builder.lattice.occupy_boxes(brick_id, builder.boxes_for(
				library.mesh_for(brick.part_id), start[brick_id]))
	return free


## Whether [param one] has room to turn [param degrees] from where it
## stands, the other joints held. Changes nothing.
func has_room_to(one: Joint, degrees: float) -> bool:
	var now: Dictionary = angles()
	var wanted: Dictionary = now.duplicate()
	wanted[one.path] = one.angle + degrees
	return _has_room(one, transforms_for(wanted), transforms_for(now))


## Whether [param brick_id] overlapped [param other] where both stood at
## rest ([member rest_cells]; a part that does not turn, where it stands).
func _touched_at_rest(brick_id: int, other: int) -> bool:
	var mine: PackedInt32Array = rest_cells.get(brick_id, PackedInt32Array())
	var theirs: PackedInt32Array = rest_cells.get(other, builder.lattice.boxes_of(other))
	return not mine.is_empty() and not theirs.is_empty() and BrickLattice._overlaps(mine, theirs)


## Whether the parts stand as the joints' angles say: false once something
## else has moved them (an undo, an edit), and the pose is read again.
func holds() -> bool:
	if joints.is_empty():
		return true
	var placed: Dictionary = transforms_for(angles())
	for brick_id: Variant in placed:
		var brick: BrickWorld.Brick = world.get_brick(int(brick_id))
		if brick == null:
			return false
		if not _near(brick.transform, placed[brick_id]):
			return false
	return true


## Read each joint's angle back off where its parts stand, outermost first,
## after an undo has moved them. False when they do not stand as any pose
## of these joints would put them.
func read_back() -> bool:
	for one: Joint in joints:
		var own: int = _own_brick(one)
		if own == 0 or world.get_brick(own) == null:
			continue
		var outer: Dictionary = angles()
		outer[one.path] = 0.0
		for other: Joint in joints:
			if other.depth >= one.depth and other != one:
				outer[other.path] = 0.0
		# Undo what the joints outside it did to it, and what is left is
		# this joint's own turn.
		var carried: Basis = (transforms_for(outer)[own] as Transform3D).basis
		var at_rest: Basis = (rest[own] as Transform3D).basis
		# now = outer · own turn · rest, and carried = outer · rest.
		var turn: Basis = at_rest * carried.inverse() * world.get_brick(own).transform.basis \
			* at_rest.inverse()
		var across: Vector3 = (Vector3.UP if absf(one.axis.y) < 0.9 else Vector3.RIGHT) \
			.cross(one.axis).normalized()
		var turned: Vector3 = turn * across
		one.angle = rad_to_deg(atan2(one.axis.dot(across.cross(turned)), across.dot(turned)))
	return holds()


## A part of the joint's own, not inside a joint within it.
func _own_brick(one: Joint) -> int:
	var inner: Dictionary = {}
	for other: Joint in joints:
		if other.depth > one.depth and other.path.begins_with(one.path + "/"):
			for brick_id: int in other.ids:
				inner[brick_id] = true
	for brick_id: int in one.ids:
		if not inner.has(brick_id):
			return brick_id
	return 0


static func _near(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.05 and a.basis.x.distance_to(b.basis.x) < 0.001 \
		and a.basis.y.distance_to(b.basis.y) < 0.001 and a.basis.z.distance_to(b.basis.z) < 0.001


## The poses a balance check weighs (Balance.measure): each
## {"label", "angles": path -> degrees, "transforms": brick id -> Transform3D}.
##
## The frames of [param animation] when it has keys, as Play and Render
## animation run them. Otherwise every joint swung on its own from where it
## is now, [param step] degrees at a time each way round to half a turn, as
## far as it has room for, the others held: what the sliders can reach. A
## turntable goes all the way round, and an arm on a hinge stops where it
## would run into the model, as the slider does (see [method settle]).
func sweep(animation: PoseAnimation = null, step: float = 15.0) -> Array:
	var out: Array = []
	if joints.is_empty():
		return out
	if animation != null and not animation.keys.is_empty():
		for n: int in animation.frame_count():
			var t: float = animation.time_of(n)
			var angles_then: Dictionary = animation.angles_at(t)
			out.append({"label": "the animation at %.2f s" % t, "angles": angles_then,
				"transforms": transforms_for(angles_then)})
		return out
	var now: Dictionary = angles()
	var start: Dictionary = transforms_for(now)
	for one: Joint in joints:
		for way: float in [1.0, -1.0]:
			var turned: float = step
			# The other way stops a step short of half a turn: that one is
			# already in.
			var furthest: float = 180.0 if way > 0.0 else 180.0 - step
			while turned <= furthest + 0.001:
				var wanted: Dictionary = now.duplicate()
				wanted[one.path] = one.angle + way * turned
				var placed: Dictionary = transforms_for(wanted)
				if not _has_room(one, placed, start):
					break
				out.append({"label": "%s at %d°" % [Assemblies.label(one.path),
					roundi(wrapf(one.angle + way * turned, -180.0, 180.0))],
					"angles": wanted, "transforms": placed})
				turned += step
	return out


## The box every part that moves sweeps through over [param poses], each a
## brick id -> Transform3D: what a render of them must frame.
func reach(poses: Array) -> AABB:
	var box := AABB()
	var first: bool = true
	for placed: Dictionary in poses:
		for brick_id: Variant in placed:
			var brick: BrickWorld.Brick = world.get_brick(int(brick_id))
			if brick == null:
				continue
			var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if part == null:
				continue
			var here: AABB = ((placed[brick_id] as Transform3D) * part.bounds).abs()
			box = here if first else box.merge(here)
			first = false
	return box
