## Whether a model stands on what it stands on, by how much, and which stud
## joint gives first.
##
## Asked for by the owner (2026-10-13) after Claude told them "Brickworks
## checks that the parts connect, not physical balance… Neptune's arm still
## reaches about 18 studs past the base edge". The research, the numbers and
## their sources are docs/MECHANISMS.md §4; this is its phase S1.
##
## Tipping
## -------
## The support polygon is the convex hull of where the model touches the
## floor or its baseplate ([url]https://en.wikipedia.org/wiki/Support_polygon[/url]).
## The model stands while its centre of mass is over it, and the tipping
## margin is how far that point is from the nearest edge: positive inside,
## negative past it. The force-angle measure (Papadopoulos and Rey 1996) is
## the same edge weighed against how high the centre of mass stands: the tilt
## that carries it over the edge, so a tall model on a narrow base reads
## nearer tipping than a low one with the same margin. With gravity the only
## force, it is atan(margin / height).
##
## The fix, as a number: a mass m whose centre is d past an edge needs a
## counter-moment m·d, so a counterweight w a lever L inside the edge must
## have w·L ≥ m·d. [member Report.counterweight] is the least w that brings
## every pose back at least [constant SPARE] studs inside, placed where it
## does most good, and [member Report.widen] how far the base would have to
## grow instead.
##
## Stud joints
## -----------
## A stud joint holds a moment about the edge it would turn on by the
## rigid-plastic bound M = Σ F·dᵢ, each stud pulling F at its distance dᵢ
## from that edge (a 2x2 at 1 N a stud holds 3.2 N·cm). Nobody has published
## a measured clutch force: the book the LEGO Group published says "the
## ideal strength's value must remain secret" (The Secret Life of LEGO®
## Bricks, p. 22), and StableLego
## measured 0.98 N per contact point, three or four contact points to a stud
## (arXiv 2402.10711). So F is 1 N a stud for the working load and 3 N for
## where it lets go, and the answer is honest to a factor of two or so.
##
## What a joint carries is everything beyond it: the parts that come off with
## it. That is only well defined where the joint is the one thing holding
## them — a bridge in the graph of what holds what, grown from the floor — and
## those are the joints that fail: a cantilever's root, a tower's foot, a T on
## one stud, a part hung under another. A joint in a bonded wall shares its
## load with its neighbours by an amount statics alone cannot say, and is left
## to Stability's levels. The graph is the studs (Stability.stud_joints) and the
## pins, axles, clips, hinges and turntables (Joints), so an arm on a pin is
## carried by the stud joint under its pin; but only stud joints are checked,
## since a pin's friction torque has not been measured.
##
## Poses
## -----
## [method measure] weighs the model as it stands and then each pose it is
## given: {"label": String, "transforms": brick id -> Transform3D} for the
## parts that pose moves. Today those are the Pose panel's animation or every
## joint swung through its reach (Poser.sweep); a mechanism's cycle
## (src/assembly/mechanism.gd, P1) will hand over its frames the same way.
## The worst is reported. The support polygon is the one the model stands on
## as it is, and a pose that would put a part through the floor is not one it
## can reach, so it is left out.
##
## Pure: it reads the bricks, the lattice and the library and changes none of
## them, so it can run on a worker as the design check does.
class_name Balance
extends RefCounted

## m/s².
const GRAVITY := 9.81
const MM_PER_LDU := 0.4
## A stud's working load and where it lets go, N (see above).
const ALLOWABLE_N := 1.0
const ULTIMATE_N := 3.0
## Within this of the lowest cell a part counts as standing on the floor, in
## cells: half a plate, so a tyre's rounded foot does and a chassis above it
## does not.
const ON_FLOOR := 2
## What the advice leaves to spare, in studs: following it puts the centre
## of mass at least this far inside every edge.
const SPARE := 0.5
## A counterweight goes within twice this of the far edge, its middle this
## far in, in studs.
const WEIGHT_IN := 2.0
## A 2x4 brick, for saying a weight in bricks (BrickLink, 2026-10-13).
const BRICK_GRAMS := 2.32

var library: PartLibrary
var lattice: BrickLattice
## Bricks that are the floor and not the model: the baseplate under it.
var floor_ids: Dictionary = {}
## Where each stud joint's studs are, by the pair's ids (Vector2i(lower,
## upper) -> [method _overlap]): kept from one weighing to the next when a
## caller hands the same dictionary to each, as Tested does weighing a model
## at every step. Comparing the two parts' boxes was most of a weighing:
## 2.6 s of 2.65 for 75060's 2,014 parts, many of them turned.
var overlaps: Dictionary = {}


## One stud joint and what it carries.
class JointLoad extends RefCounted:
	## The part on the side that would come off, and the part it is held by.
	var beyond: int = 0
	var held_by: int = 0
	var beyond_part: String = ""
	var held_part: String = ""
	var studs: int = 0
	## Everything past the joint, g.
	var grams: float = 0.0
	## About the edge it would turn on, N·cm, against what its studs hold
	## there at the working load and at the most.
	var moment: float = 0.0
	var capacity: float = 0.0
	var ultimate: float = 0.0
	## Straight off its studs, N: a part hung under another.
	var pull: float = 0.0
	var hangs: bool = false
	## moment / capacity: past 1 it is over the working load.
	var ratio: float = 0.0
	## The pose it was worst in; empty as it stands.
	var pose: String = ""
	var at: Vector3 = Vector3.ZERO


class Report extends RefCounted:
	var grams: float = 0.0
	## In the worst pose, LDU; and as it stands.
	var centre: Vector3 = Vector3.ZERO
	var rest_centre: Vector3 = Vector3.ZERO
	var floor_y: float = 0.0
	## Where it touches the floor, x and z in LDU, in order round the edge.
	var support: PackedVector2Array = PackedVector2Array()
	## Studs from the nearest edge, in the worst pose and as it stands:
	## positive inside, negative past it.
	var margin: float = 0.0
	var rest_margin: float = 0.0
	## That edge: its name ("front" is +z) and its two ends in LDU.
	var edge: String = ""
	var edge_ends: PackedVector2Array = PackedVector2Array()
	## The force-angle measure in the worst pose, degrees: the tilt that
	## carries the centre of mass over that edge.
	var tilt: float = 0.0
	## How many poses were weighed besides the model as it stands, how many
	## were left out as through the floor, and the worst one's label (empty
	## when the worst is as it stands).
	var poses: int = 0
	var unreachable: int = 0
	var worst_pose: String = ""
	var worst_index: int = -1
	## The least that brings every pose SPARE studs inside, g, and where it
	## goes; 0 when nothing is needed or nothing placed on the base would do.
	var counterweight: float = 0.0
	var counterweight_at: Vector2 = Vector2.ZERO
	var counterweight_where: String = ""
	## Or the base grown this many whole studs toward [member widen_toward].
	var widen: int = 0
	var widen_toward: String = ""
	## Bridge stud joints, most loaded first, each at its worst pose.
	var joints: Array = []
	## How many are past the working load.
	var over: int = 0
	## Parts the graph does not reach from the floor (held by something it
	## does not read): weighed, but in no joint.
	var adrift: int = 0
	## Nothing in it touches anything: an empty model.
	var empty: bool = true

	func stands() -> bool:
		return not empty and margin >= 0.0

	func needs_help() -> bool:
		return not empty and margin < Balance.SPARE

	## The margin in plain words, for the person: the status bar's line, so
	## short enough to be read there whole.
	func words() -> String:
		if empty:
			return "Nothing to weigh."
		var out: String
		if margin >= 0.0:
			out = "Stands, %s studs inside the %s edge (a %d° tilt tips it)" % [
				Balance.studs(margin), edge, maxi(roundi(tilt), 0)]
		else:
			out = "Tips over, %s studs past the %s edge" % [Balance.studs(-margin), edge]
		if poses > 0:
			out += (" with %s, its worst of %d poses" % [worst_pose, poses + 1]
				if not worst_pose.is_empty() else " as it stands, its worst of %d poses" % (poses + 1))
		out += "."
		if counterweight > 0.0:
			out += " Add %d g (%d 2x4 bricks) %s, or widen it %d stud%s to the %s." % [
				ceili(counterweight), ceili(counterweight / Balance.BRICK_GRAMS),
				counterweight_where.replace("within %s studs of" % Balance.studs(
					Balance.WEIGHT_IN * 2.0), "near"), widen, "" if widen == 1 else "s",
				widen_toward]
		elif needs_help() and widen > 0:
			out += " Widen it %d stud%s to the %s." % [widen, "" if widen == 1 else "s",
				widen_toward]
		if over > 0:
			out += " %d stud joint%s overloaded, in red." % [over, "" if over == 1 else "s"]
		return out

	## The numbers for a Claude session (check_design), compact, with what to
	## do about them. [param namer] says a brick id the way the session
	## knows it.
	func said(namer: Callable = Callable()) -> String:
		if empty:
			return ""
		var lines := PackedStringArray()
		var where: String = "the %s edge %s" % [edge, Balance.edge_words(edge_ends)]
		var head: String
		if margin >= 0.0:
			head = "Balance: stands; centre of mass %s studs inside %s, force angle %d°" % [
				Balance.studs(margin), where, maxi(roundi(tilt), 0)]
		else:
			head = "Balance: TIPS OVER; centre of mass %s studs past %s, at x=%s z=%s" % [
				Balance.studs(-margin), where, Balance.studs(centre.x / BrickLattice.STUD),
				Balance.studs(centre.z / BrickLattice.STUD)]
		if poses > 0:
			head += ("; worst of %d poses: %s" % [poses + 1, worst_pose]
				if not worst_pose.is_empty() else "; worst of %d poses: as it stands" % (poses + 1))
			if not worst_pose.is_empty():
				head += " (as it stands: %s studs %s)" % [Balance.studs(absf(rest_margin)),
					"inside" if rest_margin >= 0.0 else "past"]
		lines.append(head + "; %.0f g." % grams)
		if counterweight > 0.0:
			lines.append(("To stand with %s studs to spare: add at least %d g (about %d 2x4 "
				+ "bricks) %s, centred x=%s z=%s, or widen the base %d stud%s toward the %s. "
				+ "Then check again.") % [Balance.studs(Balance.SPARE), ceili(counterweight),
				ceili(counterweight / Balance.BRICK_GRAMS), counterweight_where,
				Balance.studs(counterweight_at.x / BrickLattice.STUD),
				Balance.studs(counterweight_at.y / BrickLattice.STUD), widen,
				"" if widen == 1 else "s", widen_toward])
		elif needs_help() and widen > 0:
			lines.append("To stand with %s studs to spare: widen the base %d stud%s toward the %s." % [
				Balance.studs(Balance.SPARE), widen, "" if widen == 1 else "s", widen_toward])
		if not joints.is_empty():
			var shown := PackedStringArray()
			var name_of: Callable = namer
			if not name_of.is_valid():
				name_of = func(id: int) -> String: return "#%d" % id
			for one: JointLoad in joints.slice(0, 3):
				var line: String = "%s %s %s on %d stud%s: %s N·cm against %s (%sx; lets go at %s)" % [
					str(name_of.call(one.beyond)), "hanging from" if one.hangs else "on",
					str(name_of.call(one.held_by)), one.studs, "" if one.studs == 1 else "s",
					Balance.tidy(one.moment), Balance.tidy(one.capacity), Balance.tidy(one.ratio),
					Balance.tidy(one.ultimate)]
				if one.hangs:
					line += ", pulled %s N" % Balance.tidy(one.pull)
				if not one.pose.is_empty():
					line += ", %s" % one.pose
				shown.append(line)
			lines.append("Most loaded stud joints (1 N a stud working, 3 N lets go): "
				+ "; ".join(shown) + ".")
			if over > 0:
				lines.append(("%d past the working load: brace %s, give %s more studs, or "
					+ "move weight back over what holds it.") % [over,
					"it" if over == 1 else "them", "it" if over == 1 else "them"])
		return "\n".join(lines)


## A number of studs as said: one decimal, no trailing ".0".
static func studs(value: float) -> String:
	var rounded: float = snappedf(value, 0.1)
	if is_equal_approx(rounded, roundf(rounded)):
		return "%d" % roundi(rounded)
	return "%.1f" % rounded


static func tidy(value: float) -> String:
	if absf(value) >= 10.0:
		return "%.0f" % value
	if absf(value) >= 1.0:
		return "%.1f" % value
	return "%.2f" % value


## An edge's ends as a session reads them: "(z=8)" when it runs along x.
static func edge_words(ends: PackedVector2Array) -> String:
	if ends.size() < 2:
		return ""
	var a: Vector2 = ends[0] / BrickLattice.STUD
	var b: Vector2 = ends[1] / BrickLattice.STUD
	if absf(a.y - b.y) < 0.05:
		return "(z=%s)" % studs(a.y)
	if absf(a.x - b.x) < 0.05:
		return "(x=%s)" % studs(a.x)
	return "(x=%s z=%s to x=%s z=%s)" % [studs(a.x), studs(a.y), studs(b.x), studs(b.y)]


## Which edge a way out is: +z the front, +x the right.
static func edge_name(way: Vector2) -> String:
	if way.length() < 0.0001:
		return "nearest"
	var degrees: float = rad_to_deg(atan2(way.y, way.x))
	var names: Array = ["right", "front-right", "front", "front-left", "left",
		"back-left", "back", "back-right"]
	var sector: int = posmod(roundi(degrees / 45.0), 8)
	return names[sector]


static func opposite(name: String) -> String:
	var swap: Dictionary = {"front": "back", "back": "front", "left": "right",
		"right": "left"}
	var parts: PackedStringArray = name.split("-")
	for n: int in parts.size():
		parts[n] = swap.get(parts[n], parts[n])
	return "-".join(parts)


# -- weighing ------------------------------------------------------------------


## The model's parts, as [method measure] reads them.
var _ids := PackedInt64Array()
var _parts: Array[String] = []
var _mass := PackedFloat64Array()
var _middle: Array[Vector3] = []
var _rest: Array[Transform3D] = []
## Each part's geometry, for how low a pose takes it (Lbm.PartMesh.lowest_at).
var _meshes: Array[Lbm.PartMesh] = []
## The sub-model each is in (Assemblies.path_of), for what holds it otherwise.
var _paths: Array[String] = []
var _index_of: Dictionary = {}
## The graph: node per part and one for the floor, edges both ways.
var _edge_a := PackedInt32Array()
var _edge_b := PackedInt32Array()
var _edge_stud := PackedByteArray()
## For a stud edge, which end is the lower: the one with the studs.
var _edge_lower := PackedInt32Array()
## Stud joints whose studs point sideways or down, by pair
## (Stability.stud_joints' "sideways"): where their studs are.
var _sideways: Dictionary = {}
var _adjacent: Array = []
## Depth-first from the floor: each node's parent, its parent edge, and the
## nodes in the order they were reached.
var _parent := PackedInt32Array()
var _reached := PackedInt32Array()
## The stud joints that are bridges, each {edge, child, lower, upper,
## centre, normal, studs: PackedVector3Array, corners: PackedVector3Array}
## at the model as it stands.
var _bridges: Array = []
var _hull := PackedVector2Array()
var _floor_y: float = 0.0


## Weigh [param bricks] as they stand and in each of [param poses], and say
## how it stands at the worst. [param links] are pairs of brick ids held by
## something other than studs — a pin, an axle, a clip, a hinge, a sticker's
## glue, a string's braids — when the caller has them already (the design
## check does); found here otherwise. [param contacts] is what rests on
## what (Stability.contacts) in a model these bricks are part of, read once
## for many of its parts weighed in turn (BrickifySteps: each step's partial
## build); worked out here otherwise.
func measure(bricks: Array, poses: Array = [], links: Variant = null,
		contacts: Dictionary = {}) -> Report:
	var report := Report.new()
	if not prepare(bricks, links, contacts):
		return report
	report.empty = false
	report.support = _hull
	report.floor_y = _floor_y

	for n: int in _mass.size():
		report.grams += _mass[n]

	# As it stands, then each pose.
	var weighed: Array = []         ## [centre, margin, edge index, ...] per pose
	var worst_at: Dictionary = {}   ## joint index -> JointLoad
	var rest: Dictionary = _weigh({}, "", worst_at)
	weighed.append(rest)
	report.rest_centre = rest["centre"]
	report.rest_margin = float(rest["margin"]) / BrickLattice.STUD
	var worst: Dictionary = rest
	for n: int in poses.size():
		var pose: Dictionary = poses[n]
		var placed: Dictionary = pose.get("transforms", {})
		if _through_floor(placed):
			report.unreachable += 1
			continue
		report.poses += 1
		var here: Dictionary = _weigh(placed, str(pose.get("label", "pose %d" % (n + 1))), worst_at)
		weighed.append(here)
		if float(here["margin"]) < float(worst["margin"]):
			worst = here
			report.worst_index = n
	report.centre = worst["centre"]
	report.margin = float(worst["margin"]) / BrickLattice.STUD
	report.edge = worst["edge"]
	report.edge_ends = worst["ends"]
	report.tilt = worst["tilt"]
	report.worst_pose = worst["label"]

	for one: Variant in worst_at.values():
		report.joints.append(one)
	report.joints.sort_custom(func(a: JointLoad, b: JointLoad) -> bool:
		return a.ratio > b.ratio)
	for one: JointLoad in report.joints:
		if one.ratio > 1.0:
			report.over += 1
	for n: int in _ids.size():
		if _parent[n] == -2:
			report.adrift += 1

	if report.margin < SPARE:
		_advise(report, weighed, worst)
	return report


## Read [param bricks] and the joints between them once, so that poses can
## then be weighed one at a time as they come ([method weigh_pose]): a part
## being dragged about its joint (GrabDrag), weighed every frame. False for a
## model with nothing to stand on.
func prepare(bricks: Array, links: Variant = null, contacts: Dictionary = {}) -> bool:
	_read(bricks)
	if _ids.is_empty():
		return false
	var graph: Dictionary = contacts
	var boxes: Dictionary = {}
	if contacts.is_empty():
		var judge := Stability.new()
		judge.library = library
		judge.lattice = lattice
		var model: Array = []
		for item: Variant in bricks:
			var brick: BrickWorld.Brick = item
			if _index_of.has(brick.id):
				model.append(brick)
		graph = judge.contacts(model)
		boxes = graph["boxes"]
	else:
		# Only these bricks' boxes: what they stand on is the lowest of them.
		var all: Dictionary = contacts["boxes"]
		for id: int in _ids:
			if all.has(id):
				boxes[id] = all[id]
	_ground(boxes)
	if _hull.size() < 3:
		return false
	var joints: Dictionary = Stability.stud_joints(graph, library, lattice)
	_sideways = joints["sideways"]
	_join(joints, links if links != null else _links())
	_grow()
	_find_bridges(boxes)
	return true


## One pose weighed against what [method prepare] read: the parts [param
## placed] names (brick id -> Transform3D) where it puts them, the rest
## where they stand. The margin, the edge and each stud joint's load in that
## pose alone; no advice, which is for a whole motion.
func weigh_pose(placed: Dictionary, label: String = "") -> Report:
	var report := Report.new()
	if _ids.is_empty() or _hull.size() < 3:
		return report
	report.empty = false
	report.support = _hull
	report.floor_y = _floor_y
	for n: int in _mass.size():
		report.grams += _mass[n]
	var worst_at: Dictionary = {}
	var here: Dictionary = _weigh(placed, label, worst_at)
	report.centre = here["centre"]
	report.rest_centre = here["centre"]
	report.margin = float(here["margin"]) / BrickLattice.STUD
	report.rest_margin = report.margin
	report.edge = here["edge"]
	report.edge_ends = here["ends"]
	report.tilt = here["tilt"]
	for one: Variant in worst_at.values():
		report.joints.append(one)
	report.joints.sort_custom(func(a: JointLoad, b: JointLoad) -> bool:
		return a.ratio > b.ratio)
	for one: JointLoad in report.joints:
		if one.ratio > 1.0:
			report.over += 1
	return report


func _read(bricks: Array) -> void:
	_ids = PackedInt64Array()
	_parts.clear()
	_mass = PackedFloat64Array()
	_middle.clear()
	_rest.clear()
	_meshes.clear()
	_paths.clear()
	_index_of.clear()
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		if floor_ids.has(brick.id) or _index_of.has(brick.id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if info == null or part == null:
			continue
		_index_of[brick.id] = _ids.size()
		_ids.append(brick.id)
		_parts.append(brick.part_id)
		_mass.append(Stability.grams(info))
		# Weighed at the middle of its shape, as Stability does: LDraw puts
		# a part's origin on top of its body.
		_middle.append(part.bounds.get_center())
		_rest.append(brick.transform)
		_meshes.append(part)
		_paths.append(Assemblies.path_of(brick))


## Where it touches the floor: every box within ON_FLOOR of the lowest cell
## of the model, and the hull round them.
func _ground(boxes: Dictionary) -> void:
	var found: Dictionary = Balance.support_of(boxes)
	_hull = found["hull"]
	_floor_y = found["floor_y"]
	_grounded = {}
	for id: Variant in found["grounded"]:
		_grounded[_index_of[int(id)]] = true


var _grounded: Dictionary = {}


## Where a model touches the floor, from its parts' boxes (id -> boxes, the
## floor's own left out): every box within ON_FLOOR of the lowest cell, and
## the hull round them. {"hull": x and z in LDU in order round it,
## "floor_y": LDU, "grounded": id -> true for each part touching}.
static func support_of(boxes: Dictionary) -> Dictionary:
	var lowest: int = 0x7FFFFFFF
	for id: Variant in boxes:
		var packed: PackedInt32Array = boxes[id]
		for at: int in range(0, packed.size(), 6):
			lowest = mini(lowest, packed[at + 1])
	var grounded: Dictionary = {}
	if lowest == 0x7FFFFFFF:
		return {"hull": PackedVector2Array(), "floor_y": 0.0, "grounded": grounded}
	var points := PackedVector2Array()
	for id: Variant in boxes:
		var packed: PackedInt32Array = boxes[id]
		for at: int in range(0, packed.size(), 6):
			if packed[at + 1] > lowest + ON_FLOOR:
				continue
			grounded[id] = true
			var x0: float = packed[at] * BrickLattice.CELL
			var z0: float = packed[at + 2] * BrickLattice.CELL
			var x1: float = packed[at + 3] * BrickLattice.CELL
			var z1: float = packed[at + 5] * BrickLattice.CELL
			points.append_array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1),
				Vector2(x0, z1)])
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.resize(hull.size() - 1)
	return {"hull": hull, "floor_y": lowest * BrickLattice.CELL, "grounded": grounded}


## Pairs held by pins, axles, clips, hinges and turntables, and by glue and
## by being one thing (Joints.held_otherwise), as the design check joins them.
func _links() -> Array:
	var entries: Array = []
	for n: int in _ids.size():
		entries.append([_ids[n], _rest[n], library.mesh_for(_parts[n]), _parts[n], _paths[n]])
	var out: Array = []
	for held: Dictionary in [Joints.both_ways(entries), Joints.rounds(entries),
			Joints.held_otherwise(entries, library)]:
		for one: Variant in held:
			for other: Variant in held[one]:
				out.append([int(one), int(other)])
	return out


## The graph: a node per part and one for the floor, an edge for each pair
## studs join ([param joints], Stability.stud_joints), each pair [param
## links] names and each part on the floor. A pair seated one in the other
## (joints' "seated") is joined but by no stud joint: a cone threaded on an
## antenna carries its weight to it, but it has no studs to weigh. Left out,
## 8466-1's 1,197 parts were in no joint, held by pins nothing reads.
func _join(joints: Dictionary, links: Array) -> void:
	var count: int = _ids.size()
	_edge_a = PackedInt32Array()
	_edge_b = PackedInt32Array()
	_edge_stud = PackedByteArray()
	_edge_lower = PackedInt32Array()
	_adjacent.clear()
	for _n: int in count + 1:
		_adjacent.append([])
	var seen: Dictionary = {}
	var add := func(a: int, b: int, stud: bool, lower: int) -> void:
		if a == b:
			return
		var key: int = mini(a, b) * (count + 1) + maxi(a, b)
		if seen.has(key):
			var e: int = seen[key]
			if stud and _edge_stud[e] == 0:
				_edge_stud[e] = 1
				_edge_lower[e] = lower
			return
		var e: int = _edge_a.size()
		seen[key] = e
		_edge_a.append(a)
		_edge_b.append(b)
		_edge_stud.append(1 if stud else 0)
		_edge_lower.append(lower if stud else -1)
		(_adjacent[a] as Array).append(e)
		(_adjacent[b] as Array).append(e)
	var under: Dictionary = joints["under"]
	var overlapped: Dictionary = joints["overlapped"]
	for key: int in joints["studs"]:
		var one: int = key >> 32
		var other: int = key & 0xFFFFFFFF
		if _index_of.has(one) and _index_of.has(other):
			var by_studs: bool = not overlapped.has(key)
			add.call(int(_index_of[one]), int(_index_of[other]), by_studs,
				int(_index_of[int(under[key])]) if by_studs else -1)
	for key: int in joints["seated"]:
		var one: int = key >> 32
		var other: int = key & 0xFFFFFFFF
		if _index_of.has(one) and _index_of.has(other):
			add.call(int(_index_of[one]), int(_index_of[other]), false, -1)
	for pair: Array in links:
		if _index_of.has(int(pair[0])) and _index_of.has(int(pair[1])):
			add.call(int(_index_of[int(pair[0])]), int(_index_of[int(pair[1])]), false, -1)
	for n: Variant in _grounded:
		add.call(int(n), count, false, -1)


## Depth first from the floor, without recursion: each node's parent and
## low point, and the bridges, which are the edges nothing else spans.
var _bridge_edges: Dictionary = {}


func _grow() -> void:
	var count: int = _ids.size()
	var ground: int = count
	var found := PackedInt32Array()
	found.resize(count + 1)
	found.fill(-1)
	var low := PackedInt32Array()
	low.resize(count + 1)
	_parent = PackedInt32Array()
	_parent.resize(count + 1)
	_parent.fill(-2)
	var by_edge := PackedInt32Array()
	by_edge.resize(count + 1)
	by_edge.fill(-1)
	var next := PackedInt32Array()
	next.resize(count + 1)
	_reached = PackedInt32Array()
	_bridge_edges.clear()
	var clock: int = 0
	found[ground] = clock
	low[ground] = clock
	clock += 1
	_parent[ground] = -1
	var stack := PackedInt32Array([ground])
	while not stack.is_empty():
		var v: int = stack[stack.size() - 1]
		var mine: Array = _adjacent[v]
		if next[v] < mine.size():
			var e: int = int(mine[next[v]])
			next[v] += 1
			if e == by_edge[v]:
				continue
			var w: int = _edge_b[e] if _edge_a[e] == v else _edge_a[e]
			if found[w] == -1:
				found[w] = clock
				low[w] = clock
				clock += 1
				_parent[w] = v
				by_edge[w] = e
				_reached.append(w)
				stack.append(w)
			else:
				low[v] = mini(low[v], found[w])
		else:
			stack.resize(stack.size() - 1)
			var p: int = _parent[v]
			if p >= 0:
				low[p] = mini(low[p], low[v])
				if low[v] > found[p]:
					_bridge_edges[by_edge[v]] = v


## Each bridge that is a stud joint, with where its studs are.
func _find_bridges(boxes: Dictionary) -> void:
	_bridges.clear()
	for e: Variant in _bridge_edges:
		if _edge_stud[int(e)] == 0:
			continue
		var child: int = _bridge_edges[e]
		var lower: int = _edge_lower[int(e)]
		var upper: int = _edge_b[int(e)] if _edge_a[int(e)] == lower else _edge_a[int(e)]
		var side: Variant = _sideways.get(Stability.pair_of(_ids[lower], _ids[upper]))
		if side != null:
			_bridges.append(Balance._bridge_of_studs(child, lower, upper, side[0], side[1]))
			continue
		var pair := Vector2i(_ids[lower], _ids[upper])
		var met: Variant = overlaps.get(pair)
		if met == null:
			met = _overlap(boxes[_ids[lower]], boxes[_ids[upper]])
			overlaps[pair] = met
		var lo: Vector3i = (met as Array)[0]
		var hi: Vector3i = (met as Array)[1]
		if lo.x == 0x7FFFFFFF:
			continue
		var y: float = lo.y * BrickLattice.CELL
		var x_from: float = lo.x * BrickLattice.CELL
		var z_from: float = lo.z * BrickLattice.CELL
		var wide: float = (hi.x - lo.x) * BrickLattice.CELL
		var deep: float = (hi.z - lo.z) * BrickLattice.CELL
		var across: int = maxi(1, roundi(wide / BrickLattice.STUD))
		var along: int = maxi(1, roundi(deep / BrickLattice.STUD))
		var studs := PackedVector3Array()
		for i: int in across:
			for k: int in along:
				studs.append(Vector3(x_from + (i + 0.5) * wide / across, y,
					z_from + (k + 0.5) * deep / along))
		var corners := PackedVector3Array([Vector3(x_from, y, z_from),
			Vector3(x_from + wide, y, z_from), Vector3(x_from + wide, y, z_from + deep),
			Vector3(x_from, y, z_from + deep)])
		_bridges.append({"child": child, "lower": lower, "upper": upper,
			"centre": Vector3(x_from + wide * 0.5, y, z_from + deep * 0.5),
			"normal": Vector3.UP if child == upper else Vector3.DOWN,
			"studs": studs, "corners": corners})


## A bridge whose studs point sideways or down, from where they stand
## ([param feet], LDU, pointing [param way]): its plane square to them
## through their feet, half a stud round them, and its normal toward
## [param child], as a stud joint lying flat has its normal up when what is
## on it is the part beyond.
static func _bridge_of_studs(child: int, lower: int, upper: int, feet: PackedVector3Array,
		way: Vector3) -> Dictionary:
	var normal: Vector3 = way.normalized()
	var u: Vector3 = normal.cross(Vector3.UP)
	if u.length() < 0.1:
		u = normal.cross(Vector3.RIGHT)
	u = u.normalized()
	var v: Vector3 = normal.cross(u).normalized()
	var origin: Vector3 = feet[0]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for foot: Vector3 in feet:
		var at := Vector2((foot - origin).dot(u), (foot - origin).dot(v))
		lo = lo.min(at)
		hi = hi.max(at)
	var half: float = BrickLattice.STUD * 0.5
	lo -= Vector2(half, half)
	hi += Vector2(half, half)
	var corners := PackedVector3Array([origin + u * lo.x + v * lo.y,
		origin + u * hi.x + v * lo.y, origin + u * hi.x + v * hi.y,
		origin + u * lo.x + v * hi.y])
	return {"child": child, "lower": lower, "upper": upper,
		"centre": origin + u * (lo.x + hi.x) * 0.5 + v * (lo.y + hi.y) * 0.5,
		"normal": normal if child == upper else -normal, "studs": feet, "corners": corners}


## Where a stud joint's studs are: the cells [param lower]'s boxes lifted one
## cell share with [param upper]'s, as [lowest corner, highest corner].
static func _overlap(lower: PackedInt32Array, upper: PackedInt32Array) -> Array:
	var lid: PackedInt32Array = BrickLattice.moved_by(lower, Vector3i(0, 1, 0))
	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	var hi := Vector3i(-0x7FFFFFFF, -0x7FFFFFFF, -0x7FFFFFFF)
	for i: int in range(0, lid.size(), 6):
		for j: int in range(0, upper.size(), 6):
			var x0: int = maxi(lid[i], upper[j])
			var x1: int = mini(lid[i + 3], upper[j + 3])
			var y0: int = maxi(lid[i + 1], upper[j + 1])
			var y1: int = mini(lid[i + 4], upper[j + 4])
			var z0: int = maxi(lid[i + 2], upper[j + 2])
			var z1: int = mini(lid[i + 5], upper[j + 5])
			if x1 <= x0 or y1 <= y0 or z1 <= z0:
				continue
			lo = Vector3i(mini(lo.x, x0), mini(lo.y, y0), mini(lo.z, z0))
			hi = Vector3i(maxi(hi.x, x1), maxi(hi.y, y1), maxi(hi.z, z1))
	return [lo, hi]


## Whether a pose puts a moving part through the floor.
func _through_floor(placed: Dictionary) -> bool:
	for id: Variant in placed:
		if not _index_of.has(int(id)):
			continue
		var n: int = _index_of[int(id)]
		var at: Transform3D = placed[id]
		if at.is_equal_approx(_rest[n]):
			continue
		# By its shape: a turned part's box hangs below it, and a wheel swung
		# round on its axle went through the floor by its box.
		if _meshes[n].lowest_at(at) < _floor_y - BrickLattice.PLATE * 0.5:
			return true
	return false


## The centre of mass and the margin in one pose, and each bridge's load,
## kept in [param worst_at] where it is the worst yet.
func _weigh(placed: Dictionary, label: String, worst_at: Dictionary) -> Dictionary:
	var count: int = _ids.size()
	var at: Array[Transform3D] = []
	at.resize(count)
	var sum_m := PackedFloat64Array()
	sum_m.resize(count + 1)
	var sum_x := PackedFloat64Array()
	sum_x.resize(count + 1)
	var sum_y := sum_x.duplicate()
	var sum_z := sum_x.duplicate()
	var total: float = 0.0
	var weighted := Vector3.ZERO
	for n: int in count:
		var here: Transform3D = placed.get(_ids[n], _rest[n])
		at[n] = here
		var middle: Vector3 = here * _middle[n]
		sum_m[n] = _mass[n]
		sum_x[n] = middle.x * _mass[n]
		sum_y[n] = middle.y * _mass[n]
		sum_z[n] = middle.z * _mass[n]
		total += _mass[n]
		weighted += middle * _mass[n]
	var centre: Vector3 = weighted / maxf(total, 0.000001)
	var flat := Vector2(centre.x, centre.z)
	var standing: Dictionary = _margin(flat)
	var height: float = maxf(centre.y - _floor_y, 1.0)
	var out: Dictionary = {"centre": centre, "flat": flat, "margin": standing["margin"],
		"edge": standing["edge"], "ends": standing["ends"], "label": label,
		"tilt": rad_to_deg(atan2(float(standing["margin"]), height))}

	# What hangs past each joint: everything under it in the tree.
	for k: int in range(_reached.size() - 1, -1, -1):
		var v: int = _reached[k]
		var p: int = _parent[v]
		if p >= 0 and p < count:
			sum_m[p] += sum_m[v]
			sum_x[p] += sum_x[v]
			sum_y[p] += sum_y[v]
			sum_z[p] += sum_z[v]
	for b: int in _bridges.size():
		var bridge: Dictionary = _bridges[b]
		var child: int = bridge["child"]
		var lower: int = bridge["lower"]
		var grams: float = sum_m[child]
		if grams <= 0.0:
			continue
		var carried := Vector3(sum_x[child], sum_y[child], sum_z[child]) / grams
		var moved: Transform3D = at[lower] * _rest[lower].affine_inverse()
		var one: JointLoad = _load(bridge, moved, grams, carried)
		one.pose = label
		var kept: JointLoad = worst_at.get(b)
		if kept == null or one.ratio > kept.ratio:
			worst_at[b] = one
	return out


## A joint's moment about the edge it would turn on, against what its studs
## hold there: M = Σ F·dᵢ.
func _load(bridge: Dictionary, moved: Transform3D, grams: float, carried: Vector3) -> JointLoad:
	var joint: Vector3 = moved * (bridge["centre"] as Vector3)
	var normal: Vector3 = (moved.basis * (bridge["normal"] as Vector3)).normalized()
	var studs: PackedVector3Array = bridge["studs"]
	var corners: PackedVector3Array = bridge["corners"]
	var weight: float = grams / 1000.0 * GRAVITY
	var force := Vector3(0.0, -weight, 0.0)
	# N·LDU about the joint's middle, the part of it that bends the joint
	# rather than twisting it, and how hard it presses the two together.
	var turning: Vector3 = (carried - joint).cross(force)
	var bending: Vector3 = turning - normal * turning.dot(normal)
	var pressed: float = -force.dot(normal)
	# The edge it would turn on: the way the far side tips, in the joint's
	# plane. Straight off, on the joint's narrower way, where it holds least.
	var way: Vector3
	if bending.length() > 0.000001:
		way = bending.cross(normal).normalized()
	else:
		var side_a: Vector3 = moved.basis * ((corners[1] as Vector3) - (corners[0] as Vector3))
		var side_b: Vector3 = moved.basis * ((corners[3] as Vector3) - (corners[0] as Vector3))
		way = (side_a if side_a.length() < side_b.length() else side_b).normalized()
	var reach: float = -INF
	for corner: Vector3 in corners:
		reach = maxf(reach, (moved * corner - joint).dot(way))
	var lever: float = 0.0
	for stud: Vector3 in studs:
		lever += reach - (moved * stud - joint).dot(way)
	var one := JointLoad.new()
	var lower: int = bridge["lower"]
	var upper: int = bridge["upper"]
	var child: int = bridge["child"]
	var held: int = lower if child == upper else upper
	one.beyond = _ids[child]
	one.held_by = _ids[held]
	one.beyond_part = _parts[child]
	one.held_part = _parts[held]
	one.studs = studs.size()
	one.grams = grams
	one.hangs = pressed < 0.0
	one.pull = maxf(-pressed, 0.0)
	var to_cm: float = MM_PER_LDU / 10.0
	one.moment = maxf(bending.length() - pressed * reach, 0.0) * to_cm
	one.capacity = ALLOWABLE_N * lever * to_cm
	one.ultimate = ULTIMATE_N * lever * to_cm
	one.ratio = one.moment / maxf(one.capacity, 0.000001)
	one.at = joint
	return one


## How far a point is inside the support polygon, LDU (negative past it),
## the nearest edge's name and its ends.
func _margin(point: Vector2) -> Dictionary:
	return Balance.margin_in(_hull, point)


static func margin_in(hull: PackedVector2Array, point: Vector2) -> Dictionary:
	var count: int = hull.size()
	var middle := Vector2.ZERO
	for corner: Vector2 in hull:
		middle += corner
	middle /= float(maxi(count, 1))
	var inside: bool = true
	var least: float = INF
	var nearest: int = 0
	var closest: float = INF
	var nearest_out: int = 0
	var touch := Vector2.ZERO
	for n: int in count:
		var a: Vector2 = hull[n]
		var b: Vector2 = hull[(n + 1) % count]
		var along: Vector2 = (b - a).normalized()
		var inward := Vector2(-along.y, along.x)
		if (middle - a).dot(inward) < 0.0:
			inward = -inward
		var depth: float = (point - a).dot(inward)
		if depth < 0.0:
			inside = false
		if depth < least:
			least = depth
			nearest = n
		var on: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
		var gap: float = on.distance_to(point)
		if gap < closest:
			closest = gap
			nearest_out = n
			touch = on
	if inside:
		var a: Vector2 = hull[nearest]
		var b: Vector2 = hull[(nearest + 1) % count]
		var along: Vector2 = (b - a).normalized()
		var outward := Vector2(along.y, -along.x)
		if (middle - a).dot(outward) > 0.0:
			outward = -outward
		return {"margin": least, "edge": Balance.edge_name(outward),
			"ends": PackedVector2Array([a, b]), "way": outward}
	var away: Vector2 = point - touch
	return {"margin": -closest, "edge": Balance.edge_name(away),
		"ends": PackedVector2Array([hull[nearest_out], hull[(nearest_out + 1) % count]]),
		"way": away.normalized()}


## The counterweight that brings every pose SPARE studs inside, and how far
## the base would have to grow instead.
func _advise(report: Report, weighed: Array, worst: Dictionary) -> void:
	var spare: float = SPARE * BrickLattice.STUD
	var standing: Dictionary = _margin(worst["flat"])
	var way: Vector2 = standing["way"]
	report.widen = maxi(1, ceili((spare - float(worst["margin"])) / BrickLattice.STUD))
	report.widen_toward = report.edge
	# Two places to try: within 2·WEIGHT_IN studs of the far edge, straight
	# back from the edge it tips over; and the middle of the base, which is
	# better when the poses tip more than one way.
	var middle := Vector2.ZERO
	for corner: Vector2 in _hull:
		middle += corner
	middle /= float(_hull.size())
	var places: Array = [[middle, "in the middle of the base"]]
	var exit: float = _exit(middle, -way)
	if exit > WEIGHT_IN * BrickLattice.STUD:
		places.push_front([middle - way * (exit - WEIGHT_IN * BrickLattice.STUD),
			"within %s studs of the %s edge" % [Balance.studs(WEIGHT_IN * 2.0),
				Balance.opposite(report.edge)]])
	var best: float = INF
	for place: Array in places:
		var w: float = _counterweight(weighed, place[0], spare)
		if w < best:
			best = w
			report.counterweight = w
			report.counterweight_at = place[0]
			report.counterweight_where = place[1]
	if best == INF:
		report.counterweight = 0.0


## How far from [param from] along [param way] the support polygon ends.
func _exit(from: Vector2, way: Vector2) -> float:
	var furthest: float = 0.0
	var count: int = _hull.size()
	for n: int in count:
		var hit: Variant = Geometry2D.segment_intersects_segment(from,
			from + way * 1000000.0, _hull[n], _hull[(n + 1) % count])
		if hit != null:
			furthest = maxf(furthest, from.distance_to(hit as Vector2))
	return furthest


## The least weight at [param place] that brings every pose [param spare]
## inside, g; INF when none would.
func _counterweight(weighed: Array, place: Vector2, spare: float) -> float:
	if float(_margin(place)["margin"]) < spare:
		return INF
	var total: float = 0.0
	for m: float in _mass:
		total += m
	var holds := func(w: float) -> bool:
		for pose: Dictionary in weighed:
			var flat: Vector2 = (pose["flat"] as Vector2 * total + place * w) / (total + w)
			if float(_margin(flat)["margin"]) < spare:
				return false
		return true
	var high: float = 1.0
	while not holds.call(high):
		high *= 2.0
		if high > 10000000.0:
			return INF
	var low: float = 0.0
	for _n: int in 40:
		var mid: float = (low + high) * 0.5
		if holds.call(mid):
			high = mid
		else:
			low = mid
	return high
