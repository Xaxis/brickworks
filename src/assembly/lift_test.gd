## A model lifted by one of its parts: every joint between that part and the
## rest carries what hangs past it, and what lets go is named, with all that
## comes away with it (docs/APP_UX8.md, unit 13, loadtest).
##
## View, Stress weighs a model standing on the floor (Balance). A person
## picks it up by a part: a car by its roof, a wall by a top brick. Then the
## floor holds nothing and the part in the hand holds everything: a joint
## that pressed its studs home now hangs, and what is under it pulls them
## out. So this weighs the model with that part as its one support, Balance's
## tree grown from it rather than from the floor ([member Balance.support]
## names it the one part standing), by Balance's own rule: each stud joint
## that alone holds what is past it is levered about the edge it would turn
## on, M = Σ F·dᵢ, with the pull added where a part hangs (Balance._load). A
## joint whose moment is past where its studs let go (Balance.lets_go: 1.92 N
## a stud, 3.07 N into a part a stud wide, as stabletruth measured them)
## lets go, and everything past it comes away.
##
## The one nearest letting go goes first. A lift loads every joint in step
## as the weight comes off the floor, so the joint with the most load for
## what it holds reaches it first, and what it held is gone before any joint
## above it carries it. Then what is left is weighed again without it, until
## every joint left holds: a joint relieved by what went below it may hold
## after all. At most [constant ROUNDS] rounds; past them, all that is still
## past its hold lets go together.
##
## A joint on pins or axles past what holds it turns: the part swings on it
## and stays ([member Result.swings]). A touch carries only what stands on it
## (Balance), so what hung on a touch comes away, and what nothing joins to
## the part lifted stays where it was. The baseplate is the floor, not the
## model: the model comes off it.
##
## Pure, as Balance is: it reads the parts, the lattice and the library and
## changes none of them, so it runs on a worker (StressView.lift_paced).
class_name LiftTest
extends RefCounted

## Rounds of letting go and weighing again, at most.
const ROUNDS := 12
## Joints said in [method Result.said] beyond those that let go, at most.
const SAID := 8

var library: PartLibrary
var lattice: BrickLattice
## The floor's parts (ModelStore.scenery): left where they are.
var floor_ids: Dictionary = {}
## Asked from the main thread to end a lift on a worker early: it then
## returns null.
var stop: WorkerTasks.Stop = null


## What comes away, and why: "lets go" (a stud joint past where its studs
## let go: [member joint], and everything past it), "loose" (joined to the
## part lifted by nothing, so it stays where it was) or "falls" (it only
## stood on what is under it by a touch, its weight past where they touch).
class Away extends RefCounted:
	var why: String = ""
	var joint: Balance.JointLoad = null
	## Every part that comes away, the one past the joint first.
	var ids := PackedInt64Array()
	var grams: float = 0.0
	## Its moment over what lets it go, for "lets go": past 1.
	var give: float = 0.0
	## For "falls": the part it stood on, 0 for none.
	var on: int = 0
	## For "lets go": the joint is all the part lifted's joints together
	## (Balance.ring_of), and what comes away everything they held.
	var whole: bool = false


class Result extends RefCounted:
	## The part lifted by, and its part number; 0 when it could not be.
	var by: int = 0
	var by_part: String = ""
	## Why it could not be lifted, empty when it was.
	var problem: String = ""
	## What was lifted (the model, the floor left), and what stays in the
	## hand, g.
	var grams: float = 0.0
	var kept_grams: float = 0.0
	## What came away, in the order it went.
	var away: Array[Away] = []
	## Each part that came away: id -> its Away.
	var gone: Dictionary = {}
	## The joints left, each alone holding what is past it, nearest letting
	## go first (Balance.JointLoad), and of them the pins and axles past what
	## holds them, which turn: the part on them swings, and stays.
	var joints: Array = []
	var swings: Array = []
	## The part lifted's own joints weighed together, when more than one
	## joins it and studs alone do (Balance.ring_of): they hold all the rest.
	var ring: Balance.JointLoad = null
	var rounds: int = 0
	## How each part left is held, as Balance says it (Balance.Report.held).
	var held: Dictionary = {}
	## Names a part by its id for the words: "#12 Brick 1 x 4".
	var namer: Callable = func(id: int) -> String: return "#%d" % id

	## How many parts come away.
	func count_away() -> int:
		return gone.size()

	## The joint holding [param id], when one alone does and it held.
	func joint_of(id: int) -> Balance.JointLoad:
		for one: Balance.JointLoad in joints:
			if one.beyond == id:
				return one
		return null

	## What the panel heads its list with and the status bar says.
	func headline() -> String:
		if not problem.is_empty():
			return problem
		var lifted: String = namer.call(by)
		if gone.is_empty():
			return "Lifted by %s: everything comes with it, %s g" % [lifted, Balance.tidy(grams)]
		if gone.size() == 1:
			return "Lifted by %s: 1 part comes away, %s g of %s" % [lifted,
				Balance.tidy(grams - kept_grams), Balance.tidy(grams)]
		return "Lifted by %s: %d parts come away, %s g of %s" % [lifted, gone.size(),
			Balance.tidy(grams - kept_grams), Balance.tidy(grams)]

	## [param one] said, its parts joined by "; " as the status bar's are:
	## what lets go and of what, what it carried on how many studs, how near
	## it was by Balance's numbers, and how much comes away with it, each of
	## them by number when [param listed] (a session's).
	func away_words(one: Away, listed: bool = false) -> String:
		var parts := PackedStringArray()
		match one.why:
			"lets go":
				var j: Balance.JointLoad = one.joint
				parts.append("%s lets go of all it holds" % namer.call(by) if one.whole
					else "%s lets go of %s" % [namer.call(j.beyond), namer.call(j.held_by)])
				var how: String = "hangs from it" if j.hangs else "is levered off it"
				parts.append(("%s g " + how + " on 1 stud") % Balance.tidy(j.grams) if j.studs == 1
					else ("%s g " + how + " on %d studs") % [Balance.tidy(j.grams), j.studs])
				parts.append("%s times what lets it go (%s of %s N·cm)" % [LiftTest.times(one.give),
					Balance.tidy(j.moment), Balance.tidy(j.ultimate)])
			"falls":
				parts.append("%s falls off %s, which it only stood on, its weight past where they touch"
					% [namer.call(int(one.ids[0])), namer.call(one.on) if one.on != 0 else "what was under it"])
			_:
				parts.append("%s stays where it was: nothing joins it to %s" % [namer.call(int(one.ids[0])),
					namer.call(by)])
		if one.ids.size() > 1:
			parts.append("%d parts come away with it, %s g" % [one.ids.size(), Balance.tidy(one.grams)])
			if listed:
				var each := PackedStringArray()
				for id: int in one.ids:
					each.append(namer.call(id))
				parts[parts.size() - 1] += ": " + ", ".join(each)
		return "; ".join(parts)

	## The part lifted's own joints together ([member ring]), said as a joint
	## left is.
	func ring_words() -> String:
		var parts := PackedStringArray([
			"%s holds the rest on %d studs together: %s of what lets it go" % [namer.call(by),
				ring.studs, LiftTest.times(LiftTest.give_of(ring))],
			"%s g past it" % Balance.tidy(ring.grams)])
		if ring.ratio > 1.0:
			parts.append("past its studs' working load")
		return "; ".join(parts)

	## [param one], a joint left, said as [method away_words] says one.
	func joint_words(one: Balance.JointLoad) -> String:
		var beyond: String = namer.call(one.beyond)
		var held: String = namer.call(one.held_by)
		var parts := PackedStringArray()
		match one.kind:
			"studs":
				var how: String = "hangs from" if one.hangs else "stands on"
				parts.append(("%s " + how + " %s on 1 stud: %s of what lets it go") % [beyond, held,
					LiftTest.times(LiftTest.give_of(one))] if one.studs == 1
					else ("%s " + how + " %s on %d studs: %s of what lets it go") % [beyond, held,
					one.studs, LiftTest.times(LiftTest.give_of(one))])
			"axle", "two lines":
				parts.append("%s is held square on %s: nothing turns it" % [beyond, held])
			_:
				parts.append("%s swings on %s, and stays on" % [beyond, held] if one.moment > one.ultimate
					else "%s turns on %s: %s of what turns it" % [beyond, held,
					LiftTest.times(LiftTest.give_of(one))])
		parts.append("%s g past it" % Balance.tidy(one.grams))
		if one.kind == "studs" and one.ratio > 1.0:
			parts.append("past its studs' working load")
		return "; ".join(parts)

	## What lifting says of part [param id], as pointing at it does.
	func part_words(id: int) -> String:
		var name: String = namer.call(id)
		if id == by:
			return "%s: lifted by it, it holds the rest" % name
		if gone.has(id):
			var one: Away = gone[id]
			match one.why:
				"lets go":
					if one.whole:
						return "%s: comes away, as %s lets go of all it holds" % [name, namer.call(by)]
					return away_words(one) if one.joint.beyond == id \
						else "%s: comes away with %s, which lets go" % [name, namer.call(one.joint.beyond)]
				"falls":
					return "%s: falls off what it only stood on" % name
			return "%s: stays where it was, joined to nothing lifted" % name
		var one: Balance.JointLoad = joint_of(id)
		if one != null:
			return joint_words(one)
		return "%s: comes with it, held more than one way" % name

	## What the panel lists, in order: each thing that comes away, then the
	## joints left past their working load and those that swing, then the
	## nearest letting go of the rest to make [param least], of those within
	## a hundred times of it. Each {"kind":
	## "lets go", "loose", "falls", "strained", "swings" or "holds", "id": the
	## part said and selected, "ids": all it takes with it, "around": what
	## holds it, framed with it, "give": how near letting go, "why": its
	## words}.
	func rows(least: int) -> Array:
		var out: Array = []
		for one: Away in away:
			out.append({"kind": one.why, "id": int(one.ids[0]), "ids": Array(one.ids),
				"around": one.joint.held_by if one.joint != null else (one.on if one.on != 0 else by),
				"give": one.give, "why": away_words(one)})
		if ring != null:
			out.append({"kind": "strained" if ring.ratio > 1.0 else "holds", "id": by, "ids": [by],
				"around": ring.beyond, "give": LiftTest.give_of(ring), "why": ring_words()})
		for one: Balance.JointLoad in joints:
			var kind: String = "swings" if swings.has(one) else ("strained"
				if one.kind == "studs" and one.ratio > 1.0 else "holds")
			# Those that hold it a hundred times over and more say nothing, as
			# in said(): a car's wheels on their pins, under its own weight.
			if kind == "holds" and (out.size() >= least or LiftTest.give_of(one) < 0.01):
				continue
			out.append({"kind": kind, "id": one.beyond, "ids": [one.beyond], "around": one.held_by,
				"give": LiftTest.give_of(one), "why": joint_words(one)})
		return out

	## What a session reads (weakest_joints lift_by=): the headline, each
	## thing that comes away with every part of it, then the [param count]
	## joints left nearest letting go and what swings.
	func said(count: int = SAID) -> String:
		if not problem.is_empty():
			return problem
		var lines := PackedStringArray([headline() + "."])
		lines.append(("As View, Stress's Lift weighs it: the floor holds nothing and the part lifted "
			+ "holds everything; each joint that alone holds what is past it carries that, "
			+ "levered about the edge it would turn on and pulled where it hangs (%s N a stud "
			+ "working; a stud lets go at %s N, %s N into a part a stud wide). The one nearest "
			+ "letting go goes first, and the rest is weighed again without it.") % [
			Balance.tidy(Balance.ALLOWABLE_N), Balance.tidy(Balance.ULTIMATE_N),
			Balance.tidy(Balance.ULTIMATE_ONE_WIDE_N)])
		if not away.is_empty():
			lines.append("Comes away, in the order it goes:")
			for one: Away in away:
				lines.append("  " + away_words(one, true) + ".")
		if ring != null:
			lines.append("The part lifted's own joints, together: " + ring_words() + ".")
		var holding: Array = joints.filter(func(one: Balance.JointLoad) -> bool:
			return not swings.has(one))
		# Those that hold it a hundred times over and more say nothing.
		var said_ones: Array = holding.filter(func(one: Balance.JointLoad) -> bool:
			return LiftTest.give_of(one) >= 0.01).slice(0, count)
		if holding.is_empty():
			lines.append("No joint left alone holds what is past it: every part left is held more than one way, and shares its load.")
		else:
			lines.append("Of the %d joint%s left that each alone hold what is past them, nearest letting go first:"
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
		return "\n".join(lines)


## How many times what lets it go, as said: two places under 10, so a joint
## just past it reads 1.02 and not 1.0.
static func times(give: float) -> String:
	return "%.2f" % give if give < 10.0 else Balance.tidy(give)


## How near [param one] is to letting go: its moment over what its studs
## hold where they let go, or its pins where they slip. Past 1 it goes.
static func give_of(one: Balance.JointLoad) -> float:
	if one.kind in ["axle", "two lines"]:
		return 0.0
	if one.ultimate <= 0.000001:
		return INF if one.moment > 0.000001 else 0.0
	return one.moment / one.ultimate


## Lift [param bricks] (a world's, the floor's among them or not) by part
## [param by]. Null when [member stop] was asked.
func lift(bricks: Array, by: int) -> Result:
	var result := Result.new()
	result.by = by
	var model: Array = []
	var held: BrickWorld.Brick = null
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		if floor_ids.has(brick.id):
			continue
		model.append(brick)
		if brick.id == by:
			held = brick
	if held == null:
		result.by = 0
		result.problem = ("The baseplate is the floor: lift the model by one of its own parts."
			if floor_ids.has(by) else "There is no part #%d in the model to lift it by." % by)
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
	if (boxes.get(by, PackedInt32Array()) as PackedInt32Array).is_empty() \
			or library.mesh_for(held.part_id) == null or not library.parts.has(held.part_id):
		result.by = 0
		result.problem = "Its shape has not come yet: lift it again in a moment."
		return result
	# The part lifted is the one place the model is held, as the floor's
	# parts are where it stands.
	var hand: Dictionary = Balance.support_of({by: boxes[by]})
	var known: Dictionary = {}
	var overlaps: Dictionary = {}
	var left: Array = model
	var round: int = 0
	while true:
		var weigher := Balance.new()
		weigher.library = library
		weigher.lattice = lattice
		weigher.known = known
		weigher.overlaps = overlaps
		weigher.support = hand
		weigher.stop = stop
		var weighed: Balance.Report = weigher.measure(left, [], null, graph)
		if _stopping():
			return null
		if round == 0:
			result.grams = weighed.grams
		result.rounds = round + 1
		var going: Array[Away] = _going(weigher, weighed, by, boxes, round >= ROUNDS)
		var cut: Dictionary = {}
		var cut_grams: float = 0.0
		for one: Away in going:
			result.away.append(one)
			cut_grams += one.grams
			for id: int in one.ids:
				cut[id] = true
				result.gone[id] = one
		# Done when nothing more goes, or a few rounds past the last in
		# which all still past their hold went at once.
		if going.is_empty() or round >= ROUNDS + 2:
			result.kept_grams = weighed.grams - cut_grams
			result.held = weighed.held
			if going.is_empty():
				result.ring = weigher.ring_of(by, boxes)
			for one: Balance.JointLoad in weighed.joints:
				if one.beyond == by or cut.has(one.beyond):
					continue
				result.joints.append(one)
				if one.kind in ["friction pin", "free pin"] and one.moment > one.ultimate:
					result.swings.append(one)
			result.joints.sort_custom(func(a: Balance.JointLoad, b: Balance.JointLoad) -> bool:
				var ga: float = LiftTest.give_of(a)
				var gb: float = LiftTest.give_of(b)
				return ga > gb if ga != gb else a.beyond < b.beyond)
			break
		left = left.filter(func(item: Variant) -> bool:
			return not cut.has((item as BrickWorld.Brick).id))
		round += 1
	return result


## What comes away from [param weighed] this round: what nothing joins to
## the part lifted ([param by]), what falls off a touch, and the stud joints
## past where they let go that go before any other could relieve them: each
## joint alone holding what is past it, and the part lifted's own joints
## together (Balance.ring_of), which hold everything. The worst goes first,
## and with it all past it; any other past its hold goes too unless it is
## above one gone, whose going may let it hold, or under one not yet
## decided. In the [param last] round all of them go, the worst first.
func _going(weigher: Balance, weighed: Balance.Report, by: int, boxes: Dictionary,
		last: bool) -> Array[Away]:
	var out: Array[Away] = []
	var loose := PackedInt64Array()
	var loose_grams: float = 0.0
	for id: Variant in weighed.held:
		if str(weighed.held[id]) == "nothing":
			loose.append(int(id))
			loose_grams += _grams_of(weigher, int(id))
	for piece: Dictionary in weighed.tipping:
		var one := Away.new()
		one.why = "falls"
		one.ids = PackedInt64Array(piece["ids"])
		one.grams = float(piece["grams"])
		one.on = int(piece["on"])
		out.append(one)
	if not loose.is_empty():
		loose.sort()
		var one := Away.new()
		one.why = "loose"
		one.ids = loose
		one.grams = loose_grams
		out.append(one)
	var over: Array = weighed.joints.filter(func(one: Balance.JointLoad) -> bool:
		return one.kind == "studs" and LiftTest.give_of(one) > 1.0)
	var held_ring: Array = []
	var ring: Balance.JointLoad = weigher.ring_of(by, boxes, held_ring)
	if ring != null and LiftTest.give_of(ring) > 1.0:
		over.append(ring)
	over.sort_custom(func(a: Balance.JointLoad, b: Balance.JointLoad) -> bool:
		var ga: float = LiftTest.give_of(a)
		var gb: float = LiftTest.give_of(b)
		return ga > gb if ga != gb else a.beyond < b.beyond)
	var cut: Dictionary = {}
	var roots: Array = []
	for one: Balance.JointLoad in over:
		var whole: bool = one == ring
		if not whole and cut.has(one.beyond):
			continue
		var past: PackedInt64Array = PackedInt64Array(held_ring) if whole else weigher.past(one.beyond)
		var above: bool = false
		for root: int in roots:
			if past.has(root):
				above = true
		if above and not last:
			# Relieved by what went under it: weighed again first. And so is
			# everything after it, which it may yet take with it.
			break
		roots.append(one.beyond)
		var going := Away.new()
		going.why = "lets go"
		going.joint = one
		going.whole = whole
		going.give = LiftTest.give_of(one)
		for id: int in past:
			if not cut.has(id):
				cut[id] = true
				going.ids.append(id)
				going.grams += _grams_of(weigher, id)
		out.append(going)
	return out


## What part [param id] weighs, as [param weigher] read it.
static func _grams_of(weigher: Balance, id: int) -> float:
	var it: Array = weigher.known.get(id, [])
	return float(it[1]) if it.size() > 1 else 0.0


func _stopping() -> bool:
	return stop != null and stop.asked()
