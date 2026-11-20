## A model held by one of its parts and swung like a toy: what comes away
## first, and when (docs/APP_UX10.md, Past parity 1, swoosh).
##
## A spaceship swooshed by a child loses its wings first. Lift (LiftTest)
## hangs a model from a part, still; this is Lift's sum with speed and a turn.
##
## The arc. The hand goes 1 m in 0.5 s while the model turns a quarter turn
## with it ([constant METRES], [constant SECONDS], [constant TURN]). A model
## held fast in the hand turns as the arm does, so the hand is on a circle
## round the shoulder, R = 1 m / (π/2) = 0.64 m: a child's arm. The arm
## swings down through the bottom and up again, 45° either side, the model
## along its length, upright at the bottom. That is the arc's worst: at the
## bottom the swing is fastest and its pull, ω²r out from the shoulder,
## points the way gravity does, so what hangs is pulled 3.3 times its weight
## there. Swept sideways, level, the pull is at right angles to gravity and
## never adds to it. The hand speeds up and slows down as a reaching hand
## does, by the smoothest path (minimum jerk, Flash and Hogan 1985: θ =
## Θ(10τ³ − 15τ⁴ + 6τ⁵), τ = t/T): still at both ends, fastest at the middle
## (ω = 1.875 Θ/T, 5.9 rad/s, 3.75 m/s at the hand), speeding up hardest a
## fifth of the way in and slowing hardest a fifth from the end (τ = ½ ∓
## √3/6, α = 5.77 Θ/T², 36 rad/s²), where the push along the path is 2.4
## times gravity and a tall thing held at its top is swung out sideways.
##
## The sum. Held in the hand the model moves as one body about the
## shoulder, so each part's middle has a = α × d + ω × (ω × d), d from the
## shoulder, and a joint carries what is past it pulled by F = Σ mᵢ(g − aᵢ)
## and turned by Σ (rᵢ − J) × mᵢ(g − aᵢ) + Σ cᵢ, cᵢ = −(Iᵢα + ω × Iᵢω) each
## part's own spin as a solid box of its shape (Balance.Moving, d'Alembert).
## Each is then weighed as Lift weighs it (Balance): a stud joint levered
## about the edge it would turn on against where its studs let go (1.92 N a
## stud, 3.07 N into a part a stud wide, stabletruth), a friction pin and a
## Technic ball about their line or middle against what they were measured to
## hold (posehold), a clip, hinge or turntable named and held as Lift holds
## it. The arc is weighed at [constant STEPS] + 1 moments evenly and at the
## two of the hardest push; a joint's load is its worst of them.
##
## What comes away. The moments are taken in turn, as the swing goes: at
## the first moment a joint is past where it lets go, the worst goes with
## everything past it, the rest is weighed again at that moment without it,
## and the swing goes on (LiftTest's rounds, in time). What nothing joins to
## the part held stays behind and what only stood on a touch falls, as Lift
## has them, as soon as it is held. So after Strengthen the same joint goes
## later in the arc, or not at all.
##
## Pure, as LiftTest is: it reads the parts, the lattice and the library and
## changes none of them, so it runs on a worker (StressView.lift_paced).
class_name SwingTest
extends LiftTest

## The arc: the hand this far, m, in this long, s, turning the model this
## far, degrees.
const METRES := 1.0
const SECONDS := 0.5
const TURN := 90.0
## What a session may ask of it.
const METRES_RANGE := Vector2(0.1, 3.0)
const SECONDS_RANGE := Vector2(0.1, 5.0)
const TURN_RANGE := Vector2(10.0, 180.0)
## Moments weighed evenly along it, past the first: every 12.5 ms of 0.5 s.
const STEPS := 40
## Where a reaching hand speeds up and slows down hardest, τ = ½ ∓ √3/6.
const HARDEST := 0.28867513459481287

var metres: float = METRES
var seconds: float = SECONDS
var turn: float = TURN


## What a swing showed: Lift's result, each thing that came away at its
## moment, and each joint left at its worst.
class Swung extends LiftTest.Result:
	## Seconds into the swing each of [member away] went, by its place.
	var times: Array = []
	## Where on the model each of [member away] was: "on the left", "".
	var sides: Array = []
	## Each joint left (of [member joints], and [member ring]): seconds into
	## the swing it was worst.
	var worst_at: Dictionary = {}
	## The arc: the hand's path, m, its time, s, the turn, degrees, the
	## shoulder's reach, m, the hand's top speed, m/s, and the most what
	## hangs at the hand is pulled, in its weights; and the way swung,
	## "front" or "right".
	var metres: float = METRES
	var seconds: float = SECONDS
	var turn: float = TURN
	var radius: float = 0.0
	var speed: float = 0.0
	var pull: float = 0.0
	var toward: String = "front"

	## The arc in words: "1 m in 0.5 s, a quarter turn".
	func arc_words() -> String:
		var turned: String = "a quarter turn" if absf(turn - 90.0) < 0.01 else (
			"a half turn" if absf(turn - 180.0) < 0.01 else "%s°" % Balance.tidy(turn))
		return "%s m in %s s, %s" % [Balance.tidy(metres), Balance.tidy(seconds), turned]

	## [param at] seconds into the swing, its number: "0.21". The words say
	## " s" after it, each its own, so a language finds them as patterns.
	static func when(at: float) -> String:
		return "%.2f" % at

	## The piece [param n] of [member away] names, with where it was:
	## "the Plate 2 x 4 on the left and 2 more".
	func piece_words(n: int) -> String:
		var one: LiftTest.Away = away[n]
		var first: int = one.joint.beyond if one.why == "lets go" and not one.whole else int(one.ids[0])
		var side: String = str(sides[n]) if n < sides.size() else ""
		var said: String = namer.call(first) + ("" if side.is_empty() else " " + side)
		return said

	## How [param n] of [member away] goes, after its name: "3 parts, 41 g,
	## at its 2 studs".
	func how_words(n: int) -> String:
		var one: LiftTest.Away = away[n]
		var parts: String = "1 part" if one.ids.size() == 1 else "%d parts" % one.ids.size()
		var weighs: String = "%s, %s g" % [parts, Balance.tidy(one.grams)]
		match one.why:
			"lets go":
				var j: Balance.JointLoad = one.joint
				if one.whole:
					return "%s, at the %d studs of %s" % [weighs, j.studs, namer.call(by)]
				return "%s, at its 1 stud" % weighs if j.studs == 1 else "%s, at its %d studs" % [weighs, j.studs]
			"falls":
				return "%s: it only stood on %s" % [weighs, namer.call(one.on) if one.on != 0 else "what was under it"]
		return "%s: nothing joins it to %s" % [weighs, namer.call(by)]

	func headline() -> String:
		if not problem.is_empty():
			return problem
		var held: String = namer.call(by)
		if away.is_empty():
			return "Swung by %s: everything holds through the swing, %s g" % [held, Balance.tidy(grams)]
		var pattern: String = {"lets go": "Swung by %s: %s comes away first, %s s in: %s",
			"falls": "Swung by %s: %s falls off first, %s s in: %s"}.get((away[0] as LiftTest.Away).why,
			"Swung by %s: %s stays behind, %s s in: %s")
		var said: String = pattern % [held, piece_words(0), when(float(times[0])), how_words(0)]
		if away.size() > 1:
			said += "; %d pieces in all, %s g of %s" % [away.size(), Balance.tidy(grams - kept_grams),
				Balance.tidy(grams)]
		return said

	## [param one] of [member away] said as a session reads it, with when.
	func away_words(one: LiftTest.Away, listed: bool = false) -> String:
		var n: int = away.find(one)
		var said: String = super.away_words(one, listed)
		return said if n < 0 else "%s s in: %s" % [when(float(times[n])), said]

	## A joint left, said as Lift says one, at its worst moment.
	func joint_words(one: Balance.JointLoad) -> String:
		var said: String = super.joint_words(one)
		return said + ("; worst %s s in" % when(float(worst_at[one])) if worst_at.has(one) else "")

	func ring_words() -> String:
		var said: String = super.ring_words()
		return said + ("; worst %s s in" % when(float(worst_at[ring])) if worst_at.has(ring) else "")

	## What swinging says of part [param id], as pointing at it does.
	func part_words(id: int) -> String:
		var name: String = namer.call(id)
		if id == by:
			return "%s: swung by it, it holds the rest" % name
		if gone.has(id):
			var one: LiftTest.Away = gone[id]
			var n: int = away.find(one)
			var at: String = when(float(times[n])) if n >= 0 else ""
			match one.why:
				"lets go":
					if one.whole:
						return "%s: comes away %s s in, as %s lets go of all it holds" % [name, at, namer.call(by)]
					if one.joint.beyond == id:
						return away_words(one)
					return "%s: comes away %s s in with %s, which lets go" % [name, at, namer.call(one.joint.beyond)]
				"falls":
					return "%s: falls off what it only stood on" % name
			return "%s: stays behind, joined to nothing swung" % name
		var one: Balance.JointLoad = joint_of(id)
		if one != null:
			return joint_words(one)
		return "%s: comes with it, held more than one way" % name

	## What the panel lists, as Lift's rows, each that lets go with its
	## joint ("joint") for Strengthen to make hold.
	func rows(least: int) -> Array:
		var out: Array = super.rows(least)
		for n: int in mini(away.size(), out.size()):
			var one: LiftTest.Away = away[n]
			(out[n] as Dictionary)["at"] = float(times[n])
			if one.why == "lets go" and not one.whole:
				(out[n] as Dictionary)["joint"] = one.joint
		return out

	## What a session reads (weakest_joints swing=): the headline, how the
	## arc was swung, each thing that comes away with when, then the [param
	## count] joints left nearest letting go at their worst, and what swings.
	func said(count: int = SAID) -> String:
		if not problem.is_empty():
			return problem
		var lines := PackedStringArray([headline() + "."])
		lines.append(("As View, Stress's Swing weighs it: held by %s and swung like a toy, the hand %s, "
			+ "on a circle %s m round the shoulder, down through the bottom and up, %s first, "
			+ "speeding up and slowing down as a reaching hand does (minimum jerk); fastest at the "
			+ "bottom, %s m/s, where what hangs at the hand is pulled %s times its weight. Each joint "
			+ "carries what is past it pulled by gravity and the swing together and turned by its "
			+ "spin, levered about the edge it would turn on (a stud lets go at %s N, %s N into a part "
			+ "a stud wide; a friction pin and a Technic ball at what they were measured to hold), at "
			+ "its worst moment of the arc. The moments are taken in turn: the first joint past what "
			+ "holds it lets go with all past it, and the swing goes on without it.") % [
			namer.call(by), arc_words(), Balance.tidy(radius), "front" if toward == "front" else "right side",
			Balance.tidy(speed), Balance.tidy(pull), Balance.tidy(Balance.ULTIMATE_N),
			Balance.tidy(Balance.ULTIMATE_ONE_WIDE_N)])
		if not away.is_empty():
			lines.append("Comes away, in the order it goes:")
			for one: LiftTest.Away in away:
				lines.append("  " + away_words(one, true) + ".")
		if ring != null:
			lines.append("The part held's own joints, together: " + ring_words() + ".")
		var holding: Array = joints.filter(func(one: Balance.JointLoad) -> bool:
			return not swings.has(one))
		var said_ones: Array = holding.filter(func(one: Balance.JointLoad) -> bool:
			return LiftTest.give_of(one) >= 0.01).slice(0, count)
		if holding.is_empty():
			lines.append("No joint left alone holds what is past it: every part left is held more than one way, and shares its load.")
		else:
			lines.append("Of the %d joint%s left that each alone hold what is past them, nearest letting go at its worst first:"
				% [holding.size(), "" if holding.size() == 1 else "s"])
			for one: Balance.JointLoad in said_ones:
				lines.append("  " + joint_words(one) + ".")
			if holding.size() > said_ones.size():
				lines.append("  %d more hold what is past them %s." % [holding.size() - said_ones.size(),
					"a hundred times over or more" if said_ones.size() < count else "further from letting go"])
		if not swings.is_empty():
			lines.append("Swings, held on a pin or axle that turns:")
			for one: Balance.JointLoad in swings:
				lines.append("  " + joint_words(one) + ".")
		lines.append("Lift (lift_by=) weighs it held still. Strengthen's fix for a joint that lets go: "
			+ "weakest_joints part= that part's number.")
		return "\n".join(lines)


# -- the arc ---------------------------------------------------------------------


## The smoothest path from still to still (minimum jerk), as a share of the
## turn at [param tau] = t/T, and its first and second rates in τ.
static func along(tau: float) -> float:
	return tau * tau * tau * (10.0 - 15.0 * tau + 6.0 * tau * tau)


static func pace(tau: float) -> float:
	return 30.0 * tau * tau * (1.0 - tau) * (1.0 - tau)


static func push(tau: float) -> float:
	return 60.0 * tau * (1.0 - tau) * (1.0 - 2.0 * tau)


## The moments weighed, as τ = t/T from 0 to 1: every 1/[constant STEPS],
## and the two of the hardest push.
static func taus() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for k: int in STEPS + 1:
		out.append(float(k) / STEPS)
	out.append(0.5 - HARDEST)
	out.append(0.5 + HARDEST)
	out.sort()
	return out


## How far round the shoulder the hand is, m: the turn's arc is the path.
func radius() -> float:
	return metres / deg_to_rad(turn)


## The model moving at [param tau] of the swing (Balance.Moving): held at
## [param hand] (LDU), swung [param toward] (a level way in the model's
## frame), upright at the bottom.
func moving_at(tau: float, hand: Vector3, toward: Vector3) -> Balance.Moving:
	var whole: float = deg_to_rad(turn)
	var axis: Vector3 = toward.cross(Vector3.UP).normalized()
	var arm: float = whole * (along(tau) - 0.5)
	var one := Balance.Moving.new()
	one.pivot = hand + Vector3.UP * (radius() * 1000.0 / Balance.MM_PER_LDU)
	one.spin = axis * (whole * pace(tau) / seconds)
	one.spin_rate = axis * (whole * push(tau) / (seconds * seconds))
	one.gravity = Vector3(0.0, -Balance.GRAVITY, 0.0).rotated(axis, -arm)
	return one


## Swing [param bricks] (a world's, the floor's among them or not) by part
## [param by]. Null when [member stop] was asked.
func swing(bricks: Array, by: int) -> Swung:
	var result := Swung.new()
	result.by = by
	result.metres = metres
	result.seconds = seconds
	result.turn = turn
	result.radius = radius()
	var whole: float = deg_to_rad(turn)
	var fastest: float = whole * pace(0.5) / seconds
	result.speed = fastest * result.radius
	result.pull = (Balance.GRAVITY + fastest * fastest * result.radius) / Balance.GRAVITY
	var model: Array = []
	var held: BrickWorld.Brick = null
	var by_id: Dictionary = {}
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		if floor_ids.has(brick.id):
			continue
		model.append(brick)
		by_id[brick.id] = brick
		if brick.id == by:
			held = brick
	if held == null:
		result.by = 0
		result.problem = ("The baseplate is the floor: swing the model by one of its own parts."
			if floor_ids.has(by) else "There is no part #%d in the model to swing it by." % by)
		return result
	result.by_part = held.part_id
	var judge := Stability.new()
	judge.library = library
	judge.lattice = lattice
	if stop != null:
		judge.stop = stop
	var graph: Dictionary = judge.contacts(model)
	if _stopping():
		return null
	var boxes: Dictionary = graph["boxes"]
	var mesh: Lbm.PartMesh = library.mesh_for(held.part_id)
	if (boxes.get(by, PackedInt32Array()) as PackedInt32Array).is_empty() \
			or mesh == null or not library.parts.has(held.part_id):
		result.by = 0
		result.problem = "Its shape has not come yet: swing it again in a moment."
		return result
	var hand: Dictionary = Balance.support_of({by: boxes[by]})
	var hand_at: Vector3 = held.transform * mesh.bounds.get_center()
	var toward: Vector3 = _length_of(boxes)
	result.toward = "right" if toward == Vector3.RIGHT else "front"
	var moments: PackedFloat64Array = taus()
	var known: Dictionary = {}
	var overlaps: Dictionary = {}
	var left: Array = model
	var round: int = 0
	var k: int = 0
	var centre := Vector3.ZERO
	## "beyond:held_by" -> [JointLoad at its worst, seconds]
	var worst: Dictionary = {}
	var ring_worst: Array = []
	while true:
		var weigher := Balance.new()
		weigher.library = library
		weigher.lattice = lattice
		weigher.known = known
		weigher.overlaps = overlaps
		weigher.support = hand
		weigher.stop = stop
		var still: Balance.Report = weigher.measure(left, [], null, graph)
		if _stopping():
			return null
		if round == 0:
			result.grams = still.grams
			centre = still.rest_centre
		result.rounds = round + 1
		var going: Array[Away] = []
		var first: bool = true
		while k < moments.size():
			var at: float = moments[k] * seconds
			weigher.moving = moving_at(moments[k], hand_at, toward)
			var swung: Balance.Report = weigher.weigh_moving()
			if _stopping():
				return null
			for one: Balance.JointLoad in swung.joints:
				var key: String = "%d:%d" % [one.beyond, one.held_by]
				var kept: Array = worst.get(key, [])
				if kept.is_empty() or LiftTest.give_of(one) > LiftTest.give_of(kept[0]):
					worst[key] = [one, at]
			var ring: Balance.JointLoad = weigher.ring_of(by, boxes)
			if ring != null and (ring_worst.is_empty() or LiftTest.give_of(ring) > LiftTest.give_of(ring_worst[0])):
				ring_worst = [ring, at]
			var asked := Balance.Report.new()
			asked.joints = swung.joints
			if first:
				# What nothing joins to the hand, and what only stood on a
				# touch, as soon as it is held, as Lift has them.
				asked.held = still.held
				asked.tipping = still.tipping
				first = false
			going = _going(weigher, asked, by, boxes, round >= ROUNDS)
			if not going.is_empty():
				break
			k += 1
		var cut: Dictionary = {}
		var cut_grams: float = 0.0
		for one: Away in going:
			result.away.append(one)
			result.times.append(moments[mini(k, moments.size() - 1)] * seconds)
			result.sides.append(_side_of(one, weigher, by_id, centre))
			cut_grams += one.grams
			for id: int in one.ids:
				cut[id] = true
				result.gone[id] = one
		if going.is_empty() or round >= ROUNDS + 2:
			result.kept_grams = still.grams - cut_grams
			result.held = still.held
			_finish(result, worst, ring_worst, cut)
			break
		left = left.filter(func(item: Variant) -> bool:
			return not cut.has((item as BrickWorld.Brick).id))
		round += 1
	return result


## The joints left at their worst ([param worst], by "beyond:held_by"),
## nearest letting go first, and those that swing; the part held's own
## joints together at their worst, when it still holds anything.
func _finish(result: Swung, worst: Dictionary, ring_worst: Array, cut: Dictionary) -> void:
	for key: Variant in worst:
		var pair: Array = worst[key]
		var one: Balance.JointLoad = pair[0]
		if one.beyond == result.by or result.gone.has(one.beyond) or cut.has(one.beyond) \
				or result.gone.has(one.held_by):
			continue
		result.joints.append(one)
		result.worst_at[one] = pair[1]
		if one.kind in ["friction pin", "free pin"] and one.moment > one.ultimate or one.droops():
			result.swings.append(one)
	result.joints.sort_custom(func(a: Balance.JointLoad, b: Balance.JointLoad) -> bool:
		var ga: float = LiftTest.give_of(a)
		var gb: float = LiftTest.give_of(b)
		return ga > gb if ga != gb else a.beyond < b.beyond)
	if not ring_worst.is_empty() and not result.gone.has((ring_worst[0] as Balance.JointLoad).beyond):
		var whole: bool = false
		for one: Away in result.away:
			whole = whole or one.whole
		if not whole:
			result.ring = ring_worst[0]
			result.worst_at[result.ring] = ring_worst[1]


## The model's longer level way, from its parts' boxes: it is swung along
## its length, toward its right (+x) or its front (+z) as View names them.
static func _length_of(boxes: Dictionary) -> Vector3:
	var low := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
	var high := Vector2i(-0x7FFFFFFF, -0x7FFFFFFF)
	for id: Variant in boxes:
		var packed: PackedInt32Array = boxes[id]
		for at: int in range(0, packed.size(), 6):
			low = Vector2i(mini(low.x, packed[at]), mini(low.y, packed[at + 2]))
			high = Vector2i(maxi(high.x, packed[at + 3]), maxi(high.y, packed[at + 5]))
	return Vector3.RIGHT if high.x - low.x >= high.y - low.y else Vector3.BACK


## Where on the model [param one]'s parts were, from its middle [param
## centre]: "on the left", "on the front-right", "at the top", or "" near
## the middle. Its weight's middle as [param weigher] read the parts.
static func _side_of(one: LiftTest.Away, weigher: Balance, by_id: Dictionary, centre: Vector3) -> String:
	var grams: float = 0.0
	var weighted := Vector3.ZERO
	for id: int in one.ids:
		var it: Array = weigher.known.get(id, [])
		var brick: BrickWorld.Brick = by_id.get(id)
		if it.size() < 3 or brick == null:
			continue
		grams += float(it[1])
		weighted += (brick.transform * (it[2] as Vector3)) * float(it[1])
	if grams <= 0.0:
		return ""
	var off: Vector3 = weighted / grams - centre
	var level := Vector2(off.x, off.z)
	if level.length() >= BrickLattice.STUD and level.length() >= absf(off.y):
		return "on the " + Balance.edge_name(level)
	if absf(off.y) >= BrickLattice.STUD:
		return "at the top" if off.y > 0.0 else "at the bottom"
	return ""
