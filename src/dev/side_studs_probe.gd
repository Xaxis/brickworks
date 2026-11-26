extends SceneTree
## Does Balance carry load through side studs as through top studs, by the
## same rule, both ways: holding what a real build holds and refusing what
## would fall? (snot6, 2026-11-25.) A part held by its side studs (a bracket's
## flange, a headlight brick, a brick with studs on a side, a turned plate's
## own studs) is a stud joint whose plane is square to its studs, weighed as
## a stud joint lying flat is: the moment about the edge it would turn on
## against M = sum F d, F the working load and where a stud lets go.
##
## Each build is made by seating parts on the studs they go on, read off the
## parts' own connectors, so nothing here is placed by hand to a number.
##
##   godot --headless --path . --script src/dev/side_studs_probe.gd

const PLATE := 8.0
const STUD := 20.0

var _library: PartLibrary
var _builder: Builder
var _checker: Assistant
var _failures: int = 0
var _checks: int = 0
var _next_id: int = 1


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	return ok


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	_builder = Builder.new()
	_builder.world = world
	_builder.library = _library
	root.add_child(_builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = world
	_checker.builder = _builder
	await process_frame
	for id: String in ["3001", "3010", "3005", "3710", "3623", "3020", "3004", "87087", "4070", "30414",
			"11211", "99781", "3024"]:
		if _library.mesh_for(id) == null:
			_check("part %s is in the catalogue" % id, false)
	_brackets()
	_headlights()
	_sideways_arm()
	_off_the_stud()
	print("")
	print("%d of %d checks pass" % [_checks - _failures, _checks])
	if _failures == 0:
		print("side studs carry load as top studs do, by the same rule")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


# -- building ------------------------------------------------------------------


## A part square to the grid at [param x], [param z] studs and [param y]
## plates up, turned [param rot] quarters, as a design places it.
func _up(part: String, x: float, y: float, z: float, rot: int = 0) -> BrickWorld.Brick:
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	var at: Transform3D = _checker._transform(Assistant.Placement.from_dict({"part": part, "color": 4,
		"x": x, "y": y, "z": z, "rot": rot}), mesh)
	return _brick(part, at)


func _brick(part: String, at: Transform3D) -> BrickWorld.Brick:
	var brick := BrickWorld.Brick.new(_next_id, part, 4, at)
	_next_id += 1
	return brick


## The studs of [param brick] pointing [param way] (within a few degrees):
## each [foot, way], world.
func _studs(brick: BrickWorld.Brick, way: Vector3) -> Array:
	var out: Array = []
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or connector.gender != "male":
			continue
		var w: Vector3 = (brick.transform.basis * connector.axis).normalized()
		if w.dot(way.normalized()) > 0.98:
			out.append([brick.transform * connector.position, w])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		var pa: Vector3 = a[0]
		var pb: Vector3 = b[0]
		return pa.x < pb.x or (pa.x == pb.x and (pa.y < pb.y or (pa.y == pb.y and pa.z < pb.z))))
	return out


## [param part] seated on [param studs] ([foot, way] all one way), its
## underside on them: of every socket on the first stud and every quarter
## turn about it, the one that takes the most of them.
func _seat(part: String, studs: Array) -> BrickWorld.Brick:
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	var way: Vector3 = studs[0][1]
	var lift := Basis.IDENTITY
	if way.dot(Vector3.UP) < -0.99:
		lift = Basis(Vector3.RIGHT, PI)
	elif way.dot(Vector3.UP) < 0.99:
		var axis: Vector3 = Vector3.UP.cross(way).normalized()
		lift = Basis(axis, acos(clampf(Vector3.UP.dot(way), -1.0, 1.0)))
	var best: Transform3D
	var most: int = -1
	for s: Vector2 in mesh.sockets:
		var local := Vector3(s.x, mesh.bounds.position.y, s.y)
		for quarter: int in 4:
			var basis: Basis = Basis(way, quarter * PI * 0.5) * lift
			var at := Transform3D(basis, (studs[0][0] as Vector3) - basis * local)
			var taken: int = 0
			for one: Array in studs:
				if Joints.socket_at(at, mesh, one[0], one[1]):
					taken += 1
			if taken > most:
				most = taken
				best = at
	if most < studs.size():
		print("  (%s takes %d of the %d studs it is seated on)" % [part, most, studs.size()])
	return _brick(part, best)


## Where [param brick]'s underside would sit on studs: the middle of its
## bottom face, x and z, at its lowest.
func _middle_of_studs(brick: BrickWorld.Brick) -> Vector3:
	var box: AABB = brick.transform * _library.mesh_for(brick.part_id).bounds
	return Vector3(box.get_center().x, box.position.y, box.get_center().z)


## [param part] stacked on [param under]'s studs that point [param way], as
## on its top: the same seat, square to them.
func _on(part: String, under: BrickWorld.Brick, way: Vector3, first: int = 0,
		count: int = -1) -> BrickWorld.Brick:
	var studs: Array = _studs(under, way)
	if count > 0:
		studs = studs.slice(first, first + count)
	return _seat(part, studs)


## Balance on [param bricks] as the design check weighs a model: their covers
## in a lattice of their own, every stud's tip read.
func _weigh(bricks: Array) -> Balance.Report:
	var lattice := BrickLattice.new()
	for brick: BrickWorld.Brick in bricks:
		lattice.occupy_boxes(brick.id, _builder.boxes_for(_library.mesh_for(brick.part_id), brick.transform))
	var judge := Balance.new()
	judge.library = _library
	judge.lattice = lattice
	return judge.measure(bricks)


## What the joints read of the pair [param a], [param b] in [param bricks],
## said: how many studs, which has them, and where they stand if they point
## sideways.
func _read_pair(bricks: Array, a: BrickWorld.Brick, b: BrickWorld.Brick) -> String:
	var lattice := BrickLattice.new()
	for brick: BrickWorld.Brick in bricks:
		lattice.occupy_boxes(brick.id, _builder.boxes_for(_library.mesh_for(brick.part_id), brick.transform))
	var shapes := Stability.new()
	shapes.library = _library
	shapes.lattice = lattice
	var joints: Dictionary = Stability.stud_joints(shapes.contacts(bricks), _library, lattice)
	var key: int = Stability.pair_of(a.id, b.id)
	var said: PackedStringArray = []
	for name: String in joints:
		if joints[name] is Dictionary and (joints[name] as Dictionary).has(key):
			said.append("%s %s" % [name, str(joints[name][key])])
	return "; ".join(said)


## The joint whose far side starts at [param beyond] and is held by [param
## held], or null.
func _joint(report: Balance.Report, beyond: BrickWorld.Brick, held: BrickWorld.Brick) -> Balance.JointLoad:
	for one: Balance.JointLoad in report.joints:
		if one.beyond == beyond.id and one.held_by == held.id:
			return one
	return null


func _grams(bricks: Array) -> float:
	var grams: float = 0.0
	for brick: BrickWorld.Brick in bricks:
		grams += Stability.grams(_library.parts.get(brick.part_id))
	return grams


## The middle of [param bricks]' weight, as Balance takes each part's: the
## middle of its shape.
func _centre(bricks: Array) -> Vector3:
	var sum := Vector3.ZERO
	var grams: float = 0.0
	for brick: BrickWorld.Brick in bricks:
		var g: float = Stability.grams(_library.parts.get(brick.part_id))
		sum += brick.transform * _library.mesh_for(brick.part_id).bounds.get_center() * g
		grams += g
	return sum / grams


## The rule by hand for a joint of [param feet] all pointing [param way],
## carrying [param grams] whose middle is at [param centre]: the turning of
## the weight about the joint's middle, less its part along the studs; the
## edge it turns on, the far edge of the joint half a stud past its studs;
## the levers each stud has from it. [moment, capacity] in N·cm.
func _by_hand(feet: Array, way: Vector3, grams: float, centre: Vector3) -> Array:
	# The joint's rectangle: its studs and half a stud round them, square to
	# them, and its middle.
	var u: Vector3 = way.cross(Vector3.UP)
	if u.length() < 0.1:
		u = way.cross(Vector3.RIGHT)
	u = u.normalized()
	var v: Vector3 = way.cross(u).normalized()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for foot: Vector3 in feet:
		var at := Vector2(foot.dot(u), foot.dot(v))
		lo = lo.min(at)
		hi = hi.max(at)
	lo -= Vector2.ONE * STUD * 0.5
	hi += Vector2.ONE * STUD * 0.5
	var plane: float = (feet[0] as Vector3).dot(way)
	var middle: Vector3 = u * (lo.x + hi.x) * 0.5 + v * (lo.y + hi.y) * 0.5 + way * plane
	var corners: Array[Vector3] = []
	for c: Vector2 in [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]:
		corners.append(u * c.x + v * c.y + way * plane)
	var force := Vector3(0.0, -grams / 1000.0 * Balance.GRAVITY, 0.0)
	var turning: Vector3 = (centre - middle).cross(force)
	var bending: Vector3 = turning - way * turning.dot(way)
	var pressed: float = -force.dot(way)
	var tips: Vector3 = bending.cross(way).normalized()
	var reach: float = -INF
	for corner: Vector3 in corners:
		reach = maxf(reach, (corner - middle).dot(tips))
	var lever: float = 0.0
	for foot: Vector3 in feet:
		lever += reach - (foot - middle).dot(tips)
	var to_cm: float = Balance.MM_PER_LDU / 10.0
	return [maxf(bending.length() - pressed * reach, 0.0) * to_cm, Balance.ALLOWABLE_N * lever * to_cm]


# -- the builds ----------------------------------------------------------------


## A turned wall on brackets: two 1 x 2 - 1 x 2 brackets on a 2 x 4 brick, a
## 1 x 4 plate on their four side studs, its face out. Light, it holds; the
## wall then carrying a long stack of turned plates out from it hangs on those
## four studs, and past where they let go it falls.
func _brackets() -> void:
	print("")
	print("a turned wall on brackets")
	_next_id = 1
	# The bracket's underside names no sockets in the catalogue: it is placed
	# on the brick as a design places it, three plates up, and its flange's
	# studs read from where it stands.
	var base: BrickWorld.Brick = _up("3010", 0, 0, 0, 1)
	var tops: Array = _studs(base, Vector3.UP)
	var at_a: Vector3 = ((tops[0][0] as Vector3) + (tops[1][0] as Vector3)) * 0.5
	var at_b: Vector3 = ((tops[2][0] as Vector3) + (tops[3][0] as Vector3)) * 0.5
	var left: BrickWorld.Brick = _up("99781", 0, 3, 0, 1)
	var own: Array = _studs(left, Vector3.UP)
	if own.size() == 2:
		# Its base's two studs straight over the brick's, a plate up.
		left.transform.origin += at_a + Vector3(0.0, PLATE, 0.0) \
			- ((own[0][0] as Vector3) + (own[1][0] as Vector3)) * 0.5
	else:
		left.transform.origin += at_a - _middle_of_studs(left)
	var other: BrickWorld.Brick = _brick("99781", Transform3D(left.transform.basis,
		left.transform.origin + (at_b - at_a)))
	var flange: Array = []
	for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		if not _studs(left, way).is_empty():
			flange = _studs(left, way)
	if not _check("a bracket's flange has its studs on its side (%d)" % flange.size(), flange.size() == 2):
		return
	var out: Vector3 = flange[0][1]
	var feet: Array = _studs(left, out) + _studs(other, out)
	_check("the two brackets' flanges are one row of four side studs", feet.size() == 4
		and absf(((feet[3][0] as Vector3) - (feet[0][0] as Vector3)).length() - 3.0 * STUD) < 0.5)
	var wall: BrickWorld.Brick = _seat("3710", feet)
	var bricks: Array = [base, left, other, wall]
	print("  the bracket on the brick: %s" % _read_pair(bricks, base, left))
	print("  the wall on the bracket: %s" % _read_pair(bricks, left, wall))
	var report: Balance.Report = _weigh(bricks)
	print("  %d parts, %.1f g, %d bridges, %d over" % [bricks.size(), report.grams, report.joints.size(),
		report.over])
	_check("the wall is held on the brackets' side studs: nothing adrift", report.adrift == 0
		and not report.held.values().has("nothing"))
	_check("light, nothing is past its working load", report.over == 0)
	# A stack of 1 x 4 plates laid out from the wall on its studs, each on the
	# one before: a beam out sideways, held by the brackets' four side studs.
	var beam: Array = []
	var last: BrickWorld.Brick = wall
	for n: int in 24:
		last = _on("3710", last, out)
		beam.append(last)
	var heavy: Array = bricks + beam
	var weighed: Balance.Report = _weigh(heavy)
	var into_left: Balance.JointLoad = _joint(weighed, wall, left)
	var into_other: Balance.JointLoad = _joint(weighed, wall, other)
	print("  with %d plates out: %.1f g, %d bridges, %d over" % [beam.size(), weighed.grams,
		weighed.joints.size(), weighed.over])
	# Two brackets each hold the wall: no one joint carries it, the joint is
	# the bracket on the brick under it and the wall on both brackets.
	var worst: Balance.JointLoad = weighed.joints[0] if not weighed.joints.is_empty() else null
	if worst != null:
		print("  the worst: %s on %s by %d studs, %.0f g, %.2f N·cm of %.2f (%.1fx), lets go at %.2f" % [
			worst.beyond_part, worst.held_part, worst.studs, worst.grams, worst.moment, worst.capacity,
			worst.ratio, worst.ultimate])
	_check("the beam's own joints are read whole along it: each plate on the one before by 4 studs",
		weighed.joints.any(func(one: Balance.JointLoad) -> bool:
			return one.beyond_part == "3710" and one.held_part == "3710" and one.studs == 4))
	var first: Balance.JointLoad = _joint(weighed, beam[0] as BrickWorld.Brick, wall)
	_check("the beam's first plate hangs on the wall by its 4 side studs",
		first != null and first.studs == 4)
	if first != null:
		var hand: Array = _by_hand(_studs(wall, out).map(func(s: Array) -> Vector3: return s[0]), out,
			_grams(beam), _centre(beam))
		_check("...weighed by the same rule as a flat joint: %.3f of %.3f N·cm by hand, %.3f of %.3f here"
			% [hand[0], hand[1], first.moment, first.capacity],
			absf(first.moment - float(hand[0])) < 0.01 * maxf(1.0, float(hand[0]))
			and absf(first.capacity - float(hand[1])) < 0.01 * maxf(1.0, float(hand[1])))
		_check("...and a beam of 24 plates (%.0f mm, %.0f g) on four studs holds: %.2f of %.2f N·cm"
			% [24 * 3.2, first.grams, first.moment, first.capacity], first.ratio < 1.0)
	# Two brackets hold the wall, so neither alone is what holds it: no
	# bridge between the wall and either, as two studs-up props share a beam.
	_check("the wall on two brackets is held two ways: no one joint carries it",
		into_left == null and into_other == null)


## A headlight row: four headlight bricks on a 1 x 4 brick, a 1 x 4 plate on
## their four side studs. It holds. One headlight alone holding a long arm on
## its one side stud is past its load, as the same arm on a brick with a stud
## on its side is by the same number: the joint is the plate's on one stud,
## whatever the stud stands on.
func _headlights() -> void:
	print("")
	print("a headlight row")
	_next_id = 1
	var base: BrickWorld.Brick = _up("3010", 0, 0, 0)
	var row: Array = []
	var tops: Array = _studs(base, Vector3.UP)
	for n: int in tops.size():
		row.append(_seat("4070", [tops[n]]))
	var out: Vector3 = Vector3.ZERO
	for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		if _studs(row[0], way).size() == 1:
			out = way
	if not _check("a headlight brick has one stud on a side", out != Vector3.ZERO):
		return
	var feet: Array = []
	for one: BrickWorld.Brick in row:
		feet.append_array(_studs(one, out))
	if feet.size() != 4 or absf(((feet[1][0] as Vector3) - (feet[0][0] as Vector3)).dot(out)) > 0.5:
		# Turned the other way along the row, the side studs face the brick's
		# long side.
		row.clear()
		for n: int in tops.size():
			var one: BrickWorld.Brick = _seat("4070", [tops[n]])
			one.transform = Transform3D(one.transform.basis * Basis(Vector3.UP, PI * 0.5), one.transform.origin)
			row.append(one)
		for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			if _studs(row[0], way).size() == 1:
				out = way
		feet.clear()
		for one: BrickWorld.Brick in row:
			feet.append_array(_studs(one, out))
	var plate: BrickWorld.Brick = _seat("3710", feet)
	var bricks: Array = [base] + row + [plate]
	var report: Balance.Report = _weigh(bricks)
	print("  %d parts, %.1f g, %d bridges, %d over" % [bricks.size(), report.grams, report.joints.size(),
		report.over])
	_check("the plate on four headlights is held: nothing adrift", report.adrift == 0
		and not report.held.values().has("nothing"))
	_check("it holds: nothing past its working load", report.over == 0)
	# One headlight on a 1 x 1 brick, a 1 x 2 plate on its side stud, and
	# from that plate bricks laid out sideways on each one before.
	var arm_on := func(holder: String, bricks_out: int) -> Array:
		_next_id = 1
		var foot: BrickWorld.Brick = _up("3005", 0, 0, 0)
		var head: BrickWorld.Brick = _seat(holder, _studs(foot, Vector3.UP))
		var way: Vector3 = Vector3.ZERO
		for w: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			if _studs(head, w).size() == 1:
				way = w
		var first: BrickWorld.Brick = _seat("3023b", _studs(head, way))
		var arm: Array = [first]
		var last: BrickWorld.Brick = first
		for n: int in bricks_out:
			last = _on("3004", last, way)
			arm.append(last)
		var weighed: Balance.Report = _weigh([foot, head] + arm)
		print("  %s's side stud and the plate on it: %s" % [holder, _read_pair([foot, head] + arm, head, first)])
		return [_joint(weighed, first, head), weighed, arm, head, way]
	var lit: Array = arm_on.call("4070", 20)
	var snot: Array = arm_on.call("87087", 20)
	var on_light: Balance.JointLoad = lit[0]
	var on_brick: Balance.JointLoad = snot[0]
	if not _check("a 1 x 2 plate on one headlight's side stud is a joint of 1 stud",
			on_light != null and on_light.studs == 1):
		return
	# Short, the headlight holds its arm as an 87087 does. Read flat across the
	# sliver of covers the lift saw (Stability.stud_joints before snot6), the
	# same eight bricks were 2.3 times its working load.
	var short: Balance.JointLoad = (arm_on.call("4070", 8) as Array)[0]
	var short_snot: Balance.JointLoad = (arm_on.call("87087", 8) as Array)[0]
	_check("eight 1 x 2 bricks out from one headlight hold, as from an 87087: %.2fx and %.2fx"
		% [short.ratio if short != null else -1.0, short_snot.ratio if short_snot != null else -1.0],
		short != null and short_snot != null and short.ratio < 1.0 and short_snot.ratio < 1.0
		and absf(short.ratio - short_snot.ratio) < 0.15 * short_snot.ratio)
	print("  twenty 1 x 2 bricks out from one headlight: %.1f g, %.2f N·cm of %.2f (%.1fx), lets go at %.2f"
		% [on_light.grams, on_light.moment, on_light.capacity, on_light.ratio, on_light.ultimate])
	_check("...past its working load, and past where a stud lets go: it falls",
		on_light.ratio > 1.0 and on_light.moment > on_light.ultimate)
	_check("...as the same arm on a brick with a stud on its side (87087) is: %.2f and %.2f N·cm"
		% [on_light.moment, on_brick.moment if on_brick != null else -1.0],
		on_brick != null and on_brick.studs == 1 and absf(on_brick.moment - on_light.moment) < 0.15 * on_light.moment)
	var hand: Array = _by_hand(_studs(lit[3], lit[4]).map(func(s: Array) -> Vector3: return s[0]), lit[4],
		_grams(lit[2]), _centre(lit[2]))
	_check("...by the rule by hand: %.3f of %.3f N·cm" % [hand[0], hand[1]],
		absf(on_light.moment - float(hand[0])) < 0.01 * maxf(1.0, float(hand[0]))
		and absf(on_light.capacity - float(hand[1])) < 0.01 * maxf(1.0, float(hand[1])))


## A cantilever held only sideways: a 1 x 4 brick with four studs on its side
## in a tower, a 1 x 4 plate on them and 1 x 4 bricks laid out from it on each
## one before. Short, it holds; long, its four side studs let go, by the rule
## worked by hand. Stood up on a brick's four top studs instead, the same
## bricks press their joint and lever nothing.
func _sideways_arm() -> void:
	print("")
	print("a cantilever held only sideways")
	var build := func(bricks_out: int) -> Array:
		_next_id = 1
		var low: BrickWorld.Brick = _up("3010", 0, 0, 0)
		var snot: BrickWorld.Brick = _seat("30414", _studs(low, Vector3.UP))
		var way: Vector3 = Vector3.ZERO
		for w: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			if _studs(snot, w).size() == 4:
				way = w
		var top: BrickWorld.Brick = _seat("3010", _studs(snot, Vector3.UP))
		var face: BrickWorld.Brick = _seat("3710", _studs(snot, way))
		var arm: Array = [face]
		var last: BrickWorld.Brick = face
		for n: int in bricks_out:
			last = _on("3010", last, way)
			arm.append(last)
		var weighed: Balance.Report = _weigh([low, snot, top] + arm)
		return [_joint(weighed, face, snot), weighed, arm, snot, way]
	var short: Array = build.call(2)
	var long: Array = build.call(32)
	var near: Balance.JointLoad = short[0]
	var far: Balance.JointLoad = long[0]
	if not _check("the plate on a 30414's four side studs is a joint of 4 studs",
			near != null and near.studs == 4 and far != null and far.studs == 4):
		return
	print("  2 bricks out: %.1f g, %.2f of %.2f N·cm (%.2fx); 32 out: %.1f g, %.2f of %.2f N·cm (%.2fx), lets go at %.2f"
		% [near.grams, near.moment, near.capacity, near.ratio, far.grams, far.moment, far.capacity, far.ratio,
			far.ultimate])
	_check("two bricks out it holds", near.ratio <= 1.0 and (short[1] as Balance.Report).over == 0)
	_check("thirty-two out it falls: past where its four side studs let go", far.moment > far.ultimate)
	var hand: Array = _by_hand(_studs(long[3], long[4]).map(func(s: Array) -> Vector3: return s[0]), long[4],
		_grams(long[2]), _centre(long[2]))
	_check("...by the rule by hand: %.3f of %.3f N·cm" % [hand[0], hand[1]],
		absf(far.moment - float(hand[0])) < 0.01 * maxf(1.0, float(hand[0]))
		and absf(far.capacity - float(hand[1])) < 0.01 * maxf(1.0, float(hand[1])))
	# Turned up: the same 1 x 4 plate on a 1 x 4 brick's four top studs, the
	# same sixteen bricks stacked on it the way the arm ran, but now up: its
	# weight is along the studs and presses the joint, so nothing levers it.
	_next_id = 1
	var foot: BrickWorld.Brick = _up("3010", 0, 0, 0)
	var plate: BrickWorld.Brick = _seat("3710", _studs(foot, Vector3.UP))
	var stack: Array = [plate]
	var last: BrickWorld.Brick = plate
	for n: int in 16:
		last = _on("3010", last, Vector3.UP)
		stack.append(last)
	var up: Balance.Report = _weigh([foot] + stack)
	var standing: Balance.JointLoad = _joint(up, plate, foot)
	_check("the same plate and bricks stood on top studs press their joint and lever nothing",
		standing != null and standing.studs == 4 and standing.moment < 0.01)


## What would fall is not held: a plate against a brick's side with no stud in
## it (a stud off), and a plate against the face of a brick with no side studs,
## are held by nothing.
func _off_the_stud() -> void:
	print("")
	print("a plate beside a side, on no stud")
	_next_id = 1
	var foot: BrickWorld.Brick = _up("3005", 0, 0, 0)
	var snot: BrickWorld.Brick = _seat("87087", _studs(foot, Vector3.UP))
	var way: Vector3 = Vector3.ZERO
	for w: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		if _studs(snot, w).size() == 1:
			way = w
	var on_it: BrickWorld.Brick = _seat("3024", _studs(snot, way))
	var held: Balance.Report = _weigh([foot, snot, on_it])
	_check("a 1 x 1 plate on an 87087's side stud is held", held.adrift == 0)
	# Moved a stud across the face, along it: its underside against the brick's
	# side no longer, beside the stud, on nothing.
	var along: Vector3 = way.cross(Vector3.UP).normalized()
	var off: BrickWorld.Brick = _brick("3024", Transform3D(on_it.transform.basis,
		on_it.transform.origin + along * STUD))
	var loose: Balance.Report = _weigh([foot, snot, off])
	_check("moved a stud along the side, it is held by nothing (adrift %d)" % loose.adrift, loose.adrift == 1)
	# Against a plain brick's side, where no stud is.
	_next_id = 1
	var plain_foot: BrickWorld.Brick = _up("3005", 0, 0, 0)
	var plain: BrickWorld.Brick = _seat("3005", _studs(plain_foot, Vector3.UP))
	var against: BrickWorld.Brick = _brick("3024", Transform3D(on_it.transform.basis,
		on_it.transform.origin - snot.transform.origin + plain.transform.origin))
	var nothing: Balance.Report = _weigh([plain_foot, plain, against])
	_check("against a plain brick's side, it is held by nothing (adrift %d)" % nothing.adrift,
		nothing.adrift == 1)
