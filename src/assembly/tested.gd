## Whether a shared model can be built as its steps say: the "Tested" mark
## (2026-10-18), worked out by the app as the model is published, where the
## model and the library are. The server cannot run any of it, so it keeps
## what the app found, as the app's finding, with the app's version
## (api/share.js, supabase/tested.sql).
##
## Paid fan instructions elsewhere are often untested virtual models, and a
## builder finds out when the build falls apart. Four tests, each passed or
## failed with its reason:
##
##   stands  the model holds together at every step of the steps the share
##           carries, set down on a table: each step's build so far weighed
##           as the build check weighs it (Balance), and no stud joint past
##           where it lets go. A build that tips over is not held against
##           it: it is let fall as one rigid thing onto a second and a third
##           contact until it rests (Topple.fall), as a builder lays a
##           Technic chassis on its side or a boat on its keel, and weighed
##           as it lies there. It fails where a joint gives as it lies, or
##           where it never comes to rest. Weighed standing upright on its
##           lowest parts, 9 of the gallery's 30 real sets failed 102 times,
##           42022-1 on one tyre from step 4 to 37, 851-1 on two crown gears
##           and 5521-1 on its keel (tested305). A sub-assembly built in the
##           hand is weighed once it is on the model, and an author's
##           sub-model once it is built.
##   steps   every part of a step can be put where the step puts it, and
##           seen there. At the end of its step each new thing is held to
##           something that stands (the steps score's "floating",
##           src/dev/steps_score.gd: on the model, what is on its lowest
##           point, its first parts and the first parts of each piece a step
##           begins; in the hand, the sub-assembly's first parts; and
##           anywhere the first parts of each of the author's sub-models,
##           which may be built in the hand). Parts put down in the air and
##           held to each other there, two or more, until a later step holds
##           them are a sub-assembly built in the hand, as a callout is that
##           a modeller drew where it goes; one part alone, or a sub-assembly
##           put on where nothing holds it, is put down in the air
##           (Steps._held_up). And a real booklet could show it: drawn by the
##           parts' own shapes (their covers), a tenth of it is in sight from
##           the front, the back or either side, or from any of those with
##           the model turned over, past everything earlier steps built in
##           front of it, of its sub-model's own until that is built (Sight);
##           a see-through part hides nothing. A part buried inside, which no
##           view shows, is hidden. Judged by boxes from the front and the
##           back alone, the gallery's 30 real sets failed it 230 times, 148
##           of them hidden: bogies under a train, plates under a wing, a part
##           under a turned part's box; and 43 parts of 5891-1's flattened
##           callouts were put down in the air (tested306).
##   parts   every part is a real element in its colour, as the catalogue's
##           colour availability knows it (PartInfo.never_made_in): none in a
##           colour it was never made in, none made here, none in a colour
##           typed in rather than one parts are made in. A part the catalogue
##           has no colours for is not held against it, and is counted.
##   whole   every part held, none through another, by the parts' exact
##           shapes as the design check reads them (ExactCheck):
##           no two parts' real shapes overlap by more than 1 LDU, past what
##           a joint's own parts do and gears in mesh (ExactCheck.forgiven);
##           each part is joined to the rest by BrickNet's connections (a
##           stud in its hole, a pin, an axle, a clip, a hinge, a ball), by
##           a joint other than a stud the app reads itself (Joints: a pin, an
##           axle, a bar in a clip, a ball, as Mechanism and the build check
##           read them: of the gallery's 30 real sets' pieces held by
##           nothing, 34 were held so, flowers on their stems, plumes,
##           torches and bows in hands, gates on their hinges, tested301), by
##           glue, magnets or being one flexible thing (Joints.held_otherwise),
##           or, standing where it is, caught there so it cannot slide out
##           (ExactCheck.comes_away). A piece on the floor that stands by
##           itself and touches no bigger piece is a build of its own (a
##           set's figures beside its car); one that leans, or stands
##           against or inside a bigger one, is not held. A part with no
##           exact shape is held as the joints and what rests on what hold
##           it, as before.
##           models175 found the test before this held a part whenever it
##           touched a held one and never asked about collisions: Orthanc,
##           145 pairs through each other and 72 pieces, could have passed.
##
## A part the finished model does not hold is the whole test's, and is not
## held against its step too, as the steps score leaves it out.
##
## Paced ([method check]): a slice a frame, so the share panel is never held.
class_name Tested
extends RefCounted

const VERSION := 1
## A new thing shows at least this much of itself, from one way a booklet
## looks at a step (Sight.VIEWS): the steps score's SEEN, the planner's
## Pictures.SEEN.
const SEEN := 0.1
## How many failures each test names before it says how many more.
const NAMED := 3
## How much of a test's reason the site keeps (api/_tested.js MOST_WHY).
const MOST_WHY := 300
## How long the tests may take before the model goes untested, ms: a
## 2,042-part set takes about 2.2 s here. A bigger model may take longer
## ([method most_ms]): before its first step is built, the Wizard's Tower's
## 10,101 parts take 7.5 s to read what holds what and their exact shapes,
## and each step that adds to one of its piers, columns held to each other
## by what rests on what, weighs that pier again: 568 steps, about 90 s
## (orthsteps212).
const MOST_MS := 15000
## ...the parts past which it may, and how much longer for each.
const MOST_MS_FROM := 2000
const MS_A_PART := 15
## LDraw's direct colours, 0x2RRGGBB: a colour typed in, not one parts are made in.
const DIRECT_FROM := 0x2000000


## Where the last [method check]'s time went, in microseconds, for a probe.
static var laps: Dictionary = {}
## Every failure the last [method check] found, in full, by test: its
## finding names the first [constant NAMED] of each. For a probe.
static var said_all: Dictionary = {}


## A build's parts joined as they go in: the main build, or a sub-assembly
## in the hand. Which part each is joined to, and whether its piece stands.
class Pile extends RefCounted:
	var placed: Dictionary = {}       ## id -> true
	var _parent: Dictionary = {}      ## id -> id
	var _stands: Dictionary = {}      ## root id -> true
	var begun: bool = false
	var lowest: int = 0x7FFFFFFF
	## Things put down in the air and not yet held to what stands: [step
	## number, thing, its root as the last step left it] ([method Steps.take]).
	var aloft: Array = []

	func root(id: int) -> int:
		var at: int = id
		while int(_parent.get(at, at)) != at:
			var up: int = int(_parent[at])
			_parent[at] = int(_parent.get(up, up))
			at = up
		return at

	func put(id: int) -> void:
		placed[id] = true
		_parent[id] = id

	func join(a: int, b: int) -> void:
		var ra: int = root(a)
		var rb: int = root(b)
		if ra == rb:
			return
		_parent[rb] = ra
		if _stands.has(rb):
			_stands[ra] = true
			_stands.erase(rb)

	func stand(id: int) -> void:
		_stands[root(id)] = true

	func stands(id: int) -> bool:
		return _stands.has(root(id))


## The build so far weighed at each step as Balance weighs it, without
## weighing again what already stands fast. Weighed whole, each of the
## Wizard's Tower's 1,420 steps read its build afresh, 0.6 s a step at its
## end and ten minutes in all, and a share's time ran out at step 340
## (orthsteps212). What stands fast is the core: the parts held to the floor
## two ways or more by what always holds them (Balance.core), weighed from
## then on as the floor is (Balance.rigid), since no joint inside it is a
## bridge and a bridge outside it carries what it would in the whole build.
## And once weighed, each piece hanging off the core is settled: it carries
## what it carried, and is weighed no more until a part put in joins or
## touches it. A piece with a joint that gave stays, and is said again at
## each step, as weighing the whole build said it. The margin is the whole
## build's, kept as each step adds to it. A build that tips is weighed whole
## again where it comes to rest ([method settle]).
class Weighing extends RefCounted:
	## At most this many falls, one edge after another, to where a build
	## that tips comes to rest (Topple.MOST is a dragged part's): 8862-1's
	## grader settles at its step 14 in 22 falls of a degree or less, onto
	## one part after another just above the floor.
	const FALLS := 32
	## What Stability.stud_joints says of a pair, each by its kind.
	const KINDS: Array[String] = ["studs", "under", "sideways", "seated", "overlapped", "pivots",
		"beside", "resting"]
	var library: PartLibrary
	var lattice: BrickLattice
	var contacts: Dictionary
	var by_id: Dictionary
	var overlaps: Dictionary = {}
	var known: Dictionary = {}
	## Every part each is joined to or touches in the finished model, as
	## Balance reads them: studs, seated, pins and the rest (links).
	var _adjacent: Dictionary = {}     ## id -> Array of ids
	var _keys: Dictionary = {}         ## id -> Array of its pairs' keys in the joints
	## Each pair's entries in the joints, [kind, value, ...]: looked up once
	## here, not in all eight kinds each time the pair is weighed.
	var _entries: Dictionary = {}      ## key -> Array
	var _links: Dictionary = {}        ## id -> Array of [a, b]
	var _joints: Dictionary = {}
	var placed: Dictionary = {}
	var core: Dictionary = {}
	## Put in, not in the core, not settled: what each step weighs.
	var loose: Dictionary = {}
	## Settled: id -> the piece it was settled in, its ids.
	var settled: Dictionary = {}
	var _lowest: int = 0x7FFFFFFF
	var _points := PackedVector2Array()
	var _hull := PackedVector2Array()
	var _grams: float = 0.0
	var _weighted := Vector3.ZERO
	## The corners of each weighed part's box, by id: how the build falls
	## where it tips. Eight a part, not every corner of each part's cover a
	## dragged part falls on (Topple.corners_of): fewer to turn at each fall.
	var _corners: Dictionary = {}       ## id -> PackedVector3Array
	var _all_links: Array = []
	## As it last lay where it tipped: the parts held two ways or more to the
	## floor, and every part it lay on.
	var _lying_core: Dictionary = {}
	var _lying_on: Dictionary = {}

	func _init(given_library: PartLibrary, given_lattice: BrickLattice, given: Dictionary,
			bricks: Dictionary, links: Array) -> void:
		library = given_library
		lattice = given_lattice
		contacts = given
		by_id = bricks
		_all_links = links
		_joints = Stability.stud_joints(contacts, library, lattice)
		Stability.beside(contacts, library, lattice)
		for id: int in by_id:
			_adjacent[id] = []
			_keys[id] = []
			_links[id] = []
		for kind: String in ["studs", "seated"]:
			for key: int in (_joints[kind] as Dictionary):
				var a: int = key >> 32
				var b: int = key & 0xFFFFFFFF
				if not by_id.has(a) or not by_id.has(b) or _entries.has(key):
					continue
				var entries: Array = []
				for each: String in KINDS:
					var from: Dictionary = _joints[each]
					if from.has(key):
						entries.append_array([each, from[key]])
				_entries[key] = entries
				(_keys[a] as Array).append(key)
				(_keys[b] as Array).append(key)
				(_adjacent[a] as Array).append(b)
				(_adjacent[b] as Array).append(a)
		for pair: Array in links:
			var a: int = pair[0]
			var b: int = pair[1]
			if not by_id.has(a) or not by_id.has(b):
				continue
			(_links[a] as Array).append(pair)
			(_links[b] as Array).append(pair)
			(_adjacent[a] as Array).append(b)
			(_adjacent[b] as Array).append(a)

	## [param ids] put in: {"empty": nothing to stand on yet, "margin": studs
	## inside the edge it would tip over, "edge", "joints": the stud joints
	## that carry what is past them, as Balance.Report.joints}.
	func add(ids: Array[int]) -> Dictionary:
		var boxes: Dictionary = contacts["boxes"]
		var lower: bool = false
		for id: int in ids:
			placed[id] = true
			loose[id] = true
			for other: int in (_adjacent[id] as Array):
				var piece: Variant = settled.get(other)
				if piece != null:
					for one: int in (piece as Array):
						settled.erase(one)
						loose[one] = true
			var brick: BrickWorld.Brick = by_id[id]
			var it: Array = known.get(id, [])
			if it.is_empty() or it[0] != brick.part_id:
				var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
				var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
				if info == null or part == null:
					continue
				it = [brick.part_id, Stability.grams(info), part.bounds.get_center(), part,
					Assemblies.path_of(brick), info.stud_count > 0]
				known[id] = it
			var middle: Vector3 = brick.transform * (it[2] as Vector3)
			_grams += float(it[1])
			_weighted += middle * float(it[1])
			var bounds: AABB = (it[3] as Lbm.PartMesh).bounds
			var corners := PackedVector3Array()
			for corner: int in 8:
				corners.append(brick.transform * bounds.get_endpoint(corner))
			_corners[id] = corners
			var packed: PackedInt32Array = boxes.get(id, PackedInt32Array())
			for at: int in range(0, packed.size(), 6):
				if packed[at + 1] < _lowest:
					_lowest = packed[at + 1]
					lower = true
		# A new lowest point is a new floor: what stands on it is read again.
		if lower:
			_points.clear()
			core.clear()
			settled.clear()
			for id: int in placed:
				loose[id] = true
				_add_points(boxes.get(id, PackedInt32Array()))
		else:
			for id: int in ids:
				_add_points(boxes.get(id, PackedInt32Array()))
		var out: Dictionary = {"empty": _hull.size() < 3, "margin": 0.0, "edge": "", "joints": []}
		if out["empty"]:
			return out
		var centre: Vector3 = _weighted / maxf(_grams, 0.000001)
		var standing: Dictionary = Balance.margin_in(_hull, Vector2(centre.x, centre.z))
		out["margin"] = float(standing["margin"]) / BrickLattice.STUD
		out["edge"] = standing["edge"]

		# The loose parts, and the parts of the core they are joined to.
		var rigid: Dictionary = {}
		for id: int in loose:
			for other: int in (_adjacent[id] as Array):
				if core.has(other):
					rigid[other] = true
		var bricks: Array = []
		var weighed: Dictionary = {}
		for id: int in loose:
			bricks.append(by_id[id])
			weighed[id] = true
		for id: int in rigid:
			bricks.append(by_id[id])
			weighed[id] = true
		var joints: Dictionary = {}
		for kind: String in KINDS:
			joints[kind] = {}
		var links: Array = []
		var taken: Dictionary = {}
		for id: int in loose:
			for key: int in (_keys[id] as Array):
				if taken.has(key):
					continue
				var other: int = (key >> 32) if (key & 0xFFFFFFFF) == id else (key & 0xFFFFFFFF)
				if not weighed.has(other):
					continue
				taken[key] = true
				var entries: Array = _entries[key]
				for at: int in range(0, entries.size(), 2):
					(joints[entries[at]] as Dictionary)[key] = entries[at + 1]
			for pair: Array in (_links[id] as Array):
				if weighed.has(int(pair[0])) and weighed.has(int(pair[1])):
					links.append(pair)
		joints["beside read"] = true
		var balance := Balance.new()
		balance.library = library
		balance.lattice = lattice
		balance.overlaps = overlaps
		balance.known = known
		balance.rigid = rigid
		balance.floor_cell = _lowest
		balance.finds_core = true
		var report: Balance.Report = balance.measure(bricks, [], links,
			{"boxes": boxes, "joints": joints})
		out["joints"] = report.joints
		for id: Variant in balance.core:
			core[id] = true
			loose.erase(id)
		# What hangs off the core, settled, but for a piece where a joint gave.
		var gave: Dictionary = {}
		for one: Balance.JointLoad in report.joints:
			if one.moment > one.ultimate:
				gave[one.beyond] = true
				gave[one.held_by] = true
		_settle(gave)
		return out

	## The build so far, which tips, let fall as a rigid body until it rests
	## (Topple.fall), as a real one settles on a table: a Technic chassis on
	## its side, a boat on its keel. Then weighed whole as it lies there, on
	## what touches the floor: {"fell": Topple.fall, "gave": the first stud
	## joint past where it lets go as it lies, or null}.
	func settle() -> Dictionary:
		var points := PackedVector3Array()
		for id: int in _corners:
			points.append_array(_corners[id])
		var centre: Vector3 = _weighted / maxf(_grams, 0.000001)
		var fell: Dictionary = Topple.fall(points, centre, _lowest * BrickLattice.CELL, FALLS)
		return {"fell": fell, "gave": _lying(fell["turn"])}

	## The build so far turned by [param turn] and weighed on what then
	## touches the floor, within half a plate of the lowest of it: the first
	## stud joint past where it lets go, or null. What was held to the floor
	## two ways or more as it last lay is weighed as the floor (Balance.rigid)
	## while it lies on all it lay on then, as the core is standing. Weighed
	## whole at each of the 46 steps it tips at, 42029-1 spent 1.4 s of its 9
	## lying; weighed so, 0.4 s.
	func _lying(turn: Transform3D) -> Balance.JointLoad:
		var lowest: float = INF
		for id: int in _corners:
			for p: Vector3 in (_corners[id] as PackedVector3Array):
				lowest = minf(lowest, (turn * p).y)
		var grounded: Dictionary = {}
		for id: int in _corners:
			for p: Vector3 in (_corners[id] as PackedVector3Array):
				if (turn * p).y <= lowest + BrickLattice.PLATE * 0.5:
					grounded[id] = true
					break
		if not _lying_on.keys().all(func(id: int) -> bool: return grounded.has(id)):
			_lying_core.clear()
		var rigid: Dictionary = {}
		var bricks: Array = []
		for id: int in _corners:
			if _lying_core.has(id):
				continue
			bricks.append(by_id[id])
			for other: int in (_adjacent[id] as Array):
				if _lying_core.has(other) and not rigid.has(other):
					rigid[other] = true
					bricks.append(by_id[other])
		var on: Dictionary = {}
		var placed_at: Dictionary = {}
		for brick: BrickWorld.Brick in bricks:
			placed_at[brick.id] = turn * brick.transform
			if grounded.has(brick.id):
				on[brick.id] = true
		var balance := Balance.new()
		balance.library = library
		balance.lattice = lattice
		balance.overlaps = overlaps
		balance.known = known
		balance.rigid = rigid
		balance.finds_core = true
		balance.floor_cell = _lowest
		balance.support = {"hull": PackedVector2Array(), "floor_y": lowest, "grounded": on}
		if not balance.prepare(bricks, _all_links, contacts):
			return null
		_lying_core.merge(balance.core)
		_lying_on = grounded
		for one: Balance.JointLoad in balance.weigh_pose(placed_at).joints:
			if one.moment > one.ultimate:
				return one
		return null

	func _add_points(packed: PackedInt32Array) -> void:
		var more: bool = false
		for at: int in range(0, packed.size(), 6):
			if packed[at + 1] > _lowest + Balance.ON_FLOOR:
				continue
			var x0: float = packed[at] * BrickLattice.CELL
			var z0: float = packed[at + 2] * BrickLattice.CELL
			var x1: float = packed[at + 3] * BrickLattice.CELL
			var z1: float = packed[at + 5] * BrickLattice.CELL
			_points.append_array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1),
				Vector2(x0, z1)])
			more = true
		if more:
			_hull = Geometry2D.convex_hull(_points)
			if _hull.size() > 1 and _hull[0].is_equal_approx(_hull[_hull.size() - 1]):
				_hull.resize(_hull.size() - 1)

	## Each piece of the loose parts settled, but one with a part of [param
	## gave] in it.
	func _settle(gave: Dictionary) -> void:
		var seen: Dictionary = {}
		for start: int in loose.keys():
			if seen.has(start):
				continue
			var piece: Array[int] = [start]
			seen[start] = true
			var keep: bool = false
			var k: int = 0
			while k < piece.size():
				var here: int = piece[k]
				k += 1
				keep = keep or gave.has(here)
				for other: int in (_adjacent[here] as Array):
					if loose.has(other) and not seen.has(other):
						seen[other] = true
						piece.append(other)
			if keep:
				continue
			for id: int in piece:
				loose.erase(id)
				settled[id] = piece


## A part as a step's pictures draw it: its box where it stands, and its
## cover, the boxes the build check reads it by, which follow its shape to
## within a cell (Lbm.PartMesh.boxes), its box alone for a part with none.
## Drawn from a view the first time that view is asked about.
class Seen extends RefCounted:
	var id: int = 0
	var box := AABB()
	var at := Transform3D.IDENTITY
	var cover: Array[AABB] = []
	## The size of a cell of [member cover], LDU.
	var cell: float = 1.0
	## In a see-through colour: drawn so in a booklet, it hides nothing.
	var clear: bool = false
	var _drawn: Array = []             ## per view: {pixel: depth}, null till drawn
	var _spans: Array = []             ## per view: [Rect2, Vector2(furthest, nearest)]

	## Where its box lands in [param frame]'s picture ([member Sight.frames]),
	## in pixels, and how near the eye it comes, furthest and nearest.
	func span(v: int, frame: Array) -> Array:
		if _spans.is_empty():
			_spans.resize(Sight.VIEWS.size())
		var known: Variant = _spans[v]
		if known != null:
			return known
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var depth := Vector2(INF, -INF)
		for corner: int in 8:
			var point: Vector3 = box.get_endpoint(corner)
			var flat := Vector2(point.dot(frame[1]), point.dot(frame[2])) / Sight.PIXEL
			low = low.min(flat)
			high = high.max(flat)
			var d: float = point.dot(frame[0])
			depth = Vector2(minf(depth.x, d), maxf(depth.y, d))
		var out: Array = [Rect2(low, high - low), depth]
		_spans[v] = out
		return out

	## Its pixels in [param frame]'s picture, {pixel: how near the eye}: each
	## pixel whose middle's line of sight meets a box of its cover, and how
	## near the eye it first does. Each box is read in the part's own frame,
	## where it is square, along the line of sight brought into that frame.
	func drawn(v: int, frame: Array) -> Dictionary:
		if _drawn.is_empty():
			_drawn.resize(Sight.VIEWS.size())
		var known: Variant = _drawn[v]
		if known != null:
			return known
		var view: Vector3 = frame[0]
		var right: Vector3 = frame[1]
		var up: Vector3 = frame[2]
		var inverse: Transform3D = at.affine_inverse()
		var across: Vector3 = inverse.basis * right * Sight.PIXEL
		var along: Vector3 = inverse.basis * up * Sight.PIXEL
		var sight: Vector3 = inverse.basis * view
		var out: Dictionary = {}
		for one: AABB in cover:
			var lo: Vector3 = one.position * cell
			var hi: Vector3 = one.end * cell
			var low := Vector2(INF, INF)
			var high := Vector2(-INF, -INF)
			for corner: int in 8:
				var point: Vector3 = at * AABB(lo, hi - lo).get_endpoint(corner)
				var flat := Vector2(point.dot(right), point.dot(up)) / Sight.PIXEL
				low = low.min(flat)
				high = high.max(flat)
			for x: int in range(ceili(low.x - 0.5), floori(high.x - 0.5) + 1):
				var column: Vector3 = inverse.origin + across * (x + 0.5)
				for y: int in range(ceili(low.y - 0.5), floori(high.y - 0.5) + 1):
					var from: Vector3 = column + along * (y + 0.5)
					var enters: float = -INF
					var leaves: float = INF
					var meets: bool = true
					for k: int in 3:
						if absf(sight[k]) < 0.000001:
							if from[k] < lo[k] or from[k] > hi[k]:
								meets = false
								break
							continue
						var a: float = (lo[k] - from[k]) / sight[k]
						var b: float = (hi[k] - from[k]) / sight[k]
						enters = maxf(enters, minf(a, b))
						leaves = minf(leaves, maxf(a, b))
					if not meets or enters > leaves:
						continue
					var pixel: int = (x << 24) + y
					if leaves > float(out.get(pixel, -INF)):
						out[pixel] = leaves
		_drawn[v] = out
		return out


## What a booklet's pictures of a step show of a new thing: each part drawn
## by its own shape (Seen), from each way a booklet looks at a step, with
## everything earlier steps built along the line of sight in front of it.
## The planner's own pictures count only what is within a stud and a bit
## (Instructions.Pictures.IN_FRONT), where two views are enough; from eight,
## a brick shut in a box after its roof showed through the gap to the far
## walls.
class Sight extends RefCounted:
	## The ways a booklet looks at a step, towards the eye: from the front and
	## the back, as the app's booklet draws them (BookletStudio.FRONT, BACK),
	## and from either side, the model turned a quarter; and each again from
	## below, the model turned over to build its underside.
	const VIEWS: Array[Vector3] = [BookletStudio.FRONT, BookletStudio.BACK,
		Vector3(1.0, 0.68, -0.62), Vector3(-1.0, 0.68, 0.62),
		Vector3(0.62, -0.68, 1.0), Vector3(-0.62, -0.68, -1.0),
		Vector3(1.0, -0.68, -0.62), Vector3(-1.0, -0.68, 0.62)]
	## A booklet's picture is a few hundred pixels across; a stud is 20 LDU.
	const PIXEL := Instructions.Pictures.PIXEL
	const CELL := Instructions.Pictures.CELL
	## Each view's [toward the eye, right, up].
	var frames: Array = []
	var _built: Dictionary = {}        ## Vector3i -> the parts of earlier steps there
	var _bounds := AABB()              ## round all of them

	func _init() -> void:
		for view: Vector3 in VIEWS:
			var ahead: Vector3 = view.normalized()
			var right: Vector3 = Vector3.UP.cross(ahead).normalized()
			frames.append([ahead, right, ahead.cross(right).normalized()])

	## A step is done: [param step]'s parts may stand in front of the next
	## steps', but for those a booklet draws see-through.
	func built(step: Array) -> void:
		for seen: Seen in step:
			if seen.clear:
				continue
			_bounds = seen.box if _built.is_empty() else _bounds.merge(seen.box)
			for key: Vector3i in Instructions.Pictures._cells_of(seen.box):
				if not _built.has(key):
					_built[key] = []
				(_built[key] as Array).append(seen)

	## How far past [param box], toward the eye of view [param v], what is
	## built reaches.
	func _reach(box: AABB, v: int) -> float:
		var way: Vector3 = frames[v][0]
		var reach: float = -INF
		for corner: int in 8:
			reach = maxf(reach, (_bounds.get_endpoint(corner) - box.get_center()).dot(way))
		return reach

	## The parts of earlier steps in the cells the line of sight from [param
	## box] to the eye of view [param v] passes through, into [param out], the
	## nearest it first.
	func _ahead(box: AABB, v: int, out: Dictionary) -> void:
		var way: Vector3 = frames[v][0] * (0.5 * CELL)
		var at: AABB = box
		var passed: Dictionary = {}
		for k: int in ceili(maxf(0.0, _reach(box, v)) / (0.5 * CELL)) + 1:
			for key: Vector3i in Instructions.Pictures._cells_of(at):
				if passed.has(key):
					continue
				passed[key] = true
				for other: Seen in _built.get(key, []):
					out[other.id] = other
			at.position += way

	## Whether [param thing], its parts each a Seen, shows less than a tenth
	## of itself from every view, with what earlier steps built in front of
	## it. A view with nothing in front shows it whole; a thing too small for
	## a pixel is not judged. The views are asked the shortest way out of
	## what is built first, and each drawn before the next is asked: a part
	## on the back wall is in sight from the back, and the line of sight
	## from the front through the whole model, asked of every view first,
	## made 10218-1's tests take a third longer.
	func hides(thing: Array) -> bool:
		if _built.is_empty():
			return false
		var own: Dictionary = {}
		for seen: Seen in thing:
			own[seen.id] = true
		var order: Array = []
		for v: int in frames.size():
			var reach: float = -INF
			for seen: Seen in thing:
				reach = maxf(reach, _reach(seen.box, v))
			order.append([reach, v])
		order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for one: Array in order:
			var v: int = one[1]
			# In front of it, by the boxes: no part's shape is drawn for a
			# view something leaves bare.
			var ahead: Dictionary = {}
			for seen: Seen in thing:
				_ahead(seen.box, v, ahead)
			var there: Array = []
			for other: Seen in ahead.values():
				if own.has(other.id):
					continue
				var theirs: Array = other.span(v, frames[v])
				for seen: Seen in thing:
					var span: Array = seen.span(v, frames[v])
					if (theirs[0] as Rect2).intersects(span[0]) \
							and (theirs[1] as Vector2).y > (span[1] as Vector2).x:
						there.append(other)
						break
			if there.is_empty():
				return false
			var mine: Dictionary = {}
			for seen: Seen in thing:
				var drawn: Dictionary = seen.drawn(v, frames[v])
				for pixel: int in drawn:
					mine[pixel] = maxf(float(mine.get(pixel, -INF)), float(drawn[pixel]))
			if mine.is_empty():
				return false
			var open: Dictionary = mine.duplicate()
			for other: Seen in there:
				if float(open.size()) < SEEN * float(mine.size()):
					break
				Instructions.Pictures._cover(open, other.drawn(v, frames[v]))
			if float(open.size()) >= SEEN * float(mine.size()):
				return false
		return true


## The steps test as a build goes in, a step at a time: what each step puts
## down in the air, and what it puts behind what is already built, by the
## booklet's own rules (the "steps" test). The worked-out steps are put
## right by asking it first what would stand ([method stands_if]) and then
## building with it as the test does (HeldSteps).
##
## An author's sub-model may be built in the hand, as a callout is: the
## parts of its first step stand, held in the hand, and what goes onto them
## stands with them; and each is in sight with what its own earlier steps
## built, not the rest of the model, until it is built. The booklet shows
## them where they will go. An LDraw file's sub-model is the booklet's
## sub-assembly, built on the side or where it goes. Built only where it
## goes, 6043-1's dragon head, begun above the trebuchet that later holds
## it, put 60 parts down in the air, 928-1's pilot sat down in its cockpit a
## part at a time, each hidden by the ship, and the gallery's 30 real sets
## failed the steps test 22 times (tested301).
class Steps extends RefCounted:
	var by_id: Dictionary
	var near: Dictionary
	var bottom: Dictionary
	var piece: Dictionary
	var joined: Dictionary
	var library: PartLibrary
	var main := Pile.new()
	var side: Dictionary = {}          ## callout -> Pile
	var _main_pictures := Sight.new()
	var _side_pictures: Dictionary = {} ## callout -> Sight
	## The author's sub-models begun, by path: true for one begun in the
	## hand, whose first parts stood on nothing that stands.
	var _begun_sections: Dictionary = {}
	## Those being built, by path: the pictures of what each has built, the
	## parts it has, and the pictures it goes into when it is built (its
	## build's: the model's or its callout's).
	var _section_pictures: Dictionary = {}
	var _section_nodes: Dictionary = {}
	var _section_onto: Dictionary = {}
	## id -> Seen, made as they are asked for ([method Tested._node]).
	var nodes: Dictionary = {}
	var _begun_pieces: Dictionary = {}
	var floating: Array = []           ## [step number, id]
	var hidden: Array = []
	var hidden_us: int = 0

	## [param holding] is [method holds]'s, of the parts [param bricks_by_id].
	func _init(bricks_by_id: Dictionary, holding: Dictionary, given_library: PartLibrary) -> void:
		by_id = bricks_by_id
		near = holding["near"]
		bottom = holding["bottom"]
		piece = holding["piece"]
		joined = holding["joined"]
		library = given_library

	## What [param step] puts down, each thing a PackedInt64Array of ids: in
	## the hand each part of the copy its pictures show; on the model each
	## copy of a sub-assembly it puts on, then each part.
	func things_of(step: Instructions.Step) -> Array:
		var things: Array = []
		if step.in_callout():
			for id: int in (step.shown_ids if not step.shown_ids.is_empty() else step.brick_ids):
				if by_id.has(id):
					things.append(PackedInt64Array([id]))
			return things
		things = copies_of(step)
		for id: int in step.brick_ids:
			if by_id.has(id):
				things.append(PackedInt64Array([id]))
		return things

	## The copies of a sub-assembly [param step] puts on the model, each a thing.
	func copies_of(step: Instructions.Step) -> Array:
		var things: Array = []
		for copy: PackedInt64Array in step.copies:
			var mine := PackedInt64Array()
			for id: int in copy:
				if by_id.has(id):
					mine.append(id)
			if not mine.is_empty():
				things.append(mine)
		return things

	## The build [param step] goes into: the model's, or its sub-assembly's in the hand.
	func pile_of(step: Instructions.Step) -> Pile:
		if not step.in_callout():
			return main
		if not side.has(step.callout):
			side[step.callout] = Pile.new()
			_side_pictures[step.callout] = Sight.new()
		return side[step.callout]

	## Which of [param things], put down as [param step]'s, would stand were
	## they put down now, by the rules [method take] judges them by: true for
	## each that would, and for each the finished model does not hold, whose
	## fault is the whole test's. Nothing is put down. One that would stand
	## stands as well with those that would not left out: each that stands is
	## held through parts that stand.
	func stands_if(step: Instructions.Step, things: Array) -> Array[bool]:
		var in_hand: bool = step.in_callout()
		var pile: Pile = pile_of(step)
		var fresh: Dictionary = {}
		var lowest: int = pile.lowest
		for thing: PackedInt64Array in things:
			for id: int in thing:
				if not pile.placed.has(id):
					fresh[id] = true
					lowest = mini(lowest, int(bottom[id]))
		var stood: Dictionary = {}
		var queue: Array[int] = []
		for id: int in fresh:
			var stands: bool = not pile.begun or not in_hand and int(bottom[id]) <= lowest + Balance.ON_FLOOR
			if not stands:
				for other: int in (near[id] as Dictionary):
					if pile.placed.has(other) and pile.stands(other):
						stands = true
						break
			if stands:
				stood[id] = true
				queue.append(id)
		if not in_hand:
			var begun: Dictionary = {}
			for thing: PackedInt64Array in things:
				var which: int = int(piece[thing[0]])
				if not _begun_pieces.has(which) and not begun.has(which):
					begun[which] = true
					if fresh.has(thing[0]) and not stood.has(thing[0]):
						stood[thing[0]] = true
						queue.append(thing[0])
		while not queue.is_empty():
			var here: int = queue.pop_back()
			for other: int in (near[here] as Dictionary):
				if fresh.has(other) and not stood.has(other):
					stood[other] = true
					queue.append(other)
		var out: Array[bool] = []
		for thing: PackedInt64Array in things:
			var stands: bool = not joined.has(thing[0])
			for id: int in thing:
				if stood.has(id) or pile.placed.has(id) and pile.stands(id):
					stands = true
					break
			out.append(stands)
		return out

	## [param things] put down as [param step]'s, and judged: each new thing
	## held to something that stands at the end of the step, and in sight
	## with what earlier steps built in front of it ([member floating],
	## [member hidden]). The ids it put in.
	func take(step: Instructions.Step, things: Array) -> Array[int]:
		var in_hand: bool = step.in_callout()
		var pile: Pile = pile_of(step)
		var section: String = step.authored_in if step.authored_step >= 0 else ""
		var pictures: Sight = _pictures_for(section,
			_side_pictures[step.callout] if in_hand else _main_pictures)
		var new_ids: Array[int] = []
		for thing: PackedInt64Array in things:
			for id: int in thing:
				if not pile.placed.has(id):
					new_ids.append(id)
		# Hidden by what earlier steps built, before this one's parts go in.
		var hidden_from: int = Time.get_ticks_usec()
		for thing: PackedInt64Array in things:
			var seen: Array = []
			for id: int in thing:
				seen.append(Tested._node(id, nodes, by_id, library))
			if pictures.hides(seen):
				hidden.append([step.number, thing[0]])
		hidden_us += Time.get_ticks_usec() - hidden_from
		# Put in, and joined to what is there.
		for id: int in new_ids:
			pile.put(id)
			pile.lowest = mini(pile.lowest, int(bottom[id]))
		for id: int in new_ids:
			for other: int in (near[id] as Dictionary):
				if pile.placed.has(other):
					pile.join(id, other)
		# What stands: in the hand its first parts; on the model those, what
		# is on its lowest point as it stands, and the first parts of each
		# piece of the finished model a step begins. Asked of the new parts
		# only: the lowest point only goes lower, so a part on it now was on
		# it when it went in, and stood then.
		if not pile.begun:
			for id: int in new_ids:
				pile.stand(id)
			pile.begun = true
		if not in_hand:
			for id: int in new_ids:
				if int(bottom[id]) <= pile.lowest + Balance.ON_FLOOR:
					pile.stand(id)
			for thing: PackedInt64Array in things:
				var which: int = int(piece[thing[0]])
				if not _begun_pieces.has(which):
					_begun_pieces[which] = true
					pile.stand(thing[0])
		# And, on the model or in a callout, the first parts of each of the
		# author's sub-models, in the hand where nothing that stands holds them.
		if not section.is_empty() and not _begun_sections.has(section):
			_begun_sections[section] = not new_ids.any(func(id: int) -> bool: return pile.stands(id))
			for id: int in new_ids:
				pile.stand(id)
		for thing: PackedInt64Array in things:
			if not joined.has(thing[0]) or _stood(pile, thing):
				continue
			# A sub-assembly put on whole is put on where it is held.
			if thing.size() > 1:
				floating.append([step.number, thing[0]])
			else:
				pile.aloft.append([step.number, thing, -1])
		_held_up(pile)
		var step_nodes: Array = []
		for id: int in new_ids:
			step_nodes.append(Tested._node(id, nodes, by_id, library))
		pictures.built(step_nodes)
		if _section_nodes.has(section):
			(_section_nodes[section] as Array).append_array(step_nodes)
		return new_ids

	func _stood(pile: Pile, thing: PackedInt64Array) -> bool:
		for id: int in thing:
			if pile.stands(id):
				return true
		return false

	## What [param pile] holds in the air, judged once a step holds it to
	## what stands. Parts held to each other there, two or more, are a
	## sub-assembly built in the hand and put on whole, as a booklet's
	## callout is; a modeller who draws the callout's steps where it goes
	## puts it down in the air. 5891-1's apple tree crown, seven steps
	## before the trunk under it, and its mailbox, before its post, put 43
	## parts down in the air (tested306). One part alone, held by the next
	## step's under it, was put down in the air.
	func _held_up(pile: Pile) -> void:
		var held: Dictionary = {}          ## root as the last step left it -> [entry]
		var still: Array = []
		for one: Array in pile.aloft:
			if _stood(pile, one[1]):
				var root: int = int(one[2])
				if not held.has(root):
					held[root] = []
				(held[root] as Array).append(one)
			else:
				one[2] = pile.root((one[1] as PackedInt64Array)[0])
				still.append(one)
		pile.aloft = still
		for root: int in held:
			var parts: int = 0
			for one: Array in held[root]:
				parts += (one[1] as PackedInt64Array).size()
			if root < 0 or parts < 2:
				for one: Array in held[root]:
					floating.append([int(one[0]), (one[1] as PackedInt64Array)[0]])

	## The steps are all built: what is still in the air was put down there.
	func finish() -> void:
		var piles: Array = [main]
		piles.append_array(side.values())
		for pile: Pile in piles:
			for one: Array in pile.aloft:
				floating.append([int(one[0]), (one[1] as PackedInt64Array)[0]])
			pile.aloft = []
		floating.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))

	## The outermost of the author's sub-models [param section] is in that
	## is built in the hand, or "": what its parts wait for to be weighed.
	## Every one is but one the model itself places that was begun on what
	## stands, which is a build of the model's own: its main build, as one
	## file of a whole set often is, or a figure beside it.
	func in_hand(section: String) -> String:
		var path: String = ""
		for segment: String in Assemblies.segments(section):
			path = Assemblies.join(path, segment)
			if path.contains("/") or bool(_begun_sections.get(path, false)):
				return path
		return ""

	## The pictures a step of [param section] is judged in sight by: its
	## sub-model's own, once each sub-model it is not in is built into what
	## holds it; [param build]'s for the model's own steps.
	func _pictures_for(section: String, build: Sight) -> Sight:
		var done: Array = _section_pictures.keys().filter(func(path: String) -> bool:
			return not (section == path or section.begins_with(path + "/")))
		done.sort_custom(func(a: String, b: String) -> bool:
			return Assemblies.segments(a).size() > Assemblies.segments(b).size())
		for path: String in done:
			var built: Array = _section_nodes[path]
			var onto: Variant = _section_onto[path]
			var up: String = Assemblies.parent_of(path)
			while not up.is_empty():
				if section == up or section.begins_with(up + "/"):
					onto = _section(up, onto)
					(_section_nodes[up] as Array).append_array(built)
					break
				up = Assemblies.parent_of(up)
			(onto as Sight).built(built)
			_section_pictures.erase(path)
			_section_nodes.erase(path)
			_section_onto.erase(path)
		return build if section.is_empty() else _section(section, build)

	func _section(path: String, onto: Sight) -> Sight:
		if not _section_pictures.has(path):
			_section_pictures[path] = Sight.new()
			_section_nodes[path] = []
			_section_onto[path] = onto
		return _section_pictures[path]


## What holds what in [param bricks], as the tests read it, into [param
## out]: "contacts" (Stability.contacts), "bottom" (id -> its lowest cell),
## "floor" (the lowest of them), "near" (id -> {id: true}, every joint read,
## either way round), "links" (the joints Balance weighs a part by),
## "otherwise" (what glue, magnets and flexible things hold,
## Joints.held_otherwise), "jointed" (those, and what every joint but a
## stud's holds, either way round), "joined" (what the finished model holds to what it
## stands on through them), "piece" (id -> which piece of the finished model
## it is in, by them) and "us" (microseconds reading the contacts, then the
## joints). Left empty when [param job] was cancelled; at once with no job.
## The worked-out steps are put right by these same joints (HeldSteps).
static func holds_into(out: Dictionary, bricks: Array, lattice: BrickLattice,
		library: PartLibrary, job: Working.Job = null) -> void:
	var by_id: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		by_id[brick.id] = brick
	var lap_from: int = Time.get_ticks_usec()
	var judge := Stability.new()
	judge.library = library
	judge.lattice = lattice
	var contacts: Dictionary = judge.contacts(bricks)
	var contacts_us: int = Time.get_ticks_usec() - lap_from
	var boxes: Dictionary = contacts["boxes"]
	var bottom: Dictionary = {}
	var floor_cell: int = 0x7FFFFFFF
	for id: int in by_id:
		var low: int = 0x7FFFFFFF
		var packed: PackedInt32Array = boxes.get(id, PackedInt32Array())
		for at: int in range(1, packed.size(), 6):
			low = mini(low, packed[at])
		bottom[id] = low
		floor_cell = mini(floor_cell, low)
	if job != null:
		await job.next()
		if job.cancelled:
			return

	# What holds what: the studs, as Balance and Sections read them
	# (Stability.stud_joints), what is seated in what, and every other joint
	# the build check reads, either way round. And the joints Balance weighs a
	# part by. Without what is seated, 1793-1's whip on a cone threaded on an
	# antenna was loose, and 8466-1, held by its pins, took 108 s to find
	# held by touch and went untested (2026-10-20).
	var near: Dictionary = {}
	for id: int in by_id:
		near[id] = {}
	var link := func(a: Variant, b: Variant) -> void:
		if a == b or not by_id.has(a) or not by_id.has(b):
			return
		(near[a] as Dictionary)[b] = true
		(near[b] as Dictionary)[a] = true
	var joints: Dictionary = Stability.stud_joints(contacts, library, lattice)
	for held: Dictionary in [joints["studs"], joints["seated"]]:
		for key: int in held:
			link.call(key >> 32, key & 0xFFFFFFFF)
	var entries: Array = []
	var with_paths: Array = []
	for brick: BrickWorld.Brick in bricks:
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		entries.append([brick.id, brick.transform, mesh])
		with_paths.append([brick.id, brick.transform, mesh, brick.part_id, Assemblies.path_of(brick)])
	var links: Array = []
	var both: Dictionary = Joints.both_ways(entries)
	if job != null:
		await job.next()
	var rounds: Dictionary = Joints.rounds(entries)
	if job != null:
		await job.next()
	var otherwise: Dictionary = Joints.held_otherwise(with_paths, library)
	if job != null:
		await job.next()
	for held: Dictionary in [both, rounds, otherwise]:
		for one: Variant in held:
			for other: Variant in (held[one] as Dictionary):
				link.call(one, other)
				links.append([int(one), int(other)])
	# And each part with what holds it by a joint of its own, not a stud:
	# what the whole test holds by besides BrickNet's connections.
	var jointed: Dictionary = {}
	var joint := func(a: Variant, b: Variant) -> void:
		link.call(a, b)
		if not jointed.has(a):
			jointed[a] = {}
		(jointed[a] as Dictionary)[b] = true
	for held: Dictionary in [both, rounds, otherwise]:
		for one: Variant in held:
			for other: Variant in (held[one] as Dictionary):
				joint.call(one, other)
	var balls: Dictionary = Joints.balls(entries)
	for one: Variant in balls:
		for other: Variant in (balls[one] as Dictionary):
			joint.call(one, other)
	for pair: Array in Joints.through(entries):
		joint.call(pair[0], pair[1])
	if job != null:
		await job.next()
		if job.cancelled:
			return
	var joints_us: int = Time.get_ticks_usec() - lap_from - contacts_us

	# What the finished model holds to what it stands on, and its pieces.
	var held: Dictionary = {}
	var queue: Array[int] = []
	for id: int in by_id:
		if int(bottom[id]) <= floor_cell + Balance.ON_FLOOR:
			held[id] = true
			queue.append(id)
	while not queue.is_empty():
		var here: int = queue.pop_back()
		for next: int in (near[here] as Dictionary):
			if not held.has(next):
				held[next] = true
				queue.append(next)
	var piece: Dictionary = {}
	var pieces: int = 0
	for start: int in by_id:
		if piece.has(start):
			continue
		piece[start] = pieces
		var pending: Array[int] = [start]
		while not pending.is_empty():
			var here: int = pending.pop_back()
			for next: int in (near[here] as Dictionary):
				if not piece.has(next):
					piece[next] = pieces
					pending.append(next)
		pieces += 1
	out.merge({"contacts": contacts, "bottom": bottom, "floor": floor_cell, "near": near,
		"links": links, "otherwise": otherwise, "jointed": jointed, "joined": held, "piece": piece,
		"us": [contacts_us, joints_us]})


## The four tests of [param world]'s parts as [param steps] build them.
## [param lattice] holds the parts' covers (what rests on what, the stud
## joints); [param skip] is the baseplate, which is the floor. {"v", "app",
## "parts", "steps", "tests": {stands, steps, parts, whole: {"ok", "why"}},
## "ms"}, or {} when there is nothing to test or [param job] was cancelled.
static func check(world: BrickWorld, lattice: BrickLattice, library: PartLibrary,
		steps: Array[Instructions.Step], skip: Dictionary = {},
		job: Working.Job = null) -> Dictionary:
	var began: int = Time.get_ticks_msec()
	var asked: Working.Job = job if job != null else Working.Job.new()
	var bricks: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not skip.has(brick.id) and library.mesh_for(brick.part_id) != null:
			bricks.append(brick)
	if bricks.is_empty() or steps.is_empty():
		return {}
	var by_id: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		by_id[brick.id] = brick

	asked.say("Testing it: what holds what in %s parts…" % Working.comma(bricks.size()))
	await asked.next()
	laps.clear()
	var holding: Dictionary = {}
	await holds_into(holding, bricks, lattice, library, asked)
	if asked.cancelled or holding.is_empty():
		return {}
	laps["contacts"] = int(holding["us"][0])
	laps["joints"] = int(holding["us"][1])
	var contacts: Dictionary = holding["contacts"]
	var boxes: Dictionary = contacts["boxes"]
	var near: Dictionary = holding["near"]
	var links: Array = holding["links"]
	var otherwise: Dictionary = holding["jointed"]
	# What a step is judged on: held through what joins it, as the steps score
	# judges it. Then, for a part with no exact shape, which the whole test
	# holds by these as the design check holds it by the lattice
	# ([method _exact_whole]), what rests against what is held though nothing
	# read joins them — a wheel on an old holder's pin, a tool in a figure's
	# hand: such a part is loose only when it touches nothing held. 6688-1's
	# car read 67 parts loose without it.
	var held: Dictionary = (holding["joined"] as Dictionary).duplicate()
	var touches: Dictionary = {}
	for id: int in by_id:
		if held.has(id):
			continue
		var grown: PackedInt32Array = _grown(boxes.get(id, PackedInt32Array()))
		var found: Array[int] = []
		for other: int in lattice.near_bounds(grown, id):
			if by_id.has(other) and BrickLattice.shared_cells(grown, lattice.boxes_of(other)) > 0:
				found.append(other)
		touches[id] = found
	var more: bool = true
	while more:
		more = false
		for id: int in touches:
			if held.has(id):
				continue
			for other: int in (touches[id] as Array):
				if held.has(other):
					held[id] = true
					more = true
					break

	# The whole of it by the parts' exact shapes, on a worker.
	var lap_exact: int = Time.get_ticks_usec()
	var whole: Dictionary = await _exactly(bricks, otherwise, near, held, library, asked)
	laps["exact"] = Time.get_ticks_usec() - lap_exact
	if asked.cancelled or whole.is_empty():
		return {}

	# Step by step: each new thing held and in sight, and the build so far
	# weighed.
	var test := Steps.new(by_id, holding, library)
	var tips: Array = []               ## [step number, words]
	## How many steps were built when the time ran out; -1 when every one was.
	var built_to: int = -1
	var weighed: int = 0
	var weighing := Weighing.new(library, lattice, contacts, by_id, links)
	## Put in on the model and not yet weighed, each by the author's
	## sub-model it is in, not yet built.
	var held_up: Dictionary = {}
	asked.say("Testing it: building its %s…" % _counted(int(Instructions.count(steps)["steps"]), "step"))
	asked.count(0, steps.size())
	for step: Instructions.Step in steps:
		if asked.due():
			await asked.next()
			if asked.cancelled:
				return {}
		# Past its time a model's steps are built no further, rather than hold
		# its share: a 3,457-part ship took 38 s, most of it weighed at 676
		# steps. What it failed already is said ([method _unfinished]).
		if Time.get_ticks_msec() - began > most_ms(bricks.size()):
			built_to = step.index
			break
		asked.count(step.index, steps.size())
		var things: Array = test.things_of(step)
		if things.is_empty():
			continue
		var new_ids: Array[int] = test.take(step, things)
		if step.in_callout():
			continue
		# Weighed as the build check weighs it, the build so far: a part of
		# one of the author's sub-models begun in the hand once that is built,
		# as a booklet's sub-assembly is put on whole, not while a hand holds
		# it (Steps). Each weighed where the booklet shows it as it was built,
		# 8862-1 tipped over at its step 10 and 5984-1 at its step 16. But
		# the model's own builds, begun on what stands, are weighed as they
		# go: held back, 10124-1's plane, one sub-model of its file, had its
		# own frame weighed only at its end, and tipped over at 12 steps, not
		# 6 (tested301).
		var section: String = step.authored_in if step.authored_step >= 0 else ""
		var hand: String = test.in_hand(section)
		for id: int in new_ids:
			held_up[id] = hand
		var weigh: Array[int] = []
		for id: int in held_up.keys():
			var in_section: String = held_up[id]
			if in_section.is_empty() or not (section == in_section
					or section.begins_with(in_section + "/")):
				weigh.append(id)
				held_up.erase(id)
		if _weighed(weighing, weigh, step.number, tips, library):
			weighed += 1
	if built_to < 0 and _weighed(weighing, Array(held_up.keys(), TYPE_INT, "", null),
			steps[-1].number, tips, library):
		weighed += 1
	test.finish()
	laps["hidden"] = test.hidden_us
	var floating: Array = test.floating
	var hidden: Array = test.hidden

	# Every part in its colour.
	var never: Dictionary = {}         ## "part:colour" -> [part, colour, how many, why]
	var unknown: int = 0
	for brick: BrickWorld.Brick in bricks:
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var why: String = ""
		if brick.color_code >= DIRECT_FROM:
			why = "in a colour typed in, not one parts are made in"
		elif info == null or info.custom:
			why = "made here, not a real element"
		elif info.never_made_in(brick.color_code):
			why = "never made in %s" % HiddenColours.colour_name(library, brick.color_code)
		elif not info.availability_known():
			unknown += 1
		if why.is_empty():
			continue
		var key: String = "%s:%d" % [brick.part_id, brick.color_code]
		if not never.has(key):
			never[key] = [brick.part_id, brick.color_code, 0, why]
		never[key][2] = int(never[key][2]) + 1

	var tests: Dictionary = {}
	said_all.clear()
	var main_steps: int = int(Instructions.count(steps)["steps"])
	if tips.is_empty():
		tests["stands"] = {"ok": weighed > 0, "why": ("Stands at every one of its %s"
			% _counted(main_steps, "step")) if weighed > 0 else "Nothing in it stands on anything to weigh"}
	else:
		said_all["stands"] = tips.map(func(one: Array) -> String:
			return "At step %d %s" % [int(one[0]), str(one[1])])
		tests["stands"] = {"ok": false, "why": _list(said_all["stands"], tips.size(), "step")}
	if floating.is_empty() and hidden.is_empty():
		tests["steps"] = {"ok": true, "why": "Every part goes onto what is already built, in sight"}
	else:
		var said: Array = []
		for one: Array in floating:
			said.append("Step %d: %s is put down in the air" % [int(one[0]),
				_named((by_id[int(one[1])] as BrickWorld.Brick).part_id, library)])
		for one: Array in hidden:
			said.append("Step %d: %s is hidden behind what is already built" % [int(one[0]),
				_named((by_id[int(one[1])] as BrickWorld.Brick).part_id, library)])
		said_all["steps"] = said
		tests["steps"] = {"ok": false, "why": _list(said, said.size(), "part")}
	if never.is_empty():
		tests["parts"] = {"ok": true, "why": "Every part is made in its colour" + (
			(" (%s the catalogue has no colours for)" % _counted(unknown, "part")) if unknown > 0 else "")}
	else:
		var said: Array = []
		for key: String in never:
			var one: Array = never[key]
			said.append("%s%s %s" % [_named(str(one[0]), library),
				(" (%d)" % int(one[2])) if int(one[2]) > 1 else "", str(one[3])])
		said_all["parts"] = said
		tests["parts"] = {"ok": false, "why": _list(said, said.size(), "kind")}
	tests["whole"] = _whole_said(whole, bricks, library)
	if built_to >= 0 and not _unfinished(tests, built_to, steps.size()):
		return {"untested": "it is too big to test in the time a share takes (%s)"
			% _counted(bricks.size(), "part"), "parts": bricks.size(), "steps": steps.size()}
	return {"v": VERSION, "app": BuildInfo.version(), "parts": bricks.size(), "steps": steps.size(),
		"tests": tests, "ms": Time.get_ticks_msec() - began}


## [param ids] put on the model at step [param number], and the build so
## far weighed as the build check weighs it: whether it stood on anything
## to weigh. Where a joint gives, it is said into [param tips]. A build that
## tips over is let fall to where it rests, as a real one is laid on a table
## (Weighing.settle), and is said only where a joint gives as it lies
## there, or where it does not come to rest.
static func _weighed(weighing: Weighing, ids: Array[int], number: int, tips: Array,
		library: PartLibrary) -> bool:
	if ids.is_empty():
		return false
	var weigh_from: int = Time.get_ticks_usec()
	var report: Dictionary = weighing.add(ids)
	if report["empty"]:
		laps["weigh"] = int(laps.get("weigh", 0)) + Time.get_ticks_usec() - weigh_from
		return false
	var joints: Array = report["joints"]
	var fell: String = ""
	if float(report["margin"]) < 0.0:
		var settle_from: int = Time.get_ticks_usec()
		var settled: Dictionary = weighing.settle()
		laps["settle"] = int(laps.get("settle", 0)) + Time.get_ticks_usec() - settle_from
		var falls: Dictionary = settled["fell"]
		if not str(falls["words"]).is_empty():
			fell = "it %s, and " % falls["words"]
		joints = [] if settled["gave"] == null else [settled["gave"]]
		if not bool(falls["rests"]) and joints.is_empty():
			tips.append([number, "it %s" % falls["words"]])
	laps["weigh"] = int(laps.get("weigh", 0)) + Time.get_ticks_usec() - weigh_from
	for one: Balance.JointLoad in joints:
		if one.moment > one.ultimate:
			tips.append([number, "%s%s %s %s on %d stud%s past where it lets go" % [fell,
				_named(one.beyond_part, library), "hangs from" if one.hangs else "is held by",
				_named(one.held_part, library), one.studs, "" if one.studs == 1 else "s"]])
			break
	return true


## How long the tests of a model of [param parts] parts may take, ms.
static func most_ms(parts: int) -> int:
	return MOST_MS + maxi(0, parts - MOST_MS_FROM) * MS_A_PART


## A model whose steps were built only to step [param built_to] of [param
## of] before the time ran out: its stands and steps tests, where they found
## nothing wrong so far, say they were not finished, and are not passed. True
## when another test failed, so the finding says why it is not Tested;
## false when nothing failed, and it goes untested, as it went before.
## Orthanc's 9,541 parts in 1,494 steps run out of time, and it fails the
## whole test (models175).
static func _unfinished(tests: Dictionary, built_to: int, of: int) -> bool:
	var failed_already: bool = false
	for name: String in ["stands", "steps", "parts", "whole"]:
		if not bool((tests[name] as Dictionary)["ok"]):
			failed_already = true
	if not failed_already:
		return false
	var so_far: String = "Not finished: built to step %d of %d in the time a share takes" % [built_to, of]
	if bool((tests["stands"] as Dictionary)["ok"]) or built_to == 0:
		tests["stands"] = {"ok": false, "why": so_far + (", standing at each" if built_to > 0 else "")}
	if bool((tests["steps"] as Dictionary)["ok"]):
		tests["steps"] = {"ok": false, "why": so_far + (", each part on what was built, in sight"
			if built_to > 0 else "")}
	return true


## The model by its parts' exact shapes (ExactCheck), as the design check
## reads a whole design. The shapes are read here a part a slice, and in a
## browser fetched, as the design check waits for them; the rest runs on a
## worker ([method _exact_whole]). [param otherwise] is what glue, magnets,
## flexible things and every joint but a stud's hold (holds_into's
## "jointed"), [param near] every joint
## read, and [param held] what they and what rests on what hold, by brick id:
## a part with no exact shape is judged by those. {} when [param asked] was
## cancelled.
static func _exactly(bricks: Array, otherwise: Dictionary, near: Dictionary, held: Dictionary,
		library: PartLibrary, asked: Working.Job) -> Dictionary:
	var ids: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		ids[brick.part_id] = true
	asked.say("Testing it: reading its parts' exact shapes…")
	for part_id: String in ids:
		if asked.due():
			await asked.next()
			if asked.cancelled:
				return {}
		Exact.shape_for(library, part_id)
	var deadline: int = Time.get_ticks_msec() + Assistant.FETCH_WAIT_MS
	var wanted: Array = ids.keys().filter(func(part_id: String) -> bool:
		return not Exact.known(library, part_id) and library.is_exact_on_its_way(part_id))
	while not wanted.is_empty() and Time.get_ticks_msec() < deadline:
		await Engine.get_main_loop().process_frame
		if asked.cancelled:
			return {}
		wanted = wanted.filter(func(part_id: String) -> bool:
			return not Exact.known(library, part_id) and library.is_exact_on_its_way(part_id))
	var shapes: Dictionary = Exact.shapes_for(library, ids.keys())
	var parts: Array = []          ## [part id, Transform3D, Lbm.PartMesh] each
	var number: Dictionary = {}    ## brick id -> its number in parts
	for brick: BrickWorld.Brick in bricks:
		number[brick.id] = parts.size()
		parts.append([brick.part_id, brick.transform, library.mesh_for(brick.part_id)])
	var glued: Array = []
	for one: Variant in otherwise:
		for other: Variant in (otherwise[one] as Dictionary):
			if number.has(one) and number.has(other):
				glued.append([int(number[one]), int(number[other])])
	var joints: Array = []
	for one: Variant in near:
		for other: Variant in (near[one] as Dictionary):
			if int(one) < int(other) and number.has(one) and number.has(other):
				joints.append([int(number[one]), int(number[other])])
	var resting: Dictionary = {}
	for id: Variant in held:
		if number.has(id):
			resting[int(number[id])] = true
	asked.say("Testing it: what holds what, by the parts' exact shapes…")
	var found: Variant = await WorkerTasks.awaited(func() -> Dictionary:
		return _exact_whole(parts, shapes, glued, joints, resting), "test a model's parts", library)
	return found if found is Dictionary else {}


## How far a part's exact shapes may be off the floor and stand on it, LDU
## (ExactCheck.ON_GROUND).
const ON_GROUND := ExactCheck.ON_GROUND


## What [method _exactly] finds, on a worker: {"into": [[a, b, depth], ...]
## the pairs whose real shapes pass into each other by more than 1 LDU, the
## deepest first, past what a joint's own parts do and gears in mesh
## (ExactCheck.forgiven, as the design check forgives them); "builds": how
## many builds it is, each standing on its own; "apart": [{kind, part, on,
## size}, ...] each piece held by nothing, the biggest first, kind "falls"
## (it does not stand where it is), "away" (it stands, and comes away in the
## hand), "missed" (that, on another part's stud grid where it has no stud),
## "against" (on the floor, touching a bigger piece) or "leans" (on the
## floor, and it does not stand by itself)}. Numbers are [param parts]'.
##
## Two parts are joined by BrickNet's connections, by [param glued], and by
## [param joints] where either has no exact shape. The piece with the most
## parts on the floor is the model; another on the floor that stands by
## itself and touches no bigger piece is a build of its own, as a set's
## figures beside its car are. Any other piece that stands where it is and is caught
## there stays, as the orrery's planet rings do (connect166, models175:
## ExactCheck.comes_away), unless what catches it comes away itself; and so
## does one with a part of no exact shape that [param resting] holds, as the
## design check holds such a part by the lattice. BrickBench's one piece is
## the design check's count (Assistant._pieces_of), not this.
static func _exact_whole(parts: Array, shapes: Dictionary, glued: Array, joints: Array,
		resting: Dictionary) -> Dictionary:
	var count: int = parts.size()
	var exact := ExactCheck.new(shapes, count)
	var low := PackedFloat64Array()
	low.resize(count)
	var floor_y: float = INF
	var entries: Array = []
	for n: int in count:
		exact.place(n, parts[n][0], parts[n][1])
		var item: Exact.Item = exact.items[n]
		var mesh: Lbm.PartMesh = parts[n][2]
		low[n] = item.lo.y if item != null else ((parts[n][1] as Transform3D) * mesh.bounds).position.y
		floor_y = minf(floor_y, low[n])
		entries.append([n, parts[n][1], mesh, parts[n][0]])
	exact.ground = floor_y
	var meshing: Dictionary = Joints.meshing(entries)
	var into: Array = []
	for found: Dictionary in exact.collisions({}):
		var a: int = found["a"]
		var b: int = found["b"]
		if (meshing.get(a, {}) as Dictionary).has(b) or (meshing.get(b, {}) as Dictionary).has(a) \
				or exact.forgiven(a, b):
			continue
		into.append([a, b, float(found["depth"])])
	into.sort_custom(func(x: Array, y: Array) -> bool: return x[2] > y[2])

	# A chain round its sprockets is held by them, as the plastic is.
	var extra: Array = glued.duplicate()
	for a: Variant in meshing:
		for b: Variant in (meshing[a] as Dictionary):
			if str(meshing[a][b]).begins_with("a chain on") or str(meshing[a][b]).begins_with("a tread on"):
				extra.append([int(a), int(b)])
	for pair: Array in joints:
		if exact.items[pair[0]] == null or exact.items[pair[1]] == null:
			extra.append(pair)
	var root: PackedInt32Array = exact.pieces(extra)
	var members: Dictionary = {}       ## root -> its parts
	var on_floor: Dictionary = {}      ## root -> true
	var by_covers: Dictionary = {}     ## root -> true: a part of no shape held as before
	for n: int in count:
		var key: int = root[n]
		if not members.has(key):
			members[key] = []
		(members[key] as Array).append(n)
		if low[n] - floor_y <= ON_GROUND:
			on_floor[key] = true
		if exact.items[n] == null and resting.has(n):
			by_covers[key] = true
	var model: int = -1
	for key: int in on_floor:
		if model < 0 or (members[key] as Array).size() > (members[model] as Array).size():
			model = key
	# A piece on the floor beside the model is a build of its own, as a set's
	# figures and its stretcher stand beside its ambulance (6680-1), when it
	# stands there by itself (ExactCheck.tips, on a bare floor) and touches no
	# bigger piece. One that leans to stand, or stands against or inside a
	# bigger one (a part left against a wall, a dish in a ring of bricks), is
	# a part held by nothing. The model is turned any way: its outline is no
	# guide, what touches what is.
	var outline: Dictionary = {}       ## root -> [lo, hi]
	for n: int in count:
		var item: Exact.Item = exact.items[n]
		var box: AABB = (parts[n][1] as Transform3D) * (parts[n][2] as Lbm.PartMesh).bounds
		var lo: Vector3 = item.lo if item != null else box.position
		var hi: Vector3 = item.hi if item != null else box.end
		var was: Array = outline.get(root[n], [lo, hi])
		outline[root[n]] = [(was[0] as Vector3).min(lo), (was[1] as Vector3).max(hi)]
	var bulk := func(key: int) -> float:
		var size: Vector3 = (outline[key][1] as Vector3) - (outline[key][0] as Vector3)
		return size.x * size.y * size.z
	var builds: Dictionary = {}        ## root -> true: a build of its own
	var against: Dictionary = {}       ## root -> the part of a bigger piece it touches
	var leans: Dictionary = {}         ## root -> true
	for key: int in on_floor:
		if key == model or by_covers.has(key):
			continue
		if not exact.tips(members[key]).is_empty():
			leans[key] = true
			continue
		var touched: int = _touches(exact, members[key], root)
		if touched >= 0 and float(bulk.call(root[touched])) >= float(bulk.call(key)):
			against[key] = touched
		else:
			builds[key] = true
	# What stands where it is and is caught there stays; what falls, and what
	# comes away, catches nothing, asked again until nothing more comes away.
	var stands: Dictionary = {}
	var gone: Dictionary = {}
	for key: int in members:
		if key == model or by_covers.has(key) or builds.has(key):
			continue
		stands[key] = not on_floor.has(key) and exact.rests(members[key])
		if not stands[key]:
			for n: int in members[key]:
				gone[n] = true
	var away: Dictionary = {}
	var more: bool = true
	while more:
		more = false
		for key: int in stands:
			if stands[key] and not away.has(key) and exact.comes_away(members[key], gone):
				away[key] = true
				more = true
				for n: int in members[key]:
					gone[n] = true
	var apart: Array = []
	for key: int in stands:
		if stands[key] and not away.has(key):
			continue
		var kind: String = "leans" if leans.has(key) else "against" if against.has(key) \
			else "away" if away.has(key) else "falls"
		apart.append({"kind": kind, "part": (members[key] as Array)[0], "on": -1,
			"size": (members[key] as Array).size(), "key": key})
	apart.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["size"]) > int(y["size"]))
	# Those named, by the part that rests on something not of its piece, or
	# the part of the piece it stands in that it stands under or by.
	for one: Dictionary in apart.slice(0, NAMED):
		var them: Array = members[one["key"]]
		if one["kind"] == "against":
			one["on"] = against[one["key"]]
		else:
			for n: int in them:
				var under: int = exact.under(n)
				if under >= 0 and not them.has(under):
					one["part"] = n
					one["on"] = under
					break
		if one["kind"] == "away":
			var missed: int = exact.on_missing_stud(them)
			if missed >= 0:
				one["kind"] = "missed"
				one["on"] = missed
		one.erase("key")
	return {"into": into, "builds": 1 + builds.size(), "apart": apart}


## A part of another piece that one of [param members] touches, by their
## exact shapes within ExactCheck.TOUCH, the first found; -1 for none.
## [param root] says which piece each part is in.
static func _touches(exact: ExactCheck, members: Array, root: PackedInt32Array) -> int:
	var mine: int = root[int(members[0])]
	var around: PackedInt32Array = exact._around(members)
	var points := PackedVector3Array()
	for i: Variant in members:
		var item: Exact.Item = exact.items[int(i)]
		if item == null:
			continue
		for j: int in Exact._near(exact.items, int(i), around, ExactCheck.TOUCH + Exact.TAU):
			if root[j] == mine or exact.items[j] == null:
				continue
			points.clear()
			ExactCheck._touching(item, exact.items[j], points)
			if not points.is_empty():
				return j
	return -1


## The whole test, said: every part held and none in another, or what is
## not, in a person's words.
static func _whole_said(whole: Dictionary, bricks: Array, library: PartLibrary) -> Dictionary:
	var name := func(n: int) -> String: return _named((bricks[n] as BrickWorld.Brick).part_id, library)
	var into: Array = whole.get("into", [])
	var apart: Array = whole.get("apart", [])
	if into.is_empty() and apart.is_empty():
		var builds: int = int(whole.get("builds", 1))
		return {"ok": true, "why": ("One piece" if builds == 1 else "%d builds, each standing on its own"
			% builds) + ": every part is held by a stud or a joint, or caught where it is, and none "
			+ "passes into another"}
	var pairs: Array = into.map(func(one: Array) -> String:
		return "%s into %s by %s LDU" % [name.call(int(one[0])), name.call(int(one[1])),
			ExactCheck._n(snappedf(float(one[2]), 0.1))])
	var pieces: Array = apart.map(func(one: Dictionary) -> String:
		var who: String = name.call(int(one["part"]))
		var rest: int = int(one["size"]) - 1
		if rest > 0:
			who += " and %s with it" % _counted(rest, "part")
		var on: String = name.call(int(one["on"])) if int(one["on"]) >= 0 else ""
		match str(one["kind"]):
			"against":
				return "%s stands against %s" % [who, on]
			"leans":
				return "%s leans on the rest to stand" % who
			"missed":
				return "%s stands on %s where it has no stud" % [who, on]
			"away":
				return ("%s rests on %s" % [who, on]) if not on.is_empty() else "%s rests where it is" % who
		return ("%s falls off %s" % [who, on]) if not on.is_empty() else "%s falls" % who)
	said_all["whole"] = pairs + pieces
	var heads := PackedStringArray()
	if not into.is_empty():
		heads.append("%s %s into each other: " % [_counted(into.size(), "pair"),
			"of parts passes" if into.size() == 1 else "of parts pass"])
	if not apart.is_empty():
		heads.append("%s%s %s held by nothing, and come%s away when the model is lifted: " % [
			"and " if not into.is_empty() else "", _counted(apart.size(), "piece"),
			"is" if apart.size() == 1 else "are", "s" if apart.size() == 1 else ""])
	# The site keeps MOST_WHY characters of it (api/_tested.js): each list
	# names what fits in its share, after the heads and its "and N more".
	var room: int = maxi(40, (MOST_WHY - "".join(heads).length() - 2) / heads.size() - 24)
	var said := PackedStringArray()
	var at: int = 0
	if not into.is_empty():
		said.append(heads[at] + _list_within(pairs, into.size(), "pair", room))
		at += 1
	if not apart.is_empty():
		said.append(heads[at] + _list_within(pieces, apart.size(), "piece", room))
	return {"ok": false, "why": "; ".join(said)}


## Whether every test passed.
static func passed(found: Dictionary) -> bool:
	var tests: Variant = found.get("tests")
	if not tests is Dictionary:
		return false
	for name: String in ["stands", "steps", "parts", "whole"]:
		var one: Variant = (tests as Dictionary).get(name)
		if not one is Dictionary or not bool((one as Dictionary).get("ok", false)):
			return false
	return true


## The tests that failed, by name.
static func failed(found: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var tests: Dictionary = found.get("tests", {})
	for name: String in ["stands", "steps", "parts", "whole"]:
		var one: Dictionary = tests.get(name, {})
		if not bool(one.get("ok", false)):
			out.append(name)
	return out


## What the share panel says of it to its owner: that it is marked Tested,
## or which test it failed and why, plainly. Only its owner sees a failure.
static func words(found: Dictionary) -> String:
	if found.has("untested"):
		return "Not tested: %s." % str(found["untested"])
	if found.is_empty():
		return "Not tested: its steps could not be worked out to test."
	if passed(found):
		return "Marked Tested: it stands at every step, every step can be reached, every part " \
			+ "is made in its colour, and every part is held, none in another."
	var tests: Dictionary = found["tests"]
	var said := PackedStringArray()
	for name: String in failed(found):
		said.append(str((tests[name] as Dictionary).get("why", name)))
	return "Not marked Tested (only you see why): %s." % "; ".join(said).trim_suffix(".")


## A model file's fingerprint as the server takes it (api/_directory.js
## modelHash): each line trimmed, the blank ones left out, joined by line
## feeds. A finding is the finding of exactly this file.
static func fingerprint(text: String) -> String:
	var kept := PackedStringArray()
	for line: String in text.trim_prefix("﻿").replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty():
			kept.append(trimmed)
	return "\n".join(kept).sha256_text()


## [param packed] boxes each a cell bigger every way: what touches them.
static func _grown(packed: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = packed.duplicate()
	for at: int in range(0, out.size(), 6):
		out[at] -= 1
		out[at + 1] -= 1
		out[at + 2] -= 1
		out[at + 3] += 1
		out[at + 4] += 1
		out[at + 5] += 1
	return out


## A part as the steps test sees it (Seen): its box where it stands, and its
## cover. Made where the library is read, for a worker to draw.
static func _node(id: int, nodes: Dictionary, by_id: Dictionary, library: PartLibrary) -> Seen:
	var known: Variant = nodes.get(id)
	if known != null:
		return known
	var brick: BrickWorld.Brick = by_id[id]
	var node := Seen.new()
	node.id = id
	node.at = brick.transform
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	var colour: PartLibrary.BrickColor = library.colors.get(brick.color_code)
	node.clear = colour != null and colour.is_transparent()
	if mesh == null:
		node.box = AABB(brick.transform.origin, Vector3.ZERO)
	else:
		node.box = brick.transform * mesh.bounds
		if mesh.boxes.is_empty():
			node.cover = [mesh.bounds]
		else:
			node.cover = mesh.boxes
			node.cell = mesh.cell_ldu
	nodes[id] = node
	return node


## A part as a person reads its name: "Plate 1 x 2", not "Plate  1 x  2".
static func _named(part: String, library: PartLibrary) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part)
	var name: String = info.name if info != null and not info.name.is_empty() else part
	while name.contains("  "):
		name = name.replace("  ", " ")
	return name.strip_edges().trim_prefix("~")


static func _counted(n: int, one: String) -> String:
	return "%s %s%s" % [Working.comma(n), one, "" if n == 1 else "s"]


## The first few of [param said] that fit in [param room] characters (the
## first always), and how many more of [param total].
static func _list_within(said: Array, total: int, what: String, room: int) -> String:
	var out: String = ""
	var shown: int = 0
	for one: Variant in said.slice(0, NAMED):
		var longer: String = str(one) if shown == 0 else out + "; " + str(one)
		if shown > 0 and longer.length() > room:
			break
		out = longer
		shown += 1
	if total > shown:
		out += "; and %s more" % _counted(total - shown, what)
	return out


## The first few of [param said], and how many more of [param total].
static func _list(said: Array, total: int, what: String) -> String:
	var shown: Array = said.slice(0, NAMED)
	var out: String = "; ".join(PackedStringArray(shown))
	if total > shown.size():
		out += "; and %s more" % _counted(total - shown.size(), what)
	return out
