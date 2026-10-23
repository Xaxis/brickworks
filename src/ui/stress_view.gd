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
## is left plain.
##
## Pointing at a part says on the status bar what it carries and on what:
## "carries 12 g on 1 stud, margin 0.4". A weak one's menu offers Ask Claude
## to brace this (Shell.open_context).
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


## Turn the view on or off. On, the model is drawn faded at once and its
## weak joints tinted when the weighing it asks for comes in.
func set_on(value: bool) -> void:
	if value == on:
		return
	on = value
	report = null
	world.set_stress(on)
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
	world.set_stress(true, tints)


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
	var brick: BrickWorld.Brick = world.get_brick(id)
	if brick == null or report == null or scenery.has(id):
		return ""
	var name: String = _name(brick.part_id)
	var one: Balance.JointLoad = report.margins.get(id)
	if one != null:
		return "%s: carries %s g %s %d stud%s, margin %s" % [name, Balance.tidy(one.grams),
			"hanging from" if one.hangs else "on", one.studs, "" if one.studs == 1 else "s",
			margin_words(margin_of(id))]
	match str(report.held.get(id, "")):
		"floor":
			return "%s: stands on the %s" % [name, "baseplate" if not scenery.is_empty() else "ground"]
		"other":
			return "%s: held by a pin, an axle, a clip or a hinge, which are not weighed" % name
		"nothing":
			return "%s: held by nothing that can be weighed" % name
	return "%s: held more than one way, so no one joint carries it" % name


## What Ask Claude to brace this asks, for the part on a weak joint.
func brace_words(id: int) -> String:
	var one: Balance.JointLoad = report.margins.get(id) if report != null else null
	if one == null:
		return ""
	return ("Brace this: the %s %s %s g %s %d stud%s of the %s, %s its studs' working "
		+ "load (margin %s). Make that joint hold, by supporting what it carries or by "
		+ "tying it in with more studs, and change nothing else.") % [
		_name(one.beyond_part), "hangs" if one.hangs else "carries", Balance.tidy(one.grams),
		"from" if one.hangs else "on", one.studs, "" if one.studs == 1 else "s",
		_name(one.held_part), "past" if margin_of(id) < WEAK else "near",
		margin_words(margin_of(id))]


## A margin as said: one decimal, and a joint pressed straight down, with
## nothing levering it, "100+".
static func margin_words(margin: float) -> String:
	return Balance.studs(margin) if margin < 100.0 else "100+"


func _name(part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	return Inventory._tidy(info.name) if info != null else part_id
