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
class_name StressView
extends Node

const RED := BalanceMark.TIPS
const AMBER := BalanceMark.CLOSE
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
	var how: String = "hold it up from below, or hang it from more studs" if one.hangs \
		else "brace it, give it more studs, or move weight back over the %s" % _named(library,
			one.held_part)
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
	return words(id) if id > 0 else ""


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
		return "%s: carries %s g %s, margin %s" % [name, Balance.tidy(one.grams),
			"hanging from" + one.held_on().trim_prefix("on") if one.hangs else one.held_on(),
			margin_words(1.0 / maxf(one.ratio, 0.000001))]
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
	return ("Brace this: the %s %s %s g %s of the %s, %s its %sworking "
		+ "load (margin %s). Make that joint hold, by supporting what it carries or by "
		+ "tying it in with %s, and change nothing else.") % [
		_name(one.beyond_part), "hangs" if one.hangs else "carries", Balance.tidy(one.grams),
		"from" + one.held_on().trim_prefix("on") if one.hangs else one.held_on(),
		_name(one.held_part), "past" if margin_of(id) < WEAK else "near",
		"studs' " if one.kind == "studs" else "", margin_words(margin_of(id)),
		"more studs" if one.kind == "studs" else "a second pin off its line"]


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
			+ "edge each would turn on (1 N a stud working, about 3 N lets go); on pins or axles "
			+ "in a line, turned about it (a friction pin about 0.75 N·cm working, 1 slips; a "
			+ "frictionless one nothing); an axle keyed in its hole or pins on two lines, held "
			+ "square. The weakest:") % [
			all, "" if all == 1 else "s"])
	# A piece on a touch past where it touches first: it falls.
	for risk: Stability.Risk in weighed.risks:
		if risk.kind == "rests on a touch":
			lines.append("  #%d and what is with it: %s, red." % [risk.brick_id, risk.message])
	for listed: Weak in joints.slice(0, count):
		var one: Balance.JointLoad = listed.joint
		var margin: float = listed.margin
		var how: String
		if margin < WEAK:
			how = "past its studs' working load, red"
		elif margin < CLOSE:
			how = "within twice its working load, amber"
		elif margin >= 100.0:
			how = "held square, nothing turns it" if one.kind in ["axle", "two lines"] else (
				"nothing turns it about its pin" if one.kind != "studs"
				else "pressed straight down, nothing levers it")
		else:
			how = "holds it %s times over" % Balance.studs(margin)
		lines.append("  #%d %s %s #%d %s %s, %s g past it: margin %s (%sx its working load), %s%s" % [
			one.beyond, _named(library, one.beyond_part), "hangs from" if one.hangs else "stands on",
			one.held_by, _named(library, one.held_part), one.held_on(),
			Balance.tidy(one.grams), margin_words(margin), Balance.tidy(one.ratio), how,
			"; it lets go at about %s times this load" % Balance.tidy(
				(one.ultimate / maxf(one.capacity, 0.000001) if one.kind != "studs" else 3.0) * margin)
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
