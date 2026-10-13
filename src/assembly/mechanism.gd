## Mechanisms: which parts turn together, which joints turn, which gears
## mesh, and how far every body turns for one turn of a driver, all read
## off the parts and where they stand. Phase P1a of docs/MECHANISMS.md.
##
## Pure, as Flex is: [method build] takes parts and where they stand and
## hands back bodies, joints and couplings; [method solve] takes drivers
## and hands back every joint's rate; [method pose] says where every part
## stands with the driver turned so far. Nothing here touches a world, a
## scene or a file but the gear table.
##
## The model is kinematic and linear.
##   - A body is parts joined rigidly: studs in sockets, an axle keyed in
##     an axle hole, two pins through two beams, a driving ring on its
##     ridged carrier and on the clutch gear it is pushed into.
##   - A joint is one body turning in another about a fixed line: an axle
##     or a pin in a round hole, a turntable's top on its base.
##   - A coupling is one linear equation between joints' rates: two gears'
##     pitch circles moving together where they touch (spur, crown, bevel,
##     worm, a ring's inside), or a chain's run moving at one speed at both
##     sprockets.
## One unknown per joint, in a tree grown out from the ground: a turn
## relative to the body it hangs from. One equation per coupling, and
## five per joint that closes a loop. Each driver sets its joint's rate.
## Gaussian elimination then says what every joint does, which are left
## free (they follow what carries them, as friction would have it) and
## whether the equations contradict each other (the train is locked, and
## which couplings lock it). While every axis stays fixed relative to the
## body that carries it, the angles are exactly the rates times the
## driver's angle: gear trains, epicyclic trains, differentials and
## turntables. Linkages, whose axes move, are phase P2.
class_name Mechanism
extends RefCounted

## Tooth counts, kinds and holes: data the parts pipeline checks
## (tools/gears.py, tests/test_gears.py). Beside ldd.json rather than in
## assets/knowledge, which the web build leaves out of its pack.
const TABLE := "res://assets/ldraw/gears.json"

## Two pitch circles touch when their centres are this close to r1 + r2
## (or R - r for a ring's inside). A real set's 16 and 20 on a stud's
## diagonal stand 44.72 for 45; a neighbour that is not a mesh is 1.2 or
## more out (docs/MECHANISMS.md, section 2).
const MESH_SLACK := 1.0
## A mesh further than this from its ideal spacing is said to be, LDU: real
## sets stand their gears to 0.3 of it. It still meshes within MESH_SLACK,
## and still turns at its teeth's ratio, but a real pair that far out is
## loose or tight. The 2 LDU lattice stands a worm on a 28 tooth turntable
## 46 apart for 45, and a 16 and a 20 on a stud's diagonal 44.72 for 45.
const SPACING_SLACK := 0.3
## What 32-bit transforms leave of a distance on the lattice: 46 - 45 can
## come out 1.0000001.
const FLOAT_SLACK := 0.001
## Parallel gears mesh when their teeth's planes are this close.
const PLANE_SLACK := 6.0
## A shaft is on a hole's line to within this, LDU, and reaches it to this.
const LINE_SLACK := 1.5
const REACH_SLACK := 2.0
## A stud is in a socket when they are this close.
const STUD_SLACK := 1.5
## An axle or a pin turns in any round bore its size: a Technic hole, the
## hub of a gear with a clutch, a differential's casing.
const ROUND_HOLE := 6.0
## A chain's links sit on a sprocket's pin circle to within this.
const CHAIN_SLACK := 1.0

## The parts a driving ring slides on and is keyed to by their ridges.
## Read from the table at first use.

const Z := Vector3(0, 0, 1)
const Y := Vector3(0, 1, 0)

static var _table: Dictionary = {}


## The gear table: {"gears": part -> spec, "turntables", "driving_rings",
## "ring_carriers", "clutch_gears", "chains"...}. See assets/ldraw/gears.json.
static func table() -> Dictionary:
	if _table.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
		if parsed is Dictionary:
			_table = parsed
	return _table


## One part's entry in the table, empty for a part that is not a gear.
static func spec_of(part_id: String) -> Dictionary:
	return (table().get("gears", {}) as Dictionary).get(part_id, {})


static func _axis_of(word: Variant) -> Vector3:
	match str(word):
		"x":
			return Vector3.RIGHT
		"y":
			return Y
	return Z


# -- what it is made of --------------------------------------------------------


## A part where it stands.
class Piece extends RefCounted:
	var key: int = 0
	var part: String = ""
	var at: Transform3D
	var mesh: Lbm.PartMesh
	var name: String = ""


## A toothed part where it stands.
class Gear extends RefCounted:
	var key: int = 0
	var part: String = ""
	## spur, double (double bevel: as a spur and at right angles), bevel
	## (at right angles only), crown (as a spur, and at right angles to a
	## spur), worm, ring (teeth on the inside of a circle).
	var kind: String = ""
	## Round the whole circle: a quarter ring of 35 is a circle of 140.
	var teeth: int = 0
	var radius: float = 0.0
	## For a mesh at right angles, how far its origin is from its pitch
	## plane.
	var face: float = 0.0
	## Its teeth's plane, on its axis.
	var centre: Vector3
	var axis: Vector3
	## A worm's length.
	var length: float = 0.0
	## A part of a ring: the middle of the arc its teeth go round, and how
	## far either side of it they reach, radians. ZERO for a whole circle.
	var arc_middle := Vector3.ZERO
	var arc_half: float = PI
	## Links of chain round it, as a sprocket; 0 for none.
	var links: int = 0
	var body: int = 0


## Two gears whose teeth are in each other, or two sprockets on one
## chain: where each one's teeth are, and which way they move together
## there. For a gear mesh both points are one; for a worm, the wheel's
## teeth move along the worm's axis as far as the thread advances.
class Coupling extends RefCounted:
	var one: Gear
	var other: Gear
	## parallel, right angle, worm, ring, chain
	var how: String = ""
	var point: Vector3
	var along: Vector3
	var point_other: Vector3
	var along_other: Vector3
	## A worm's thread's advance per radian, signed by its hand.
	var lead: float = 0.0
	## How far apart the two stand, LDU, and how far their pitch circles
	## say they should: centres across the axes (a ring's inside, a worm's
	## axis lines), or from where the axes cross at a right angle. Only
	## whether they mesh depends on these; the ratio is the teeth's.
	var apart: float = 0.0
	var ideal: float = 0.0

	func said() -> String:
		return "%s %d-%d" % [how, one.teeth if one.kind != "worm" else 1,
			other.teeth if other.kind != "worm" else 1]

	## How far off its ideal spacing, LDU: more than it, loose; less, tight.
	func off() -> float:
		return apart - ideal

	## "46 LDU apart for 45, 1 LDU loose" when it is off by more than
	## SPACING_SLACK; "" when it stands as real sets stand theirs.
	func off_said() -> String:
		if how == "chain" or absf(off()) <= SPACING_SLACK:
			return ""
		var from: String = " from where their axes cross" if how == "right angle" else " apart"
		return "%s LDU%s for %s, %s LDU %s" % [Mechanism._tidy(apart), from,
			Mechanism._tidy(ideal), Mechanism._tidy(absf(off())), "loose" if off() > 0.0 else "tight"]


## A joint one body turns on in another: a line, and which body hangs from
## which once the tree is grown from the ground.
class Joint extends RefCounted:
	var a: int = 0
	var b: int = 0
	var point: Vector3
	var way: Vector3
	## A turntable's, a pin's, an axle's: for reading a model back.
	var what: String = ""
	var parent: int = 0
	var child: int = 0
	## Its unknown's column, for a joint of the tree; -1 for one closing a
	## loop.
	var column: int = -1
	var rate: float = 0.0
	var free: bool = false


## A loop of chain: its links and the sprockets it runs on, in order
## round the loop.
class Chain extends RefCounted:
	var links: Array[int] = []
	var sprockets: Array[Gear] = []


# -- the model -----------------------------------------------------------------


var parts: Dictionary = {}       ## key -> Piece
var rest: Dictionary = {}        ## key -> Transform3D, where it stood
var grounded: Array = []
var ground: int = -1
var bodies: Dictionary = {}      ## body -> Array of keys
var gears: Array[Gear] = []
var couplings: Array[Coupling] = []
var chains: Array[Chain] = []
var joints: Array[Joint] = []    ## every joint between two bodies
var tree: Array[Joint] = []      ## the ones the tree is grown along, root first
var closing: Array[Joint] = []   ## the ones that close a loop
var floating: Array = []         ## bodies no joint reaches from the ground
## Gears the table gives a hole that the part's connectors do not have
## on its axis: a part whose hole is drawn without the primitive, or a
## catalogue built before connectivity.py read it. [key, what].
var unseated: Array = []
## Driving rings and what they were found pushed into: [ring key, gear key
## or 0 for neither].
var shifts: Array = []
var _up: Dictionary = {}         ## union-find
var _joint_of: Dictionary = {}   ## body -> its Joint in the tree
var _paths: Dictionary = {}      ## body -> Array[Joint], ground first


## Read the bodies, the joints and the couplings off [param list]: each a
## Dictionary {"key": int, "part": String, "at": Transform3D, "mesh":
## Lbm.PartMesh, "name": String}. "key" is the caller's own (a brick id)
## and defaults to the place in the list from 1; "name" is for reading it
## back. [param held] are keys that are the ground; without any, the body
## with the most parts is.
static func build(list: Array, held: Array = []) -> Mechanism:
	var model := Mechanism.new()
	var next: int = 1
	for entry: Dictionary in list:
		var piece := Piece.new()
		piece.key = int(entry.get("key", next))
		next = maxi(next, piece.key) + 1
		piece.part = str(entry.get("part", ""))
		piece.at = entry.get("at", Transform3D.IDENTITY)
		piece.mesh = entry.get("mesh")
		piece.name = str(entry.get("name", ""))
		model.parts[piece.key] = piece
		model.rest[piece.key] = piece.at
	model.grounded = held.duplicate()
	model._build()
	return model


func body_of(key: int) -> int:
	var at: int = key
	while int(_up.get(at, at)) != at:
		at = int(_up.get(at, at))
	# Halve the path, so a long chain of joins is not walked every time.
	if at != key:
		_up[key] = at
	return at


func _join(one: int, other: int) -> bool:
	var a: int = body_of(one)
	var b: int = body_of(other)
	if a == b:
		return false
	# The smaller key stays the root, so a body's name does not depend on
	# the order things were joined in.
	if a < b:
		_up[b] = a
	else:
		_up[a] = b
	return true


func first_key(part_id: String) -> int:
	var best: int = 0
	for key: int in parts:
		if (parts[key] as Piece).part == part_id and (best == 0 or key < best):
			best = key
	return best


func gear_at(key: int) -> Gear:
	for gear: Gear in gears:
		if gear.key == key:
			return gear
	return null


func gears_of(part_id: String) -> Array[Gear]:
	var out: Array[Gear] = []
	for gear: Gear in gears:
		if gear.part == part_id:
			out.append(gear)
	return out


## The joint [param body] turns on in the tree, or null.
func joint_of(body: int) -> Joint:
	return _joint_of.get(body)


func joint_axis(body: int) -> Vector3:
	var joint: Joint = _joint_of.get(body)
	return joint.way if joint != null else Y


func _build() -> void:
	var pieces: Array = []        ## [key, kind, origin, way, lo, hi]
	var holes: Dictionary = {}    ## bucket -> Array of [key, kind, at, way]
	var studs: Array = []         ## [key, at, way]
	var sockets: Dictionary = {}  ## bucket -> Array of [key, "socket", at, up]
	var shaft_kinds: Dictionary = {}   ## key -> {"axle": true, "pin": true}
	for key: int in parts:
		var piece: Piece = parts[key]
		var mesh: Lbm.PartMesh = piece.mesh
		var at: Transform3D = piece.at
		if mesh == null:
			continue
		var shaft: Array = _shaft_of(mesh)
		if not shaft.is_empty():
			var kinds: Dictionary = {}
			for bit: Array in shaft:
				var origin: Vector3 = at * (bit[1] as Vector3)
				var way: Vector3 = (at.basis * (bit[2] as Vector3)).normalized()
				pieces.append([key, bit[0], origin, way, bit[3], bit[4]])
				kinds[bit[0]] = true
			shaft_kinds[key] = kinds
		for hole: Array in _holes_of(mesh, shaft):
			_bucket_in(holes, [key, hole[0], at * (hole[1] as Vector3),
				(at.basis * (hole[2] as Vector3)).normalized()])
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male":
				studs.append([key, at * connector.position, (at.basis * connector.axis).normalized()])
		for socket: Vector2 in mesh.sockets:
			var point: Vector3 = at * Vector3(socket.x, mesh.bounds.position.y, socket.y)
			_bucket_in(sockets, [key, "socket", point, (at.basis * Vector3.UP).normalized()])

	# An axle keyed in an axle hole is one body with it; an axle or a pin
	# in a round hole turns in it.
	var held: Dictionary = {}    ## "shaft|part" -> [how, origin, way, shaft, holder]
	for bit: Array in pieces:
		var origin: Vector3 = bit[2]
		var way: Vector3 = bit[3]
		for hole: Array in _near_line(holes, origin, way, float(bit[4]), float(bit[5])):
			if hole[0] == bit[0]:
				continue
			if absf((hole[3] as Vector3).dot(way)) < 0.99:
				continue
			var gap: Vector3 = (hole[2] as Vector3) - origin
			var along: float = gap.dot(way)
			if along < float(bit[4]) - REACH_SLACK or along > float(bit[5]) + REACH_SLACK:
				continue
			if (gap - way * along).length() > LINE_SLACK:
				continue
			if bit[1] == "pin" and hole[1] == "axle":
				continue
			var how: String = "keyed" if bit[1] == "axle" and hole[1] == "axle" else "turns"
			var name: String = "%d|%d" % [bit[0], hole[0]]
			if held.has(name) and held[name][0] == "keyed":
				continue
			held[name] = [how, origin, way, bit[0], hole[0]]
	var shafts_turning: Dictionary = {}   ## shaft key -> Array of [holder, origin, way]
	for name: String in held:
		var it: Array = held[name]
		if it[0] == "keyed":
			_join(it[3], it[4])
		else:
			if not shafts_turning.has(it[3]):
				shafts_turning[it[3]] = []
			(shafts_turning[it[3]] as Array).append([it[4], it[1], it[2]])
	# Studs in sockets are one body.
	for stud: Array in studs:
		for socket: Array in _around(sockets, stud[1]):
			if socket[0] == stud[0]:
				continue
			if (socket[2] as Vector3).distance_to(stud[1]) > STUD_SLACK:
				continue
			if (socket[3] as Vector3).dot(stud[2]) < 0.95:
				continue
			_join(stud[0], socket[0])
	# And so is a part standing on studs that records no socket for them: a
	# turntable's base on a plate, a beam's holes over a plate's studs.
	_rest_on_studs(studs)
	# A driving ring is keyed to the ridged part it slides on, and to the
	# clutch gear it is pushed into.
	_shift()
	# A pin carries nothing of its own: what it joins turn on its line
	# against each other, and a pin in one part only is part of it.
	var sizes: Dictionary = {}
	for key: int in parts:
		var body: int = body_of(key)
		sizes[body] = int(sizes.get(body, 0)) + 1
	var lines: Array = []    ## [a, b, origin, way, what]
	for shaft: int in shafts_turning:
		var holders: Array = shafts_turning[shaft]
		var kinds: Dictionary = shaft_kinds.get(shaft, {})
		var pin_only: bool = kinds.has("pin") and not kinds.has("axle")
		var keyed_to_something: bool = int(sizes.get(body_of(shaft), 1)) > 1
		var what: String = (parts[shaft] as Piece).part
		if pin_only and not keyed_to_something:
			_join(shaft, holders[0][0])
			for n: int in range(1, holders.size()):
				lines.append([holders[0][0], holders[n][0], holders[n][1], holders[n][2], what])
		else:
			for holder: Array in holders:
				lines.append([shaft, holder[0], holder[1], holder[2], what])
	# A differential's planets turn on the stubs inside its casing.
	_stubs(lines)
	# A turntable's top turns on its base.
	var turntables: Dictionary = table().get("turntables", {})
	var bases: Dictionary = {}   ## base part -> Array of keys
	for key: int in parts:
		var id: String = (parts[key] as Piece).part
		for top: String in turntables:
			if str(turntables[top]) == id:
				if not bases.has(id):
					bases[id] = []
				(bases[id] as Array).append(key)
	for key: int in parts:
		var base_id: String = str(turntables.get((parts[key] as Piece).part, ""))
		if base_id.is_empty():
			continue
		var at: Transform3D = (parts[key] as Piece).at
		for other: int in bases.get(base_id, []):
			var there: Transform3D = (parts[other] as Piece).at
			if there.origin.distance_to(at.origin) < LINE_SLACK \
					and absf((there.basis * Y).normalized().dot((at.basis * Y).normalized())) > 0.99:
				lines.append([key, other, at.origin, (at.basis * Y).normalized(), "turntable"])
	for key: int in grounded:
		_join(grounded[0], key)
	# Two joints between the same two bodies on different lines hold them
	# together: two pins through two beams.
	var changed: bool = true
	while changed:
		changed = false
		var by_pair: Dictionary = {}
		for line: Array in lines:
			var a: int = body_of(line[0])
			var b: int = body_of(line[1])
			if a == b:
				continue
			var pair: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			if not by_pair.has(pair):
				by_pair[pair] = []
			(by_pair[pair] as Array).append(line)
		for pair: Vector2i in by_pair:
			var found: Array = by_pair[pair]
			var first: Array = found[0]
			for line: Array in found:
				if not _same_line(first[2], first[3], line[2], line[3]):
					changed = _join(first[0], first[1]) or changed
					break
	joints.clear()
	var seen: Dictionary = {}
	for line: Array in lines:
		var a: int = body_of(line[0])
		var b: int = body_of(line[1])
		if a == b:
			continue
		var pair: Vector2i = Vector2i(mini(a, b), maxi(a, b))
		if seen.has(pair):
			continue
		seen[pair] = true
		var joint := Joint.new()
		joint.a = a
		joint.b = b
		joint.point = line[2]
		joint.way = line[3]
		joint.what = line[4]
		joints.append(joint)
	bodies.clear()
	for key: int in parts:
		var body: int = body_of(key)
		if not bodies.has(body):
			bodies[body] = []
		(bodies[body] as Array).append(key)
	ground = body_of(grounded[0]) if not grounded.is_empty() else _largest()
	_grow()
	_find_gears()
	_find_couplings()
	_rims()


## Join each part to the studs it stands on: its underside at the studs'
## foot, the studs under it and clear of its edges. A stud in a socket is
## joined already; this is what stands on studs without one, so that a
## turntable's base resting on a plate, a frame or the baseplate is held
## still with it rather than read as floating. [param studs] are
## [key, foot, way], as _build gathers them.
func _rest_on_studs(studs: Array) -> void:
	if studs.is_empty():
		return
	var at_foot: Dictionary = {}   ## bucket -> Array of [key, "stud", foot, way]
	for stud: Array in studs:
		_bucket_in(at_foot, [stud[0], "stud", stud[1], stud[2]])
	for key: int in parts:
		var piece: Piece = parts[key]
		if piece.mesh == null:
			continue
		var box: AABB = (piece.at * piece.mesh.bounds).abs().grow(STUD_SLACK)
		var lo: Vector3i = _bucket_of(box.position)
		var hi: Vector3i = _bucket_of(box.end)
		var inverse: Transform3D = piece.at.affine_inverse()
		for x: int in range(lo.x, hi.x + 1):
			for y: int in range(lo.y, hi.y + 1):
				for z: int in range(lo.z, hi.z + 1):
					for stud: Array in at_foot.get(Vector3i(x, y, z), []):
						if stud[0] != key and body_of(stud[0]) != body_of(key) \
								and _stands_on(piece.mesh.bounds, inverse, stud[2], stud[3]):
							_join(key, stud[0])


## How far inside a part's edge a stud must be to be under it, LDU: a
## stud is 6 across its middle, and one at a 1 x 1's middle is 10 in.
const STUD_INSET := 4.0


## Whether a part whose box is [param box], placed by the inverse of
## [param inverse], stands on a stud whose foot is at [param foot] pointing
## [param way]: the face of its box that way at the foot, the stud within
## the face.
static func _stands_on(box: AABB, inverse: Transform3D, foot: Vector3, way: Vector3) -> bool:
	var here: Vector3 = inverse * foot
	var up: Vector3 = (inverse.basis * way).normalized()
	for n: int in 3:
		if absf(up[n]) < 0.99:
			continue
		var face: float = box.position[n] if up[n] > 0.0 else box.end[n]
		if absf(here[n] - face) > STUD_SLACK:
			return false
		for m: int in 3:
			if m != n and (here[m] < box.position[m] + STUD_INSET
					or here[m] > box.end[m] - STUD_INSET):
				return false
		return true
	return false


## Lines inside a part that a gear turns on, from the table's "stubs": the
## planet of a 62821 differential sits on a round stub in its casing that
## no connector records. Adds [gear, part, point, way, "stub"] to [param
## lines].
func _stubs(lines: Array) -> void:
	var with: Array[int] = []
	var toothed: Array[int] = []
	for key: int in parts:
		var spec: Dictionary = spec_of((parts[key] as Piece).part)
		if spec.has("stubs"):
			with.append(key)
		if not spec.is_empty() and str(spec.get("hole", "none")) != "none":
			toothed.append(key)
	for key: int in with:
		var at: Transform3D = (parts[key] as Piece).at
		for stub: Array in spec_of((parts[key] as Piece).part)["stubs"]:
			var point: Vector3 = at * Vector3(float(stub[0]), float(stub[1]), float(stub[2]))
			var way: Vector3 = (at.basis * Vector3(float(stub[3]), float(stub[4]),
				float(stub[5]))).normalized()
			var half: float = float(stub[6])
			for gear: int in toothed:
				if gear == key:
					continue
				var there: Transform3D = (parts[gear] as Piece).at
				var axis: Vector3 = (there.basis * _axis_of(spec_of((parts[gear] as Piece).part)
					.get("axis", "z"))).normalized()
				if absf(axis.dot(way)) < 0.99:
					continue
				var gap: Vector3 = there.origin - point
				var along: float = gap.dot(way)
				if absf(along) > half + REACH_SLACK or (gap - way * along).length() > LINE_SLACK:
					continue
				lines.append([gear, key, point, way, "stub"])


## A ring that nothing it is fixed to turns on, carried round its rim by
## rollers as 42055's bucket wheel is: it turns about its own centre, on
## whatever carries a gear meshing its inside, or the mesh would come
## apart. Such a joint is said as "rim".
func _rims() -> void:
	var added: bool = true
	while added:
		added = false
		for coupling: Coupling in couplings:
			if coupling.how != "ring" or not floating.has(coupling.one.body) \
					or floating.has(coupling.other.body):
				continue
			var carrier: Joint = _joint_of.get(coupling.other.body)
			var joint := Joint.new()
			joint.a = coupling.one.body
			joint.b = carrier.parent if carrier != null else ground
			joint.point = coupling.one.centre
			joint.way = coupling.one.axis
			joint.what = "rim"
			joints.append(joint)
			_grow()
			added = true
			break


func _largest() -> int:
	var best: int = -1
	for body: int in bodies:
		if best < 0 or (bodies[body] as Array).size() > (bodies[best] as Array).size():
			best = body
	return best


## What an axle or a pin does in a connector, if it is a hole: "axle"
## keys it, "round" lets it turn.
static func _hole_kind(connector: Lbm.Connector) -> String:
	if connector.kind == "axle_hole":
		return "axle"
	if connector.kind == "pin_hole":
		return "round"
	if connector.kind == "bore" and absf(connector.radius - ROUND_HOLE) < 0.6:
		return "round"
	return ""


## The tree of joints from the ground outwards, breadth first.
func _grow() -> void:
	tree.clear()
	closing.clear()
	_joint_of.clear()
	_paths.clear()
	var touching: Dictionary = {}   ## body -> Array of Joint
	for joint: Joint in joints:
		for end: int in [joint.a, joint.b]:
			if not touching.has(end):
				touching[end] = []
			(touching[end] as Array).append(joint)
	var reached: Dictionary = {ground: true}
	var frontier: Array = [ground]
	var used: Dictionary = {}
	while not frontier.is_empty():
		var body: int = frontier.pop_front()
		for joint: Joint in touching.get(body, []):
			if used.has(joint):
				continue
			used[joint] = true
			var other: int = joint.b if joint.a == body else joint.a
			joint.parent = body
			joint.child = other
			if reached.has(other):
				closing.append(joint)
				continue
			reached[other] = true
			joint.column = tree.size()
			tree.append(joint)
			_joint_of[other] = joint
			frontier.append(other)
	floating.clear()
	for body: int in bodies:
		if not reached.has(body):
			floating.append(body)


func _find_gears() -> void:
	gears.clear()
	unseated.clear()
	for key: int in parts:
		var piece: Piece = parts[key]
		var spec: Dictionary = spec_of(piece.part)
		if spec.is_empty():
			continue
		var specs: Array = [spec]
		specs.append_array(spec.get("also", []))
		for one: Dictionary in specs:
			gears.append(_gear(piece, one))
		# What it turns on, said by its own connectors: a gear the table
		# says has a hole, with none on its axis, will float.
		var hole: String = str(spec.get("hole", "none"))
		var local_axis: Vector3 = _axis_of(spec.get("axis", "z"))
		if hole != "none" and piece.mesh != null \
				and not _has_hole(piece.mesh, Vector3.ZERO, local_axis):
			unseated.append([key, "%s: no %s hole on its axis in its connectors" % [piece.part,
				hole]])


func _gear(piece: Piece, spec: Dictionary) -> Gear:
	var at: Transform3D = piece.at
	var gear := Gear.new()
	gear.key = piece.key
	gear.part = piece.part
	gear.body = body_of(piece.key)
	gear.kind = str(spec.get("kind", "spur"))
	var local_axis: Vector3 = _axis_of(spec.get("axis", "z"))
	gear.axis = (at.basis * local_axis).normalized()
	gear.centre = at * (local_axis * float(spec.get("plane", 0.0)))
	gear.face = float(spec.get("face", 0.0))
	if gear.kind == "worm":
		gear.teeth = 1
		gear.radius = float(spec.get("radius", 10.0))
		gear.length = float(spec.get("length", 0.0))
		if gear.length <= 0.0 and piece.mesh != null:
			gear.length = absf((piece.mesh.bounds.size * local_axis).length())
	else:
		gear.teeth = int(spec.get("circle", spec.get("teeth", 0)))
		gear.radius = float(table().get("ldu_per_tooth", 1.25)) * float(gear.teeth)
	if spec.has("arc"):
		var arc: Array = spec["arc"]
		gear.arc_middle = (at.basis * Vector3(float(arc[0]), float(arc[1]),
			float(arc[2]))).normalized()
		gear.arc_half = deg_to_rad(float(arc[3]))
	gear.links = int(Flex.SPROCKETS.get(piece.part, 0))
	return gear


## Whether a part's connectors have a hole through [param centre] along
## [param axis], in its own frame.
static func _has_hole(mesh: Lbm.PartMesh, centre: Vector3, axis: Vector3) -> bool:
	for connector: Lbm.Connector in mesh.connectors:
		if _hole_kind(connector).is_empty():
			continue
		if absf(connector.axis.normalized().dot(axis)) < 0.99:
			continue
		var gap: Vector3 = connector.position - centre
		if (gap - axis * gap.dot(axis)).length() < LINE_SLACK:
			return true
	return false


func _find_couplings() -> void:
	couplings.clear()
	for i: int in gears.size():
		for j: int in range(i + 1, gears.size()):
			var one: Gear = gears[i]
			var other: Gear = gears[j]
			if one.body == other.body:
				continue
			var found: Coupling = null
			if one.kind == "worm" or other.kind == "worm":
				found = _worm_mesh(one, other) if one.kind == "worm" else _worm_mesh(other, one)
			elif one.kind == "ring" or other.kind == "ring":
				found = _ring_mesh(one, other) if one.kind == "ring" else _ring_mesh(other, one)
			else:
				found = _gear_mesh(one, other)
			if found != null:
				couplings.append(found)
	_find_chains()


func _gear_mesh(one: Gear, other: Gear) -> Coupling:
	var dot: float = one.axis.dot(other.axis)
	var gap: Vector3 = other.centre - one.centre
	if absf(dot) > 0.999:
		if one.kind == "bevel" or other.kind == "bevel":
			return null
		var along: float = gap.dot(one.axis)
		if absf(along) > PLANE_SLACK:
			return null
		var across: Vector3 = gap - one.axis * along
		var ideal: float = one.radius + other.radius
		if absf(across.length() - ideal) > MESH_SLACK + FLOAT_SLACK:
			return null
		var mesh := Coupling.new()
		mesh.one = one
		mesh.other = other
		mesh.how = "parallel"
		mesh.apart = across.length()
		mesh.ideal = ideal
		# Where the teeth meet: the line between the centres split as the
		# radii are, so each gear's lever is its radius times one factor and
		# the ratio is the teeth's however far off the spacing is. On a
		# stud's diagonal a 16 and a 20 stand 44.72 for 45, and read at the
		# 16's pitch circle the 20 turned 16/19.72 of it, not 16/20.
		mesh.point = one.centre + across.normalized() * mesh.apart * one.radius / ideal
		mesh.along = one.axis.cross(mesh.point - one.centre).normalized()
		mesh.point_other = mesh.point
		mesh.along_other = mesh.along
		return mesh
	if absf(dot) > 0.02:
		return null
	# At right angles: a bevel with a bevel, or a crown with a spur.
	var faces: bool = (one.kind in ["bevel", "double"] and other.kind in ["bevel", "double"]) \
		or (one.kind == "crown" and other.kind in ["spur", "double"]) \
		or (other.kind == "crown" and one.kind in ["spur", "double"])
	if not faces:
		return null
	var normal: Vector3 = one.axis.cross(other.axis).normalized()
	if absf(gap.dot(normal)) > LINE_SLACK:
		return null
	# Where the two axes cross.
	var t: float = _crossing(one.centre, one.axis, other.centre, other.axis)
	var cross: Vector3 = one.centre + one.axis * t
	var d_one: float = one.centre.distance_to(cross)
	var d_other: float = other.centre.distance_to(cross)
	var face_one: float = one.face if one.kind != "spur" else 0.0
	var face_other: float = other.face if other.kind != "spur" else 0.0
	if absf(d_one - other.radius - face_one) > LINE_SLACK \
			or absf(d_other - one.radius - face_other) > LINE_SLACK:
		return null
	var toward_one: Vector3 = (one.centre - cross).normalized()
	var toward_other: Vector3 = (other.centre - cross).normalized()
	var mesh := Coupling.new()
	mesh.one = one
	mesh.other = other
	mesh.how = "right angle"
	# The worse of the two gears' distances from the crossing. The point
	# below is a pitch radius from each axis wherever they stand, so the
	# ratio is the teeth's already.
	if absf(d_one - other.radius - face_one) >= absf(d_other - one.radius - face_other):
		mesh.apart = d_one
		mesh.ideal = other.radius + face_one
	else:
		mesh.apart = d_other
		mesh.ideal = one.radius + face_other
	mesh.point = cross + toward_one * other.radius + toward_other * one.radius
	mesh.along = one.axis.cross(mesh.point - one.centre).normalized()
	mesh.point_other = mesh.point
	mesh.along_other = mesh.along
	return mesh


## A gear inside a ring: centres R - r apart in one plane, the teeth
## meeting on the ring's pitch circle, where the ring's arc reaches.
## Both turn the same way.
func _ring_mesh(ring: Gear, gear: Gear) -> Coupling:
	if gear.kind in ["ring", "bevel", "worm"] or absf(ring.axis.dot(gear.axis)) < 0.999:
		return null
	var gap: Vector3 = gear.centre - ring.centre
	var along: float = gap.dot(ring.axis)
	if absf(along) > PLANE_SLACK:
		return null
	var across: Vector3 = gap - ring.axis * along
	var ideal: float = ring.radius - gear.radius
	if absf(across.length() - ideal) > MESH_SLACK + FLOAT_SLACK:
		return null
	var toward: Vector3 = across.normalized()
	if ring.arc_middle != Vector3.ZERO and toward.angle_to(ring.arc_middle) > ring.arc_half:
		return null
	var mesh := Coupling.new()
	mesh.one = ring
	mesh.other = gear
	mesh.how = "ring"
	mesh.apart = across.length()
	mesh.ideal = ideal
	# On the line from the ring's centre through the gear's, as far out as
	# makes the levers R and r times one factor: the teeth's ratio.
	mesh.point = ring.centre + toward * mesh.apart * ring.radius / ideal
	mesh.along = ring.axis.cross(toward).normalized()
	mesh.point_other = mesh.point
	mesh.along_other = mesh.along
	return mesh


func _worm_mesh(worm: Gear, wheel: Gear) -> Coupling:
	if wheel.kind in ["worm", "ring"] or absf(worm.axis.dot(wheel.axis)) > 0.02:
		return null
	var gap: Vector3 = worm.centre - wheel.centre
	if absf(gap.dot(wheel.axis)) > 3.0:
		return null
	var normal: Vector3 = worm.axis.cross(wheel.axis).normalized()
	var ideal: float = worm.radius + wheel.radius
	if absf(absf(gap.dot(normal)) - ideal) > MESH_SLACK + FLOAT_SLACK:
		return null
	var t: float = _crossing(worm.centre, worm.axis, wheel.centre, wheel.axis)
	if absf(t) > worm.length * 0.5 + REACH_SLACK:
		return null
	var on_worm: Vector3 = worm.centre + worm.axis * t
	var toward: Vector3 = normal * (-signf(gap.dot(normal)))
	var mesh := Coupling.new()
	mesh.one = worm
	mesh.other = wheel
	mesh.how = "worm"
	mesh.apart = absf(gap.dot(normal))
	mesh.ideal = ideal
	# The wheel's lever is its radius and the thread's advance a tooth a
	# turn, both times one factor, so a 28 turns once in 28 however far off
	# the lattice stands it: 46 for 45 read at the worm's own radius was
	# 1/28.8.
	var scale: float = mesh.apart / ideal
	mesh.point = on_worm + toward * worm.radius * scale
	mesh.along = worm.axis
	mesh.point_other = mesh.point
	mesh.along_other = mesh.along
	# A worm advances one tooth a turn: pi times the module. Which way its
	# thread runs is not yet read from the part; the ratio does not depend
	# on it, the direction does.
	mesh.lead = float(table().get("worm_lead", PI * 2.5)) / TAU \
		* float(table().get("worm_hand", 1.0)) * scale
	return mesh


## Chains: links that hook onto each other, and the sprockets at least two
## of their pins sit on. Each pair of sprockets next to each other round
## the loop is one coupling: the run between them moves at one speed, so
## each turns at that speed over its own radius, both the same way.
func _find_chains() -> void:
	chains.clear()
	var kinds: Dictionary = {str(Flex.KINDS["chain"]["link"]): true,
		str(Flex.KINDS["tread"]["link"]): true}
	var link_keys: Array[int] = []
	for key: int in parts:
		if kinds.has((parts[key] as Piece).part):
			link_keys.append(key)
	if link_keys.is_empty():
		return
	# Links hook onto the next one's pins: one link's far pin is the next
	# one's origin.
	var pitch: float = Flex.CHAIN_PITCH
	var at_pins: Dictionary = {}
	for key: int in link_keys:
		_bucket_in(at_pins, [key, "link", (parts[key] as Piece).at.origin, Vector3.ZERO])
	var group: Dictionary = {}
	for key: int in link_keys:
		group[key] = key
	var find := func(k: int) -> int:
		var at: int = k
		while int(group[at]) != at:
			at = int(group[at])
		return at
	for key: int in link_keys:
		var at: Transform3D = (parts[key] as Piece).at
		var far: Vector3 = at.origin - at.basis.z.normalized() * pitch
		for row: Array in _around(at_pins, far):
			if row[0] != key and (row[2] as Vector3).distance_to(far) < CHAIN_SLACK * 2.0:
				var a: int = find.call(key)
				var b: int = find.call(int(row[0]))
				if a != b:
					group[maxi(a, b)] = mini(a, b)
	var loops: Dictionary = {}
	for key: int in link_keys:
		var root: int = find.call(key)
		if not loops.has(root):
			loops[root] = []
		(loops[root] as Array).append(key)
	for root: int in loops:
		var chain := Chain.new()
		for key: int in loops[root]:
			chain.links.append(key)
		for gear: Gear in gears:
			if gear.links <= 0:
				continue
			var circle: float = pitch * 0.5 / sin(PI / float(gear.links))
			var on: int = 0
			for key: int in chain.links:
				var gap: Vector3 = (parts[key] as Piece).at.origin - gear.centre
				var along: float = gap.dot(gear.axis)
				if absf(along) < CHAIN_SLACK * 2.0 \
						and absf((gap - gear.axis * along).length() - circle) < CHAIN_SLACK:
					on += 1
			if on >= 2:
				chain.sprockets.append(gear)
		if chain.sprockets.size() < 2:
			chains.append(chain)
			continue
		_order_round(chain.sprockets)
		for n: int in range(chain.sprockets.size() - 1):
			var coupling: Coupling = _chain_run(chain.sprockets[n], chain.sprockets[n + 1], pitch)
			if coupling != null:
				couplings.append(coupling)
		chains.append(chain)


## Sprockets in the order they lie about their middle, as Flex.belt goes
## round them.
static func _order_round(sprockets: Array[Gear]) -> void:
	var axis: Vector3 = sprockets[0].axis
	var u: Vector3 = (Vector3.UP - axis * axis.dot(Vector3.UP))
	if u.length_squared() < 0.01:
		u = Vector3.RIGHT - axis * axis.x
	u = u.normalized()
	var v: Vector3 = axis.cross(u)
	var middle := Vector3.ZERO
	for one: Gear in sprockets:
		middle += one.centre
	middle /= float(sprockets.size())
	sprockets.sort_custom(func(a: Gear, b: Gear) -> bool:
		var pa: Vector3 = a.centre - middle
		var pb: Vector3 = b.centre - middle
		return atan2(pa.dot(v), pa.dot(u)) < atan2(pb.dot(v), pb.dot(u)))


## One run of chain between two sprockets in one plane: each turns at the
## chain's speed over its own radius, the radius a whole turn of its links
## makes (links times pitch over two pi), so the ratio is the links'.
func _chain_run(one: Gear, other: Gear, pitch: float) -> Coupling:
	if absf(one.axis.dot(other.axis)) < 0.995:
		return null
	var axis: Vector3 = one.axis
	var gap: Vector3 = other.centre - one.centre
	gap -= axis * gap.dot(axis)
	if gap.length() < 1.0:
		return null
	var out: Vector3 = axis.cross(gap.normalized())
	var coupling := Coupling.new()
	coupling.one = one
	coupling.other = other
	coupling.how = "chain"
	coupling.point = one.centre + out * (float(one.links) * pitch / TAU)
	coupling.point_other = other.centre + out * (float(other.links) * pitch / TAU)
	# Both measured about one axis, the same way, so a sprocket on an axle
	# that points the other way still reads as turning with the chain.
	coupling.along = axis.cross(out).normalized()
	coupling.along_other = coupling.along
	return coupling


## Driving rings: keyed by their ridges to the part they slide on, and
## pushed into a clutch gear's face or standing between two. Each ring is
## said in [member shifts], with the gear it drives or 0.
func _shift() -> void:
	shifts.clear()
	var rings: Dictionary = table().get("driving_rings", {})
	var carriers: Dictionary = table().get("ring_carriers", {})
	var clutches: Dictionary = table().get("clutch_gears", {})
	if rings.is_empty():
		return
	var ring_keys: Array[int] = []
	var carrier_keys: Array[int] = []
	var clutch_keys: Array[int] = []
	for key: int in parts:
		var id: String = (parts[key] as Piece).part
		if rings.has(id):
			ring_keys.append(key)
		if carriers.has(id):
			carrier_keys.append(key)
		if clutches.has(id):
			clutch_keys.append(key)
	for ring: int in ring_keys:
		var spec: Dictionary = rings[(parts[ring] as Piece).part]
		var at: Transform3D = (parts[ring] as Piece).at
		var way: Vector3 = (at.basis * _axis_of(spec.get("axis", "z"))).normalized()
		var reach: float = float(spec.get("reach", 10.0))
		var span := Vector2(-reach, reach)
		for carrier: int in carrier_keys:
			var other: Dictionary = carriers[(parts[carrier] as Piece).part]
			var there: Transform3D = (parts[carrier] as Piece).at
			var its: Vector2 = _span_on(there, other, at.origin, way)
			if its != Vector2.INF and its.x < span.y and its.y > span.x:
				_join(ring, carrier)
		var driven: int = 0
		for gear: int in clutch_keys:
			var other: Dictionary = clutches[(parts[gear] as Piece).part]
			var there: Transform3D = (parts[gear] as Piece).at
			var its: Vector2 = _span_on(there, other, at.origin, way)
			if its == Vector2.INF:
				continue
			# The ring's teeth reach into the gear's clutch past its face.
			var into: float = minf(span.y, its.y) - maxf(span.x, its.x)
			if into >= float(spec.get("engage", 1.0)):
				_join(ring, gear)
				driven = gear
		shifts.append([ring, driven])


## Where a coaxial part reaches along a line through [param origin] along
## [param way]: its span from its spec's "reach" (half its length along its
## axis, or [lo, hi]) about its origin, or Vector2.INF when it is off the
## line.
static func _span_on(at: Transform3D, spec: Dictionary, origin: Vector3, way: Vector3) -> Vector2:
	var axis: Vector3 = (at.basis * _axis_of(spec.get("axis", "z"))).normalized()
	if absf(axis.dot(way)) < 0.99:
		return Vector2.INF
	var gap: Vector3 = at.origin - origin
	var along: float = gap.dot(way)
	if (gap - way * along).length() > LINE_SLACK:
		return Vector2.INF
	var reach: Variant = spec.get("reach", 10.0)
	var lo: float = float((reach as Array)[0]) if reach is Array else -float(reach)
	var hi: float = float((reach as Array)[1]) if reach is Array else float(reach)
	var sense: float = signf(axis.dot(way))
	var a: float = along + lo * sense
	var b: float = along + hi * sense
	return Vector2(minf(a, b), maxf(a, b))


## Along the first line, where it comes nearest the second.
static func _crossing(p: Vector3, u: Vector3, q: Vector3, v: Vector3) -> float:
	var w: Vector3 = p - q
	var b: float = u.dot(v)
	var d: float = u.dot(w)
	var e: float = v.dot(w)
	var denominator: float = 1.0 - b * b
	if absf(denominator) < 1e-9:
		return 0.0
	return (b * e - d) / denominator


static func _same_line(p: Vector3, u: Vector3, q: Vector3, v: Vector3) -> bool:
	if absf(u.dot(v)) < 0.99:
		return false
	var gap: Vector3 = q - p
	return (gap - u * gap.dot(u)).length() <= LINE_SLACK


## The lengths of axle and pin a part is, in its own frame: [kind, a point
## on the line, its way, from, to], each line of its axles and pins in
## turn. An axle pin is two, the axle the way its axle connector points.
## A pin long with a hole across its middle (87082) or an axle connector
## with an axle of its own is both these and the holes [method _holes_of]
## gives.
static func _shaft_of(mesh: Lbm.PartMesh) -> Array:
	var lines: Array = []   ## [origin, way, [males]]
	for connector: Lbm.Connector in mesh.connectors:
		if (connector.kind != "axle" and connector.kind != "pin") or connector.gender != "male":
			continue
		var found: bool = false
		for line: Array in lines:
			if _same_line(line[0], line[1], connector.position, connector.axis.normalized()):
				(line[2] as Array).append(connector)
				found = true
				break
		if not found:
			lines.append([connector.position, connector.axis.normalized(), [connector]])
	var out: Array = []
	for line: Array in lines:
		var origin: Vector3 = line[0]
		var way: Vector3 = line[1]
		var males: Array = line[2]
		# Its reach along the line: the box, corner by corner.
		var lo: float = INF
		var hi: float = -INF
		for n: int in 8:
			var corner: Vector3 = mesh.bounds.position + mesh.bounds.size * Vector3(n & 1,
				(n >> 1) & 1, (n >> 2) & 1)
			var along: float = (corner - origin).dot(way)
			lo = minf(lo, along)
			hi = maxf(hi, along)
		var axles: Array = males.filter(func(c: Lbm.Connector) -> bool: return c.kind == "axle")
		var pins: Array = males.filter(func(c: Lbm.Connector) -> bool: return c.kind == "pin")
		if pins.is_empty():
			out.append(["axle", origin, way, lo, hi])
		elif axles.is_empty():
			out.append(["pin", origin, way, lo, hi])
		else:
			var axle: Lbm.Connector = axles[0]
			var split: float = (axle.position - origin).dot(way)
			if axle.axis.dot(way) > 0.0:
				out.append_array([["pin", origin, way, lo, split], ["axle", origin, way, split, hi]])
			else:
				out.append_array([["axle", origin, way, lo, split], ["pin", origin, way, split, hi]])
	return out


## A part's holes, in its own frame, as [kind, middle, way]: those off the
## lines of its own axles and pins. One on such a line is the part's own (a
## catalogue built before connectivity.py stopped reading an axle's notch
## as a hole has one).
static func _holes_of(mesh: Lbm.PartMesh, shafts: Array) -> Array:
	var out: Array = []
	for connector: Lbm.Connector in mesh.connectors:
		var kind: String = _hole_kind(connector)
		if kind.is_empty():
			continue
		var middle: Vector3 = connector.position + connector.axis * connector.length * 0.5
		var own: bool = false
		for bit: Array in shafts:
			if _same_line(bit[1], bit[2], middle, connector.axis.normalized()):
				own = true
				break
		if not own:
			out.append([kind, middle, connector.axis.normalized()])
	return out


static func _bucket_of(at: Vector3) -> Vector3i:
	return Vector3i(floori(at.x / 20.0), floori(at.y / 20.0), floori(at.z / 20.0))


static func _bucket_in(buckets: Dictionary, row: Array) -> void:
	var box: Vector3i = _bucket_of(row[2])
	if not buckets.has(box):
		buckets[box] = []
	(buckets[box] as Array).append(row)


static func _around(buckets: Dictionary, at: Vector3) -> Array:
	var out: Array = []
	var home: Vector3i = _bucket_of(at)
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			for dz: int in [-1, 0, 1]:
				out.append_array(buckets.get(home + Vector3i(dx, dy, dz), []))
	return out


## What is in the buckets a length of line passes through.
static func _near_line(buckets: Dictionary, origin: Vector3, way: Vector3, lo: float,
		hi: float) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var at: float = lo - REACH_SLACK
	while at <= hi + REACH_SLACK + 10.0:
		for row: Array in _around(buckets, origin + way * minf(at, hi + REACH_SLACK)):
			if not seen.has(row):
				seen[row] = true
				out.append(row)
		at += 10.0
	return out


# -- solving --------------------------------------------------------------------


## The joints from the ground to [param body], root first.
func path(body: int) -> Array:
	if _paths.has(body):
		return _paths[body]
	var out: Array = []
	var at: int = body
	while _joint_of.has(at):
		var joint: Joint = _joint_of[at]
		out.push_front(joint)
		at = joint.parent
	_paths[body] = out
	return out


## A coupling's equation, as {column: coefficient}: the teeth at its
## points move together along its directions. For a worm, the wheel's
## teeth move along the worm's axis as far as the thread advances.
func _row(coupling: Coupling) -> Dictionary:
	var row: Dictionary = {}
	var sides: Array = [[coupling.one, coupling.point, coupling.along, -1.0],
		[coupling.other, coupling.point_other, coupling.along_other, 1.0]]
	for side: Array in sides:
		var gear: Gear = side[0]
		var point: Vector3 = side[1]
		var along: Vector3 = side[2]
		for joint: Joint in path(gear.body):
			var moves: float = joint.way.cross(point - joint.point).dot(along)
			moves += coupling.lead * joint.way.dot(along)
			row[joint.column] = float(row.get(joint.column, 0.0)) + float(side[3]) * moves
	return row


## A joint closing a loop, as equations: what it joins may only turn
## against each other about its line. Five of them: no turn about two lines
## across it, and its point not moving, either way round. Linear, as the
## couplings are, while every axis stays where it is.
func _loop_rows(joint: Joint) -> Array:
	var across: Vector3 = joint.way.cross(Vector3.UP if absf(joint.way.y) < 0.9
		else Vector3.RIGHT).normalized()
	var other: Vector3 = joint.way.cross(across).normalized()
	var rows: Array = []
	for n: int in 5:
		var row: Dictionary = {}
		for side: Array in [[joint.parent, -1.0], [joint.child, 1.0]]:
			for one: Joint in path(int(side[0])):
				var value: float = 0.0
				if n == 0:
					value = one.way.dot(across)
				elif n == 1:
					value = one.way.dot(other)
				else:
					value = one.way.cross(joint.point - one.point)[n - 2]
				row[one.column] = float(row.get(one.column, 0.0)) + float(side[1]) * value
		rows.append(row)
	return rows


## Every joint's rate for the [param drivers]: body -> how fast it turns
## about its own joint's axis, against the ground (1.0 to drive it, 0.0 to
## hold it). Returns {ok, locked, said, culprits (each coupling whose removal
## frees a locked train, said), meshes (the same couplings, each [the key of
## one gear, the other's], for naming and showing the parts), freedoms (how
## many rates nothing decides), free (the bodies whose own turn those leave
## undecided)}. A rate nothing decides is left at 0 relative to what carries
## it, as friction would have it: sails threaded on an axle go round with it.
func solve(drivers: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": false, "locked": false, "said": "", "culprits": [], "meshes": [],
		"free": [], "freedoms": 0}
	var fixed: Array = []   ## [row, rhs]
	for body: int in drivers:
		var joint: Joint = _joint_of.get(body)
		if joint == null:
			out["said"] = "a driver turns on nothing (body %d)" % body
			return out
		var row: Dictionary = {}
		for one: Joint in path(body):
			row[one.column] = float(row.get(one.column, 0.0)) + one.way.dot(joint.way)
		fixed.append([row, float(drivers[body])])
	var held: Array = []
	for loop: Joint in closing:
		for row: Dictionary in _loop_rows(loop):
			held.append([row, 0.0])
	# A coupling with a floating gear says nothing: what that gear turns on
	# is not known, and taking it for the ground would lock the train.
	var used: Array[Coupling] = []
	var rows: Array = []
	for coupling: Coupling in couplings:
		if floating.has(coupling.one.body) or floating.has(coupling.other.body):
			continue
		used.append(coupling)
		rows.append([_row(coupling), 0.0])
	var depth: Dictionary = {}
	for joint: Joint in tree:
		depth[joint.column] = path(joint.child).size()
	var answer: Dictionary = _eliminate(fixed + held + rows, depth)
	if not answer["consistent"]:
		out["locked"] = true
		for n: int in used.size():
			var fewer: Array = rows.duplicate()
			fewer.remove_at(n)
			if _eliminate(fixed + held + fewer, depth)["consistent"]:
				(out["culprits"] as Array).append(used[n].said())
				(out["meshes"] as Array).append([used[n].one.key, used[n].other.key])
		out["said"] = "locked: the couplings ask for two different turns at once"
		for one: Joint in tree:
			one.rate = 0.0
			one.free = false
		return out
	var pivots: Array = answer["pivots"]
	var rates: Dictionary = _back(pivots, {})
	# What nothing decides: every column no pivot is, and every column a
	# free one moves when it alone turns, the drivers held.
	var decided: Dictionary = {}
	for pivot: Array in pivots:
		decided[int(pivot[0])] = true
	var undecided: Dictionary = {}   ## column -> true
	var loose: Dictionary = {}       ## body -> true, its own turn undecided
	var freedoms: int = 0
	for joint: Joint in tree:
		if decided.has(joint.column):
			continue
		freedoms += 1
		var alone: Dictionary = _back(pivots, {joint.column: 1.0}, true)
		# How each body turns when only this freedom does, the drivers held:
		# a body that turns then is one nothing decides.
		var turning: Dictionary = {ground: Vector3.ZERO}
		for one: Joint in tree:
			var rate: float = float(alone.get(one.column, 0.0))
			if absf(rate) > 1e-9:
				undecided[one.column] = true
			var here: Vector3 = (turning.get(one.parent, Vector3.ZERO) as Vector3) + one.way * rate
			turning[one.child] = here
			if here.length() > 1e-9:
				loose[one.child] = true
	var moving: int = 0
	for joint: Joint in tree:
		joint.rate = float(rates.get(joint.column, 0.0))
		joint.free = undecided.has(joint.column)
		if absf(joint.rate) > 1e-12:
			moving += 1
	var free: Array = loose.keys()
	out["ok"] = true
	out["free"] = free
	out["freedoms"] = freedoms
	out["said"] = "%d of %d joints turn; %s left, %s undecided, following what carries them" \
		% [moving, tree.size(), _counted(freedoms, "freedom"), _counted(free.size(), "body")]
	return out


static func _counted(n: int, what: String) -> String:
	if n == 1:
		return "1 " + what
	return "%d %s" % [n, "bodies" if what == "body" else what + "s"]


## Back-substitution through [param pivots]: each pivot's column from its
## right-hand side (or 0, [param homogeneous]) less what its row has of
## the columns after it, the free ones taken from [param given].
static func _back(pivots: Array, given: Dictionary, homogeneous: bool = false) -> Dictionary:
	var rates: Dictionary = given.duplicate()
	for n: int in range(pivots.size() - 1, -1, -1):
		var pivot: Array = pivots[n]
		var value: float = 0.0 if homogeneous else float(pivot[2])
		var with: Dictionary = pivot[1]
		for c: int in with:
			value -= float(with[c]) * float(rates.get(c, 0.0))
		rates[int(pivot[0])] = value
	return rates


## Sparse Gaussian elimination of [param rows], each [{column: value},
## right-hand side]: {consistent, pivots ([column, the rest of its row,
## right-hand side], in the order found)}. Each row's pivot is its column
## furthest from the ground by [param depth] among those not much smaller
## than its largest, so the columns left free, at 0, are the ones nearest
## the ground: an idle axle stays still and what it carries turns on it,
## rather than the axle turning back under a driven arm.
static func _eliminate(rows: Array, depth: Dictionary = {}) -> Dictionary:
	var pivots: Array = []        ## [column, row, rhs]
	for given: Array in rows:
		var row: Dictionary = (given[0] as Dictionary).duplicate()
		var rhs: float = float(given[1])
		var biggest: float = 0.0
		for c: int in row:
			biggest = maxf(biggest, absf(float(row[c])))
		if biggest < 1e-12:
			if absf(rhs) > 1e-9:
				return {"consistent": false, "pivots": []}
			continue
		for c: int in row.keys():
			row[c] = float(row[c]) / biggest
		rhs /= biggest
		for pivot: Array in pivots:
			var column: int = pivot[0]
			if not row.has(column):
				continue
			var factor: float = float(row[column])
			var with: Dictionary = pivot[1]
			for c: int in with:
				row[c] = float(row.get(c, 0.0)) - factor * float(with[c])
			rhs -= factor * float(pivot[2])
			row.erase(column)
		var size: float = 0.0
		for c: int in row.keys():
			if absf(float(row[c])) < 1e-12:
				row.erase(c)
			else:
				size = maxf(size, absf(float(row[c])))
		var best: int = -1
		for c: int in row:
			if size < 1e-9 or absf(float(row[c])) < size * 0.1:
				continue
			if best < 0 or int(depth.get(c, 0)) > int(depth.get(best, 0)) \
					or (int(depth.get(c, 0)) == int(depth.get(best, 0))
						and absf(float(row[c])) > absf(float(row[best]))):
				best = c
		if best < 0:
			if absf(rhs) > 1e-7:
				return {"consistent": false, "pivots": []}
			continue
		var scale: float = float(row[best])
		for c: int in row.keys():
			row[c] = float(row[c]) / scale
		rhs /= scale
		row.erase(best)
		pivots.append([best, row, rhs])
	return {"consistent": true, "pivots": pivots}


## How fast [param body] turns, as a vector: the sum of every joint's rate
## on its way from the ground, radians for one of the driver's.
func omega(body: int) -> Vector3:
	var out := Vector3.ZERO
	for joint: Joint in path(body):
		out += joint.way * joint.rate
	return out


## How fast [param body] turns about [param about].
func spin(body: int, about: Vector3) -> float:
	return omega(body).dot(about.normalized())


## Whether a part turns with another: the same transform relative to where
## they stood, at a turn of the driver, and not standing still.
func follows(key: int, other: int) -> bool:
	var placed: Dictionary = pose(0.7)
	var mine: Transform3D = (placed[key] as Transform3D) * (rest[key] as Transform3D).affine_inverse()
	var theirs: Transform3D = (placed[other] as Transform3D) * (rest[other] as Transform3D).affine_inverse()
	return _close(mine, theirs) and not _close(mine, Transform3D.IDENTITY)


static func _close(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.01 and a.basis.x.distance_to(b.basis.x) < 1e-5 \
		and a.basis.y.distance_to(b.basis.y) < 1e-5 and a.basis.z.distance_to(b.basis.z) < 1e-5


## Where every part stands with the driver turned [param angle] radians:
## key -> Transform3D.
func pose(angle: float) -> Dictionary:
	var at: Dictionary = {ground: Transform3D.IDENTITY}
	for joint: Joint in tree:
		var parent: Transform3D = at.get(joint.parent, Transform3D.IDENTITY)
		var about: Transform3D = Transform3D(Basis.IDENTITY, joint.point) \
			* Transform3D(Basis(joint.way, joint.rate * angle), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -joint.point)
		var both: Transform3D = parent * about
		at[joint.child] = Transform3D(both.basis.orthonormalized(), both.origin)
	var out: Dictionary = {}
	for key: int in parts:
		out[key] = (at.get(body_of(key), Transform3D.IDENTITY) as Transform3D) \
			* (rest[key] as Transform3D)
	return out


# -- saying what it found ---------------------------------------------------------


func couplings_said() -> String:
	var said: PackedStringArray = []
	for coupling: Coupling in couplings:
		said.append(coupling.said())
	return ", ".join(said) if not said.is_empty() else "none"


## The meshes standing further from their ideal spacing than real sets
## stand theirs (SPACING_SLACK): they mesh, at their teeth's ratio, and a
## person building them should know they are loose or tight.
func off_spacing() -> Array[Coupling]:
	var out: Array[Coupling] = []
	for coupling: Coupling in couplings:
		if not coupling.off_said().is_empty():
			out.append(coupling)
	return out


## A length as a person reads it: 46, 44.72, 1.5.
static func _tidy(value: float) -> String:
	var said: String = "%.2f" % value
	return said.rstrip("0").rstrip(".") if said.contains(".") else said


## The floating bodies with a gear in them: the drivetrain the reading
## lost.
func floating_gears() -> Array:
	var out: Array = []
	var with_gear: Dictionary = {}
	for gear: Gear in gears:
		with_gear[gear.body] = true
	for body: int in floating:
		if with_gear.has(body):
			out.append(body)
	return out


## A body's parts, by id and count: "3706, 3648a x2".
func parts_said(body: int) -> String:
	var names: Dictionary = {}
	for key: int in bodies.get(body, []):
		var id: String = (parts[key] as Piece).part
		names[id] = int(names.get(id, 0)) + 1
	var said: PackedStringArray = []
	for id: String in names:
		said.append("%s%s" % [id, "" if names[id] == 1 else " x%d" % names[id]])
	return ", ".join(said)


## Every body: its parts, what it turns on and how fast. For reading a
## model the inference got wrong.
func describe() -> String:
	var lines: PackedStringArray = []
	for body: int in bodies:
		var joint: Joint = _joint_of.get(body)
		var how: String = "the ground" if body == ground else ("floating" if joint == null
			else "on %d about %s at %s (%s), rate %.4f%s" % [joint.parent,
			joint.way.snapped(Vector3.ONE * 0.001), joint.point.snapped(Vector3.ONE * 0.1),
			joint.what, joint.rate, " (free)" if joint.free else ""])
		lines.append("      body %d: %s; %s" % [body, parts_said(body), how])
	return "\n".join(lines)


func summary() -> String:
	return "%d parts, %d bodies (the ground %d parts), %d joints in the tree, %d closing loops, " \
		% [parts.size(), bodies.size(), (bodies.get(ground, []) as Array).size(), tree.size(),
		closing.size()] + "%d floating (%d with a gear); %d gears, %d couplings" % [floating.size(),
		floating_gears().size(), gears.size(), couplings.size()]
