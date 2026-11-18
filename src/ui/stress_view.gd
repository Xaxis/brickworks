## View, Stress: every part tinted by how near its weakest joint is to
## letting go, rather than a list of weak joints.
##
## Studio colours weak parts pink and red, and its own help calls its check
## "very conservative": it "often flags parts that are actually well
## connected". This reads the joints as Balance weighs them
## (src/assembly/balance.gd, docs/MECHANISMS.md §4). A stud joint that alone
## holds what is past it — a cantilever's root, a tower's foot, a part hung
## under another — is levered about the edge it would turn on, and its studs
## hold it there at their working load, 1 N a stud; its margin is how many
## times over. The part past a joint under 1 is red, under 2 amber, and every
## other part is drawn in its own colour, faded. A joint that shares its load
## with others, as a bonded wall's do, is never the one that gives first, and
## is left plain. A touch shares nothing: a part that only touches another
## carries weight straight down into it and nothing else (Balance), and one
## standing on touches alone with its weight past them is red.
##
## Pointing at a part says on the status bar what it carries and on what:
## "carries 12 g on 1 stud, margin 0.4". A weak one's menu offers Ask Claude
## to brace this (Shell.open_context). Its panel (StressPanel) says what the
## colours mean, how many joints are past their working load and how many
## near it, and lists the weakest, worst first, to step through: walk180
## found a 3,164-part hotel washed pale with nothing to say it stands, where
## Studio lists what it reads weak (2026-10-23, A9).
##
## The weighing is the status bar's own (Main._weigh), on a worker after a
## change, asked for its margins only while this is on: off, it costs
## nothing. The drawing is BrickWorld's (set_stress), the picture only, as
## x-ray's ghosts are: the paint, the history and the saves never change.
##
## Its Lift (loadtest, APP_UX8 #13): the model lifted by a part, off the
## floor, as a person picks a car up by its roof. Lift on, the part chosen
## (clicked, tapped, or already selected) is the one in the hand; every joint
## between it and the rest carries what hangs past it, and what lets go is
## red with everything that comes away with it, a joint that holds past its
## working load amber, the part lifted blue (LiftTest). Choosing another part
## lifts by that one; a change to the model lifts it again; Lift off, the
## model stands again.
class_name StressView
extends Node

const RED := BalanceMark.TIPS
const AMBER := BalanceMark.CLOSE
## The part a lift holds the model by.
const LIFTED := Color(0.32, 0.58, 1.0)
## Under this margin a joint is past its working load; under twice it, close.
const WEAK := 1.0
const CLOSE := 2.0

var world: BrickWorld
var library: PartLibrary
var scenery: Dictionary = {}
var say: Callable = func(_line: String) -> void: pass
## The part under the pointer (Main._hovered), 0 or less for none.
var hovered: Callable = func() -> int: return 0

## A weighing with its margins wanted at once (Main._weigh).
signal wanted

var on: bool = false
## The weighing drawn, null until the first arrives.
var report: Stability.Report = null
## The legend, the count and the weakest joints, over the model's right
## edge (Shell); null for a view with no window, as a probe's.
var panel: StressPanel = null

## Lift: the builder, whose lattice a lift reads and whose selection says
## the part chosen (Shell); Lift on; what lifting showed (LiftTest.Result),
## null while nothing is lifted, and the model's revision it was of.
var builder: Builder = null
var lifting: bool = false
var lift: RefCounted = null
var _lift_revision: int = -1
var _lift_generation: int = -1
## The newest lift asked for: an older one coming in late is dropped.
var _lift_asked: int = 0
## Set while the panel selects a row's parts to show them, which is not a
## part chosen to lift by.
var framing: bool = false


## One place the view shows weak, as its panel lists it: a stud joint that
## alone holds what is past it, by the part past it, or a piece standing on a
## touch alone past where it touches.
class Weak extends RefCounted:
	## The part said and selected, every part that comes off with it that
	## the view tints, and what holds it, framed with it.
	var id: int = 0
	var ids: Array = []
	var around: int = 0
	## The joint, or null for a piece on a touch.
	var joint: Balance.JointLoad = null
	## How many times over it holds what is past it: 0 for a piece on a
	## touch past where it touches, which falls.
	var margin: float = INF


## Turn the view on or off. On, the model is drawn faded at once and its
## weak joints tinted when the weighing it asks for comes in.
func set_on(value: bool) -> void:
	if value == on:
		return
	on = value
	report = null
	if not on:
		lifting = false
		lift = null
		_lift_asked += 1
	world.set_stress(on)
	if panel != null:
		panel.visible = on
		panel.show_weak([])
	if on:
		say.call("stress: red is past its working load, amber within twice it — "
			+ "point at a part for what it carries")
		wanted.emit()
	else:
		say.call("stress off")


## A weighing with its margins (Main._weigh): each part past a weak joint
## tinted, the rest faded.
func show_report(weighed: Stability.Report) -> void:
	if not on or weighed == null:
		return
	report = weighed
	# Lifted, the lift is what is drawn: the model changed, lifted again;
	# another opened, its part chosen afresh.
	if lifting and lift != null and world.generation() != _lift_generation:
		lift = null
		_lift_asked += 1
		say.call("lift: click the part to lift the model by")
	if lifting and lift != null:
		if world.revision != _lift_revision:
			_lift_again()
		return
	var tints: Dictionary = {}
	for id: int in weighed.margins:
		if scenery.has(id):
			continue
		var margin: float = margin_of(id)
		if margin < CLOSE:
			tints[id] = RED if margin < WEAK else AMBER
	# And what stands on a touch alone with its weight past it: it falls.
	for id: Variant in weighed.held:
		if weighed.held[id] == "tips off" and not scenery.has(int(id)):
			tints[int(id)] = RED
	world.set_stress(true, tints)
	if panel != null:
		panel.show_weak(ranked(weighed, world, scenery, StressPanel.AT_LEAST))


## The places [param weighed] is weak, worst first (Weak): each piece standing
## on a touch alone past where it touches, heaviest first, since it falls;
## then the joints that alone hold what is past them, nearest their working
## load first, a tie by the part's id. What the panel lists and a session's
## weakest_joints says. Every one red or amber, and the weakest of the rest
## to make [param least] joints in all; every joint when it is -1. Sorting
## all of the hotel's 581 was most of the 6 ms a weighing took to show.
static func ranked(weighed: Stability.Report, world: BrickWorld, scenery: Dictionary,
		least: int = -1) -> Array:
	var out: Array = []
	if weighed == null:
		return out
	for piece: Dictionary in weighed.tipping:
		var ids: Array = (piece["ids"] as Array).filter(func(id: Variant) -> bool:
			return not scenery.has(int(id)) and world.get_brick(int(id)) != null)
		if ids.is_empty():
			continue
		var weak := Weak.new()
		weak.id = int(ids[0])
		weak.ids = ids
		weak.around = int(piece["on"])
		weak.margin = 0.0
		out.append(weak)
	var ratios := PackedFloat64Array()
	var loads: Array = []
	for id: Variant in weighed.margins:
		if not scenery.has(int(id)) and world.get_brick(int(id)) != null:
			loads.append(weighed.margins[id])
			ratios.append((weighed.margins[id] as Balance.JointLoad).ratio)
	# Under a margin of CLOSE is a ratio over 1 / CLOSE.
	var cut: float = 1.0 / CLOSE
	if least < 0 or ratios.size() <= least:
		cut = -INF
	elif least > 0:
		var sorted: PackedFloat64Array = ratios.duplicate()
		sorted.sort()
		cut = minf(cut, sorted[sorted.size() - least])
	var joints: Array = []
	for n: int in loads.size():
		if ratios[n] >= cut or ratios[n] > 1.0 / CLOSE:
			joints.append(loads[n])
	joints.sort_custom(func(a: Balance.JointLoad, b: Balance.JointLoad) -> bool:
		return a.ratio > b.ratio or (a.ratio == b.ratio and a.beyond < b.beyond))
	for one: Balance.JointLoad in joints:
		var weak := Weak.new()
		weak.id = one.beyond
		weak.ids = [one.beyond]
		weak.around = one.held_by
		weak.joint = one
		weak.margin = 1.0 / maxf(one.ratio, 0.000001)
		out.append(weak)
	return out


## How many joints alone hold what is past them in [param weighed].
static func joints_in(weighed: Stability.Report, world: BrickWorld, scenery: Dictionary) -> int:
	var count: int = 0
	if weighed != null:
		for id: Variant in weighed.margins:
			if not scenery.has(int(id)) and world.get_brick(int(id)) != null:
				count += 1
	return count


## Of [param weak] (as [method ranked] gives), how many are past their
## working load and how many near it: [past, near].
static func tally(weak: Array) -> Array:
	var past: int = 0
	var near: int = 0
	for one: Weak in weak:
		if one.margin < WEAK:
			past += 1
		elif one.margin < CLOSE:
			near += 1
	return [past, near]


## The count as the panel heads it and a session reads it.
static func count_words(weak: Array) -> String:
	var counted: Array = tally(weak)
	return "%d past working load · %d near it" % counted


## What would make [param weak] hold, as the designer is told to make a joint
## past its working load hold (Balance.Report.said): with how much more hold
## it needs, and empty for one that holds twice over already.
static func fix_words(weak: Weak, library: PartLibrary) -> String:
	var one: Balance.JointLoad = weak.joint
	if one == null:
		return "Hold it with studs, or move its weight back over where it touches."
	if weak.margin >= CLOSE:
		return ""
	# By its kind: a pin has no studs to be given more of, and what nothing
	# holds no hold to be times more of (drvrecheck F2).
	if one.holds_nothing():
		return ("Nothing holds it there: give it studs to stand on, or hold up what it carries."
			if one.kind == "studs" else "It turns with nothing holding it: tie it in with a second "
			+ "pin off its line, or hold up what it carries.")
	# A ball turns any way: no second line ties it in (posehold).
	var more: String = "give it more studs" if one.kind == "studs" else (
		"shorten or lighten what hangs on it" if one.hold == PoseHold.TECHNIC_BALL
		else "tie it in with a second pin off its line")
	var how: String = "hold it up from below, or hang it from more studs" if one.hangs and one.kind == "studs" \
		else "brace it, %s, or move weight back over the %s" % [more, _named(library, one.held_part)]
	if weak.margin < WEAK:
		return "It needs %s times the hold it has: %s." % [Balance.tidy(one.ratio), how]
	return "To hold it twice over, %s." % how


## How many times over the one stud joint holding [param id] holds what is
## past it; INF for a part no one stud joint holds.
func margin_of(id: int) -> float:
	if report == null or not report.margins.has(id):
		return INF
	return 1.0 / maxf((report.margins[id] as Balance.JointLoad).ratio, 0.000001)


## Of [param ids] (id -> anything), the part on the weakest joint under
## [constant CLOSE]; 0 for none.
func weakest_of(ids: Dictionary) -> int:
	if not on:
		return 0
	var found: int = 0
	var least: float = CLOSE
	for id: Variant in ids:
		var margin: float = margin_of(int(id))
		if margin < least:
			least = margin
			found = int(id)
	return found


## What the status bar says of the part under the pointer: "" for none, or
## while the view is off.
func line() -> String:
	if not on:
		return ""
	var id: int = hovered.call()
	if id > 0 and lift != null and not scenery.has(id):
		return lift.call("part_words", id)
	return words(id) if id > 0 else ""


# -- Lift (loadtest) ------------------------------------------------------------


## Lift on or off. On, the one part selected, when there is one, is lifted by
## at once, and otherwise the next one chosen; off, the model stands again.
func set_lift(value: bool) -> void:
	if value == lifting:
		return
	lifting = value
	lift = null
	_lift_asked += 1
	if not lifting:
		say.call("lift off: the model stands on the floor again")
		if report != null:
			show_report(report)
		elif panel != null:
			panel.show_weak([])
		return
	if not on:
		set_on(true)
		lifting = true
	var one: int = _one_chosen()
	if one != 0:
		lift_by(one)
		return
	say.call("lift: click the part to lift the model by")
	if panel != null:
		panel.show_lift(null)


## Lift the model by part [param id] and draw what gives: on a worker for a
## big model, as the status bar weighs one.
func lift_by(id: int) -> void:
	_lift_asked += 1
	var asked: int = _lift_asked
	var revision: int = world.revision
	var generation: int = world.generation()
	if panel != null:
		panel.lifting_now(id)
	var lifted: RefCounted = await lift_paced(id)
	if asked != _lift_asked or not lifting or world.generation() != generation:
		return
	if lifted == null:
		# A part the library had to add meanwhile: lifted again at the next
		# weighing.
		_lift_revision = -1
		return
	if int(lifted.get("by")) == 0:
		say.call(str(lifted.get("problem")))
		if panel != null:
			panel.show_lift(lifted)
		return
	lift = lifted
	_lift_revision = revision
	_lift_generation = generation
	_show_lift()


## The model changed while lifted: lifted again by the same part, or, when
## that part is gone, back to choosing one.
func _lift_again() -> void:
	var by: int = int(lift.get("by"))
	if world.get_brick(by) == null:
		lift = null
		_lift_asked += 1
		say.call("lift: the part it was lifted by is gone — click another")
		if panel != null:
			panel.show_lift(null)
		return
	_lift_revision = world.revision
	lift_by(by)


func _show_lift() -> void:
	var tints: Dictionary = {}
	for one: Balance.JointLoad in lift.get("joints"):
		if one.ratio > 1.0 or (lift.get("swings") as Array).has(one):
			tints[one.beyond] = AMBER
	for id: Variant in lift.get("gone"):
		tints[int(id)] = RED
	tints[int(lift.get("by"))] = LIFTED
	world.set_stress(true, tints)
	say.call(lift.call("headline"))
	if panel != null:
		panel.show_lift(lift)


## The one part chosen, not the floor's: 0 for none, or for several.
func _one_chosen() -> int:
	if builder == null or builder.selection.size() != 1:
		return 0
	var id: int = int(builder.selection.keys()[0])
	return 0 if scenery.has(id) or world.get_brick(id) == null else id


## A part chosen while Lift is on is the one lifted by, but not one the
## panel selected to show a row's parts (Shell connects it).
func chosen(_count: int) -> void:
	if not lifting or framing:
		return
	var one: int = _one_chosen()
	if one != 0 and (lift == null or int(lift.get("by")) != one):
		lift_by(one)


## The model lifted by part [param id] (LiftTest.Result), what Lift draws
## and a session's weakest_joints lift_by= reads, so the two agree: on a
## worker on copies of the model and the lattice where there are threads and
## the model is big, the library holding new arrivals aside. Parts named by
## their names, with their numbers when [param numbered] (a session's).
## Null when the library had to add a part meanwhile.
func lift_paced(id: int, numbered: bool = false) -> RefCounted:
	var lifter: RefCounted = Later.script(&"LiftTest").new()
	lifter.library = library
	lifter.floor_ids = scenery.duplicate()
	var lifted: RefCounted
	if world.brick_count() < Stability.ON_A_WORKER_FROM or OS.has_feature("nothreads"):
		lifter.lattice = builder.lattice
		lifted = lifter.lift(world.bricks(), id)
	else:
		lifter.lattice = builder.lattice.copy_for_reading()
		lifter.stop = WorkerTasks.Stop.new()
		var still: BrickWorld = world.copy_for_reading()
		var out: Array = [null]
		library.begin_reading()
		var task: int = WorkerTasks.add(func() -> void:
			out[0] = lifter.lift(still.bricks(), id), false, "lift the model")
		library.reading_in(task, func() -> void: (lifter.stop as WorkerTasks.Stop).ask())
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerTasks.collect(task)
		library.end_reading(task)
		still.free()
		lifted = out[0]
	if lifted != null:
		lifted.set("namer", func(part: int) -> String:
			var brick: BrickWorld.Brick = world.get_brick(part)
			var name: String = _name(brick.part_id) if brick != null else "?"
			return "#%d %s" % [part, name] if numbered else name)
	return lifted


## What [param id] carries and on what, as the person reads it.
func words(id: int) -> String:
	return part_words(report, world, library, scenery, id)


## What part [param id] of [param world] carries and on what, as [param
## weighed] has it: what pointing at it says, and a session's weakest_joints.
static func part_words(weighed: Stability.Report, world: BrickWorld, library: PartLibrary,
		scenery: Dictionary, id: int) -> String:
	var brick: BrickWorld.Brick = world.get_brick(id)
	if brick == null or weighed == null or scenery.has(id):
		return ""
	var name: String = _named(library, brick.part_id)
	var one: Balance.JointLoad = weighed.margins.get(id)
	if one != null:
		# What nothing holds has no margin (drvrecheck F2).
		return "%s: carries %s g %s, %s" % [name, Balance.tidy(one.grams),
			"hanging from" + one.held_on().trim_prefix("on") if one.hangs else one.held_on(),
			"with nothing holding it" if one.holds_nothing() and one.moment > 0.000001
			else "margin " + margin_words(1.0 / maxf(one.ratio, 0.000001))]
	match str(weighed.held.get(id, "")):
		"floor":
			return "%s: stands on the %s" % [name, "baseplate" if not scenery.is_empty() else "ground"]
		"other":
			return "%s: held by a clip, a hinge, a ball or a turntable, which are not weighed" % name
		"nothing":
			return "%s: held by nothing that can be weighed" % name
		"rests":
			return "%s: stands on what is under it, its weight over where they touch" % name
		"tips off":
			return "%s: stands on a touch alone, its weight past where it touches" % name
	return "%s: held more than one way, so no one joint carries it" % name


## What Ask Claude to brace this asks, for the part on a weak joint.
func brace_words(id: int) -> String:
	var one: Balance.JointLoad = report.margins.get(id) if report != null else null
	if one == null:
		return ""
	# What nothing holds is past no working load by a margin: it has none
	# (drvrecheck F2).
	var how: String = "with nothing holding it" if one.holds_nothing() and one.moment > 0.000001 \
		else "%s its %sworking load (margin %s)" % ["past" if margin_of(id) < WEAK else "near",
			"studs' " if one.kind == "studs" else "", margin_words(margin_of(id))]
	return ("Brace this: the %s %s %s g %s of the %s, %s. Make that joint hold, by supporting "
		+ "what it carries or by tying it in with %s, and change nothing else.") % [
		_name(one.beyond_part), "hangs" if one.hangs else "carries", Balance.tidy(one.grams),
		"from" + one.held_on().trim_prefix("on") if one.hangs else one.held_on(),
		_name(one.held_part), how,
		"more studs" if one.kind == "studs" else (
			"a second joint beside it" if one.hold == PoseHold.TECHNIC_BALL else "a second pin off its line")]


## A margin as said: one decimal, and a joint pressed straight down, with
## nothing levering it, "100+".
static func margin_words(margin: float) -> String:
	return Balance.studs(margin) if margin < 100.0 else "100+"


func _name(part_id: String) -> String:
	return _named(library, part_id)


static func _named(library: PartLibrary, part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	return Inventory._tidy(info.name) if info != null else part_id


## What a session reads of the view (AppTools' weakest_joints), from the
## weighing the view draws (Main.weigh_joints): the verdict; the [param
## count] joints that alone hold what is past them, weakest first, each with
## what it carries, on what, and its margin; any piece standing on a touch
## alone, past where it touches; and how the parts no one joint holds are
## held. [param part] > 0 says what holds that one part instead.
static func said(weighed: Stability.Report, world: BrickWorld, library: PartLibrary,
		scenery: Dictionary, count: int = 8, part: int = 0) -> String:
	var lines := PackedStringArray(["As View, Stress weighs it: %s." % weighed.summary()])
	for risk: Stability.Risk in weighed.risks:
		if risk.kind in ["leaning", "top-heavy", "tips"]:
			lines.append("  It %s: %s." % ["tips over" if risk.kind == "tips" else "is " + risk.kind,
				risk.message])
	if part > 0:
		var about: String = part_words(weighed, world, library, scenery, part)
		lines.append("#%d %s." % [part, about] if not about.is_empty()
			else "There is no part #%d in the model." % part)
		return "\n".join(lines)
	# As the panel counts and lists them (ranked), so the two agree.
	var weak: Array = ranked(weighed, world, scenery, count)
	lines.append("%s (red past the studs' working load, amber within twice it)." % count_words(weak))
	var joints: Array = weak.filter(func(one: Weak) -> bool: return one.joint != null)
	var all: int = joints_in(weighed, world, scenery)
	if all == 0:
		lines.append("No joint alone holds what is past it: every part is held more than one way.")
	else:
		lines.append(("%d joint%s each hold alone what is past them: on studs, levered about the "
			+ "edge each would turn on (%s N a stud working; it lets go at about %s N, %s N into "
			+ "a part a stud wide); on pins or axles "
			+ "in a line, turned about it (a friction pin about 0.75 N·cm working, 1 slips; a "
			+ "frictionless one nothing); an axle keyed in its hole or pins on two lines, held "
			+ "square; the weakest:") % [
			all, "" if all == 1 else "s", Balance.tidy(Balance.ALLOWABLE_N),
			Balance.tidy(Balance.ULTIMATE_N), Balance.tidy(Balance.ULTIMATE_ONE_WIDE_N)])
	# A piece on a touch past where it touches first: it falls.
	for risk: Stability.Risk in weighed.risks:
		if risk.kind == "rests on a touch":
			lines.append("  #%d and what is with it: %s, red." % [risk.brick_id, risk.message])
	for listed: Weak in joints.slice(0, count):
		var one: Balance.JointLoad = listed.joint
		var margin: float = listed.margin
		var who: String = "  #%d %s %s #%d %s %s, %s g past it: " % [one.beyond,
			_named(library, one.beyond_part), "hangs from" if one.hangs else "stands on", one.held_by,
			_named(library, one.held_part), one.held_on(), Balance.tidy(one.grams)]
		# What nothing holds has no working load to be a margin of, nor a
		# load it lets go at: divided by that nothing, a steering arm free on
		# its axle read "3801303x its working load" (drvrecheck F2).
		if one.holds_nothing():
			var said: String
			if one.moment <= 0.000001:
				said = "nothing levers it" if one.kind == "studs" else "nothing turns it about its line"
			elif one.kind == "studs":
				said = "nothing holds it there, red"
			else:
				said = "it turns with nothing holding it, %s N·cm about its line, red" % Balance.tidy(one.moment)
			lines.append(who + said)
			continue
		# A friction joint holds its pose or droops (posehold): by the share
		# of what hangs on it that one of its kind holds.
		if not one.hold.is_empty():
			lines.append(who + ("droops: it %s, red" if one.droops() else "holds its pose: it %s")
				% PoseHold.share_words(one.share()))
			continue
		var how: String
		if margin < WEAK:
			how = "past its %sworking load, red" % ("studs' " if one.kind == "studs" else "")
		elif margin < CLOSE:
			how = "within twice its working load, amber"
		elif margin >= 100.0:
			how = "held square, nothing turns it" if one.kind in ["axle", "two lines"] else (
				"nothing turns it about its pin" if one.kind != "studs"
				else "pressed straight down, nothing levers it")
		else:
			how = "holds it %s times over" % Balance.studs(margin)
		lines.append(who + "margin %s (%sx its working load), %s%s" % [margin_words(margin),
			Balance.tidy(one.ratio), how,
			"; it lets go at about %s times this load" % Balance.tidy(
				one.ultimate / maxf(one.capacity, 0.000001) * margin)
				if margin < 100.0 else ""])
	var held: Dictionary = {}
	for id: Variant in weighed.held:
		if not scenery.has(int(id)):
			held[weighed.held[id]] = int(held.get(weighed.held[id], 0)) + 1
	var rest := PackedStringArray()
	for pair: Array in [["floor", "standing on the %s" % ("baseplate" if not scenery.is_empty()
			else "ground")], ["rests", "standing on what is under them by touch, their weight over it"],
			["other", "held by a clip, a hinge, a ball or a turntable, not weighed"],
			["nothing", "held by nothing the weighing reads"]]:
		if int(held.get(pair[0], 0)) > 0:
			rest.append("%d %s" % [int(held[pair[0]]), pair[1]])
	if not rest.is_empty():
		lines.append("Held otherwise: " + "; ".join(rest) + ".")
	lines.append("A touch (one face on another, no stud between) carries only what stands on it, "
		+ "and never shares a joint's load. part= says what holds one part.")
	return "\n".join(lines)
